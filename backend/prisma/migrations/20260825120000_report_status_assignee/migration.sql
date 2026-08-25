-- Feature backlog #4: status + assignee on Report, so moderators can see
-- whether a report was already handled and by whom instead of two people
-- silently working the same report.

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'DISMISSED');

-- AlterTable
ALTER TABLE "reports"
    ADD COLUMN "status" "ReportStatus" NOT NULL DEFAULT 'OPEN',
    ADD COLUMN "assignedToId" TEXT,
    ADD COLUMN "resolutionNote" TEXT,
    ADD COLUMN "resolvedAt" TIMESTAMP(3);

-- AddForeignKey
ALTER TABLE "reports" ADD CONSTRAINT "reports_assignedToId_fkey" FOREIGN KEY ("assignedToId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateIndex
CREATE INDEX "reports_status_idx" ON "reports"("status");
