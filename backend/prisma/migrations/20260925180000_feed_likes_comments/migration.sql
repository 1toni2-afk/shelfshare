-- Aprecieri și comentarii pe evenimentele din feed. Ținta e o cheie
-- `tip:idSursă`, nu o cheie străină: feedul se recompune la citire din cinci
-- tabele, deci nu există un rând de „eveniment" la care să se lege.
CREATE TABLE "feed_likes" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "feed_likes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "feed_likes_userId_eventKey_key" ON "feed_likes"("userId", "eventKey");
CREATE INDEX "feed_likes_eventKey_idx" ON "feed_likes"("eventKey");

ALTER TABLE "feed_likes" ADD CONSTRAINT "feed_likes_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "feed_comments" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "eventKey" TEXT NOT NULL,
    "text" TEXT NOT NULL,
    "hiddenAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "feed_comments_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "feed_comments_eventKey_createdAt_idx" ON "feed_comments"("eventKey", "createdAt");

ALTER TABLE "feed_comments" ADD CONSTRAINT "feed_comments_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Comentariile se raportează prin același flux ca restul conținutului.
ALTER TYPE "ReportTargetType" ADD VALUE 'FEED_COMMENT';

ALTER TABLE "reports" ADD COLUMN "feedCommentId" TEXT;
ALTER TABLE "reports" ADD CONSTRAINT "reports_feedCommentId_fkey"
    FOREIGN KEY ("feedCommentId") REFERENCES "feed_comments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
