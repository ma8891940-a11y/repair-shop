import { useEffect, useState } from 'react';
import { clearDraft, loadDraft, saveDraft } from '../lib/draft';
import { Link, useLocation } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { Play, CheckCheck, Clock, AlertTriangle } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { useLoad, must } from '../app/useLoad';
import { useMe } from '../app/auth';
import { rpc } from '../app/ledgerApi';
import { useDuration, useRouteName, useSpecName } from '../app/tech/names';
import { useRoutes } from '../app/tech/RoutingFields';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import type { CheckItems } from '../lib/checks';
import type { DeviceStatus } from '../lib/status';
import { useFormat } from '../i18n/format';
import { Panel } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Field, Select } from '../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { StatusBadge } from '../ui/StatusBadge';
import { QuickCheck, CheckCompare } from '../ui/QuickCheck';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

interface QueueRow {
  step_id: string;
  device_id: string;
  order_no: string;
  brand: string;
  model: string;
  issue: string;
  priority: 'urgent' | 'normal' | 'warranty';
  status: DeviceStatus;
  received_at: string;
  est_minutes: number | null;
  step_no: number;
  steps_total: number;
  specialty_id: string;
  step_status: 'pending' | 'active';
  started_at: string | null;
  diagnose: boolean;
  late: boolean;
  is_return: boolean;
}

