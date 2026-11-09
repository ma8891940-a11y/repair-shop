import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { readExtras } from '../lib/extras';
import type { Preset } from './settings/ExtrasTab';
import { useNavigate } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { CheckCircle2, ImagePlus, Printer, KeyRound, Phone, ShieldAlert, ShieldCheck, Trash2, UserRound } from 'lucide-react';
import { useMe } from '../app/auth';
import { PageHeader } from '../app/AppShell';
import { useShortcuts } from '../app/shortcuts';
import { supabase } from '../lib/supabase';
import { normalizeEgyptPhone } from '../lib/phone';
import { isValidImei, normalizeImei } from '../lib/imei';
import { formatPounds, parsePounds } from '../lib/money';
import { errorMessage } from '../lib/errors';
import { MAX_PHOTOS, uploadDevicePhoto } from '../lib/photos';
import type { Customer } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { ChipToggle } from '../ui/Checkbox';
import { Panel, PanelHeader } from '../ui/Panel';
import { Alert, Skeleton } from '../ui/Feedback';
import { Dialog } from '../ui/Dialog';
import { Kbd } from '../ui/Kbd';
import { LineIcon } from '../ui/fx/LineIcon';
import { QuickCheck } from '../ui/QuickCheck';
import { SignaturePad } from '../ui/SignaturePad';
import { RoutingFields, type Routing } from '../app/tech/RoutingFields';
import { shouldQueue, useSync } from '../offline/sync';
import { localDb } from '../offline/outbox';
import type { CheckItems } from '../lib/checks';
import { inWarranty } from '../lib/customers';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';
import { InlineAdd, ListOptions, useListLabel, useShopList } from '../app/lists';
import { intakeDocs, printChain, readPrint } from '../lib/printPlan';
import { IntakeAssist } from '../app/assist/IntakeAssist';
import { useSensitiveNames } from '../app/assist';

// الماركات والملحقات والألوان من القوايم اللي بيديرها صاحب المحل (الإعدادات ← القوائم). الافتراضي في src/app/lists.tsx
const QUICK_ISSUES = ['screen', 'battery', 'charging', 'software', 'water', 'speaker', 'mic', 'camera', 'dead'] as const;

type Lookup = { state: 'idle' } | { state: 'loading' } | { state: 'found'; customer: Customer; devices: number } | { state: 'new' };
interface Prev {
  id: string;
  order_no: string;
  received_at: string;
  status: string;
  warranty_until: string | null;
  route_id: string | null;
}

