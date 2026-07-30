/**
 * Normalizează un nume de persoană la „Prima Literă Mare", fiindcă mulți îl
 * scriu integral cu litere mici la înregistrare („ion popescu").
 *
 * Reguli:
 * - se păstrează separatorii compuși („ana-maria" → „Ana-Maria", „o'neil" →
 *   „O'Neil"), nu doar spațiile;
 * - un cuvânt care conține deja o majusculă e lăsat neatins, ca să nu stricăm
 *   forme scrise intenționat („McDonald", „van der Berg" rămân cum au fost);
 * - spațiile multiple se colapsează, iar cele de la capete se taie.
 */
export function capitalizeName(name: string): string {
  return name
    .trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .map((word) =>
      word
        .split(/([-'’])/)
        .map((part) =>
          // Are deja o majusculă undeva → autorul a vrut forma asta.
          /\p{Lu}/u.test(part)
            ? part
            : part.charAt(0).toLocaleUpperCase('ro-RO') + part.slice(1),
        )
        .join(''),
    )
    .join(' ');
}
