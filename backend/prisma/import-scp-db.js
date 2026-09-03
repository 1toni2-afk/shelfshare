/**
 * Importă catalogul PROPRIU (scrape Cărturești/Google, vezi
 * scripts/book-enrichment) peste rândurile deja existente din `books`, și
 * marchează rândurile atinse cu `curatedAt`.
 *
 * ---------------------------------------------------------------------------
 * DE CE EXISTĂ
 * ---------------------------------------------------------------------------
 * Cele ~1900 de titluri scrapuite există deja ca rânduri în `books`, create de
 * importul în masă din Open Library - îmbogățirea le-a completat descrierea,
 * editura, paginile și anul, dar le-a lăsat `source = 'ol_cdump_import'`,
 * adică exact ce au și cele 3,68M importate în vrac. Fără `curatedAt`,
 * căutarea nu are cum să le prefere: nu le poate distinge.
 *
 * În plus, coperțile scrapuite nu ajunseseră niciodată în bază - rândurile
 * arătau tot spre `covers.openlibrary.org`, deși scrape-ul descărcase local
 * coperta de la editură/librărie.
 *
 * ---------------------------------------------------------------------------
 * CE FACE
 * ---------------------------------------------------------------------------
 * Pentru fiecare carte din ShelfShare_SCP_DB.json, căutată după ISBN:
 *   1. completează câmpurile lipsă din rândul existent (datele scrapuite au
 *      prioritate față de cele din Open Library - de-aia le-am scrapuit);
 *   2. urcă coperta locală în MinIO ca `book-covers/<isbn>.webp` și pune
 *      `coverUrl` spre ea;
 *   3. setează `curatedAt`.
 *
 * Cheia obiectului din MinIO e ISBN-ul, nu un UUID: scriptul trebuie să poată
 * fi rulat de câte ori e nevoie (scrape-ul crește în fiecare noapte) fără să
 * lase în urmă coperți orfane la fiecare rulare.
 *
 * NU creează cărți noi. O carte scrapuită care nu e în catalog e sărită și
 * raportată la final - importul în masă e sursa rândurilor, ăsta doar le
 * îmbogățește.
 *
 * Rulare (din containerul backend, care are deja MINIO_* și DATABASE_URL):
 *   docker exec shelfshare-backend-1 node prisma/import-scp-db.js [--dry-run]
 */

require('dotenv/config');

const fs = require('fs');
const path = require('path');

const SCP_DB_PATH =
  process.env.SCP_DB_PATH || '/scp/ShelfShare_SCP_DB.json';
const COVERS_DIR = process.env.SCP_COVERS_DIR || '/scp/ShelfShare_SCP_DB_covers';

/** Aceleași limite ca StorageService.uploadImage, ca să arate la fel. */
const MAX_DIMENSION = 1200;
const WEBP_QUALITY = 80;

const DRY_RUN = process.argv.includes('--dry-run');

function cleanIsbn(value) {
  return String(value || '')
    .replace(/[-\s]/g, '')
    .trim();
}

/**
 * Datele scrapuite au prioritate, dar nu suprascriu cu gol: un câmp lipsă în
 * scrape nu trebuie să șteargă ce știa deja Open Library.
 */
function pick(scraped, existing) {
  if (scraped === null || scraped === undefined) return existing;
  if (typeof scraped === 'string' && scraped.trim() === '') return existing;
  return scraped;
}

/**
 * Un `coverUrl` scrapuit e bun doar dacă e o adresă absolută ȘI nu e
 * placeholder-ul „fără imagine" al librăriei.
 *
 * Fără verificarea asta, `pick` accepta `/assets/.../img/noimg.jpg` ca valoare
 * validă (e un string ne-gol) și suprascria coperta care funcționa cu o cale
 * relativă care nu se încarcă nicăieri - exact ce s-a întâmplat la prima
 * rulare, pe 8 cărți.
 */
