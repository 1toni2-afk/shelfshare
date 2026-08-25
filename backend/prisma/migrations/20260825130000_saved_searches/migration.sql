-- Feature backlog #6: saved searches with alerts ("SF, sub 30 lei, în
-- Cluj") - notifies the user when a new listing matches genre/city/maxPrice.

-- AlterEnum
ALTER TYPE "NotificationType" ADD VALUE 'SAVED_SEARCH_MATCH';

-- CreateTable
CREATE TABLE "saved_searches" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "genre" TEXT,
    "city" TEXT,
    "maxPrice" DECIMAL(10,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_searches_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "saved_searches" ADD CONSTRAINT "saved_searches_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateIndex
CREATE INDEX "saved_searches_userId_idx" ON "saved_searches"("userId");
