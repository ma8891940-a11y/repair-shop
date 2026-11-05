import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import { ACTION_LABELS, ENTITY_LABELS, diffChanges } from '../lib/audit';
import { cairoDayEnd, cairoDayStart, formatDateTime } from '../lib/dates';
import { arabicError } from '../lib/errors';
import { formatEGP } from '../lib/money';
import { STATUS_LABELS, isStatus } from '../lib/status';
import type { Profile } from '../lib/types';

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

const MONEY_FIELDS = new Set(['estimated_cost', 'final_cost']);

function show(field: string, v: unknown): string {
  if (v === null || v === undefined || v === '') return '—';
  if (MONEY_FIELDS.has(field) && typeof v === 'number') return formatEGP(v);
  if (field === 'status' && isStatus(v)) return STATUS_LABELS[v];
  if (Array.isArray(v)) return v.join('، ');
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
}

/** سجل النشاط: قراءة بس لصاحب المحل. مفيش أي زرار تعديل أو حذف. */
export function AuditPage() {
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [users, setUsers] = useState<Profile[]>([]);
  const [actor, setActor] = useState('');
  const [entity, setEntity] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    supabase
      .from('profiles')
      .select('id, full_name, shop_id, email, role, deleted_at')
      .then(({ data }) => setUsers((data ?? []) as Profile[]));
  }, []);

  useEffect(() => {
    let q = supabase
      .from('audit_log')
      .select('id, actor_id, action, entity, entity_id, before, after, created_at')
      .order('created_at', { ascending: false })
      .limit(300);
    if (actor) q = q.eq('actor_id', actor);
    if (entity) q = q.eq('entity', entity);
    // الأيام بتوقيت القاهرة (بيراعي التوقيت الصيفي)
    if (from) q = q.gte('created_at', cairoDayStart(from).toISOString());
    if (to) q = q.lt('created_at', cairoDayEnd(to).toISOString());
    q.then(({ data, error }) => {
      if (error) return setError(arabicError(error));
      setError(null);
      setRows((data ?? []) as AuditRow[]);
    });
  }, [actor, entity, from, to]);

  const names = Object.fromEntries(users.map((u) => [u.id, u.full_name]));

  return (
    <div>
      <h1>سجل النشاط</h1>
      <p className="muted small">كل عملية في البرنامج بتتسجّل هنا: مين، عمل إيه، إمتى، والقيمة قبل وبعد. السجل ده ما بيتعدلش ولا بيتحذف.</p>
      <div className="toolbar">
        <select value={actor} onChange={(e) => setActor(e.target.value)}>
          <option value="">كل المستخدمين</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {u.full_name}
            </option>
          ))}
        </select>
        <select value={entity} onChange={(e) => setEntity(e.target.value)}>
          <option value="">كل العمليات</option>
          {Object.entries(ENTITY_LABELS).map(([k, v]) => (
            <option key={k} value={k}>
              {v}
            </option>
          ))}
        </select>
        <label className="inline">
          من <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
        </label>
        <label className="inline">
          إلى <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
        </label>
      </div>
      {error && <div className="alert error">{error}</div>}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>الوقت</th>
              <th>المستخدم</th>
              <th>العملية</th>
              <th>التفاصيل</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const changes = r.action === 'update' || r.action === 'soft_delete' ? diffChanges(r.before, r.after) : [];
              return (
                <tr key={r.id}>
                  <td className="small">{formatDateTime(r.created_at)}</td>
                  <td>{r.actor_id ? (names[r.actor_id] ?? '—') : 'النظام'}</td>
                  <td>
                    {ACTION_LABELS[r.action] ?? r.action} {ENTITY_LABELS[r.entity] ?? r.entity}
                    {typeof r.after?.order_no === 'string' && (
                      <div className="small" dir="ltr">
                        {r.after.order_no}
                      </div>
                    )}
                  </td>
                  <td className="small">
                    {changes.length > 0 ? (
                      <ul className="changes">
                        {changes.map((c) => (
                          <li key={c.field}>
                            <code>{c.field}</code>: {show(c.field, c.before)} ← {show(c.field, c.after)}
                          </li>
                        ))}
                      </ul>
                    ) : null}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}
