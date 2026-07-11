-- AlterTable
ALTER TABLE "users" ADD COLUMN     "bio" TEXT,
ADD COLUMN     "booksExchangedCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "city" TEXT,
ADD COLUMN     "name" TEXT,
ADD COLUMN     "profileImage" TEXT,
ADD COLUMN     "rating" DOUBLE PRECISION NOT NULL DEFAULT 0;
