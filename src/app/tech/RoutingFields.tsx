import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../../lib/supabase';
import { durationParts, toMinutes, type DurationUnit } from '../../lib/tech';
import { toLatinDigits } from '../../lib/digits';
import { useLoad, must } from '../useLoad';
import { useRouteName } from './names';
import { Field, Input, Select } from '../../ui/Field';
import { cn } from '../../ui/cn';

export interface Routing {
  routeId: string | null;
  priority: 'urgent' | 'normal';
  estMinutes: number | null;
  /** الموظف اختار المسار بإيده (ساعتها ما بيتحسبش تاني من الوصف وقت الحفظ) */
  manual?: boolean;
}
export interface RouteRow {
  id: string;
  code: string | null;
  name: string | null;
  diagnose: boolean;
  steps: string[];
}

export function useRoutes() {
  return useLoad(async () => must(await supabase.from('routes').select('id, code, name, diagnose, steps').is('deleted_at', null).order('sort')) as RouteRow[], []);
}

/**
 * الاستلام: الأولوية، ونوع العطل (المسار) بيتحدد لوحده من الوصف ويتعدّل، والمدة المتوقعة:
 * لو فيه 5 أجهزة مشابهة أو أكتر بتتقترح لوحدها، ولو أقل الموظف بيكتبها. والموظف يقدر يعدّل الاقتراح.
 */
export function RoutingFields({ issue, brand, value, onChange }: { issue: string; brand: string; value: Routing; onChange: (v: Routing) => void }) {
  const { t } = useTranslation();
  const routeName = useRouteName();
  const routes = useRoutes();
  const [manual, setManual] = useState(false); // الموظف اختار المسار بإيده
  const [suggested, setSuggested] = useState<{ n: number; minutes: number | null } | null>(null);
  const [amount, setAmount] = useState('');
  const [unit, setUnit] = useState<DurationUnit>('hour');
  const [touched, setTouched] = useState(false);

  // المسار من الوصف
  useEffect(() => {
    // الوصف لسه فاضي: ما نختارش "عطل غير معروف" بدري (المسار بيتحسب تاني من الوصف النهائي وقت الحفظ)
    if (manual || !issue.trim()) return;
    const tm = setTimeout(async () => {
      const { data } = await supabase.rpc('detect_route', { p_issue: issue });
      if (data && data !== value.routeId) onChange({ ...value, routeId: data as string });
    }, 250);
    return () => clearTimeout(tm);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [issue, manual]);

  // اقتراح المدة
  useEffect(() => {
    if (!value.routeId || !brand.trim()) return setSuggested(null);
    let off = false;
    void supabase.rpc('estimate_minutes', { p_brand: brand.trim(), p_route: value.routeId }).then(({ data }) => {
      if (off) return;
      const s = (data as { n: number; minutes: number | null } | null) ?? null;
      setSuggested(s);
      if (s?.minutes && !touched) {
        const p = durationParts(s.minutes);
        setAmount(String(p.value));
        setUnit(p.unit);
        onChange({ ...value, estMinutes: s.minutes });
      }
    });
    return () => {
      off = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value.routeId, brand]);

  const setDuration = (a: string, u: DurationUnit) => {
    setTouched(true);
    setAmount(a);
    setUnit(u);
    onChange({ ...value, estMinutes: toMinutes(Number(toLatinDigits(a.trim())), u) });
  };

  return (
    <div className="grid gap-3 sm:col-span-2 sm:grid-cols-3">
      <div className="flex flex-col gap-1.5">
        <span className="text-sm font-medium text-fg">{t('tech.priority')}</span>
        <div className="flex gap-1" role="radiogroup" aria-label={t('tech.priority')}>
          {(['normal', 'urgent'] as const).map((p) => (
            <button
              key={p}
              type="button"
              role="radio"
              aria-checked={value.priority === p}
              onClick={() => onChange({ ...value, priority: p })}
              className={cn('h-9 flex-1 rounded-md border text-sm', value.priority === p ? (p === 'urgent' ? 'border-danger bg-[color-mix(in_srgb,var(--danger)_14%,transparent)] text-fg' : 'border-accent bg-accent-soft text-fg') : 'border-line text-fg-3 hover:text-fg')}
            >
              {t(`tech.priorities.${p}`)}
            </button>
          ))}
        </div>
      </div>
      <Field label={t('tech.route')} hint={manual ? t('tech.routeManual') : t('tech.routeAuto')}>
        <Select
          value={value.routeId ?? ''}
          onChange={(e) => {
            setManual(true);
            onChange({ ...value, routeId: e.target.value || null, manual: true });
          }}
        >
          {(routes.data ?? []).map((r) => (
            <option key={r.id} value={r.id}>
              {routeName(r)}
            </option>
          ))}
        </Select>
      </Field>
      <Field label={t('tech.estimate')} hint={suggested?.minutes ? t('tech.estSuggested', { n: suggested.n }) : t('tech.estManual', { n: suggested?.n ?? 0 })}>
        <div className="flex gap-1.5">
          <Input dir="ltr" inputMode="numeric" mono value={amount} onChange={(e) => setDuration(e.target.value, unit)} placeholder="0" className="w-20 text-start" aria-label={t('tech.estimate')} />
          <Select value={unit} onChange={(e) => setDuration(amount, e.target.value as DurationUnit)} aria-label={t('tech.estUnit')}>
            {(['minute', 'hour', 'day'] as const).map((u) => (
              <option key={u} value={u}>
                {t(`tech.units.${u}`)}
              </option>
            ))}
          </Select>
        </div>
      </Field>
    </div>
  );
}
