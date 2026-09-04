-- Preferințe de notificare per user și per tip + tipul nou de notificare
-- „un user pe care îl urmărești a terminat o carte".
--
-- Numele tabelei e cel din @@map ("notification_preferences"), NU numele
-- modelului Prisma - vezi migrarea unified_reports pentru ce se întâmplă
-- altfel.
--
-- ORDINEA de deploy: migrarea asta e retro-compatibilă (adaugă o tabelă nouă
-- și o valoare nouă de enum, nu atinge nimic existent), deci se poate aplica
-- ÎNAINTE de a porni codul nou, fără să strice codul vechi aflat în rulare.

ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'FOLLOWED_USER_FINISHED_BOOK';

CREATE TABLE IF NOT EXISTS "notification_preferences" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "type" "NotificationType" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "notification_preferences_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "notification_preferences_userId_type_key"
    ON "notification_preferences" ("userId", "type");

ALTER TABLE "notification_preferences"
    ADD CONSTRAINT "notification_preferences_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users" ("id")
    ON DELETE CASCADE ON UPDATE CASCADE;
