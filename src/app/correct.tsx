import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from './auth';
import { usePerms } from './perms';
import { useToast } from '../ui/Toast';
import { errorMessage } from '../lib/errors';
import { deferUndoable, UNDO_MS } from '../lib/undo';

/** القيد بتاع أنهي قسم: نفس entry_section في قاعدة البيانات (0075) */
export function entrySection(source: string): string {
  if (['sale', 'sale_return'].includes(source)) return 'sales';
  if (['payment', 'transfer', 'drawer_close'].includes(source)) return 'cashbox';
  if (source === 'expense') return 'expenses';
  if (['purchase', 'supplier_payment', 'supplier_return'].includes(source)) return 'purchases';
  if (['write_off', 'stock_transfer'].includes(source)) return 'inventory';
  if (['part_use', 'delivery'].includes(source)) return 'devices';
  return 'finance';
}

/** يقدر يعدّل ويلغي ويحذف في القسم ده؟ صاحب المحل دايمًا، أو إذن "يصحح ويحذف" الكامل، أو "يحذف" في القسم نفسه */
export function useCanCorrect() {
  const { profile } = useMe();
  const { grant } = usePerms();
  return (section: string) => profile.role === 'owner' || !!profile.can_correct || grant(section, 'delete');
}

function Countdown({ ms }: { ms: number }) {
  const { t } = useTranslation();
  const [left, setLeft] = useState(Math.ceil(ms / 1000));
  useEffect(() => {
    const iv = setInterval(() => setLeft((n) => Math.max(0, n - 1)), 1000);
    return () => clearInterval(iv);
  }, []);
  return <span data-testid="undo-countdown">{t('undo.in', { n: left })}</span>;
}

/**
 * حذف أو إلغاء مع "تراجع": التنبيه بيظهر بعدّاد، والعملية ما بتتبعتش لقاعدة البيانات غير لما المدة تخلص.
 * لو داس "تراجع" قبلها، ولا حاجة بتحصل خالص.
 */
export function useUndoable() {
  const { t } = useTranslation();
  const toast = useToast();
  return (opts: { title: string; done: string; run: () => Promise<unknown>; onDone?: () => void }) => {
    const d = deferUndoable(() => {
      opts
        .run()
        .then(() => {
          toast({ tone: 'ok', title: opts.done });
          opts.onDone?.();
        })
        .catch((e) => toast({ tone: 'danger', title: errorMessage(e) }));
    });
    toast({
      tone: 'warn',
      title: opts.title,
      description: <Countdown ms={UNDO_MS} />,
      duration: UNDO_MS,
      action: {
        label: t('undo.undo'),
        onClick: () => {
          if (d.undo()) toast({ tone: 'info', title: t('undo.undone') });
        },
      },
    });
  };
}
