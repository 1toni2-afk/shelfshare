-- Cereri de carte („nu găsesc cartea") + tipul de notificare trimis când una
-- e găsită de căutarea de noapte.
--
-- Numele tabelei e cel din @@map ("book_requests"), la fel referințele către
-- "users" și "books" - NU numele modelelor Prisma.
--
-- ORDINEA de deploy: migrarea e retro-compatibilă (tabelă nouă + două tipuri
-- noi, nimic existent atins), deci se aplică ÎNAINTE de pornirea codului nou.
-- Codul vechi aflat în rulare nu vede nimic schimbat.

ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'BOOK_REQUEST_FOUND';

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'BookRequestStatus') THEN
        CREATE TYPE "BookRequestStatus" AS ENUM ('PENDING', 'FULFILLED', 'NOT_FOUND', 'CANCELLED');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS "book_requests" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "author" TEXT,
    "isbn" TEXT,
    "note" TEXT,
    "normalizedKey" TEXT NOT NULL,
    "status" "BookRequestStatus" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "lastAttemptAt" TIMESTAMP(3),
    "resolvedSource" TEXT,
    "bookId" TEXT,
    "fulfilledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "book_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "book_requests_userId_normalizedKey_key"
    ON "book_requests" ("userId", "normalizedKey");

-- Coada de noapte citește exact „PENDING, cele mai vechi întâi".
CREATE INDEX IF NOT EXISTS "book_requests_status_createdAt_idx"
    ON "book_requests" ("status", "createdAt");

ALTER TABLE "book_requests"
    ADD CONSTRAINT "book_requests_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- SET NULL, nu CASCADE: dacă o carte dispare din catalog, cererea rămâne
-- (redevine o cerere fără rezultat), nu se șterge istoricul userului.
ALTER TABLE "book_requests"
    ADD CONSTRAINT "book_requests_bookId_fkey"
    FOREIGN KEY ("bookId") REFERENCES "books" ("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
