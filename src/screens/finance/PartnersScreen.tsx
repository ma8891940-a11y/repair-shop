import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowDownToLine, ArrowUpFromLine, FileText, Pencil, PieChart, Plus } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { loadCashboxes, opId, rpc, useAccountName, type Cashbox } from '../../app/ledgerApi';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { parsePounds } from '../../lib/money';
import { parsePercent, remainingBp } from '../../lib/partners';
import { toLatinDigits } from '../../lib/digits';
import { cairoDay, cairoDayEnd, cairoDayStart } from '../../lib/dates';
import { useFormat } from '../../i18n/format';
import { ExportMenu } from '../../app/exporting';
import { Panel } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { Checkbox } from '../../ui/Checkbox';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

export interface PartnerRow {
  id: string;
  name: string;
  phone: string | null;
  share_bp: number;
  joined_on: string;
  capital: number;
  current: number;
  total: number;
}

/**
 * الشركاء (صاحب المحل بس): نسبة كل شريك من صافي الربح، ورأس ماله، وحسابه الجاري.
 * السحب مش مصروف (ما بيقللش الربح). وتوزيع الأرباح لأي فترة بيتسجل قيد متوازن، ونفس الفترة ما تتوزعش مرتين.
 */
export function PartnersScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const [edit, setEdit] = useState<PartnerRow | 'new' | null>(null);
  const [money, setMoney] = useState<{ p: PartnerRow; kind: 'deposit' | 'withdraw' } | null>(null);
  const [dist, setDist] = useState(false);
  const { data, error, loading, reload } = useLoad(
    async () => (await rpc<PartnerRow[]>('partner_balances')).map((r) => ({ ...r, share_bp: Number(r.share_bp), capital: Number(r.capital), current: Number(r.current), total: Number(r.total) })),
    [],
  );
  useLiveRefresh(reload);
  const rest = remainingBp((data ?? []).map((p) => p.share_bp));
  const cur = f.currency(shop.currency);

  return (
    <div className="max-w-5xl">
      <PageHeader
        title={t('partners.title')}
        sub={t('partners.sub')}
        actions={
          <div className="flex flex-wrap gap-2">
            <ExportMenu
              testid="partners-export"
              disabled={!data}
              table={() =>
                data && {
                  title: t('partners.title'),
                  columns: [
                    { header: t('customers.cols.name') },
                    { header: t('customers.cols.phone') },
                    { header: t('export.cols.share') },
                    { header: t('partners.joined'), type: 'date' },
                    { header: t('export.cols.capital'), type: 'money', total: true },
                    { header: t('export.cols.current'), type: 'money', total: true },
                    { header: t('fin.total'), type: 'money', total: true },
                  ],
                  rows: data.map((x) => [x.name, x.phone, f.percentBp(x.share_bp), x.joined_on, x.capital, x.current, x.total]),
                }
              }
            />
            <Button size="sm" icon={<PieChart className="size-4" />} onClick={() => setDist(true)} disabled={!data?.length} data-testid="partners-distribute">
              {t('partners.distribute')}
            </Button>
            <Button size="sm" variant="primary" icon={<Plus className="size-4" />} onClick={() => setEdit('new')} data-testid="partners-add">
              {t('partners.add')}
            </Button>
          </div>
        }
      />
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading || !data ? (
        <Skeleton className="h-40 w-full" />
      ) : data.length === 0 ? (
        <Panel>
          <EmptyState line="shield" title={t('partners.empty')}>
            {t('partners.emptyText')}
          </EmptyState>
        </Panel>
      ) : (
        <>
          <p className="mb-2 text-sm text-fg-2" data-testid="partners-rest">
            {t('partners.rest', { total: f.percentBp(10000 - rest), rest: f.percentBp(rest) })}
          </p>
          <Panel className="overflow-x-auto">
            <table className="w-full min-w-[720px] text-sm">
              <thead className="text-2xs text-fg-3">
                <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                  <th>{t('partners.name')}</th>
                  <th className="!text-end">{t('partners.share')}</th>
                  <th className="!text-end">{t('partners.capital')}</th>
                  <th className="!text-end">{t('partners.current')}</th>
                  <th className="!text-end">{t('partners.total')}</th>
                  <th>
                    <span className="sr-only">{t('partners.actions')}</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-glass-border">
                {data.map((p) => (
                  <tr key={p.id} className="[&_td]:px-3 [&_td]:py-2" data-testid="partner-row">
                    <td>
                      <div className="text-fg">{p.name}</div>
                      <div className="text-2xs text-fg-3">{t('partners.since', { d: f.date(p.joined_on) })}</div>
                    </td>
                    <td className="num text-end text-fg" data-testid="partner-share">
                      {f.percentBp(p.share_bp)}
                    </td>
                    <td className="num text-end text-fg-2" dir="ltr" data-testid="partner-capital">
                      {f.money(p.capital)}
                    </td>
                    <td className={cn('num text-end', p.current < 0 ? 'text-danger' : 'text-fg-2')} dir="ltr" data-testid="partner-current">
                      {f.money(p.current)}
                    </td>
                    <td className="num text-end font-semibold text-fg" dir="ltr" data-testid="partner-total">
                      {f.money(p.total)} <span className="font-sans text-2xs font-normal text-fg-3">{cur}</span>
                    </td>
                    <td>
                      <div className="flex justify-end gap-0.5">
                        <IconBtn label={t('partners.deposit')} onClick={() => setMoney({ p, kind: 'deposit' })} testid="partner-deposit">
                          <ArrowDownToLine className="size-4" aria-hidden />
                        </IconBtn>
                        <IconBtn label={t('partners.withdraw')} onClick={() => setMoney({ p, kind: 'withdraw' })} testid="partner-withdraw">
                          <ArrowUpFromLine className="size-4" aria-hidden />
                        </IconBtn>
                        <Link to={`/finance/partner/${p.id}`} className="rounded-sm p-1.5 text-fg-3 hover:bg-raised hover:text-fg" aria-label={t('partners.statement')} title={t('partners.statement')} data-testid="partner-statement">
                          <FileText className="size-4" aria-hidden />
                        </Link>
                        <IconBtn label={t('partners.edit')} onClick={() => setEdit(p)} testid="partner-edit">
                          <Pencil className="size-4" aria-hidden />
                        </IconBtn>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
          <p className="mt-2 text-xs text-fg-3">{t('partners.note')}</p>
        </>
      )}
      <PartnerDialog partner={edit} others={(data ?? []).filter((p) => edit === 'new' || p.id !== (edit as PartnerRow | null)?.id)} onOpenChange={(v) => !v && setEdit(null)} onDone={reload} />
      <MoneyDialog target={money} onOpenChange={(v) => !v && setMoney(null)} onDone={reload} />
      <DistributeDialog open={dist} onOpenChange={setDist} onDone={reload} />
    </div>
  );
}

function IconBtn({ label, onClick, testid, children }: { label: string; onClick: () => void; testid: string; children: React.ReactNode }) {
  return (
    <button type="button" onClick={onClick} className="rounded-sm p-1.5 text-fg-3 hover:bg-raised hover:text-fg" aria-label={label} title={label} data-testid={testid}>
      {children}
    </button>
  );
}

function PartnerDialog({ partner, others, onOpenChange, onDone }: { partner: PartnerRow | 'new' | null; others: PartnerRow[]; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [share, setShare] = useState('');
  const [joined, setJoined] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const isNew = partner === 'new';
  // رأس مال الشريك وقت الإضافة (اختياري): النوع والمبلغ والتاريخ
  const [capKind, setCapKind] = useState<CapitalKind>('cash');
  const [capAmount, setCapAmount] = useState('');
  const [capDate, setCapDate] = useState(cairoDay(new Date()));
  const [cashbox, setCashbox] = useState('');
  const [lines, setLines] = useState<GoodsLine[]>([{ item: '', qty: '1', cost: '' }]);
  const ids = useMemo(() => (partner ? { partner: crypto.randomUUID(), cap: opId() } : null), [partner]);
  const lists = useLoad(async () => {
    if (partner !== 'new') return { cbs: [] as Cashbox[], items: [] as { id: string; name: string }[] };
    const [cbs, items] = await Promise.all([loadCashboxes(), rpc<{ id: string; name: string }[]>('items_stock')]);
    return { cbs, items };
  }, [partner === 'new']);
  useEffect(() => {
    if (!cashbox && lists.data?.cbs.length) setCashbox(lists.data.cbs[0].id);
  }, [lists.data, cashbox]);
  useEffect(() => {
    if (!partner) return;
    const p = partner === 'new' ? null : partner;
    setName(p?.name ?? '');
    setPhone(p?.phone ?? '');
    setShare(p ? String(p.share_bp / 100) : '');
    setJoined(p?.joined_on ?? cairoDay(new Date()));
    setCapKind('cash');
    setCapAmount('');
    setCapDate(cairoDay(new Date()));
    setLines([{ item: '', qty: '1', cost: '' }]);
    setErr(null);
  }, [partner]);
  const free = remainingBp(others.map((o) => o.share_bp));
  async function save() {
    setErr(null);
    const bp = parsePercent(share);
    if (!name.trim()) return setErr(t('common.required'));
    if (bp == null) return setErr(t('partners.errShare'));
    if (bp > free) return setErr(t('partners.errOver', { free: f.percentBp(free) }));
    // رأس المال اختياري: لو الخانة فاضية (أو مفيش سطور بضاعة) الشريك بيتضاف من غيره، ويتسجل بعدين من "زيادة رأس المال"
    const hasCap = isNew && (capKind === 'goods' ? lines.some((l) => l.item || l.cost.trim()) : capAmount.trim() !== '');
    const cap = hasCap ? capitalArgs(capKind, capAmount, lines) : null;
    if (typeof cap === 'string') return setErr(t(cap));
    setBusy(true);
    const row = { name: name.trim(), phone: phone.trim() || null, share_bp: bp, joined_on: joined };
    const pid = isNew ? ids!.partner : (partner as PartnerRow).id;
    const { error } = isNew
      ? await supabase.from('partners').upsert({ id: pid, shop_id: crypto.randomUUID(), ...row }, { onConflict: 'id', ignoreDuplicates: true })
      : await supabase.from('partners').update(row).eq('id', pid);
    if (error) {
      setBusy(false);
      return setErr(errorMessage(error));
    }
    if (cap) {
      try {
        await rpc('partner_capital_in', { p_id: ids!.cap, p_partner: pid, p_kind: capKind, p_amount: cap.amount, p_date: capDate, p_cashbox: capKind === 'cash' ? cashbox : null, p_lines: cap.lines, p_note: null });
      } catch (e) {
        setBusy(false);
        onDone();
        return setErr(errorMessage(e));
      }
    }
    setBusy(false);
    toast({ tone: 'ok', title: t('partners.saved') });
    onOpenChange(false);
    onDone();
  }
  return (
    <Dialog
      open={!!partner}
      onOpenChange={onOpenChange}
      title={isNew ? t('partners.add') : t('partners.edit')}
      className="w-[min(94vw,620px)]"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()} data-testid="partner-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t('partners.name')} required>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
        </Field>
        <Field label={t('partners.phone')}>
          <Input mono dir="ltr" inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className="text-start" />
        </Field>
        <Field label={t('partners.share')} required hint={t('partners.free', { free: f.percentBp(free) })}>
          <Input mono inputMode="decimal" value={share} onChange={(e) => setShare(e.target.value)} suffix="%" />
        </Field>
        <Field label={t('partners.joined')}>
          <Input type="date" dir="ltr" value={joined} onChange={(e) => setJoined(e.target.value)} />
        </Field>
      </div>
      {isNew && (
        <div className="mt-4 border-t border-glass-border pt-3" data-testid="new-partner-capital">
          <div className="mb-2 text-sm font-semibold text-fg">{t('partners.capTitle')}</div>
          <p className="mb-2 text-2xs text-fg-3">{t('partners.capHint')}</p>
          <CapitalFields kind={capKind} setKind={setCapKind} amount={capAmount} setAmount={setCapAmount} date={capDate} setDate={setCapDate} cashbox={cashbox} setCashbox={setCashbox} lines={lines} setLines={setLines}
            cashboxes={lists.data?.cbs ?? []} items={lists.data?.items ?? []} />
        </div>
      )}
      {err && (
        <Alert tone="danger" className="mt-3">
          {err}
        </Alert>
      )}
    </Dialog>
  );
}

export type CapitalKind = 'cash' | 'goods' | 'equipment' | 'old';
const KINDS: CapitalKind[] = ['cash', 'goods', 'equipment', 'old'];
type GoodsLine = { item: string; qty: string; cost: string };

/**
 * رأس مال الشريك (زيادة) أو سحب جزء منه، بتاريخ. أنواع رأس المال:
 * فلوس دخلت خزنة، أو بضاعة (المخزون بيزيد)، أو معدات (أصول ثابتة)، أو رأس مال قديم قبل البرنامج (من غير ما الخزن تتلمس).
 * ده حقوق ملكية: ما بيتحسبش إيراد ولا ربح، ولا دين على المحل.
 */
export function CapitalFields({ kind, setKind, amount, setAmount, date, setDate, cashbox, setCashbox, lines, setLines, cashboxes, items, withdraw }: {
  kind: CapitalKind; setKind: (k: CapitalKind) => void; amount: string; setAmount: (v: string) => void; date: string; setDate: (v: string) => void;
  cashbox: string; setCashbox: (v: string) => void; lines: GoodsLine[]; setLines: (f: (l: GoodsLine[]) => GoodsLine[]) => void;
  cashboxes: Cashbox[]; items: { id: string; name: string }[]; withdraw?: boolean;
}) {
  const { t } = useTranslation();
  const f = useFormat();
  const accName = useAccountName();
  return (
    <div className="flex flex-col gap-3">
      {!withdraw && (
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4" role="radiogroup" aria-label={t('partners.capKind')}>
          {KINDS.map((k) => (
            <button key={k} type="button" role="radio" aria-checked={kind === k} onClick={() => setKind(k)} data-testid={`cap-kind-${k}`}
              className={cn('rounded-md border px-2 py-2 text-start text-xs', kind === k ? 'border-accent bg-accent-soft text-fg' : 'border-glass-border text-fg-2 hover:text-fg')}>
              <div className="font-medium">{t(`partners.kinds.${k}.title`)}</div>
              <div className="mt-0.5 text-2xs text-fg-3">{t(`partners.kinds.${k}.hint`)}</div>
            </button>
          ))}
        </div>
      )}
      {kind === 'goods' && !withdraw ? (
        <div className="flex flex-col gap-2" data-testid="cap-goods">
          {lines.map((l, i) => (
            <div key={i} className="grid grid-cols-[minmax(0,1fr)_70px_100px] gap-2">
              <Select value={l.item} onChange={(e) => setLines((cur) => cur.map((x, k) => (k === i ? { ...x, item: e.target.value } : x)))} aria-label={`${t('inv.cols.name')} ${i + 1}`}>
                <option value="">{t('fin.pick')}</option>
                {items.map((it) => (
                  <option key={it.id} value={it.id}>
                    {it.name}
                  </option>
                ))}
              </Select>
              <Input mono inputMode="numeric" value={l.qty} onChange={(e) => setLines((cur) => cur.map((x, k) => (k === i ? { ...x, qty: e.target.value } : x)))} aria-label={`${t('inv.cols.qty')} ${i + 1}`} />
              <Input mono inputMode="decimal" value={l.cost} onChange={(e) => setLines((cur) => cur.map((x, k) => (k === i ? { ...x, cost: e.target.value } : x)))} aria-label={`${t('opening.unitCost')} ${i + 1}`} suffix={f.currency()} />
            </div>
          ))}
          <Button size="sm" variant="ghost" className="self-start" icon={<Plus className="size-4" />} onClick={() => setLines((cur) => [...cur, { item: '', qty: '1', cost: '' }])}>
            {t('opening.addRows')}
          </Button>
          {items.length === 0 && <p className="text-xs text-fg-3">{t('partners.noItems')}</p>}
        </div>
      ) : (
        <Field label={t('fin.amount')} required>
          <Input mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency()} data-testid="cap-amount" />
        </Field>
      )}
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t('partners.capDate')}>
          <Input type="date" dir="ltr" value={date} max={cairoDay(new Date())} onChange={(e) => setDate(e.target.value)} data-testid="cap-date" />
        </Field>
        {(kind === 'cash' || withdraw) && (
          <Field label={withdraw ? t('partners.fromCashbox') : t('partners.toCashbox')}>
            <Select value={cashbox} onChange={(e) => setCashbox(e.target.value)}>
              {cashboxes.map((c) => (
                <option key={c.id} value={c.id}>
                  {accName(c)}
                </option>
              ))}
            </Select>
          </Field>
        )}
      </div>
    </div>
  );
}

