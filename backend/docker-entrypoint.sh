#!/bin/sh
# Faz 7.1 — Üretim container'ı için başlangıç betiği.
#
# `prisma migrate deploy` uygulanmamış migration'ları veritabanına uygular
# ve `prisma migrate dev`'in aksine ASLA şema taslağı (drift) oluşturmaz ya da
# veri kaybına yol açabilecek bir işlem sormaz — üretimde kullanılması güvenli
# olan tek migrate komutu budur. Concurrent (çoklu replika) çalıştırmalarda
# Prisma kendi migration kilidini kullanır, bu yüzden birden fazla instance
# aynı anda başlasa bile güvenlidir.
#
# NOT: çok-replikalı (yatay ölçekli) bir üretim dağıtımında migration'ı her
# instance'ın kendi başlangıcında çalıştırmak yerine, deploy pipeline'ında AYRI
# bir "migration job" adımı olarak çalıştırmak daha temiz bir örüntüdür (bkz.
# `.github/workflows/deploy.yml` notu). Bu betik, `docker-compose.prod.yml` ile
# tek-instance bir dağıtımı hemen çalışır halde tutmak için kasıtlı olarak
# basit tutuldu.
set -e

echo "→ Veritabanı migration'ları uygulanıyor (prisma migrate deploy)..."
npx prisma migrate deploy

echo "→ Vyron API başlatılıyor..."
exec node dist/main.js
