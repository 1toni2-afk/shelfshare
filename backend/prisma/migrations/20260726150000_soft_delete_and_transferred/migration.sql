-- Milestone 10: bulk delete restore în 7 zile + „emptied shelves" pentru
-- cărțile deja transferate.
--
-- `deletedAt` = soft-delete cu grace period. User poate „restore" până se
-- împlinesc 7 zile de la ștergere; după, un cron șterge definitiv.
-- Query-urile publice trebuie să filtreze deletedAt IS NULL, altfel cărțile
-- „coșul de gunoi" apar în feed.
--
-- `permanentlyTransferred` = flag imutabil setat când un exchange se
-- completează efectiv (ambele părți confirmă). Blochează redenumirea în
-- „disponibil" din bulk edit - o carte care a plecat NU mai poate fi
-- readăugată în stoc din greșeală. Cerință Milestone 10.
ALTER TABLE "user_books"
  ADD COLUMN "deletedAt" TIMESTAMP(3),
  ADD COLUMN "permanentlyTransferred" BOOLEAN NOT NULL DEFAULT false;

-- Index parțial: majoritatea rândurilor au deletedAt NULL, iar query-urile
-- publice filtrează pe asta - un index parțial doar pe rânduri ne-șterse ține
-- indexul mic și scanarea rapidă.
CREATE INDEX "user_books_active_idx"
  ON "user_books" ("userId")
  WHERE "deletedAt" IS NULL;
