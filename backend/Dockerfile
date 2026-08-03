# syntax=docker/dockerfile:1
# =============================================================================
# Vyron Backend — Üretim Dockerfile (Faz 7.1)
#
# İki aşamalı (multi-stage) build:
#   1) "builder"  — devDependencies dahil tam kurulum, TypeScript derlemesi,
#                    Prisma Client üretimi (`prisma generate`).
#   2) "runtime"  — sadece üretim bağımlılıkları (`npm prune --omit=dev`) ve
#                    derlenmiş `dist/` çıktısı; devDependencies (ts-jest,
#                    eslint, @nestjs/cli, typescript vb.) NİHAİ imaja
#                    kopyalanmaz. Bu, imaj boyutunu küçültür ve saldırı
#                    yüzeyini azaltır.
#
# `prisma` CLI paketi (`package.json`de bilinçli olarak `dependencies`e
# taşındı — bkz. o dosyadaki not) `docker-entrypoint.sh` içindeki
# `prisma migrate deploy` için üretim imajında da mevcut kalır.
# =============================================================================

# ---- Aşama 1: bağımlılıklar + derleme ----
FROM node:20-alpine AS builder
WORKDIR /app

# Sadece manifest dosyaları önce kopyalanır ki `npm install` katmanı, kaynak
# kod değiştiğinde değil sadece bağımlılıklar değiştiğinde yeniden çalışsın
# (Docker layer cache).
COPY package*.json ./
# NOT: depoda henüz bir package-lock.json YOK (bkz. kök README "Docker" notu)
# — komitlenirse `npm ci` daha hızlı/deterministik olur, o zamana kadar
# `npm install` kullanılıyor.
RUN npm install

COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN npm run build

# Üretimde gerekmeyen devDependencies'i node_modules'tan temizler — Prisma'nın
# ürettiği `.prisma/client` çıktısı `@prisma/client` (bir `dependency`) altında
# yaşadığı için bu adımdan ETKİLENMEZ.
RUN npm prune --omit=dev

# ---- Aşama 2: üretim çalışma zamanı ----
FROM node:20-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# `curl`: Docker HEALTHCHECK'in `/health/live`'ı çağırabilmesi için.
# `dumb-init`: PID 1 sinyal işleme sorunlarını önler (SIGTERM'in Node'a düzgün
# iletilmesi — orkestratör tarafından zarif kapatma/graceful shutdown için önemli).
RUN apk add --no-cache curl dumb-init \
  && addgroup -S vyron \
  && adduser -S vyron -G vyron

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY package.json ./
COPY docker-entrypoint.sh ./

RUN chmod +x docker-entrypoint.sh && chown -R vyron:vyron /app

USER vyron

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD curl -fs http://localhost:3000/api/v1/health/live || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["./docker-entrypoint.sh"]
