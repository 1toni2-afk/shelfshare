-- Pre-înscriere pentru lansarea Android: un email opt-in per rând, cu
-- deduplicare pe (email lower-case). userId opțional pentru cazul când
-- pre-registrarea vine de la un user deja logat - putem trimite anunțul
-- de lansare doar celor care nu au deja aplicația.
CREATE TABLE "pre_registrations" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "email" TEXT NOT NULL,
  "emailLower" TEXT NOT NULL,
  "userId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "pre_registrations_pkey" PRIMARY KEY ("id")
);

-- Un email = o pre-înscriere. emailLower e pentru deduplicarea case-
-- insensitive, altfel „X@YAHOO.com" și „x@yahoo.com" ar apărea de două ori.
CREATE UNIQUE INDEX "pre_registrations_emailLower_key"
  ON "pre_registrations" ("emailLower");
