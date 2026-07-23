-- Public Bookshelf (Milestone 2): personal reading status per book,
-- independent of owning a physical listed copy (UserBook).
CREATE TYPE "BookshelfStatus" AS ENUM ('READING', 'WANT_TO_READ', 'FINISHED');

CREATE TABLE "bookshelf_entries" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bookId" TEXT NOT NULL,
    "status" "BookshelfStatus" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "bookshelf_entries_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "bookshelf_entries_userId_bookId_key" ON "bookshelf_entries"("userId", "bookId");

ALTER TABLE "bookshelf_entries" ADD CONSTRAINT "bookshelf_entries_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "bookshelf_entries" ADD CONSTRAINT "bookshelf_entries_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "books"("id") ON DELETE CASCADE ON UPDATE CASCADE;
