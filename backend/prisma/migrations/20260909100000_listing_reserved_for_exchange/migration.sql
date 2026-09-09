-- Un schimb ACCEPTAT nu mai stinge anunțul: cartea rămâne listată, marcată
-- „schimb în curs", până la finalizare. Coloana ține id-ul schimbului care a
-- rezervat exemplarul și e totodată lacătul de concurență la acceptare.
--
-- Numele tabelei e cel din @@map ("user_books"), NU numele modelului Prisma.
--
-- ORDINEA de deploy: retro-compatibilă (coloană nouă, nullable, fără
-- default), deci se aplică ÎNAINTE de pornirea codului nou. Codul vechi nu
-- știe de coloană; anunțurile repuse de UPDATE-urile de mai jos îi apar pur
-- și simplu ca disponibile, adică exact comportamentul cerut.
ALTER TABLE "user_books" ADD COLUMN "reservedForExchangeId" TEXT;

-- Retroactiv: schimburile deja ACCEPTED au stins anunțurile sub regula veche.
-- Le repunem pe piață cu marcajul de rezervare, ca ele să arate la fel ca
-- schimburile acceptate de acum înainte.
UPDATE "user_books" ub
SET "availableForSwap" = true,
    "reservedForExchangeId" = er."id"
FROM "exchange_requests" er
WHERE er."status" = 'ACCEPTED'
  AND ub."permanentlyTransferred" = false
  AND ub."deletedAt" IS NULL
  AND (ub."id" = er."requestedBookId" OR ub."id" = er."offeredBookId");

UPDATE "user_books" ub
SET "availableForSwap" = true,
    "reservedForExchangeId" = ebb."exchangeRequestId"
FROM "exchange_bundle_books" ebb
JOIN "exchange_requests" er ON er."id" = ebb."exchangeRequestId"
WHERE er."status" = 'ACCEPTED'
  AND ub."permanentlyTransferred" = false
  AND ub."deletedAt" IS NULL
  AND ub."id" = ebb."userBookId";
