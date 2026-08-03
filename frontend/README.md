# Vyron — Flutter İstemcisi

## Kurulum

Bu klasör, `flutter create` tarafından üretilen platform çalıştırıcı
(android/ios/windows/macos/web) klasörlerini İÇERMEZ — bunlar makine
üzerinde kurulu Flutter SDK sürümüne göre üretilmesi gerektiğinden elle
yazılmadı. İlk kurulum:

```bash
cd frontend
flutter create --org com.vyron --project-name vyron --platforms=android,ios,windows,macos,web .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000/api/v1 --dart-define=SOCKET_BASE_URL=http://localhost:3000
```

> `flutter create .` mevcut `lib/`, `pubspec.yaml` ve `analysis_options.yaml`
> dosyalarınızın ÜZERİNE YAZMAZ; sadece eksik platform klasörlerini ekler.

Android emülatörde backend'e erişim için `10.0.2.2` kullanılmalıdır:
```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1 --dart-define=SOCKET_BASE_URL=http://10.0.2.2:3000
```

Kod üretimi gereken paketler eklendiğinde (freezed/json_serializable, Faz 6.2+):
```bash
dart run build_runner build --delete-conflicting-outputs
```

## Mimari Kararları

- **Durum yönetimi:** Riverpod (`flutter_riverpod`) — test edilebilirlik ve
  provider-bazlı DI için. `GetIt` sadece Dio/SecureStorage gibi çapraz-kesit
  singleton'lar için kullanılır (bkz. `core/di/service_locator.dart`);
  özellik katmanları bunları Riverpod provider'ları üzerinden tüketir.
