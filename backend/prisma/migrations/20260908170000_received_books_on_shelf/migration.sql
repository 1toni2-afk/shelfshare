-- Cartea primită printr-un schimb sau o vânzare ajunge de acum și în raftul
-- personal al noului proprietar, ca deținută - exact ca una adăugată manual
-- prin „Add a book" > „Add to shelf" (vezi transferListingOwnership). Fără
-- intrarea asta, exemplarul primit exista doar ca anunț nelistat, iar de când
-- anunțurile nelistate primite nu mai apar în grila de listări (getMyLibrary)
-- cartea n-ar mai apărea nicăieri în My Shelf.
--
-- Aici recuperăm transferurile deja făcute: fiecare exemplar primit
-- (`previousListingId` setat) și încă nescos în piață primește o intrare de
-- raft „vreau să citesc", deținută. Dacă userul avea deja cartea pe raft, nu
-- îi rescriem statusul - doar o marcăm ca deținută.
INSERT INTO "bookshelf_entries" ("id", "userId", "bookId", "status", "owned", "createdAt", "updatedAt")
SELECT DISTINCT ON (ub."userId", ub."bookId")
  gen_random_uuid()::text, ub."userId", ub."bookId",
  'WANT_TO_READ'::"BookshelfStatus", true,
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "user_books" ub
WHERE ub."previousListingId" IS NOT NULL
  AND ub."deletedAt" IS NULL
  AND ub."availableForSwap" = false
  AND ub."isForSale" = false
  AND ub."isAuction" = false
ON CONFLICT ("userId", "bookId") DO UPDATE SET "owned" = true;
