-- Feature backlog #10: daily admin stats snapshot, written by a cron
-- (AdminService#snapshotDailyStats), so the admin panel can show growth
-- over time instead of only the current absolute counts.

-- CreateTable
CREATE TABLE "stats_snapshots" (
    "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
    "date" DATE NOT NULL,
    "totalUsers" INTEGER NOT NULL,
    "verifiedUsers" INTEGER NOT NULL,
    "totalBooks" INTEGER NOT NULL,
    "totalListings" INTEGER NOT NULL,
    "totalExchanges" INTEGER NOT NULL,
    "completedExchanges" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "stats_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "stats_snapshots_date_key" ON "stats_snapshots"("date");
