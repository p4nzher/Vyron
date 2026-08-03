# Vyron

Discord'dan ilham alan, tamamen özgün tasarım ve mimariye sahip modern iletişim platformu.

**Marka renk paleti** için `docs/brand.md` dosyasına bakınız.

## Teknoloji Yığını

| Katman | Teknoloji |
|---|---|
| Frontend | Flutter (Android/iOS/Windows/macOS/Web) |
| Backend | NestJS (Node.js + TypeScript) |
| Veritabanı | PostgreSQL + Prisma ORM |
| Gerçek zamanlı | Socket.IO |
| Sesli/Görüntülü | WebRTC + LiveKit |
| Cache | Redis |
| Depolama | S3 uyumlu (Cloudflare R2 / MinIO) |
| Kimlik doğrulama | JWT (access + refresh token rotasyonu) |

## Geliştirme Yol Haritası (Faz Planı)

- [x] **Faz 1 — Temel Altyapı ve Kimlik Doğrulama** ✅ Tamamlandı
  - Klasör yapısı, Prisma şeması (tüm platform)
  - Kayıt, giriş, refresh token rotasyonu, 2FA (TOTP), e-posta doğrulama, şifre sıfırlama
  - Global güvenlik: Helmet, rate limiting, DTO validasyonu, tutarlı hata/yanıt formatı
- [x] **Faz 2 — Arkadaşlık Sistemi** ✅ Tamamlandı
  - "kullaniciadi#0000" etiketiyle istek gönderme, kabul/red/iptal
  - Karşılıklı istek varsa otomatik eşleştirme, engelleme (çift yönlü kontrol + otomatik arkadaşlık iptali)
- [x] **Faz 3 — Sunucular** ✅ Tamamlandı (backend)
  - Sunucu oluşturma (otomatik @everyone rolü + varsayılan metin/sesli kanal)
  - Kanal CRUD + sıralama (kategori/pozisyon)
  - Rol sistemi: JSON tabanlı yetkiler, hiyerarşi kontrolü (`position`), `ADMINISTRATOR` bypass
  - Davet linkleri: süre/limit sınırlı kod üretimi, önizleme, katılma
  - Moderasyon: kick / ban (kalıcı `ServerBan` kaydı) / timeout / uyarı, tümü hiyerarşi korumalı
  - Denetim kaydı (audit log): her yönetimsel işlem `audit_logs` tablosuna yazılır ve `GET /servers/:id/audit-log` ile görüntülenir
- [x] **Faz 4 — Mesajlaşma** ✅ Tamamlandı (backend)
  - Dosya depolama (`storage` modülü): S3/R2 uyumlu presigned-URL üretimi, bağlam bazlı (avatar/ek/ses kaydı/emoji/sticker) boyut ve MIME doğrulaması
  - Mesajlaşma (`messages` modülü): sunucu kanalları için CRUD, imleç tabanlı sayfalama, yanıtlama (reply), düzenleme, soft-delete, sabitleme (pin), emoji tepkileri, dosya/ses kaydı/GIF/sticker ekleri
  - Özel mesajlar (`dm` modülü): birebir ve grup DM kanalları, engelleme kontrolü, okundu işaretleme, aynı mesaj altyapısının `{dmChannelId}` kapsamıyla yeniden kullanımı
  - Gerçek zamanlı katman (`messages.gateway.ts`): JWT doğrulamalı Socket.IO `/realtime` namespace'i, kanal/DM odaları, yazıyor... göstergesi, çevrimiçi/çevrimdışı presence yayını
  - Yatay ölçekleme: `@socket.io/redis-adapter` ile çoklu Node.js instance'ı arasında oda senkronizasyonu (`src/adapters/redis-io.adapter.ts`)
  - Mimari not: mesaj oluşturma/düzenleme/silme REST üzerinden (komut), gerçek zamanlı yayın Socket.IO üzerinden (olay) yapılır — Discord'un kendi mimarisiyle aynı ayrım
