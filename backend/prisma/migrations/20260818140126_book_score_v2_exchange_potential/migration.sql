-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "ListingScoreEventKind" ADD VALUE 'RETURN_VISIT';
ALTER TYPE "ListingScoreEventKind" ADD VALUE 'EXCHANGE_REQUEST';
ALTER TYPE "ListingScoreEventKind" ADD VALUE 'BUY_OFFER';

-- AlterTable
ALTER TABLE "user_books" ADD COLUMN     "manualScoreOverride" DOUBLE PRECISION;
