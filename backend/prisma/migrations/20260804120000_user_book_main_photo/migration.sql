-- „Poza principală" a unui anunț (Batch 8): URL-ul afișat implicit în feed,
-- carduri și listări. Poate fi una dintre pozele urcate de user (String din
-- `photos[]`), coperta oficială a cărții (Book.coverUrl) sau o copertă
-- recomandată extern (Open Library/Google Books) pe care user o alege în
-- ecranul „Adaugă carte". Când e null, UI-ul cade pe fallback-ul existent:
-- prima poză urcată, altfel coperta cărții, altfel un placeholder.
ALTER TABLE "user_books"
  ADD COLUMN "mainPhotoUrl" TEXT;
