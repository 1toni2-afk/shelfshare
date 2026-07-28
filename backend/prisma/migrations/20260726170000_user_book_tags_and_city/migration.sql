-- Milestone 10 batch 3: tag-uri per anunț (max 5, validat în DTO) + localitatea
-- unde se face schimbul. Localitatea e la nivel de exemplar pentru că un user
-- poate posta cărți din mai multe orașe (călătorii, mutări) - separat de
-- user.city care e „orașul principal".
ALTER TABLE "user_books"
  ADD COLUMN "tags" TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN "city" TEXT;
