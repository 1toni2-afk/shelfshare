-- Confidentialitatea anunturilor: userul poate ascunde din rezultatele
-- publice (cautare/discover) anunturile dupa tip (schimb/vanzare/donatie/
-- licitatie), independent unele de altele - vezi comentariul de pe User in
-- schema.prisma.

-- AlterTable
ALTER TABLE "users" ADD COLUMN "hideSwapListingsPublic" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "hideSaleListingsPublic" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "hideDonationListingsPublic" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "users" ADD COLUMN "hideAuctionListingsPublic" BOOLEAN NOT NULL DEFAULT false;
