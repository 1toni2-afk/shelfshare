-- Milestone 18: câmp `languages` pe User (String[]), afișat pe cardul „Despre"
-- din profilul lateral. Default „Română" ca userii existenți să nu vadă un
-- gol pe profilul propriu la prima încărcare după deploy.
ALTER TABLE "users" ADD COLUMN "languages" TEXT[] NOT NULL DEFAULT ARRAY['Română']::TEXT[];
