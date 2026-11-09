import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus } from 'lucide-react';
import { useLoad, must } from '../../app/useLoad';
import { opId, rpc, useAccountName, type Account } from '../../app/ledgerApi';
import { supabase } from '../../lib/supabase';
import { PAYMENT_METHODS } from '../../lib/regions';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { PricingSettings } from './PricingSettings';

/** الخزن وبنود المصروفات: صاحب المحل بيضيف خزن، ويحدد مسؤول الدرج، ويضيف بنود مصروفات */
export function LedgerTab() {
  const { t } = useTranslation();
  const toast = useToast();
  const accName = useAccountName();
  const { data, loading, reload } = useLoad(async () => {
    const accs = must(await supabase.from('accounts').select('id, code, name, type, kind, method, holder_id, active').in('kind', ['cash', 'expense']).is('deleted_at', null).order('created_at')) as Account[];
    const staff = must(await supabase.from('profiles').select('id, full_name, role').is('deleted_at', null).neq('role', 'technician').order('full_name')) as { id: string; full_name: string }[];
    return { accs, staff };
  }, []);
  const [kind, setKind] = useState<'cash' | 'expense'>('cash');
  const [name, setName] = useState('');
  const [method, setMethod] = useState<string>('cash');
  const [err, setErr] = useState<string | null>(null);

  async function run(fn: () => Promise<unknown>) {
    setErr(null);
    try {
      await fn();
      toast({ tone: 'ok', title: t('settings.saved') });
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  async function add() {
    if (!name.trim()) return setErr(t('inv.errName'));
    await run(() => rpc('add_account', { p_id: opId(), p_kind: kind, p_name: name.trim(), p_method: kind === 'cash' ? method : null }));
    setName('');
  }
  if (loading || !data) return <Skeleton className="h-40 w-full" />;
  const cash = data.accs.filter((a) => a.kind === 'cash');
  const exp = data.accs.filter((a) => a.kind === 'expense');
  return (
    <div className="flex flex-col gap-4">
      <PricingSettings />
      <Panel>
        <PanelHeader title={t('ledgerSettings.cashboxes')} />
        <ul className="divide-y divide-glass-border">
          {cash.map((a) => (
            <li key={a.id} className="flex flex-wrap items-center gap-3 px-4 py-2.5 text-sm">
              <span className="min-w-0 flex-1 truncate text-fg">
                {accName(a)} <span className="text-2xs text-fg-3">· {t(`payments.${a.method}`, { defaultValue: a.method ?? '' })}</span>
              </span>
              <label className="flex items-center gap-2 text-xs text-fg-3">
                {t('ledgerSettings.holder')}
                <Select
                  aria-label={`${t('ledgerSettings.holder')} ${accName(a)}`}
                  value={a.holder_id ?? ''}
                  onChange={(e) => void run(() => rpc('update_account', e.target.value ? { p_id: a.id, p_holder: e.target.value } : { p_id: a.id, p_clear_holder: true }))}
                  className="h-8 w-40"
                >
                  <option value="">{t('ledgerSettings.ownerOnly')}</option>
                  {data.staff.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.full_name}
                    </option>
                  ))}
                </Select>
              </label>
              <Button size="sm" variant="ghost" onClick={() => void run(() => rpc('update_account', { p_id: a.id, p_active: !a.active }))}>
                {a.active ? t('ledgerSettings.disable') : t('ledgerSettings.enable')}
              </Button>
            </li>
          ))}
        </ul>
      </Panel>
      <Panel>
        <PanelHeader title={t('ledgerSettings.expenses')} />
        <div className="flex flex-wrap gap-1.5 p-4">
          {exp.map((a) => (
            <span key={a.id} className="inline-flex h-7 items-center rounded-full border border-line px-3 text-xs text-fg-2">
              {accName(a)}
            </span>
          ))}
        </div>
      </Panel>
      <Panel className="p-4">
        <div className="grid items-end gap-3 sm:grid-cols-[140px_minmax(0,1fr)_160px_auto]">
          <Field label={t('ledgerSettings.type')}>
            <Select value={kind} onChange={(e) => setKind(e.target.value as 'cash' | 'expense')}>
              <option value="cash">{t('ledgerSettings.newCashbox')}</option>
              <option value="expense">{t('ledgerSettings.newExpense')}</option>
            </Select>
          </Field>
          <Field label={t('inv.cols.name')}>
            <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={80} />
          </Field>
          {kind === 'cash' ? (
            <Field label={t('ledgerSettings.method')}>
              <Select value={method} onChange={(e) => setMethod(e.target.value)}>
                {PAYMENT_METHODS.map((m) => (
                  <option key={m} value={m}>
                    {t(`payments.${m}`)}
                  </option>
                ))}
              </Select>
            </Field>
          ) : (
            <span />
          )}
          <Button variant="primary" needsNet icon={<Plus className="size-4" />} onClick={() => void add()}>
            {t('ledgerSettings.add')}
          </Button>
        </div>
        {err && (
          <Alert tone="danger" className="mt-3">
            {err}
          </Alert>
        )}
      </Panel>
    </div>
  );
}
