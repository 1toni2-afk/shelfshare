-- Milestone 2: multi-dimensional ratings, XP & Levels, Reading Streak,
-- Reading Challenge goal.
ALTER TABLE "users" ADD COLUMN "avgCommunicationRating" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "avgPunctualityRating" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "avgConditionRating" DOUBLE PRECISION NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "currentStreakDays" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "longestStreakDays" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "lastStreakDate" TIMESTAMP(3);
ALTER TABLE "users" ADD COLUMN "xp" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "readingChallengeGoal" INTEGER;

ALTER TABLE "exchange_requests" ADD COLUMN "requesterCommunicationForOwner" INTEGER;
ALTER TABLE "exchange_requests" ADD COLUMN "requesterPunctualityForOwner" INTEGER;
ALTER TABLE "exchange_requests" ADD COLUMN "requesterConditionForOwner" INTEGER;
ALTER TABLE "exchange_requests" ADD COLUMN "ownerCommunicationForRequester" INTEGER;
ALTER TABLE "exchange_requests" ADD COLUMN "ownerPunctualityForRequester" INTEGER;
ALTER TABLE "exchange_requests" ADD COLUMN "ownerConditionForRequester" INTEGER;
