import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Activity, CheckCircle2, Cpu, Gauge, PauseCircle } from 'lucide-react';
import { usePrefs } from '../../app/prefs';
import { setBgStillSaved, useBgStillSaved } from '../../app/stage';
import { detectSoftwareRendering, motionReasons, type MotionReason } from '../../app/motionStatus';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';

const ICON: Record<MotionReason, typeof Activity> = { reduced: PauseCircle, auto: Gauge, software: Cpu };

/** حالة الخلفية المتحركة على الجهاز ده: شغالة ولا واقفة، وليه، والحل لكل سبب */
export function MotionStatus() {
  const { t } = useTranslation();
  const { calm } = usePrefs();
  const autoStill = useBgStillSaved();
  const [software, setSoftware] = useState<boolean | null>(null);
  useEffect(() => setSoftware(detectSoftwareRendering()), []);
  const reasons = motionReasons({ reduced: calm, autoStill, software });
  const stopped = calm || autoStill;
  return (
    <Panel data-testid="motion-status">
      <PanelHeader title={t('motion.title')} />
      <div className="flex flex-col gap-3 p-4">
        <div className="flex items-center gap-2 text-sm font-medium" data-testid="motion-state" data-state={stopped ? 'still' : 'live'}>
          {stopped ? <PauseCircle className="size-4 text-warn" aria-hidden /> : <CheckCircle2 className="size-4 text-ok" aria-hidden />}
          <span className={stopped ? 'text-warn' : 'text-ok'}>{stopped ? t('motion.stopped') : t('motion.running')}</span>
        </div>
        {reasons.map((r) => {
          const Icon = ICON[r];
          return (
            <div key={r} className="rounded-md border border-glass-border bg-sunken/40 p-3 text-sm" data-testid={`motion-reason-${r}`}>
              <div className="flex items-center gap-2 font-medium text-fg">
                <Icon className="size-4 text-accent" aria-hidden />
                {t(`motion.${r}.title`)}
              </div>
              <p className="mt-1 text-xs text-fg-2">{t(`motion.${r}.why`)}</p>
              <ol className="mt-2 list-decimal space-y-0.5 ps-5 text-xs text-fg-2">
                {(t(`motion.${r}.steps`, { returnObjects: true }) as string[]).map((st) => (
                  <li key={st}>
                    <bdi>{st}</bdi>
                  </li>
                ))}
              </ol>
              {r === 'auto' && (
                <Button size="sm" className="mt-2" onClick={() => setBgStillSaved(false)}>
                  {t('prefs.bgRestore')}
                </Button>
              )}
            </div>
          );
        })}
      </div>
    </Panel>
  );
}
