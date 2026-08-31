-- Book Match: bazinul de rezervă de candidați citește cărți per gen, dintr-un
-- punct aleator al indexului (vezi `exactCandidates` din book-match.service.ts).
-- Fără index ar fi seq scan pe cele ~3.7M de rânduri importate din Open Library.
CREATE INDEX IF NOT EXISTS "books_genre_id_idx" ON "books"("genre", "id");
