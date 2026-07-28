-- Descriere per anunț (Milestone 10 + share form). Book.description e a
-- „operei" (partajată între useri), iar user cerea un câmp editabil pe
-- exemplarul propriu - stare, note, ce e inclus, etc. Max 256 char validat
-- în DTO; DB nu are constraint pentru că vrem să putem crește limita fără
-- migrație.
ALTER TABLE "user_books"
  ADD COLUMN "description" TEXT;
