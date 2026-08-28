-- Reducere de pret: anuntul retine pretul de dinaintea ultimei reduceri
-- (afisat taiat langa cel nou) si momentul ultimei modificari, care impune
-- cooldown-ul de 72h intre doua schimbari de pret.

-- AlterTable
ALTER TABLE "user_books" ADD COLUMN "previousSalePrice" DECIMAL(10,2);
ALTER TABLE "user_books" ADD COLUMN "priceUpdatedAt" TIMESTAMP(3);