function usableCoverUrl(url) {
  if (typeof url !== 'string') return null;
  const trimmed = url.trim();
  if (!/^https?:\/\//i.test(trimmed)) return null;
  if (/noimg|no-image|placeholder/i.test(trimmed)) return null;
  return trimmed;
}

async function main() {
  const { PrismaClient } = require('@prisma/client');
  const { PrismaPg } = require('@prisma/adapter-pg');
  const sharp = require('sharp');
  const { Client } = require('minio');

  const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
  const prisma = new PrismaClient({ adapter });

  const bucket = process.env.MINIO_BUCKET || 'shelfshare';
  const minio = new Client({
    endPoint: process.env.MINIO_ENDPOINT || 'minio',
    port: Number(process.env.MINIO_PORT || 9000),
    useSSL: process.env.MINIO_USE_SSL === 'true',
    accessKey: process.env.MINIO_ROOT_USER,
    secretKey: process.env.MINIO_ROOT_PASSWORD,
  });
  const publicBaseUrl =
    process.env.MINIO_PUBLIC_URL ||
    `http://localhost:${process.env.MINIO_API_PORT || 9000}/${bucket}`;

  const db = JSON.parse(fs.readFileSync(SCP_DB_PATH, 'utf8'));
  const books = db.books || [];
  console.log(`Catalog scrapuit: ${books.length} titluri (${db.generatedAt})`);
  if (DRY_RUN) console.log('DRY RUN - nu se scrie nimic\n');

  const stats = {
    updated: 0,
    coversUploaded: 0,
    coversMissing: 0,
    notInCatalog: 0,
    failed: 0,
  };
  const missing = [];

  for (const [index, scraped] of books.entries()) {
    const isbn = cleanIsbn(scraped.isbn);
    if (!isbn) continue;

    try {
      const existing = await prisma.book.findUnique({ where: { isbn } });
      if (!existing) {
        stats.notInCatalog += 1;
        missing.push(`${isbn} ${scraped.title || ''}`);
        continue;
      }

      // ---- coperta ----
      let coverUrl = existing.coverUrl;
      const localCover = findCoverFile(isbn);
      if (localCover) {
        if (!DRY_RUN) {
          const webp = await sharp(fs.readFileSync(localCover))
            .resize(MAX_DIMENSION, MAX_DIMENSION, {
              fit: 'inside',
              withoutEnlargement: true,
            })
            .webp({ quality: WEBP_QUALITY })
            .toBuffer();

          const key = `book-covers/${isbn}.webp`;
          await minio.putObject(bucket, key, webp, webp.length, {
            'Content-Type': 'image/webp',
          });
          coverUrl = `${publicBaseUrl}/${key}`;
        }
        stats.coversUploaded += 1;
      } else {
        // Fără fișier local cade pe URL-ul scrapuit DOAR dacă e utilizabil,
        // apoi pe ce era deja - vezi usableCoverUrl.
        coverUrl = usableCoverUrl(scraped.coverUrl) || existing.coverUrl;
        stats.coversMissing += 1;
      }

      // ---- metadate ----
      const data = {
        title: pick(scraped.title, existing.title),
        author: pick(scraped.author, existing.author),
        description: pick(scraped.description, existing.description),
        publisher: pick(scraped.publisher, existing.publisher),
        publishedYear: pick(scraped.publishedYear, existing.publishedYear),
        pageCount: pick(scraped.pageCount, existing.pageCount),
        language: pick(scraped.language, existing.language),
        coverUrl,
        curatedAt: new Date(),
      };

      if (!DRY_RUN) {
        await prisma.book.update({ where: { id: existing.id }, data });
      }
      stats.updated += 1;
    } catch (error) {
      stats.failed += 1;
      console.error(`  ! ${isbn}: ${error.message}`);
    }

    if ((index + 1) % 200 === 0) {
      console.log(`  ...${index + 1}/${books.length}`);
    }
  }

  console.log('\n--- rezultat ---');
  console.log(`  actualizate:        ${stats.updated}`);
  console.log(`  coperți urcate:     ${stats.coversUploaded}`);
  console.log(`  fără fișier local:  ${stats.coversMissing}`);
  console.log(`  lipsă din catalog:  ${stats.notInCatalog}`);
  console.log(`  eșuate:             ${stats.failed}`);
  if (missing.length) {
    console.log('\nNu există în `books` (nu se creează de aici):');
    missing.slice(0, 20).forEach((m) => console.log(`  ${m}`));
    if (missing.length > 20) console.log(`  ... și încă ${missing.length - 20}`);
  }

  await prisma.$disconnect();
}

/** Scrape-ul salvează când .jpg, când .jpeg - le acceptăm pe amândouă. */
function findCoverFile(isbn) {
  for (const ext of ['.jpg', '.jpeg', '.webp', '.png']) {
    const candidate = path.join(COVERS_DIR, `${isbn}${ext}`);
    if (fs.existsSync(candidate)) return candidate;
  }
  return null;
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
