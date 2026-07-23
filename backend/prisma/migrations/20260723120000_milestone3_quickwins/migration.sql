-- Milestone 3 quick wins: Offer Expiration, Popular Searches, and two new
-- notification types (Nearby Book Listed, Price Changed).
ALTER TYPE "OfferStatus" ADD VALUE 'EXPIRED';
ALTER TYPE "ExchangeStatus" ADD VALUE 'EXPIRED';
ALTER TYPE "NotificationType" ADD VALUE 'NEARBY_BOOK_LISTED';
ALTER TYPE "NotificationType" ADD VALUE 'PRICE_CHANGED';

ALTER TABLE "price_offers" ADD COLUMN "expiresAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "expiresAt" TIMESTAMP(3);

CREATE TABLE "search_logs" (
    "id" TEXT NOT NULL,
    "query" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "search_logs_pkey" PRIMARY KEY ("id")
);
