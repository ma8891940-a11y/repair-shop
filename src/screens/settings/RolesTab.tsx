import { useLayoutEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, ShieldCheck } from 'lucide-react';
import { opId, rpc } from '../../app/ledgerApi';
import { useLoad, must } from '../../app/useLoad';
import { PERMS_CHANGED } from '../../app/perms';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

export const SECTIONS = ['devices', 'intake', 'customers', 'technicians', 'inventory', 'sales', 'purchases', 'cashbox', 'expenses', 'finance', 'partners', 'reports', 'staff', 'settings', 'audit'] as const;
export const OPS = ['view', 'add', 'edit', 'delete', 'amounts', 'export'] as const;
export type PermMap = Record<string, string[]>;
export interface Role {
  id: string;
  name: string;
  preset: string | null;
  base: 'reception' | 'technician';
  perms: PermMap;
}

/** جدول الصلاحيات: الأقسام في الصفوف والعمليات في الأعمدة */
export function PermGrid({ value, onToggle, cell, testid }: {
  value: PermMap;
  onToggle: (section: string, op: string) => void;
  /** شكل مخصص للخانة (للاستثناءات) */
  cell?: (section: string, op: string) => { label: string; tone: 'on' | 'off' | 'allow' | 'deny' } | null;
  testid?: string;
}) {
  const { t } = useTranslation();
  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[620px] border-collapse text-sm" data-testid={testid}>
        <thead>
          <tr className="text-2xs text-fg-3 [&_th]:px-2 [&_th]:py-1.5 [&_th]:font-normal">
            <th className="text-start">{t('audit.fields.section')}</th>
            {OPS.map((o) => (
              <th key={o} className="text-center">
                {t(`perm.ops.${o}`)}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {SECTIONS.map((s) => (
            <tr key={s} className="border-t border-glass-border" data-testid="perm-row" data-section={s}>
              <th scope="row" className="px-2 py-1.5 text-start text-sm font-normal text-fg">
                {t(`perm.sections.${s}`)}
              </th>
              {OPS.map((o) => {
                const c = cell?.(s, o);
                const on = c ? c.tone === 'on' || c.tone === 'allow' : (value[s] ?? []).includes(o);
                return (
                  <td key={o} className="px-2 py-1 text-center">
                    <button
                      type="button"
                      role="checkbox"
                      aria-checked={on}
                      aria-label={`${t(`perm.sections.${s}`)}: ${t(`perm.ops.${o}`)}${c ? ` (${c.label})` : ''}`}
                      title={c?.label}
                      onClick={() => onToggle(s, o)}
                      className={cn(
                        'grid size-6 place-items-center rounded-sm border text-2xs transition-colors',
                        c?.tone === 'allow' ? 'border-ok bg-ok/15 text-ok' : c?.tone === 'deny' ? 'border-danger bg-danger-soft text-danger' : on ? 'border-accent bg-accent-soft text-accent' : 'border-line text-fg-3 hover:border-line-strong',
                      )}
                      data-testid={`perm-${s}-${o}`}
                    >
                      {on ? '✓' : c?.tone === 'deny' ? '×' : ''}
                    </button>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** الإعدادات ← الأدوار والصلاحيات (صاحب المحل بس) */
export function RolesTab() {
  const { t } = useTranslation();
  const toast = useToast();
  const { data, loading, reload } = useLoad(async () => must(await supabase.from('roles').select('id, name, preset, base, perms').is('deleted_at', null).order('created_at')) as Role[], []);
  const [sel, setSel] = useState<string | 'new' | null>(null);
  const roles = useMemo(() => data ?? [], [data]);
  const cur = sel === 'new' ? null : (roles.find((r) => r.id === sel) ?? roles[0] ?? null);
  const [name, setName] = useState('');
  const [base, setBase] = useState<'reception' | 'technician'>('reception');
  const [perms, setPerms] = useState<PermMap>({});
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useLayoutEffect(() => {
    setName(cur?.name ?? '');
    setBase(cur?.base ?? 'reception');
    setPerms(cur?.perms ?? {});
    setErr(null);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cur?.id, sel]);
  const toggle = (s: string, o: string) =>
    setPerms((p) => {
      const has = (p[s] ?? []).includes(o);
      const next = has ? (p[s] ?? []).filter((x) => x !== o) : [...(p[s] ?? []), o];
      const out = { ...p, [s]: next };
      if (!next.length) delete out[s];
      return out;
    });
  async function save() {
    setErr(null);
    setBusy(true);
    try {
      const rid = cur?.id ?? opId();
      await rpc('save_role', { p_id: rid, p_name: name, p_base: base, p_perms: perms });
      toast({ tone: 'ok', title: t('perm.saved') });
      await reload();
      setSel(rid);
      window.dispatchEvent(new Event(PERMS_CHANGED));
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function archive() {
    if (!cur) return;
    try {
      await rpc('archive_role', { p_id: cur.id });
      toast({ tone: 'ok', title: t('perm.archived') });
      setSel(null);
      await reload();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  return (
    <div className="flex flex-col gap-4" data-testid="roles-settings">
      <Panel>
        <PanelHeader
          index="01"
          title={t('perm.title')}
          actions={
            <Button size="sm" variant="primary" icon={<Plus className="size-4" />} needsNet onClick={() => setSel('new')} data-testid="role-new">
              {t('perm.newRole')}
            </Button>
          }
        />
        <div className="flex flex-col gap-3 p-4">
          <p className="text-xs text-fg-3">{t('perm.hint')}</p>
          <Alert tone="info">{t('perm.stage')}</Alert>
          <div className="flex flex-wrap gap-1.5" role="tablist" aria-label={t('perm.title')}>
            <span className="inline-flex h-8 items-center gap-1.5 rounded-md border border-glass-border px-3 text-xs text-fg-3">
              <ShieldCheck className="size-3.5" aria-hidden /> {t('perm.ownerAll')}
            </span>
            {loading && <Skeleton className="h-8 w-60" />}
            {roles.map((r) => (
              <button
                key={r.id}
                type="button"
                role="tab"
                aria-selected={cur?.id === r.id && sel !== 'new'}
                onClick={() => setSel(r.id)}
                className={cn('h-8 rounded-md border px-3 text-sm', cur?.id === r.id && sel !== 'new' ? 'border-accent bg-accent-soft text-fg' : 'border-glass-border text-fg-2 hover:text-fg')}
                data-testid="role-tab"
              >
                {r.name}
                {r.preset && <span className="ms-1.5 text-2xs text-fg-3">· {t('perm.preset')}</span>}
              </button>
            ))}
          </div>
        </div>
      </Panel>
      {(cur || sel === 'new') && (
        <Panel>
          <div className="grid gap-3 p-4 sm:grid-cols-2">
            <Field label={t('perm.roleName')} required>
              <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={60} data-testid="role-name" />
            </Field>
            <Field label={t('perm.base')} hint={t('perm.baseHint')}>
              <Select value={base} onChange={(e) => setBase(e.target.value as 'reception' | 'technician')} data-testid="role-base">
                <option value="reception">{t('perm.bases.reception')}</option>
                <option value="technician">{t('perm.bases.technician')}</option>
              </Select>
            </Field>
          </div>
          <div className="px-2 pb-2">
            <PermGrid value={perms} onToggle={toggle} testid="role-grid" />
          </div>
          {err && (
            <div className="px-4 pb-2">
              <Alert tone="danger">{err}</Alert>
            </div>
          )}
          <div className="flex justify-end gap-2 border-t border-glass-border px-4 py-3">
            {cur && !cur.preset && (
              <Button variant="ghost" className="me-auto text-fg-3 hover:text-danger" needsNet onClick={() => void archive()} data-testid="role-archive">
                {t('perm.archive')}
              </Button>
            )}
            <Button variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="role-save">
              {t('common.save')}
            </Button>
          </div>
        </Panel>
      )}
    </div>
  );
}
