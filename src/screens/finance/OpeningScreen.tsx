import { useEffect, useMemo, useRef, useState, type ClipboardEvent, type KeyboardEvent } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Check, Plus } from 'lucide-react';
import { PageHeader } from '../../app/AppShell';
import { useMe } from '../../app/auth';
import { useLoad, must } from '../../app/useLoad';
import { loadCashboxes, opId, rpc, useAccountName, type StockRow } from '../../app/ledgerApi';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { normalizeEgyptPhone } from '../../lib/phone';
import { checkStockRows, OPENING_STEPS, openingProgress, pasteIntoGrid, type OpeningStep, type StockRowIn } from '../../lib/opening';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Input } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

type Step = OpeningStep | 'summary';
const STEPS: Step[] = [...OPENING_STEPS, 'summary'];

interface Summary {
  stock: number;
  stock_items: number;
  cash: number;
  receivables: number;
  payables: number;
  capital: number;
  entries: number;
  balanced: boolean;
  done: boolean;
}

/**
 * جرد المحل أول مرة (صاحب المحل): المخزون في جدول زي Excel (ولصق من Excel)، ورصيد كل خزنة، وديون العملاء والموردين.
 * كل خطوة بتتحفظ لوحدها كقيد افتتاحي متوازن قصاد رأس المال، وبعدين ملخص وتأكيد. التقدم بيظهر في لوحة التحكم.
 */
export function OpeningScreen() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const prog = openingProgress(shop.extras);
  const [step, setStep] = useState<Step>(() => OPENING_STEPS.find((k) => !prog.steps[k]) ?? 'summary');

  async function mark(k: OpeningStep) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const steps = { ...((ex.opening_steps as Record<string, boolean>) ?? {}), [k]: true };
    await supabase.from('shops').update({ extras: { ...ex, opening_steps: steps } }).eq('id', shop.id);
    await refresh();
    setStep(STEPS[STEPS.indexOf(k) + 1]);
  }

  return (
    <div className="max-w-5xl">
      <PageHeader title={t('opening.title')} sub={t('opening.sub')} />
      <ol className="mb-4 flex flex-wrap gap-2" aria-label={t('opening.steps')}>
        {STEPS.map((k, i) => {
          const done = k !== 'summary' && prog.steps[k];
          return (
            <li key={k}>
              <button
                type="button"
                onClick={() => setStep(k)}
                aria-current={step === k ? 'step' : undefined}
                className={cn('inline-flex h-8 items-center gap-2 rounded-full border px-3 text-sm', step === k ? 'border-accent bg-accent-soft text-fg' : 'border-glass-border text-fg-2 hover:text-fg')}
                data-testid={`opening-step-${k}`}
              >
                <span className={cn('grid size-5 place-items-center rounded-full text-2xs', done ? 'bg-ok text-on-accent' : 'border border-line')}>{done ? <Check className="size-3" aria-hidden /> : i + 1}</span>
                {t(`opening.step.${k}`)}
              </button>
            </li>
          );
        })}
      </ol>
      {step === 'stock' && <StockStep onSaved={() => void mark('stock')} />}
      {step === 'cash' && <CashStep onSaved={() => void mark('cash')} />}
      {step === 'customers' && <PartyStep kind="customer" onSaved={() => void mark('customers')} />}
      {step === 'suppliers' && <PartyStep kind="supplier" onSaved={() => void mark('suppliers')} />}
      {step === 'summary' && <SummaryStep />}
    </div>
  );
}

const STOCK_COLS: (keyof StockRowIn)[] = ['name', 'kind', 'qty', 'cost', 'price'];
const blankStock = (): StockRowIn => ({ name: '', kind: 'part', qty: '', cost: '', price: '' });

/** تنقّل زي Excel: الأسهم فوق وتحت، وEnter للسطر اللي تحته */
function gridKeys(e: KeyboardEvent<HTMLElement>, row: number, col: number, focus: (r: number, c: number) => void) {
  if (e.key === 'ArrowDown' || (e.key === 'Enter' && !e.shiftKey)) {
    e.preventDefault();
    focus(row + 1, col);
  } else if (e.key === 'ArrowUp' || (e.key === 'Enter' && e.shiftKey)) {
    e.preventDefault();
    focus(row - 1, col);
  }
}

