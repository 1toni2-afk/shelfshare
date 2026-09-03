-- Sistem unificat de rapoarte.
--
-- `Report` era deja UN singur model, dar tot ce ținea de „aceeași țintă" se
-- putea exprima doar prin una din cheile străine tipate (userBook /
-- conversation / groupPost / review), deci nu se putea nici număra, nici
-- deduplica, nici filtra uniform. Adăugăm perechea (targetType, targetId)
-- PE LÂNGĂ chei, nu în locul lor: cheile păstrează integritatea referențială
-- și ștergerea în cascadă, iar perechea face posibile cele două reguli noi -
-- „un user raportează o țintă o singură dată" și auto-hide pe praguri.

-- Motive noi. Lista rămâne una singură în baza de date; ce se OFERĂ userului
-- diferă după tipul țintei (vezi REPORT_REASONS_BY_TARGET în cod).
ALTER TYPE "ReportReason" ADD VALUE IF NOT EXISTS 'ABUSIVE_LANGUAGE';
ALTER TYPE "ReportReason" ADD VALUE IF NOT EXISTS 'FALSE_CONTENT';
ALTER TYPE "ReportReason" ADD VALUE IF NOT EXISTS 'FAKE_PROFILE';

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'ReportTargetType') THEN
    CREATE TYPE "ReportTargetType" AS ENUM (
      'USER', 'LISTING', 'REVIEW', 'CONVERSATION', 'GROUP_POST', 'EXCHANGE'
    );
  END IF;
END
$$;

-- Adăugate nullable, completate din cheile existente, abia apoi făcute NOT
-- NULL: coloane NOT NULL fără default pe o tabelă cu rânduri ar fi picat.
ALTER TABLE "reports" ADD COLUMN IF NOT EXISTS "targetType" "ReportTargetType";
ALTER TABLE "reports" ADD COLUMN IF NOT EXISTS "targetId" TEXT;

-- Precedența contează: un raport are mereu `reportedUserId`, plus cel mult una
-- dintre celelalte chei. Cea mai specifică cheie prezentă dă ținta; dacă nu e
-- niciuna, raportul e despre user.
UPDATE "reports" SET
  "targetType" = CASE
    WHEN "reviewId"       IS NOT NULL THEN 'REVIEW'::"ReportTargetType"
    WHEN "groupPostId"    IS NOT NULL THEN 'GROUP_POST'::"ReportTargetType"
    WHEN "conversationId" IS NOT NULL THEN 'CONVERSATION'::"ReportTargetType"
    WHEN "userBookId"     IS NOT NULL THEN 'LISTING'::"ReportTargetType"
    ELSE 'USER'::"ReportTargetType"
  END,
  "targetId" = COALESCE("reviewId", "groupPostId", "conversationId", "userBookId", "reportedUserId")
WHERE "targetType" IS NULL;

ALTER TABLE "reports" ALTER COLUMN "targetType" SET NOT NULL;
ALTER TABLE "reports" ALTER COLUMN "targetId" SET NOT NULL;

-- Regula „un raport per user per țintă" se aplică de acum înainte, dar datele
-- vechi pot avea deja duplicate (nimic nu le împiedica). Le curățăm păstrând
-- raportul cel mai vechi - e cel pe care un moderator l-ar fi văzut oricum
-- primul - altfel indexul unic de mai jos n-ar putea fi creat.
DELETE FROM "reports" r
USING "reports" keep
WHERE r."reporterId" = keep."reporterId"
  AND r."targetType" = keep."targetType"
  AND r."targetId"   = keep."targetId"
  AND (r."createdAt" > keep."createdAt"
       OR (r."createdAt" = keep."createdAt" AND r."id" > keep."id"));

CREATE UNIQUE INDEX IF NOT EXISTS "reports_reporterId_targetType_targetId_key"
  ON "reports" ("reporterId", "targetType", "targetId");

-- Pragurile de auto-hide numără rapoartele pe aceeași țintă într-o fereastră
-- de timp; fără indexul ăsta, fiecare raport nou ar scana toată tabela.
CREATE INDEX IF NOT EXISTS "reports_targetType_targetId_createdAt_idx"
  ON "reports" ("targetType", "targetId", "createdAt");

-- Auto-hide: conținutul rămâne în baza de date (moderatorul trebuie să-l
-- poată judeca, iar decizia trebuie să fie reversibilă), doar că iese din
-- fluxurile publice. Distinct de `deletedAt` de pe anunțuri, care e decizia
-- proprietarului, nu a moderării.
ALTER TABLE "reviews"     ADD COLUMN IF NOT EXISTS "hiddenAt" TIMESTAMP(3);
ALTER TABLE "group_posts" ADD COLUMN IF NOT EXISTS "hiddenAt" TIMESTAMP(3);
ALTER TABLE "user_books"  ADD COLUMN IF NOT EXISTS "hiddenAt" TIMESTAMP(3);