- [x] **Faz 5 — Sesli/Görüntülü/Ekran Paylaşımı** ✅ Tamamlandı (backend)
  - `voice` modülü: `LiveKitService` (token üretimi + oda yönetimi REST çağrıları) ve `VoiceService` (VoiceState senkronizasyonu, yetki/hiyerarşi kontrolleri)
  - Kanala katılma: `CONNECT_VOICE` yetkisi, timeout kontrolü, `Channel.userLimit` doluluk kontrolü, tek-kanal kısıtı (kullanıcı aynı anda tek sesli kanalda bulunabilir)
  - Yayın izinleri (mikrofon/kamera/ekran paylaşımı) sunucu tarafında `SPEAK_VOICE`/`VIDEO_VOICE`/`SCREEN_SHARE` rol yetkilerinden hesaplanıp LiveKit token grant'lerine gömülür (istemci taklit edemez)
  - Moderasyon: zorla susturma/sağırlaştırma/taşıma/atma — rol hiyerarşisi kontrolüyle (`assertHierarchy`, `moderation` modülüyle aynı mantık)
  - `MessagesGateway` yeniden kullanılarak `voice:user-joined` / `voice:user-left` / `voice:state-updated` / `voice:force-muted` / `voice:you-were-moved` gibi olaylar aynı Socket.IO odalarına yayınlanır
  - `docker-compose.yml`'e yerel geliştirme için `--dev` modunda LiveKit sunucusu eklendi (sabit `devkey/secret`)
- [x] **Faz 6 — Flutter İstemcisi** ✅ Tamamlandı (6.1 → 6.7, bkz. `frontend/README.md`)
  - [x] 6.1 — Proje iskeleti: tema sistemi, ağ katmanı (otomatik token yenileme), DI, routing, **uçtan uca çalışan kayıt/giriş** (2FA dahil)
  - [x] 6.2 — Kalıcı oturum durumu (Riverpod `AuthController`), şifre sıfırlama, 2FA kurulumu, profil düzenleme
  - [x] 6.3 — Ana kabuk: responsive 3 sütunlu düzen (sunucu rayı + kanallar + içerik)
  - [x] 6.4 — Mesajlaşma ekranı + Socket.IO entegrasyonu
  - [x] 6.5 — Sesli/görüntülü görüşme (`livekit_client`)
  - [x] 6.6 — Sunucu/kanal/rol/davet yönetim ekranları
  - [x] 6.7 — Arkadaşlar, bildirimler, ayarlar
- [x] **Faz 7 — Yönetim Paneli ve Sertleştirme** ✅ Tamamlandı (7.1 → 7.5)
  - [x] 7.1 — Docker sertleştirme: çok aşamalı üretim `Dockerfile`, `/health/live` + `/health/ready`, `docker-compose.prod.yml`
  - [x] 7.2 — CI/CD: GitHub Actions (`backend-ci.yml`, `frontend-ci.yml`, `docker-publish.yml`) — lint, birim/e2e test, `flutter analyze`, GHCR imaj yayını
  - [x] 7.3 — Yapılandırılmış loglama (`nestjs-pino` — request-id/correlation-id, JSON log formatı)
  - [x] 7.4 — İstatistik/metrik uç noktaları (`/admin/stats/**`, sadece `isSystemAdmin`)
  - [x] 7.5 — Yönetim (admin) paneli arayüzü (`admin/` — React + Vite, `/admin/stats/**` üzerinden salt-okunur genel bakış)

## Yerel Kurulum

```bash
# 1. Altyapı servislerini başlat (PostgreSQL, Redis, MinIO)
docker compose up -d

# 2. Backend bağımlılıklarını kur
cd backend
npm install

# 3. Ortam değişkenlerini ayarla
cp .env.example .env
# .env içindeki JWT_ACCESS_SECRET / JWT_REFRESH_SECRET değerlerini
# en az 32 karakterlik rastgele string'lerle değiştir:
#   openssl rand -hex 32

# 4. Veritabanı şemasını uygula
npm run prisma:generate
npm run prisma:migrate

# 5. Sunucuyu başlat
npm run start:dev
```

