// Faz 7.5 — Bu bir DAHİLİ yönetim aracıdır (mobil istemcinin aksine, bkz.
// `frontend/lib/core/storage/secure_storage_service.dart` — orada
// flutter_secure_storage kullanılır). Burada tarayıcının `localStorage`'ı
// kullanılıyor; bu, XSS'e karşı `httpOnly` cookie kadar dayanıklı DEĞİLDİR,
// ama backend token'ları zaten JSON gövdesinde döndürüyor (cookie tabanlı
// değil — bkz. `auth.controller.ts`), bu yüzden başka bir seçenek de yok.
// Üretimde bu paneli SADECE güvenilir bir ağda/VPN arkasında ya da ek bir
// reverse-proxy kimlik doğrulaması katmanıyla yayınlamanız önerilir.

const ACCESS_TOKEN_KEY = 'vyron_admin_access_token';
const REFRESH_TOKEN_KEY = 'vyron_admin_refresh_token';

export function getAccessToken(): string | null {
  return localStorage.getItem(ACCESS_TOKEN_KEY);
}

export function getRefreshToken(): string | null {
  return localStorage.getItem(REFRESH_TOKEN_KEY);
}

export function setTokens(accessToken: string, refreshToken: string): void {
  localStorage.setItem(ACCESS_TOKEN_KEY, accessToken);
  localStorage.setItem(REFRESH_TOKEN_KEY, refreshToken);
}

export function clearTokens(): void {
  localStorage.removeItem(ACCESS_TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
}

export function isLoggedIn(): boolean {
  return getAccessToken() !== null;
}
