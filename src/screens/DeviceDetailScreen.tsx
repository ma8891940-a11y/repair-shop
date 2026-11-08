import { useEffect, useRef, useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, ArrowRight, Eye, ImagePlus, KeyRound, Printer, QrCode, Receipt, ShieldCheck, Trash2, X } from 'lucide-react';
import { DeleteDialog } from '../app/DeleteDialog';
import { readExtras } from '../lib/extras';
import { useCanCorrect } from '../app/correct';
import { useMe } from '../app/auth';
import { useLoad, must } from '../app/useLoad';
import { useLiveRefresh } from '../app/AppShell';
import { WhatsAppButton, WhatsAppDialog, type MessageTarget } from '../app/messaging';
import type { CheckItems } from '../lib/checks';
import { inWarranty } from '../lib/customers';
import { CheckCompare, QuickCheck } from '../ui/QuickCheck';
import { supabase } from '../lib/supabase';
import { nextStatusesFor, type DeviceStatus } from '../lib/status';
import { errorMessage } from '../lib/errors';
import { formatPounds, parsePounds } from '../lib/money';
import { MAX_PHOTOS, signedPhotoUrls, uploadDevicePhoto } from '../lib/photos';
import type { Customer, Device, DeviceCost } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { Alert, EmptyState, Skeleton } from '../ui/Feedback';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { Dialog } from '../ui/Dialog';
import { useToast } from '../ui/Toast';
import { DeviceMoneyPanel, PartsPanel } from '../app/finance/DeviceMoneyPanel';
import { StepsPanel } from '../app/tech/StepsPanel';
import { shouldQueue, useSync } from '../offline/sync';
import { StaleNote } from '../ui/StaleNote';
import { cn } from '../ui/cn';
import { AssistantPanel } from '../app/AssistantPanel';

interface LogRow {
  id: string;
  new_status: DeviceStatus;
  created_at: string;
  profiles: { full_name: string } | null;
}
interface NoteRow {
  id: string;
  body: string;
  created_at: string;
  profiles: { full_name: string } | null;
}
interface PhotoRow {
  id: string;
  storage_path: string;
}
interface CheckRow {
  id: string;
  stage: 'intake' | 'delivery';
  items: CheckItems;
}
interface LockRow {
  kind: 'pin' | 'pattern';
  secret_id: string | null;
  erased_at: string | null;
}

/**
 * تفاصيل الجهاز. لو اتفتحت من كارت (overlay) بتظهر فوق الشاشة اللي قبلها،
 * والكارت نفسه بيكبر ويتحول لرأس الصفحة (layoutId مشترك).
 */