- **Yönlendirme:** `go_router`, deep-link ve web URL senkronizasyonu için.
- **Katmanlar:** `core/` (paylaşılan altyapı: tema, ağ, depolama, widget'lar)
  ve `features/<isim>/{data,domain,presentation}` (özellik-bazlı Clean
  Architecture — backend'deki modül yapısıyla birebir örtüşür: `auth`,
  `messages`, `dm`, `voice`, `servers`...).
- **Tema:** `docs/brand.md` içindeki token'ların birebir Flutter karşılığı
  `core/theme/` altında. Tek tema koyu temadır (`AppTheme.dark`).
- **Ağ katmanı:** Tek bir `ApiClient` (Dio), otomatik JWT ekleme + 401'de
  sessiz refresh-token rotasyonu ile (bkz. `core/network/api_client.dart`).

## Faz 6 Alt-Adım Planı

**Faz 6'nın tüm alt-adımları (6.1 → 6.7) tamamlandı.** Aşağıdaki liste,
her adımın neyi kapsadığının ve bilinen sınırlamalarının kaydını tutar —
`flutter create .` sonrası ilk `flutter analyze` bu depoda hiç
çalıştırılamadığı için (bkz. Kurulum), yeni bir faza geçmeden önce her
alt-adımın notlarını gözden geçirmeniz önerilir.

- [x] **6.1 — Proje İskeleti** ✅ Bu paket
  - `pubspec.yaml`, tema sistemi (`AppColors`/`AppTextStyles`/`AppTheme`/`AppMotion`)
  - Paylaşılan widget'lar: `GlassContainer`, `GradientButton`, `AppTextField`, `StatusDot`/`GradientAvatarRing`
  - `ApiClient` (Dio + otomatik token yenileme), `SecureStorageService`, `GetIt` DI
  - `go_router` iskeleti + **uçtan uca çalışan** kayıt/giriş ekranları (gerçek backend'e bağlı, 2FA akışı dahil)
  - Geçici "giriş başarılı" ekranı (Faz 6.3'e kadar `/home` yer tutucusu)
- [x] **6.2 — Oturum Durumu & Kalıcı Auth** ✅ — Riverpod `AuthController` (app açılışında token doğrulama/otomatik giriş), şifre sıfırlama ekranı, 2FA kurulum ekranı (QR kod), profil düzenleme
- [x] **6.3 — Ana Kabuk (Shell)** ✅ — `features/servers` ve `features/dm` (gerçek `GET /servers`, `GET /servers/:id`, `GET /dm-channels` uçlarına bağlı repository + provider'lar) üzerine kurulu, `go_router` yol parametreleriyle durumu URL'de tutan responsive 3 sütunlu düzen (sunucu rayı + kanal/DM listesi + içerik başlığı). ≥860px'te sabit üç sütun; altında rayın `Drawer`'a taşındığı, geri okuyla gezinilen tek sütunlu mobil görünüm. Mesaj listesi/input Faz 6.4'te bu iskelete bağlandı.
- [x] **6.4 — Mesajlaşma** ✅ — `features/messages`: `MessageScope` (kanal/DM tekilleştirme) üzerine kurulu `MessagesRepository` (imleç tabanlı sayfalama, CRUD, sabitleme, tepkiler) + `SocketService` (`core/realtime`, `/realtime` ad alanı — `message:*`/`reaction:*`/`typing:*`/`presence:*` olayları) + `MessagesController` (Riverpod `StateNotifier.autoDispose.family`: iyimser/optimistic gönderim, sayfalama, socket senkronizasyonu, "yazıyor..." göstergesi). Arayüz: sonsuz kaydırmalı `MessageList` (yazar gruplama), `MessageBubble` (yanıt önizlemesi, düzenle/sil/sabitle/tepki menüsü, ek gösterimi), `MessageInput` (emoji seçici, görsel/dosya eki — presigned upload, sesli not kaydı — `record` paketi, yanıt/düzenleme çubukları). `ContentPanel` artık yer tutucu değil, gerçek `MessageScope`'a bağlı.
- [x] **6.5 — Sesli/Görüntülü Görüşme** ✅ — `features/voice`: `VoiceRepository` (`voice.controller.ts` ile birebir — katıl/ayrıl/durum/katılımcılar/moderasyon uçları) + `VoiceCallController` (`livekit_client` `Room` sarmalayıcısı — mikrofon/kamera/ekran paylaşımı, "sağırlaştırma" — LiveKit'te doğal karşılığı olmayan, `RemoteTrackPublication.setSubscribed(false)` ile istemci tarafında uygulanan bir davranış). **Kasıtlı olarak Faz 6.4'ün aksine GLOBAL/tekil bir provider** (`autoDispose` DEĞİL): Discord'daki gibi görüşme, başka bir kanala/sunucuya geçilse bile kopmaz. Arayüz: `VoiceChannelPanel` (katıl-öncesi roster önizlemesi + "Katıl"), `VoiceCallScreen` (katılımcı ızgarası + kontrol çubuğu), `VoiceCallBar` (uygulamanın HER ekranında görünen kalıcı alt çubuk — `HomeShellScreen`'in 4 `Scaffold` dalına da `bottomNavigationBar` olarak eklendi), `ParticipantTile` (video/ekran paylaşımı > avatar önceliği, konuşma/susturma rozetleri). Bir moderatör kullanıcıyı başka bir sesli kanala taşıdığında (`voice:you-were-moved`) istemci OTOMATİK olarak yeni kanala yeniden bağlanır.
- [x] **6.6 — Sunucu/Kanal/Rol Yönetimi** ✅ — `features/servers` genişletildi: `ServersRepository` (create/update/delete/leave/listMembers), yeni `ChannelsRepository`, `RolesRepository`, `InvitesRepository`, `ModerationRepository`, `AuditLogRepository` — hepsi backend uç noktalarıyla (`channels`/`roles`/`invites`/`moderation`/`audit-log` controller'ları) birebir. `ServerDetail` artık rolleri de taşıyor. `MemberPermissions` (`domain/server_permissions.dart`), backend `permissions.util.ts`'nin istemci karşılığı: sahiplik + rol OR'u + `ADMINISTRATOR` bypass'ını taklit eder — **sadece UI'da yönetim ekranlarını göstermek/gizlemek için**, nihai yetkilendirme her zaman backend'de. Arayüz: rayın "+" butonuna bağlı `CreateOrJoinServerSheet` (sunucu oluştur / davetle katıl), dişli ikonuna bağlı `ServerSettingsScreen` (yeni `/home/servers/:serverId/settings` rotası) — kullanıcının etkin yetkisine göre gösterilen sekmeler: Genel Bakış (isim/açıklama düzenleme, sil/ayrıl), Kanallar (oluştur/düzenle/sil/yukarı-aşağı sıralama), Roller (renk/yetki toggle'larıyla tam editör), Davetler (limit/süre seçenekleriyle oluştur, kopyala, iptal et), Üyeler (rol atama chip'leri + moderasyon aksiyon sayfası: uyar/sustur/at/yasakla/geçmiş), Yasaklılar, Denetim Kaydı.
- [x] **6.7 — Arkadaşlar, Bildirimler, Ayarlar** ✅ — yeni `features/friends`: `FriendsRepository` (`friends.controller.ts` ile birebir — istek gönder/kabul/reddet/iptal, kaldır, engelle/engeli kaldır) + `FriendsScreen` (Çevrimiçi/Bekleyen/Tümü/Engellenenler sekmeleri, rozet sayaçlı) + `AddFriendSheet` (`kullaniciadi#0000` etiketiyle istek gönderme). Arkadaş listesinden "Mesaj Gönder", `DmRepository.createOrGet` (yeni `POST /dm-channels`) ile DM'i açar/oluşturur. `DmListPanel`'in üstüne bekleyen istek rozetli bir "Arkadaşlar" girişi eklendi.
  Bildirimler: yeni `features/notifications` — `NotificationsController` (GLOBAL provider, `VoiceCallController` ile aynı mimari) kullanıcının TÜM DM'lerine ve metin kanallarına PASİF olarak katılır (`SocketService.joinDm`/`joinChannel` — `MessagesController`'ın sadece o an açık kanalı dinleyen AKTİF katılımından bağımsız) ve `message:created` olaylarını okunmamış rozetine + `flutter_local_notifications` ile yerel bildirime çevirir. `ActiveScopeReporter` (`ContentPanel`'e bağlı) o an açık kapsamı bildirir, böylece izlenen kanal/DM'den bildirim gelmez. Okunmamış rozetleri: DM listesi, kanal listesi, ray'deki DM ikonu (toplam). `ContentPanel`'deki eski üye-listesi ikonu artık `ServerSettingsScreen`'e yönlendiriyor (Faz 6.6'da kalan bir boşluk kapatıldı).
  Ayarlar: yeni `SettingsScreen` (ray'deki avatara dokununca açılır) — profil linki, 2FA aç/kapa, engellenen kullanıcılar linki, "tüm cihazlardan çıkış yap" (yeni `AuthRepository.logoutAllDevices`/`AuthController.logoutEverywhere`, `POST /auth/logout-all`), bildirim tercihleri (`NotificationPrefsController` — `shared_preferences` ile CİHAZA özel ses/popup tercihleri), çıkış yap.

### 6.7 notları / bilinen sınırlamalar

- **Gerçek push bildirimi YOK.** `NotificationsController`/`NotificationService` sadece uygulama açıkken (ön planda ya da arka planda çalışırken, Socket.IO bağlantısı canlıyken) yerel bildirim gösterir. Uygulama tamamen kapalıyken bildirim almak için backend'de bir cihaz-token kayıt tablosu ve FCM (Android)/APNs (iOS) entegrasyonu gerekir — bu depoda henüz yok. `SettingsScreen`'deki bildirim bölümünde bu sınırlama kullanıcıya da açıkça belirtiliyor.
- Arkadaşlık istekleri gerçek zamanlı DEĞİL — `MessagesGateway` her bağlantıyı kişisel bir `user:<id>` odasına alıyor ve bu oda tam olarak bu amaç için ayrılmış görünüyor, ama `FriendsService` şu an bu odaya hiçbir olay yayınlamıyor. `FriendsScreen` her açıldığında REST üzerinden tazeleniyor; gerçek zamanlı anlık güncelleme için backend'e `friend:request-received`/`friend:request-accepted` gibi olayların eklenmesi gerekir.
- Okunmamış rozetleri sadece bu OTURUM için bellekte tutulur (`NotificationsState` — kalıcı depolama yok); uygulama yeniden başlatıldığında sıfırlanır.
- Arkadaş listesindeki/DM'lerdeki çevrimiçi durum noktaları `presence:update` soket olayına gerçek zamanlı bağlı DEĞİL — sadece ilgili REST çağrısındaki anlık durumu gösterir (bu olay zaten sunucu-üyeliği odalarına yayınlanıyor ama tüketen bir global önbellek henüz yok).
- Hesap silme akışı yok — backend'de böyle bir uç nokta bulunmuyor, bu yüzden Ayarlar'a kasıtlı olarak eklenmedi.

### 6.4 notları / bilinen sınırlamalar

- Sesli not kaydı (`record` paketi) şimdilik sadece `!kIsWeb` platformlarında aktif; web'de dosya-yolu tabanlı kayıt akışı Faz 6.5'teki LiveKit entegrasyonuyla birlikte ele alınacak.
- GIF/sticker seçici arayüzü yok — backend `AttachmentType.GIF`/`STICKER` ve `Message` modeli hazır, `AttachmentView` bu türleri görsel gibi render eder; seçici Faz 6.7'de (özel emoji/sticker yönetimiyle birlikte) eklenebilir.
- Mesaj içeriği düz metin olarak render edilir; Markdown (kalın/italik/kod bloğu) desteği kapsam dışı bırakıldı.
- `messagesControllerProvider` bilinçli olarak `autoDispose` — kanal/DM değiştirildiğinde eski Socket.IO odasından çıkılır (`channel:leave`/`dm:leave`) ve dinleyiciler iptal edilir; aksi halde soket tüm ziyaret edilen odalarda sonsuza dek asılı kalırdı.

### 6.5 notları / bilinen sınırlamalar

- `livekit_client` API yüzeyi (`Room`, `Participant.isMicrophoneEnabled()`, `RemoteTrackPublication.setSubscribed()` vb.) bu ortamda `flutter pub get`/`flutter analyze` ÇALIŞTIRILAMADIĞI için resmi LiveKit Flutter SDK dokümantasyonu ve GitHub kaynak koduyla tek tek doğrulandı; yine de `flutter create .` sonrası ilk `flutter analyze`'da bu dosyalara (`features/voice/presentation/controllers/voice_call_providers.dart`) özellikle bakmanızı öneririz.
- "Sağırlaştırma" (deafen) LiveKit'in doğal bir kavramı DEĞİLDİR — uzak katılımcıların ses parçalarından abone kaldırılarak (`setSubscribed(false)`) taklit edilir. Diğer katılımcılara "sağırlaştırılmış" rozetini göstermek tamamen bizim `VoiceState.isDeafened` alanımıza (REST + `voice:state-updated`/`voice:force-deafened`) dayanır.
- Ekran paylaşımı Android'de bir foreground service, iOS'ta bir broadcast extension gerektirir (LiveKit'in kendi platform kurulum adımları — `frontend/README.md` `flutter create .` sonrası bu adımları LiveKit'in resmi kurulum kılavuzundan tamamlamanız gerekir).
- Katılımcı ızgarası basit bir grid (1/2/3 sütun); konuşan kişiyi büyütme, sabitleme (pin) gibi gelişmiş düzenler kapsam dışı bırakıldı.
- Moderasyon menüsü (zorla sustur/at) her zaman gösterilir — sunucu yetkiyi (`MUTE_MEMBERS_VOICE`/`MOVE_MEMBERS_VOICE`) zaten reddediyor, ama Faz 6.6'daki rol/izin verisi istemciye ulaştığında düğmeler yetkisiz kullanıcılar için önceden gizlenebilir.
