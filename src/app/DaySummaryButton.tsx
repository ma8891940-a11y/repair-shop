import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Send } from 'lucide-react';
import { useMe } from './auth';
import { rpc, type Position } from './ledgerApi';
import { supabase } from '../lib/supabase';
import { cairoDay, cairoDayEnd, cairoDayStart } from '../lib/dates';
import { daySummaryText, readExtras, waShareUrl } from '../lib/extras';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Button } from '../ui/Button';
import { useToast } from '../ui/Toast';

/**
 * ملخص اليوم على واتساب (لصاحب المحل): عدد الأجهزة اللي دخلت واتسلّمت والجاهزة، والإيراد والمصروف والمقبوض بكل طريقة.
 * أرقام بس، من غير أي اسم أو رقم عميل. واتساب بيفتح من غير رقم، وصاحب المحل بيختار يبعته لمين.
 */
export function DaySummaryButton() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const toast = useToast();
  const [busy, setBusy] = useState(false);
  if (profile.role !== 'owner' || !readExtras(shop.extras).day_summary) return null;

  async function share() {
    setBusy(true);
    try {
      const day = cairoDay(new Date());
      const from = cairoDayStart(day).toISOString();
      const to = cairoDayEnd(day).toISOString();
      const count = async (q: PromiseLike<{ count: number | null; error: unknown }>) => {
        const r = await q;
        if (r.error) throw r.error;
        return r.count ?? 0;
      };
      const [p, received, ready] = await Promise.all([
        rpc<Position>('financial_position', { p_from: from, p_to: to }),
        count(supabase.from('devices').select('id', { count: 'exact', head: true }).is('deleted_at', null).gte('received_at', from).lt('received_at', to)),
        count(supabase.from('devices').select('id', { count: 'exact', head: true }).is('deleted_at', null).eq('status', 'ready')),
      ]);
      const text = daySummaryText(
        shop.name,
        f.dateLong(new Date()),
        { received, delivered: p.delivered, ready, revenue: p.revenue, expenses: p.expenses, byMethod: Object.fromEntries(Object.entries(p.by_method).map(([k, v]) => [k, Number(v)])) },
        {
          title: t('extras.summary.title'),
          received: t('extras.summary.received'),
          delivered: t('extras.summary.delivered'),
          ready: t('extras.summary.ready'),
          revenue: t('fin.revenue'),
          expenses: t('fin.expenses'),
          profit: t('extras.summary.profit'),
          collected: t('extras.summary.collected'),
          currency: f.currency(shop.currency),
        },
        (m) => t(`payments.${m}`, { defaultValue: m }),
      );
      window.open(waShareUrl(text), '_blank', 'noopener');
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }
  return (
    <Button variant="secondary" loading={busy} icon={<Send className="size-4" />} tip={t('extras.summary.tip')} onClick={() => void share()}>
      {t('extras.summary.button')}
    </Button>
  );
}
