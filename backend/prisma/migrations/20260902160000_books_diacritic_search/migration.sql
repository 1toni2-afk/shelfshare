-- Căutare de cărți insensibilă la diacritice.
--
-- „Stapanul Inelelor" nu găsea „Stăpânul Inelelor: Frăția Inelului": nici
-- Google Books (`intitle:"..."` e potrivire de frază exactă), nici Open
-- Library (n-are edițiile românești), iar catalogul propriu - care O ARE -
-- nu era interogat deloc din autocomplete-ul de la „adaugă carte".
--
-- `unaccent()` e STABLE, nu IMMUTABLE (rezultatul depinde de dicționarul
-- curent), deci nu poate intra direct într-un index. Wrapper-ul de mai jos
-- fixează dicționarul, ceea ce îl face corect ca IMMUTABLE.
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE OR REPLACE FUNCTION immutable_unaccent(text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
AS $$
  SELECT public.unaccent('public.unaccent'::regdictionary, $1)
$$;

-- Index de expresie, NU coloană generată: o coloană `STORED` ar rescrie toată
-- tabela (~2GB, ACCESS EXCLUSIVE pe toată durata). Indexul cere doar un
-- ShareLock - blochează scrierile în `books`, nu și citirile.
--
-- Configurația 'simple' (fără stemming): titlurile sunt în mai multe limbi,
-- iar un stemmer englezesc pe titluri românești face mai mult rău decât bine.
-- Potrivirea de prefix pe ultimul cuvânt (`:*`) acoperă autocomplete-ul.
--
-- Interogările TREBUIE să folosească exact aceeași expresie ca să prindă
-- indexul - vezi BooksService.searchCatalog.
CREATE INDEX IF NOT EXISTS "books_search_fts_idx" ON "books"
USING GIN (
  to_tsvector(
    'simple',
    immutable_unaccent(coalesce("title", '') || ' ' || coalesce("author", ''))
  )
);
