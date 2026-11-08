import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { RotateCcw } from 'lucide-react';
import { usePrefs } from '../../app/prefs';
import { LOGO_ANIMS, LogoIntro, type LogoAnim } from '../../ui/LogoIntro';
import { LOGO_RATIO } from '../../ui/Logo';
import { Panel, PanelHeader } from '../../ui/Panel';
import { cn } from '../../ui/cn';

/** اختيار شكل حركة لوجو التطبيق في الافتتاحية، مع معاينة حيّة لكل شكل (نفس الحركة بالظبط) */
export function LogoAnimPicker() {
  const { t } = useTranslation();
  const { logoAnim, setLogoAnim, calm } = usePrefs();
  // كل ضغطة على "شوف تاني" بتعيد الحركة من الأول
  const [runs, setRuns] = useState<Record<LogoAnim, number>>({ draw: 0, shine: 0, assemble: 0 });
  const h = 64;
  const w = Math.round(h * LOGO_RATIO);
  return (
    <Panel data-testid="logo-anim-picker">
      <PanelHeader title={t('logoAnim.title')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{calm ? t('logoAnim.calm') : t('logoAnim.hint')}</p>
        <div role="radiogroup" aria-label={t('logoAnim.title')} className="grid gap-3 sm:grid-cols-3">
          {LOGO_ANIMS.map((a) => {
            const on = logoAnim === a;
            return (
              <div key={a} className={cn('flex flex-col items-center gap-2 rounded-md border p-3 transition-colors', on ? 'border-accent bg-accent-soft' : 'border-glass-border')}>
                <button type="button" role="radio" aria-checked={on} onClick={() => { setLogoAnim(a); setRuns((r) => ({ ...r, [a]: r[a] + 1 })); }} className="flex w-full flex-col items-center gap-2 rounded-md focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus" data-testid={`logo-anim-${a}`}>
                  <div className="grid h-24 w-full place-items-center overflow-hidden rounded-md bg-sunken/60">
                    <LogoIntro key={runs[a]} style={a} w={w} h={h} calm={calm} alt="" testids={false} />
                  </div>
                  <span className="text-sm font-medium text-fg">{t(`logoAnim.${a}`)}</span>
                  <span className="text-2xs text-fg-3">{t(`logoAnim.${a}Hint`)}</span>
                </button>
                <button type="button" onClick={() => setRuns((r) => ({ ...r, [a]: r[a] + 1 }))} className="inline-flex items-center gap-1 text-2xs text-fg-3 hover:text-fg">
                  <RotateCcw className="size-3" aria-hidden /> {t('logoAnim.replay')}
                </button>
              </div>
            );
          })}
        </div>
      </div>
    </Panel>
  );
}
