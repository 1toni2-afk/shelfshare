-- Exchange flow v2: meeting accept/decline, contact sharing, safety ack,
-- mutual Done confirmation, cancel reason, and the notification types the
-- new flow needs.
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_MEETING_PROPOSED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_MEETING_ACCEPTED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_MEETING_DECLINED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_CONTACT_SHARED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_READY';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_POSTPONED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_DONE_PENDING_CONFIRMATION';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_DONE_DISPUTED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_COMPLETED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_CANCELLED';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_BOOK_PENDING';
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_REOPENED';

ALTER TABLE "exchange_requests" ADD COLUMN "meetingProposedBy" TEXT;
ALTER TABLE "exchange_requests" ADD COLUMN "meetingAcceptedAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "acceptedAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "requesterContactPhone" TEXT;
ALTER TABLE "exchange_requests" ADD COLUMN "ownerContactPhone" TEXT;
ALTER TABLE "exchange_requests" ADD COLUMN "requesterContactSharedAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "ownerContactSharedAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "requesterSafetyAckAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "ownerSafetyAckAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "requesterDoneAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "ownerDoneAt" TIMESTAMP(3);
ALTER TABLE "exchange_requests" ADD COLUMN "cancelReason" TEXT;
ALTER TABLE "exchange_requests" ADD COLUMN "cancelDetails" TEXT;
ALTER TABLE "exchange_requests" ADD COLUMN "cancelledBy" TEXT;

-- Backfill acceptedAt for rows already ACCEPTED/COMPLETED so the 7-day
-- timeout cron has a sane anchor instead of treating them all as brand new.
UPDATE "exchange_requests" SET "acceptedAt" = "updatedAt"
  WHERE "status" IN ('ACCEPTED', 'COMPLETED') AND "acceptedAt" IS NULL;
