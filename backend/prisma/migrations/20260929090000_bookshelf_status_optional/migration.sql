-- My Shelf pe categorii care se suprapun (Deținute / Citite / De citit /
-- Listate): o carte poate fi doar deținută, fără status de lectură.
-- Compatibil cu codul vechi: el scrie mereu un status, iar citirile lui
-- filtrează după o valoare anume, deci un NULL pur și simplu nu apare.
ALTER TABLE "bookshelf_entries" ALTER COLUMN "status" DROP NOT NULL;
