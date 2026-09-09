-- Două tipuri noi de notificare:
--   GROUP_POST    - postare nouă într-un grup din care userul face parte;
--   ADMIN_MESSAGE - răspuns de la echipa de suport (nu apare în setări).
--
-- Stau într-o migrare separată de cea de rezervare a anunțului fiindcă
-- PostgreSQL nu lasă o valoare nouă de enum să fie FOLOSITĂ în aceeași
-- tranzacție în care a fost adăugată, iar Prisma rulează fiecare fișier
-- într-o tranzacție.
--
-- ORDINEA de deploy: retro-compatibilă (doar valori noi de enum, nimic
-- existent atins), deci se aplică ÎNAINTE de pornirea codului nou.
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'GROUP_POST';
ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'ADMIN_MESSAGE';
