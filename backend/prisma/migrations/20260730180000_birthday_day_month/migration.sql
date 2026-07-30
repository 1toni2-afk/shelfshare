-- Milestone 14: ziua de naștere (doar zi + lună) pentru mesajul „La mulți ani"
-- din salutul paginii principale. Numele tabelei e cel din @@map („users").
ALTER TABLE "users" ADD COLUMN "birthdayDay" INTEGER;
ALTER TABLE "users" ADD COLUMN "birthdayMonth" INTEGER;
