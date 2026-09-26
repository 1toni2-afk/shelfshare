# Capturi pentru „See Demo"

Pagina vizitatorilor (`web/src/features/public/LandingFeatures.tsx`) deschide
`/demo/<id>.webp` când se apasă „See Demo"; fișierele stau în `web/public/demo/`.
O captură lipsă nu strică nimic - dialogul arată doar descrierea.

Capturile se fac logat ca `toni@ss.com` pe zona de TEST (conturile se creează cu
`backend/prisma/seed-demo-accounts.js`, parola e `DEMO_PASSWORD` din mediu).
Lățime recomandată: ~1600px, WebP.

Nota asta stătea în `web/public/demo/`, deci se publica pe site odată cu
capturile - inclusiv parola. Tot ce e în `web/public/` ajunge public.

| Fișier             | Ecran                                   |
| ------------------ | --------------------------------------- |
| `collections.webp` | Colecții                                |
| `matches.webp`     | Potriviri de schimb                     |
| `nearby.webp`      | Cărți din apropiere (harta)             |
| `groups.webp`      | Grupuri → Clubul de lectură Cluj        |
| `leaderboard.webp` | Clasament și statistici (un singur chenar) |
| `history.webp`     | Istoria cărții (cartea cu 3 proprietari)|
| `shelf.webp`       | Raftul meu (în curs, cu progres)        |
| `trade.webp`       | Schimbul cu Andrada (întâlnire, telefon) |
| `feed.webp`        | Activitate                              |
