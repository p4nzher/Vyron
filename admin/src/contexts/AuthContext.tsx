import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';
import { clearTokens, isLoggedIn as checkIsLoggedIn, setTokens } from '../lib/tokenStorage';
import { login as loginRequest, type PublicUser } from '../lib/authApi';

interface AuthContextValue {
  isAuthenticated: boolean;
  user: PublicUser | null;
  login: (email: string, password: string, twoFactorCode?: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);

/**
 * `SystemAdminGuard` nihai yetkilendirmeyi backend'de yapar (bkz. Faz 7.4) —
 * bu context sadece "giriş yapılmış mı" bilgisini tutar. `isSystemAdmin`
 * bilgisi login yanıtında YOK (bkz. `PublicUser` — backend'de bilinçli
 * olarak eklenmedi, admin olmayan hiçbir istemcinin bunu görmesine gerek
 * yok). Yetkisiz bir kullanıcı giriş yapabilir ama `/admin/stats/**`
 * çağrıları 403 döner — bkz. `DashboardPage`'deki hata işleme.
 */
export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(checkIsLoggedIn());
  const [user, setUser] = useState<PublicUser | null>(null);

  const login = useCallback(async (email: string, password: string, twoFactorCode?: string) => {
    const result = await loginRequest(email, password, twoFactorCode);
    setTokens(result.tokens.accessToken, result.tokens.refreshToken);
    setUser(result.user);
    setIsAuthenticated(true);
  }, []);

  const logout = useCallback(() => {
    clearTokens();
    setUser(null);
    setIsAuthenticated(false);
  }, []);

  const value = useMemo(() => ({ isAuthenticated, user, login, logout }), [isAuthenticated, user, login, logout]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth, AuthProvider içinde kullanılmalıdır.');
  return ctx;
}