export function IntakeScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const navigate = useNavigate();
  const toast = useToast();
  const formRef = useRef<HTMLFormElement>(null);
  const brands = useShopList('brands').items;
  const accList = useShopList('accessories').items;
  const listLabel = useListLabel();

  const [phone, setPhone] = useState('');
  const [lookup, setLookup] = useState<Lookup>({ state: 'idle' });
  const [custName, setCustName] = useState('');
  useSensitiveNames([custName]);
  const [custArea, setCustArea] = useState('');
  const [brand, setBrand] = useState('');
  const [model, setModel] = useState('');
  const [color, setColor] = useState('');
  const [imei, setImei] = useState('');
  const [prev, setPrev] = useState<Prev[]>([]);
  const [lockType, setLockType] = useState<'none' | 'pin' | 'pattern'>('none');
  const [lockValue, setLockValue] = useState('');
  const [accessories, setAccessories] = useState<string[]>([]);
  const [issue, setIssue] = useState('');
  const [condition, setCondition] = useState('');
  const [estimate, setEstimate] = useState('');
  const [photos, setPhotos] = useState<{ file: File; url: string }[]>([]);
  const [check, setCheck] = useState<CheckItems>({});
  const [signature, setSignature] = useState<string | null>(null);
  const [routing, setRouting] = useState<Routing>({ routeId: null, priority: 'normal', estMinutes: null });
  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [attempt, setAttempt] = useState(0);
  const [saved, setSaved] = useState<{ id: string; orderNo: string | null } | null>(null);
  const extras = readExtras(shop.extras);
  const [presets, setPresets] = useState<Preset[]>([]);
  useEffect(() => {
    if (!extras.quick_issues) return;
    void supabase
      .from('issue_presets')
      .select('id, label, issue, est_cost, sort')
      .is('deleted_at', null)
      .order('sort')
      .order('created_at')
      .then(({ data }) => setPresets((data as Preset[] | null) ?? []));
  }, [extras.quick_issues]);
  const sync = useSync();

  const normPhone = normalizeEgyptPhone(phone);
  const imeiClean = normalizeImei(imei);
  const imeiOk = imeiClean.length > 0 && isValidImei(imeiClean);
  const estMinor = estimate.trim() ? parsePounds(estimate) : null;

  useEffect(() => {
    if (!normPhone) {
      setLookup({ state: 'idle' });
      return;
    }
    let live = true;
    setLookup({ state: 'loading' });
    void (async () => {
      if (!navigator.onLine) return setLookup({ state: 'new' });
      const { data, error } = await supabase.from('customers').select('id, name, phone, area').eq('phone', normPhone).is('deleted_at', null).maybeSingle();
      if (!live) return;
      if (error) {
        // بدون نت: بنكمّل كعميل جديد، والمزامنة بتربطه بالعميل الموجود لو الرقم متسجل قبل كده
        if (shouldQueue(error)) return setLookup({ state: 'new' });
        setFormError(errorMessage(error));
        return setLookup({ state: 'idle' });
      }
      if (!data) return setLookup({ state: 'new' });
      const { count } = await supabase.from('devices').select('id', { count: 'exact', head: true }).eq('customer_id', data.id).is('deleted_at', null);
      if (live) setLookup({ state: 'found', customer: data as Customer, devices: count ?? 0 });
    })();
    return () => {
      live = false;
    };
  }, [normPhone]);

  useEffect(() => {
    if (imeiClean.length < 14) return setPrev([]);
    let live = true;
    const tm = setTimeout(async () => {
      const { data } = await supabase.from('devices').select('id, order_no, received_at, status, warranty_until, route_id').eq('imei', imeiClean).is('deleted_at', null).order('received_at', { ascending: false }).limit(5);
      if (live) setPrev((data ?? []) as Prev[]);
    }, 250);
    return () => {
      live = false;
      clearTimeout(tm);
    };
  }, [imeiClean]);

  const photosRef = useRef(photos);
  photosRef.current = photos;
  useEffect(() => () => photosRef.current.forEach((p) => URL.revokeObjectURL(p.url)), []);

  const shortcuts = useMemo(() => [{ combo: 'Ctrl+Enter', handler: () => formRef.current?.requestSubmit(), allowInInputs: true }], []);
  useShortcuts(shortcuts);

  function addPhotos(files: File[]) {
    setPhotos((cur) => [...cur, ...files.filter((x) => x.type.startsWith('image/')).map((file) => ({ file, url: URL.createObjectURL(file) }))].slice(0, MAX_PHOTOS));
  }

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!normPhone) e.phone = t('intake.phoneInvalid');
    if (lookup.state === 'new' && !custName.trim()) e.custName = t('intake.custNameReq');
    if (!brand.trim()) e.brand = t('intake.brandReq');
    if (!model.trim()) e.model = t('intake.modelReq');
    if (!issue.trim()) e.issue = t('intake.issueReq');
    if (estimate.trim() && estMinor === null) e.estimate = t('intake.estimateBad');
    if (lockType !== 'none' && !lockValue.trim()) e.lock = t('intake.lockReq');
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setFormError(null);
    if (!validate()) return setAttempt((a) => a + 1);
    if (lookup.state === 'loading' || lookup.state === 'idle') return setFormError(t('intake.wait'));
    setBusy(true);
    // المسار من الوصف النهائي (لو الموظف ما اختاروش بإيده): الاقتراح بيتحدّث بعد ربع ثانية من آخر كتابة،
    // فلو حفظ على طول بعد ما كتب الوصف، كان ممكن يتسجل المسار القديم
    let routeId = routing.routeId;
    if (!routing.manual && issue.trim() && navigator.onLine) {
      const { data: detected } = await supabase.rpc('detect_route', { p_issue: issue.trim() });
      if (detected) routeId = detected as string;
    }
    // كل اللي هيتسجل، مبني مرة واحدة بأرقام من التطبيق (عشان لو النت قطع في النص، المزامنة تكمّل من غير تكرار)
    const id = crypto.randomUUID();
    const newCustomer = lookup.state === 'found' ? null : { id: crypto.randomUUID(), shop_id: profile.shop_id, name: custName.trim(), phone: normPhone, area: custArea.trim() || null };
    const customerIdPlanned = lookup.state === 'found' ? lookup.customer.id : newCustomer!.id;
    const payload = {
      customer: newCustomer,
      device: { id, shop_id: profile.shop_id, customer_id: customerIdPlanned, brand: brand.trim(), model: model.trim(), imei: imeiClean || null, color: color.trim() || null, accessories, issue: issue.trim(), cosmetic_condition: condition.trim() || null, intake_signature: signature, priority: routing.priority, est_minutes: routing.estMinutes },
      cost: { id: crypto.randomUUID(), shop_id: profile.shop_id, device_id: id, estimated_cost: estMinor },
      check: Object.keys(check).length > 0 ? { id: crypto.randomUUID(), shop_id: profile.shop_id, device_id: id, stage: 'intake', items: check } : null,
      route: routeId,
      lock: lockType !== 'none' && lockValue.trim() ? { p_kind: lockType, p_value: lockValue.trim() } : null,
    };
    const saveOffline = async () => {
      await sync.queue('intake', id, payload);
      for (const p of photos) {
        const pid = crypto.randomUUID();
        await localDb().blobs.put({ id: pid, deviceId: id, shopId: profile.shop_id, blob: p.file, createdAt: Date.now() });
        await sync.queue('photo', pid, { device: id });
      }
      setSaved({ id, orderNo: null });
    };
    if (!navigator.onLine) {
      try {
        await saveOffline();
      } finally {
        setBusy(false);
      }
      return;
    }
    try {
      let customerId = lookup.state === 'found' ? lookup.customer.id : null;
      if (!customerId) {
        customerId = newCustomer!.id;
        const r = await supabase.from('customers').insert(newCustomer!);
        if (r.error) throw r.error;
      }
      const d = await supabase
        .from('devices')
        .insert({ ...payload.device, id, customer_id: customerId })
        .select('order_no')
        .single();
      if (d.error) throw d.error;
      const c = await supabase.from('device_costs').insert(payload.cost);
      if (c.error) throw c.error;
      // المرحلة 4: المسار والتوزيع على الفنيين
      if (routeId) {
        const rt = await supabase.rpc('set_route', { p_device: id, p_route: routeId });
        if (rt.error) throw rt.error;
      }
      if (lockType !== 'none' && lockValue.trim()) {
        const l = await supabase.rpc('set_device_passcode', { p_device_id: id, p_kind: lockType, p_value: lockValue.trim() });
        if (l.error) throw l.error;
      }
      if (Object.keys(check).length > 0) {
        const ck = await supabase.from('device_checks').insert(payload.check!);
        if (ck.error) throw ck.error;
      }
      for (const p of photos) await uploadDevicePhoto(profile.shop_id, id, p.file);
      setSaved({ id, orderNo: d.data.order_no as string });
      // الطباعة التلقائية (الإعدادات ← الطباعة): المستندات اللي متعلّمة للاستلام بتتطبع ورا بعض (الاستيكر الأول)
      const plan = readPrint(shop.extras);
      const chain = printChain(id, intakeDocs(plan));
      if (plan.autoAfterIntake && chain) navigate(chain);
    } catch (e) {
      if (shouldQueue(e)) {
        // النت قطع في النص: الباقي بيتسجل على الجهاز ويكمّل بعدين
        await saveOffline();
        return;
      }
      setAttempt((a) => a + 1);
      setFormError(errorMessage(e));
      toast({ tone: 'danger', title: t('common.errorTitle'), description: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }

  function reset() {
    photos.forEach((p) => URL.revokeObjectURL(p.url));
    setPhone('');
    setCustName('');
    setCustArea('');
    setBrand('');
    setModel('');
    setColor('');
    setImei('');
    setLockType('none');
    setLockValue('');
    setAccessories([]);
    setIssue('');
    setCondition('');
    setEstimate('');
    setPhotos([]);
    setCheck({});
    setSignature(null);
    setRouting({ routeId: null, priority: 'normal', estMinutes: null });
    setErrors({});
    setSaved(null);
    setTimeout(() => document.getElementById('intake-phone')?.focus(), 50);
  }

  const errCount = Object.keys(errors).length;
  // نفس الجهاز اتسلّم قبل كده ولسه في الضمان: الأنسب يتسجل مرتجع ضمان على نفس الطلب
  const warrantyHit = prev.find((p) => p.status === 'delivered' && inWarranty(p.warranty_until, new Date())) ?? null;
  async function asWarrantyReturn(deviceId: string) {
    setBusy(true);
    const { error } = await supabase.from('devices').update({ status: 'warranty_return' }).eq('id', deviceId);
    setBusy(false);
    if (error) return setFormError(errorMessage(error));
    toast({ tone: 'ok', title: t('warranty.returned') });
    navigate(`/devices/${deviceId}`);
  }
  const cur = f.currency(shop.currency);

  return (
    <form ref={formRef} onSubmit={submit} noValidate>
      <PageHeader
        title={t('intake.title')}
        sub={t('intake.subtitle')}
        actions={
          <span className="hidden items-center gap-1.5 text-xs text-fg-3 sm:flex">
            {t('intake.saveHint')} <Kbd>Ctrl</Kbd>
            <Kbd>Enter</Kbd>
          </span>
        }
      />

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_310px]">
        <div className="flex min-w-0 flex-col gap-4">
          {/* 01 العميل */}
          <Panel>
            <PanelHeader index="01" title={t('intake.customer')} />
            <div className="grid gap-3 p-4 sm:grid-cols-[minmax(0,240px)_minmax(0,1fr)]">
              <Field label={t('intake.phone')} required error={errors.phone}>
                <Input
                  id="intake-phone"
                  dir="ltr"
                  inputMode="tel"
                  mono
                  autoFocus
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  onBlur={() => normPhone && normPhone !== phone && setPhone(normPhone)}
                  placeholder="01xxxxxxxxx"
                  className="text-start"
                />
              </Field>
              <div className="min-h-[60px]">
                <AnimatePresence mode="wait">
                  {lookup.state === 'loading' && (
                    <motion.div key="l" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex h-full flex-col justify-end gap-2 pb-1">
                      <Skeleton className="h-4 w-40" />
                      <Skeleton className="h-3 w-24" />
                    </motion.div>
                  )}
                  {lookup.state === 'found' && (
                    <motion.div key="f" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="flex h-full items-end">
                      <div className="flex w-full items-center gap-3 rounded-md border border-[color-mix(in_srgb,var(--ok)_30%,var(--glass-border))] bg-ok-soft px-3 py-2">
                        <UserRound className="size-4 shrink-0 text-ok" aria-hidden />
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-sm font-semibold text-fg">
                            <bdi>{lookup.customer.name}</bdi>
                          </div>
                          <div className="text-xs text-fg-3">
                            {t('intake.registered')}
                            {lookup.customer.area && (
                              <>
                                {' · '}
                                <bdi>{lookup.customer.area}</bdi>
                              </>
                            )}
                            {' · '}
                            {t('intake.prevDevices', { n: f.number(lookup.devices) })}
                          </div>
                        </div>
                      </div>
                    </motion.div>
                  )}
                  {lookup.state === 'new' && (
                    <motion.div key="n" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} className="grid gap-3 sm:grid-cols-2">
                      <Field label={t('intake.custName')} required error={errors.custName} aside={<span className="text-2xs text-accent">{t('intake.newCustomer')}</span>}>
                        <Input value={custName} onChange={(e) => setCustName(e.target.value)} maxLength={120} autoFocus />
                      </Field>
                      <Field label={t('intake.area')}>
                        <Input value={custArea} onChange={(e) => setCustArea(e.target.value)} />
                      </Field>
                    </motion.div>
                  )}
                  {lookup.state === 'idle' && (
                    <motion.div key="i" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex h-full items-end gap-2 pb-2 text-sm text-fg-3">
                      <Phone className="size-4" aria-hidden />
                      {t('intake.phoneHint')}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>
          </Panel>

          {/* 02 الجهاز */}
          <Panel>
            <PanelHeader index="02" title={t('intake.device')} />
            <div className="flex flex-col gap-3 p-4">
              <div className="flex flex-wrap gap-1.5" role="group" aria-label={t('intake.brandQuick')}>
                {brands.map(({ value: b }) => (
                  <ChipToggle key={b} pressed={brand === b} onChange={(v) => setBrand(v ? b : '')}>
                    <span dir="ltr">{b}</span>
                  </ChipToggle>
                ))}
              </div>
              <div className="grid gap-3 sm:grid-cols-3">
                <div>
                  <Field label={t('intake.brand')} required error={errors.brand}>
                    <Input value={brand} onChange={(e) => setBrand(e.target.value)} maxLength={60} dir="auto" list="list-brands" />
                  </Field>
                  <ListOptions id="list-brands" list="brands" />
                  <InlineAdd list="brands" value={brand} />
                </div>
                <div>
                  <Field label={t('intake.model')} required error={errors.model}>
                    <Input value={model} onChange={(e) => setModel(e.target.value)} maxLength={80} dir="auto" placeholder={t('intake.modelPh')} list="list-models" />
                  </Field>
                  <ListOptions id="list-models" list="models" />
                  <InlineAdd list="models" value={model} />
                </div>
                <div>
                  <Field label={t('intake.color')}>
                    <Input value={color} onChange={(e) => setColor(e.target.value)} list="list-colors" maxLength={40} />
                  </Field>
                  <ListOptions id="list-colors" list="colors" />
                  <InlineAdd list="colors" value={color} />
                </div>
              </div>
              <div className="grid gap-3 sm:grid-cols-2">
                <Field
                  label={t('intake.imei')}
                  hint={imeiClean && !imeiOk ? t('intake.imeiBad') : t('intake.imeiHint')}
                  aside={
                    imeiClean ? (
                      imeiOk ? (
                        <span className="flex items-center gap-1 text-2xs text-ok">
                          <ShieldCheck className="size-3.5" /> {t('intake.imeiOk')}
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-2xs text-warn">
                          <ShieldAlert className="size-3.5" /> {t('intake.imeiCheck')}
                        </span>
                      )
                    ) : undefined
                  }
                >
                  <Input dir="ltr" inputMode="numeric" mono value={imei} onChange={(e) => setImei(e.target.value)} placeholder={t('intake.imeiPh')} className="text-start tracking-wider" />
                </Field>
                <Field label={t('intake.lock')} error={errors.lock} hint={t('intake.lockHint')} aside={<KeyRound className="size-3.5 text-fg-3" aria-hidden />}>
                  <Input
                    dir="ltr"
                    mono
                    disabled={lockType === 'none'}
                    value={lockValue}
                    onChange={(e) => setLockValue(e.target.value)}
                    placeholder={lockType === 'pattern' ? '1-5-9-6' : lockType === 'pin' ? '••••' : t('common.none')}
                    autoComplete="off"
                    className="text-start"
                    leading={
                      <div className="flex shrink-0 rounded-md border border-glass-border bg-sunken/60 p-0.5" role="radiogroup" aria-label={t('intake.lockType')}>
                        {(['none', 'pin', 'pattern'] as const).map((k) => (
                          <button
                            key={k}
                            type="button"
                            role="radio"
                            aria-checked={lockType === k}
                            onClick={() => setLockType(k)}
                            className={cn('relative h-7 rounded-sm px-2.5 text-xs transition-colors', lockType === k ? 'text-fg' : 'text-fg-3 hover:text-fg')}
                          >
                            {lockType === k && <motion.span layoutId="lock-pill" className="absolute inset-0 rounded-sm bg-raised shadow-1" transition={{ duration: 0.18 }} />}
                            <span className="relative">{t(k === 'none' ? 'intake.lockNone' : k === 'pin' ? 'intake.lockPin' : 'intake.lockPattern')}</span>
                          </button>
                        ))}
                      </div>
                    }
                  />
                </Field>
              </div>
              {warrantyHit && (
                <Alert
                  tone="info"
                  title={t('warranty.inTitle')}
                  action={
                    <Button size="sm" variant="primary" loading={busy} onClick={() => void asWarrantyReturn(warrantyHit.id)}>
                      {t('warranty.asReturn')}
                    </Button>
                  }
                >
                  {t('warranty.inText', { order: warrantyHit.order_no, until: f.date(warrantyHit.warranty_until!) })}
                  {/* نفس نوع العطل اللي اتصلح قبل كده = غالبًا مرتجع ضمان حقيقي */}
                  {warrantyHit.route_id && warrantyHit.route_id === routing.routeId && (
                    <span className="mt-1 block font-semibold text-warn" data-testid="warranty-same-fault">
                      {t('warranty.sameFault')}
                    </span>
                  )}
                </Alert>
              )}
              <AnimatePresence>
                {prev.length > 0 && (
                  <Alert tone="warn" title={t('intake.seenBefore', { n: prev.length })}>
                    {prev.map((p) => (
                      <span key={p.id} className="me-3 inline-block">
                        <span className="num" dir="ltr">
                          {p.order_no}
                        </span>{' '}
                        · {f.date(p.received_at)}
                      </span>
                    ))}
                  </Alert>
                )}
              </AnimatePresence>
              <div>
                <div className="mb-1.5 text-sm font-medium text-fg-2">{t('intake.accessories')}</div>
                <div className="flex flex-wrap gap-1.5">
                  {accList.map(({ value: a }) => (
                    <ChipToggle key={a} pressed={accessories.includes(a)} onChange={(v) => setAccessories((c) => (v ? [...c, a] : c.filter((x) => x !== a)))}>
                      {listLabel('accessories', a)}
                    </ChipToggle>
                  ))}
                </div>
              </div>
            </div>
          </Panel>

          {/* 03 العطل والحالة */}
          <Panel>
            <PanelHeader index="03" title={t('intake.issueSec')} />
            <div className="grid gap-3 p-4 sm:grid-cols-2">
              <div className="flex flex-col gap-2 sm:col-span-2">
                <Field label={t('intake.issue')} required error={errors.issue}>
                  <Textarea rows={2} value={issue} onChange={(e) => setIssue(e.target.value)} maxLength={1000} />
                </Field>
                {extras.quick_issues && presets.length > 0 && (
                  <div className="flex flex-wrap gap-1.5" role="group" aria-label={t('extras.presets')} data-testid="intake-presets">
                    {presets.map((p) => (
                      <button
                        key={p.id}
                        type="button"
                        onClick={() => {
                          setIssue(p.issue);
                          if (p.est_cost != null) setEstimate(formatPounds(p.est_cost));
                        }}
                        className="h-7 rounded-sm border border-accent/50 px-2.5 text-xs font-medium text-fg transition-[border-color,transform] active:scale-95 hover:border-accent"
                      >
                        {p.label}
                        {p.est_cost != null && <span className="num ms-1.5 text-fg-3">{f.money(p.est_cost)}</span>}
                      </button>
                    ))}
                  </div>
                )}
                <div className="flex flex-wrap gap-1.5">
                  {QUICK_ISSUES.map((q) => {
                    const label = t(`intake.quick.${q}`);
                    return (
                      <button
                        key={q}
                        type="button"
                        onClick={() => setIssue((c) => (c.includes(label) ? c : c ? `${c}${t('common.sep')}${label}` : label))}
                        className="h-6 rounded-sm border border-dashed border-line-strong px-2 text-xs text-fg-2 transition-[border-color,color,transform] active:scale-95 hover:border-accent hover:text-accent"
                      >
                        + {label}
                      </button>
                    );
                  })}
                </div>
              </div>
              <div className="sm:col-span-2">
                <IntakeAssist
                  brand={brand}
                  model={model}
                  issue={issue}
                  names={[custName]}
                  onApply={(v) => {
                    setIssue(v.issue);
                    if (v.cost != null) setEstimate(formatPounds(v.cost));
                  }}
                />
              </div>
              <RoutingFields issue={issue} brand={brand} value={routing} onChange={setRouting} />
              <div>
                <ConditionChips value={condition} onPick={setCondition} />
                <Field label={t('intake.condition')} hint={t('intake.conditionHint')}>
                <Textarea rows={2} value={condition} onChange={(e) => setCondition(e.target.value)} />
              </Field>
                <InlineAdd list="conditions" value={condition} />
              </div>
              <Field label={t('intake.estimate')} error={errors.estimate} hint={t('intake.estimateHint')}>
                <Input dir="ltr" inputMode="decimal" mono value={estimate} onChange={(e) => setEstimate(e.target.value)} placeholder="0" suffix={cur} className="text-start text-md" />
              </Field>
            </div>
          </Panel>

 {/* 04 الفحص السريع */}
          <Panel>
            <PanelHeader index="04" title={t('checks.title')} actions={<span className="text-2xs text-fg-3">{t('common.optional')}</span>} />
            <div className="p-4">
              <QuickCheck value={check} onChange={setCheck} />
            </div>
          </Panel>

          {/* 05 الصور */}
          <Panel>
            <PanelHeader index="05" title={t('intake.photos')} actions={<span className="num text-xs text-fg-3">{photos.length}/{MAX_PHOTOS}</span>} />
            <div className="p-4">
              <PhotoDrop
                photos={photos}
                onAdd={addPhotos}
                onRemove={(i) =>
                  setPhotos((c) => {
                    URL.revokeObjectURL(c[i].url);
                    return c.filter((_, j) => j !== i);
                  })
                }
              />
            </div>
          </Panel>

          {/* 06 توقيع العميل */}
          <Panel>
            <PanelHeader index="06" title={t('signature.title')} actions={<span className="text-2xs text-fg-3">{t('common.optional')}</span>} />
            <div className="p-4">
              <p className="mb-2 text-xs text-fg-3">{t('signature.text')}</p>
              <SignaturePad value={signature} onChange={setSignature} />
            </div>
          </Panel>
        </div>

        {/* الملخص */}
        <aside className="lg:sticky lg:top-[72px]">
          <Panel elevated glow className="overflow-hidden">
            <div className="border-b border-glass-border px-4 py-3">
              <div className="readout-label">{t('intake.orderNo')}</div>
              <div className="num mt-0.5 text-lg text-fg-3" dir="ltr">
                {new Date().getFullYear()}-····
              </div>
              <div className="text-2xs text-fg-3">{t('intake.orderAuto')}</div>
            </div>
            <dl className="divide-y divide-glass-border text-sm">
              <SummaryRow label={t('intake.customer')} value={lookup.state === 'found' ? lookup.customer.name : custName || null} />
              <SummaryRow label={t('intake.phone')} value={normPhone} mono />
              <SummaryRow label={t('intake.device')} value={[brand, model].filter(Boolean).join(' ') || null} />
              <SummaryRow label="IMEI" value={imeiClean || null} mono warn={!!imeiClean && !imeiOk} />
              <SummaryRow label={t('intake.accessories')} value={accessories.length ? accessories.map((a) => listLabel('accessories', a)).join(t('common.sep')) : null} />
              <SummaryRow label={t('intake.sumLock')} value={t(`intake.lockKind.${lockType}`)} />
              <SummaryRow label={t('intake.photos')} value={t('intake.sumPhotos', { n: photos.length, max: MAX_PHOTOS })} />
            </dl>
            <div className="border-t border-glass-border px-4 py-3">
              <div className="readout-label">{t('intake.estimate')}</div>
              <div className={cn('num mt-1 text-xl', estMinor != null ? 'text-glow text-fg' : 'text-fg-3')}>
                {estMinor != null ? f.money(estMinor) : t('common.none')} <span className="font-sans text-sm text-fg-3">{cur}</span>
              </div>
            </div>
            <div className="flex flex-col gap-2 border-t border-glass-border p-4">
              {formError && (
                <div key={`e${attempt}`}>
                  <Alert tone="danger">{formError}</Alert>
                </div>
              )}
              {errCount > 0 && (
                <div key={`w${attempt}`}>
                  <Alert tone="warn">{t('intake.fix', { n: errCount })}</Alert>
                </div>
              )}
              <Button type="submit" variant="primary" size="lg" loading={busy} className="w-full justify-center" shortcut="Ctrl+Enter" tip={t('intake.save')}>
                {t('intake.save')}
              </Button>
              <Button variant="ghost" size="sm" className="w-full justify-center" onClick={() => navigate('/')}>
                {t('common.cancel')}
              </Button>
            </div>
          </Panel>
        </aside>
      </div>

      <Dialog
        open={!!saved}
        onOpenChange={(v) => !v && reset()}
        title={t('intake.saved')}
        description={t('intake.savedText')}
        footer={
          <>
            <Button variant="ghost" onClick={reset}>
              {t('intake.another')}
            </Button>
            <Button variant="primary" onClick={() => saved && navigate(`/devices/${saved.id}`)}>
              {t('intake.open')}
            </Button>
          </>
        }
      >
        <div className="flex items-center gap-3">
          <motion.span initial={{ scale: 0, rotate: -30 }} animate={{ scale: 1, rotate: 0 }} transition={{ type: 'spring', stiffness: 380, damping: 16 }}>
            <CheckCircle2 className="size-9 text-ok drop-shadow-[0_0_10px_var(--ok)]" aria-hidden />
          </motion.span>
          <div>
            <div className="readout-label">{t('intake.orderNo')}</div>
            {saved?.orderNo ? (
              <div className="num text-glow text-2xl text-fg" dir="ltr">
                {saved.orderNo}
              </div>
            ) : (
              <div>
                <div className="text-lg font-semibold text-warn">{t('sync.tempOrder')}</div>
                <div className="text-2xs text-fg-3">{t('sync.tempOrderHint')}</div>
              </div>
            )}
          </div>
        </div>
        {/* اطبع بإيدك: المستندات المتعلّمة للاستلام في الإعدادات ← الطباعة */}
        {saved?.orderNo && intakeDocs(readPrint(shop.extras)).length > 0 && (
          <div className="mt-4 flex flex-wrap gap-2" data-testid="intake-print">
            {intakeDocs(readPrint(shop.extras)).map((doc) => (
              <Button key={doc} size="sm" icon={<Printer className="size-4" />} onClick={() => navigate(`/print/${doc}/${saved.id}`)} data-testid={`intake-print-${doc}`}>
                {t(`print.docs.${doc}`)}
              </Button>
            ))}
          </div>
        )}
      </Dialog>
    </form>
  );
}

function SummaryRow({ label, value, mono, warn }: { label: string; value: string | null; mono?: boolean; warn?: boolean }) {
  const { t } = useTranslation();
  return (
    <div className="flex items-baseline justify-between gap-3 px-4 py-2">
      <dt className="shrink-0 text-xs text-fg-3">{label}</dt>
      <AnimatePresence mode="wait" initial={false}>
        <motion.dd
          key={value ?? '-'}
          initial={{ opacity: 0, y: 3 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -3 }}
          transition={{ duration: 0.14 }}
          className={cn('min-w-0 truncate text-end', value ? 'text-fg' : 'text-fg-3', mono && 'num', warn && 'text-warn')}
          dir={mono ? 'ltr' : undefined}
        >
          {value || t('common.none')}
        </motion.dd>
      </AnimatePresence>
    </div>
  );
}

function PhotoDrop({ photos, onAdd, onRemove }: { photos: { url: string }[]; onAdd: (f: File[]) => void; onRemove: (i: number) => void }) {
  const { t } = useTranslation();
  const ref = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);
  const full = photos.length >= MAX_PHOTOS;
  return (
    <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
      <AnimatePresence initial={false}>
        {photos.map((p, i) => (
          <motion.div key={p.url} layout initial={{ opacity: 0, scale: 0.9 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.9 }} className="group relative aspect-square overflow-hidden rounded-md border border-glass-border bg-sunken">
            <img src={p.url} alt={t('intake.photoN', { n: i + 1 })} className="size-full object-cover" />
            <button
              type="button"
              onClick={() => onRemove(i)}
              aria-label={t('intake.photoRemove', { n: i + 1 })}
              className="absolute end-1 top-1 grid size-6 place-items-center rounded-sm bg-[rgb(0_0_0/0.6)] text-white opacity-0 transition-opacity focus:opacity-100 group-hover:opacity-100"
            >
              <Trash2 className="size-3.5" />
            </button>
            <span className="num absolute bottom-1 start-1 rounded-xs bg-[rgb(0_0_0/0.55)] px-1 text-2xs text-white">{i + 1}</span>
          </motion.div>
        ))}
      </AnimatePresence>
      {!full && (
        <button
          type="button"
          onClick={() => ref.current?.click()}
          onDragOver={(e) => {
            e.preventDefault();
            setOver(true);
          }}
          onDragLeave={() => setOver(false)}
          onDrop={(e) => {
            e.preventDefault();
            setOver(false);
            onAdd(Array.from(e.dataTransfer.files));
          }}
          className={cn(
            'flex aspect-square flex-col items-center justify-center gap-1 rounded-md border border-dashed text-xs transition-colors',
            over ? 'border-accent bg-accent-soft text-accent' : 'border-line-strong text-fg-3 hover:border-accent hover:text-accent',
            photos.length === 0 && 'col-span-3 aspect-auto h-28 flex-row gap-3 text-sm sm:col-span-6',
          )}
        >
          {photos.length === 0 ? <LineIcon name="scan" size={44} /> : <ImagePlus className="size-5" aria-hidden />}
          {photos.length === 0 ? t('intake.photosEmpty') : t('intake.photoAdd')}
        </button>
      )}
      <input
        ref={ref}
        type="file"
        accept="image/*"
        multiple
        capture="environment"
        hidden
        onChange={(e) => {
          onAdd(Array.from(e.target.files ?? []));
          e.target.value = '';
        }}
      />
    </div>
  );
}

/** الحالة الشكلية الجاهزة (من القوايم): دوسة بتضيف البند للخانة */
function ConditionChips({ value, onPick }: { value: string; onPick: (v: string) => void }) {
  const { t } = useTranslation();
  const label = useListLabel();
  const { items } = useShopList('conditions');
  if (!items.length) return null;
  const parts = value.split(/[\u060C,]\s*/).map((x) => x.trim()).filter(Boolean);
  return (
    <div className="mb-1.5 flex flex-wrap gap-1.5" role="group" aria-label={t('lists.names.conditions')} data-testid="condition-chips">
      {items.map((i) => {
        const l = label('conditions', i.value);
        const on = parts.includes(l);
        return (
          <ChipToggle key={i.value} pressed={on} onChange={(v) => onPick((v ? [...parts, l] : parts.filter((x) => x !== l)).join(t('common.sep')))}>
            {l}
          </ChipToggle>
        );
      })}
    </div>
  );
}