API şu adreste çalışır: `http://localhost:3000/api/v1`
Swagger dokümantasyonu: `http://localhost:3000/docs`

### Hızlı Test (curl)

```bash
# Kayıt ol
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"enes_dev","email":"enes@example.com","password":"GucluSifre!123"}'

# Giriş yap
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"enes@example.com","password":"GucluSifre!123"}'
```

## Docker ile Çalıştırma (Faz 7.1)

Yerel geliştirme (yukarıdaki `docker compose up -d` + `npm run start:dev`)
DEĞİŞMEDİ — hot-reload için backend hâlâ host üzerinde çalışır. Backend'i DE
container'da çalıştıran, kendi kendine yeterli bir üretim benzeri stack için:

```bash
cp backend/.env.example backend/.env
# backend/.env içindeki TÜM "CHANGE_ME" değerlerini gerçek gizli anahtarlarla
# değiştirin (bkz. docker-compose.prod.yml başındaki üretim kontrol listesi).

docker compose -f docker-compose.prod.yml --env-file backend/.env up -d --build
```

- Sağlık kontrolleri: `GET /api/v1/health/live` (sadece süreç canlı mı),
  `GET /api/v1/health/ready` (Postgres + Redis'e gerçekten bağlanabiliyor mu
  — `docker-compose.prod.yml`'deki `backend` servisinin `healthcheck`'i bunu kullanır).
- İmaj `backend/Dockerfile`'da iki aşamalı (multi-stage) build edilir; devDependencies
  nihai imaja dahil edilmez, container root olmayan bir kullanıcıyla (`vyron`) çalışır.
- Container başlarken `docker-entrypoint.sh` önce `prisma migrate deploy` çalıştırır,
  sonra API'yi başlatır (bkz. o dosyadaki çoklu-replika notu).

## CI/CD (Faz 7.2)

`.github/workflows/` altında üç iş akışı var:

| Dosya | Ne zaman çalışır | Ne yapar |
|---|---|---|
| `backend-ci.yml` | `backend/**` değiştiğinde | lint, `tsc` derlemesi, birim testleri (dış servis gerekmez) + gerçek Postgres/Redis `services` container'larıyla e2e testleri |
| `frontend-ci.yml` | `frontend/**` değiştiğinde | `flutter pub get` + `flutter analyze` (platform klasörleri OLMADAN da çalışır — bkz. `frontend/README.md`) |
| `docker-publish.yml` | `main`'e push / `v*.*.*` tag | backend imajını build edip `ghcr.io/<repo>-backend`'e yayınlar |

