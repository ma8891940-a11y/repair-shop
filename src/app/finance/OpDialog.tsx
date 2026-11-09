import { useEffect, useMemo, useState, useLayoutEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../../lib/supabase';
import { cacheSet, localDb } from '../../offline/outbox';
import { parsePounds } from '../../lib/money';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { useMe } from '../auth';
import { useLoad } from '../useLoad';
import { loadCashboxes, opId, rpc, useAccountName, type Account, type Cashbox } from '../ledgerApi';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { shouldQueue, useSync } from '../../offline/sync';

/** العمليات اللي ليها فورم واحد بسيط (مبلغ + خزنة + طرف) */
export const OPS = ['payment', 'expense', 'transfer', 'capital', 'drawing', 'supplier_payment', 'salary', 'salary_payment', 'advance', 'advance_settle'] as const;
export type Op = (typeof OPS)[number];

type Need = 'cashbox' | 'to' | 'customer' | 'supplier' | 'employee' | 'expense';
const NEEDS: Record<Op, Need[]> = {
  payment: ['customer', 'cashbox'],
  expense: ['expense', 'cashbox'],
  transfer: ['cashbox', 'to'],
  capital: ['cashbox'],
  drawing: ['cashbox'],
  supplier_payment: ['supplier', 'cashbox'],
  salary: ['employee'],
  salary_payment: ['employee', 'cashbox'],
  advance: ['employee', 'cashbox'],
  advance_settle: ['employee'],
};

export interface OpFixed {
  customer?: { id: string; name: string };
  supplier?: { id: string; name: string };
  employee?: { id: string; name: string };
  device?: { id: string; label: string };
  cashbox?: string;
  amount?: number;
}

/** القوايم اللي الفورم محتاجها (الخزن، وأنواع المصروفات، والموردين، والموظفين) */
async function loadOpLists(op: Op, fixed: OpFixed) {
  const needs = NEEDS[op];
  const [cbs, exp, sup, emp] = await Promise.all([
    needs.includes('cashbox') || needs.includes('to') ? loadCashboxes() : Promise.resolve([] as Cashbox[]),
    needs.includes('expense') ? supabase.from('accounts').select('id, code, name, type, kind, method, holder_id, active').eq('kind', 'expense').eq('active', true).order('created_at') : Promise.resolve({ data: [] }),
    needs.includes('supplier') && !fixed.supplier ? supabase.from('suppliers').select('id, name').is('deleted_at', null).order('name') : Promise.resolve({ data: [] }),
    needs.includes('employee') && !fixed.employee ? supabase.from('profiles').select('id, full_name').is('deleted_at', null).order('full_name') : Promise.resolve({ data: [] }),
  ]);
  return { cbs, exp: (exp.data ?? []) as Account[], sup: (sup.data ?? []) as { id: string; name: string }[], emp: (emp.data ?? []) as { id: string; full_name: string }[] };
}
const opListsKey = (op: Op, userId: string) => `op-lists:${op}:${userId}`;

/** بيحفظ قوايم الفورم على الجهاز والنت شغال، عشان الدفعة تتسجل بخزنة صح لو النت فصل بعدين */
export async function warmOpLists(op: Op, userId: string) {
  if (typeof navigator !== 'undefined' && !navigator.onLine) return;
  await cacheSet(localDb(), opListsKey(op, userId), await loadOpLists(op, {}));
}

/** فورم عملية فلوس واحدة. كل عملية بتتسجل بدالة في قاعدة البيانات (قيد متوازن جوه transaction) */
export function OpDialog({ op, open, onOpenChange, fixed = {}, onDone }: { op: Op; open: boolean; onOpenChange: (v: boolean) => void; fixed?: OpFixed; onDone?: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, profile } = useMe();
  const toast = useToast();
  const accName = useAccountName();
  const needs = NEEDS[op];
  const [amount, setAmount] = useState('');
  const [cashbox, setCashbox] = useState(fixed.cashbox ?? '');
  const [to, setTo] = useState('');
  const [party, setParty] = useState('');
  const [expense, setExpense] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [id, setId] = useState(opId);
  const sync = useSync();

  // نسخة على الجهاز (وهو مفتوح بس) عشان الدفعة تتسجل بخزنة صح والنت فاصل
  const lists = useLoad(async () => (open ? loadOpLists(op, fixed) : null), [open, op], { cacheKey: open ? opListsKey(op, profile.id) : undefined });

  // كل مرة الفورم يتفتح: عملية جديدة برقم جديد.
  // useLayoutEffect: القيم الأولية بتتحط قبل ما النافذة تترسم، فاللي المستخدم بيكتبه بسرعة ما يتمسحش (كان بيحصل على جهاز بطيء)
  useLayoutEffect(() => {
    if (!open) return;
    setId(opId());
    setAmount(fixed.amount ? String(fixed.amount / 100) : '');
    setNote('');
    setErr(null);
    setTo('');
    setParty('');
    setExpense('');
    setCashbox(fixed.cashbox ?? '');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, op]);
  useEffect(() => {
    const l = lists.data;
    if (!l) return;
    if (!cashbox && l.cbs.length) setCashbox(fixed.cashbox ?? l.cbs[0].id);
    if (!expense && l.exp.length) setExpense(l.exp[0].id);
  }, [lists.data, cashbox, expense, fixed.cashbox]);

  const amountMinor = useMemo(() => parsePounds(amount), [amount]);
  const partyId = fixed.customer?.id ?? fixed.supplier?.id ?? fixed.employee?.id ?? party;

  async function submit() {
    setErr(null);
    // القوايم لسه بتتحمّل: ما نبعتش طلب ناقص
    if (!lists.data) return;
    if (!amountMinor || amountMinor <= 0) return setErr(t('fin.errAmount'));
    if ((needs.includes('cashbox') || needs.includes('to')) && !cashbox) return setErr(t('fin.errCashbox'));
    if (needs.includes('expense') && !expense) return setErr(t('fin.errExpense'));
    if ((needs.includes('supplier') || needs.includes('employee') || needs.includes('customer')) && !partyId) return setErr(t('fin.errParty'));
    if (needs.includes('to') && (!to || to === cashbox)) return setErr(t('fin.errTo'));
    const n = note.trim() || null;
    const base = { p_id: id, p_amount: amountMinor };
    const calls: Record<Op, () => Promise<unknown>> = {
      payment: () => rpc('record_payment', payArgs),
      expense: () => rpc('record_expense', { ...base, p_account: expense, p_cashbox: cashbox, p_note: n }),
      transfer: () => rpc('transfer_cash', { ...base, p_from: cashbox, p_to: to, p_note: n }),
      capital: () => rpc('owner_capital', { ...base, p_cashbox: cashbox, p_note: n }),
      drawing: () => rpc('owner_drawing', { ...base, p_cashbox: cashbox, p_note: n }),
      supplier_payment: () => rpc('pay_supplier', { ...base, p_supplier: partyId, p_cashbox: cashbox, p_note: n }),
      salary: () => rpc('accrue_salary', { ...base, p_employee: partyId, p_note: n }),
      salary_payment: () => rpc('pay_salary', { ...base, p_employee: partyId, p_cashbox: cashbox, p_note: n }),
      advance: () => rpc('give_advance', { ...base, p_employee: partyId, p_cashbox: cashbox, p_note: n }),
      advance_settle: () => rpc('settle_advance', { ...base, p_employee: partyId, p_note: n }),
    };
    setBusy(true);
    // الدفعة بس بتتسجل بدون نت (من المواصفات)، وبنفس رقم العملية فما تتكررش
    const payArgs = { ...base, p_customer: partyId, p_cashbox: cashbox, p_device: fixed.device?.id ?? null, p_note: n };
    const queueIt = async () => {
      await sync.queue('payment', id, payArgs);
      toast({ tone: 'warn', title: t('sync.queued'), description: `${f.money(amountMinor)} ${f.currency(shop.currency)}` });
      onOpenChange(false);
      onDone?.();
    };
    if (op === 'payment' && !navigator.onLine) {
      await queueIt();
      setBusy(false);
      return;
    }
    try {
      await calls[op]();
      toast({ tone: 'ok', title: t('fin.done'), description: `${f.money(amountMinor)} ${f.currency(shop.currency)}` });
      onOpenChange(false);
      onDone?.();
    } catch (e) {
      if (op === 'payment' && shouldQueue(e)) await queueIt();
      else setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  const l = lists.data;
  const cashboxSelect = (value: string, set: (v: string) => void, label: string, exclude?: string) => (
    <Field label={label}>
      <Select value={value} onChange={(e) => set(e.target.value)} disabled={!!fixed.cashbox && set === setCashbox}>
        {!value && <option value="">{t('fin.pick')}</option>}
        {(l?.cbs ?? [])
          .filter((c) => c.id !== exclude)
          .map((c) => (
            <option key={c.id} value={c.id}>
              {accName(c)}
            </option>
          ))}
      </Select>
    </Field>
  );

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t(`fin.ops.${op}`)}
      description={t(`fin.opsHint.${op}`)}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet={op !== 'payment'} loading={busy || (!lists.data && !lists.error)} onClick={() => void submit()} disabled={!(profile.role === 'owner' || profile.role === 'reception')}>
            {t('fin.record')}
          </Button>
        </>
      }
    >
      <form
        className="flex flex-col gap-3"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        {fixed.customer && <ReadOnly label={t('fin.customer')} value={fixed.customer.name} />}
        {fixed.device && <ReadOnly label={t('fin.device')} value={fixed.device.label} mono />}
        {fixed.supplier && <ReadOnly label={t('fin.supplier')} value={fixed.supplier.name} />}
        {fixed.employee && <ReadOnly label={t('fin.employee')} value={fixed.employee.name} />}
        {needs.includes('supplier') && !fixed.supplier && (
          <Field label={t('fin.supplier')}>
            <Select value={party} onChange={(e) => setParty(e.target.value)}>
              <option value="">{t('fin.pick')}</option>
              {l?.sup.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </Select>
          </Field>
        )}
        {needs.includes('employee') && !fixed.employee && (
          <Field label={t('fin.employee')}>
            <Select value={party} onChange={(e) => setParty(e.target.value)}>
              <option value="">{t('fin.pick')}</option>
              {l?.emp.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.full_name}
                </option>
              ))}
            </Select>
          </Field>
        )}
        {needs.includes('expense') && (
          <Field label={t('fin.expenseItem')}>
            <Select value={expense} onChange={(e) => setExpense(e.target.value)}>
              {l?.exp.map((a) => (
                <option key={a.id} value={a.id}>
                  {accName(a)}
                </option>
              ))}
            </Select>
          </Field>
        )}
        {needs.includes('cashbox') && cashboxSelect(cashbox, setCashbox, needs.includes('to') ? t('fin.from') : t('fin.cashbox'))}
        {needs.includes('to') && cashboxSelect(to, setTo, t('fin.to'), cashbox)}
        <Field label={t('fin.amount')}>
          <Input autoFocus dir="ltr" inputMode="decimal" mono value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0" suffix={f.currency(shop.currency)} className="text-start text-md" />
        </Field>
        <Field label={t('fin.note')}>
          <Textarea rows={2} maxLength={500} value={note} onChange={(e) => setNote(e.target.value)} />
        </Field>
        {lists.error && <Alert tone="danger">{lists.error}</Alert>}
        {err && <Alert tone="danger">{err}</Alert>}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

function ReadOnly({ label, value, mono }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="flex items-center justify-between gap-3 rounded-md border border-glass-border bg-sunken/40 px-3 py-2 text-sm">
      <span className="text-fg-3">{label}</span>
      <span className={mono ? 'num text-fg' : 'truncate font-medium text-fg'} dir={mono ? 'ltr' : undefined}>
        <bdi>{value}</bdi>
      </span>
    </div>
  );
}
