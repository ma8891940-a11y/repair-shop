import { useEffect } from 'react';
import { useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { FpsGuard } from '../lib/fpsGuard';
import { usePrefs } from './prefs';
import { useToast } from '../ui/Toast';

/**
 * بيراقب الأداء طول ما المؤثرات الكاملة شغالة.
 * لو نزلت تحت 50 إطار لمدة 3 ثواني متواصلة (بعد أول ثانيتين من فتح الشاشة)، بيقفلها لوحده
 * ويظهر تنبيه فيه زرار "رجّعها".
 */
export function EffectsGuard() {
  const { effects, setEffects } = usePrefs();
  const { t } = useTranslation();
  const toast = useToast();
  const location = useLocation();

  useEffect(() => {
    if (!effects) return;
    const guard = new FpsGuard();
    guard.start(performance.now());
    let raf = 0;
    const tick = (now: number) => {
      if (guard.frame(now)) {
        setEffects(false);
        toast({
          tone: 'warn',
          title: t('prefs.autoOff'),
          duration: 10_000,
          action: { label: t('prefs.restore'), onClick: () => setEffects(true) },
        });
        return;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
    // أي شاشة جديدة (location.key) = بداية قياس جديدة بفترة سماح ثانيتين
  }, [effects, location.key, setEffects, t, toast]);

  return null;
}
