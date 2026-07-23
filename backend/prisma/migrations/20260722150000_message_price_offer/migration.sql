-- AlterTable
ALTER TABLE "messages" ADD COLUMN     "priceOfferId" TEXT;

-- AddForeignKey
ALTER TABLE "messages" ADD CONSTRAINT "messages_priceOfferId_fkey" FOREIGN KEY ("priceOfferId") REFERENCES "price_offers"("id") ON DELETE SET NULL ON UPDATE CASCADE;
