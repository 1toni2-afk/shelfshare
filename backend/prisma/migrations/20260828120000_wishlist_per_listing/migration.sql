-- Favorite pe ANUNT, nu pe titlu: daca aceeasi carte e listata de trei useri,
-- inima apasata pe anuntul unuia nu mai trebuie sa apara aprinsa si pe
-- celelalte doua. Randul de wishlist retine acum anuntul de pe care a fost
-- apasata inima; NULL ramane "vreau titlul, de la oricine" (Book Match, sau
-- anunt sters intre timp).

-- AlterTable
ALTER TABLE "wishlist_items" ADD COLUMN "userBookId" TEXT;

-- AddForeignKey
ALTER TABLE "wishlist_items" ADD CONSTRAINT "wishlist_items_userBookId_fkey"
  FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- DropIndex: unicitatea (user, carte) ar bloca al doilea anunt al aceluiasi titlu.
DROP INDEX IF EXISTS "wishlist_items_userId_bookId_key";

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_items_userId_bookId_userBookId_key"
  ON "wishlist_items"("userId", "bookId", "userBookId");
CREATE INDEX "wishlist_items_userId_bookId_idx" ON "wishlist_items"("userId", "bookId");

-- Backfill: favoritele existente sunt legate de titlu, nu de un anunt anume.
-- Acolo unde titlul are un SINGUR anunt activ, ancorarea e neambigua, deci o
-- facem automat - restul raman la nivel de titlu (comportamentul de dinainte)
-- pana cand userul apasa din nou inima pe anuntul dorit.
UPDATE "wishlist_items" w
SET "userBookId" = single."id"
FROM (
  SELECT "bookId", MIN("id") AS "id"
  FROM "user_books"
  WHERE "deletedAt" IS NULL AND "permanentlyTransferred" = false
  GROUP BY "bookId"
  HAVING COUNT(*) = 1
) AS single
WHERE w."bookId" = single."bookId" AND w."source" = 'PERSONAL';