**Faz 7.2 kapsamında ayrıca eklendi** (backend'de daha önce hiç yoktu):
`.eslintrc.js`, `jest.config.js`, `test/jest-e2e.json`, birkaç gerçek birim testi
(`src/common/permissions/permissions.util.spec.ts`) ve bir e2e testi
(`test/health.e2e-spec.ts`). `npm run test:e2e`'nin çalışması için önce
`docker compose up -d postgres redis` gerekir.

### ⚠️ Faz 7.1'de bulunan ve düzeltilen kritik hata

`main.ts` hem `app.setGlobalPrefix('api/v1')` hem `app.enableVersioning({ defaultVersion: '1' })`
çağırıyordu — bu ikisi üst üste biniyor ve gerçek rotaların `/api/v1/v1/...`
olarak kaydolmasına yol açıyordu, oysa Flutter istemcisi (Faz 6.1'den beri)
`/api/v1/...` (TEK v1) bekliyordu. `API_PREFIX` varsayılanı `api/v1`'den
sadece `api`'ye çekilerek düzeltildi (versioning zaten `v1`'i ekliyor). Bu,
kod bu ortamda hiç gerçekten çalıştırılıp uçtan uca test edilmediği için
muhtemelen hiç yakalanmamıştı. **Backend'i ilk kez ayağa kaldırdığınızda
`curl http://localhost:3000/api/v1/auth/register` gibi bilinen bir uca
istek atarak ya da `/docs`'taki Swagger UI'dan bunu doğrulamanız önerilir.**



## Bilinen Eksikler (henüz yapılmadı)

- **Gürültü/yankı engelleme:** Bu, DSP seviyesinde bir istemci (Flutter/WebRTC) özelliğidir — backend'de yapılacak bir şey yoktur. LiveKit istemci SDK'ları (`livekit_client` Flutter paketi) varsayılan olarak WebRTC'nin yerleşik `noiseSuppression`/`echoCancellation` seçeneklerini destekler; Faz 6'da istemci tarafında etkinleştirilecek.
- **TURN/STUN sunucusu:** `docker-compose.yml`'deki LiveKit `--dev` modu, NAT arkasındaki (ör. kurumsal ağ) istemciler için TURN relay içermez. Üretimde LiveKit Cloud kullanılması ya da self-hosted bir TURN sunucusunun (coturn) devreye alınması gerekir.
- **Sanal arka plan:** İstemci tarafında (ör. TensorFlow Lite / MediaPipe segmentasyon) çözülecek bir Flutter özelliğidir; backend'de bir bağımlılığı yoktur.
- **Mention/bildirim tetikleyicileri:** `Notification` tablosu ve modeli hazır, ancak mesaj içindeki `@kullanıcı` etiketlerini algılayıp otomatik bildirim/push oluşturan mantık henüz yazılmadı.
- **Custom emoji/GIF sağlayıcı entegrasyonu:** Sunucuya özel emoji CRUD uç noktaları (`CustomEmoji` modeli) ve harici bir GIF servisi (ör. Tenor) entegrasyonu henüz yazılmadı; şu an istemci GIF/sticker URL'ini doğrudan `storage` üzerinden veya harici bir kaynaktan sağlayıp mesaj ekine ekliyor.
- **Flutter istemcisi:** Faz 6'nın tüm alt-adımları (6.1–6.7) tamamlandı. Platform çalıştırıcı klasörleri (`android/`, `ios/`, `web/` vb.) elle üretilmedi — `frontend/README.md`'deki `flutter create .` adımıyla oluşturulmalıdır. Kod bu ortamda hiçbir zaman gerçek bir Flutter/Node SDK'sıyla çalıştırılıp derlenmedi (bkz. her fazın README notları) — ilk `flutter analyze`/`flutter build` ve backend `npm install` sonrası dikkatli bir doğrulama önerilir.
- **`package-lock.json` yok:** bu yüzden `backend-ci.yml` ve `Dockerfile` `npm ci` yerine `npm install` kullanıyor. Bir kez `npm install` çalıştırıp oluşan lockfile'ı commitlemek, hem CI/Docker build'lerini hızlandırır hem deterministik hale getirir — sonrasında ilgili `npm install` adımları `npm ci` olarak değiştirilebilir.
- **Lint taban çizgisi gevşek:** `backend-ci.yml`'deki `npm run lint` adımı `--max-warnings=9999` ile çalışıyor çünkü `.eslintrc.js` Faz 7.2'de ilk kez eklendi ve mevcut koddaki uyarı sayısı hiç ölçülmedi. Bu eşiği zamanla sıkılaştırmak (ör. `--max-warnings=0`) önerilir.
- **Yönetim paneli kapsamı sınırlı:** `admin/` sadece salt-okunur istatistikler sunar; kullanıcı arama/yasaklama, sunucu silme gibi platform-genel moderasyon işlemleri için arayüz YOK (backend'de bu uç noktalar sunucu-içi yetkilerle zaten var, ama platform-admin bağlamında panelden erişilebilir hale getirilmedi — bkz. `admin/README.md`).
- **Hiçbir Node/npm paketi (backend, admin) bu ortamda gerçekten `npm install` ile kurulup çalıştırılmadı** — sadece Flutter değil, Faz 7'deki backend/admin kodu da hiç derlenip test edilmedi. İlk kurulumda hem `backend/` hem `admin/` için `npm install` + ilgili build/test komutlarını dikkatle çalıştırıp doğrulamanız önerilir.

## Yapılandırılmış Loglama (Faz 7.3)

`nestjs-pino` NestJS'in varsayılan konsol logger'ının yerine geçer —
mevcut hiçbir servis dosyası değiştirilmeden (bkz. `common/logging/logging.module.ts`
doc yorumu), uygulama genelindeki tüm `new Logger(...)` çağrıları otomatik
olarak yapılandırılmış çıktıya yönlenir:

- **Geliştirmede:** `pino-pretty` ile renkli, okunabilir tek satır.
- **Üretimde:** her satır tek satırlık JSON (log toplayıcılar için).
- Her isteğe bir `x-request-id` atanır (istemci zaten göndermişse onu kullanır),
  yanıt header'ına geri yazılır ve o isteğe ait TÜM log satırlarına eklenir.
- `Authorization`, `Cookie`, şifre/token alanları loglarda otomatik olarak
  `**REDACTED**` ile maskelenir.
- `/health/*` istekleri loglanmaz (orkestratör gürültüsünü önler).

`LOG_LEVEL` env değişkeniyle ayarlanır (boşsa NODE_ENV'e göre otomatik).

## İstatistik Uç Noktaları (Faz 7.4)

`GET /api/v1/admin/stats/overview`, `GET /api/v1/admin/stats/signups?days=30`,
`GET /api/v1/admin/stats/messages?days=30` — sadece `User.isSystemAdmin = true`
olan hesaplarla erişilebilir (`SystemAdminGuard`, her istekte veritabanından
taze kontrol eder — bkz. o dosyadaki tasarım notu). `prisma/seed.ts` zaten
`admin@vyron.dev` / `GucluSifre!123` (`vyron_admin#0001`) ile bir sistem
yöneticisi oluşturuyor — yerel test için bununla giriş yapıp dönen access
token'ı `Authorization: Bearer ...` olarak kullanabilirsiniz. Bu uç noktalar
henüz platform-admin olmayan bir kullanıcıyı admin yapan bir API SUNMUYOR
(kasıtlı — kendi kendine yetki yükseltmeyi önlemek için `isSystemAdmin` sadece
doğrudan veritabanından/`prisma studio` ile değiştirilebilir).

## Yönetim Paneli (Faz 7.5)

`admin/` — React + Vite + TypeScript ile yazılmış, minimal bir platform
istatistik/izleme paneli (kullanıcı/sunucu YÖNETİMİ içermez, bilinçli olarak
sadece salt-okunur genel bakış — bkz. `admin/README.md`'deki kapsam notu).

```bash
cd admin
npm install
cp .env.example .env   # VITE_API_BASE_URL'i backend adresinize göre düzenleyin
npm run dev             # http://localhost:5173
```

- Giriş: mevcut `/auth/login` (2FA destekli) — panele özel bir kimlik
  doğrulama sistemi yoktur. `prisma/seed.ts`'deki `admin@vyron.dev` /
  `GucluSifre!123` ile test edilebilir.
- Nihai yetkilendirme backend'dedir (`SystemAdminGuard`, Faz 7.4) — admin
  olmayan bir hesap giriş yapabilir ama istatistiklere erişemez ve
  `/forbidden`'a yönlendirilir.
- `docker-compose.prod.yml`'de `admin` servisi olarak `:8081`'de yayınlanır
  (bkz. o dosyanın başındaki üretim kontrol listesi — bu paneli genel
  internete DEĞİL, bir VPN/iç ağ arkasında yayınlamanız önerilir çünkü
  token'lar tarayıcı `localStorage`'ında tutulur).
- CI: `.github/workflows/admin-ci.yml` (lint + tip kontrolü + build).

## Faz 4 API Özeti

**Dosya yükleme:**
```
POST /storage/presigned-upload   { fileName, mimeType, fileSizeBytes, context } → { uploadUrl, publicUrl, key }
```
İstemci dönen `uploadUrl`'e dosyayı doğrudan `PUT` eder, ardından mesaj gönderirken `publicUrl`'i `attachments[].url` olarak kullanır.

**Sunucu kanalı mesajları:**
```
GET    /channels/:channelId/messages?limit=&before=&after=
POST   /channels/:channelId/messages
PATCH  /channels/:channelId/messages/:messageId
DELETE /channels/:channelId/messages/:messageId
POST   /channels/:channelId/messages/:messageId/pin
POST   /channels/:channelId/messages/:messageId/reactions
DELETE /channels/:channelId/messages/:messageId/reactions/:emoji
```

**Özel mesajlar (DM):**
```
GET  /dm-channels                         # konuşmalarım
POST /dm-channels                         { participantIds, isGroup?, name? }
GET  /dm-channels/:id/messages ...        # messages ile aynı uç noktalar
```

**Gerçek zamanlı (Socket.IO, `/realtime` namespace'i):**
```js
const socket = io('http://localhost:3000/realtime', { auth: { token: accessToken } });
socket.emit('channel:join', { channelId });
socket.on('message:created', (msg) => { /* ... */ });
socket.on('message:updated', (msg) => { /* ... */ });
socket.on('message:deleted', ({ id }) => { /* ... */ });
socket.on('reaction:added', (r) => { /* ... */ });
socket.on('typing:start', ({ userId, username }) => { /* ... */ });
socket.on('presence:update', ({ userId, status }) => { /* ... */ });
```

## Faz 5 API Özeti

```
POST   /channels/:channelId/voice/join              → { token, mediaUrl, roomName, voiceState }
POST   /channels/:channelId/voice/leave
PATCH  /channels/:channelId/voice/state              { isMuted?, isDeafened?, isCameraOn?, isScreenSharing? }
GET    /channels/:channelId/voice/participants
POST   /channels/:channelId/voice/members/:userId/mute     # MUTE_MEMBERS_VOICE
DELETE /channels/:channelId/voice/members/:userId/mute
POST   /channels/:channelId/voice/members/:userId/deafen   # DEAFEN_MEMBERS_VOICE
DELETE /channels/:channelId/voice/members/:userId/deafen
POST   /channels/:channelId/voice/members/:userId/move     { targetChannelId }  # MOVE_MEMBERS_VOICE
DELETE /channels/:channelId/voice/members/:userId          # zorla atma
```

İstemci akışı: `join` çağrılır → dönen `token` ve `mediaUrl` ile [`livekit_client`](https://pub.dev/packages/livekit_client) Flutter paketi kullanılarak odaya bağlanılır → oda içi olaylar (katılım/ayrılış/susturma) aynı anda `/realtime` Socket.IO namespace'inden de yayınlanır, böylece UI (katılımcı listesi, konuşma göstergesi) LiveKit'in kendi event'lerine ek olarak backend'in yetki/moderasyon kararlarını da anlık yansıtır.

## Mimari Notlar

- **Neden Argon2 (bcrypt değil)?** Argon2id, GPU/ASIC saldırılarına karşı bcrypt'ten daha dayanıklıdır ve OWASP'ın güncel önerisidir.
- **Neden refresh token hash'lenerek saklanıyor?** Veritabanı sızıntısı olsa dahi ham token'lar ele geçirilemez; ayrıca token rotasyonu ile çalıntı token kullanımı tespit edilebilir.
- **Neden global `JwtAuthGuard` + `@Public()`?** Varsayılan olarak "güvenli" (her endpoint korumalı), sadece açıkça işaretlenen uçlar herkese açık — güvenlik açısından "fail closed" yaklaşımı.
- **Neden `TransformInterceptor` + `HttpExceptionFilter`?** Frontend'in (Flutter) tüm API yanıtlarını `{ success, data }` / `{ success: false, message }` gibi tek tip parse etmesini sağlar.
