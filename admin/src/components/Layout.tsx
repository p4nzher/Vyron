import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export function Layout({ children }: { children: ReactNode }) {
  const { logout } = useAuth();
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    navigate('/login', { replace: true });
  }

  return (
    <div style={{ minHeight: '100%' }}>
      <header
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '16px 24px',
          borderBottom: '1px solid var(--glass-border)',
          background: 'var(--bg-secondary)',
        }}
      >
        <div style={{ fontSize: 16, fontWeight: 700 }}>
          <span className="brand-gradient-text">Vyron</span> Yönetim Paneli
        </div>
        <button
          onClick={handleLogout}
          className="text-field"
          style={{ width: 'auto', cursor: 'pointer', background: 'var(--bg-elevated)' }}
        >
          Çıkış Yap
        </button>
      </header>
      <main style={{ padding: 24, maxWidth: 1100, margin: '0 auto' }}>{children}</main>
    </div>
  );
}