export function DeviceDetailScreen({ overlay = false }: { overlay?: boolean }) {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const navigate = useNavigate();
  const toast = useToast();
  const front = (profile.role === 'owner' || profile.role === 'reception');
  const canSeeLock = profile.role === 'owner' || profile.role === 'technician';
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<{ msg: string; n: number } | null>(null);
  const [confirmDeliver, setConfirmDeliver] = useState(false);
  const [wa, setWa] = useState(false);
  const canCorrect = useCanCorrect();
  const [del, setDel] = useState(false);
  const [moneyVer, setMoneyVer] = useState(0);
  const [localStatus, setLocalStatus] = useState<DeviceStatus | null>(null);
  const sync = useSync();

  const { data, error, loading, reload, stale } = useLoad(async () => {
    const d = must(await supabase.from('devices').select('*').eq('id', id).is('deleted_at', null).maybeSingle()) as Device | null;
    if (!d) return null;
    const [c, k, l, n, p, lk, ck] = await Promise.all([
      front ? supabase.from('customers').select('id, name, phone, area').eq('id', d.customer_id).maybeSingle() : Promise.resolve({ data: null, error: null }),
      front ? supabase.from('device_costs').select('id, device_id, estimated_cost, final_cost').eq('device_id', id).is('deleted_at', null).maybeSingle() : Promise.resolve({ data: null, error: null }),
      supabase.from('status_log').select('id, new_status, created_at, profiles(full_name)').eq('device_id', id).order('created_at'),
      supabase.from('device_notes').select('id, body, created_at, profiles(full_name)').eq('device_id', id).is('deleted_at', null).order('created_at'),
      supabase.from('device_photos').select('id, storage_path').eq('device_id', id).is('deleted_at', null).order('created_at'),
      supabase.from('device_passcodes').select('kind, secret_id, erased_at').eq('device_id', id).maybeSingle(),
      supabase.from('device_checks').select('id, stage, items').eq('device_id', id).is('deleted_at', null),
    ]);
    const photos = (must(p) ?? []) as PhotoRow[];
    let urls: Record<string, string> = {};
    try {
      urls = await signedPhotoUrls(photos.map((x) => x.storage_path));
    } catch {
      /* الصور مش ضرورية لعرض الصفحة */
    }
    return {
      device: d,
      customer: (c.data as Customer | null) ?? null,
      cost: (k.data as DeviceCost | null) ?? null,
      log: (must(l) ?? []) as unknown as LogRow[],
      notes: (must(n) ?? []) as unknown as NoteRow[],
      photos,
      urls,
      lock: (lk.data as LockRow | null) ?? null,
      checks: (must(ck) ?? []) as CheckRow[],
      // الرسايل بتتبعت باسم الفني اللي شغال على الجهاز
      techName: front ? (((await supabase.rpc('device_tech_name', { p_device: id })).data as string | null) ?? null) : null,
    };
  }, [id, front], { cacheKey: `device:${id}:${profile.id}` });
  useLiveRefresh(reload);

  const close = () => (overlay ? navigate(-1) : navigate('/devices'));
  useEffect(() => {
    if (!overlay) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !document.querySelector('[role=dialog][data-state=open]')) navigate(-1);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [overlay, navigate]);

  async function run(fn: () => Promise<unknown>, okTitle?: string) {
    setBusy(true);
    setErr(null);
    try {
      await fn();
      if (okTitle) toast({ tone: 'ok', title: okTitle });
      reload();
      return true;
    } catch (e) {
      setErr((x) => ({ msg: errorMessage(e), n: (x?.n ?? 0) + 1 }));
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function change(to: DeviceStatus) {
    if (to === 'delivered' && !confirmDeliver) return setConfirmDeliver(true);
    setConfirmDeliver(false);
    // بدون نت: التغيير بيتسجل على الجهاز ويتبعت بعدين ("آخر تعديل بالوقت يكسب"). التسليم محتاج نت (الدفع)
    const offline = async () => {
      await sync.queue('status', crypto.randomUUID(), { device: id, status: to });
      setLocalStatus(to);
      toast({ tone: 'warn', title: t('sync.queued'), description: t(`status.${to}`) });
    };
    if (!navigator.onLine && to !== 'delivered') return void offline();
    await run(
      async () => {
        const r = await supabase.from('devices').update({ status: to }).eq('id', id);
        if (r.error) {
          if (shouldQueue(r.error) && to !== 'delivered') return offline();
          throw r.error;
        }
        setLocalStatus(null);
        // كل تغيير حالة بيبعت رسالة للعميل (واتساب برابط جاهز): التنبيه فيه زرار يفتح الرسالة المناسبة للحالة
        toast({
          tone: 'ok',
          title: `${t('device.statusChanged')}: ${t(`status.${to}`)}`,
          ...(target ? { duration: 8000, action: { label: t('device.notifyCustomer'), onClick: () => setWa(true) } } : {}),
        });
      },
    );
  }

  const d = data?.device ? { ...data.device, status: localStatus ?? data.device.status } : undefined;
  const readyLog = data?.log.filter((l) => l.new_status === 'ready').at(-1);
  const target: MessageTarget | null =
    d && data?.customer
      ? {
          deviceId: d.id,
          customerId: data.customer.id,
          customerName: data.customer.name,
          phone: data.customer.phone,
          orderNo: d.order_no,
          device: `${d.brand} ${d.model}`,
          status: d.status,
          token: d.tracking_token,
          cost: data.cost?.final_cost ?? data.cost?.estimated_cost ?? null,
          readySince: readyLog?.created_at ?? null,
          warrantyUntil: d.warranty_until,
          tech: data.techName,
          etaMinutes: d.est_minutes ?? null,
        }
      : null;
  const waInitial = d
    ? d.status === 'ready'
      ? 'ready'
      : d.status === 'awaiting_approval'
        ? 'approval'
        : d.status === 'delivered'
          ? 'delivered'
          : d.status === 'received'
            ? 'received'
            : 'status'
    : 'status';
  const body = (
    <div className={cn('mx-auto w-full max-w-6xl', overlay && 'px-4 py-6 md:px-6')}>
      <StaleNote at={stale} />
      <div className="mb-3 flex items-center justify-between gap-2">
        <button type="button" onClick={close} className="inline-flex items-center gap-1.5 rounded-sm text-sm text-fg-3 hover:text-fg">
          <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden />
          {t('device.back')}
        </button>
        {front && d && (
          <div className="flex flex-wrap gap-2">
            {target && <WhatsAppButton onClick={() => setWa(true)} />}
            <Link to={`/print/label/${id}`} className="glass inline-flex h-8 items-center gap-1.5 rounded-sm px-3 text-sm text-fg hover:border-glass-border-strong">
              <QrCode className="size-4" /> {t('detail.label')}
            </Link>
            <Link to={`/print/receipt/${id}`} className="glass inline-flex h-8 items-center gap-1.5 rounded-sm px-3 text-sm text-fg hover:border-glass-border-strong">
              <Printer className="size-4" /> {t('detail.receipt')}
            </Link>
            <Link to={`/print/invoice/${id}`} className="glass inline-flex h-8 items-center gap-1.5 rounded-sm px-3 text-sm text-fg hover:border-glass-border-strong">
              <Receipt className="size-4" /> {t('detail.invoice')}
            </Link>
            {canCorrect && (
              <button type="button" onClick={() => setDel(true)} className="glass inline-flex h-8 items-center gap-1.5 rounded-sm px-3 text-sm text-fg-2 hover:text-danger" data-testid="device-delete">
                <Trash2 className="size-4" /> {t('del.delete')}
              </button>
            )}
            <DeleteDialog target={del ? { kind: 'device', id, name: d.order_no } : null} onOpenChange={setDel} onDone={close} />
          </div>
        )}
      </div>

      <motion.div layoutId={`device-card-${id}`} className="glass-strong edge-glow relative overflow-hidden rounded-xl p-5" transition={{ duration: 0.32, ease: [0.2, 0.8, 0.2, 1] }}>
        {loading || !d ? (
          <div className="flex flex-col gap-2">
            <Skeleton className="h-7 w-40" />
            <Skeleton className="h-4 w-64" />
          </div>
        ) : (
          <div className="flex flex-wrap items-center gap-x-5 gap-y-3 pe-8">
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
                {data?.customer && (
                  <>
                    <bdi>{data.customer.name}</bdi>
                    {' · '}
                  </>
                )}
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
        d &&
        data && (
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.12, duration: 0.25 }}
            className="mt-4 grid gap-4 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]"
          >
            <div className="flex min-w-0 flex-col gap-4">
              <Panel>
                <PanelHeader index="01" title={t('device.changeStatus')} />
                <div className="p-4">
                  {err && (
                    <div key={err.n} className="mb-3">
                      <Alert tone="danger">{err.msg}</Alert>
                    </div>
                  )}
                  {nextStatusesFor(d.status, profile.role).length === 0 ? (
                    <p className="text-sm text-fg-3">{t('device.noNext')}</p>
                  ) : (
                    <div className="flex flex-wrap gap-2">
                      {nextStatusesFor(d.status, profile.role).map((s) => (
                        <button
                          key={s}
                          type="button"
                          disabled={busy}
                          onClick={() => void change(s)}
                          className="lift inline-flex h-9 items-center gap-2 rounded-md border px-3 text-sm font-medium disabled:opacity-50"
                          style={{
                            color: `var(--st-${s})`,
                            borderColor: `color-mix(in srgb, var(--st-${s}) 40%, transparent)`,
                            background: `color-mix(in srgb, var(--st-${s}) 10%, transparent)`,
                          }}
                        >
                          <ArrowRight className="size-3.5 rtl:-scale-x-100" aria-hidden />
                          {t(`status.${s}`)}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              </Panel>

              {front && <CostPanel deviceId={id} shopId={profile.shop_id} cost={data.cost} currency={f.currency(shop.currency)} onSaved={reload} />}
              {front && (
                <DeviceMoneyPanel
                  deviceId={id}
                  customer={data.customer ? { id: data.customer.id, name: data.customer.name } : null}
                  orderNo={d.order_no}
                  status={d.status}
                  finalCost={data.cost?.final_cost}
                  version={moneyVer}
                  onChanged={reload}
                />
              )}
              {(profile.role !== 'reception' || !readExtras(shop.extras).link_inventory) && (
                <PartsPanel
                  deviceId={id}
                  status={d.status}
                  onChanged={() => {
                    setMoneyVer((v) => v + 1);
                    reload();
                  }}
                />
              )}

              <Panel>
                <PanelHeader index={front ? '03' : '02'} title={t('device.info')} />
                <dl className="grid grid-cols-[max-content_1fr] gap-x-5 gap-y-2.5 p-4 text-sm">
                  {data.customer && (
                    <Row label={t('device.customer')}>
                      <bdi>{data.customer.name}</bdi> ·{' '}
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
                  {d.warranty_until && (
                    <Row label={t('print.warranty')}>
                      <span className={cn('inline-flex items-center gap-1', inWarranty(d.warranty_until, new Date()) ? 'text-ok' : 'text-fg-3')}>
                        <ShieldCheck className="size-3.5" aria-hidden />
                        {inWarranty(d.warranty_until, new Date()) ? t('warranty.until', { d: f.date(d.warranty_until) }) : t('warranty.expired')}
                      </span>
                    </Row>
                  )}
                </dl>
              </Panel>

              <StepsPanel deviceId={id} routeId={d.route_id ?? null} priority={d.priority ?? 'normal'} estMinutes={d.est_minutes ?? null} onChanged={reload} />

              {(profile.role === 'technician' || profile.role === 'owner') && (
                <AssistantPanel brand={d.brand} model={d.model} issue={d.issue ?? ''} names={data.customer ? [data.customer.name] : []} />
              )}

              <ChecksPanel deviceId={id} shopId={profile.shop_id} status={d.status} checks={data.checks} onSaved={reload} />

              <PhotosPanel deviceId={id} shopId={profile.shop_id} photos={data.photos} urls={data.urls} canEdit={front && d.status !== 'delivered'} onChanged={reload} />
            </div>

            <div className="flex min-w-0 flex-col gap-4">
              <LockPanel deviceId={id} lock={data.lock} canSee={canSeeLock} canSet={front && d.status !== 'delivered'} onChanged={reload} />
              <NotesPanel deviceId={id} shopId={profile.shop_id} notes={data.notes} onAdded={reload} />
              <Panel>
                <PanelHeader title={t('device.history')} />
                <ol className="relative m-4 border-s border-line ps-5">
                  {data.log.map((l, i) => (
                    <motion.li key={l.id} initial={{ opacity: 0, x: 6 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: 0.15 + i * 0.04 }} className="relative mb-4 last:mb-0">
                      <span
                        className="absolute -start-[25px] top-1 size-2.5 rounded-full border-2 border-bg"
                        style={{
                          backgroundColor: `var(--st-${l.new_status})`,
                          boxShadow: `0 0 8px var(--st-${l.new_status})`,
                        }}
                        aria-hidden
                      />
                      <StatusBadge status={l.new_status} size="sm" />
                      <div className="mt-1 text-xs text-fg-3">
                        {l.profiles?.full_name ?? t('common.none')} · {f.dateTime(l.created_at)}
                      </div>
                    </motion.li>
                  ))}
                </ol>
              </Panel>
            </div>
          </motion.div>
        )
      )}

      <WhatsAppDialog open={wa} onOpenChange={setWa} target={target} initial={waInitial} />
      <Dialog
        open={confirmDeliver}
        onOpenChange={setConfirmDeliver}
        title={t('detail.deliverTitle')}
        description={t('detail.deliverText')}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirmDeliver(false)}>
              {t('common.cancel')}
            </Button>
            <Button variant="primary" loading={busy} onClick={() => void change('delivered')}>
              {t('detail.confirm')}
            </Button>
          </>
        }
      />
    </div>
  );

  if (!overlay) return body;
  return (
    <motion.div className="fixed inset-0 z-40 overflow-y-auto" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.2 }} role="dialog" aria-modal>
      <div className="fixed inset-0 bg-[color-mix(in_srgb,var(--bg)_78%,transparent)] backdrop-blur-md" onClick={close} aria-hidden />
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

function CostPanel({ deviceId, shopId, cost, currency, onSaved }: { deviceId: string; shopId: string; cost: DeviceCost | null; currency: string; onSaved: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const plain = (v: number | null | undefined) => (v == null ? '' : formatPounds(v).replace(/,/g, ''));
  const [est, setEst] = useState(plain(cost?.estimated_cost));
  const [fin, setFin] = useState(plain(cost?.final_cost));
  const [errs, setErrs] = useState<{ est?: string; fin?: string }>({});
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    setEst(plain(cost?.estimated_cost));
    setFin(plain(cost?.final_cost));
  }, [cost?.estimated_cost, cost?.final_cost]);

  async function save() {
    const e: { est?: string; fin?: string } = {};
    const a = est.trim() ? parsePounds(est) : null;
    const b = fin.trim() ? parsePounds(fin) : null;
    if (est.trim() && a === null) e.est = t('intake.estimateBad');
    if (fin.trim() && b === null) e.fin = t('intake.estimateBad');
    setErrs(e);
    if (e.est || e.fin) return;
    setBusy(true);
    const r = cost
      ? await supabase.from('device_costs').update({ estimated_cost: a, final_cost: b }).eq('id', cost.id)
      : await supabase.from('device_costs').insert({
          id: crypto.randomUUID(),
          shop_id: shopId,
          device_id: deviceId,
          estimated_cost: a,
          final_cost: b,
        });
    setBusy(false);
    if (r.error) return toast({ tone: 'danger', title: errorMessage(r.error) });
    toast({ tone: 'ok', title: t('detail.costsSaved') });
    onSaved();
  }

  return (
    <Panel>
      <PanelHeader index="02" title={t('detail.costs')} />
      <div className="grid gap-3 p-4 sm:grid-cols-2">
        <Field label={t('detail.estimated')} error={errs.est}>
          <Input dir="ltr" mono inputMode="decimal" value={est} onChange={(e) => setEst(e.target.value)} suffix={currency} className="text-start" />
        </Field>
        <Field label={t('detail.final')} error={errs.fin}>
          <Input dir="ltr" mono inputMode="decimal" value={fin} onChange={(e) => setFin(e.target.value)} suffix={currency} className="text-start" />
        </Field>
        <p className="text-xs text-fg-3 sm:col-span-2">{t('detail.costHint')}</p>
        <div className="sm:col-span-2">
          <Button loading={busy} onClick={() => void save()}>
            {t('detail.saveCosts')}
          </Button>
        </div>
      </div>
    </Panel>
  );
}

function LockPanel({ deviceId, lock, canSee, canSet, onChanged }: { deviceId: string; lock: LockRow | null; canSee: boolean; canSet: boolean; onChanged: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [shown, setShown] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [kind, setKind] = useState<'pin' | 'pattern'>('pin');
  const [value, setValue] = useState('');
  const [busy, setBusy] = useState(false);
  const hideTimer = useRef(0);
  useEffect(() => () => clearTimeout(hideTimer.current), []);

  async function reveal() {
    setBusy(true);
    const { data, error } = await supabase.rpc('reveal_device_passcode', {
      p_device_id: deviceId,
    });
    setBusy(false);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    const row = Array.isArray(data) ? data[0] : null;
    setShown(row?.value ?? null);
    // بيتخفي لوحده بعد 20 ثانية
    clearTimeout(hideTimer.current);
    hideTimer.current = window.setTimeout(() => setShown(null), 20_000);
  }
  async function save() {
    if (!value.trim()) return;
    setBusy(true);
    const { error } = await supabase.rpc('set_device_passcode', {
      p_device_id: deviceId,
      p_kind: kind,
      p_value: value.trim(),
    });
    setBusy(false);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    setEditing(false);
    setValue('');
    toast({ tone: 'ok', title: t('detail.lockSaved') });
    onChanged();
  }

  const has = lock && lock.secret_id;
  return (
    <Panel>
      <PanelHeader title={t('detail.lock')} actions={<KeyRound className="size-4 text-fg-3" aria-hidden />} />
      <div className="p-4 text-sm">
        {!lock ? (
          <p className="text-fg-3">{t('detail.lockNone')}</p>
        ) : !has ? (
          <p className="text-fg-3">{t('detail.lockErased')}</p>
        ) : (
          <div className="flex flex-wrap items-center gap-3">
            <span className="rounded-sm border border-glass-border bg-sunken/60 px-2 py-0.5 text-xs text-fg-2">{t(`detail.lockKinds.${lock.kind}`)}</span>
            <AnimatePresence mode="wait">
              <motion.span
                key={shown ?? 'hidden'}
                initial={{ opacity: 0, y: 4 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                className={cn('num text-lg tracking-widest', shown ? 'text-glow text-fg' : 'text-fg-3')}
                dir="ltr"
              >
                {shown ?? '••••••'}
              </motion.span>
            </AnimatePresence>
            {canSee && !shown && (
              <Button size="sm" variant="outline" loading={busy} icon={<Eye className="size-3.5" />} onClick={() => void reveal()}>
                {t('detail.lockShow')}
              </Button>
            )}
          </div>
        )}
        {canSee && has && <p className="mt-2 text-2xs text-fg-3">{t('detail.lockShowHint')}</p>}
        {canSet && (
          <div className="mt-3">
            {editing ? (
              <div className="flex flex-col gap-2">
                <div className="flex gap-1" role="radiogroup" aria-label={t('intake.lockType')}>
                  {(['pin', 'pattern'] as const).map((k) => (
                    <button
                      key={k}
                      type="button"
                      role="radio"
                      aria-checked={kind === k}
                      onClick={() => setKind(k)}
                      className={cn('h-7 rounded-sm border px-2.5 text-xs', kind === k ? 'border-accent bg-accent-soft text-fg' : 'border-line text-fg-3')}
                    >
                      {t(`detail.lockKinds.${k}`)}
                    </button>
                  ))}
                </div>
                <div className="flex gap-2">
                  <Input
                    dir="ltr"
                    mono
                    value={value}
                    onChange={(e) => setValue(e.target.value)}
                    autoComplete="off"
                    placeholder={kind === 'pattern' ? '1-5-9-6' : '••••'}
                    className="text-start"
                    aria-label={t('detail.lock')}
                  />
                  <Button variant="primary" loading={busy} onClick={() => void save()}>
                    {t('detail.lockSave')}
                  </Button>
                </div>
              </div>
            ) : (
              <Button size="sm" variant="ghost" onClick={() => setEditing(true)}>
                {t('detail.lockSet')}
              </Button>
            )}
          </div>
        )}
      </div>
    </Panel>
  );
}

function NotesPanel({ deviceId, shopId, notes, onAdded }: { deviceId: string; shopId: string; notes: NoteRow[]; onAdded: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [body, setBody] = useState('');
  const [busy, setBusy] = useState(false);
  async function add() {
    const b = body.trim();
    if (!b) return;
    setBusy(true);
    const { error } = await supabase.from('device_notes').insert({
      id: crypto.randomUUID(),
      shop_id: shopId,
      device_id: deviceId,
      body: b,
    });
    setBusy(false);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    setBody('');
    onAdded();
  }
  return (
    <Panel>
      <PanelHeader title={t('detail.notes')} />
      <div className="p-4">
        <p className="mb-2 text-2xs text-fg-3">{t('detail.notesHint')}</p>
        {notes.length === 0 ? (
          <p className="mb-3 text-sm text-fg-3">{t('detail.noNotes')}</p>
        ) : (
          <ul className="mb-3 flex flex-col gap-2">
            {notes.map((n) => (
              <li key={n.id} className="rounded-md border border-[color-mix(in_srgb,var(--warn)_25%,var(--glass-border))] bg-warn-soft px-3 py-2">
                <div className="whitespace-pre-wrap text-sm text-fg">{n.body}</div>
                <div className="mt-1 text-2xs text-fg-3">
                  {n.profiles?.full_name ?? t('common.none')} · {f.dateTime(n.created_at)}
                </div>
              </li>
            ))}
          </ul>
        )}
        <div className="flex flex-col gap-2">
          <Textarea
            rows={2}
            value={body}
            onChange={(e) => setBody(e.target.value)}
            placeholder={t('detail.notePh')}
            maxLength={2000}
            aria-label={t('detail.notes')}
            onKeyDown={(e) => {
              if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) void add();
            }}
          />
          <Button size="sm" disabled={!body.trim()} loading={busy} onClick={() => void add()} className="self-start">
            {t('detail.addNote')}
          </Button>
        </div>
      </div>
    </Panel>
  );
}

function PhotosPanel({
  deviceId,
  shopId,
  photos,
  urls,
  canEdit,
  onChanged,
}: {
  deviceId: string;
  shopId: string;
  photos: PhotoRow[];
  urls: Record<string, string>;
  canEdit: boolean;
  onChanged: () => void;
}) {
  const { t } = useTranslation();
  const toast = useToast();
  const ref = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  async function add(files: File[]) {
    setBusy(true);
    try {
      for (const file of files.slice(0, MAX_PHOTOS - photos.length)) await uploadDevicePhoto(shopId, deviceId, file);
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
    setBusy(false);
    onChanged();
  }
  async function hide(p: PhotoRow) {
    const { error } = await supabase.from('device_photos').update({ deleted_at: new Date().toISOString() }).eq('id', p.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    toast({ tone: 'ok', title: t('detail.photoHidden') });
    onChanged();
  }
  return (
    <Panel>
      <PanelHeader
        title={t('detail.photos')}
        actions={
          <span className="num text-xs text-fg-3">
            {photos.length}/{MAX_PHOTOS}
          </span>
        }
      />
      <div className="p-4">
        {photos.length === 0 && !canEdit ? (
          <p className="text-sm text-fg-3">{t('detail.noPhotos')}</p>
        ) : (
          <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
            {photos.map((p, i) => (
              <div key={p.id} className="group relative aspect-square overflow-hidden rounded-md border border-glass-border bg-sunken">
                {urls[p.storage_path] ? (
                  <a href={urls[p.storage_path]} target="_blank" rel="noreferrer">
                    <img src={urls[p.storage_path]} alt={t('intake.photoN', { n: i + 1 })} className="size-full object-cover" />
                  </a>
                ) : (
                  <Skeleton className="size-full" />
                )}
                {canEdit && (
                  <button
                    type="button"
                    onClick={() => void hide(p)}
                    aria-label={t('detail.hidePhoto')}
                    className="absolute end-1 top-1 grid size-6 place-items-center rounded-sm bg-[rgb(0_0_0/0.6)] text-white opacity-0 transition-opacity focus:opacity-100 group-hover:opacity-100"
                  >
                    <X className="size-3.5" />
                  </button>
                )}
              </div>
            ))}
            {canEdit && photos.length < MAX_PHOTOS && (
              <button
                type="button"
                disabled={busy}
                onClick={() => ref.current?.click()}
                className="flex aspect-square flex-col items-center justify-center gap-1 rounded-md border border-dashed border-line-strong text-xs text-fg-3 transition-colors hover:border-accent hover:text-accent disabled:opacity-50"
              >
                <ImagePlus className="size-5" aria-hidden />
                {t('detail.addPhotos')}
              </button>
            )}
          </div>
        )}
        <input
          ref={ref}
          type="file"
          accept="image/*"
          multiple
          capture="environment"
          hidden
          onChange={(e) => {
            void add(Array.from(e.target.files ?? []));
            e.target.value = '';
          }}
        />
      </div>
    </Panel>
  );
}

function ChecksPanel({ deviceId, shopId, status, checks, onSaved }: { deviceId: string; shopId: string; status: DeviceStatus; checks: CheckRow[]; onSaved: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const intake = checks.find((c) => c.stage === 'intake') ?? null;
  const delivery = checks.find((c) => c.stage === 'delivery') ?? null;
  // فحص التسليم بيتفتح لما الجهاز يخلص صيانة
  const deliveryOpen = ['repaired', 'ready', 'delivered', 'unrepairable'].includes(status);
  const [stage, setStage] = useState<'intake' | 'delivery'>(deliveryOpen ? 'delivery' : 'intake');
  const current = stage === 'intake' ? intake : delivery;
  const [items, setItems] = useState<CheckItems>(current?.items ?? {});
  const [busy, setBusy] = useState(false);
  useEffect(() => setItems((stage === 'intake' ? intake : delivery)?.items ?? {}), [stage, intake, delivery]);

  async function save() {
    setBusy(true);
    const r = current
      ? await supabase.from('device_checks').update({ items }).eq('id', current.id)
      : await supabase.from('device_checks').insert({
          id: crypto.randomUUID(),
          shop_id: shopId,
          device_id: deviceId,
          stage,
          items,
        });
    setBusy(false);
    if (r.error) return toast({ tone: 'danger', title: errorMessage(r.error) });
    toast({ tone: 'ok', title: t('checks.saved') });
    onSaved();
  }

  return (
    <Panel>
      <PanelHeader
        title={t('checks.title')}
        actions={
          <div className="flex rounded-sm border border-glass-border p-0.5" role="tablist">
            {(['intake', 'delivery'] as const).map((k) => (
              <button
                key={k}
                type="button"
                role="tab"
                aria-selected={stage === k}
                disabled={k === 'delivery' && !deliveryOpen}
                onClick={() => setStage(k)}
                className={cn('h-6 rounded-xs px-2 text-2xs disabled:opacity-40', stage === k ? 'bg-raised text-fg' : 'text-fg-3')}
              >
                {t(`checks.${k}`)}
              </button>
            ))}
          </div>
        }
      />
      <div className="flex flex-col gap-3 p-4">
        <QuickCheck value={items} onChange={setItems} disabled={status === 'delivered' && stage === 'delivery' && !!delivery} />
        <Button size="sm" loading={busy} onClick={() => void save()} className="self-start">
          {t('checks.save')}
        </Button>
        {intake && delivery && (
          <div className="mt-1 border-t border-glass-border pt-3">
            <div className="mb-1 text-xs font-medium text-fg-2">{t('checks.compare')}</div>
            <CheckCompare intake={intake.items} delivery={delivery.items} />
          </div>
        )}
      </div>
    </Panel>
  );
}
