import { useEffect, useMemo, useRef, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { AnimatePresence, motion } from 'motion/react';
import { Camera, CheckCircle2, ImagePlus, KeyRound, Phone, ShieldCheck, ShieldAlert, Trash2, UserRound } from 'lucide-react';
import { useMe } from '../app/auth';
import { PageHeader } from '../app/AppShell';
import { useShortcuts } from '../app/shortcuts';
import { supabase } from '../lib/supabase';
import { normalizeEgyptPhone } from '../lib/phone';
import { isValidImei, normalizeImei } from '../lib/imei';
import { formatPounds, parsePounds } from '../lib/money';
import { arabicError } from '../lib/errors';
import { MAX_PHOTOS, uploadDevicePhoto } from '../lib/photos';
import { formatDateTime } from '../lib/dates';
import type { Customer } from '../lib/types';
import { Button } from '../ui/Button';
import { Field, Input, Textarea } from '../ui/Field';
import { ChipToggle } from '../ui/Checkbox';
import { Panel, PanelHeader } from '../ui/Panel';
import { Alert, Skeleton } from '../ui/Feedback';
import { Dialog } from '../ui/Dialog';
import { Kbd } from '../ui/Kbd';
import { cn } from '../ui/cn';

const BRANDS = ['Samsung', 'iPhone', 'Xiaomi', 'Oppo', 'Realme', 'Infinix', 'Vivo', 'Honor', 'Huawei', 'Tecno'];
const ACCESSORIES = ['شريحة', 'جراب', 'كارت ذاكرة', 'شاحن', 'سماعة', 'علبة'];
const QUICK_ISSUES = ['شاشة مكسورة', 'بطارية', 'مش بيشحن', 'سوفت وير', 'دخل مية', 'السماعة', 'المايك', 'الكاميرا', 'مش بيفتح'];

type Lookup = { state: 'idle' } | { state: 'loading' } | { state: 'found'; customer: Customer; devices: number } | { state: 'new' };

interface Prev {
  id: string;
  order_no: string;
  received_at: string;
}

export function IntakeScreen() {
  const { profile } = useMe();
  const navigate = useNavigate();
  const formRef = useRef<HTMLFormElement>(null);

  const [phone, setPhone] = useState('');
  const [lookup, setLookup] = useState<Lookup>({ state: 'idle' });
  const [custName, setCustName] = useState('');
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

  const [busy, setBusy] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [formError, setFormError] = useState<string | null>(null);
  const [saved, setSaved] = useState<{ id: string; orderNo: string } | null>(null);

  const normPhone = normalizeEgyptPhone(phone);
  const imeiClean = normalizeImei(imei);
  const imeiOk = imeiClean.length > 0 && isValidImei(imeiClean);
  const estPiasters = estimate.trim() ? parsePounds(estimate) : null;

  // البحث عن العميل تلقائيًا أول ما الرقم يكمل
  useEffect(() => {
    if (!normPhone) {
      setLookup({ state: 'idle' });
      return;
    }
    let active = true;
    setLookup({ state: 'loading' });
    void (async () => {
      const { data, error } = await supabase.from('customers').select('id, name, phone, area').eq('phone', normPhone).is('deleted_at', null).maybeSingle();
      if (!active) return;
      if (error) {
        setFormError(arabicError(error));
        setLookup({ state: 'idle' });
        return;
      }
      if (!data) return setLookup({ state: 'new' });
      const { count } = await supabase.from('devices').select('id', { count: 'exact', head: true }).eq('customer_id', data.id).is('deleted_at', null);
      if (active) setLookup({ state: 'found', customer: data as Customer, devices: count ?? 0 });
    })();
    return () => {
      active = false;
    };
  }, [normPhone]);

  // تنبيه IMEI دخل قبل كده في نفس المحل
  useEffect(() => {
    if (imeiClean.length < 14) {
      setPrev([]);
      return;
    }
    let active = true;
    const t = setTimeout(async () => {
      const { data } = await supabase
        .from('devices')
        .select('id, order_no, received_at')
        .eq('imei', imeiClean)
        .is('deleted_at', null)
        .order('received_at', { ascending: false })
        .limit(5);
      if (active) setPrev((data ?? []) as Prev[]);
    }, 250);
    return () => {
      active = false;
      clearTimeout(t);
    };
  }, [imeiClean]);

  // نمسح معاينات الصور من الذاكرة لما نخرج من الشاشة بس
  const photosRef = useRef(photos);
  photosRef.current = photos;
  useEffect(() => () => photosRef.current.forEach((p) => URL.revokeObjectURL(p.url)), []);

  const shortcuts = useMemo(() => [{ combo: 'Ctrl+Enter', handler: () => formRef.current?.requestSubmit(), allowInInputs: true }], []);
  useShortcuts(shortcuts);

  function addPhotos(files: File[]) {
    setPhotos((cur) => [...cur, ...files.filter((f) => f.type.startsWith('image/')).map((file) => ({ file, url: URL.createObjectURL(file) }))].slice(0, MAX_PHOTOS));
  }

  function validate(): boolean {
    const e: Record<string, string> = {};
    if (!normPhone) e.phone = 'رقم موبايل مصري من 11 رقم (010، 011، 012، 015)';
    if (lookup.state === 'new' && !custName.trim()) e.custName = 'اكتب اسم العميل';
    if (!brand.trim()) e.brand = 'اختار أو اكتب النوع';
    if (!model.trim()) e.model = 'اكتب الموديل';
    if (!issue.trim()) e.issue = 'اكتب العطل زي ما العميل قاله';
    if (estimate.trim() && estPiasters === null) e.estimate = 'رقم غير صحيح. مثال: 350 أو 350.50';
    if (lockType !== 'none' && !lockValue.trim()) e.lock = 'اكتب الرقم السري أو النمط، أو اختار «بدون قفل»';
    setErrors(e);
    return Object.keys(e).length === 0;
  }

  async function submit(ev: FormEvent) {
    ev.preventDefault();
    setFormError(null);
    if (!validate()) return;
    if (lookup.state === 'loading' || lookup.state === 'idle') return setFormError('استنى لحظة لحد ما نتأكد من العميل');
    setBusy(true);
    try {
      let customerId = lookup.state === 'found' ? lookup.customer.id : null;
      if (!customerId) {
        customerId = crypto.randomUUID();
        const r = await supabase.from('customers').insert({ id: customerId, shop_id: profile.shop_id, name: custName.trim(), phone: normPhone, area: custArea.trim() || null });
        if (r.error) throw r.error;
      }
      const id = crypto.randomUUID();
      const d = await supabase
        .from('devices')
        .insert({
          id,
          shop_id: profile.shop_id,
          customer_id: customerId,
          brand: brand.trim(),
          model: model.trim(),
          imei: imeiClean || null,
          color: color.trim() || null,
          accessories,
          issue: issue.trim(),
          cosmetic_condition: condition.trim() || null,
        })
        .select('order_no')
        .single();
      if (d.error) throw d.error;
      const c = await supabase.from('device_costs').insert({ shop_id: profile.shop_id, device_id: id, estimated_cost: estPiasters });
      if (c.error) throw c.error;
      if (lockType !== 'none' && lockValue.trim()) {
        const l = await supabase.rpc('set_device_passcode', { p_device_id: id, p_kind: lockType, p_value: lockValue.trim() });
        if (l.error) throw l.error;
      }
      for (const p of photos) await uploadDevicePhoto(profile.shop_id, id, p.file);
      setSaved({ id, orderNo: d.data.order_no as string });
    } catch (e) {
      setFormError(arabicError(e));
    } finally {
      setBusy(false);
    }
  }

  function reset() {
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
    setErrors({});
    setSaved(null);
    setTimeout(() => document.getElementById('intake-phone')?.focus(), 50);
  }

  return (
    <form ref={formRef} onSubmit={submit} noValidate>
      <PageHeader
        title="استلام جهاز"
        sub="سجّل الجهاز قدام العميل. كل حاجة هنا بتتطبع على الإيصال."
        actions={
          <span className="hidden items-center gap-1.5 text-xs text-fg-3 sm:flex">
            حفظ <Kbd>Ctrl</Kbd>
            <Kbd>Enter</Kbd>
          </span>
        }
      />

      <div className="grid items-start gap-4 lg:grid-cols-[minmax(0,1fr)_300px]">
        <div className="flex min-w-0 flex-col gap-4">
          {/* 01 العميل */}
          <Panel>
            <PanelHeader index="01" title="العميل" />
            <div className="grid gap-3 p-4 sm:grid-cols-[minmax(0,240px)_minmax(0,1fr)]">
              <Field label="رقم الموبايل (واتساب)" required error={errors.phone}>
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
                    <motion.div
                      key="f"
                      initial={{ opacity: 0, x: -6 }}
                      animate={{ opacity: 1, x: 0 }}
                      exit={{ opacity: 0 }}
                      className="flex h-full items-end"
                    >
                      <div className="flex w-full items-center gap-3 rounded-md border border-[color-mix(in_srgb,var(--ok)_30%,var(--line))] bg-ok-soft px-3 py-2">
                        <UserRound className="size-4 shrink-0 text-ok" aria-hidden />
                        <div className="min-w-0 flex-1">
                          <div className="truncate text-sm font-semibold text-fg">{lookup.customer.name}</div>
                          <div className="text-xs text-fg-3">
                            عميل متسجّل{lookup.customer.area && ` · ${lookup.customer.area}`} · <span className="num">{lookup.devices}</span> جهاز قبل كده
                          </div>
                        </div>
                      </div>
                    </motion.div>
                  )}
                  {lookup.state === 'new' && (
                    <motion.div key="n" initial={{ opacity: 0, x: -6 }} animate={{ opacity: 1, x: 0 }} exit={{ opacity: 0 }} className="grid gap-3 sm:grid-cols-2">
                      <Field label="اسم العميل" required error={errors.custName} aside={<span className="text-2xs text-accent">عميل جديد</span>}>
                        <Input value={custName} onChange={(e) => setCustName(e.target.value)} maxLength={120} autoFocus />
                      </Field>
                      <Field label="المنطقة">
                        <Input value={custArea} onChange={(e) => setCustArea(e.target.value)} />
                      </Field>
                    </motion.div>
                  )}
                  {lookup.state === 'idle' && (
                    <motion.div key="i" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="flex h-full items-end pb-2 text-sm text-fg-3">
                      <Phone className="me-2 size-4" aria-hidden />
                      اكتب الرقم، وهنشوف العميل متسجّل ولا جديد.
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>
          </Panel>

          {/* 02 الجهاز */}
          <Panel>
            <PanelHeader index="02" title="الجهاز" />
            <div className="flex flex-col gap-3 p-4">
              <div className="flex flex-wrap gap-1.5" role="group" aria-label="اختيار سريع للنوع">
                {BRANDS.map((b) => (
                  <ChipToggle key={b} pressed={brand === b} onChange={(v) => setBrand(v ? b : '')}>
                    <span dir="ltr">{b}</span>
                  </ChipToggle>
                ))}
              </div>
              <div className="grid gap-3 sm:grid-cols-3">
                <Field label="النوع" required error={errors.brand}>
                  <Input value={brand} onChange={(e) => setBrand(e.target.value)} maxLength={60} dir="auto" />
                </Field>
                <Field label="الموديل" required error={errors.model}>
                  <Input value={model} onChange={(e) => setModel(e.target.value)} maxLength={80} dir="auto" placeholder="A52، 13 Pro..." />
                </Field>
                <Field label="اللون">
                  <Input value={color} onChange={(e) => setColor(e.target.value)} />
                </Field>
              </div>
              <div className="grid gap-3 sm:grid-cols-[minmax(0,1fr)_minmax(0,1fr)]">
                <Field
                  label="IMEI"
                  hint={imeiClean && !imeiOk ? 'الرقم شكله مش صحيح (15 رقم). اتأكد منه، وتقدر تكمّل عادي.' : 'اطلب *#06# من الجهاز'}
                  aside={
                    imeiClean ? (
                      imeiOk ? (
                        <span className="flex items-center gap-1 text-2xs text-ok">
                          <ShieldCheck className="size-3.5" /> صحيح
                        </span>
                      ) : (
                        <span className="flex items-center gap-1 text-2xs text-warn">
                          <ShieldAlert className="size-3.5" /> راجعه
                        </span>
                      )
                    ) : undefined
                  }
                >
                  <Input dir="ltr" inputMode="numeric" mono value={imei} onChange={(e) => setImei(e.target.value)} placeholder="15 رقم" className="text-start tracking-wider" />
                </Field>
                <Field
                  label="قفل الجهاز"
                  error={errors.lock}
                  hint="النمط: أرقام النقط بالترتيب. متشفّر، والفني وصاحب المحل بس يشوفوه، وبيتمسح عند التسليم."
                  aside={<KeyRound className="size-3.5 text-fg-3" aria-hidden />}
                >
                  <Input
                    dir="ltr"
                    mono
                    disabled={lockType === 'none'}
                    value={lockValue}
                    onChange={(e) => setLockValue(e.target.value)}
                    placeholder={lockType === 'pattern' ? '1-5-9-6' : lockType === 'pin' ? '••••' : '—'}
                    autoComplete="off"
                    className="text-start"
                    leading={
                      <div className="flex shrink-0 rounded-md border border-line bg-sunken/60 p-0.5" role="radiogroup" aria-label="نوع القفل">
                        {(
                          [
                            ['none', 'بدون'],
                            ['pin', 'رقم'],
                            ['pattern', 'نمط'],
                          ] as const
                        ).map(([k, l]) => (
                          <button
                            key={k}
                            type="button"
                            role="radio"
                            aria-checked={lockType === k}
                            onClick={() => setLockType(k)}
                            className={cn('h-7 rounded-sm px-2.5 text-xs transition-colors', lockType === k ? 'bg-raised text-fg shadow-1' : 'text-fg-3 hover:text-fg')}
                          >
                            {l}
                          </button>
                        ))}
                      </div>
                    }
                  />
                </Field>
              </div>
              <AnimatePresence>
                {prev.length > 0 && (
                  <Alert tone="warn" title={`الجهاز ده دخل المحل قبل كده (${prev.length} مرة)`}>
                    {prev.map((p) => (
                      <span key={p.id} className="me-3 inline-block">
                        <span className="num" dir="ltr">
                          {p.order_no}
                        </span>{' '}
                        · {formatDateTime(p.received_at)}
                      </span>
                    ))}
                  </Alert>
                )}
              </AnimatePresence>
              <div>
                <div className="mb-1.5 text-sm font-medium text-fg-2">الملحقات المستلمة</div>
                <div className="flex flex-wrap gap-1.5">
                  {ACCESSORIES.map((a) => (
                    <ChipToggle key={a} pressed={accessories.includes(a)} onChange={(v) => setAccessories((cur) => (v ? [...cur, a] : cur.filter((x) => x !== a)))}>
                      {a}
                    </ChipToggle>
                  ))}
                </div>
              </div>
            </div>
          </Panel>

          {/* 03 العطل والحالة */}
          <Panel>
            <PanelHeader index="03" title="العطل والحالة" />
            <div className="grid gap-3 p-4 sm:grid-cols-2">
              <div className="flex flex-col gap-2 sm:col-span-2">
                <Field label="العطل زي ما العميل وصفه" required error={errors.issue}>
                  <Textarea rows={2} value={issue} onChange={(e) => setIssue(e.target.value)} maxLength={1000} />
                </Field>
                <div className="flex flex-wrap gap-1.5">
                  {QUICK_ISSUES.map((q) => (
                    <button
                      key={q}
                      type="button"
                      onClick={() => setIssue((cur) => (cur.includes(q) ? cur : cur ? `${cur}، ${q}` : q))}
                      className="h-6 rounded-sm border border-dashed border-line-strong px-2 text-xs text-fg-2 transition-colors hover:border-accent hover:text-accent"
                    >
                      + {q}
                    </button>
                  ))}
                </div>
              </div>
              <Field label="الحالة الشكلية" hint="خدوش، كسر، انحناء...">
                <Textarea rows={2} value={condition} onChange={(e) => setCondition(e.target.value)} />
              </Field>
              <Field label="التكلفة التقديرية" error={errors.estimate} hint="اختياري. تقدر تحدّدها بعد الفحص.">
                <Input dir="ltr" inputMode="decimal" mono value={estimate} onChange={(e) => setEstimate(e.target.value)} placeholder="0" suffix="ج.م" className="text-start text-md" />
              </Field>
            </div>
          </Panel>

          {/* 04 الصور */}
          <Panel>
            <PanelHeader index="04" title="صور الجهاز" actions={<span className="num text-xs text-fg-3">{photos.length}/{MAX_PHOTOS}</span>} />
            <div className="p-4">
              <PhotoDrop photos={photos} onAdd={addPhotos} onRemove={(i) =>
                  setPhotos((cur) => {
                    URL.revokeObjectURL(cur[i].url);
                    return cur.filter((_, j) => j !== i);
                  })
                } />
            </div>
          </Panel>
        </div>

        {/* الملخص */}
        <aside className="lg:sticky lg:top-[72px]">
          <Panel className="overflow-hidden">
            <div className="border-b border-line bg-raised px-4 py-3">
              <div className="readout-label">رقم الطلب</div>
              <div className="num mt-0.5 text-lg text-fg-3" dir="ltr">
                {new Date().getFullYear()}-····
              </div>
              <div className="text-2xs text-fg-3">بيتحدد تلقائيًا عند الحفظ</div>
            </div>
            <dl className="divide-y divide-line text-sm">
              <SummaryRow label="العميل" value={lookup.state === 'found' ? lookup.customer.name : custName || null} />
              <SummaryRow label="الموبايل" value={normPhone} mono />
              <SummaryRow label="الجهاز" value={[brand, model].filter(Boolean).join(' ') || null} />
              <SummaryRow label="IMEI" value={imeiClean || null} mono warn={!!imeiClean && !imeiOk} />
              <SummaryRow label="الملحقات" value={accessories.length ? accessories.join('، ') : null} />
              <SummaryRow label="قفل" value={lockType === 'none' ? 'بدون' : lockType === 'pin' ? 'رقم سري' : 'نمط'} />
              <SummaryRow label="الصور" value={`${photos.length} من ${MAX_PHOTOS}`} />
            </dl>
            <div className="border-t border-line px-4 py-3">
              <div className="readout-label">التكلفة التقديرية</div>
              <div className={cn('num mt-1 text-xl', estPiasters != null ? 'text-fg' : 'text-fg-3')}>
                {estPiasters != null ? formatPounds(estPiasters) : '—'} <span className="font-sans text-sm text-fg-3">ج.م</span>
              </div>
            </div>
            <div className="flex flex-col gap-2 border-t border-line p-4">
              {formError && <Alert tone="danger">{formError}</Alert>}
              {Object.keys(errors).length > 0 && <Alert tone="warn">فيه {Object.keys(errors).length} حقل محتاج مراجعة.</Alert>}
              <Button type="submit" variant="primary" size="lg" loading={busy} className="w-full justify-center" shortcut="Ctrl+Enter" tip="حفظ الاستلام">
                حفظ الاستلام
              </Button>
              <Button variant="ghost" size="sm" className="w-full justify-center" onClick={() => navigate('/')}>
                إلغاء
              </Button>
            </div>
          </Panel>
        </aside>
      </div>

      <Dialog
        open={!!saved}
        onOpenChange={(v) => !v && reset()}
        title="اتسجّل الجهاز"
        description="اطبع الإيصال واديه للعميل."
        footer={
          <>
            <Button variant="ghost" onClick={reset}>
              استلام جهاز تاني
            </Button>
            <Button variant="primary" onClick={() => saved && navigate(`/devices/${saved.id}`)}>
              فتح الجهاز
            </Button>
          </>
        }
      >
        <div className="flex items-center gap-3">
          <CheckCircle2 className="size-8 text-ok" aria-hidden />
          <div>
            <div className="readout-label">رقم الطلب</div>
            <div className="num text-2xl text-fg" dir="ltr">
              {saved?.orderNo}
            </div>
          </div>
        </div>
      </Dialog>
    </form>
  );
}

function SummaryRow({ label, value, mono, warn }: { label: string; value: string | null; mono?: boolean; warn?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-3 px-4 py-2">
      <dt className="shrink-0 text-xs text-fg-3">{label}</dt>
      <dd className={cn('min-w-0 truncate text-end', value ? 'text-fg' : 'text-fg-3', mono && 'num', warn && 'text-warn')} dir={mono ? 'ltr' : undefined}>
        {value || '—'}
      </dd>
    </div>
  );
}

function PhotoDrop({ photos, onAdd, onRemove }: { photos: { url: string }[]; onAdd: (f: File[]) => void; onRemove: (i: number) => void }) {
  const ref = useRef<HTMLInputElement>(null);
  const [over, setOver] = useState(false);
  const full = photos.length >= MAX_PHOTOS;
  return (
    <div className="grid grid-cols-3 gap-2 sm:grid-cols-6">
      {photos.map((p, i) => (
        <motion.div key={p.url} layout initial={{ opacity: 0, scale: 0.94 }} animate={{ opacity: 1, scale: 1 }} className="group relative aspect-square overflow-hidden rounded-md border border-line bg-sunken">
          <img src={p.url} alt={`صورة ${i + 1}`} className="size-full object-cover" />
          <button
            type="button"
            onClick={() => onRemove(i)}
            aria-label={`شيل الصورة ${i + 1}`}
            className="absolute end-1 top-1 grid size-6 place-items-center rounded-sm bg-[rgb(0_0_0/0.6)] text-white opacity-0 transition-opacity focus:opacity-100 group-hover:opacity-100"
          >
            <Trash2 className="size-3.5" />
          </button>
          <span className="num absolute bottom-1 start-1 rounded-xs bg-[rgb(0_0_0/0.55)] px-1 text-2xs text-white">{i + 1}</span>
        </motion.div>
      ))}
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
            photos.length === 0 && 'col-span-3 aspect-auto h-24 flex-row gap-2 text-sm sm:col-span-6',
          )}
        >
          {photos.length === 0 ? <Camera className="size-5" aria-hidden /> : <ImagePlus className="size-5" aria-hidden />}
          {photos.length === 0 ? 'صوّر الجهاز من كل الجهات، أو اسحب الصور هنا' : 'إضافة'}
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
