import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client } from 'minio';
import sharp from 'sharp';
import { randomUUID } from 'crypto';

const MAX_DIMENSION = 1200;
const WEBP_QUALITY = 80;

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private client: Client;
  private bucket: string;
  private publicBaseUrl: string;

  constructor(private config: ConfigService) {
    this.bucket = this.config.get<string>('MINIO_BUCKET', 'shelfshare');

    this.client = new Client({
      endPoint: this.config.get<string>('MINIO_ENDPOINT', 'minio'),
      port: this.config.get<number>('MINIO_PORT', 9000),
      useSSL: this.config.get<string>('MINIO_USE_SSL', 'false') === 'true',
      accessKey: this.config.get<string>('MINIO_ROOT_USER')!,
      secretKey: this.config.get<string>('MINIO_ROOT_PASSWORD')!,
    });

    this.publicBaseUrl = this.config.get<string>(
      'MINIO_PUBLIC_URL',
      `http://localhost:${this.config.get<string>('MINIO_API_PORT', '9000')}/${this.bucket}`,
    );
  }

  async onModuleInit() {
    const exists = await this.client
      .bucketExists(this.bucket)
      .catch(() => false);
    if (!exists) {
      await this.client.makeBucket(this.bucket);
      this.logger.log(`Bucket "${this.bucket}" creat`);
    }

    const policy = {
      Version: '2012-10-17',
      Statement: [
        {
          Effect: 'Allow',
          Principal: { AWS: ['*'] },
          Action: ['s3:GetObject'],
          Resource: [`arn:aws:s3:::${this.bucket}/*`],
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

  async deleteImage(path: string): Promise<void> {
    await this.client.removeObject(this.bucket, path).catch((error) => {
      this.logger.warn(`Nu am putut șterge ${path}: ${error}`);
    });
  }

  getPublicUrl(path: string): string {
    return `${this.publicBaseUrl}/${path}`;
  }
}
