import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Layout } from '../components/Layout';
import { StatCard } from '../components/StatCard';
import { TimeseriesChart } from '../components/TimeseriesChart';
import { ApiError } from '../lib/apiClient';
import { getDailyMessages, getDailySignups, getOverview, type DailyCount, type StatsOverview } from '../lib/statsApi';
import { useAuth } from '../contexts/AuthContext';

/**
 * `/admin/stats/**`'e 403 dönerse (kullanıcı giriş yapmış ama
 * `isSystemAdmin` değil) `/forbidden`'a yönlendirir; 401 dönerse (refresh de
 * başarısız oldu) oturumu temizleyip `/login`'e yönlendirir — bkz.
 * `apiClient.ts`'deki tek-seferlik otomatik refresh mantığı.
 */
export function DashboardPage() {
  const navigate = useNavigate();
  const { logout } = useAuth();

  const [overview, setOverview] = useState<StatsOverview | null>(null);
  const [signups, setSignups] = useState<DailyCount[]>([]);
  const [messages, setMessages] = useState<DailyCount[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setIsLoading(true);
      setError(null);
      try {
        const [overviewData, signupsData, messagesData] = await Promise.all([
          getOverview(),
          getDailySignups(30),
          getDailyMessages(30),
        ]);
        if (cancelled) return;
        setOverview(overviewData);
        setSignups(signupsData);
        setMessages(messagesData);
      } catch (err) {
        if (cancelled) return;
        if (err instanceof ApiError && err.status === 403) {
          navigate('/forbidden', { replace: true });
          return;
        }
        if (err instanceof ApiError && err.status === 401) {
          logout();
          navigate('/login', { replace: true });
          return;
        }
        setError(err instanceof ApiError ? err.message : 'İstatistikler yüklenemedi.');
      } finally {
        if (!cancelled) setIsLoading(false);
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [navigate, logout]);

  return (
    <Layout>
      <h1 style={{ fontSize: 20, marginBottom: 20 }}>Genel Bakış</h1>

      {error && (
        <div className="error-banner" style={{ marginBottom: 20 }}>
          {error}
        </div>
      )}

      {isLoading && !overview ? (
        <p style={{ color: 'var(--text-secondary)' }}>Yükleniyor…</p>
      ) : overview ? (
        <>
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
              gap: 16,
              marginBottom: 24,
            }}
          >
            <StatCard label="Toplam Kullanıcı" value={overview.totalUsers} />
            <StatCard label="Toplam Sunucu" value={overview.totalServers} />
            <StatCard label="Toplam Kanal" value={overview.totalChannels} />
            <StatCard label="Toplam Mesaj" value={overview.totalMessages} />
            <StatCard label="Sesli Kanalda Aktif" value={overview.activeVoiceParticipants} />
            <StatCard label="Son 7 Gün Yeni Üye" value={overview.newUsersLast7Days} />
            <StatCard label="Son 7 Gün Yeni Sunucu" value={overview.newServersLast7Days} />
            <StatCard label="Son 24 Saat Mesaj" value={overview.messagesLast24h} />
            <StatCard label="Yasaklı Kullanıcı" value={overview.bannedUsers} accent="danger" />
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(360px, 1fr))', gap: 16 }}>
            <TimeseriesChart title="Günlük Yeni Kayıtlar (30 gün)" data={signups} color="#9f7aea" />
            <TimeseriesChart title="Günlük Mesaj Sayısı (30 gün)" data={messages} color="#4c5fd5" />
          </div>

          <p style={{ color: 'var(--text-secondary)', fontSize: 12, marginTop: 20 }}>
            Son güncelleme: {new Date(overview.generatedAt).toLocaleString('tr-TR')}
          </p>
        </>
      ) : null}
    </Layout>
  );
}
