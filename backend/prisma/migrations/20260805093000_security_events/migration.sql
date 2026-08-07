-- Milestone 17 (Securitate si Exploits): audit trail pentru evenimente de
-- securitate (login, schimbare parolă, acțiuni admin, toggle premium).
-- userId e nullable cu ON DELETE SET NULL - vezi comentariul din
-- schema.prisma pentru de ce nu urmăm convenția obișnuită de Cascade aici.
CREATE TABLE "security_events" (
    "id" TEXT NOT NULL,
    "type" TEXT NOT NULL,
    "userId" TEXT,
    "ip" TEXT,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "security_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "security_events_userId_idx" ON "security_events"("userId");

CREATE INDEX "security_events_type_createdAt_idx" ON "security_events"("type", "createdAt");

ALTER TABLE "security_events" ADD CONSTRAINT "security_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
