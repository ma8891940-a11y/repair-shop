import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { useNavigate, useParams } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { Check, Phone, ShieldCheck, X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { toLatinDigits } from '../lib/digits';
import type { DeviceStatus } from '../lib/status';
import { useFormat } from '../i18n/format';
import { CircuitField } from '../ui/fx/CircuitField';
import { LineIcon } from '../ui/fx/LineIcon';
import { Mark } from '../ui/Logo';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Button } from '../ui/Button';
import { Field, Input } from '../ui/Field';
import { Alert, Skeleton } from '../ui/Feedback';
import { StatusBadge } from '../ui/StatusBadge';
import { cn } from '../ui/cn';

interface Tracking {
  order_no: string;
  status: DeviceStatus;
  brand: string;
  model: string;
  received_at: string;
  updated_at: string;
  estimated_cost: number | null;
  final_cost: number | null;
  technician: string | null;
  shop_name: string;
  shop_phone: string | null;
  shop_logo: string | null;
  currency: string;
  warranty_until: string | null;
  can_decide: boolean;
  decision: 'approved' | 'rejected' | null;
}

/** المرحلة (من 4) اللي الجهاز فيها، لشريط التقدم */
function stage(s: DeviceStatus): number {
  if (s === 'delivered') return 3;
  if (s === 'ready' || s === 'repaired' || s === 'unrepairable') return 2;
  if (s === 'received') return 0;
  return 1;
}

