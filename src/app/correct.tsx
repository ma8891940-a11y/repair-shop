import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from './auth';
import { useToast } from '../ui/Toast';
import { errorMessage } from '../lib/errors';
import { deferUndoable, UNDO_MS } from '../lib/undo';

/** يقدر يعدّل ويلغي العمليات ويحذف؟ صاحب المحل دايمًا، والموظف لو صاحب المحل اداله الإذن */
export function useCanCorrect() {
  const { profile } = useMe();
  return profile.role === 'owner' || !!profile.can_correct;
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
