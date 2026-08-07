-- Milestone 17 (Securitate si Exploits): email abuse protection (cooldown +
-- daily cap shared by verification/reset emails) and account lockout after
-- repeated failed logins.
ALTER TABLE "users"
  ADD COLUMN "lastAuthEmailSentAt" TIMESTAMP(3),
  ADD COLUMN "authEmailWindowStart" TIMESTAMP(3),
  ADD COLUMN "authEmailSentCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "failedLoginAttempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lockedUntil" TIMESTAMP(3);
