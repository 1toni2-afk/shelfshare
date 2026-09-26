import { applyDecorators } from '@nestjs/common';
import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

/**
 * Identificatorul unei cărți din CATALOG (`Book.id`).
 *
 * De ce nu `@IsUUID()`, deși coloana are `@default(uuid())`: valoarea implicită
 * se aplică doar când nu dăm noi una. Cărțile nu intră în catalog doar prin
 * aplicație - vin din importuri, din scraperul de librării și din seed-uri,
 * care scriu `id`-ul explicit, cu cheia sursei. În baza de test, 40 din 52 de
 * cărți au un id care nu e UUID.
 *
 * Consecința era vizibilă: inima de favorite răspundea „bookId must be a UUID"
 * pentru majoritatea cărților, iar cartea exista perfect în catalog. Validarea
 * respingea un identificator corect doar fiindcă nu avea forma pe care schema
 * nu o garantează nicăieri.
 *
 * Existența o verifică oricum serviciul, cu un `findUnique` care întoarce 404 -
 * deci aici rămâne doar ce ne protejează cu adevărat: un șir nevid, cu o limită
 * de lungime.
 *
 * Pentru id-uri pe care le generează DOAR aplicația (utilizatori, conversații,
 * anunțuri) `@IsUUID()` rămâne corect: acolo forma chiar e garantată.
 */
export function IsCatalogId() {
  return applyDecorators(IsString(), IsNotEmpty(), MaxLength(64));
}
