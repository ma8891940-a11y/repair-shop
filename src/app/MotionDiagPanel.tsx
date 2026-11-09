import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { motionDiag, stopReason } from './motionDiag';
import { createFrameCost } from '../lib/fpsGuard';
import { DIAG_SHORTCUT, isDiagShortcut, OPEN_DIAG_EVENT } from './diagShortcut';

/**
 * شاشة تشخيص صغيرة للخلفية المتحركة: بتظهر وتستخبى بـ Ctrl+Alt+Shift+M، أو من زرار "تشخيص الحركة" في الإعدادات ← المظهر.
 * (Ctrl+Shift+D كان محجوز في Chrome وEdge لحفظ كل التبويبات في المفضلة، فالمتصفح كان بياخده قبل البرنامج.)
 * بتعرض عدد الإطارات دلوقتي، وتكلفة الإطار، والخلفية شغالة ولا واقفة وليه، وحالة حارس الأداء.
 */
export function MotionDiagPanel() {
  const { t } = useTranslation();
  const [open, setOpen] = useState(false);
  const [snap, setSnap] = useState({ ...motionDiag, now: 0, cost: 0 });

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      // بالحرف الفعلي على الكيبورد (e.code)، عشان يشتغل والكيبورد عربي برضه
      if (isDiagShortcut(e)) {
        e.preventDefault();
        setOpen((o) => !o);
      }
    };
    const onOpen = () => setOpen(true);
    window.addEventListener('keydown', onKey);
    window.addEventListener(OPEN_DIAG_EVENT, onOpen);
    return () => {
      window.removeEventListener('keydown', onKey);
      window.removeEventListener(OPEN_DIAG_EVENT, onOpen);
    };
  }, []);

  // عدّاد إطارات مستقل (بيشتغل بس والشاشة مفتوحة)
  useEffect(() => {
    if (!open) return;
    const cost = createFrameCost();
    let raf = 0;
    let frames = 0;
    let since = performance.now();
    let fps = 0;
    const tick = (now: number) => {
      cost.mark(now);
      frames++;
      if (now - since >= 500) {
        fps = (frames * 1000) / (now - since);
        frames = 0;
        since = now;
        setSnap({ ...motionDiag, now: fps, cost: cost.last });
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => {
      cancelAnimationFrame(raf);
      cost.close();
    };
  }, [open]);

  if (!open) return null;
  const reason = stopReason(snap);
  const row = (k: string, v: string, testid?: string) => (
    <div className="flex justify-between gap-4">
      <span className="text-fg-3">{k}</span>
      <bdi className="num text-fg" data-testid={testid}>
        {v}
      </bdi>
    </div>
  );
  return (
    <div role="status" aria-label={t('diag.title')} data-testid="motion-diag" data-moving={snap.moving ? '1' : '0'} data-reason={reason ?? ''} className="glass-strong fixed bottom-3 start-3 z-[200] w-72 rounded-lg p-3 text-xs shadow-3 print:hidden">
      <div className="mb-2 flex items-center justify-between font-semibold text-fg">
        {t('diag.title')}
        <kbd className="rounded border border-line px-1 text-2xs text-fg-3">{DIAG_SHORTCUT}</kbd>
      </div>
      <div className="flex flex-col gap-1">
        {row(t('diag.fps'), String(Math.round(snap.now)), 'diag-fps')}
        {row(t('diag.cost'), `${snap.cost.toFixed(1)} ms`)}
        {row(t('diag.state'), snap.moving ? t('diag.moving') : t('diag.stopped'), 'diag-state')}
        {reason && row(t('diag.reason'), t(`diag.reasons.${reason}`), 'diag-reason')}
        {row(t('diag.guard'), t(`diag.guards.${snap.guard}`), 'diag-guard')}
        {snap.fps !== null && row(t('diag.guardFps'), `${Math.round(snap.fps)}${snap.capped ? ` · ${t('diag.capped')}` : ''}`)}
      </div>
    </div>
  );
}
