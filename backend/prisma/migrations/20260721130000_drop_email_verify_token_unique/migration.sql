-- Verificarea prin email a trecut de la link (token lung, unic) la un cod
-- pe 6 cifre introdus manual - un cod scurt nu mai poate fi garantat unic
-- global la volum mare, deci scoatem constrângerea. Căutarea la verificare
-- se face acum după email, nu după token.
DROP INDEX "users_emailVerifyToken_key";
