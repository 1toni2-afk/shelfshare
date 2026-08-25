-- Feature backlog #11: "Cartea lunii" - simple community vote, one vote per
-- user per month. The winner is computed at read time (groupBy on the
-- current month's votes), so there is no separate winner row to keep in sync.

-- CreateTable
CREATE TABLE "book_of_month_votes" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL,
    "bookId" TEXT NOT NULL,
    "month" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_of_month_votes_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "book_of_month_votes" ADD CONSTRAINT "book_of_month_votes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "book_of_month_votes" ADD CONSTRAINT "book_of_month_votes_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "books"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateIndex
CREATE UNIQUE INDEX "book_of_month_votes_userId_month_key" ON "book_of_month_votes"("userId", "month");
CREATE INDEX "book_of_month_votes_month_bookId_idx" ON "book_of_month_votes"("month", "bookId");
