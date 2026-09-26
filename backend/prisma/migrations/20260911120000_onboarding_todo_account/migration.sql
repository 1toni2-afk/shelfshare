-- Lista „Primii pași" trece de pe dispozitiv pe cont.
--
-- Numele tabelei e cel din @@map ("users"), NU numele modelului Prisma.
--
-- ORDINEA de deploy: migrarea e retro-compatibilă - ambele coloane au
-- DEFAULT, deci codul vechi aflat în rulare (care nu le cunoaște) continuă să
-- insereze useri fără să le menționeze. Se poate aplica ÎNAINTE de a porni
-- codul nou.

ALTER TABLE "users"
    ADD COLUMN IF NOT EXISTS "onboardingTodoDone" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN IF NOT EXISTS "onboardingTodoDismissed" BOOLEAN NOT NULL DEFAULT false;
