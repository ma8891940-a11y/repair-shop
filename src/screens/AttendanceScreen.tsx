import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Pencil, Plus, Trash2 } from 'lucide-react';
import { PageHeader } from '../app/AppShell';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
import { usePerms } from '../app/perms';
import { useLoad, must } from '../app/useLoad';
import { rpc } from '../app/ledgerApi';
import { PeriodFilter, usePeriod } from '../app/finance/PeriodFilter';
import { ExportMenu } from '../app/exporting';
import { ATT_CHANGED, AttendanceButton } from '../app/AttendanceButton';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { hm, totalsByPerson, type AttendanceRow } from '../lib/attendance';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Field, Input, Select, Textarea } from '../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';

/** datetime-local (وقت الجهاز) ← ISO */
const toIso = (v: string) => (v ? new Date(v).toISOString() : '');
/** ISO ← datetime-local بوقت الجهاز */
const toLocal = (iso: string | null) => {
  if (!iso) return '';
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};

/**
 * R2: الحضور والانصراف. كل واحد بيشوف حضوره، وصاحب المحل (أو اللي معاه "الفريق ← يشوف") بيشوف الكل في فروعه.
 * صاحب المحل بس بيصلّح ويضيف ويلغي (بسبب). الدقايق والتأخير من قاعدة البيانات.
 */
