import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ArrowDown, ArrowUp, Plus, Trash2 } from 'lucide-react';
import { useLoad, must } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { useRouteName, useSpecName } from '../../app/tech/names';
import { toLatinDigits } from '../../lib/digits';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Checkbox } from '../../ui/Checkbox';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

interface Spec {
  id: string;
  code: string | null;
  name: string | null;
}
interface Route {
  id: string;
  code: string | null;
  name: string | null;
  keywords: string[];
  steps: string[];
  diagnose: boolean;
  sort: number;
  warranty_days: number | null;
}

type Thenable = PromiseLike<{ error: unknown }>;

/** الفنيين والمسارات (صاحب المحل): التخصصات، وتخصص كل فني، ومسار كل نوع عطل */
export function TechTab() {
  const { t } = useTranslation();
  const { shop } = useMe();
  const toast = useToast();
  const specName = useSpecName();
  const [err, setErr] = useState<string | null>(null);
  const [newSpec, setNewSpec] = useState('');
  const { data, loading, reload } = useLoad(async () => {
    const [sp, techs, ss, rt] = await Promise.all([
      supabase.from('specialties').select('id, code, name').is('deleted_at', null).order('created_at'),
      supabase.from('profiles').select('id, full_name').eq('role', 'technician').is('deleted_at', null).order('full_name'),
      supabase.from('staff_specialties').select('id, profile_id, specialty_id').is('deleted_at', null),
      supabase.from('routes').select('id, code, name, keywords, steps, diagnose, sort, warranty_days').is('deleted_at', null).order('sort'),
    ]);
    return { spec: must(sp) as Spec[], techs: must(techs) as { id: string; full_name: string }[], ss: must(ss) as { id: string; profile_id: string; specialty_id: string }[], routes: must(rt) as Route[] };
  }, []);

  async function run(fn: () => Thenable) {
    const { error } = await fn();
    if (error) return setErr(errorMessage(error));
    setErr(null);
    toast({ tone: 'ok', title: t('settings.saved') });
    reload();
  }
  async function toggle(tech: string, spec: string, on: boolean) {
    const ex = data?.ss.find((x) => x.profile_id === tech && x.specialty_id === spec);
    if (on && !ex) await run(() => supabase.from('staff_specialties').insert({ id: crypto.randomUUID(), shop_id: shop.id, profile_id: tech, specialty_id: spec }));
    if (!on && ex) await run(() => supabase.from('staff_specialties').update({ deleted_at: new Date().toISOString() }).eq('id', ex.id));
  }
  if (loading || !data) return <Skeleton className="h-48 w-full" />;
  return (
    <div className="flex flex-col gap-4">
      <Panel>
        <PanelHeader title={t('techSettings.staff')} />
        <div className="overflow-x-auto p-4">
          {data.techs.length === 0 ? (
            <p className="text-sm text-fg-3">{t('techSettings.noTechs')}</p>
          ) : (
            <table className="w-full min-w-[420px] text-sm">
              <thead className="text-2xs text-fg-3">
                <tr>
                  <th className="py-1 text-start font-medium">{t('roles.technician')}</th>
                  {data.spec.map((s) => (
                    <th key={s.id} className="py-1 text-start font-medium">
                      {specName(s)}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody className="divide-y divide-glass-border">
                {data.techs.map((tc) => (
                  <tr key={tc.id}>
                    <td className="py-2 text-fg">{tc.full_name}</td>
                    {data.spec.map((s) => (
                      <td key={s.id} className="py-2">
                        <Checkbox
                          checked={data.ss.some((x) => x.profile_id === tc.id && x.specialty_id === s.id)}
                          onChange={(v) => void toggle(tc.id, s.id, v)}
                          label={<span className="sr-only">{`${tc.full_name} ${specName(s)}`}</span>}
                        />
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          )}
          <p className="mt-2 text-2xs text-fg-3">{t('techSettings.generalHint')}</p>
          <div className="mt-3 flex items-end gap-2">
            <Field label={t('techSettings.newSpec')} className="flex-1">
              <Input value={newSpec} onChange={(e) => setNewSpec(e.target.value)} maxLength={60} />
            </Field>
            <Button
              icon={<Plus className="size-4" />}
              onClick={() => {
                if (!newSpec.trim()) return;
                void run(() => supabase.from('specialties').insert({ id: crypto.randomUUID(), shop_id: shop.id, name: newSpec.trim() })).then(() => setNewSpec(''));
              }}
            >
              {t('ledgerSettings.add')}
            </Button>
          </div>
        </div>
      </Panel>
      <Panel>
        <PanelHeader title={t('techSettings.routes')} />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('techSettings.routesHint')}</p>
          {data.routes.map((r) => (
            <RouteEditor key={r.id} route={r} specs={data.spec} onSaved={reload} />
          ))}
          <RouteEditor route={null} specs={data.spec} onSaved={reload} />
        </div>
      </Panel>
      {err && <Alert tone="danger">{err}</Alert>}
    </div>
  );
}

function RouteEditor({ route, specs, onSaved }: { route: Route | null; specs: Spec[]; onSaved: () => void }) {
  const { t } = useTranslation();
  const { shop } = useMe();
  const toast = useToast();
  const specName = useSpecName();
  const routeName = useRouteName();
  const [name, setName] = useState('');
  const [keywords, setKeywords] = useState('');
  const [warranty, setWarranty] = useState('');
  const [steps, setSteps] = useState<string[]>([]);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setName(route ? routeName(route) : '');
    setKeywords(route ? route.keywords.join(t('common.sep')) : '');
    setWarranty(route?.warranty_days != null ? String(route.warranty_days) : '');
    setSteps(route ? route.steps : specs[0] ? [specs[0].id] : []);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [route?.id, specs.length]);
  const move = (i: number, d: number) => setSteps((s) => {
    const j = i + d;
    if (j < 0 || j >= s.length) return s;
    const c = [...s];
    [c[i], c[j]] = [c[j], c[i]];
    return c;
  });
  async function save() {
    if (!name.trim() || steps.length === 0) return setErr(t('techSettings.errRoute'));
    const kw = keywords.split(/[,\u060C\n]/).map((x) => x.trim()).filter(Boolean);
    // مدة ضمان نوع العطل (فاضية = مدة ضمان المحل)
    const wTxt = toLatinDigits(warranty.trim());
    const warranty_days = wTxt === '' ? null : Number(wTxt);
    if (warranty_days !== null && (!Number.isInteger(warranty_days) || warranty_days < 0 || warranty_days > 3650)) return setErr(t('techSettings.errWarranty'));
    const body = { name: route?.code && name.trim() === routeName({ code: route.code, name: null }) ? null : name.trim(), keywords: kw, steps, warranty_days };
    const { error } = route
      ? await supabase.from('routes').update(body).eq('id', route.id)
      : await supabase.from('routes').insert({ id: crypto.randomUUID(), shop_id: shop.id, ...body, name: name.trim(), sort: 500 });
    if (error) return setErr(errorMessage(error));
    setErr(null);
    toast({ tone: 'ok', title: t('settings.saved') });
    if (!route) {
      setName('');
      setKeywords('');
    }
    onSaved();
  }
  return (
    <div className="rounded-md border border-glass-border p-3" data-testid="route-editor">
      <div className="grid gap-2 sm:grid-cols-2">
        <Field label={route ? t('techSettings.routeName') : t('techSettings.newRoute')}>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={80} />
        </Field>
        <Field label={t('techSettings.keywords')} hint={route?.diagnose ? t('techSettings.diagnoseHint') : t('techSettings.keywordsHint')}>
          <Input value={keywords} onChange={(e) => setKeywords(e.target.value)} disabled={route?.diagnose} />
        </Field>
        <Field label={t('techSettings.warranty')} hint={t('techSettings.warrantyHint', { n: shop.warranty_days })}>
          <Input dir="ltr" mono inputMode="numeric" value={warranty} onChange={(e) => setWarranty(e.target.value)} placeholder={String(shop.warranty_days)} suffix={t('techSettings.days')} className="w-28 text-start" />
        </Field>
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-1.5" role="group" aria-label={t('techSettings.steps')}>
        {steps.map((sid, i) => (
          <span key={i} className="inline-flex items-center gap-1 rounded-md border border-line bg-sunken/40 ps-2 text-xs">
            <span className="num text-fg-3">{i + 1}</span>
            <Select aria-label={`${t('techSettings.step')} ${i + 1}`} value={sid} onChange={(e) => setSteps((s) => s.map((x, j) => (j === i ? e.target.value : x)))} className="h-7 w-32 border-0 text-xs">
              {specs.map((s) => (
                <option key={s.id} value={s.id}>
                  {specName(s)}
                </option>
              ))}
            </Select>
            <button type="button" onClick={() => move(i, -1)} className="p-0.5 text-fg-3 hover:text-fg" aria-label={t('techSettings.up')}>
              <ArrowUp className="size-3 rtl:rotate-0" aria-hidden />
            </button>
            <button type="button" onClick={() => move(i, 1)} className="p-0.5 text-fg-3 hover:text-fg" aria-label={t('techSettings.down')}>
              <ArrowDown className="size-3" aria-hidden />
            </button>
            <button type="button" onClick={() => setSteps((s) => (s.length > 1 ? s.filter((_, j) => j !== i) : s))} className="p-0.5 pe-1.5 text-fg-3 hover:text-danger" aria-label={t('techSettings.removeStep')}>
              <Trash2 className="size-3" aria-hidden />
            </button>
          </span>
        ))}
        {steps.length < 8 && specs[0] && (
          <Button size="sm" variant="ghost" icon={<Plus className="size-3.5" />} onClick={() => setSteps((s) => [...s, specs[0].id])}>
            {t('techSettings.addStep')}
          </Button>
        )}
        <Button size="sm" className="ms-auto" onClick={() => void save()}>
          {route ? t('common.save') : t('ledgerSettings.add')}
        </Button>
      </div>
      {err && (
        <Alert tone="danger" className="mt-2">
          {err}
        </Alert>
      )}
    </div>
  );
}
