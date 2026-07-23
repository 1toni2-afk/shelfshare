-- Resetarea parolei trece de la un token lung, unic, trimis printr-un link
-- (care avea aceleași probleme de routing/cache ca vechiul link de
-- verificare email) la un cod pe 6 cifre introdus manual în aplicație -
-- vezi migrarea 20260721130000_drop_email_verify_token_unique pentru
-- același fix aplicat anterior la emailVerifyToken. Un cod scurt nu mai
-- poate fi garantat unic global, deci scoatem constrângerea. Căutarea la
-- resetare se face acum după email, nu după token.
DROP INDEX "users_resetPasswordToken_key";
