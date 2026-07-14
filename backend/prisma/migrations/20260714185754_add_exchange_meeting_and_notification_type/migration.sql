-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'EXCHANGE_MEETING_SCHEDULED';

-- AlterTable
ALTER TABLE "exchange_requests" ADD COLUMN     "meetingLocation" TEXT,
ADD COLUMN     "meetingTime" TIMESTAMP(3);