/** شغلي (الفني): أجهزتي بس، بالأولوية ثم الأقدم. "ابدأ" بيسجل البداية، و"خلّصت" بينقل الجهاز للخطوة الجاية */
export function WorkScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile } = useMe();
  const toast = useToast();
  const location = useLocation();
  const specName = useSpecName();
  const dur = useDuration();
  const [finalFor, setFinalFor] = useState<QueueRow | null>(null);
  const [routeFor, setRouteFor] = useState<QueueRow | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const { data, error, loading, reload } = useLoad(async () => {
    const [q, sp] = await Promise.all([rpc<QueueRow[]>('my_queue'), supabase.from('specialties').select('id, code, name')]);
    return { q, spec: new Map((must(sp) as { id: string; code: string | null; name: string | null }[]).map((x) => [x.id, x])) };
  }, []);
  useLiveRefresh(reload);

  async function nextName(id: string | null | undefined) {
    if (!id) return null;
    if (id === profile.id) return t('work.you');
    const { data: p } = await supabase.from('profiles').select('full_name').eq('id', id).maybeSingle();
    return (p?.full_name as string | undefined)?.split(' ')[0] ?? null;
  }
  async function start(r: QueueRow) {
    setBusy(r.step_id);
    try {
      await rpc('start_step', { p_step: r.step_id });
      toast({ tone: 'ok', title: t('work.started', { o: r.order_no }) });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(null);
    }
  }
  // "خلّصت": لو دي خطوة التشخيص (عطل غير معروف) بنسأل عن المسار، ولو آخر خطوة بنفتح الفحص النهائي على طول،
  // من غير ما نستنى رفض من السيرفر (اللي كان بيسيب خطأ في الـ console). الرفض لسه متعامل معاه تحت كاحتياط
  function done(r: QueueRow) {
    if (r.diagnose && r.step_no >= r.steps_total) return setRouteFor(r);
    if (!r.diagnose && r.step_no >= r.steps_total) return setFinalFor(r);
    void finish(r);
  }
  async function finish(r: QueueRow, check?: CheckItems, route?: string) {
    setBusy(r.step_id);
    try {
      const res = await rpc<{ next_step: string | null; next_tech?: string | null; ready: boolean }>('finish_step', { p_step: r.step_id, p_check: check ?? null, p_next_route: route ?? null });
      if (check) clearDraft(`final:${r.step_id}`);
      setFinalFor(null);
      setRouteFor(null);
      if (res.ready) toast({ tone: 'ok', title: t('work.ready', { o: r.order_no }) });
      else {
        const n = await nextName(res.next_tech);
        toast({ tone: 'ok', title: t('work.moved', { o: r.order_no }), description: n ? t('work.movedTo', { n }) : t('work.unassigned') });
      }
      reload();
    } catch (e) {
      const m = String((e as { message?: string }).message ?? '');
      if (/E_FINAL_CHECK_REQUIRED/.test(m)) setFinalFor(r);
      else if (/E_ROUTE_REQUIRED/.test(m)) setRouteFor(r);
      else toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="max-w-4xl">
      <PageHeader title={t('work.title')} sub={t('work.sub')} />
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading || !data ? (
        <div className="flex flex-col gap-2">
          {[0, 1, 2].map((k) => (
            <Skeleton key={k} className="h-24 w-full" />
          ))}
        </div>
      ) : data.q.length === 0 ? (
        <Panel>
          <EmptyState line="tool" title={t('work.empty')}>
            {t('work.emptyText')}
          </EmptyState>
        </Panel>
      ) : (
        <ul className="flex flex-col gap-2">
          {data.q.map((r, i) => (
            <motion.li key={r.step_id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18, delay: Math.min(i, 10) * 0.03 }}>
              <Panel className={cn('flex flex-wrap items-center gap-3 p-3', r.late && 'border-[color-mix(in_srgb,var(--danger)_45%,var(--glass-border))]')} data-testid="work-item">
                <div className="min-w-0 flex-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <Link to={`/devices/${r.device_id}`} state={{ bg: location }} className="num text-md font-semibold text-fg hover:text-accent" dir="ltr">
                      {r.order_no}
                    </Link>
                    <PriorityBadge p={r.priority} />
                    {r.is_return && <span className="text-2xs text-warn">{t('work.return')}</span>}
                    {r.late && (
                      <span className="inline-flex items-center gap-1 text-2xs text-danger">
                        <AlertTriangle className="size-3" aria-hidden /> {t('work.late')}
                      </span>
                    )}
                    <StatusBadge status={r.status} size="sm" />
                  </div>
                  <div className="mt-0.5 truncate text-sm text-fg">
                    {r.brand} {r.model} · <span className="text-fg-2">{r.issue}</span>
                  </div>
                  <div className="mt-0.5 flex flex-wrap gap-3 text-2xs text-fg-3">
                    <span>{t('work.step', { i: r.step_no, n: r.steps_total, s: specName(data.spec.get(r.specialty_id)) })}</span>
                    <span>{f.dateTime(r.received_at)}</span>
                    {r.est_minutes && (
                      <span className="inline-flex items-center gap-1">
                        <Clock className="size-3" aria-hidden /> {dur(r.est_minutes)}
                      </span>
                    )}
                  </div>
                </div>
                {r.step_status === 'pending' ? (
                  <Button size="sm" variant="primary" icon={<Play className="size-4" />} loading={busy === r.step_id} disabled={r.status === 'awaiting_approval'} onClick={() => void start(r)}>
                    {t('work.start')}
                  </Button>
                ) : (
                  <Button size="sm" variant="primary" icon={<CheckCheck className="size-4" />} loading={busy === r.step_id} disabled={r.status === 'awaiting_approval'} onClick={() => void done(r)}>
                    {t('work.finish')}
                  </Button>
                )}
                {r.status === 'awaiting_approval' && <p className="w-full text-2xs text-warn">{t('work.waitApproval')}</p>}
              </Panel>
            </motion.li>
          ))}
        </ul>
      )}
      <FinalCheckDialog row={finalFor} onOpenChange={(v) => !v && setFinalFor(null)} onSubmit={(c) => finalFor && void finish(finalFor, c)} busy={!!busy} />
      <RouteDialog row={routeFor} onOpenChange={(v) => !v && setRouteFor(null)} onSubmit={(rid) => routeFor && void finish(routeFor, undefined, rid)} busy={!!busy} />
    </div>
  );
}

