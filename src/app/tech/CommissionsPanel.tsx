import { useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Gift, Minus, Plus, X } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { useLoad } from '../useLoad';
import { useRouteName } from './names';
import { useMe } from '../auth';
import { opId, rpc } from '../ledgerApi';
import { ExportMenu } from '../exporting';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Field, Input, Select, Textarea } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

interface Row {
  technician_id: string;
  full_name: string;
  devices: number;
  commission: number;
  bonus: number;
  penalty: number;
  paid: number;
  balance: number;
}

/** C5: تقرير عمولات الفنيين في الفترة (من القيود): الأجهزة، والعمولة، والمكافآت، والجزاءات، والمصروف، والرصيد. لصاحب المحل */
export function CommissionsPanel({ from, to, periodLine }: { from: Date; to: Date; periodLine: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const [op, setOp] = useState<{ row: Row; kind: 'bonus' | 'penalty' } | null>(null);
  const { data, error, reload } = useLoad(
    async () =>
      (((await rpc('commissions_report', { p_from: from.toISOString(), p_to: to.toISOString() })) ?? []) as Row[]).map((r) => ({
        ...r,
        devices: Number(r.devices),
        commission: Number(r.commission),
        bonus: Number(r.bonus),
        penalty: Number(r.penalty),
        paid: Number(r.paid),
        balance: Number(r.balance),
      })),
    [from.getTime(), to.getTime()],
  );
  const cur = f.currency(shop.currency);
  const title = t('comm.title');
  return (
    <Panel className="break-inside-avoid overflow-hidden" data-testid="report-commissions">
      <PanelHeader
        title={title}
        actions={
          <span className="print:hidden">
            <ExportMenu
              testid="report-commissions-export"
              disabled={!data?.length}
              table={() => ({
                title,
                meta: [periodLine],
                file: 'commissions',
                columns: [
                  { header: t('roles.technician') },
                  { header: t('reports.devices'), type: 'int', total: true },
                  { header: t('comm.commission'), type: 'money', total: true },
                  { header: t('comm.bonus'), type: 'money', total: true },
                  { header: t('comm.penalty'), type: 'money', total: true },
                  { header: t('comm.paid'), type: 'money', total: true },
                  { header: t('comm.balance'), type: 'money', total: true },
                ],
                rows: (data ?? []).map((r) => [r.full_name, r.devices, r.commission, r.bonus, r.penalty, r.paid, r.balance]),
              })}
            />
          </span>
        }
      />
      {error ? (
        <div className="p-4">
          <Alert tone="danger">{error}</Alert>
        </div>
      ) : !data ? (
        <Skeleton className="m-4 h-24" />
      ) : data.length === 0 ? (
        <p className="p-4 text-sm text-fg-3">{t('comm.noTechs')}</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-sm [&_td]:px-3 [&_td]:py-2 [&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
            <thead className="text-2xs text-fg-3">
              <tr>
                <th>{t('roles.technician')}</th>
                <th>{t('reports.devices')}</th>
                <th>{t('comm.commission')}</th>
                <th>{t('comm.bonus')}</th>
                <th>{t('comm.penalty')}</th>
                <th>{t('comm.paid')}</th>
                <th>{t('comm.balance')}</th>
                <th className="print:hidden" />
              </tr>
            </thead>
            <tbody>
              {data.map((r) => (
                <tr key={r.technician_id} className="border-t border-glass-border" data-testid="comm-row">
                  <td>
                    <Link to={`/finance/employee/${r.technician_id}`} className="text-fg hover:text-accent focus-visible:outline-2 focus-visible:outline-accent">
                      {r.full_name}
                    </Link>
                  </td>
                  <td className="num">{r.devices}</td>
                  <td className="num" data-testid="comm-commission">
                    {f.money(r.commission)}
                  </td>
                  <td className="num">{f.money(r.bonus)}</td>
                  <td className="num">{f.money(r.penalty)}</td>
                  <td className="num">{f.money(r.paid)}</td>
                  <td className="num font-semibold" data-testid="comm-balance">
                    {f.money(r.balance)} {cur}
                  </td>
                  <td className="print:hidden">
                    <div className="flex justify-end gap-1">
                      <Button size="sm" variant="ghost" onClick={() => setOp({ row: r, kind: 'bonus' })} icon={<Gift className="size-3.5" />} data-testid="comm-bonus">
                        {t('comm.addBonus')}
                      </Button>
                      <Button size="sm" variant="ghost" onClick={() => setOp({ row: r, kind: 'penalty' })} icon={<Minus className="size-3.5" />} data-testid="comm-penalty">
                        {t('comm.addPenalty')}
                      </Button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <BonusDialog op={op} onClose={() => setOp(null)} onDone={reload} />
    </Panel>
  );
}

function BonusDialog({ op, onClose, onDone }: { op: { row: Row; kind: 'bonus' | 'penalty' } | null; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function save() {
    if (!op) return;
    setErr(null);
    const a = parsePounds(amount);
    if (!a || a <= 0) return setErr(t('comm.needAmount'));
    if (op.kind === 'penalty' && !note.trim()) return setErr(t('comm.needReason'));
    setBusy(true);
    try {
      await rpc(op.kind === 'bonus' ? 'staff_bonus' : 'staff_penalty', { p_id: opId(), p_employee: op.row.technician_id, p_amount: a, p_note: note.trim() || null });
      toast({ tone: 'ok', title: op.kind === 'bonus' ? t('comm.bonusDone') : t('comm.penaltyDone') });
      setAmount('');
      setNote('');
      onClose();
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open={!!op}
      onOpenChange={(v) => !v && onClose()}
      title={op ? `${op.kind === 'bonus' ? t('comm.addBonus') : t('comm.addPenalty')}: ${op.row.full_name}` : ''}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()} data-testid="comm-op-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('comm.amount')} required>
          <Input mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} data-testid="comm-op-amount" />
        </Field>
        <Field label={op?.kind === 'penalty' ? t('comm.reason') : t('comm.note')} required={op?.kind === 'penalty'}>
          <Textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} data-testid="comm-op-note" />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

interface Rule {
  id: string;
  technician_id: string | null;
  route_id: string | null;
  mode: 'percent' | 'fixed';
  value: number;
}

/** C5: الإعدادات ← الفنيين: قواعد العمولة (نسبة من المصنعية أو مبلغ ثابت، لكل فني أو نوع عطل) */
export function CommissionRulesPanel() {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const { shop } = useMe();
  const { data, error, reload } = useLoad(async () => {
    const [rules, techs, routes] = await Promise.all([
      supabase.from('commission_rules').select('id, technician_id, route_id, mode, value').is('deleted_at', null).order('created_at'),
      supabase.from('profiles').select('id, full_name').eq('role', 'technician').is('deleted_at', null).order('full_name'),
      supabase.from('routes').select('id, code, name').is('deleted_at', null).order('created_at'),
    ]);
    if (rules.error) throw rules.error;
    return {
      rules: (rules.data ?? []) as Rule[],
      techs: (techs.data ?? []) as { id: string; full_name: string }[],
      routes: (routes.data ?? []) as { id: string; code: string | null; name: string | null }[],
    };
  }, []);
  const [tech, setTech] = useState('');
  const [route, setRoute] = useState('');
  const [mode, setMode] = useState<'percent' | 'fixed'>('percent');
  const [value, setValue] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const rn = useRouteName();
  const routeName = (id: string | null) => {
    const r = data?.routes.find((x) => x.id === id);
    return r ? rn(r) : t('comm.anyRoute');
  };
  const techName = (id: string | null) => data?.techs.find((x) => x.id === id)?.full_name ?? t('comm.anyTech');
  const show = (r: Rule) => (r.mode === 'percent' ? `${(Number(r.value) / 100).toLocaleString('en-US', { maximumFractionDigits: 2 })}%` : `${f.money(Number(r.value))} ${f.currency(shop.currency)}`);

  async function add() {
    setErr(null);
    let v: number | null;
    if (mode === 'percent') {
      const n = Number(toLatinDigits(value.trim()).replace('%', ''));
      // النسبة بـ basis points (عدد صحيح): 12.5% = 1250
      v = Number.isFinite(n) && n > 0 && n <= 100 ? Math.round(n * 100) : null;
    } else v = parsePounds(value);
    if (!v || v <= 0) return setErr(mode === 'percent' ? t('comm.badPercent') : t('comm.needAmount'));
    setBusy(true);
    const r = await supabase.from('commission_rules').insert({ id: crypto.randomUUID(), technician_id: tech || null, route_id: route || null, mode, value: v });
    setBusy(false);
    if (r.error) return setErr(/duplicate|unique/i.test(r.error.message) ? t('comm.dup') : errorMessage(r.error));
    setValue('');
    toast({ tone: 'ok', title: t('settings.saved') });
    reload();
  }
  async function remove(id: string) {
    const r = await supabase.from('commission_rules').update({ deleted_at: new Date().toISOString() }).eq('id', id);
    if (r.error) return toast({ tone: 'danger', title: errorMessage(r.error) });
    reload();
  }

  return (
    <Panel data-testid="commission-rules">
      <PanelHeader title={t('comm.rules')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('comm.rulesHint')}</p>
        {error ? (
          <Alert tone="danger">{error}</Alert>
        ) : !data ? (
          <Skeleton className="h-20 w-full" />
        ) : (
          <>
            {data.rules.length === 0 ? (
              <p className="text-sm text-fg-3">{t('comm.noRules')}</p>
            ) : (
              <ul className="divide-y divide-line rounded-md border border-line">
                {data.rules.map((r) => (
                  <li key={r.id} className="flex items-center justify-between gap-2 px-3 py-2 text-sm" data-testid="comm-rule">
                    <span className="min-w-0 truncate text-fg">
                      {techName(r.technician_id)} · {routeName(r.route_id)}
                    </span>
                    <span className="flex items-center gap-2">
                      <span className="num text-fg">{show(r)}</span>
                      <button type="button" onClick={() => void remove(r.id)} aria-label={t('comm.remove')} className="grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-danger-soft hover:text-danger">
                        <X className="size-3.5" />
                      </button>
                    </span>
                  </li>
                ))}
              </ul>
            )}
            <div className="flex flex-wrap items-end gap-2">
              <Field label={t('roles.technician')}>
                <Select value={tech} onChange={(e) => setTech(e.target.value)} data-testid="comm-tech">
                  <option value="">{t('comm.anyTech')}</option>
                  {data.techs.map((x) => (
                    <option key={x.id} value={x.id}>
                      {x.full_name}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label={t('comm.route')}>
                <Select value={route} onChange={(e) => setRoute(e.target.value)}>
                  <option value="">{t('comm.anyRoute')}</option>
                  {data.routes.map((x) => (
                    <option key={x.id} value={x.id}>
                      {routeName(x.id)}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label={t('comm.mode')}>
                <Select value={mode} onChange={(e) => setMode(e.target.value as 'percent' | 'fixed')} data-testid="comm-mode">
                  <option value="percent">{t('comm.percent')}</option>
                  <option value="fixed">{t('comm.fixed')}</option>
                </Select>
              </Field>
              <Field label={mode === 'percent' ? t('comm.percentValue') : t('comm.amount')}>
                <Input mono inputMode="decimal" value={value} onChange={(e) => setValue(e.target.value)} className="w-28" data-testid="comm-value" />
              </Field>
              <Button variant="primary" loading={busy} onClick={() => void add()} icon={<Plus className="size-4" />} className="mb-5" data-testid="comm-add">
                {t('comm.add')}
              </Button>
            </div>
            {err && <Alert tone="danger">{err}</Alert>}
          </>
        )}
      </div>
    </Panel>
  );
}
