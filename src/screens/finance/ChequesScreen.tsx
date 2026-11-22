import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowDownLeft, ArrowUpRight, Check, X } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useMe } from '../../app/auth';
import { useBranch } from '../../app/branch';
import { usePerms } from '../../app/perms';
import { useLoad, must } from '../../app/useLoad';
import { cashboxesFor, loadCashboxes, opId, rpc, useAccountName } from '../../app/ledgerApi';
import { ExportMenu } from '../../app/exporting';
import { getBranchHeader } from '../../lib/branchHeader';
import { supabase } from '../../lib/supabase';
import { parsePounds } from '../../lib/money';
import { errorMessage } from '../../lib/errors';
import { chequeUrgency, type ChequeStatus } from '../../lib/cheques';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

interface Cheque {
  id: string;
  direction: 'in' | 'out';
  party_name: string | null;
  cheque_no: string;
  bank: string | null;
  due_date: string;
  amount: number;
  status: ChequeStatus;
  branch_id: string | null;
  note: string | null;
}
type Filter = 'pending' | 'all';

/**
 * R7: الشيكات: شيك من عميل (بيقلل اللي عليه وبيستنى التحصيل) وشيك لمورد (بيقلل اللي له وبيستنى الصرف).
 * "اتصرف" بيدخّل أو يخرّج الفلوس من الخزنة، و"اترفض" بيرجّع الدين زي ما كان. كل خطوة قيد متوازن في قاعدة البيانات.
 */
