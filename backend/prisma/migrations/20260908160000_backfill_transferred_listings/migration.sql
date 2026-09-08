-- Cărțile schimbate/vândute până acum au rămas, ca exemplar, doar la cel care
-- le-a dat mai departe: la finalizare marcam anunțul cu `permanentlyTransferred`
-- și atât, iar cel care primea cartea nu avea nimic în bibliotecă până când nu
-- apăsa manual „re-listează". De acum transferul se face automat (vezi
-- transferListingOwnership), iar anunțul transferat nu mai apare în biblioteca
-- activă a fostului proprietar - deci pentru schimburile deja finalizate
-- trebuie creat aici, o singură dată, exemplarul noului proprietar.
--
-- Copia e nelistată (nici schimb, nici vânzare, nici licitație): ce face cu ea
-- mai departe decide noul proprietar. `previousListingId` păstrează lanțul de
-- proveniență, iar `NOT EXISTS` face migrarea sigură la re-rulare și
-- compatibilă cu re-listările făcute deja manual.

-- 1. Cartea cerută -> cel care a cerut schimbul.
INSERT INTO "user_books" (
  "id", "userId", "bookId", "condition", "language", "edition", "isHardcover",
  "availableForSwap", "isForSale", "isAuction", "isPromoted", "photos",
  "mainPhotoUrl", "description", "tags", "city", "previousListingId",
  "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::text, e."requesterId", ub."bookId", ub."condition",
  ub."language", ub."edition", ub."isHardcover",
  false, false, false, false, ub."photos",
  ub."mainPhotoUrl", ub."description", ub."tags", ub."city", ub."id",
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "exchange_requests" e
JOIN "user_books" ub ON ub."id" = e."requestedBookId"
WHERE e."status" = 'COMPLETED'
  AND ub."userId" <> e."requesterId"
  AND NOT EXISTS (
    SELECT 1 FROM "user_books" x
    WHERE x."previousListingId" = ub."id" AND x."userId" = e."requesterId"
  );

-- 2. Cartea oferită -> proprietarul anunțului cerut.
INSERT INTO "user_books" (
  "id", "userId", "bookId", "condition", "language", "edition", "isHardcover",
  "availableForSwap", "isForSale", "isAuction", "isPromoted", "photos",
  "mainPhotoUrl", "description", "tags", "city", "previousListingId",
  "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::text, e."ownerId", ub."bookId", ub."condition",
  ub."language", ub."edition", ub."isHardcover",
  false, false, false, false, ub."photos",
  ub."mainPhotoUrl", ub."description", ub."tags", ub."city", ub."id",
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "exchange_requests" e
JOIN "user_books" ub ON ub."id" = e."offeredBookId"
WHERE e."status" = 'COMPLETED'
  AND ub."userId" <> e."ownerId"
  AND NOT EXISTS (
    SELECT 1 FROM "user_books" x
    WHERE x."previousListingId" = ub."id" AND x."userId" = e."ownerId"
  );

-- 3. Cărțile din bundle (oferta extinsă) -> tot proprietarul anunțului cerut.
INSERT INTO "user_books" (
  "id", "userId", "bookId", "condition", "language", "edition", "isHardcover",
  "availableForSwap", "isForSale", "isAuction", "isPromoted", "photos",
  "mainPhotoUrl", "description", "tags", "city", "previousListingId",
  "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::text, e."ownerId", ub."bookId", ub."condition",
  ub."language", ub."edition", ub."isHardcover",
  false, false, false, false, ub."photos",
  ub."mainPhotoUrl", ub."description", ub."tags", ub."city", ub."id",
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "exchange_bundle_books" bb
JOIN "exchange_requests" e ON e."id" = bb."exchangeRequestId"
JOIN "user_books" ub ON ub."id" = bb."userBookId"
WHERE e."status" = 'COMPLETED'
  AND ub."userId" <> e."ownerId"
  AND NOT EXISTS (
    SELECT 1 FROM "user_books" x
    WHERE x."previousListingId" = ub."id" AND x."userId" = e."ownerId"
  );

-- 4. Vânzările finalizate -> cumpărătorul.
INSERT INTO "user_books" (
  "id", "userId", "bookId", "condition", "language", "edition", "isHardcover",
  "availableForSwap", "isForSale", "isAuction", "isPromoted", "photos",
  "mainPhotoUrl", "description", "tags", "city", "previousListingId",
  "createdAt", "updatedAt"
)
SELECT
  gen_random_uuid()::text, o."buyerId", ub."bookId", ub."condition",
  ub."language", ub."edition", ub."isHardcover",
  false, false, false, false, ub."photos",
  ub."mainPhotoUrl", ub."description", ub."tags", ub."city", ub."id",
  CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "price_offers" o
JOIN "user_books" ub ON ub."id" = o."userBookId"
WHERE o."status" = 'COMPLETED'
  AND ub."userId" <> o."buyerId"
  AND NOT EXISTS (
    SELECT 1 FROM "user_books" x
    WHERE x."previousListingId" = ub."id" AND x."userId" = o."buyerId"
  );

-- Anunțurile transferate nu mai au ce căuta în piață.
UPDATE "user_books"
SET "availableForSwap" = false, "isForSale" = false, "isPromoted" = false
WHERE "permanentlyTransferred" = true
  AND ("availableForSwap" = true OR "isForSale" = true OR "isPromoted" = true);
