-- Feature backlog #7: next-volume-in-series alert. series/seriesNumber are
-- populated manually at listing time (no reliable external source - see
-- schema.prisma comment on Book.series), and matched against users' own
-- bookshelf to notify when a later volume of a series they own appears.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'SERIES_VOLUME_AVAILABLE';

-- AlterTable
ALTER TABLE "books"
    ADD COLUMN "series" TEXT,
    ADD COLUMN "seriesNumber" INTEGER;

-- CreateIndex
CREATE INDEX "books_series_idx" ON "books"("series");
