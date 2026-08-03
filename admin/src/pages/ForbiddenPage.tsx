import { useAuth } from '../contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

export function ForbiddenPage() {
  const { logout } = useAuth();
  const navigate = useNavigate();

  return (
    <div
      style={{ minHeight: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}
    >
      <div className="glass-card" style={{ padding: 32, maxWidth: 420, textAlign: 'center' }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>🔒</div>
        <h1 style={{ fontSize: 18, margin: '0 0 8px' }}>Yetkin Yok</h1>
        <p style={{ color: 'var(--text-secondary)', fontSize: 14, marginBottom: 24 }}>
          Bu hesap bir sistem yöneticisi (<code>isSystemAdmin</code>) değil. Yönetim paneline erişmek için
          yöneticinizden hesabınızı yükseltmesini isteyin.
        </p>
        <button
          className="btn-primary"
          onClick={() => {
            logout();
            navigate('/login', { replace: true });
          }}
        >
          Farklı bir hesapla giriş yap
        </button>
      </div>
    </div>
  );
}
