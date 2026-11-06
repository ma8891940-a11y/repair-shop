import { useState } from 'react';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import { useFormat } from '../i18n/format';

export interface DayPoint {
  day: string;
  revenue: number;
  expenses: number;
  profit: number;
}

/**
 * الإيرادات والمصروفات (أعمدة) والربح (خط) يوم بيوم.
 * فيه جدول مخفي لقارئ الشاشة، وتفاصيل اليوم بتظهر بالماوس أو بالكيبورد.
 */
export function DailyChart({ data, height = 200 }: { data: DayPoint[]; height?: number }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { calm } = usePrefs();
  const [hover, setHover] = useState<number | null>(null);
  const W = 640;
  const H = height;
  const pad = { t: 10, b: 22, x: 4 };
  const max = Math.max(1, ...data.flatMap((d) => [d.revenue, d.expenses, Math.abs(d.profit)]));
  const min = Math.min(0, ...data.map((d) => d.profit));
  const span = max - min || 1;
  const y = (v: number) => pad.t + ((max - v) / span) * (H - pad.t - pad.b);
  const slot = (W - pad.x * 2) / Math.max(1, data.length);
  const bw = Math.max(2, Math.min(16, slot / 3));
  const cx = (i: number) => pad.x + slot * i + slot / 2;
  const line = data.map((d, i) => `${i ? 'L' : 'M'}${cx(i).toFixed(1)},${y(d.profit).toFixed(1)}`).join(' ');
  const h = hover != null ? data[hover] : null;
  const step = Math.ceil(data.length / 8);

  return (
    <div className="relative">
      <div className="mb-2 flex flex-wrap items-center gap-4 text-2xs text-fg-3">
        <Legend color="var(--ok)" label={t('fin.revenue')} />
        <Legend color="var(--danger)" label={t('fin.expenses')} />
        <Legend color="var(--accent)" label={t('fin.profit')} line />
      </div>
      <svg viewBox={`0 0 ${W} ${H}`} className="h-auto w-full" role="img" aria-label={t('fin.dailyChart')} style={{ direction: 'ltr' }} onMouseLeave={() => setHover(null)}>
        <line x1={0} x2={W} y1={y(0)} y2={y(0)} stroke="var(--line)" strokeWidth={1} />
        {data.map((d, i) => (
          <g key={d.day} onMouseEnter={() => setHover(i)}>
            <rect x={pad.x + slot * i} y={0} width={slot} height={H} fill={hover === i ? 'var(--accent-soft)' : 'transparent'} />
            <motion.rect
              x={cx(i) - bw - 1}
              width={bw}
              rx={2}
              fill="var(--ok)"
              opacity={0.85}
              initial={calm ? false : { y: y(0), height: 0 }}
              animate={{ y: y(d.revenue), height: Math.max(0, y(0) - y(d.revenue)) }}
              transition={{ duration: 0.22, delay: calm ? 0 : Math.min(i, 30) * 0.01 }}
            />
            <motion.rect
              x={cx(i) + 1}
              width={bw}
              rx={2}
              fill="var(--danger)"
              opacity={0.75}
              initial={calm ? false : { y: y(0), height: 0 }}
              animate={{ y: y(d.expenses), height: Math.max(0, y(0) - y(d.expenses)) }}
              transition={{ duration: 0.22, delay: calm ? 0 : Math.min(i, 30) * 0.01 }}
            />
            {i % step === 0 && (
              <text x={cx(i)} y={H - 6} textAnchor="middle" fontSize={10} fill="var(--text-3)" className="num">
                {d.day.slice(5)}
              </text>
            )}
          </g>
        ))}
        {data.length > 1 && <path d={line} fill="none" stroke="var(--accent)" strokeWidth={2} strokeLinejoin="round" />}
        {data.map((d, i) => (
          <circle key={d.day} cx={cx(i)} cy={y(d.profit)} r={hover === i ? 4 : 2.5} fill="var(--accent)" />
        ))}
      </svg>
      {h && (
        <div className="glass-strong pointer-events-none absolute end-2 top-6 rounded-md px-3 py-2 text-xs" role="status">
          <div className="mb-1 font-medium text-fg">{f.date(h.day)}</div>
          <Row label={t('fin.revenue')} value={f.money(h.revenue)} />
          <Row label={t('fin.expenses')} value={f.money(h.expenses)} />
          <Row label={t('fin.profit')} value={f.money(h.profit)} />
        </div>
      )}
      <table className="sr-only">
        <caption>{t('fin.dailyChart')}</caption>
        <thead>
          <tr>
            <th>{t('fin.day')}</th>
            <th>{t('fin.revenue')}</th>
            <th>{t('fin.expenses')}</th>
            <th>{t('fin.profit')}</th>
          </tr>
        </thead>
        <tbody>
          {data.map((d) => (
            <tr key={d.day}>
              <td>{d.day}</td>
              <td>{f.money(d.revenue)}</td>
              <td>{f.money(d.expenses)}</td>
              <td>{f.money(d.profit)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function Legend({ color, label, line }: { color: string; label: string; line?: boolean }) {
  return (
    <span className="inline-flex items-center gap-1.5">
      <span className={line ? 'h-0.5 w-3 rounded-full' : 'size-2.5 rounded-xs'} style={{ background: color }} aria-hidden />
      {label}
    </span>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-4">
      <span className="text-fg-3">{label}</span>
      <span className="num text-fg">{value}</span>
    </div>
  );
}
