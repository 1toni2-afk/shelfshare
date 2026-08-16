-- „Cele mai căutate" (Milestone 20): scor de interes per anunț, în care fiecare
-- punct expiră individual la 14 zile. Nu putem folosi un contor cumulat pe
-- user_books (nu am ști ce parte din el a expirat), deci logăm evenimentele
-- una câte una și însumăm la citire doar rândurile mai noi de 14 zile.
CREATE TYPE "ListingScoreEventKind" AS ENUM ('UNIQUE_VIEW', 'REVIEW', 'WISHLIST_ADD');

CREATE TABLE "listing_score_events" (
    "id" TEXT NOT NULL,
    "userBookId" TEXT NOT NULL,
    "userId" TEXT,
    "kind" "ListingScoreEventKind" NOT NULL,
    "points" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "listing_score_events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "listing_score_events_createdAt_idx" ON "listing_score_events"("createdAt");
CREATE INDEX "listing_score_events_userBookId_createdAt_idx" ON "listing_score_events"("userBookId", "createdAt");
CREATE INDEX "listing_score_events_userBookId_userId_kind_createdAt_idx" ON "listing_score_events"("userBookId", "userId", "kind", "createdAt");

ALTER TABLE "listing_score_events" ADD CONSTRAINT "listing_score_events_userBookId_fkey" FOREIGN KEY ("userBookId") REFERENCES "user_books"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "listing_score_events" ADD CONSTRAINT "listing_score_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
