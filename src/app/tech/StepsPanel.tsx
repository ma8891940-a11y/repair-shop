import { useTranslation } from 'react-i18next';
import { useMe } from '../auth';
import { useLoad, must } from '../useLoad';
import { useLiveRefresh } from '../AppShell';
import { rpc } from '../ledgerApi';
import { useDuration, useRouteName, useSpecName } from './names';
import { useRoutes } from './RoutingFields';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { toMinutes } from '../../lib/tech';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Select } from '../../ui/Field';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

interface Step {
  id: string;
  step_no: number;
  specialty_id: string;
  technician_id: string | null;
  status: 'pending' | 'active' | 'done' | 'skipped';
  started_at: string | null;
  finished_at: string | null;
}

type Thenable = PromiseLike<{ error: unknown }>;

/** مسار الجهاز: الخطوات بالترتيب، والفني ووقت كل خطوة. الاستقبال وصاحب المحل بيغيّروا المسار والفني والأولوية والمدة */
export function StepsPanel({ deviceId, routeId, priority, estMinutes, onChanged }: { deviceId: string; routeId: string | null; priority: string; estMinutes: number | null; onChanged: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile } = useMe();
  const toast = useToast();
  const front = (profile.role === 'owner' || profile.role === 'reception');
  const specName = useSpecName();
  const routeName = useRouteName();
  const dur = useDuration();
  const routes = useRoutes();
  const { data, reload } = useLoad(async () => {
    const [s, sp, techs] = await Promise.all([
      supabase.from('repair_steps').select('id, step_no, specialty_id, technician_id, status, started_at, finished_at').eq('device_id', deviceId).neq('status', 'skipped').order('step_no'),
      supabase.from('specialties').select('id, code, name'),
      supabase.from('profiles').select('id, full_name').eq('role', 'technician').is('deleted_at', null).order('full_name'),
    ]);
    return {
      steps: must(s) as Step[],
      spec: new Map((must(sp) as { id: string; code: string | null; name: string | null }[]).map((x) => [x.id, x])),
      techs: must(techs) as { id: string; full_name: string }[],
    };
  }, [deviceId, routeId]);
  useLiveRefresh(reload);

  async function run(fn: () => Thenable) {
    try {
      const r = (await fn()) as { error?: unknown } | undefined;
      if (r && typeof r === 'object' && 'error' in r && r.error) throw r.error;
      toast({ tone: 'ok', title: t('settings.saved') });
      reload();
      onChanged();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }
  const techName = (id: string | null) => data?.techs.find((x) => x.id === id)?.full_name ?? t('tech.unassigned');

  return (
    <Panel>
      <PanelHeader title={t('tech.stepsTitle')} />
      <div className="flex flex-col gap-3 p-4">
        {front && (
          <div className="grid gap-2 sm:grid-cols-3">
            <label className="flex flex-col gap-1 text-2xs text-fg-3">
              {t('tech.route')}
              <Select value={routeId ?? ''} onChange={(e) => e.target.value && void run(() => rpc('set_route', { p_device: deviceId, p_route: e.target.value }))} className="h-8">
                {!routeId && <option value="">{t('fin.pick')}</option>}
                {(routes.data ?? []).map((r) => (
                  <option key={r.id} value={r.id}>
                    {routeName(r)}
                  </option>
                ))}
              </Select>
            </label>
            <label className="flex flex-col gap-1 text-2xs text-fg-3">
              {t('tech.priority')}
              <Select value={priority} onChange={(e) => void run(() => supabase.from('devices').update({ priority: e.target.value }).eq('id', deviceId))} className="h-8">
                {(['normal', 'urgent', 'warranty'] as const).map((p) => (
                  <option key={p} value={p}>
                    {t(`tech.priorities.${p}`)}
                  </option>
                ))}
              </Select>
            </label>
            <label className="flex flex-col gap-1 text-2xs text-fg-3">
              {t('tech.estimate')}
              <Select
                value={estMinutes ? String(estMinutes) : ''}
                onChange={(e) => void run(() => supabase.from('devices').update({ est_minutes: e.target.value ? Number(e.target.value) : null }).eq('id', deviceId))}
                className="h-8"
              >
                <option value="">{t('common.none')}</option>
                {estMinutes && ![30, 60, 120, 240, 1440, 2880, 4320].includes(estMinutes) && <option value={estMinutes}>{dur(estMinutes)}</option>}
                {[30, 60, 120, 240, 1440, 2880, 4320].map((m) => (
                  <option key={m} value={toMinutes(m, 'minute') ?? m}>
                    {dur(m)}
                  </option>
                ))}
              </Select>
            </label>
          </div>
        )}
        {!data || data.steps.length === 0 ? (
          <p className="text-xs text-fg-3">{t('tech.noSteps')}</p>
        ) : (
          <ol className="flex flex-col gap-1.5" data-testid="steps">
            {data.steps.map((s, i) => (
              <li key={s.id} className={cn('flex flex-wrap items-center gap-2 rounded-md border px-3 py-2 text-sm', s.status === 'active' ? 'border-accent bg-accent-soft' : 'border-glass-border', s.status === 'done' && 'text-fg-3')}>
                <span className="num w-5 text-fg-3">{i + 1}</span>
                <span className="font-medium text-fg">{specName(data.spec.get(s.specialty_id))}</span>
                <span className="text-2xs text-fg-3">{t(`tech.stepStatus.${s.status}`)}</span>
                <span className="ms-auto text-xs">
                  {front && s.status !== 'done' ? (
                    <Select aria-label={t('tech.assignTo')} value={s.technician_id ?? ''} onChange={(e) => void run(() => rpc('reassign_step', { p_step: s.id, p_tech: e.target.value || null }))} className="h-7 w-36 text-xs">
                      <option value="">{t('tech.unassigned')}</option>
                      {data.techs.map((x) => (
                        <option key={x.id} value={x.id}>
                          {x.full_name}
                        </option>
                      ))}
                    </Select>
                  ) : (
                    techName(s.technician_id)
                  )}
                </span>
                {(s.started_at || s.finished_at) && (
                  <span className="w-full text-2xs text-fg-3">
                    {s.started_at && f.dateTime(s.started_at)}
                    {s.finished_at && ` → ${f.dateTime(s.finished_at)}`}
                  </span>
                )}
              </li>
            ))}
          </ol>
        )}
      </div>
    </Panel>
  );
}
