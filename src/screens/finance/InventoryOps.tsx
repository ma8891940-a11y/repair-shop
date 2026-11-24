import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ItemPicker } from '../../app/ItemPicker';
import { useMe } from '../../app/auth';
import { usePerms } from '../../app/perms';
import { NewItemInline } from '../../app/NewItemInline';
import { loadCashboxes, opId, rpc, useAccountName, type Cashbox, type StockRow } from '../../app/ledgerApi';
import { useLoad } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { errorMessage } from '../../lib/errors';
import { parseItemsCsv, type ImportResult } from '../../lib/csv';
import { useFormat } from '../../i18n/format';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert, EmptyState, Skeleton } from '../../ui/Feedback';
import { Checkbox, ChipToggle } from '../../ui/Checkbox';
import { useListLabel, useShopList } from '../../app/lists';
import { ListCombo } from '../../app/ListCombo';
import { ChipAdd, ChipRemove } from '../../app/ChipEdit';
import { useToast } from '../../ui/Toast';
import { SaleReturnDialog } from './SaleReturnDialog';
import { cn } from '../../ui/cn';

export type InvOp = 'write_off' | 'supplier_return' | 'sale_return';
interface Sup {
  id: string;
  name: string;
}

/** صنف + كمية: نفس الخانات في الهالك والمرتجعات */
function ItemQty({ items, item, setItem, qty, setQty, onlyInStock, canCreate }: { items: StockRow[]; item: string; setItem: (v: string) => void; qty: string; setQty: (v: string) => void; onlyInStock: boolean; canCreate?: boolean }) {
  const { t } = useTranslation();
  // S6: الصنف بحث وكتابة، والمرتجع من عميل ممكن يكون لصنف لسه مش متسجل
  const [extra, setExtra] = useState<StockRow[]>([]);
  const [creating, setCreating] = useState<string | null>(null);
  const mayCreate = usePerms().grant('item_create', 'add');
  const all = useMemo(() => [...extra.filter((x) => !items.some((y) => y.id === x.id)), ...items], [extra, items]);
  return (
    <div className="flex flex-col gap-2">
      <div className="grid grid-cols-[minmax(0,1fr)_80px] gap-2">
        <Field label={t('inv.cols.name')} required>
          <ItemPicker items={all} value={item} onPick={(x) => setItem(x.id)} onlyInStock={onlyInStock} onCreate={canCreate && mayCreate ? setCreating : undefined} createDenied={canCreate && !mayCreate} testid="op-item" />
        </Field>
        <Field label={t('inv.cols.qty')} required>
          <Input mono inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} />
        </Field>
      </div>
      {creating != null && (
        <NewItemInline
          key={creating}
          typed={creating}
          withStock={false}
          onCancel={() => setCreating(null)}
          onCreated={(row) => {
            setExtra((xs) => [...xs, row]);
            setCreating(null);
            setItem(row.id);
          }}
        />
      )}
    </div>
  );
}

/**
 * عمليات المخزون: هالك، ومرتجع للمورد، ومرتجع من عميل. كل واحدة قيد متوازن واحد في قاعدة البيانات،
 * والسبب إجباري، ورقم العملية ثابت (لو اتبعتت مرتين ما تتسجلش مرتين).
 */
