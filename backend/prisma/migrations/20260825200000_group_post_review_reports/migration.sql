-- Feature backlog #18: moderation queue for group posts + reviews. Neither
-- GroupPost nor Review had any report/hide flow before this - reuses the
-- existing Report model/status workflow (OPEN/IN_PROGRESS/RESOLVED/DISMISSED)
-- instead of a parallel moderation system per content type.

-- AlterTable
ALTER TABLE "reports"
    ADD COLUMN "groupPostId" TEXT,
    ADD COLUMN "reviewId" TEXT;

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_groupPostId_fkey" FOREIGN KEY ("groupPostId") REFERENCES "group_posts"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "reports" ADD CONSTRAINT "reports_reviewId_fkey" FOREIGN KEY ("reviewId") REFERENCES "reviews"("id") ON DELETE SET NULL ON UPDATE CASCADE;
