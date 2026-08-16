-- Separate migration file so the 'COMPLETED' enum value added in
-- 20260813210000_price_offer_flow_v2 is committed before we use it here -
-- Postgres won't let a freshly added enum value be used in the same
-- transaction that added it.
--
-- Ofertele deja ACCEPTED (vânzarea deja finalizată instant, sub vechiul
-- comportament unde accept() transfera cartea pe loc) devin COMPLETED - au
-- trecut deja cartea efectiv, n-are sens să retrăiască flow-ul de programare.
UPDATE "price_offers" SET status = 'COMPLETED', "acceptedAt" = "updatedAt"
  WHERE status = 'ACCEPTED';
