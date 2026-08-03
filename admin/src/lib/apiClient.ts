import { clearTokens, getAccessToken, getRefreshToken, setTokens } from './tokenStorage';

const API_BASE = `${import.meta.env.VITE_API_BASE_URL}/api/v1`;

/** Backend'in `HttpExceptionFilter`'indan donen tutarli hata govdesi. */
interface ApiErrorBody {
  success: false;
  statusCode: number;
  message: string | string[];
  errorCode?: string;
}

/** Backend'in `TransformInterceptor`'indan donen tutarli basari zarfi. */
interface ApiSuccessBody<T> {
  success: true;
  data: T;
  timestamp: string;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly errorCode?: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

let refreshInFlight: Promise<boolean> | null = null;

/** `/auth/refresh` - basarisizsa token'lari temizler ve false doner (cagiran taraf login'e yonlendirmeli). */
async function tryRefreshToken(): Promise<boolean> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) return false;

  try {
    const res = await fetch(`${API_BASE}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    });
    if (!res.ok) {
      clearTokens();
      return false;
    }
    const body = (await res.json()) as ApiSuccessBody<{ accessToken: string; refreshToken: string }>;
    setTokens(body.data.accessToken, body.data.refreshToken);
    return true;
  } catch {
    clearTokens();
    return false;
  }
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'DELETE';
  body?: unknown;
  /** Dahili kullanim - 401 sonrasi tek seferlik refresh+retry icin. */
  _isRetry?: boolean;
}

/**
 * Tum admin panel API cagrilarinin gectigi tek nokta.
 * - Access token'i otomatik ekler.
 * - 401 alirsa BIR KEZ `refresh` dener, basariliysa istegi tekrarlar;
 *   basarisizsa token'lari temizler ve cagiran tarafin login'e yonlendirmesi
 *   icin `ApiError(401)` firlatir (bkz. `AuthContext` - global 401 dinleyicisi).
 * - Basari zarfini (`{ success, data }`) otomatik acar; sadece `data` doner.
 */
export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const token = getAccessToken();
  const res = await fetch(`${API_BASE}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: options.body !== undefined ? JSON.stringify(options.body) : undefined,
  });

  if (res.status === 401 && !options._isRetry) {
    // Ayni anda birden fazla istek 401 alirsa, hepsi TEK bir refresh
    // cagrisini paylasir (istek firtinasi / thundering herd onlenir).
    refreshInFlight ??= tryRefreshToken().finally(() => {
      refreshInFlight = null;
    });
    const refreshed = await refreshInFlight;
    if (refreshed) {
      return apiFetch<T>(path, { ...options, _isRetry: true });
    }
    throw new ApiError('Oturum suresi doldu, lutfen tekrar giris yapin.', 401);
  }

  if (!res.ok) {
    let body: ApiErrorBody | null = null;
    try {
      body = (await res.json()) as ApiErrorBody;
    } catch {
      // JSON olmayan bir hata govdesi (or. 502 - proxy hatasi)
    }
    const message = Array.isArray(body?.message) ? body.message.join(', ') : body?.message;
    throw new ApiError(message || `Istek basarisiz oldu (${res.status}).`, res.status, body?.errorCode);
  }

  const body = (await res.json()) as ApiSuccessBody<T>;
  return body.data;
}
