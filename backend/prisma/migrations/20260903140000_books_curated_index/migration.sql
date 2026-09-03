-- Book Match servește acum din catalogul PROPRIU, verificat manual, nu dintr-un
-- eșantion orb din cele 3,68M de rânduri importate în vrac din Open Library
-- (vezi BookMatchService.curatedCandidates).
--
-- Fără index, `WHERE "curatedAt" IS NOT NULL` e un seq scan pe toată tabela -
-- măsurat 920ms, adică aproape o secundă adăugată la FIECARE cerere de coadă.
--
-- Index PARȚIAL, nu btree pe toată coloana: doar ~1900 din 3,68M de rânduri au
-- `curatedAt`, deci indexul are câteva zeci de KB în loc de zeci de MB. Nu e
-- declarat în schema.prisma fiindcă Prisma nu poate exprima indexuri parțiale
-- (la fel ca `books_search_fts_idx` din migrarea books_diacritic_search).
--
-- Predicatul trebuie să fie IDENTIC cu cel din interogare, altfel planner-ul
-- nu poate folosi indexul.
CREATE INDEX IF NOT EXISTS "books_curated_idx" ON "books" ("curatedAt")
WHERE "curatedAt" IS NOT NULL;