/** بيجهّز الطلب لقاعدة البيانات، أو بيرجّع مفتاح رسالة الخطأ */
export function capitalArgs(kind: CapitalKind, amount: string, lines: GoodsLine[]): { amount: number | null; lines: { item: string; qty: number; unit_cost: number }[] | null } | string {
  if (kind === 'goods') {
    const out = [];
    for (const l of lines) {
      if (!l.item && !l.cost.trim()) continue;
      const q = Number(toLatinDigits(l.qty.trim()));
      const c = parsePounds(l.cost);
      if (!l.item || !Number.isInteger(q) || q <= 0 || c == null) return 'inv.errLines';
      out.push({ item: l.item, qty: q, unit_cost: c });
    }
    if (!out.length) return 'inv.errLines';
    return { amount: null, lines: out };
  }
  const a = parsePounds(amount);
  if (!a || a <= 0) return 'fin.errAmount';
  return { amount: a, lines: null };
}

/** زيادة رأس المال (بأي نوع) أو سحب جزء منه، بتاريخ */
function MoneyDialog({ target, onOpenChange, onDone }: { target: { p: PartnerRow; kind: 'deposit' | 'withdraw' } | null; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [kind, setKind] = useState<CapitalKind>('cash');
  const [amount, setAmount] = useState('');
  const [date, setDate] = useState(cairoDay(new Date()));
  const [cashbox, setCashbox] = useState('');
  const [lines, setLines] = useState<GoodsLine[]>([{ item: '', qty: '1', cost: '' }]);
  const [note, setNote] = useState('');
  const [fromCapital, setFromCapital] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const id = useMemo(() => (target ? opId() : ''), [target]);
  const lists = useLoad(async () => {
    if (!target) return { cbs: [] as Cashbox[], items: [] as { id: string; name: string }[] };
    const [cbs, items] = await Promise.all([loadCashboxes(), rpc<{ id: string; name: string }[]>('items_stock')]);
    return { cbs, items };
  }, [!!target]);
  useEffect(() => {
    setKind('cash');
    setAmount('');
    setDate(cairoDay(new Date()));
    setLines([{ item: '', qty: '1', cost: '' }]);
    setNote('');
    setFromCapital(false);
    setErr(null);
  }, [target]);
  useEffect(() => {
    if (!cashbox && lists.data?.cbs.length) setCashbox(lists.data.cbs[0].id);
  }, [lists.data, cashbox]);
  async function save() {
    if (!target) return;
    setErr(null);
    const w = target.kind === 'withdraw';
    const args = capitalArgs(w ? 'cash' : kind, amount, lines);
    if (typeof args === 'string') return setErr(t(args));
    setBusy(true);
    try {
      if (!w) await rpc('partner_capital_in', { p_id: id, p_partner: target.p.id, p_kind: kind, p_amount: args.amount, p_date: date, p_cashbox: kind === 'cash' ? cashbox : null, p_lines: args.lines, p_note: note.trim() || null });
      else await rpc('partner_capital_out', { p_id: id, p_partner: target.p.id, p_cashbox: cashbox, p_amount: args.amount, p_date: date, p_from_capital: fromCapital, p_note: note.trim() || null });
      toast({ tone: 'ok', title: t(w ? 'partners.withdrawn' : 'partners.deposited', { name: target.p.name }) });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open={!!target}
      onOpenChange={onOpenChange}
      title={target ? `${t(target.kind === 'deposit' ? 'partners.deposit' : 'partners.withdraw')} · ${target.p.name}` : ''}
      description={target?.kind === 'withdraw' ? t('partners.withdrawHint') : t('partners.depositHint')}
      className="w-[min(94vw,620px)]"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()} data-testid="partner-money-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <CapitalFields kind={kind} setKind={setKind} amount={amount} setAmount={setAmount} date={date} setDate={setDate} cashbox={cashbox} setCashbox={setCashbox} lines={lines} setLines={setLines}
          cashboxes={lists.data?.cbs ?? []} items={lists.data?.items ?? []} withdraw={target?.kind === 'withdraw'} />
        {target?.kind === 'withdraw' && <Checkbox checked={fromCapital} onChange={setFromCapital} label={t('partners.fromCapital')} />}
        <Field label={t('edit.note')}>
          <Textarea rows={2} maxLength={300} value={note} onChange={(e) => setNote(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

interface Split {
  profit: number;
  overlap: boolean;
  shares: { partner: string; name: string; share_bp: number; amount: number }[];
}

/** توزيع الأرباح لفترة: معاينة (الربح ونصيب كل شريك) وبعدين تأكيد */
function DistributeDialog({ open, onOpenChange, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const today = cairoDay(new Date());
  const [from, setFrom] = useState(`${today.slice(0, 8)}01`);
  const [to, setTo] = useState(today);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const range = useMemo(() => (from && to && from <= to ? { from: cairoDayStart(from).toISOString(), to: cairoDayEnd(to).toISOString() } : null), [from, to]);
  // رقم جديد لكل فترة (ونفس الرقم لو اتبعت مرتين)
  const id = useMemo(() => (open && range ? opId() : ''), [open, range]);
  const split = useLoad(async () => {
    if (!open || !range) return null;
    const s = await rpc<Split>('profit_split', { p_from: range.from, p_to: range.to });
    return { ...s, profit: Number(s.profit), shares: s.shares.map((x) => ({ ...x, amount: Number(x.amount) })) };
  }, [open, range?.from, range?.to]);
  useEffect(() => setErr(null), [open, from, to]);
  const kept = split.data ? split.data.profit - split.data.shares.reduce((a, x) => a + x.amount, 0) : 0;
  async function go() {
    if (!range) return;
    setErr(null);
    setBusy(true);
    try {
      await rpc('distribute_profit', { p_id: id, p_from: range.from, p_to: range.to });
      toast({ tone: 'ok', title: t('partners.distributed') });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('partners.distribute')}
      description={t('partners.distributeHint')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} disabled={!split.data || split.data.overlap || split.data.shares.every((x) => x.amount === 0)} onClick={() => void go()} data-testid="distribute-confirm">
            {t('partners.distributeNow')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <div className="grid grid-cols-2 gap-3">
          <Field label={t('partners.from')}>
            <Input type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} data-testid="distribute-from" />
          </Field>
          <Field label={t('partners.to')}>
            <Input type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} data-testid="distribute-to" />
          </Field>
        </div>
        {split.error ? (
          <Alert tone="danger">{split.error}</Alert>
        ) : !split.data ? (
          <Skeleton className="h-24" />
        ) : (
          <div data-testid="distribute-preview">
            <div className="flex items-baseline justify-between border-b border-glass-border pb-2 text-sm">
              <span className="text-fg-2">{split.data.profit < 0 ? t('partners.loss') : t('partners.profit')}</span>
              <span className={cn('num font-semibold', split.data.profit < 0 ? 'text-danger' : 'text-fg')} dir="ltr" data-testid="distribute-profit">
                {f.money(split.data.profit)}
              </span>
            </div>
            <ul className="divide-y divide-glass-border text-sm">
              {split.data.shares.map((x) => (
                <li key={x.partner} className="flex justify-between py-1.5" data-testid="distribute-share">
                  <span className="text-fg">
                    {x.name} <span className="text-2xs text-fg-3">({f.percentBp(x.share_bp)})</span>
                  </span>
                  <span className="num text-fg" dir="ltr">
                    {f.money(x.amount)}
                  </span>
                </li>
              ))}
              <li className="flex justify-between py-1.5 text-fg-3">
                <span>{t('partners.keptByShop')}</span>
                <span className="num" dir="ltr">
                  {f.money(kept)}
                </span>
              </li>
            </ul>
            {split.data.overlap && (
              <Alert tone="warn" className="mt-2">
                {t('errors.db.E_PERIOD_DISTRIBUTED')}
              </Alert>
            )}
          </div>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
