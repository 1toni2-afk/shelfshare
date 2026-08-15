-- Book Match (swipe) - fundația de backend.
--
-- Log append-only de swipe-uri + scoruri derivate pe 3 dimensiuni (gen, autor,
-- epocă). Scorurile NU se scriu incremental: după fiecare swipe se recalculează
-- din tot istoricul valorii atinse, cu pondere 0.5^(zile/180). Așa nu contează
-- când rulează recalculul, rezultatul e mereu același.

CREATE TYPE "BookSwipeAction" AS ENUM ('YES', 'NO', 'SKIP');
CREATE TYPE "WishlistItemSource" AS ENUM ('PERSONAL', 'BOOK_MATCH');

-- Rândurile existente de wishlist sunt toate adăugări manuale.
ALTER TABLE "wishlist_items"
  ADD COLUMN "source" "WishlistItemSource" NOT NULL DEFAULT 'PERSONAL';

ALTER TABLE "users"
  ADD COLUMN "onboardingSwipesCount" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lastRecalibrationAt" TIMESTAMP(3),
  ADD COLUMN "discoveryBoostSwipesRemaining" INTEGER NOT NULL DEFAULT 0;

-- Multiplicator de cold start; NULL = necurat, codul folosește 0.3.
ALTER TABLE "books"
  ADD COLUMN "popularityScore" DOUBLE PRECISION;

CREATE TABLE "book_swipes" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "bookId" TEXT NOT NULL,
    "action" "BookSwipeAction" NOT NULL,
    "sessionId" TEXT NOT NULL,
    "isDiscovery" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "book_swipes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "book_swipes_userId_bookId_idx" ON "book_swipes"("userId", "bookId");
CREATE INDEX "book_swipes_userId_createdAt_idx" ON "book_swipes"("userId", "createdAt");
CREATE INDEX "book_swipes_userId_sessionId_idx" ON "book_swipes"("userId", "sessionId");

ALTER TABLE "book_swipes" ADD CONSTRAINT "book_swipes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "book_swipes" ADD CONSTRAINT "book_swipes_bookId_fkey" FOREIGN KEY ("bookId") REFERENCES "books"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "user_genre_scores" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "genre" TEXT NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_genre_scores_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "user_genre_scores_userId_genre_key" ON "user_genre_scores"("userId", "genre");
ALTER TABLE "user_genre_scores" ADD CONSTRAINT "user_genre_scores_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "user_author_scores" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "author" TEXT NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_author_scores_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "user_author_scores_userId_author_key" ON "user_author_scores"("userId", "author");
ALTER TABLE "user_author_scores" ADD CONSTRAINT "user_author_scores_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "user_era_scores" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "era" TEXT NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_era_scores_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "user_era_scores_userId_era_key" ON "user_era_scores"("userId", "era");
ALTER TABLE "user_era_scores" ADD CONSTRAINT "user_era_scores_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "recalibration_logs" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "scoresBefore" JSONB NOT NULL,
    "scoresAfter" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "recalibration_logs_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "recalibration_logs_userId_createdAt_idx" ON "recalibration_logs"("userId", "createdAt");
ALTER TABLE "recalibration_logs" ADD CONSTRAINT "recalibration_logs_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
