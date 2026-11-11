import { useLayoutEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { CalendarClock, Plus, X } from 'lucide-react';
import { opId, rpc } from '../ledgerApi';
import { useLoad } from '../useLoad';
import { usePerms } from '../perms';
import { buildSchedule, type Every } from '../../lib/plans';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

export interface PlanInstallment {
  seq: number;
  due: string;
  amount: number;
  covered: number;
  status: 'paid' | 'overdue' | 'due_soon' | 'upcoming';
}
export interface PlanRow {
  plan_id: string;
  party_type: 'customer' | 'supplier';
  party_id: string;
  party_name: string | null;
  title: string | null;
  total: number;
  paid: number;
  remaining: number;
  next_due: string | null;
  next_amount: number | null;
  overdue: number;
  status: 'done' | 'overdue' | 'due_soon' | 'open';
  installments: PlanInstallment[];
}

export const toPlan = (r: PlanRow): PlanRow => ({
  ...r,
  total: Number(r.total),
  paid: Number(r.paid),
  remaining: Number(r.remaining),
  overdue: Number(r.overdue),
  next_amount: r.next_amount == null ? null : Number(r.next_amount),
  installments: (r.installments ?? []).map((i) => ({ ...i, amount: Number(i.amount), covered: Number(i.covered) })),
});

const tone: Record<string, string> = { paid: 'text-ok', overdue: 'text-danger', due_soon: 'text-warn', upcoming: 'text-fg-3', done: 'text-ok', open: 'text-fg-2' };

/**
 * N: مواعيد التحصيل وخطط التقسيط في كشف حساب العميل أو المورد.
 * المدفوع بيتحسب من القيود: أي دفعة للطرف بتغطي الأقساط بالترتيب، والخطة بتتقفل لوحدها.
 */
export function PlansPanel({ partyType, partyId, balance }: { partyType: 'customer' | 'supplier'; partyId: string; balance: number | undefined }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const { grant } = usePerms();
  const [open, setOpen] = useState(false);
  const { data, loading, reload } = useLoad(async () => (await rpc<PlanRow[]>('plans_overview', { p_party_type: partyType, p_party: partyId })).map(toPlan), [partyType, partyId]);
  async function cancel(p: PlanRow) {
    try {
      await rpc('cancel_plan', { p_id: p.plan_id });
      toast({ tone: 'ok', title: t('inst.cancelled') });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  return (
    <Panel className="mb-3" data-testid="plans-panel">
      <PanelHeader
        title={t(`inst.title.${partyType}`)}
        actions={
          grant('finance', 'add') && (
            <Button size="sm" icon={<Plus className="size-4" />} needsNet onClick={() => setOpen(true)} data-testid="plan-new">
              {t('inst.new')}
            </Button>
          )
        }
      />
      <div className="flex flex-col gap-3 p-3">
        {loading && !data ? (
          <Skeleton className="h-12" />
        ) : !data?.length ? (
          <p className="text-xs text-fg-3">{t('inst.none')}</p>
        ) : (
          data.map((p) => {
            const pct = p.total > 0 ? Math.round((p.paid * 100) / p.total) : 0;
            return (
              <section key={p.plan_id} className="rounded-md border border-glass-border p-3" data-testid="plan-row" data-status={p.status}>
                <div className="flex flex-wrap items-center gap-2 text-sm">
                  <CalendarClock className="size-4 text-fg-3" aria-hidden />
                  <span className="font-medium text-fg">{p.title || t(p.installments.length > 1 ? 'plan.installments' : 'plan.dueDate')}</span>
                  <span className={cn('text-2xs', tone[p.status])} data-testid="plan-status">
                    {t(`inst.status.${p.status}`)}
                  </span>
                  <span className="ms-auto text-2xs text-fg-3">
                    {t('inst.paidOf', { paid: f.money(p.paid), total: f.money(p.total) })}
                  </span>
                  {grant('finance', 'delete') && p.status !== 'done' && (
                    <button type="button" onClick={() => void cancel(p)} className="rounded-sm p-1 text-fg-3 hover:text-danger" aria-label={t('inst.cancel')} title={t('inst.cancel')} data-testid="plan-cancel">
                      <X className="size-4" aria-hidden />
                    </button>
                  )}
                </div>
                {/* شريط التقدم */}
                <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-sunken" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={pct} aria-label={t('inst.progress')}>
                  <div className={cn('h-full rounded-full', p.status === 'overdue' ? 'bg-danger' : 'bg-accent')} style={{ width: `${pct}%` }} />
                </div>
                {p.overdue > 0 && (
                  <p className="mt-1 text-2xs text-danger" data-testid="plan-overdue">
                    {t('inst.overdueAmount', { v: f.money(p.overdue) })}
                  </p>
                )}
                <table className="mt-2 w-full text-xs">
                  <tbody className="divide-y divide-glass-border">
                    {p.installments.map((i) => (
                      <tr key={i.seq} className="[&_td]:py-1" data-testid="plan-inst" data-status={i.status}>
                        <td className="num w-8 text-fg-3">{f.number(i.seq)}</td>
                        <td className="num text-fg-2">{f.dateNum(i.due)}</td>
                        <td className="num text-end text-fg">{f.money(i.amount)}</td>
                        <td className="num text-end text-fg-3">{i.covered > 0 && i.covered < i.amount ? t('inst.partly', { v: f.money(i.covered) }) : ''}</td>
                        <td className={cn('w-24 text-end', tone[i.status])}>{t(`inst.inst.${i.status}`)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </section>
            );
          })
        )}
      </div>
      <PlanDialog
        open={open}
        onOpenChange={setOpen}
        partyType={partyType}
        partyId={partyId}
        suggested={balance && balance > 0 ? balance : 0}
        onDone={() => {
          reload();
          toast({ tone: 'ok', title: t('inst.saved') });
        }}
      />
    </Panel>
  );
}

function PlanDialog({ open, onOpenChange, partyType, partyId, suggested, onDone }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  partyType: 'customer' | 'supplier';
  partyId: string;
  suggested: number;
  onDone: () => void;
}) {
  const { t } = useTranslation();
  const f = useFormat();
  const [title, setTitle] = useState('');
  const [total, setTotal] = useState('');
  const [count, setCount] = useState('1');
  const [first, setFirst] = useState('');
  const [every, setEvery] = useState<Every>('month');
  const [rows, setRows] = useState<{ due: string; amount: string }[]>([]);
  const [edited, setEdited] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [id, setId] = useState(opId);
  useLayoutEffect(() => {
    if (!open) return;
    const d = new Date(Date.now() + 30 * 86400_000);
    setTitle('');
    setTotal(suggested > 0 ? String(suggested / 100) : '');
    setCount('1');
    setFirst(d.toISOString().slice(0, 10));
    setEvery('month');
    setEdited(false);
    setErr(null);
    setId(opId());
  }, [open, suggested]);
  const n = Number(toLatinDigits(count.trim() || '0'));
  const tot = parsePounds(total);
  const auto = useMemo(() => (tot && Number.isInteger(n) && n >= 1 && n <= 120 && /^\d{4}-\d{2}-\d{2}$/.test(first) ? buildSchedule(tot, n, first, every) : []), [tot, n, first, every]);
  // الجدول بيتعمل لوحده من الإجمالي والعدد، ولو عدّلت فيه بإيدك بيفضل زي ما عدّلته
  useLayoutEffect(() => {
    if (!edited) setRows(auto.map((r) => ({ due: r.due, amount: String(r.amount / 100) })));
  }, [auto, edited]);
  const parsed = rows.map((r) => ({ due: r.due, amount: parsePounds(r.amount) }));
  const sum = parsed.reduce((a, r) => a + (r.amount ?? 0), 0);
  async function save() {
    setErr(null);
    if (!parsed.length || parsed.some((r) => !r.amount || r.amount <= 0 || !/^\d{4}-\d{2}-\d{2}$/.test(r.due))) return setErr(t('inst.errRows'));
    setBusy(true);
    try {
      await rpc('save_plan', { p_id: id, p_party_type: partyType, p_party: partyId, p_rows: parsed, p_title: title || null });
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
      title={t('inst.new')}
      description={t(`inst.hint.${partyType}`)}
      footer={
        <>
          <span className="me-auto text-sm text-fg-2">
            {t('fin.total')}: <span className="num text-fg" data-testid="plan-sum">{f.money(sum)}</span>
          </span>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="plan-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('inst.name')}>
          <Input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={120} placeholder={t('inst.namePh')} />
        </Field>
        <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
          <Field label={t('inst.total')}>
            <Input mono inputMode="decimal" value={total} onChange={(e) => { setTotal(e.target.value); setEdited(false); }} suffix={f.currency()} data-testid="plan-total" />
          </Field>
          <Field label={t('inst.count')} hint={t('inst.countHint')}>
            <Input mono inputMode="numeric" value={count} onChange={(e) => { setCount(e.target.value); setEdited(false); }} data-testid="plan-count" />
          </Field>
          <Field label={t('inst.first')}>
            <Input type="date" dir="ltr" value={first} onChange={(e) => { setFirst(e.target.value); setEdited(false); }} data-testid="plan-first" />
          </Field>
          <Field label={t('inst.every')}>
            <Select value={every} onChange={(e) => { setEvery(e.target.value as Every); setEdited(false); }} data-testid="plan-every">
              <option value="month">{t('inst.everyMonth')}</option>
              <option value="week">{t('inst.everyWeek')}</option>
            </Select>
          </Field>
        </div>
        {rows.length > 0 && (
          <div className="flex flex-col gap-1.5" role="group" aria-label={t('inst.schedule')}>
            {rows.map((r, i) => (
              <div key={i} className="grid grid-cols-[32px_minmax(0,1fr)_minmax(0,1fr)] items-center gap-2" data-testid="plan-row-edit">
                <span className="num text-center text-xs text-fg-3">{f.number(i + 1)}</span>
                <Input type="date" dir="ltr" value={r.due} aria-label={t('inst.dueN', { n: i + 1 })} onChange={(e) => { setEdited(true); setRows((x) => x.map((y, j) => (j === i ? { ...y, due: e.target.value } : y))); }} />
                <Input mono inputMode="decimal" value={r.amount} aria-label={t('inst.amountN', { n: i + 1 })} onChange={(e) => { setEdited(true); setRows((x) => x.map((y, j) => (j === i ? { ...y, amount: e.target.value } : y))); }} suffix={f.currency()} />
              </div>
            ))}
          </div>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
