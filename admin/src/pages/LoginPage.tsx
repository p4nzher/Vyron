import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { ApiError } from '../lib/apiClient';

export function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [twoFactorCode, setTwoFactorCode] = useState('');
  const [needsTwoFactor, setNeedsTwoFactor] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setIsSubmitting(true);
    try {
      await login(email, password, needsTwoFactor ? twoFactorCode : undefined);
      navigate('/', { replace: true });
    } catch (err) {
      if (err instanceof ApiError && err.errorCode === 'TWO_FACTOR_REQUIRED') {
        setNeedsTwoFactor(true);
        setError('İki faktörlü doğrulama kodunu girin.');
      } else if (err instanceof ApiError) {
        setError(err.message);
      } else {
        setError('Beklenmeyen bir hata oluştu.');
      }
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div
      style={{
        minHeight: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
      }}
    >
      <form onSubmit={handleSubmit} className="glass-card" style={{ width: 380, padding: 32 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>
          <span className="brand-gradient-text">Vyron</span> Yönetim Paneli
        </h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: 13, marginTop: 8, marginBottom: 24 }}>
          Sadece sistem yöneticileri (<code>isSystemAdmin</code>) erişebilir.
        </p>

        {error && (
          <div className="error-banner" style={{ marginBottom: 16 }}>
            {error}
          </div>
        )}

        <label style={{ display: 'block', fontSize: 13, marginBottom: 6, color: 'var(--text-secondary)' }}>
          E-posta
        </label>
        <input
          type="email"
          required
          autoFocus
          className="text-field"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="admin@vyron.dev"
          style={{ marginBottom: 16 }}
        />

        <label style={{ display: 'block', fontSize: 13, marginBottom: 6, color: 'var(--text-secondary)' }}>
          Şifre
        </label>
        <input
          type="password"
          required
          className="text-field"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          placeholder="••••••••"
          style={{ marginBottom: needsTwoFactor ? 16 : 24 }}
        />

        {needsTwoFactor && (
          <>
            <label style={{ display: 'block', fontSize: 13, marginBottom: 6, color: 'var(--text-secondary)' }}>
              2FA Kodu
            </label>
            <input
              type="text"
              required
              inputMode="numeric"
              maxLength={6}
              className="text-field mono"
              value={twoFactorCode}
              onChange={(e) => setTwoFactorCode(e.target.value)}
              placeholder="123456"
              style={{ marginBottom: 24, letterSpacing: 4 }}
            />
          </>
        )}

        <button type="submit" className="btn-primary" disabled={isSubmitting} style={{ width: '100%' }}>
          {isSubmitting ? 'Giriş yapılıyor…' : 'Giriş Yap'}
        </button>
      </form>
    </div>
  );
}
