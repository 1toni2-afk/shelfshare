-- Cărți deținute dar nelistate ("My Shelf" - prim-plan) + numărul de pagini
-- al ediției proprii, când diferă de cea din catalog.
ALTER TABLE "bookshelf_entries" ADD COLUMN "owned" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "reading_progress" ADD COLUMN "totalPages" INTEGER;

-- Intrările existente cu progres de citit sunt, practic sigur, cărți pe care
-- userul le are în mână - le marcăm ca deținute ca să nu dispară din noul
-- prim-plan al raftului.
UPDATE "bookshelf_entries" e
SET "owned" = true
WHERE EXISTS (
  SELECT 1 FROM "reading_progress" p
  WHERE p."userId" = e."userId" AND p."bookId" = e."bookId"
);
