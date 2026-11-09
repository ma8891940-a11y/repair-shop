import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { CalendarRange, Send } from 'lucide-react';
import { rpc, type Position } from '../ledgerApi';
import { financeNumbers } from '../../lib/assistPayloads';
import { cairoDay, cairoDayEnd, cairoDayStart } from '../../lib/dates';
import { Button } from '../../ui/Button';
import { Input } from '../../ui/Field';
import { Panel, PanelHeader } from '../../ui/Panel';
import { askAssistant, AssistNote, useAssistAllowed, useAssistServer, type AssistError } from '../assist';

const posNumbers = (p: Position) => financeNumbers({ cash: p.cash, receivables: p.receivables, payables: p.payables, inventory: p.inventory, revenue: p.revenue, expenses: p.expenses, profit: p.profit, net_worth: p.net_worth, delivered: p.delivered });

/**
 * المالية (صاحب المحل): سؤال بالعربي عن أرقام الفترة، وملخص الأسبوع. أرقام مجمّعة بس (من غير أسماء ولا حركات).
 * مقفولة افتراضيًا: صاحب المحل بيفتحها من الإعدادات ← المساعد بعد ما يقرا تنبيه الطبقة المجانية.
 */
export function FinanceAssist({ p, period }: { p: Position | undefined; period: string }) {
  const { t } = useTranslation();
  const allowed = useAssistAllowed('finance');
  const server = useAssistServer();
  const [q, setQ] = useState('');
  const [busy, setBusy] = useState<'qa' | 'week' | null>(null);
  const [answer, setAnswer] = useState<string | null>(null);
  const [err, setErr] = useState<AssistError | null>(null);
  if (!allowed)
    return (
      <p className="mt-4 text-xs text-fg-3" data-testid="finance-assist-off">
        {t('assist.finance.off')}{' '}
        <Link to="/settings?tab=assistant" className="text-accent hover:underline">
          {t('assist.finance.openSettings')}
        </Link>
      </p>
    );
  async function run(kind: 'qa' | 'week') {
    if (!p) return;
    setBusy(kind);
    setErr(null);
    setAnswer(null);
    let r;
    if (kind === 'qa') {
      r = await askAssistant('finance_qa', { question: q, period, numbers: posNumbers(p) });
    } else {
      // الأسبوع ده (آخر 7 أيام) والأسبوع اللي قبله
      const today = cairoDay(new Date());
      const day = (n: number) => cairoDay(new Date(cairoDayStart(today).getTime() - n * 86_400_000 + 12 * 3_600_000));
      const [now, prev] = await Promise.all([
        rpc<Position>('financial_position', { p_from: cairoDayStart(day(6)).toISOString(), p_to: cairoDayEnd(today).toISOString() }),
        rpc<Position>('financial_position', { p_from: cairoDayStart(day(13)).toISOString(), p_to: cairoDayEnd(day(7)).toISOString() }),
      ]).catch(() => [null, null] as const);
      r = now ? await askAssistant('finance_week', { numbers: posNumbers(now), previous: prev ? posNumbers(prev) : {} }) : ({ ok: false, error: 'unavailable' } as const);
    }
    setBusy(null);
    if (r.ok) setAnswer(r.answer);
    else setErr(r.error);
  }
  const ready = server === 'on' && !!p;
  return (
    <Panel className="mt-4" data-testid="finance-assist">
      <PanelHeader title={t('assist.finance.title')} />
      <div className="flex flex-col gap-2 p-4">
        <p className="text-2xs text-warn">{t('assist.finance.privacy')}</p>
        <form
          className="flex flex-wrap gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (q.trim()) void run('qa');
          }}
        >
          <Input className="min-w-[220px] flex-1" value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('assist.finance.askPh')} aria-label={t('assist.finance.askPh')} maxLength={300} />
          <Button type="submit" size="md" variant="primary" icon={<Send className="size-4" />} loading={busy === 'qa'} disabled={!ready || !q.trim()} data-testid="finance-assist-ask">
            {t('assist.finance.ask')}
          </Button>
          <Button size="md" icon={<CalendarRange className="size-4" />} loading={busy === 'week'} disabled={!ready} onClick={() => void run('week')} data-testid="finance-assist-week">
            {t('assist.finance.week')}
          </Button>
        </form>
        <AssistNote state={err ?? server} />
        {answer && (
          <div className="whitespace-pre-wrap rounded-md border border-glass-border bg-sunken/40 p-3 text-sm text-fg" data-testid="finance-assist-answer">
            {answer}
          </div>
        )}
      </div>
    </Panel>
  );
}
