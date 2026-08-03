# Vyron — Marka Kimliği & Tasarım Token'ları

Logodaki mor→mavi gradyan ve koyu lacivert zemin, tüm platformun (Flutter istemcisi
dahil) tasarım dilinin temelidir. Bu dosya, Faz 6'da Flutter `ThemeData`'sına
birebir aktarılacak referans kaynağıdır.

## Renk Paleti

| Token | Hex | Kullanım |
|---|---|---|
| `background.primary` | `#0A0A14` | Ana zemin (koyu tema varsayılan) |
| `background.secondary` | `#12121F` | Kartlar, kenar çubuğu, modal zemin |
| `background.elevated` | `#1A1A2C` | Yükseltilmiş yüzeyler (glassmorphism alt katmanı) |
| `brand.gradient.start` | `#9F7AEA` | Gradyan başlangıcı (mor/lavanta) — logo üst-sol |
| `brand.gradient.end` | `#4C5FD5` | Gradyan bitişi (indigo/mavi) — logo alt-sağ |
| `brand.accent` | `#E9E4FF` | Sparkle/vurgu, aktif durum ışıması |
| `text.primary` | `#F5F5FA` | Ana metin |
| `text.secondary` | `#9B9BB0` | İkincil metin, zaman damgaları |
| `status.online` | `#4ADE80` | Çevrimiçi göstergesi |
| `status.idle` | `#FBBF24` | Meşgul/Uzakta göstergesi |
| `status.dnd` | `#F87171` | Rahatsız Etmeyin göstergesi |
| `status.offline` | `#5B5B6E` | Çevrimdışı/Görünmez göstergesi |

## Ana Gradyan (marka imzası)

```
linear-gradient(135deg, #9F7AEA 0%, #4C5FD5 100%)
```
Kullanım alanları: birincil butonlar, aktif sekme göstergesi, avatar çerçevesi
(çevrimiçi durumda), giriş/kayıt ekranı arka plan aksanı, uygulama logosu.

## Glassmorphism Kuralları

- Blur: 20–24px
- Zemin opaklığı: `background.elevated` üzerine %6–10 beyaz overlay
- Kenarlık: 1px, `rgba(255,255,255,0.08)`
- Gölge: yumuşak, geniş yayılımlı, `rgba(79,70,229,0.15)` (marka rengine yakın, siyah değil)

## Tipografi

- Başlıklar: Inter / Manrope (Bold, geniş tracking değil — sıkı ve modern)
- Gövde metni: Inter (Regular/Medium)
- Kod/monospace (sistem mesajları, ID'ler): JetBrains Mono

## Animasyon Hissi

- Geçişler: 200–280ms, `easeOutCubic`
- Sayfa/ekran geçişleri: hafif scale (0.96→1.0) + fade, Discord'daki sert slide yerine
  daha "premium" bir yumuşaklık hedeflenir
- Sesli odaya katılımda: avatar çevresinde gradyan halkanın nabız gibi genişleyip
  daralması (konuşma algılaması ile senkron)
