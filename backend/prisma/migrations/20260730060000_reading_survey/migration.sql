-- Milestone 12: profilul de cititor completat la primul login. Alimentează
-- recomandările și notificarea „carte nouă pe gustul tău".
--
-- Genurile și autorii sunt liste de text, nu enum-uri sau tabele separate:
-- valorile de gen din `books` vin din surse externe (OpenLibrary, Google Books)
-- și nu se încadrează într-un set închis, iar potrivirea se face oricum prin
-- comparație directă cu `books.genre`.
--
-- DEFAULT '{}' (nu NULL) ca query-urile de potrivire să nu fie nevoite să
-- trateze separat cazul „user fără preferințe setate".
ALTER TABLE "users"
  ADD COLUMN "favoriteGenres"  TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN "favoriteAuthors" TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN "readingPace"     TEXT,
  ADD COLUMN "readingSurveyCompletedAt" TIMESTAMP(3);

-- Index GIN pe genuri: notificarea „carte nouă pe gustul tău" caută, la fiecare
-- carte listată, toți userii care au genul respectiv între preferințe. Fără
-- index, fiecare listare ar scana tot tabelul de useri.
CREATE INDEX "users_favoriteGenres_idx" ON "users" USING GIN ("favoriteGenres");

-- Tipul de notificare trimis când se listează o carte dintr-un gen preferat.
-- Separat de NEARBY_BOOK_LISTED (care merge pe oraș) ca userul să poată
-- distinge „lângă tine" de „pe gustul tău".
ALTER TYPE "NotificationType" ADD VALUE 'INTEREST_BOOK_LISTED';
