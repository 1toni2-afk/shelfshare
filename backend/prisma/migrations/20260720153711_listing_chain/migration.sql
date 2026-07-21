-- AlterTable
ALTER TABLE "user_books" ADD COLUMN     "previousListingId" TEXT;

-- AddForeignKey
ALTER TABLE "user_books" ADD CONSTRAINT "user_books_previousListingId_fkey" FOREIGN KEY ("previousListingId") REFERENCES "user_books"("id") ON DELETE SET NULL ON UPDATE CASCADE;
