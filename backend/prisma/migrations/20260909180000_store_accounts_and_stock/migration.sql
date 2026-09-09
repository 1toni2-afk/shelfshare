-- Conturi de anticariat/librărie + stoc pe anunț (integrări cu magazinele).
--
-- Numele tabelelor sunt cele din @@map ("users", "user_books"), NU numele
-- modelelor Prisma.
--
-- ORDINEA de deploy: totul e retro-compatibil (coloane noi cu default, tabelă
-- nouă, index unic care nu poate fi încălcat de datele existente fiindcă
-- "sku" e NULL peste tot), deci migrarea se aplică ÎNAINTE de pornirea
-- codului nou. Codul vechi nu știe de coloane și continuă să funcționeze.

-- 1. Flag-ul de cont de magazin, acordat manual de un super-admin.
ALTER TABLE "users" ADD COLUMN "isStore" BOOLEAN NOT NULL DEFAULT false;

-- 2. Datele publice ale magazinului (nume comercial, program, livrare).
CREATE TABLE "store_profiles" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "description" TEXT,
    "address" TEXT,
    "city" TEXT,
    "website" TEXT,
    "phone" TEXT,
    "openingHours" TEXT,
    "deliveryPolicy" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "store_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "store_profiles_userId_key" ON "store_profiles"("userId");

ALTER TABLE "store_profiles"
    ADD CONSTRAINT "store_profiles_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

-- 3. Stoc + cod intern pe anunț. `stockQuantity` are default 1: un anunț
-- obișnuit e un singur exemplar, deci nimic nu se schimbă pentru useri.
ALTER TABLE "user_books" ADD COLUMN "sku" TEXT;
ALTER TABLE "user_books" ADD COLUMN "stockQuantity" INTEGER NOT NULL DEFAULT 1;

-- Cheia de idempotență a importului de stoc. NULL-urile sunt distincte în
-- Postgres, deci rândurile existente (toate cu "sku" NULL) trec fără conflict.
CREATE UNIQUE INDEX "user_books_userId_sku_key" ON "user_books"("userId", "sku");
