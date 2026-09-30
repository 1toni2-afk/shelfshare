/**
 * Curățarea valorilor care vin dintr-un CSV încărcat de user.
 *
 * Importul scrie direct în Prisma, deci NU trece prin validarea din AddBookDto
 * (MaxLength, IsISBN). Fără limitele de aici, un singur rând putea pune în
 * catalogul comun un titlu de câțiva MB sau un „ISBN" de forma
 * `=HYPERLINK(...)`, iar titlurile ajung în notificări push, în exportul CSV
 * al altor useri și în fișierele .ics.
 */

/** Aceleași plafoane ca în AddBookDto, ca un rând importat să nu poată ce nu poate formularul. */
export const IMPORT_TEXT_LIMITS = {
  title: 300,
  author: 200,
  publisher: 200,
  language: 10,
  city: 100,
  description: 256,
} as const;

// Caractere de control (fără tab/newline, tratate separat) și suprascrierile
// de direcție Unicode: un titlu cu U+202E se afișează inversat, deci poate
// ascunde alt text decât cel pe care îl vede cine citește notificarea.
// eslint-disable-next-line no-control-regex
const CONTROL_CHARS = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F‪-‮⁦-⁩]/g;

/**
 * Un câmp text dintr-un rând de import: fără caractere de control, cu spațiile
 * albe compactate (sau doar liniile păstrate, pentru descrieri), tăiat la
 * plafonul formularului. Valoarea goală devine `null`, ca în `csvValue`.
 *
 * Exportul din „Cărțile mele" pune un apostrof în fața valorilor care încep cu
 * `=`, `+`, `-` sau `@` (altfel Excel le rulează ca formule); îl scoatem aici,
 * ca un fișier exportat să se reimporte identic.
 */
export function cleanImportText(
  raw: string | null | undefined,
  maxLength: number,
  options: { multiline?: boolean } = {},
): string | null {
  if (!raw) return null;
  let value = raw.replace(CONTROL_CHARS, '').replace(/^'(?=[=+\-@\t\r])/, '');
  value = options.multiline
    ? value
        .replace(/\r\n?/g, '\n')
        .replace(/[ \t]+/g, ' ')
        .replace(/\n{3,}/g, '\n\n')
    : value.replace(/\s+/g, ' ');
  value = value.trim();
  if (!value) return null;
  return value.length > maxLength ? value.slice(0, maxLength).trimEnd() : value;
}

/**
 * ISBN-ul dintr-un rând de import, sau `undefined` dacă nu e unul valid.
 *
 * Goodreads înfășoară ISBN-urile într-o pseudo-formulă Excel (`="0143039954"`),
 * ca Excel/Sheets să nu le trunchieze ca numere, iar o carte fără ISBN
 * primește `=""` - un șir NEGOL. Fără curățare ajungeau în catalog ISBN-uri
 * literale `="0143039954"`, iar toate rândurile fără ISBN se dedublau între ele
 * pe același `=""`.
 *
 * Cifra de control e verificată, la fel ca `@IsISBN` din formular: fără ea,
 * orice șir de 9-13 cifre putea ocupa un ISBN în catalogul comun.
 */
export function cleanImportIsbn(
  raw: string | null | undefined,
): string | undefined {
  if (!raw) return undefined;
  const stripped = raw
    .replace(/^="?/, '')
    .replace(/"$/, '')
    .replace(/[-\s]/g, '')
    .toUpperCase();
  return isValidIsbn(stripped) ? stripped : undefined;
}

function isValidIsbn(value: string): boolean {
  // SBN-urile de 9 cifre (dinainte de 1970) sunt ISBN-10 fără zeroul din față.
  if (/^\d{9}$/.test(value)) return isValidIsbn10(`0${value}`);
  if (/^\d{9}[\dX]$/.test(value)) return isValidIsbn10(value);
  if (/^\d{13}$/.test(value)) return isValidIsbn13(value);
  return false;
}

function isValidIsbn10(value: string): boolean {
  let sum = 0;
  for (let i = 0; i < 10; i++) {
    const digit = value[i] === 'X' ? 10 : Number(value[i]);
    sum += digit * (10 - i);
  }
  return sum % 11 === 0;
}

function isValidIsbn13(value: string): boolean {
  let sum = 0;
  for (let i = 0; i < 13; i++) {
    sum += Number(value[i]) * (i % 2 === 0 ? 1 : 3);
  }
  return sum % 10 === 0;
}
