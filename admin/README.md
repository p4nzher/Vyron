# Vyron — Yönetim Paneli (Faz 7.5)

React + Vite + TypeScript tabanlı, minimal bir platform istatistik/izleme
paneli. Bilinçli olarak KAPSAMLI bir yönetim arayüzü DEĞİLDİR — kullanıcı/
sunucu/mesaj CRUD'u içermez (bu işlevler zaten Flutter istemcisinde
moderasyon ekranları olarak var, bkz. `frontend/README.md` Faz 6.6). Bu
panelin amacı: `/admin/stats/**` (Faz 7.4) üzerinden platformun genel
sağlığını tek bakışta görmek.

## Kurulum

```bash
cd admin
npm install
cp .env.example .env
# .env içindeki VITE_API_BASE_URL'i backend adresinize göre düzenleyin.
npm run dev
```

Giriş için `prisma/seed.ts` ile oluşturulan sistem yöneticisini kullanabilirsiniz:
`admin@vyron.dev` / `GucluSifre!123`.

## Nasıl Çalışır

- Giriş, backend'in mevcut `/auth/login` uç noktasını kullanır — panele özel
  bir kimlik doğrulama sistemi YOKTUR. Dönen `accessToken`/`refreshToken`
  tarayıcının `localStorage`'ında tutulur (bkz. `src/lib/tokenStorage.ts`
  içindeki güvenlik notu — bu bilinçli bir basitleştirmedir, `httpOnly`
  cookie kadar güvenli değildir).
- `isSystemAdmin` bilgisi login yanıtında YOKTUR (bkz. backend `PublicUser`
  tipi) — bu bilinçli: admin olmayan biri paneline giriş yapabilir ama
  `/admin/stats/**` çağrıları `SystemAdminGuard` tarafından 403 ile
  reddedilir ve kullanıcı `/forbidden` sayfasına yönlendirilir. Nihai
  yetkilendirme HER ZAMAN backend'dedir; bu istemci sadece iyi bir kullanıcı
  deneyimi sağlar.
- Access token süresi dolduğunda (`401`), istemci OTOMATİK olarak bir kez
  `refresh` dener ve isteği tekrarlar — bkz. `src/lib/apiClient.ts`.

## Bilinen sınırlamalar

- **Kullanıcı/sunucu yönetimi YOK** — sadece salt-okunur istatistikler.
  Genişletilecekse doğal aday uç noktalar: kullanıcı arama/yasaklama,
  sunucu listesi/silme (backend'de zaten var olan `/users`, `/servers`,
  `/servers/:id/moderation/**` uç noktaları platform-admin bağlamında
  yeniden kullanılabilir — ama bu, backend'de o uç noktaların
  `SystemAdminGuard` ile de erişilebilir olacak şekilde ayrıca
  düzenlenmesini gerektirir, şu an sadece sunucu-içi yetkilerle çalışıyorlar).
- **Gerçek zamanlı değil** — istatistikler sayfa yenilenince/her
  `useEffect` tetiklendiğinde tazelenir, otomatik polling veya Socket.IO
  entegrasyonu yok.
- **`localStorage` token saklama** — bkz. yukarıdaki güvenlik notu. Bu
  paneli genel internete DEĞİL, bir VPN/iç ağ arkasında yayınlayın.
- Bu proje hiçbir zaman gerçek bir Node/npm ortamında çalıştırılıp
  derlenmedi (bu ortamda araç yok) — ilk `npm install && npm run build`
  sonrası dikkatli bir doğrulama önerilir.

## Docker

```bash
docker build -t vyron-admin --build-arg VITE_API_BASE_URL=https://api.vyron.example ./admin
docker run -p 8081:80 vyron-admin
```

Ya da kök dizindeki `docker-compose.prod.yml` ile tüm stack'in parçası
olarak (bkz. kök `README.md` — "Docker ile Çalıştırma").
