import { Link } from 'react-router-dom';

export function NotFoundPage() {
  return (
    <div style={{ minHeight: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontSize: 40, marginBottom: 12 }}>🧭</div>
        <h1 style={{ fontSize: 18, margin: '0 0 8px' }}>Sayfa bulunamadı</h1>
        <Link to="/" style={{ color: 'var(--brand-end)' }}>
          Panele dön
        </Link>
      </div>
    </div>
  );
}
