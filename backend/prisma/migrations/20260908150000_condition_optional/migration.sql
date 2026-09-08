-- Starea declarată a exemplarului („condition") a fost scoasă din toate
-- formularele: pozele anunțului plus pozele trimise pe chat descriu starea
-- mult mai bine decât un enum ales din dropdown. Coloana rămâne, cu datele
-- vechi intacte, dar devine nullable ca listările noi să se poată crea fără ea.
ALTER TABLE "user_books" ALTER COLUMN "condition" DROP NOT NULL;
