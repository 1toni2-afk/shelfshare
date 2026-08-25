-- Feature backlog #17: bundle transactions. A requester can offer several of
-- their own books in one exchange, not just `exchange_requests.offeredBookId`
-- (which stays the primary/first offered book, so all existing logic keeps
-- working unchanged). Additional bundle books live in this join table.

-- CreateTable
CREATE TABLE "exchange_bundle_books" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "exchangeRequestId" TEXT NOT NULL,
    "userBookId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_bundle_books_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "exchange_bundle_books" ADD CONSTRAINT "exchange_bundle_books_exchangeRequestId_fkey" FOREIGN KEY ("exchangeRequestId") REFERENCES "exchange_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "exchange_bundle_books" ADD CONSTRAINT "exchange_bundle_books_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateIndex
CREATE UNIQUE INDEX "exchange_bundle_books_exchangeRequestId_userBookId_key" ON "exchange_bundle_books"("exchangeRequestId", "userBookId");
