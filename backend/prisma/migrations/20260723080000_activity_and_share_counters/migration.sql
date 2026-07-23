-- Last Active + split Books Shared / Books Received counters (Milestone 2)
ALTER TABLE "users" ADD COLUMN "lastActiveAt" TIMESTAMP(3);
ALTER TABLE "users" ADD COLUMN "booksSharedCount" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "booksReceivedCount" INTEGER NOT NULL DEFAULT 0;
