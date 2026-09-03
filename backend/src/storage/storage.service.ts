import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'minio';
import sharp from 'sharp';
import { randomUUID } from 'crypto';

const MAX_DIMENSION = 1200;
const WEBP_QUALITY = 80;

/**
 * Prefixele care chiar trebuie citite anonim: sunt referite direct din
 * `<img>`-urile aplicației, deci nu pot purta un antet de autentificare.
 *
 * Policy-ul de dinainte acorda `s3:GetObject` pe `bucket/*`, adică pe TOT
 * bucket-ul - inclusiv `chat-reports/`, unde stau transcripturile
 * conversațiilor raportate (conținut privat între useri). Singura protecție
 * era că numele fișierului conține un UUID, iar linkul din emailul de
 * moderare nu expira niciodată: scăpat sau redirecționat o dată, transcriptul
 * rămânea public permanent. Vezi `getSignedUrl` pentru cum sunt servite acum.
 */
const PUBLIC_PREFIXES = [
  'avatars',
  'user-books',
  'chat',
  'feedback',
  // Coperțile catalogului propriu, importate din scrape (vezi
  // prisma/import-scp-db.js). Sunt conținut de catalog, nu al vreunui user -
  // publice ca orice copertă de carte, și servite de pe domeniul nostru, deci
  // fără proxy-ul de CORS de care au nevoie coperțile de la Google Books.
  'book-covers',
] as const;

/** Cât ține linkul de transcript din emailul de moderare (maximul S3 e 7 zile). */
const SIGNED_URL_TTL_SECONDS = 7 * 24 * 60 * 60;

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private client: Client;
  private signingClient: Client;
  private bucket: string;
  private publicBaseUrl: string;

  constructor(private config: ConfigService) {
    this.bucket = this.config.get<string>('MINIO_BUCKET', 'shelfshare');

    const credentials = {
      accessKey: this.config.get<string>('MINIO_ROOT_USER')!,
      secretKey: this.config.get<string>('MINIO_ROOT_PASSWORD')!,
    };

    this.client = new Client({
      endPoint: this.config.get<string>('MINIO_ENDPOINT', 'minio'),
      port: this.config.get<number>('MINIO_PORT', 9000),
      useSSL: this.config.get<string>('MINIO_USE_SSL', 'false') === 'true',
      ...credentials,
    });

    this.publicBaseUrl = this.config.get<string>(
      'MINIO_PUBLIC_URL',
      `http://localhost:${this.config.get<string>('MINIO_API_PORT', '9000')}/${this.bucket}`,
    );

    // Client separat, doar pentru semnat URL-uri. `client` de mai sus vorbește
    // cu MinIO pe rețeaua internă Docker (`minio:9000`) - un URL semnat de el
    // ar arăta spre acea gazdă, inaccesibilă din afară. Nu putem nici semna
    // intern și rescrie apoi domeniul: semnătura AWS V4 acoperă header-ul
    // `Host`, deci schimbarea gazdei o invalidează. Semnăm direct pentru
    // gazda publică, aceeași pe care o va trimite browserul moderatorului.
    this.signingClient = this.buildSigningClient(credentials);
  }

  private buildSigningClient(credentials: {
    accessKey: string;
    secretKey: string;
  }): Client {
    try {
      const publicUrl = new URL(this.publicBaseUrl);
      const useSSL = publicUrl.protocol === 'https:';
      return new Client({
        endPoint: publicUrl.hostname,
        port: publicUrl.port ? Number(publicUrl.port) : useSSL ? 443 : 80,
        useSSL,
        ...credentials,
      });
    } catch (error) {
      // MINIO_PUBLIC_URL malformat: nu oprim pornirea aplicației pentru o
      // funcție marginală (linkul de transcript din emailul de moderare),
      // dar spunem clar de ce acel link va fi nefolositor din exterior.
      this.logger.warn(
        `MINIO_PUBLIC_URL invalid ("${this.publicBaseUrl}"): ${error}. ` +
          'URL-urile semnate vor arăta spre gazda internă.',
      );
      return this.client;
    }
  }

  async onModuleInit() {
    const exists = await this.client
      .bucketExists(this.bucket)
      .catch(() => false);
    if (!exists) {
      await this.client.makeBucket(this.bucket);
      this.logger.log(`Bucket "${this.bucket}" creat`);
    }

    // Doar prefixele de imagini, nu `bucket/*` - vezi PUBLIC_PREFIXES.
    // `s3:ListBucket` rămâne neacordat: fără el, nici măcar prefixele publice
    // nu pot fi enumerate, ci doar citite dacă știi calea exactă.
    const policy = {
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Principal: { AWS: ['*'] },
          Action: ['s3:GetObject'],
          Resource: PUBLIC_PREFIXES.map(
            (prefix) => `arn:aws:s3:::${this.bucket}/${prefix}/*`,
          ),
        },
      ],
    };
    await this.client
      .setBucketPolicy(this.bucket, JSON.stringify(policy))
      .catch((error) =>
        this.logger.warn(`Nu am putut seta policy pe bucket: ${error}`),
      );
  }

  async uploadImage(buffer: Buffer, folder: string): Promise<string> {
    const resized = await sharp(buffer)
      .resize(MAX_DIMENSION, MAX_DIMENSION, {
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: WEBP_QUALITY })
      .toBuffer();

    const filename = `${folder}/${randomUUID()}.webp`;

    await this.client.putObject(
      this.bucket,
      filename,
      resized,
      resized.length,
      {
        'Content-Type': 'image/webp',
      },
    );

    return filename;
  }

  /**
   * Fișiere text generate de server (momentan doar transcripturile de chat
   * raportate, folderul `chat-reports`). Spre deosebire de imagini, astea NU
   * sunt citibile anonim: `chat-reports` nu e în PUBLIC_PREFIXES, deci se
   * ajunge la ele doar printr-un link semnat, cu expirare (`getSignedUrl`).
   */
  async uploadTextFile(
    content: string,
    folder: string,
    basename: string,
  ): Promise<string> {
    const buffer = Buffer.from(content, 'utf-8');
    const filename = `${folder}/${basename}-${randomUUID()}.txt`;

    await this.client.putObject(this.bucket, filename, buffer, buffer.length, {
      'Content-Type': 'text/plain; charset=utf-8',
    });

    return filename;
  }

  async deleteImage(path: string): Promise<void> {
    await this.client.removeObject(this.bucket, path).catch((error) => {
      this.logger.warn(`Nu am putut șterge ${path}: ${error}`);
    });
  }

  /**
   * Link temporar către un obiect care NU e public (momentan transcripturile
   * din `chat-reports`, trimise în emailul intern de moderare). Expiră după
   * SIGNED_URL_TTL_SECONDS, deci un email scăpat mai târziu nu mai dă acces.
   */
  getSignedUrl(path: string): Promise<string> {
    return this.signingClient.presignedGetObject(
      this.bucket,
      path,
      SIGNED_URL_TTL_SECONDS,
    );
  }

  /**
   * `path` e de obicei o cheie relativă din bucket, dar datele demo (seed.ts)
   * referențiază direct URL-uri absolute către imagini placeholder - le
   * lăsăm neschimbate în loc să le prefixăm greșit cu bucket-ul local.
   *
   * Doar pentru prefixele din PUBLIC_PREFIXES - orice altceva are nevoie de
   * `getSignedUrl`, altfel linkul rezultat dă 403.
   */
  getPublicUrl(path: string): string {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return `${this.publicBaseUrl}/${path}`;
  }
}
