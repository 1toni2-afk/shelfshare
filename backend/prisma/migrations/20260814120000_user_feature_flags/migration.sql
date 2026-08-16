-- Acces per-user la funcții în rulare (beta / acces preferențial), acordat
-- manual din panoul de admin. Prima cheie: "advanced_statistics".
-- onDelete: Cascade - relație nouă pe User, vezi project_account_deletion.
CREATE TABLE "user_feature_flags" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "flagKey" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_feature_flags_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_feature_flags_userId_flagKey_key" ON "user_feature_flags"("userId", "flagKey");

CREATE INDEX "user_feature_flags_flagKey_idx" ON "user_feature_flags"("flagKey");

ALTER TABLE "user_feature_flags" ADD CONSTRAINT "user_feature_flags_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