export function PriorityBadge({ p }: { p: string }) {
  const { t } = useTranslation();
  if (p === 'normal') return null;
  return (
    <span className={cn('inline-flex h-5 items-center rounded-full border px-2 text-2xs font-medium', p === 'urgent' ? 'border-[color-mix(in_srgb,var(--danger)_45%,transparent)] text-danger' : 'border-[color-mix(in_srgb,var(--warn)_45%,transparent)] text-warn')}>
      {t(`tech.priorities.${p}`)}
    </span>
  );
}

/** الفحص النهائي قبل ما الجهاز يبقى جاهز: نفس قائمة الفحص السريع، ومقارنة بفحص الاستلام */
function FinalCheckDialog({ row, onOpenChange, onSubmit, busy }: { row: QueueRow | null; onOpenChange: (v: boolean) => void; onSubmit: (c: CheckItems) => void; busy: boolean }) {
  const { t } = useTranslation();
  const [items, setItemsRaw] = useState<CheckItems>({});
  // البند 9: الفحص النهائي بيتحفظ مسودة لكل جهاز، ولو النافذة اتقفلت بيرجع زي ما سبته
  const draftKey = row ? `final:${row.step_id}` : '';
  useEffect(() => {
    if (draftKey) setItemsRaw(loadDraft<CheckItems>(draftKey)?.value ?? {});
  }, [draftKey]);
  const setItems = (v: CheckItems) => {
    setItemsRaw(v);
    if (draftKey) saveDraft(draftKey, v);
  };
  const [err, setErr] = useState<string | null>(null);
  const intake = useLoad(async () => {
    if (!row) return null;
    setItems({});
    setErr(null);
    const { data } = await supabase.from('device_checks').select('items').eq('device_id', row.device_id).eq('stage', 'intake').maybeSingle();
    return (data?.items as CheckItems | undefined) ?? null;
  }, [row?.step_id]);
  return (
    <Dialog
      open={!!row}
      onOpenChange={onOpenChange}
      title={t('work.finalTitle')}
      description={row ? `${row.order_no} · ${row.brand} ${row.model}` : undefined}
      className="w-[min(94vw,560px)]"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button
            variant="primary"
            loading={busy}
            onClick={() => {
              if (Object.keys(items).length === 0) return setErr(t('work.finalEmpty'));
              onSubmit(items);
            }}
          >
            {t('work.finalSave')}
          </Button>
        </>
      }
    >
      <div className="flex max-h-[60vh] flex-col gap-3 overflow-y-auto">
        <p className="text-sm text-fg-2">{t('work.finalHint')}</p>
        <QuickCheck value={items} onChange={setItems} />
        {intake.data && Object.keys(items).length > 0 && <CheckCompare intake={intake.data} delivery={items} />}
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** عطل غير معروف: الفني بعد الفحص بيحدد المسار */
function RouteDialog({ row, onOpenChange, onSubmit, busy }: { row: QueueRow | null; onOpenChange: (v: boolean) => void; onSubmit: (routeId: string) => void; busy: boolean }) {
  const { t } = useTranslation();
  const routes = useRoutes();
  const routeName = useRouteName();
  const [rid, setRid] = useState('');
  const options = (routes.data ?? []).filter((r) => !r.diagnose);
  return (
    <Dialog
      open={!!row}
      onOpenChange={onOpenChange}
      title={t('work.routeTitle')}
      description={row ? `${row.order_no} · ${row.issue}` : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} disabled={!rid} onClick={() => onSubmit(rid)}>
            {t('work.routeSave')}
          </Button>
        </>
      }
    >
      <Field label={t('tech.route')}>
        <Select value={rid} onChange={(e) => setRid(e.target.value)}>
          <option value="">{t('fin.pick')}</option>
          {options.map((r) => (
            <option key={r.id} value={r.id}>
              {routeName(r)}
            </option>
          ))}
        </Select>
      </Field>
    </Dialog>
  );
}
