-- Lista de onboarding: ~200 de titluri alese manual, din care Book Match
-- servește cât timp userul e încă în onboarding.
--
-- Coloana e NULLABLE fără default, deci retro-compatibilă: codul vechi din
-- producție nu o citește și nu o scrie, iar rândurile existente rămân cu NULL
-- (adică „nu e în listă"). Se poate aplica înaintea codului nou.
ALTER TABLE "books" ADD COLUMN IF NOT EXISTS "onboardingRank" INTEGER;

-- Index PARȚIAL, ca `books_curated_idx`: doar ~200 din 3,68M de rânduri au
-- valoare, deci indexul are câțiva KB în loc de zeci de MB. Predicatul trebuie
-- să fie IDENTIC cu cel din interogare, altfel planner-ul nu-l folosește.
--
-- Include coloana în index: interogarea de onboarding sortează după
-- "onboardingRank", deci așa iese direct din index, fără sortare separată.
CREATE INDEX IF NOT EXISTS "books_onboarding_idx" ON "books" ("onboardingRank")
WHERE "onboardingRank" IS NOT NULL;
