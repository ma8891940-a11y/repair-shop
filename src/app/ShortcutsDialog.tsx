import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useMe } from './auth';
import { comboFromEvent, comboProblem, SHORTCUTS, type ShortcutAction, type ShortcutDef } from './shortcutsRegistry';
import { saveExtras } from './shopExtras';
import { errorMessage } from '../lib/errors';
import { Dialog } from '../ui/Dialog';
import { Button } from '../ui/Button';
import { Kbd } from '../ui/Kbd';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';

/**
 * شاشة "الاختصارات" (بتفتح بـ ؟): كل الاختصارات، وصاحب المحل يقدر يغيّر أي واحد منهم.
 * الاختصار الجديد بيتسجل بالضغط عليه، وبيترفض لو محجوز للمتصفح أو الويندوز أو مستخدم في حاجة تانية.
 */
export function ShortcutsDialog({ open, onOpenChange, shortcuts }: { open: boolean; onOpenChange: (v: boolean) => void; shortcuts: ShortcutDef[] }) {
  const { t } = useTranslation();
  const { profile, shop, refresh } = useMe();
  const toast = useToast();
  const owner = profile.role === 'owner';
  const [recording, setRecording] = useState<ShortcutAction | null>(null);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setRecording(null);
    setErr(null);
  }, [open]);

  async function save(next: Record<string, string | undefined>) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const cur = (ex.shortcuts && typeof ex.shortcuts === 'object' ? ex.shortcuts : {}) as Record<string, string>;
    const merged = Object.fromEntries(Object.entries({ ...cur, ...next }).filter(([, v]) => !!v)) as Record<string, string>;
    const { error } = await saveExtras({ shortcuts: merged });
    if (error) return setErr(errorMessage(error));
    await refresh();
    toast({ tone: 'ok', title: t('shortcuts.saved') });
  }

  // تسجيل الاختصار الجديد: أول زرار بيتداس (Esc يلغي)
  useEffect(() => {
    if (!recording) return;
    const onKey = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();
      if (e.key === 'Escape') return setRecording(null);
      const c = comboFromEvent(e);
      if (!c) return;
      const others = shortcuts.filter((s) => s.id !== recording).flatMap((s) => s.combos);
      const p = comboProblem(c, others);
      if (p) return setErr(t(`shortcuts.problem.${p}`, { c }));
      setErr(null);
      setRecording(null);
      void save({ [recording]: c });
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [recording, shortcuts]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={t('shortcuts.title')} description={t('shortcuts.sub')} className="w-[min(94vw,560px)]">
      <table className="w-full text-sm" data-testid="shortcuts-table">
        <tbody className="divide-y divide-glass-border">
          {shortcuts.map((s) => {
            const def = SHORTCUTS.find((d) => d.id === s.id)!;
            const changed = s.combos.join() !== def.combos.join();
            return (
              <tr key={s.id} className="[&_td]:py-2" data-testid={`shortcut-${s.id}`}>
                <td className="text-fg">
                  {t(`shortcuts.actions.${s.id}`)}
                  {!s.inInputs && <div className="text-2xs text-fg-3">{t('shortcuts.outsideInputs')}</div>}
                </td>
                <td className="whitespace-nowrap text-end">
                  {recording === s.id ? (
                    <span className="text-xs text-accent" data-testid="shortcut-recording">
                      {t('shortcuts.pressNow')}
                    </span>
                  ) : (
                    <span className="inline-flex flex-wrap justify-end gap-1" dir="ltr">
                      {s.combos.map((c, i) => (
                        <span key={c} className="inline-flex items-center gap-1">
                          {i > 0 && <span className="text-2xs text-fg-3">/</span>}
                          {c.split('+').map((k) => (
                            <Kbd key={k}>{k}</Kbd>
                          ))}
                        </span>
                      ))}
                    </span>
                  )}
                </td>
                {owner && (
                  <td className="w-28 whitespace-nowrap text-end">
                    {s.editable && (
                      <span className="inline-flex gap-1">
                        <Button size="sm" variant="ghost" onClick={() => (setErr(null), setRecording(s.id))} data-testid={`shortcut-edit-${s.id}`}>
                          {t('shortcuts.change')}
                        </Button>
                        {changed && (
                          <Button size="sm" variant="ghost" onClick={() => void save({ [s.id]: undefined })} data-testid={`shortcut-reset-${s.id}`}>
                            {t('shortcuts.reset')}
                          </Button>
                        )}
                      </span>
                    )}
                  </td>
                )}
              </tr>
            );
          })}
        </tbody>
      </table>
      {err && (
        <Alert tone="danger" className="mt-3">
          <span data-testid="shortcut-error">{err}</span>
        </Alert>
      )}
      <p className="mt-3 text-2xs text-fg-3">{t('shortcuts.laptopNote')}</p>
    </Dialog>
  );
}
