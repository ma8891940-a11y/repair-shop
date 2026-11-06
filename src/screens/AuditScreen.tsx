import { useState } from 'react';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { useLoad, must } from '../app/useLoad';
import { PageHeader } from '../app/AppShell';
import { supabase } from '../lib/supabase';
import { diffChanges } from '../lib/audit';
import { cairoDayEnd, cairoDayStart } from '../lib/dates';
import { isStatus } from '../lib/status';
import type { Profile } from '../lib/types';
import { useFormat } from '../i18n/format';
import { Panel } from '../ui/Panel';
import { Input, Select } from '../ui/Field';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';

interface AuditRow {
  id: string;
  actor_id: string | null;
  action: string;
  entity: string;
  entity_id: string | null;
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  created_at: string;
}

const ENTITIES = ['devices', 'device_costs', 'customers', 'device_notes', 'device_photos', 'device_passcodes', 'profiles', 'staff_invites', 'shops'];
const MONEY = new Set(['estimated_cost', 'final_cost']);

/** سجل النشاط: قراءة بس لصاحب المحل. مفيش أي زرار تعديل أو حذف. */
export function AuditScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const [actor, setActor] = useState('');
  const [entity, setEntity] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');

  const users = useLoad(async () => must(await supabase.from('profiles').select('id, full_name, shop_id, email, role, deleted_at')) as Profile[], []);
  const { data, error, loading, reload } = useLoad(async () => {
    let q = supabase.from('audit_log').select('id, actor_id, action, entity, entity_id, before, after, created_at').order('created_at', { ascending: false }).limit(300);
    if (actor) q = q.eq('actor_id', actor);
    if (entity) q = q.eq('entity', entity);
    if (from) q = q.gte('created_at', cairoDayStart(from).toISOString());
    if (to) q = q.lt('created_at', cairoDayEnd(to).toISOString());
    return must(await q) as AuditRow[];
  }, [actor, entity, from, to]);

  const names = Object.fromEntries((users.data ?? []).map((u) => [u.id, u.full_name]));
  const show = (field: string, v: unknown): string => {
    if (v === null || v === undefined || v === '') return t('common.none');
    if (MONEY.has(field) && typeof v === 'number') return `${f.money(v)} ${f.currency()}`;
    if (field === 'status' && isStatus(v)) return t(`status.${v}`);
    if (field === 'role' && typeof v === 'string') return t(`roles.${v}`, { defaultValue: v });
    if (field.endsWith('_at') && typeof v === 'string') return f.dateTime(v);
    if (Array.isArray(v)) return v.map((x) => t(`intake.acc.${x}`, { defaultValue: t(`payments.${x}`, { defaultValue: String(x) }) })).join(t('common.sep'));
    if (typeof v === 'object') return JSON.stringify(v);
    return String(v);
  };

  return (
    <div>
      <PageHeader title={t('audit.title')} sub={t('audit.sub')} />
      <Panel className="mb-3 grid gap-2 p-3 sm:grid-cols-4">
        <Select value={actor} onChange={(e) => setActor(e.target.value)} aria-label={t('audit.user')}>
          <option value="">{t('audit.allUsers')}</option>
          {(users.data ?? []).map((u) => (
            <option key={u.id} value={u.id}>
              {u.full_name}
            </option>
          ))}
        </Select>
        <Select value={entity} onChange={(e) => setEntity(e.target.value)} aria-label={t('audit.entity')}>
          <option value="">{t('audit.allEntities')}</option>
          {ENTITIES.map((k) => (
            <option key={k} value={k}>
              {t(`audit.entities.${k}`)}
            </option>
          ))}
        </Select>
        <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} aria-label={t('audit.from')} />
        <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} aria-label={t('audit.to')} />
      </Panel>
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading ? (
        <Panel className="flex flex-col gap-2 p-3">
          {[0, 1, 2, 3, 4].map((k) => (
            <Skeleton key={k} className="h-12 w-full" />
          ))}
        </Panel>
      ) : data!.length === 0 ? (
        <Panel>
          <EmptyState line="receipt" title={t('audit.empty')} />
        </Panel>
      ) : (
        <Panel className="overflow-hidden">
          <ol className="divide-y divide-glass-border">
            {data!.map((r, i) => {
              const changes = r.action === 'update' || r.action === 'soft_delete' ? diffChanges(r.before, r.after) : [];
              const order = typeof r.after?.order_no === 'string' ? r.after.order_no : null;
              return (
                <motion.li key={r.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: Math.min(i, 20) * 0.015 }} className="grid gap-1 px-4 py-3 text-sm sm:grid-cols-[150px_140px_minmax(0,1fr)] sm:gap-4">
                  <div className="num text-xs text-fg-3">{f.dateTime(r.created_at)}</div>
                  <div className="truncate text-fg-2">{r.actor_id ? (names[r.actor_id] ?? t('common.none')) : t('audit.system')}</div>
                  <div className="min-w-0">
                    <div className="text-fg">
                      <span className="font-medium">{t(`audit.actions.${r.action}`, { defaultValue: r.action })}</span> · {t(`audit.entities.${r.entity}`, { defaultValue: r.entity })}
                      {order && (
                        <span className="num ms-2 text-xs text-fg-3" dir="ltr">
                          {order}
                        </span>
                      )}
                    </div>
                    {changes.length > 0 && (
                      <ul className="mt-1 flex flex-col gap-0.5 text-xs">
                        {changes.map((c) => (
                          <li key={c.field} className="text-fg-3">
                            <span className="text-fg-2">{t(`audit.fields.${c.field}`, { defaultValue: c.field })}</span>: <span className="text-danger line-through decoration-1">{show(c.field, c.before)}</span>{' '}
                            <span aria-hidden className="inline-block rtl:-scale-x-100">→</span> <span className="text-ok">{show(c.field, c.after)}</span>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                </motion.li>
              );
            })}
          </ol>
        </Panel>
      )}
    </div>
  );
}
