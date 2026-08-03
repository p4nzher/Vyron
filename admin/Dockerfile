# =============================================================================
# Vyron Yönetim Paneli — Üretim Dockerfile (Faz 7.5)
#
# Backend'inkiyle aynı iki-aşamalı mantık: Node ile derle, sonuçtaki statik
# dosyaları küçük bir nginx imajıyla servis et. `VITE_API_BASE_URL` BUILD
# ZAMANINDA gömülür (Vite'ın tüm env değişkenleri derleme anında JS'e
# gömülür — çalışma zamanında değiştirilemez), bu yüzden `--build-arg` ile
# geçilir; farklı bir backend adresi için imajı YENİDEN build etmeniz gerekir.
# =============================================================================

FROM node:20-alpine AS builder
WORKDIR /app

ARG VITE_API_BASE_URL=http://localhost:3000
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
