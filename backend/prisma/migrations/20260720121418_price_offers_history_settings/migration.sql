-- CreateEnum
CREATE TYPE "OfferStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED', 'CANCELLED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "NotificationType" ADD VALUE 'PRICE_OFFER_RECEIVED';
ALTER TYPE "NotificationType" ADD VALUE 'PRICE_OFFER_ACCEPTED';
ALTER TYPE "NotificationType" ADD VALUE 'PRICE_OFFER_REJECTED';

-- AlterTable
ALTER TABLE "reports" ADD COLUMN     "userBookId" TEXT;

-- AlterTable
ALTER TABLE "user_books" ADD COLUMN     "isNegotiable" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "showAcquisitionHistory" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "price_offers" (
    "id" TEXT NOT NULL,
    "buyerId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "userBookId" TEXT NOT NULL,
    "amount" DECIMAL(10,2) NOT NULL,
    "message" TEXT,
    "status" "OfferStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "price_offers_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_offers" ADD CONSTRAINT "price_offers_buyerId_fkey" FOREIGN KEY ("buyerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_offers" ADD CONSTRAINT "price_offers_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price_offers" ADD CONSTRAINT "price_offers_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;