/** صفحة تتبع العميل: الصفحة العامة الوحيدة. من غير تسجيل دخول، ومن غير أي بيانات شخصية. */
export function TrackingScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { token } = useParams();
  const navigate = useNavigate();
  const [order, setOrder] = useState('');
  const [last4, setLast4] = useState('');
  const [data, setData] = useState<Tracking | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<{ msg: string; n: number } | null>(null);
  const [done, setDone] = useState<string | null>(null);
  const [creds, setCreds] = useState<{ p_token?: string; p_order?: string; p_last4?: string } | null>(token ? { p_token: token } : null);

  const fail = (msg: string) => setErr((x) => ({ msg, n: (x?.n ?? 0) + 1 }));

  const load = useCallback(
    async (c: NonNullable<typeof creds>) => {
      setBusy(true);
      setErr(null);
      const { data: rows, error } = await supabase.rpc('get_tracking', c);
      setBusy(false);
      if (error) return fail(/E_RATE_LIMIT/.test(error.message) ? t('track.rateLimit') : t('errors.network'));
      const row = Array.isArray(rows) ? (rows[0] as Tracking | undefined) : undefined;
      if (!row) {
        setData(null);
        return fail(t('track.notFound'));
      }
      setData(row);
    },
    [t],
  );

  useEffect(() => {
    if (creds) void load(creds);
  }, [creds, load]);

  function submit(e: FormEvent) {
    e.preventDefault();
    const o = toLatinDigits(order).trim();
    const l = toLatinDigits(last4).replace(/\D/g, '');
    if (!o || l.length !== 4) return fail(t('track.notFound'));
    setCreds({ p_order: o, p_last4: l });
  }

  async function decide(decision: 'approved' | 'rejected') {
    if (!creds) return;
    setBusy(true);
    const { error } = await supabase.rpc('decide_quote', { p_decision: decision, ...creds });
    setBusy(false);
    if (error) return fail(/E_RATE_LIMIT/.test(error.message) ? t('track.rateLimit') : t('errors.generic'));
    setDone(decision === 'approved' ? t('track.approved') : t('track.rejected'));
    void load(creds);
  }

  const cost = data ? (data.final_cost ?? data.estimated_cost) : null;
  const logo = data?.shop_logo ? supabase.storage.from('shop-logos').getPublicUrl(data.shop_logo).data.publicUrl : null;
  const st = data ? stage(data.status) : 0;

  return (
    <div className="relative min-h-dvh overflow-hidden">
      <CircuitField />
      <div className="relative z-10 mx-auto flex min-h-dvh w-full max-w-lg flex-col px-4 pb-10">
        <header className="flex items-center justify-between py-4">
          <div className="flex items-center gap-2.5">
            {logo ? <img src={logo} alt="" className="size-9 rounded-md border border-glass-border bg-surface object-contain p-0.5" /> : <Mark size={32} />}
            <div className="text-sm font-semibold text-fg">{data?.shop_name ?? t('track.title')}</div>
          </div>
          <div className="flex items-center gap-1">
            <LangToggle />
            <ThemeToggle />
          </div>
        </header>

        <AnimatePresence mode="wait">
          {!data ? (
            <motion.form key="form" onSubmit={submit} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="glass edge-glow shadow-3 relative mt-6 flex flex-col gap-4 rounded-2xl p-6" noValidate>
              <div className="flex justify-center">
                <LineIcon name="scan" size={72} />
              </div>
              <div className="text-center">
                <h1 className="text-xl font-semibold text-fg">{t('track.title')}</h1>
                <p className="mt-1 text-sm text-fg-3">{t('track.sub')}</p>
              </div>
              {token && busy ? (
                <Skeleton className="h-24 w-full rounded-lg" />
              ) : (
                <>
                  <Field label={t('track.order')}>
                    <Input dir="ltr" mono value={order} onChange={(e) => setOrder(e.target.value)} placeholder="2026-0001" className="h-11 text-center text-md" autoFocus />
                  </Field>
                  <Field label={t('track.last4')}>
                    <Input dir="ltr" mono inputMode="numeric" maxLength={4} value={last4} onChange={(e) => setLast4(e.target.value)} placeholder="••••" className="h-11 text-center text-md tracking-[0.5em]" />
                  </Field>
                </>
              )}
              {err && (
                <div key={err.n}>
                  <Alert tone="danger">{err.msg}</Alert>
                </div>
              )}
              <Button type="submit" variant="primary" size="lg" loading={busy} className="w-full justify-center">
                {t('track.go')}
              </Button>
              <p className="flex items-center justify-center gap-1.5 text-2xs text-fg-3">
                <ShieldCheck className="size-3.5" aria-hidden /> {t('track.privacy')}
              </p>
            </motion.form>
          ) : (
            <motion.div key="result" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="mt-4 flex flex-col gap-4">
              <div className="glass edge-glow shadow-3 relative rounded-2xl p-5">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="readout-label">{t('track.order')}</div>
                    <div className="num text-glow text-2xl text-fg" dir="ltr">
                      {data.order_no}
                    </div>
                    <div className="mt-0.5 text-sm text-fg-2">
                      {data.brand} {data.model}
                    </div>
                  </div>
                  <StatusBadge status={data.status} />
                </div>
                {/* شريط التقدم بأربع مراحل */}
                <ol className="mt-5 grid grid-cols-4 gap-1.5" aria-label={t('track.status')}>
                  {(['received', 'work', 'ready', 'delivered'] as const).map((k, i) => (
                    <li key={k} className="flex flex-col gap-1.5">
                      <div className="h-1.5 overflow-hidden rounded-full bg-sunken">
                        <motion.div
                          className="h-full rounded-full bg-accent shadow-[0_0_8px_var(--accent-glow)]"
                          style={{ transformOrigin: 'var(--start-origin)' }}
                          initial={{ scaleX: 0 }}
                          animate={{ scaleX: i <= st ? 1 : 0 }}
                          transition={{ delay: 0.15 * i, duration: 0.35 }}
                        />
                      </div>
                      <span className={cn('text-center text-2xs', i <= st ? 'text-fg' : 'text-fg-3')}>{t(`track.steps.${k}`)}</span>
                    </li>
                  ))}
                </ol>
                <dl className="mt-5 grid grid-cols-2 gap-3 text-sm">
                  <Item label={t('track.updated')} value={f.dateTime(data.updated_at)} />
                  <Item label={t('track.received')} value={f.date(data.received_at)} />
                  {cost != null && <Item label={data.final_cost != null ? t('track.final') : t('track.estimated')} value={`${f.money(cost)} ${f.currency(data.currency)}`} mono />}
                  {data.technician && <Item label={t('track.tech')} value={data.technician} />}
                  {data.warranty_until && <Item label={t('track.warranty')} value={f.date(data.warranty_until)} />}
                </dl>
              </div>

              {done && <Alert tone="ok">{done}</Alert>}
              {err && (
                <div key={err.n}>
                  <Alert tone="danger">{err.msg}</Alert>
                </div>
              )}

              {data.can_decide ? (
                <div className="glass relative rounded-2xl border-[color-mix(in_srgb,var(--warn)_40%,var(--glass-border))] p-5">
                  <div className="text-md font-semibold text-fg">{t('track.approveTitle')}</div>
                  <p className="mt-1 text-sm text-fg-2">{t('track.approveText', { cost: cost != null ? `${f.money(cost)} ${f.currency(data.currency)}` : t('common.none') })}</p>
                  <div className="mt-4 grid gap-2 sm:grid-cols-2">
                    <Button variant="primary" size="lg" loading={busy} icon={<Check className="size-4" />} className="justify-center" onClick={() => void decide('approved')}>
                      {t('track.approve')}
                    </Button>
                    <Button variant="outline" size="lg" disabled={busy} icon={<X className="size-4" />} className="justify-center" onClick={() => void decide('rejected')}>
                      {t('track.reject')}
                    </Button>
                  </div>
                </div>
              ) : (
                data.decision && !done && <Alert tone="info">{t('track.decided', { d: t(`track.decisions.${data.decision}`) })}</Alert>
              )}

              <div className="flex flex-wrap gap-2">
                {data.shop_phone && (
                  <a href={`tel:${data.shop_phone}`} className="glass inline-flex h-10 items-center gap-2 rounded-md px-4 text-sm text-fg hover:border-glass-border-strong">
                    <Phone className="size-4 text-accent" /> {t('track.call')}
                  </a>
                )}
                <Button
                  variant="ghost"
                  onClick={() => {
                    setData(null);
                    setCreds(null);
                    setDone(null);
                    if (token) navigate('/t', { replace: true });
                  }}
                >
                  {t('track.another')}
                </Button>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}

function Item({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="min-w-0 rounded-md border border-glass-border bg-sunken/40 px-3 py-2">
      <dt className="readout-label">{label}</dt>
      <dd className={cn('mt-0.5 truncate text-fg', mono && 'num')}>{value}</dd>
    </div>
  );
}
