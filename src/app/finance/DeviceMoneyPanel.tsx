import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Calculator, HandCoins, PackageMinus, Pencil, Truck, Undo2 } from 'lucide-react';
import { useCanCorrect } from '../correct';
import { ReverseDialog } from './ReverseDialog';
import { EditEntryDialog } from './EditEntryDialog';
import { useLoad } from '../useLoad';
import { useMe } from '../auth';
import { loadCashboxes, opId, rpc, useAccountName, type DeviceMoney, type StockRow } from '../ledgerApi';
import { readExtras } from '../../lib/extras';
import { OpDialog, warmOpLists } from './OpDialog';
import { supabase } from '../../lib/supabase';
import { parsePounds } from '../../lib/money';
import { suggestPrice } from '../../lib/ledger';
import { toLatinDigits } from '../../lib/digits';
import { errorMessage } from '../../lib/errors';
import type { DeviceStatus } from '../../lib/status';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/** فلوس الجهاز (صاحب المحل والاستقبال): التكلفة، والمدفوع، والباقي، والدفعات، والتسليم بالآجل */
export function DeviceMoneyPanel({ deviceId, customer, orderNo, status, finalCost, version = 0, onChanged }: { deviceId: string; customer: { id: string; name: string } | null; orderNo: string; status: DeviceStatus; finalCost: number | null | undefined; version?: number; onChanged: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const toast = useToast();
  const owner = profile.role === 'owner';
  const [pay, setPay] = useState(false);
  const [calc, setCalc] = useState(false);
  const canCorrect = useCanCorrect();
  const [fix, setFix] = useState<{ mode: 'edit' | 'cancel'; entry_id: string; entry_no: number; amount: number } | null>(null);
  // الخزن تتحفظ على الجهاز من دلوقتي، عشان الدفعة تتسجل صح لو النت فصل قبل ما الفورم يتفتح
  useEffect(() => {
    if (profile.role === 'owner' || profile.role === 'reception') void warmOpLists('payment', profile.id).catch(() => undefined);
  }, [profile.id, profile.role]);
  const { data, error, loading, reload } = useLoad(async () => {
    const [m, sug] = await Promise.all([
      rpc<DeviceMoney>('device_money', { p_device: deviceId }),
      rpc<{ price: number; labor: number; parts?: number; margin?: number }>('suggest_device_price', { p_device: deviceId }),
    ]);
    return { ...m, suggestion: sug };
    // البند 14: آخر نسخة على الجهاز، فالدفعة بتتسجل من غير نت
  }, [deviceId, status, finalCost, version], { cacheKey: `device-money:${deviceId}` });
  const cur = f.currency(shop.currency);
  const done = () => {
    reload();
    onChanged();
  };
  async function credit() {
    try {
      await rpc('deliver_on_credit', { p_device: deviceId });
      toast({ tone: 'ok', title: t('money.creditDone') });
      done();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  const canDeliver = status === 'ready' || status === 'unrepairable';

  return (
    <Panel>
      <PanelHeader
        title={t('money.title')}
        actions={
          owner && (
            <Button size="sm" variant="ghost" icon={<Calculator className="size-4" />} onClick={() => setCalc((v) => !v)} aria-expanded={calc}>
              {t('money.calculator')}
            </Button>
          )
        }
      />
      {error ? (
        <Alert tone="danger" className="m-4">
          {error}
        </Alert>
      ) : loading || !data ? (
        <div className="p-4">
          <Skeleton className="h-16 w-full" />
        </div>
      ) : (
        <div className="flex flex-col gap-3 p-4">
          <div className="grid grid-cols-3 gap-2">
            <Cell label={t('money.final')} value={data.final != null ? f.money(data.final) : t('common.none')} />
            <Cell label={t('money.paid')} value={f.money(Number(data.paid))} tone="text-ok" />
            <Cell label={t('money.due')} value={f.money(Number(data.due))} tone={Number(data.due) > 0 ? 'text-warn' : 'text-fg'} testid="device-due" />
          </div>
          {owner && data.parts_cost != null && Number(data.parts_cost) > 0 && (
            <p className="text-xs text-fg-3">
              {t('money.partsCost')}: <span className="num text-fg-2">{f.money(Number(data.parts_cost))}</span>
              {data.final != null && (
                <>
                  {' · '}
                  {t('money.deviceProfit')}: <span className="num text-fg-2">{f.money(data.final - Number(data.parts_cost))}</span>
                </>
              )}
            </p>
          )}
          {status !== 'delivered' && data.suggestion.price > 0 && data.final !== data.suggestion.price && (
            <div className="flex flex-wrap items-center gap-2 rounded-md border border-glass-border bg-sunken/40 px-3 py-2 text-sm">
              <span className="text-fg-2">
                {t('money.suggested')}: <span className="num font-semibold text-fg" data-testid="auto-suggested">{f.money(data.suggestion.price)}</span> <span className="text-2xs text-fg-3">{cur}</span>
              </span>
              <Button size="sm" variant="ghost" className="ms-auto" onClick={() => void applyFinal(deviceId, data.suggestion.price, t('detail.costsSaved'), toast, done)}>
                {t('money.useAsFinal')}
              </Button>
            </div>
          )}
          {calc && owner && (
            <PricingCalculator deviceId={deviceId} partsCost={Number(data.parts_cost ?? 0)} labor={data.suggestion.labor} margin={data.suggestion.margin ?? shop.default_margin_pct ?? 20} locked={status === 'delivered'} onApplied={done} />
          )}
          {data.payments.length > 0 && (
            <ul className="divide-y divide-glass-border rounded-md border border-glass-border text-sm">
              {data.payments.map((p) => (
                <li key={p.id} className={cn('flex items-center gap-3 px-3 py-1.5', p.reversed && 'text-fg-3 line-through')}>
                  <span className="num text-fg">{f.money(Number(p.amount))}</span>
                  <span className="text-2xs text-fg-3">{t(`payments.${p.method}`, { defaultValue: p.method })}</span>
                  {p.reversed && (
                    <span className="inline-block rounded-full border border-line px-1.5 text-2xs text-fg-3" data-testid="payment-cancelled">
                      {t('fin.cancelledTag')}
                    </span>
                  )}
                  <span className="ms-auto text-2xs text-fg-3">
                    {p.by} · {f.dateTime(p.created_at)}
                  </span>
                  {canCorrect && !p.reversed && (
                    <span className="flex gap-0.5">
                      <button type="button" onClick={() => setFix({ mode: 'edit', entry_id: p.entry_id, entry_no: 0, amount: Number(p.amount) })} className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-accent" aria-label={t('edit.edit')} title={t('edit.edit')} data-testid="payment-edit">
                        <Pencil className="size-3.5" aria-hidden />
                      </button>
                      <button type="button" onClick={() => setFix({ mode: 'cancel', entry_id: p.entry_id, entry_no: 0, amount: Number(p.amount) })} className="rounded-sm p-1 text-fg-3 hover:bg-raised hover:text-danger" aria-label={t('edit.cancel')} title={t('edit.cancel')} data-testid="payment-cancel">
                        <Undo2 className="size-3.5" aria-hidden />
                      </button>
                    </span>
                  )}
                </li>
              ))}
            </ul>
          )}
          <div className="flex flex-wrap gap-2">
            {customer && Number(data.due) > 0 && (
              <Button size="sm" variant="primary" icon={<HandCoins className="size-4" />} onClick={() => setPay(true)}>
                {t('money.recordPayment')}
              </Button>
            )}
            {customer && Number(data.due) === 0 && status !== 'delivered' && (
              <Button size="sm" icon={<HandCoins className="size-4" />} onClick={() => setPay(true)}>
                {t('money.deposit')}
              </Button>
            )}
            {owner && canDeliver && Number(data.due) > 0 && (
              <Button size="sm" variant="ghost" icon={<Truck className="size-4" />} onClick={() => void credit()}>
                {t('money.deliverCredit')}
              </Button>
            )}
          </div>
          {canDeliver && Number(data.due) > 0 && <p className="text-2xs text-fg-3">{t('money.mustPay', { v: `${f.money(Number(data.due))} ${cur}` })}</p>}
        </div>
      )}
      <EditEntryDialog entry={fix?.mode === 'edit' ? fix : null} onOpenChange={(v) => !v && setFix(null)} onDone={done} />
      <ReverseDialog move={fix?.mode === 'cancel' ? { ...fix, source_type: 'payment' } : null} onOpenChange={(v) => !v && setFix(null)} onDone={done} />
      {customer && <OpDialog op="payment" open={pay} onOpenChange={setPay} fixed={{ customer, device: { id: deviceId, label: orderNo }, amount: data && Number(data.due) > 0 ? Number(data.due) : undefined }} onDone={done} />}
    </Panel>
  );
}

/** حاسبة التسعير: القطع + المصنعية + نسبة ربح، وزرار يحط السعر كتكلفة نهائية */
async function applyFinal(deviceId: string, price: number, okTitle: string, toast: ReturnType<typeof useToast>, onApplied: () => void) {
  const { data: row } = await supabase.from('device_costs').select('id').eq('device_id', deviceId).maybeSingle();
  const r = row
    ? await supabase.from('device_costs').update({ final_cost: price }).eq('id', row.id)
    : await supabase.from('device_costs').insert({ id: crypto.randomUUID(), device_id: deviceId, final_cost: price });
  if (r.error) return toast({ tone: 'danger', title: errorMessage(r.error) });
  toast({ tone: 'ok', title: okTitle });
  onApplied();
}

function PricingCalculator({ deviceId, partsCost, labor: laborDefault, margin: marginDefault, locked, onApplied }: { deviceId: string; partsCost: number; labor: number; margin: number; locked: boolean; onApplied: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [parts, setParts] = useState(partsCost ? String(partsCost / 100) : '');
  const [labor, setLabor] = useState(laborDefault ? String(laborDefault / 100) : '');
  const [margin, setMargin] = useState(String(marginDefault));
  useEffect(() => {
    if (partsCost) setParts(String(partsCost / 100));
  }, [partsCost]);
  const res = useMemo(() => {
    const p = parts.trim() ? parsePounds(parts) : 0;
    const l = labor.trim() ? parsePounds(labor) : 0;
    const m = Number(toLatinDigits(margin.trim() || '0'));
    if (p == null || l == null || !Number.isInteger(m) || m < 0 || m > 1000) return null;
    return suggestPrice({ parts: p, labor: l, marginPct: m });
  }, [parts, labor, margin]);
  async function apply() {
    if (res) await applyFinal(deviceId, res.price, t('detail.costsSaved'), toast, onApplied);
  }
  return (
    <div className="rounded-md border border-glass-border bg-sunken/40 p-3" data-testid="calculator">
      <div className="grid grid-cols-3 gap-2">
        <Field label={t('money.calcParts')}>
          <Input dir="ltr" mono inputMode="decimal" value={parts} onChange={(e) => setParts(e.target.value)} className="text-start" />
        </Field>
        <Field label={t('money.calcLabor')}>
          <Input dir="ltr" mono inputMode="decimal" value={labor} onChange={(e) => setLabor(e.target.value)} className="text-start" />
        </Field>
        <Field label={t('money.calcMargin')}>
          <Input dir="ltr" mono inputMode="numeric" value={margin} onChange={(e) => setMargin(e.target.value)} suffix="%" className="text-start" />
        </Field>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-3 text-sm">
        {res ? (
          <>
            <span className="text-fg-2">
              {t('money.suggested')}: <span className="num font-semibold text-fg" data-testid="suggested-price">{f.money(res.price)}</span>
            </span>
            <span className="text-2xs text-fg-3">
              {t('money.deviceProfit')}: <span className="num">{f.money(res.profit)}</span>
            </span>
            <Button size="sm" className="ms-auto" onClick={() => void apply()} disabled={locked}>
              {t('money.useAsFinal')}
            </Button>
          </>
        ) : (
          <span className="text-xs text-danger">{t('fin.errAmount')}</span>
        )}
      </div>
    </div>
  );
}

/** القطع اللي اتركبت في الجهاز (صاحب المحل والفني). الفني بيسجل من غير ما يشوف السعر */
export function PartsPanel({ deviceId, status, onChanged }: { deviceId: string; status: DeviceStatus; onChanged: () => void }) {
  const { shop } = useMe();
  if (!readExtras(shop.extras).link_inventory) return <ManualPartPanel deviceId={deviceId} status={status} onChanged={onChanged} />;
  return <StockPartPanel deviceId={deviceId} status={status} onChanged={onChanged} />;
}

/**
 * "ربط المخزون بالصيانة" مقفول: القطعة بتتكتب على الجهاز يدوي (الاسم والتكلفة واتدفعت منين)، من غير ما المخزون يتأثر.
 * التكلفة بتدخل في تكلفة قطع الجهاز، فالربح بيطلع صح. الفني ما بيشوفش فلوس، فالاستقبال أو صاحب المحل بيسجلوها.
 */
function ManualPartPanel({ deviceId, status, onChanged }: { deviceId: string; status: DeviceStatus; onChanged: () => void }) {
  const { t } = useTranslation();
  const accName = useAccountName();
  const f = useFormat();
  const { profile } = useMe();
  const toast = useToast();
  const [name, setName] = useState('');
  const [cost, setCost] = useState('');
  const [cashbox, setCashbox] = useState('');
  const [busy, setBusy] = useState(false);
  const [id, setId] = useState(opId);
  const cbs = useLoad(async () => (profile.role === 'technician' ? [] : loadCashboxes()), [profile.role]);
  useEffect(() => {
    if (!cashbox && cbs.data?.length) setCashbox(cbs.data[0].id);
  }, [cbs.data, cashbox]);
  if (status === 'delivered') return null;
  if (profile.role === 'technician') {
    return (
      <Panel>
        <PanelHeader title={t('parts.title')} />
        <p className="p-4 text-sm text-fg-3">{t('parts.manualTech')}</p>
      </Panel>
    );
  }
  async function add() {
    const c = parsePounds(cost);
    if (!name.trim()) return toast({ tone: 'danger', title: t('common.required') });
    if (!c || c <= 0) return toast({ tone: 'danger', title: t('fin.errAmount') });
    setBusy(true);
    try {
      await rpc('device_manual_part', { p_id: id, p_device: deviceId, p_name: name.trim(), p_cost: c, p_cashbox: cashbox });
      toast({ tone: 'ok', title: t('parts.manualDone') });
      setName('');
      setCost('');
      setId(opId());
      onChanged();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel>
      <PanelHeader title={t('parts.title')} />
      <p className="px-4 pt-3 text-2xs text-fg-3">{t('parts.manualHint')}</p>
      <div className="grid grid-cols-2 items-end gap-2 p-4 sm:grid-cols-[minmax(0,1fr)_110px_minmax(0,1fr)_auto]">
        <Field label={t('parts.manualName')}>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} data-testid="manual-part-name" />
        </Field>
        <Field label={t('parts.manualCost')}>
          <Input mono inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} suffix={f.currency()} data-testid="manual-part-cost" />
        </Field>
        <Field label={t('parts.paidFrom')}>
          <Select value={cashbox} onChange={(e) => setCashbox(e.target.value)}>
            {(cbs.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {accName(c)}
              </option>
            ))}
          </Select>
        </Field>
        <Button loading={busy} icon={<PackageMinus className="size-4" />} onClick={() => void add()} data-testid="manual-part-add">
          {t('parts.manualAdd')}
        </Button>
      </div>
    </Panel>
  );
}

function StockPartPanel({ deviceId, status, onChanged }: { deviceId: string; status: DeviceStatus; onChanged: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [item, setItem] = useState('');
  const [qty, setQty] = useState('1');
  const [busy, setBusy] = useState(false);
  const { data, reload } = useLoad(async () => (await rpc<StockRow[]>('items_stock')).filter((i) => i.kind === 'part').map((i) => ({ ...i, qty: Number(i.qty) })), []);
  if (status === 'delivered') return null;
  async function use() {
    const n = Number(toLatinDigits(qty));
    if (!item || !Number.isInteger(n) || n <= 0) return toast({ tone: 'danger', title: t('inv.errLines') });
    setBusy(true);
    try {
      await rpc('use_part', { p_id: opId(), p_device: deviceId, p_item: item, p_qty: n });
      toast({ tone: 'ok', title: t('parts.used') });
      setItem('');
      setQty('1');
      reload();
      onChanged();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel>
      <PanelHeader title={t('parts.title')} />
      <div className="grid grid-cols-[minmax(0,1fr)_64px_auto] items-end gap-2 p-4">
        <Field label={t('parts.item')}>
          <Select value={item} onChange={(e) => setItem(e.target.value)}>
            <option value="">{t('fin.pick')}</option>
            {(data ?? []).map((i) => (
              <option key={i.id} value={i.id} disabled={i.qty <= 0}>
                {i.name} ({f.number(i.qty)})
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t('inv.cols.qty')}>
          <Input dir="ltr" mono inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} className="text-start" />
        </Field>
        <Button loading={busy} icon={<PackageMinus className="size-4" />} onClick={() => void use()}>
          {t('parts.use')}
        </Button>
      </div>
    </Panel>
  );
}

function Cell({ label, value, tone = 'text-fg', testid }: { label: string; value: string; tone?: string; testid?: string }) {
  return (
    <div className="rounded-md border border-glass-border bg-sunken/40 px-3 py-2">
      <div className="readout-label">{label}</div>
      <div className={`num mt-0.5 truncate text-md ${tone}`} data-testid={testid}>
        {value}
      </div>
    </div>
  );
}
