-- Premium (Milestone 5) - flag-only, acordat manual din admin panel, fără
-- procesare de plăți reale. isPromoted pe user_books e un gate premium
-- (Promoted Listings), setabil doar de useri isPremium.
ALTER TABLE "users" ADD COLUMN "isPremium" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "user_books" ADD COLUMN "isPromoted" BOOLEAN NOT NULL DEFAULT false;
