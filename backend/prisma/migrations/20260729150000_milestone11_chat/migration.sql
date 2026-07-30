-- Milestone 11 - Chat: arhivare/ștergere per participant, reply la mesaj,
-- „last seen" și export de transcript pentru conversațiile raportate.

-- Ultima deconectare de la socket-ul de chat. Separat de "lastActiveAt"
-- (atins la orice request HTTP autentificat) fiindcă „Last seen" trebuie să
-- reflecte prezența reală în aplicație, nu polling de fundal.
ALTER TABLE "users" ADD COLUMN "lastSeenAt" TIMESTAMP(3);

-- Arhivarea și ștergerea sunt per capăt de conversație: dacă A șterge chatul,
-- B trebuie să îl vadă mai departe intact. userA/userB sunt deja normalizate
-- alfabetic la creare (vezi findOrCreateConversation), deci perechea de
-- coloane acoperă ambii participanți fără tabel separat.
ALTER TABLE "conversations"
  ADD COLUMN "userAArchivedAt" TIMESTAMP(3),
  ADD COLUMN "userBArchivedAt" TIMESTAMP(3),
  ADD COLUMN "userAClearedAt"  TIMESTAMP(3),
  ADD COLUMN "userBClearedAt"  TIMESTAMP(3);

-- Reply la un mesaj anterior. ON DELETE SET NULL: dacă mesajul citat dispare,
-- răspunsul rămâne în conversație, doar citatul se pierde.
ALTER TABLE "messages" ADD COLUMN "replyToId" TEXT;

ALTER TABLE "messages"
  ADD CONSTRAINT "messages_replyToId_fkey"
  FOREIGN KEY ("replyToId") REFERENCES "messages"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;

-- Paginarea mesajelor și căutarea în conversație filtrează mereu pe
-- conversationId și ordonează după createdAt.
CREATE INDEX "messages_conversationId_createdAt_idx"
  ON "messages" ("conversationId", "createdAt");

-- Un raport pornit din chat păstrează conversația vizată și calea către
-- transcriptul exportat în storage (folderul chat-reports/). Snapshot, nu
-- link viu - dovada supraviețuiește ștergerii conversației, de unde și
-- ON DELETE SET NULL pe FK.
ALTER TABLE "reports"
  ADD COLUMN "conversationId" TEXT,
  ADD COLUMN "transcriptPath" TEXT;

ALTER TABLE "reports"
  ADD CONSTRAINT "reports_conversationId_fkey"
  FOREIGN KEY ("conversationId") REFERENCES "conversations"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
