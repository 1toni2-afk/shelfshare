-- AlterTable
ALTER TABLE "messages" ADD COLUMN     "locationLat" DOUBLE PRECISION,
ADD COLUMN     "locationLng" DOUBLE PRECISION,
ADD COLUMN     "meetingAt" TIMESTAMP(3);
