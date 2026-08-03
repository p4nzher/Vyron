interface StatCardProps {
  label: string;
  value: number;
  accent?: 'default' | 'warning' | 'danger';
}

const accentColors: Record<NonNullable<StatCardProps['accent']>, string> = {
  default: 'var(--text-primary)',
  warning: 'var(--status-idle)',
  danger: 'var(--status-dnd)',
};

export function StatCard({ label, value, accent = 'default' }: StatCardProps) {
  return (
    <div className="glass-card" style={{ padding: 20 }}>
      <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 8 }}>{label}</div>
      <div className="mono" style={{ fontSize: 28, fontWeight: 700, color: accentColors[accent] }}>
        {value.toLocaleString('tr-TR')}
      </div>
    </div>
  );
}
