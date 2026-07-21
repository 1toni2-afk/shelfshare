-- AlterTable
ALTER TABLE "users" ADD COLUMN     "username" TEXT,
ADD COLUMN     "nameVisible" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE UNIQUE INDEX "users_username_key" ON "users"("username");

-- CreateTable
CREATE TABLE "book_views" (
    "id" TEXT NOT NULL,
    "userBookId" TEXT NOT NULL,
    "userId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_views_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "book_views_userBookId_userId_key" ON "book_views"("userBookId", "userId");

-- AddForeignKey
ALTER TABLE "book_views" ADD CONSTRAINT "book_views_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "book_views" ADD CONSTRAINT "book_views_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
