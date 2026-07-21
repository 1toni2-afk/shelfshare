# --- Stage 1: dependențe + build ---
FROM node:22-alpine AS builder

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .
# DATABASE_URL real vine din environment la runtime (docker-compose.prod.yml).
# La build avem nevoie doar de o valoare prezentă, ca prisma generate să nu crape -
# "generate" citește schema, nu se conectează efectiv la bază.
ENV DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
RUN pnpm exec prisma generate
RUN pnpm run build

# pnpm plasează clientul Prisma generat în store-ul .pnpm (nu la
# node_modules/.prisma ca la npm/yarn), la o cale cu hash care variază -
# copiem tot node_modules în loc să ghicim calea exactă, după ce scăpăm de
# devDependencies cu prune.
RUN pnpm prune --prod

# --- Stage 2: imagine finală, doar ce trebuie pentru rulare ---
FROM node:22-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts

EXPOSE 3000

CMD ["node", "dist/main"]
