-- Emailul de bun venit trimis la 3 zile după înregistrare (vezi
-- WelcomeEmailService): marcăm pe user MOMENTUL trimiterii, ca un al doilea
-- email să nu plece niciodată, indiferent de câte ori rulează cronul.
--
-- Numele tabelei e cel din @@map ("users"), NU numele modelului Prisma.
--
-- ORDINEA de deploy: coloana e nullable, deci codul vechi aflat în rulare
-- (care nu o cunoaște) inserează useri fără să o menționeze. Se poate aplica
-- ÎNAINTE de a porni codul nou.
--
-- Backfill: conturile existente la momentul migrării primesc `now()`, adică
-- „deja tratat". Fără asta, la prima rulare a cronului ar pleca emailul de
-- bun venit către ÎNTREAGA bază de useri deodată - useri vechi de luni de
-- zile ar primi „mulțumim că te-ai înregistrat". Serviciul are și o a doua
-- plasă de siguranță (nu trimite conturilor mai vechi de 14 zile), dar
-- backfill-ul e cel care garantează.

ALTER TABLE "users"
    ADD COLUMN IF NOT EXISTS "welcomeEmailSentAt" TIMESTAMP(3);

UPDATE "users" SET "welcomeEmailSentAt" = now() WHERE "welcomeEmailSentAt" IS NULL;
