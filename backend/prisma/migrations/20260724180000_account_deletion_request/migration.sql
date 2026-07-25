-- User poate cere ștergerea contului cu o fereastră de grace de 15 zile
-- (cerință Google Play, sec. „Data deletion"). Un job zilnic șterge conturile
-- cu deletionScheduledAt <= now. Nullable = nu e programat pentru ștergere.
ALTER TABLE "users"
  ADD COLUMN "deletionScheduledAt" TIMESTAMP(3);
