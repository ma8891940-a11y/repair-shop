import { useEffect, useState, type ReactNode } from 'react';
import { useNavigate, useParams } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, ArrowRight, X } from 'lucide-react';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { supabase } from '../lib/supabase';
import { nextStatusesFor, type DeviceStatus } from '../lib/status';
import { errorMessage } from '../lib/errors';
import type { Customer, Device } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { Alert, EmptyState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

interface LogRow {
  id: string;
  old_status: DeviceStatus | null;
  new_status: DeviceStatus;
  created_at: string;
  profiles: { full_name: string } | null;
}

/**
 * تفاصيل الجهاز. لو اتفتحت من كارت (overlay = true) بتظهر فوق الشاشة اللي قبلها،
 * والكارت نفسه بيكبر ويتحول لرأس الصفحة (layoutId مشترك).
 */
export function DeviceDetailScreen({ overlay = false }: { overlay?: boolean }) {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const { profile } = useMe();
  const navigate = useNavigate();
  const toast = useToast();
  const front = profile.role !== 'technician';
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const { data, error, loading, reload } = useLoad(async () => {
    const d = must(await supabase.from('devices').select('*').eq('id', id).is('deleted_at', null).maybeSingle()) as Device | null;
    if (!d) return null;
    const [c, l] = await Promise.all([
      front ? supabase.from('customers').select('id, name, phone, area').eq('id', d.customer_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
      supabase.from('status_log').select('id, old_status, new_status, created_at, profiles(full_name)').eq('device_id', id).order('created_at'),
    ]);
    return { device: d, customer: (c.data as Customer | null) ?? null, log: (must(l) ?? []) as unknown as LogRow[] };
  }, [id, front]);

  const close = () => (overlay ? navigate(-1) : navigate('/'));
  useEffect(() => {
    if (!overlay) return;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && navigate(-1);
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [overlay, navigate]);

  async function change(to: DeviceStatus) {
    if (to === 'delivered' && !confirm(t('device.confirmDeliver'))) return;
    setBusy(true);
    setErr(null);
    const { error: e } = await supabase.from('devices').update({ status: to }).eq('id', id);
    setBusy(false);
    if (e) return setErr(errorMessage(e));
    toast({ tone: 'ok', title: t('device.statusChanged'), description: t(`status.${to}`) });
    reload();
  }

  const d = data?.device;
  const body = (
    <div className={cn('mx-auto w-full max-w-5xl', overlay && 'px-4 py-6 md:px-6')}>
      <button type="button" onClick={close} className="mb-3 inline-flex items-center gap-1.5 rounded-sm text-sm text-fg-3 hover:text-fg">
        <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden />
        {t('device.back')}
      </button>

      {/* رأس الصفحة: نفس الكارت اللي اتداس عليه، بيكبر لهنا */}
      <motion.div layoutId={`device-card-${id}`} className="glass-strong edge-glow relative overflow-hidden rounded-xl p-5" transition={{ duration: 0.32, ease: [0.2, 0.8, 0.2, 1] }}>
        {loading || !d ? (
          <div className="flex flex-col gap-2">
            <Skeleton className="h-7 w-40" />
            <Skeleton className="h-4 w-64" />
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-x-5 gap-y-3">
            <div>
              <div className="readout-label">{t('intake.orderNo')}</div>
              <motion.div layoutId={`device-order-${id}`} className="num text-glow text-2xl text-fg" dir="ltr">
                {d.order_no}
              </motion.div>
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-lg font-semibold text-fg">
                {d.brand} {d.model}
              </div>
              <div className="text-sm text-fg-3">
                {data?.customer ? `${data.customer.name} · ` : ''}
                {f.dateTime(d.received_at)}
              </div>
            </div>
            <StatusBadge status={d.status} />
          </div>
        )}
        {overlay && (
          <button type="button" onClick={close} aria-label={t('common.close')} className="absolute end-3 top-3 rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-fg">
            <X className="size-4" />
          </button>
        )}
      </motion.div>

      {error ? (
        <Alert tone="danger" className="mt-4">
          {error}
        </Alert>
      ) : !loading && !d ? (
        <Panel className="mt-4">
          <EmptyState line="scan" title={t('device.notFound')} />
        </Panel>
      ) : (
        <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.15, duration: 0.25 }} className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
          <div className="flex min-w-0 flex-col gap-4">
            <Panel>
              <PanelHeader index="01" title={t('device.changeStatus')} />
              <div className="p-4">
                {err && (
                  <Alert tone="danger" className="mb-3">
                    {err}
                  </Alert>
                )}
                {d && nextStatusesFor(d.status, profile.role).length === 0 ? (
                  <p className="text-sm text-fg-3">{t('device.noNext')}</p>
                ) : (
                  <div className="flex flex-wrap gap-2">
                    {d &&
                      nextStatusesFor(d.status, profile.role).map((s) => (
                        <button
                          key={s}
                          type="button"
                          disabled={busy}
                          onClick={() => void change(s)}
                          className="lift inline-flex h-9 items-center gap-2 rounded-md border px-3 text-sm font-medium disabled:opacity-50"
                          style={{ color: `var(--st-${s})`, borderColor: `color-mix(in srgb, var(--st-${s}) 40%, transparent)`, background: `color-mix(in srgb, var(--st-${s}) 10%, transparent)` }}
                        >
                          <ArrowRight className="size-3.5 rtl:-scale-x-100" aria-hidden />
                          {t(`status.${s}`)}
                        </button>
                      ))}
                  </div>
                )}
              </div>
            </Panel>
            <Panel>
              <PanelHeader index="02" title={t('device.info')} />
              {d && (
                <dl className="grid grid-cols-[max-content_1fr] gap-x-5 gap-y-2.5 p-4 text-sm">
                  {data?.customer && (
                    <Row label={t('device.customer')}>
                      {data.customer.name} ·{' '}
                      <span className="num" dir="ltr">
                        {data.customer.phone}
                      </span>
                    </Row>
                  )}
                  <Row label={t('device.device')}>
                    {d.brand} {d.model} {d.color && `· ${d.color}`}
                  </Row>
                  <Row label="IMEI">
                    <span className="num" dir="ltr">
                      {d.imei || t('common.none')}
                    </span>
                  </Row>
                  <Row label={t('device.accessories')}>{d.accessories.length ? d.accessories.map((a) => t(`intake.acc.${a}`, { defaultValue: a })).join(t('common.sep')) : t('device.withoutAcc')}</Row>
                  <Row label={t('device.issue')}>{d.issue}</Row>
                  <Row label={t('device.condition')}>{d.cosmetic_condition || t('common.none')}</Row>
                </dl>
              )}
            </Panel>
          </div>
          <Panel className="min-w-0">
            <PanelHeader index="03" title={t('device.history')} />
            <ol className="relative m-4 border-s border-line ps-5">
              {(data?.log ?? []).map((l, i) => (
                <motion.li key={l.id} initial={{ opacity: 0, x: 6 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.2 + i * 0.05 }} className="relative mb-4 last:mb-0">
                  <span className="absolute -start-[25px] top-1 size-2.5 rounded-full border-2 border-bg" style={{ backgroundColor: `var(--st-${l.new_status})`, boxShadow: `0 0 8px var(--st-${l.new_status})` }} aria-hidden />
                  <StatusBadge status={l.new_status} size="sm" />
                  <div className="mt-1 text-xs text-fg-3">
                    {l.profiles?.full_name ?? t('common.none')} · {f.dateTime(l.created_at)}
                  </div>
                </motion.li>
              ))}
            </ol>
          </Panel>
        </motion.div>
      )}
    </div>
  );

  if (!overlay) return body;
  return (
    <motion.div className="fixed inset-0 z-40 overflow-y-auto" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.2 }} role="dialog" aria-modal>
      <div className="fixed inset-0 bg-[color-mix(in_srgb,var(--bg)_70%,transparent)] backdrop-blur-md" onClick={close} aria-hidden />
      <div className="relative">{body}</div>
    </motion.div>
  );
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <>
      <dt className="text-fg-3">{label}</dt>
      <dd className="min-w-0 text-fg">{children}</dd>
    </>
  );
}