export function InvOpDialog({ op, items, suppliers, presetItem, onOpenChange, onDone }: { op: InvOp | null; items: StockRow[]; suppliers: Sup[]; presetItem?: string; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const [item, setItem] = useState('');
  const [qty, setQty] = useState('1');
  const [money, setMoney] = useState('');
  const [supplier, setSupplier] = useState('');
  const [way, setWay] = useState<'account' | 'cash'>('account');
  const [cashbox, setCashbox] = useState('');
  const [phone, setPhone] = useState('');
  const [restock, setRestock] = useState(true);
  const [reason, setReason] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  // (3) مرتجع العميل: بفاتورة (الأساس)، أو من غير فاتورة (صاحب المحل بس)
  const owner = useMe().profile.role === 'owner';
  const [mode, setMode] = useState<'byInvoice' | 'noInvoice'>('byInvoice');
  const id = useMemo(() => (op ? opId() : ''), [op]);
  const cbs = useLoad(async () => (op && op !== 'write_off' ? loadCashboxes() : ([] as Cashbox[])), [op]);
  // قبل ما النافذة تترسم: اللي بيتكتب بسرعة ما يتمسحش (المبلغ الفاضي كان بيتحسب صفر)
  useLayoutEffect(() => {
    setItem(presetItem ?? '');
    setQty('1');
    setMoney('');
    setSupplier('');
    setWay(op === 'sale_return' ? 'cash' : 'account');
    setPhone('');
    setRestock(true);
    setReason('');
    setErr(null);
    setMode(presetItem && owner ? 'noInvoice' : 'byInvoice');
  }, [op, presetItem, owner]);
  useEffect(() => {
    if (!cashbox && cbs.data?.length) setCashbox(cbs.data[0].id);
  }, [cbs.data, cashbox]);
  const it = items.find((i) => i.id === item);

  async function submit() {
    setErr(null);
    const n = Number(toLatinDigits(qty.trim()));
    if (!item || !Number.isInteger(n) || n <= 0) return setErr(t('inv.errLines'));
    if (!reason.trim()) return setErr(t('fin.errReason'));
    const m = op === 'write_off' ? 0 : money.trim() ? parsePounds(money) : 0;
    if (m == null) return setErr(t('fin.errAmount'));
    setBusy(true);
    try {
      if (op === 'write_off') {
        await rpc('write_off', { p_id: id, p_item: item, p_qty: n, p_reason: reason.trim() });
      } else if (op === 'supplier_return') {
        if (!supplier) throw new Error(t('fin.errParty'));
        await rpc('supplier_return', { p_id: id, p_supplier: supplier, p_item: item, p_qty: n, p_refund: m, p_cashbox: way === 'cash' ? cashbox : null, p_reason: reason.trim() });
      } else if (op === 'sale_return') {
        let customer: string | null = null;
        if (way === 'account') {
          const p = toLatinDigits(phone.trim());
          const r = await supabase.from('customers').select('id').eq('phone', p).is('deleted_at', null).maybeSingle();
          customer = (r.data as { id: string } | null)?.id ?? null;
          if (!customer) throw new Error(t('inv.errCustomer'));
        }
        await rpc('sale_return', { p_id: id, p_item: item, p_qty: n, p_refund: m, p_cashbox: way === 'cash' ? cashbox : null, p_customer: customer, p_restock: restock, p_reason: reason.trim() });
      }
      toast({ tone: 'ok', title: t(`invop.done.${op}`) });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  const modes = owner && (
    <div className="inline-flex self-start rounded-md border border-glass-border p-0.5" role="radiogroup" aria-label={t('invop.title.sale_return')}>
      {(['byInvoice', 'noInvoice'] as const).map((m) => (
        <button key={m} type="button" role="radio" aria-checked={mode === m} onClick={() => setMode(m)} data-testid={`ret-${m}`} className={cn('h-7 rounded-sm px-2.5 text-xs', mode === m ? 'bg-raised text-fg' : 'text-fg-3')}>
          {t(`invop.ret.${m}`)}
        </button>
      ))}
    </div>
  );
  if (op === 'sale_return' && mode === 'byInvoice') return <SaleReturnDialog modes={modes} onOpenChange={onOpenChange} onDone={onDone} />;

  return (
    <Dialog
      open={!!op}
      onOpenChange={onOpenChange}
      title={op ? t(`invop.title.${op}`) : ''}
      description={op ? t(`invop.hint.${op}`) : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void submit()} data-testid="invop-submit">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {op === 'sale_return' && modes}
        <ItemQty items={items} item={item} setItem={setItem} qty={qty} setQty={setQty} onlyInStock={op !== 'sale_return'} canCreate={op === 'sale_return'} />
        {op === 'supplier_return' && (
          <Field label={t('fin.supplier')} required>
            <Select value={supplier} onChange={(e) => setSupplier(e.target.value)}>
              <option value="">{t('fin.pick')}</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </Select>
          </Field>
        )}
        {op !== 'write_off' && (
          <>
            <Field label={op === 'supplier_return' ? t('invop.refundSupplier') : t('invop.refundCustomer')} hint={it?.avg_cost != null && op === 'supplier_return' ? t('invop.costHint', { c: f.money(it.avg_cost) }) : undefined}>
              <Input mono inputMode="decimal" value={money} onChange={(e) => setMoney(e.target.value)} suffix={f.currency()} />
            </Field>
            <div className="inline-flex self-start rounded-md border border-glass-border p-0.5" role="radiogroup" aria-label={t('invop.how')}>
              {(['account', 'cash'] as const).map((w) => (
                <button key={w} type="button" role="radio" aria-checked={way === w} onClick={() => setWay(w)} className={cn('h-7 rounded-sm px-2.5 text-xs', way === w ? 'bg-raised text-fg' : 'text-fg-3')}>
                  {t(`invop.way.${op}.${w}`)}
                </button>
              ))}
            </div>
            {way === 'cash' ? (
              <Field label={t('fin.cashbox')}>
                <Select value={cashbox} onChange={(e) => setCashbox(e.target.value)}>
                  {(cbs.data ?? []).map((c) => (
                    <option key={c.id} value={c.id}>
                      {accName(c)}
                    </option>
                  ))}
                </Select>
              </Field>
            ) : (
              op === 'sale_return' && (
                <Field label={t('intake.phone')}>
                  <Input mono dir="ltr" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className="text-start" />
                </Field>
              )
            )}
          </>
        )}
        {op === 'sale_return' && <Checkbox checked={restock} onChange={setRestock} label={t('invop.restock')} />}
        <ReasonChips list={op === 'write_off' ? 'write_off_reasons' : 'return_reasons'} value={reason} onPick={setReason} />
        <Field label={t('fin.reason')} required>
          <Textarea rows={2} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** أسباب الهالك أو المرتجع الجاهزة (من القوايم): دوسة بتكتب السبب، والإضافة والحذف من نفس المكان */
export function ReasonChips({ list, value, onPick }: { list: 'write_off_reasons' | 'return_reasons'; value: string; onPick: (v: string) => void }) {
  const { t } = useTranslation();
  const label = useListLabel();
  const { items } = useShopList(list);
  return (
    <div className="flex flex-wrap items-center gap-1.5" role="group" aria-label={t(`lists.names.${list}`)} data-testid="reason-chips">
      {items.map((i) => {
        const l = label(list, i.value);
        return (
          <span key={i.value} className="inline-flex items-center gap-0.5">
            <ChipToggle pressed={value === l} onChange={(v) => onPick(v ? l : '')}>
              {l}
            </ChipToggle>
            <ChipRemove list={list} item={i} />
          </span>
        );
      })}
      <ChipAdd list={list} />
    </div>
  );
}

/** تعديل جماعي للأصناف المختارة: التصنيف، والحد الأدنى، وسعر البيع (الخانة الفاضية ما بتتغيرش) */
export function BulkEditDialog({ ids, onOpenChange, onDone }: { ids: string[] | null; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [category, setCategory] = useState('');
  const [min, setMin] = useState('');
  const [price, setPrice] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    setCategory('');
    setMin('');
    setPrice('');
    setErr(null);
  }, [ids]);
  async function save() {
    if (!ids?.length) return;
    const patch: Record<string, unknown> = {};
    if (category.trim()) patch.category = category.trim();
    if (min.trim()) {
      const m = Number(toLatinDigits(min.trim()));
      if (!Number.isInteger(m) || m < 0) return setErr(t('inv.errMin'));
      patch.min_qty = m;
    }
    if (price.trim()) {
      const p = parsePounds(price);
      if (p == null) return setErr(t('fin.errAmount'));
      patch.sale_price = p;
    }
    if (!Object.keys(patch).length) return setErr(t('bulk.nothing'));
    setBusy(true);
    const { error } = await supabase.from('items').update(patch).in('id', ids);
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('bulk.done', { n: ids.length }) });
    onOpenChange(false);
    onDone();
  }
  return (
    <Dialog
      open={!!ids}
      onOpenChange={onOpenChange}
      title={t('bulk.title', { n: ids?.length ?? 0 })}
      description={t('bulk.hint')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="grid gap-3 sm:grid-cols-3">
        <div>
          <Field label={t('inv.category')}>
            <ListCombo list="item_categories" value={category} onChange={setCategory} maxLength={60} testid="bulk-category" />
          </Field>
        </div>
        <Field label={t('inv.minQty')}>
          <Input mono inputMode="numeric" value={min} onChange={(e) => setMin(e.target.value)} />
        </Field>
        <Field label={t('inv.cols.price')}>
          <Input mono inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} suffix={f.currency()} />
        </Field>
      </div>
      {err && (
        <Alert tone="danger" className="mt-3">
          {err}
        </Alert>
      )}
    </Dialog>
  );
}

/** استيراد أصناف من Excel (CSV): معاينة الأول، والسطور الغلط بتظهر بسببها، وبعدين تأكيد */
export function ImportDialog({ open, onOpenChange, existing, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; existing: StockRow[]; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [res, setRes] = useState<ImportResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setRes(null);
    setErr(null);
  }, [open]);
  async function read(file: File) {
    setErr(null);
    try {
      const text = await file.text();
      const codes = new Set(existing.map((i) => i.barcode).filter((b): b is string => !!b));
      setRes(parseItemsCsv(text, codes));
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  async function save() {
    if (!res?.rows.length) return;
    setBusy(true);
    const rows = res.rows.map((r) => ({ id: crypto.randomUUID(), shop_id: crypto.randomUUID(), ...r }));
    const { error } = await supabase.from('items').insert(rows);
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('import.done', { n: rows.length }) });
    onOpenChange(false);
    onDone();
  }
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('import.title')}
      description={t('import.hint')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} disabled={!res?.rows.length} onClick={() => void save()} data-testid="import-save">
            {t('import.save', { n: res?.rows.length ?? 0 })}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <input type="file" accept=".csv,text/csv" aria-label={t('import.file')} onChange={(e) => e.target.files?.[0] && void read(e.target.files[0])} className="text-sm text-fg-2 file:me-3 file:rounded-md file:border file:border-line file:bg-raised file:px-3 file:py-1.5 file:text-fg" data-testid="import-file" />
        {res && (
          <div className="text-sm" data-testid="import-preview">
            <p className="text-fg">{t('import.ok', { n: res.rows.length })}</p>
            {res.errors.length > 0 && (
              <ul className="mt-1 list-disc ps-5 text-xs text-danger">
                {res.errors.slice(0, 20).map((x) => (
                  <li key={x.line}>{t('import.err', { line: x.line, why: t(`import.why.${x.reason}`) })}</li>
                ))}
              </ul>
            )}
          </div>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/**
 * مسح باركود بالكاميرا (لو الجهاز بيدعمه: BarcodeDetector في Chrome/Android). على أي جهاز تاني قارئ الباركود
 * بيكتب الرقم في خانة البحث ويدوس Enter، وده شغال في كل مكان.
 */
export function ScanDialog({ open, onOpenChange, onCode }: { open: boolean; onOpenChange: (v: boolean) => void; onCode: (code: string) => void }) {
  const { t } = useTranslation();
  const video = useRef<HTMLVideoElement | null>(null);
  const [state, setState] = useState<'starting' | 'on' | 'unsupported' | 'denied'>('starting');
  useEffect(() => {
    if (!open) return;
    const W = window as unknown as { BarcodeDetector?: new (o: { formats: string[] }) => { detect: (v: HTMLVideoElement) => Promise<{ rawValue: string }[]> } };
    if (!W.BarcodeDetector || !navigator.mediaDevices?.getUserMedia) {
      setState('unsupported');
      return;
    }
    let stream: MediaStream | null = null;
    let stop = false;
    const det = new W.BarcodeDetector({ formats: ['ean_13', 'ean_8', 'code_128', 'upc_a'] });
    void navigator.mediaDevices
      .getUserMedia({ video: { facingMode: 'environment' } })
      .then(async (s) => {
        stream = s;
        if (!video.current) return;
        video.current.srcObject = s;
        await video.current.play();
        setState('on');
        while (!stop) {
          const found = await det.detect(video.current).catch(() => []);
          if (found[0]?.rawValue) {
            onCode(found[0].rawValue);
            onOpenChange(false);
            return;
          }
          await new Promise((r) => setTimeout(r, 200));
        }
      })
      .catch(() => setState('denied'));
    return () => {
      stop = true;
      stream?.getTracks().forEach((x) => x.stop());
    };
  }, [open, onCode, onOpenChange]);
  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={t('scan.title')} description={t('scan.hint')}>
      {state === 'unsupported' || state === 'denied' ? (
        <Alert tone="info">{t(`scan.${state}`)}</Alert>
      ) : (
        <video ref={video} className="aspect-video w-full rounded-md bg-sunken object-cover" muted playsInline />
      )}
    </Dialog>
  );
}

interface MoveRow {
  entry_id: string;
  entry_no: number;
  at: string;
  source_type: string;
  memo: string | null;
  qty: number;
  value: number;
  balance_qty: number;
  balance_value: number;
  device_id: string | null;
  order_no: string | null;
  by: string | null;
  reversed: boolean;
}

/** حركة الصنف (صاحب المحل): كل دخول وخروج، والرصيد بعد كل حركة، وكل سطر بيفتح القيد */
export function ItemMoves({ itemId }: { itemId: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { data, error } = useLoad(async () => (await rpc<MoveRow[]>('item_moves', { p_item: itemId })).map((r) => ({ ...r, qty: Number(r.qty), value: Number(r.value), balance_qty: Number(r.balance_qty), balance_value: Number(r.balance_value) })), [itemId]);
  if (error) return <Alert tone="danger">{error}</Alert>;
  if (!data) return <Skeleton className="h-20 w-full" />;
  if (!data.length) return <EmptyState line="chip" title={t('moves.empty')} />;
  return (
    <div className="max-h-64 overflow-auto rounded-md border border-glass-border">
      <table className="w-full text-xs" data-testid="item-moves">
        <thead className="sticky top-0 bg-raised text-2xs text-fg-3">
          <tr className="[&_th]:px-2 [&_th]:py-1.5 [&_th]:text-start [&_th]:font-medium">
            <th>{t('fin.cols.time')}</th>
            <th>{t('fin.cols.desc')}</th>
            <th className="!text-end">{t('inv.cols.qty')}</th>
            <th className="!text-end">{t('moves.after')}</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-glass-border">
          {[...data].reverse().map((m, k) => (
            <tr key={`${m.entry_id}-${k}`} className={cn('[&_td]:px-2 [&_td]:py-1.5', m.reversed && 'text-fg-3 line-through')} data-testid="item-move">
              <td className="num whitespace-nowrap text-fg-3">{f.date(m.at)}</td>
              <td>
                <Link to={`/finance/entry/${m.entry_id}`} className="text-fg hover:text-accent">
                  {t(`fin.src.${m.source_type}`, { defaultValue: m.source_type })}
                </Link>
                {m.order_no && (
                  <span className="num ms-1 text-fg-3" dir="ltr">
                    {m.order_no}
                  </span>
                )}
                {m.memo && <span className="ms-1 text-fg-3">· {m.memo}</span>}
              </td>
              <td className={cn('num text-end', m.qty > 0 ? 'text-ok' : 'text-danger')} dir="ltr">
                {m.qty > 0 ? '+' : ''}
                {f.number(m.qty)}
              </td>
              <td className="num text-end text-fg" dir="ltr">
                {f.number(m.balance_qty)} · {f.money(m.balance_value)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** حسابات المخزون لوحده للفترة: المبيعات، والتكلفة، والهالك، وفرق المرتجعات، والربح، وأكتر الأصناف بيعًا */
export interface InvSummary {
  sales: number;
  sales_cost: number;
  wastage: number;
  return_diff: number;
  cost_adjust: number;
  parts_used: number;
  purchases: number;
  stock_value: number;
  stock_qty: number;
  profit: number;
  top: { id: string; name: string; qty: number; cost: number }[];
  /** S6: لما فيه فلتر بالنوع أو الماركة أو الموديل أو الجودة */
  filtered?: { items: number; stock_qty: number; stock_value: number } | null;
}
