-- Feature backlog #14: book-condition photos on exchange. Each party
-- photographs the book before handoff (while the exchange is ACCEPTED),
-- giving both sides documented proof for "it arrived damaged" disputes.

-- AlterTable
ALTER TABLE "exchange_requests"
    ADD COLUMN "requesterConditionPhotos" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    ADD COLUMN "ownerConditionPhotos" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
