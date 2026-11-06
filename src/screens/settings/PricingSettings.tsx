import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, Trash2 } from 'lucide-react';
import { useMe } from '../../app/auth';
import { useLoad, must } from '../../app/useLoad';
import { supabase } from '../../lib/supabase';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

interface Rate {
  id: string;
  issue: string;
  amount: number;
}

/** التسعير: هامش الربح على القطع، وأجرة كل نوع عطل. السعر المقترح للجهاز = القطع + أجرة الأعطال المذكورة في وصفه + الهامش */
export function PricingSettings() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const [margin, setMargin] = useState(String(shop.default_margin_pct ?? 20));
  const [issue, setIssue] = useState('');
  const [amount, setAmount] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const { data, reload } = useLoad(async () => must(await supabase.from('labor_rates').select('id, issue, amount').is('deleted_at', null).order('issue')) as Rate[], []);
  useEffect(() => setMargin(String(shop.default_margin_pct ?? 20)), [shop.default_margin_pct]);

  async function saveMargin() {
    const m = Number(toLatinDigits(margin.trim()));
    if (!Number.isInteger(m) || m < 0 || m > 1000) return setErr(t('pricing.errMargin'));
    const { error } = await supabase.from('shops').update({ default_margin_pct: m }).eq('id', shop.id);
    if (error) return setErr(errorMessage(error));
    setErr(null);
    toast({ tone: 'ok', title: t('settings.saved') });
    await refresh();
  }
  async function add() {
    const a = amount.trim() === '0' ? 0 : parsePounds(amount);
    if (!issue.trim() || a == null) return setErr(t('pricing.errRate'));
    const { error } = await supabase.from('labor_rates').insert({ id: crypto.randomUUID(), shop_id: shop.id, issue: issue.trim(), amount: a });
    if (error) return setErr(errorMessage(error));
    setErr(null);
    setIssue('');
    setAmount('');
    reload();
  }
  async function remove(r: Rate) {
    const { error } = await supabase.from('labor_rates').update({ deleted_at: new Date().toISOString() }).eq('id', r.id);
    if (error) return setErr(errorMessage(error));
    reload();
  }
  return (
    <Panel>
      <PanelHeader title={t('pricing.title')} />
      <div className="flex flex-col gap-4 p-4">
        <p className="text-xs text-fg-3">{t('pricing.hint')}</p>
        <div className="flex items-end gap-2">
          <Field label={t('pricing.margin')} className="w-40">
            <Input dir="ltr" mono inputMode="numeric" value={margin} onChange={(e) => setMargin(e.target.value)} suffix="%" className="text-start" />
          </Field>
          <Button onClick={() => void saveMargin()}>{t('common.save')}</Button>
        </div>
        <div>
          <div className="readout-label mb-1.5">{t('pricing.rates')}</div>
          <ul className="mb-2 divide-y divide-glass-border rounded-md border border-glass-border">
            {(data ?? []).map((r) => (
              <li key={r.id} className="flex items-center gap-3 px-3 py-1.5 text-sm" data-testid="labor-rate">
                <span className="flex-1 text-fg">{r.issue}</span>
                <span className="num text-fg-2">{f.money(r.amount)}</span>
                <button type="button" onClick={() => void remove(r)} className="rounded-sm p-1 text-fg-3 hover:text-danger" aria-label={`${t('pricing.remove')} ${r.issue}`}>
                  <Trash2 className="size-3.5" aria-hidden />
                </button>
              </li>
            ))}
            {data && data.length === 0 && <li className="px-3 py-2 text-xs text-fg-3">{t('pricing.noRates')}</li>}
          </ul>
          <div className="grid grid-cols-[minmax(0,1fr)_120px_auto] items-end gap-2">
            <Field label={t('pricing.issue')}>
              <Input value={issue} onChange={(e) => setIssue(e.target.value)} maxLength={80} placeholder={t('pricing.issuePh')} />
            </Field>
            <Field label={t('pricing.labor')}>
              <Input dir="ltr" mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency(shop.currency)} className="text-start" />
            </Field>
            <Button icon={<Plus className="size-4" />} onClick={() => void add()}>
              {t('ledgerSettings.add')}
            </Button>
          </div>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Panel>
  );
}
