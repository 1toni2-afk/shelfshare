-- Adaugă legătura mesaj -> cerere de schimb, ca ofertele de swap să apară
-- ca și card acționabil în chat, la fel ca ofertele de preț (priceOfferId).
ALTER TABLE "messages" ADD COLUMN "exchangeRequestId" TEXT;

ALTER TABLE "messages"
  ADD CONSTRAINT "messages_exchangeRequestId_fkey"
  FOREIGN KEY ("exchangeRequestId") REFERENCES "exchange_requests"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
