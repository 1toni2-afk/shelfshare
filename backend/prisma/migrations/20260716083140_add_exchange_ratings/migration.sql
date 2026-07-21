-- AlterTable
ALTER TABLE "exchange_requests" ADD COLUMN     "ownerRatingForRequester" INTEGER,
ADD COLUMN     "requesterRatingForOwner" INTEGER;