function StockStep({ onSaved }: { onSaved: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [rows, setRows] = useState<StockRowIn[]>(() => Array.from({ length: 8 }, blankStock));
  const [bad, setBad] = useState<Set<string>>(new Set());
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const entryId = useMemo(() => opId(), []);
  const itemIds = useRef(new Map() as Map<number, string>);
  const grid = useRef<HTMLTableElement | null>(null);
  const existing = useLoad(async () => (await rpc<StockRow[]>('items_stock')).map((i) => ({ ...i, qty: Number(i.qty) })), []);

  // الأصناف الموجودة (من غير رصيد) بتظهر في الجدول عشان تكتب كمياتها بس
  useEffect(() => {
    const ex = existing.data?.filter((i) => i.qty === 0) ?? [];
    if (!ex.length) return;
    setRows((cur) => (cur.some((r) => r.name.trim()) ? cur : [...ex.map((i) => ({ ...blankStock(), name: i.name, kind: i.kind })), ...Array.from({ length: 4 }, blankStock)]));
  }, [existing.data]);

  const focus = (r: number, c: number) => {
    if (r < 0) return;
    if (r >= rows.length) setRows((cur) => [...cur, blankStock()]);
    requestAnimationFrame(() => (grid.current?.querySelector(`[data-cell="${r}-${c}"]`) as HTMLElement | null)?.focus());
  };
  const set = (r: number, k: keyof StockRowIn, v: string) => setRows((cur) => cur.map((x, i) => (i === r ? { ...x, [k]: v } : x)));
  const onPaste = (e: ClipboardEvent<HTMLElement>, r: number, c: number) => {
    const text = e.clipboardData.getData('text/plain');
    if (!/[\t\n]/.test(text)) return;
    e.preventDefault();
    const acc = [t('inv.kinds.accessory'), 'accessory'].map((s) => s.toLowerCase());
    setRows((cur) => pasteIntoGrid(cur, r, c, text, STOCK_COLS, blankStock).map((x) => ({ ...x, kind: acc.includes(x.kind.trim().toLowerCase()) ? 'accessory' : 'part' })));
  };
  const check = useMemo(() => checkStockRows(rows), [rows]);
  const total = check.lines.reduce((a, l) => a + l.qty * l.unitCost, 0);

  async function save() {
    setErr(null);
    setBad(new Set(check.errors.map((x) => `${x.index}-${x.col}`)));
    if (check.errors.length) return setErr(t('opening.errRows', { n: check.errors.length }));
    if (!check.lines.length) return onSaved();
    setBusy(true);
    try {
      const byName = new Map((existing.data ?? []).map((i) => [i.name.trim(), i.id]));
      const fresh = check.lines.filter((l) => !byName.has(l.name));
      for (const l of fresh) if (!itemIds.current.has(l.index)) itemIds.current.set(l.index, crypto.randomUUID());
      if (fresh.length) {
        const { error } = await supabase
          .from('items')
          .upsert(fresh.map((l) => ({ id: itemIds.current.get(l.index), shop_id: crypto.randomUUID(), kind: l.kind, name: l.name, sale_price: l.salePrice })), { onConflict: 'id', ignoreDuplicates: true });
        if (error) throw error;
      }
      const lines = check.lines.map((l) => ({ item: byName.get(l.name) ?? itemIds.current.get(l.index), qty: l.qty, unit_cost: l.unitCost }));
      if (total > 0) await rpc('opening_balance', { p_id: entryId, p_kind: 'stock', p_ref: null, p_amount: null, p_lines: lines });
      toast({ tone: 'ok', title: t('opening.savedStock', { n: check.lines.length }) });
      onSaved();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Panel>
      <PanelHeader index="01" title={t('opening.step.stock')} />
      <p className="px-4 pt-3 text-sm text-fg-2">{t('opening.stockHint')}</p>
      {existing.loading ? (
        <Skeleton className="m-4 h-40" />
      ) : (
        <div className="overflow-x-auto p-4">
          <table ref={grid} className="w-full min-w-[640px] border-collapse text-sm" data-testid="opening-grid">
            <thead className="text-2xs text-fg-3">
              <tr className="[&_th]:border [&_th]:border-glass-border [&_th]:px-2 [&_th]:py-1.5 [&_th]:text-start [&_th]:font-medium">
                <th className="w-8">#</th>
                <th>{t('inv.cols.name')}</th>
                <th className="w-32">{t('inv.cols.kind')}</th>
                <th className="w-24">{t('inv.cols.qty')}</th>
                <th className="w-28">{t('opening.unitCost')}</th>
                <th className="w-28">{t('inv.cols.price')}</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r, i) => (
                <tr key={i} className="[&_td]:border [&_td]:border-glass-border [&_td]:p-0">
                  <td className="num px-2 text-center text-2xs text-fg-3">{i + 1}</td>
                  {STOCK_COLS.map((c, j) => (
                    <td key={c} className={cn(bad.has(`${i}-${c}`) && 'bg-danger-soft')}>
                      {c === 'kind' ? (
                        <select
                          data-cell={`${i}-${j}`}
                          value={r.kind}
                          onChange={(e) => set(i, 'kind', e.target.value)}
                          onKeyDown={(e) => gridKeys(e, i, j, focus)}
                          aria-label={`${t('inv.cols.kind')} ${i + 1}`}
                          className="h-8 w-full bg-transparent px-2 text-sm text-fg focus:outline focus:outline-2 focus:outline-accent"
                        >
                          <option value="part">{t('inv.kinds.part')}</option>
                          <option value="accessory">{t('inv.kinds.accessory')}</option>
                        </select>
                      ) : (
                        <input
                          data-cell={`${i}-${j}`}
                          value={r[c]}
                          onChange={(e) => set(i, c, e.target.value)}
                          onKeyDown={(e) => gridKeys(e, i, j, focus)}
                          onPaste={(e) => onPaste(e, i, j)}
                          inputMode={c === 'name' ? undefined : c === 'qty' ? 'numeric' : 'decimal'}
                          dir={c === 'name' ? undefined : 'ltr'}
                          aria-label={`${c === 'cost' ? t('opening.unitCost') : t(`inv.cols.${c === 'price' ? 'price' : c}`)} ${i + 1}`}
                          className={cn('h-8 w-full bg-transparent px-2 text-sm text-fg focus:outline focus:outline-2 focus:outline-accent', c !== 'name' && 'num text-start')}
                        />
                      )}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
          <div className="mt-2 flex flex-wrap items-center gap-3">
            <Button size="sm" variant="ghost" icon={<Plus className="size-4" />} onClick={() => setRows((cur) => [...cur, ...Array.from({ length: 5 }, blankStock)])}>
              {t('opening.addRows')}
            </Button>
            <span className="text-sm text-fg-2" data-testid="opening-stock-total">
              {t('opening.stockTotal', { n: check.lines.length, v: f.money(total) })}
            </span>
          </div>
        </div>
      )}
      <StepFooter err={err} busy={busy} onSave={() => void save()} onSkip={onSaved} />
    </Panel>
  );
}

function StepFooter({ err, busy, onSave, onSkip }: { err: string | null; busy: boolean; onSave: () => void; onSkip: () => void }) {
  const { t } = useTranslation();
  return (
    <div className="flex flex-wrap items-center gap-2 border-t border-glass-border p-4">
      {err && (
        <Alert tone="danger" className="w-full">
          {err}
        </Alert>
      )}
      <Button variant="primary" loading={busy} onClick={onSave} data-testid="opening-save">
        {t('opening.saveNext')}
      </Button>
      <Button variant="ghost" onClick={onSkip} data-testid="opening-skip">
        {t('opening.skip')}
      </Button>
    </div>
  );
}

function CashStep({ onSaved }: { onSaved: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const cbs = useLoad(loadCashboxes, []);
  const [vals, setVals] = useState<Record<string, string>>({});
  const ids = useRef(new Map() as Map<string, string>).current;
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  async function save() {
    setErr(null);
    const list: { cb: string; amount: number }[] = [];
    for (const [cb, v] of Object.entries(vals)) {
      if (!v.trim()) continue;
      const a = parsePounds(v);
      if (a == null) return setErr(t('fin.errAmount'));
      if (a > 0) list.push({ cb, amount: a });
    }
    setBusy(true);
    try {
      for (const x of list) {
        if (!ids.has(x.cb)) ids.set(x.cb, opId());
        await rpc('opening_balance', { p_id: ids.get(x.cb), p_kind: 'cash', p_ref: x.cb, p_amount: x.amount });
      }
      if (list.length) toast({ tone: 'ok', title: t('opening.savedCash') });
      onSaved();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel>
      <PanelHeader index="02" title={t('opening.step.cash')} />
      <p className="px-4 pt-3 text-sm text-fg-2">{t('opening.cashHint')}</p>
      <div className="grid gap-3 p-4 sm:grid-cols-2">
        {cbs.data
          ? cbs.data.map((c) => (
              <label key={c.id} className="flex items-center gap-3">
                <span className="w-36 shrink-0 text-sm text-fg">{accName(c)}</span>
                <Input mono inputMode="decimal" value={vals[c.id] ?? ''} onChange={(e) => setVals((v) => ({ ...v, [c.id]: e.target.value }))} suffix={f.currency()} aria-label={accName(c)} />
              </label>
            ))
          : [0, 1, 2].map((k) => <Skeleton key={k} className="h-9" />)}
      </div>
      <StepFooter err={err} busy={busy} onSave={() => void save()} onSkip={onSaved} />
    </Panel>
  );
}

type PartyRow = { name: string; phone: string; amount: string; dir: 'owes_us' | 'we_owe' };
/** الاتجاه الافتراضي هو الأشهر: العميل عليه للمحل، والمحل عليه للمورد */
const blankParty = (kind: 'customer' | 'supplier') => (): PartyRow => ({ name: '', phone: '', amount: '', dir: kind === 'customer' ? 'owes_us' : 'we_owe' });

/** ديون العملاء أو الموردين: الاسم والتليفون والمبلغ واتجاهه. اللي مش موجود بيتضاف */
function PartyStep({ kind, onSaved }: { kind: 'customer' | 'supplier'; onSaved: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [rows, setRows] = useState<PartyRow[]>(() => Array.from({ length: 4 }, blankParty(kind)));
  const ids = useRef(new Map() as Map<number, { party: string; entry: string }>);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const table = kind === 'customer' ? 'customers' : 'suppliers';
  const set = (i: number, k: keyof PartyRow, v: string) => setRows((cur) => cur.map((x, j) => (j === i ? { ...x, [k]: v } : x)));

  async function save() {
    setErr(null);
    const ready: { i: number; name: string; phone: string | null; amount: number }[] = [];
    for (const [i, r] of rows.entries()) {
      if (!r.name.trim() && !r.amount.trim()) continue;
      const a = parsePounds(r.amount);
      if (!r.name.trim() || a == null || a === 0) return setErr(t('opening.errParty', { n: i + 1 }));
      const phone = r.phone.trim() ? normalizeEgyptPhone(toLatinDigits(r.phone)) : null;
      if (kind === 'customer' && !phone) return setErr(t('opening.errPhone', { n: i + 1 }));
      // موجب = العميل عليه (أو المحل عليه للمورد)
      const sign = kind === 'customer' ? (r.dir === 'owes_us' ? 1 : -1) : r.dir === 'we_owe' ? 1 : -1;
      ready.push({ i, name: r.name.trim(), phone, amount: sign * a });
    }
    setBusy(true);
    try {
      for (const x of ready) {
        let got = ids.current.get(x.i);
        if (!got) {
          let party: string | null = null;
          if (x.phone) {
            const ex = await supabase.from(table).select('id').eq('phone', x.phone).is('deleted_at', null).maybeSingle();
            party = (ex.data as { id: string } | null)?.id ?? null;
          }
          if (!party) {
            party = crypto.randomUUID();
            must(await supabase.from(table).insert({ id: party, shop_id: crypto.randomUUID(), name: x.name, phone: x.phone }));
          }
          got = { party, entry: opId() };
          ids.current.set(x.i, got);
        }
        await rpc('opening_balance', { p_id: got.entry, p_kind: kind, p_ref: got.party, p_amount: x.amount });
      }
      if (ready.length) toast({ tone: 'ok', title: t('opening.savedParty', { n: ready.length }) });
      onSaved();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Panel>
      <PanelHeader index={kind === 'customer' ? '03' : '04'} title={t(`opening.step.${kind === 'customer' ? 'customers' : 'suppliers'}`)} />
      <p className="px-4 pt-3 text-sm text-fg-2">{t(`opening.${kind}Hint`)}</p>
      <div className="flex flex-col gap-2 p-4" data-testid={`opening-${kind}s`}>
        {rows.map((r, i) => (
          <div key={i} className="grid grid-cols-2 gap-2 sm:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)_120px_minmax(0,1fr)]">
            <Input value={r.name} onChange={(e) => set(i, 'name', e.target.value)} placeholder={t('opening.name')} aria-label={`${t('opening.name')} ${i + 1}`} />
            <Input mono dir="ltr" inputMode="tel" value={r.phone} onChange={(e) => set(i, 'phone', e.target.value)} placeholder={t('opening.phone')} aria-label={`${t('opening.phone')} ${i + 1}`} className="text-start" />
            <Input mono inputMode="decimal" value={r.amount} onChange={(e) => set(i, 'amount', e.target.value)} suffix={f.currency()} aria-label={`${t('fin.amount')} ${i + 1}`} />
            <select value={r.dir} onChange={(e) => set(i, 'dir', e.target.value)} aria-label={`${t('opening.dir')} ${i + 1}`} className="h-9 rounded-md border border-line bg-sunken/60 px-2 text-sm text-fg">
              <option value="owes_us">{t(`opening.dirs.${kind}.owes_us`)}</option>
              <option value="we_owe">{t(`opening.dirs.${kind}.we_owe`)}</option>
            </select>
          </div>
        ))}
        <Button size="sm" variant="ghost" className="self-start" icon={<Plus className="size-4" />} onClick={() => setRows((cur) => [...cur, ...Array.from({ length: 3 }, blankParty(kind))])}>
          {t('opening.addRows')}
        </Button>
      </div>
      <StepFooter err={err} busy={busy} onSave={() => void save()} onSkip={onSaved} />
    </Panel>
  );
}

function SummaryStep() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, refresh } = useMe();
  const navigate = useNavigate();
  const toast = useToast();
  const { data, error, reload } = useLoad(async () => {
    const s = await rpc<Summary>('opening_summary');
    return Object.fromEntries(Object.entries(s).map(([k, v]) => [k, typeof v === 'boolean' ? v : Number(v)])) as unknown as Summary;
  }, []);
  async function finish() {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const { error: e } = await supabase.from('shops').update({ extras: { ...ex, opening_done: true } }).eq('id', shop.id);
    if (e) return toast({ tone: 'danger', title: errorMessage(e) });
    await refresh();
    toast({ tone: 'ok', title: t('opening.finished') });
    navigate('/');
  }
  const rows: { k: keyof Summary; sign: '+' | '−' }[] = [
    { k: 'stock', sign: '+' },
    { k: 'cash', sign: '+' },
    { k: 'receivables', sign: '+' },
    { k: 'payables', sign: '−' },
  ];
  return (
    <Panel>
      <PanelHeader index="05" title={t('opening.step.summary')} />
      {error ? (
        <Alert tone="danger" className="m-4">
          {error}
        </Alert>
      ) : !data ? (
        <Skeleton className="m-4 h-40" />
      ) : (
        <div className="p-4">
          <table className="w-full max-w-md text-sm" data-testid="opening-summary">
            <tbody className="divide-y divide-glass-border">
              {rows.map(({ k, sign }) => (
                <tr key={k} className="[&_td]:py-2">
                  <td className="text-fg-2">{t(`opening.sum.${k}`)}</td>
                  <td className="num w-6 text-center text-fg-3">{sign}</td>
                  <td className="num text-end text-fg" dir="ltr" data-testid={`opening-sum-${k}`}>
                    {f.money(data[k] as number)}
                  </td>
                </tr>
              ))}
              <tr className="font-semibold [&_td]:py-2">
                <td className="text-fg">{t('opening.sum.capital')}</td>
                <td className="num text-center text-fg-3">=</td>
                <td className="num text-end text-accent" dir="ltr" data-testid="opening-sum-capital">
                  {f.money(data.capital)} {f.currency(shop.currency)}
                </td>
              </tr>
            </tbody>
          </table>
          <p className={cn('mt-3 text-sm', data.balanced ? 'text-ok' : 'text-danger')} data-testid="opening-balanced">
            {data.balanced ? t('opening.balanced', { n: data.entries }) : t('fin.unbalancedTitle')}
          </p>
          <p className="mt-1 text-xs text-fg-3">{t('opening.fixHint')}</p>
          <div className="mt-4 flex gap-2">
            <Button variant="primary" onClick={() => void finish()} disabled={!data.balanced} data-testid="opening-finish">
              {t('opening.finish')}
            </Button>
            <Button variant="ghost" onClick={reload}>
              {t('common.retry')}
            </Button>
          </div>
        </div>
      )}
    </Panel>
  );
}
