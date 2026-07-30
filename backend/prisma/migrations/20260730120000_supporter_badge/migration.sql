-- Milestone 13: insigna „Supporter" pentru userii care au donat prin
-- „Keep the app alive". Numele tabelei e cel din @@map („users"), nu numele
-- modelului Prisma.
ALTER TABLE "users" ADD COLUMN "supporterSince" TIMESTAMP(3);
