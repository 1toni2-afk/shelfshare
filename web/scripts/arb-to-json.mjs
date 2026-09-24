/**
 * Convertește fișierele .arb ale aplicației Flutter în JSON pentru i18next.
 *
 * De ce nu copiem pur și simplu traducerile o dată și gata: cât timp cele două
 * frontenduri coexistă (Flutter pe shelfshare.ro, ăsta pe beta), orice text
 * nou se adaugă tot în .arb, pentru că aplicația live trebuie să-l primească.
 * Dacă am ține două seturi paralele, ar diverge de la primul string adăugat -
 * și sunt 2297 de chei x 4 limbi, adică nimeni nu observă divergența la timp.
 * Rulează automat înaintea fiecărui `dev` și `build` (vezi package.json).
 *
 * ARB e deja ICU, iar i18next citește ICU prin pluginul i18next-icu, deci
 * valorile trec neatinse: `{name}`, `{count, plural, ...}` și `{x, select, ...}`
 * funcționează fără rescriere. Singura curățenie e scoaterea intrărilor de
 * metadate, care în ARB sunt chei surori prefixate cu `@`.
 */
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const arbDir = join(here, '..', '..', 'frontend', 'lib', 'l10n');
const outDir = join(here, '..', 'src', 'lib', 'i18n', 'locales');

const arbFiles = readdirSync(arbDir).filter((f) => /^app_[a-z]{2}\.arb$/.test(f));

if (arbFiles.length === 0) {
  console.error(`[i18n] Niciun fisier .arb gasit in ${arbDir}`);
  process.exit(1);
}

mkdirSync(outDir, { recursive: true });

const locales = [];
let total = 0;

for (const file of arbFiles) {
  const locale = file.slice('app_'.length, -'.arb'.length);
  // `replace(/^﻿/, '')`: fisierele .arb sunt salvate cu BOM (vezi
  // .gitattributes), iar JSON.parse refuza BOM-ul ca prim caracter.
  const raw = readFileSync(join(arbDir, file), 'utf8').replace(/^﻿/, '');
  const source = JSON.parse(raw);

  const messages = {};
  for (const [key, value] of Object.entries(source)) {
    // `@@locale`, `@@last_modified` si `@cheie` (metadatele fiecarui mesaj).
    if (key.startsWith('@')) continue;
    if (typeof value !== 'string') continue;
    messages[key] = value;
  }

  const count = Object.keys(messages).length;
  total += count;
  locales.push({ locale, count });

  writeFileSync(
    join(outDir, `${locale}.json`),
    JSON.stringify(messages, null, 2) + '\n',
    'utf8',
  );
}

// Indexul e generat, nu scris de mana: o limba noua inseamna doar un .arb nou
// in Flutter, iar aici apare singura la urmatorul build.
//
// Import DINAMIC, nu static. Cele patru limbi inseamna ~340 kB de JSON; cu
// `import x from './ro.json'` ajungeau toate in chunk-ul principal, adica
// fiecare user descarca si cele trei limbi pe care nu le vorbeste inainte sa
// vada ecranul de login. Asa, Vite face cate un fisier separat si se aduce
// doar limba activa (plus romana ca fallback).
const loaders = locales
  .map(({ locale }) => `  ${locale}: () => import('./${locale}.json'),`)
  .join('\n');

writeFileSync(
  join(outDir, 'index.ts'),
  `// GENERAT de scripts/arb-to-json.mjs - nu edita manual.
// Sursa de adevar sunt fisierele frontend/lib/l10n/app_*.arb.
export type Messages = Record<string, string>;

export const loaders = {
${loaders}
} satisfies Record<string, () => Promise<{ default: Messages }>>;

export type AppLocale = keyof typeof loaders;
export const SUPPORTED_LOCALES = Object.keys(loaders) as AppLocale[];

export async function loadMessages(locale: AppLocale): Promise<Messages> {
  return (await loaders[locale]()).default;
}
`,
  'utf8',
);

const summary = locales.map(({ locale, count }) => `${locale}:${count}`).join('  ');
console.log(`[i18n] ${locales.length} limbi, ${total} chei  (${summary})`);

// Un .arb care a ramas in urma nu e o eroare de build, dar trebuie sa se vada:
// altfel textele netraduse apar direct in UI-ul de beta fara ca nimeni sa stie.
const [reference] = locales.sort((a, b) => b.count - a.count);
for (const { locale, count } of locales) {
  if (count < reference.count) {
    console.warn(
      `[i18n] ${locale} are ${reference.count - count} chei mai putin decat ${reference.locale}`,
    );
  }
}