export function AttendanceScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop, refresh } = useMe();
  const owner = profile.role === 'owner';
  const { grant } = usePerms();
  const team = owner || grant('staff', 'view');
  const br = useBranch();
  const { period, range, set } = usePeriod();
  const toast = useToast();
  const args = { p_from: range.from.toISOString(), p_to: range.to.toISOString() };
  const mine = useLoad(async () => (await rpc('my_attendance', args)) as AttendanceRow[], [args.p_from, args.p_to]);
  const all = useLoad(async () => (team ? ((await rpc('attendance_report', { ...args, p_branch: br.filter ?? null })) as AttendanceRow[]) : null), [team, args.p_from, args.p_to, br.filter]);
  const staff = useLoad(async () => (owner ? (must(await supabase.from('profiles').select('id, full_name').is('deleted_at', null).order('full_name')) as { id: string; full_name: string }[]) : []), [owner]);
  const [edit, setEdit] = useState<{ mode: 'fix' | 'add' | 'void'; row?: AttendanceRow } | null>(null);

  const dur = (m: number | null) => {
    const x = hm(m);
    return x ? t('att.hm', { h: f.number(x.h), m: f.number(x.m) }) : t('att.open');
  };
  const reloadAll = () => {
    mine.reload();
    all.reload();
  };
  useEffect(() => {
    window.addEventListener(ATT_CHANGED, reloadAll);
    return () => window.removeEventListener(ATT_CHANGED, reloadAll);
  });
  const periodLine = `${f.date(range.from)} - ${f.date(new Date(range.to.getTime() - 1))}`;
  const totals = all.data ? totalsByPerson(all.data) : [];

  const rowsTable = (rows: AttendanceRow[], withName: boolean, testid: string) => (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] text-sm [&_td]:px-3 [&_td]:py-2 [&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium" data-testid={testid}>
        <thead className="text-2xs text-fg-3">
          <tr>
            {withName && <th>{t('att.person')}</th>}
            <th>{t('att.in')}</th>
            <th>{t('att.out')}</th>
            <th>{t('att.duration')}</th>
            <th>{t('att.late')}</th>
            {withName && br.multi && <th>{t('branch.switcher')}</th>}
            {owner && withName && <th className="w-0" />}
          </tr>
        </thead>
        <tbody className="divide-y divide-line">
          {rows.map((r) => (
            <tr key={r.id} data-testid="att-row">
              {withName && (
                <td>
                  <bdi>{r.full_name}</bdi>
                </td>
              )}
              <td className="num whitespace-nowrap">{f.dateTime(r.clock_in)}</td>
              <td className="num whitespace-nowrap">{r.clock_out ? f.dateTime(r.clock_out) : '—'}</td>
              <td className="num" data-testid="att-minutes">
                {dur(r.minutes)}
              </td>
              <td className="num">{r.late_minutes > 0 ? t('att.lateMin', { n: f.number(r.late_minutes) }) : '—'}</td>
              {withName && br.multi && <td>{br.name(r.branch_id)}</td>}
              {owner && withName && (
                <td className="whitespace-nowrap">
                  <button type="button" onClick={() => setEdit({ mode: 'fix', row: r })} className="inline-grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-raised hover:text-fg" aria-label={t('att.fix')} title={t('att.fix')} data-testid="att-fix">
                    <Pencil className="size-3.5" />
                  </button>
                  <button type="button" onClick={() => setEdit({ mode: 'void', row: r })} className="inline-grid size-7 place-items-center rounded-sm text-fg-3 hover:bg-danger-soft hover:text-danger" aria-label={t('att.void')} title={t('att.void')} data-testid="att-void">
                    <Trash2 className="size-3.5" />
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );

  return (
    <div data-testid="attendance-screen">
      <PageHeader title={t('att.title')} sub={t('att.sub')} actions={<AttendanceButton />} />
      <div className="mb-4">
        <PeriodFilter value={period} onChange={set} />
      </div>
      <div className="flex flex-col gap-4">
        <Panel data-testid="att-mine">
          <PanelHeader title={t('att.mine')} />
          {mine.error ? (
            <ErrorState message={mine.error} onRetry={mine.reload} />
          ) : !mine.data ? (
            <Skeleton className="m-4 h-24" />
          ) : mine.data.length === 0 ? (
            <EmptyState line="chip" title={t('att.emptyMine')} />
          ) : (
            rowsTable(mine.data, false, 'att-mine-table')
          )}
        </Panel>

        {team && (
          <Panel data-testid="att-team">
            <PanelHeader
              title={t('att.team')}
              actions={
                <div className="flex items-center gap-2">
                  {owner && (
                    <Button size="sm" icon={<Plus className="size-4" />} onClick={() => setEdit({ mode: 'add' })} data-testid="att-add">
                      {t('att.add')}
                    </Button>
                  )}
                  <ExportMenu
                    testid="att-export"
                    disabled={!all.data?.length}
                    table={() => ({
                      title: t('att.team'),
                      meta: [shop.name, periodLine],
                      file: 'attendance',
                      columns: [{ header: t('att.person') }, { header: t('att.days'), type: 'int', total: true }, { header: t('att.minutes'), type: 'int', total: true }, { header: t('att.lateTotal'), type: 'int', total: true }],
                      rows: totals.map((x) => [x.full_name, x.days, x.minutes, x.late_minutes]),
                    })}
                  />
                </div>
              }
            />
            {all.error ? (
              <ErrorState message={all.error} onRetry={all.reload} />
            ) : !all.data ? (
              <Skeleton className="m-4 h-32" />
            ) : all.data.length === 0 ? (
              <EmptyState line="chip" title={t('att.emptyTeam')} />
            ) : (
              <>
                <div className="overflow-x-auto border-b border-line">
                  <table className="w-full min-w-[520px] text-sm [&_td]:px-3 [&_td]:py-2 [&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium" data-testid="att-totals">
                    <thead className="text-2xs text-fg-3">
                      <tr>
                        <th>{t('att.person')}</th>
                        <th>{t('att.days')}</th>
                        <th>{t('att.duration')}</th>
                        <th>{t('att.lateTotal')}</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-line">
                      {totals.map((x) => (
                        <tr key={x.profile_id} data-testid="att-total">
                          <td>
                            <bdi>{x.full_name}</bdi>
                            {x.open > 0 && <span className="ms-2 text-2xs text-accent">{t('att.openN', { n: f.number(x.open) })}</span>}
                          </td>
                          <td className="num">{f.number(x.days)}</td>
                          <td className="num">{dur(x.minutes)}</td>
                          <td className="num">{x.late_minutes > 0 ? t('att.lateMin', { n: f.number(x.late_minutes) }) : '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {rowsTable(all.data, true, 'att-team-table')}
              </>
            )}
          </Panel>
        )}

        {owner && <StartTimePanel extras={shop.extras} shopId={shop.id} onSaved={refresh} />}
      </div>

      {edit && (
        <EditDialog
          mode={edit.mode}
          row={edit.row}
          staff={staff.data ?? []}
          onClose={() => setEdit(null)}
          onDone={() => {
            setEdit(null);
            toast({ tone: 'ok', title: t('settings.saved') });
            reloadAll();
          }}
        />
      )}
    </div>
  );
}

function EditDialog({ mode, row, staff, onClose, onDone }: { mode: 'fix' | 'add' | 'void'; row?: AttendanceRow; staff: { id: string; full_name: string }[]; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const [person, setPerson] = useState(row?.profile_id ?? '');
  const [inAt, setInAt] = useState(toLocal(row?.clock_in ?? null));
  const [outAt, setOutAt] = useState(toLocal(row?.clock_out ?? null));
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  async function submit() {
    setErr(null);
    if (!reason.trim()) return setErr(t('att.needReason'));
    setBusy(true);
    const r =
      mode === 'void'
        ? await supabase.rpc('attendance_void', { p_id: row!.id, p_reason: reason })
        : mode === 'fix'
          ? await supabase.rpc('attendance_fix', { p_id: row!.id, p_in: toIso(inAt), p_out: outAt ? toIso(outAt) : null, p_reason: reason })
          : await supabase.rpc('attendance_add', { p_id: crypto.randomUUID(), p_profile: person, p_in: toIso(inAt), p_out: toIso(outAt), p_reason: reason });
    setBusy(false);
    if (r.error) return setErr(errorMessage(r.error));
    onDone();
  }
  return (
    <Dialog
      open
      onOpenChange={(v) => !v && onClose()}
      title={t(mode === 'void' ? 'att.void' : mode === 'fix' ? 'att.fix' : 'att.add')}
      description={row ? row.full_name : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant={mode === 'void' ? 'danger' : 'primary'} loading={busy} onClick={() => void submit()} needsNet data-testid="att-save">
            {t(mode === 'void' ? 'att.void' : 'common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {mode === 'add' && (
          <Field label={t('att.person')} required>
            <Select value={person} onChange={(e) => setPerson(e.target.value)} data-testid="att-person">
              <option value="">{t('att.pick')}</option>
              {staff.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.full_name}
                </option>
              ))}
            </Select>
          </Field>
        )}
        {mode !== 'void' && (
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <Field label={t('att.in')} required>
              <Input type="datetime-local" value={inAt} onChange={(e) => setInAt(e.target.value)} data-testid="att-in" />
            </Field>
            <Field label={t('att.out')} required={mode === 'add'}>
              <Input type="datetime-local" value={outAt} onChange={(e) => setOutAt(e.target.value)} data-testid="att-out" />
            </Field>
          </div>
        )}
        <Field label={t('att.reason')} required>
          <Textarea rows={2} maxLength={300} value={reason} onChange={(e) => setReason(e.target.value)} data-testid="att-reason" />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** ميعاد بداية الشغل والسماح (للتأخير في التقرير بس) */
function StartTimePanel({ extras, shopId, onSaved }: { extras: unknown; shopId: string; onSaved: () => Promise<void> | void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const raw = (extras && typeof extras === 'object' ? extras : {}) as Record<string, unknown>;
  const cur = (raw.attendance && typeof raw.attendance === 'object' ? raw.attendance : {}) as { start?: string; grace_min?: number };
  const [start, setStart] = useState(cur.start ?? '');
  const [grace, setGrace] = useState(String(cur.grace_min ?? 15));
  async function save() {
    const g = Math.min(Math.max(Math.trunc(Number(grace)) || 0, 0), 120);
    const { error } = await supabase
      .from('shops')
      .update({ extras: { ...raw, attendance: { start: start || null, grace_min: g } } })
      .eq('id', shopId);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await onSaved();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  return (
    <Panel data-testid="att-settings">
      <PanelHeader title={t('att.settings')} />
      <div className="flex flex-wrap items-end gap-3 p-4">
        <Field label={t('att.start')} hint={t('att.startHint')}>
          <Input type="time" value={start} onChange={(e) => setStart(e.target.value)} className="w-32" data-testid="att-start" />
        </Field>
        <Field label={t('att.grace')}>
          <Input mono inputMode="numeric" value={grace} onChange={(e) => setGrace(e.target.value)} className="w-24" suffix={t('att.minShort')} data-testid="att-grace" />
        </Field>
        <Button variant="primary" onClick={() => void save()} needsNet className="mb-5" data-testid="att-settings-save">
          {t('common.save')}
        </Button>
      </div>
    </Panel>
  );
}