export function ChequesScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const br = useBranch();
  // التسجيل والصرف والرفض: صاحب المحل أو "المالية ← يضيف" (زي قاعدة البيانات). الباقي بيشوف بس
  const canAct = usePerms().grant('finance', 'add');
  const [filter, setFilter] = useState<Filter>('pending');
  const [add, setAdd] = useState<'in' | 'out' | null>(null);
  const [act, setAct] = useState<{ kind: 'clear' | 'bounce'; c: Cheque } | null>(null);
  const { data, error, reload } = useLoad(
    async () => (await rpc<Cheque[]>('cheques_list', { p_status: filter === 'pending' ? 'pending' : null, p_branch: br.filter })).map((c) => ({ ...c, amount: Number(c.amount) })),
    [filter, br.filter],
  );
  useLiveRefresh(reload);
  const today = new Date();
  const cur = f.currency(shop.currency);
  const sum = (dir: 'in' | 'out') => (data ?? []).filter((c) => c.direction === dir && c.status === 'pending').reduce((a, c) => a + c.amount, 0);

  return (
    <div data-testid="cheques-screen">
      <PageHeader
        title={t('cheques.title')}
        sub={t('cheques.sub')}
        actions={
          <span className="flex flex-wrap gap-2">
            {canAct && (
              <>
                <Button icon={<ArrowDownLeft className="size-4" />} onClick={() => setAdd('in')} data-testid="cheque-add-in">
                  {t('cheques.addIn')}
                </Button>
                <Button icon={<ArrowUpRight className="size-4" />} onClick={() => setAdd('out')} data-testid="cheque-add-out">
                  {t('cheques.addOut')}
                </Button>
              </>
            )}
            <ExportMenu
              testid="cheques-export"
              disabled={!data?.length}
              table={() =>
                data && {
                  title: t('cheques.title'),
                  meta: [shop.name],
                  columns: [
                    { header: t('cheques.cols.dir') },
                    { header: t('cheques.cols.party') },
                    { header: t('cheques.cols.no') },
                    { header: t('cheques.cols.bank') },
                    { header: t('cheques.cols.due'), type: 'date' },
                    { header: t('cheques.cols.amount'), type: 'money', total: true },
                    { header: t('cheques.cols.status') },
                  ],
                  rows: data.map((c) => [t(`cheques.dir.${c.direction}`), c.party_name, c.cheque_no, c.bank, c.due_date, c.amount, t(`cheques.status.${c.status}`)]),
                }
              }
            />
          </span>
        }
      />
      <div className="mb-4 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <Panel className="px-4 py-3">
          <div className="text-xs text-fg-3">{t('cheques.pendingIn')}</div>
          <div className="num text-lg font-semibold text-fg" data-testid="cheques-sum-in">
            {f.money(sum('in'))} {cur}
          </div>
        </Panel>
        <Panel className="px-4 py-3">
          <div className="text-xs text-fg-3">{t('cheques.pendingOut')}</div>
          <div className="num text-lg font-semibold text-fg" data-testid="cheques-sum-out">
            {f.money(sum('out'))} {cur}
          </div>
        </Panel>
      </div>
      <Panel className="overflow-hidden">
        <PanelHeader
          title={t('cheques.list')}
          actions={
            <Select value={filter} onChange={(e) => setFilter(e.target.value as Filter)} className="h-8 w-40" aria-label={t('cheques.filter')} data-testid="cheques-filter">
              <option value="pending">{t('cheques.filterPending')}</option>
              <option value="all">{t('cheques.filterAll')}</option>
            </Select>
          }
        />
        {error ? (
          <ErrorState message={error} onRetry={reload} />
        ) : !data ? (
          <Skeleton className="m-4 h-32" />
        ) : data.length === 0 ? (
          <EmptyState line="chip" title={t('cheques.empty')} />
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[760px] text-sm [&_td]:px-3 [&_td]:py-2 [&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
              <thead className="text-2xs text-fg-3">
                <tr>
                  <th>{t('cheques.cols.dir')}</th>
                  <th>{t('cheques.cols.party')}</th>
                  <th>{t('cheques.cols.no')}</th>
                  <th>{t('cheques.cols.due')}</th>
                  <th className="!text-end">{t('cheques.cols.amount')}</th>
                  <th>{t('cheques.cols.status')}</th>
                  {br.multi && <th>{t('branch.switcher')}</th>}
                  <th className="w-0" />
                </tr>
              </thead>
              <tbody className="divide-y divide-line">
                {data.map((c) => {
                  const u = chequeUrgency(c.status, c.due_date, today);
                  return (
                    <tr key={c.id} data-testid="cheque-row" data-status={c.status}>
                      <td>{t(`cheques.dir.${c.direction}`)}</td>
                      <td>
                        <bdi>{c.party_name}</bdi>
                      </td>
                      <td className="num" dir="ltr">
                        {c.cheque_no}
                        {c.bank && <span className="ms-2 text-2xs text-fg-3">{c.bank}</span>}
                      </td>
                      <td className={cn('num whitespace-nowrap', u === 'overdue' ? 'text-danger' : u === 'soon' ? 'text-warn' : 'text-fg-2')} data-urgency={u}>
                        {f.date(c.due_date)}
                      </td>
                      <td className="num text-end">{f.money(c.amount)}</td>
                      <td className={cn('text-xs', c.status === 'cleared' ? 'text-ok' : c.status === 'bounced' ? 'text-danger' : 'text-fg-2')}>{t(`cheques.status.${c.status}`)}</td>
                      {br.multi && <td>{br.name(c.branch_id)}</td>}
                      <td className="whitespace-nowrap">
                        {c.status === 'pending' && canAct && (
                          <span className="flex gap-1">
                            <Button size="sm" variant="outline" icon={<Check className="size-3.5" />} onClick={() => setAct({ kind: 'clear', c })} data-testid="cheque-clear">
                              {t('cheques.clear')}
                            </Button>
                            <Button size="sm" variant="ghost" icon={<X className="size-3.5" />} onClick={() => setAct({ kind: 'bounce', c })} data-testid="cheque-bounce">
                              {t('cheques.bounce')}
                            </Button>
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
      {add && (
        <AddDialog
          dir={add}
          onClose={() => setAdd(null)}
          onDone={() => {
            setAdd(null);
            reload();
          }}
        />
      )}
      {act && (
        <ActDialog
          kind={act.kind}
          c={act.c}
          onClose={() => setAct(null)}
          onDone={() => {
            setAct(null);
            reload();
          }}
        />
      )}
    </div>
  );
}

function AddDialog({ dir, onClose, onDone }: { dir: 'in' | 'out'; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const parties = useLoad(
    async () =>
      dir === 'in'
        ? (must(await supabase.from('customers').select('id, name, phone').is('deleted_at', null).order('name').limit(1000)) as { id: string; name: string; phone?: string }[])
        : (must(await supabase.from('suppliers').select('id, name').is('deleted_at', null).order('name').limit(1000)) as { id: string; name: string }[]),
    [dir],
  );
  const [party, setParty] = useState('');
  const [no, setNo] = useState('');
  const [bank, setBank] = useState('');
  const [due, setDue] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [id] = useState(opId);
  async function save() {
    setErr(null);
    const a = parsePounds(amount);
    if (!party) return setErr(t('cheques.errParty'));
    if (!no.trim()) return setErr(t('cheques.errNo'));
    if (!due) return setErr(t('cheques.errDue'));
    if (a == null || a <= 0) return setErr(t('cheques.errAmount'));
    setBusy(true);
    try {
      await rpc(dir === 'in' ? 'cheque_receive' : 'cheque_issue', {
        p_id: id,
        [dir === 'in' ? 'p_customer' : 'p_supplier']: party,
        p_no: no.trim(),
        p_bank: bank.trim() || null,
        p_due: due,
        p_amount: a,
        p_note: note.trim() || null,
      });
      toast({ tone: 'ok', title: t('cheques.saved') });
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={t(dir === 'in' ? 'cheques.addIn' : 'cheques.addOut')}
      description={t(dir === 'in' ? 'cheques.hintIn' : 'cheques.hintOut')}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="cheque-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t(dir === 'in' ? 'fin.customer' : 'fin.supplier')} required>
          <Select value={party} onChange={(e) => setParty(e.target.value)} data-testid="cheque-party">
            <option value="">{t('fin.pick')}</option>
            {(parties.data ?? []).map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </Select>
        </Field>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <Field label={t('cheques.cols.no')} required>
            <Input mono dir="ltr" maxLength={40} value={no} onChange={(e) => setNo(e.target.value)} data-testid="cheque-no" />
          </Field>
          <Field label={t('cheques.cols.bank')}>
            <Input maxLength={80} value={bank} onChange={(e) => setBank(e.target.value)} data-testid="cheque-bank" />
          </Field>
          <Field label={t('cheques.cols.due')} required>
            <Input type="date" value={due} onChange={(e) => setDue(e.target.value)} data-testid="cheque-due" />
          </Field>
          <Field label={t('cheques.cols.amount')} required>
            <Input mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency()} data-testid="cheque-amount" />
          </Field>
        </div>
        <Field label={t('vat.note')}>
          <Textarea rows={2} maxLength={300} value={note} onChange={(e) => setNote(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

function ActDialog({ kind, c, onClose, onDone }: { kind: 'clear' | 'bounce'; c: Cheque; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const accName = useAccountName();
  const boxes = useLoad(async () => (kind === 'clear' ? cashboxesFor(await loadCashboxes(), c.branch_id ?? getBranchHeader()) : []), [kind]);
  const [cb, setCb] = useState('');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [op] = useState(opId);
  // البنك الأول لو موجود (الشيك بيتصرف في البنك غالبًا)
  const box = cb || boxes.data?.find((b) => b.method === 'bank_transfer')?.id || boxes.data?.[0]?.id || '';
  async function save() {
    setErr(null);
    if (kind === 'bounce' && !reason.trim()) return setErr(t('cheques.needReason'));
    if (kind === 'clear' && !box) return setErr(t('vat.errBox'));
    setBusy(true);
    try {
      if (kind === 'clear') await rpc('cheque_clear', { p_op: op, p_cheque: c.id, p_cashbox: box });
      else await rpc('cheque_bounce', { p_op: op, p_cheque: c.id, p_reason: reason.trim() });
      toast({ tone: 'ok', title: t(kind === 'clear' ? 'cheques.cleared' : 'cheques.bounced') });
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={t(kind === 'clear' ? 'cheques.clear' : 'cheques.bounce')}
      description={`${c.party_name ?? ''} · ${c.cheque_no} · ${f.money(c.amount)} ${f.currency()}`}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant={kind === 'bounce' ? 'danger' : 'primary'} loading={busy} needsNet onClick={() => void save()} data-testid="cheque-act-save">
            {t(kind === 'clear' ? 'cheques.clear' : 'cheques.bounce')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <p className="text-sm text-fg-2">{t(`cheques.${kind}Hint.${c.direction}`)}</p>
        {kind === 'clear' ? (
          <Field label={t(c.direction === 'in' ? 'cheques.toBox' : 'vat.from')} required>
            <Select value={box} onChange={(e) => setCb(e.target.value)} data-testid="cheque-box">
              {(boxes.data ?? []).map((b) => (
                <option key={b.id} value={b.id}>
                  {accName(b)}
                </option>
              ))}
            </Select>
          </Field>
        ) : (
          <Field label={t('cheques.reason')} required>
            <Textarea rows={2} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} data-testid="cheque-reason" />
          </Field>
        )}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
