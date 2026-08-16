-- Price offer flow v2: a cash sale is still an in-person handoff, so it gets
-- the same meeting/contact/safety/mutual-Done flow as book-for-book exchanges
-- (see 20260813120000_exchange_flow_v2) instead of transferring the book the
-- instant the offer is accepted.
ALTER TYPE "OfferStatus" ADD VALUE 'COMPLETED';

ALTER TABLE "price_offers" ADD COLUMN "acceptedAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "meetingTime" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "meetingLocation" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "meetingProposedBy" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "meetingAcceptedAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "buyerContactPhone" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "ownerContactPhone" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "buyerContactSharedAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "ownerContactSharedAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "buyerSafetyAckAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "ownerSafetyAckAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "buyerDoneAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "ownerDoneAt" TIMESTAMP(3);
ALTER TABLE "price_offers" ADD COLUMN "cancelReason" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "cancelDetails" TEXT;
ALTER TABLE "price_offers" ADD COLUMN "cancelledBy" TEXT;
