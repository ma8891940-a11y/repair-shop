import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { supabase } from '../lib/supabase';
import { buildSearchFilter } from '../lib/search';
import { STATUSES, STATUS_LABELS, UNDER_REPAIR, isStatus } from '../lib/status';
import { isLate } from '../lib/dashboard';
import { cairoDay, formatDateTime } from '../lib/dates';
import { arabicError } from '../lib/errors';
import type { DeviceListRow } from '../lib/types';
import { StatusBadge } from '../components/StatusBadge';
import { useMe } from '../auth/AuthContext';

const FILTER_LABELS: Record<string, string> = {
  today: 'أجهزة اليوم',
  under_repair: 'تحت الصيانة',
  late: 'المتأخرة',
};

export function DevicesPage() {
  const { profile } = useMe();
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const status = params.get('status') ?? '';
  const filter = params.get('filter') ?? '';
  const [q, setQ] = useState(params.get('q') ?? '');
  const [rows, setRows] = useState<DeviceListRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const showCustomer = profile.role !== 'technician';

  useEffect(() => {
    if (params.get('focus')) searchRef.current?.focus();
  }, [params]);

  useEffect(() => {
    let active = true;
    const t = setTimeout(async () => {
      let query = supabase
        .from('devices_list')
        .select('*')
        .is('deleted_at', null)
        .order('received_at', { ascending: false })
        .limit(300);
      if (isStatus(status)) query = query.eq('status', status);
      if (filter === 'under_repair') query = query.in('status', [...UNDER_REPAIR]);
      if (filter === 'late') query = query.neq('status', 'delivered');
      const f = buildSearchFilter(q, ['order_no', 'imei', 'customer_name', 'customer_phone', 'model']);
      if (f) query = query.or(f);
      const { data, error } = await query;
      if (!active) return;
      if (error) return setError(arabicError(error));
      setError(null);
      let list = (data ?? []) as DeviceListRow[];
      const now = new Date();
      if (filter === 'late') list = list.filter((d) => isLate(d, now));
      if (filter === 'today') list = list.filter((d) => cairoDay(d.received_at) === cairoDay(now));
      setRows(list);
    }, 250);
    return () => {
      active = false;
      clearTimeout(t);
    };
  }, [q, status, filter]);

  function setParam(key: string, value: string) {
    const next = new URLSearchParams(params);
    if (value) next.set(key, value);
    else next.delete(key);
    next.delete('focus');
    setParams(next, { replace: true });
  }

  const now = new Date();
  return (
    <div>
      <div className="page-head">
        <h1>الأجهزة {filter && FILTER_LABELS[filter] ? `— ${FILTER_LABELS[filter]}` : ''}</h1>
        {profile.role !== 'technician' && (
          <Link className="button primary" to="/devices/new">
            + استلام جهاز
          </Link>
        )}
      </div>
      <div className="toolbar">
        <input
          ref={searchRef}
          className="grow"
          placeholder={showCustomer ? 'بحث برقم الطلب أو الموبايل أو الاسم أو IMEI' : 'بحث برقم الطلب أو IMEI أو الموديل'}
          value={q}
          onChange={(e) => setQ(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && rows && rows.length === 1) navigate(`/devices/${rows[0].id}`);
          }}
        />
        <select value={status} onChange={(e) => setParam('status', e.target.value)}>
          <option value="">كل الحالات</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {STATUS_LABELS[s]}
            </option>
          ))}
        </select>
        {filter && (
          <button onClick={() => setParam('filter', '')}>
            إلغاء فلتر "{FILTER_LABELS[filter] ?? filter}"
          </button>
        )}
      </div>
      {error && <div className="alert error">{error}</div>}
      {!rows ? (
        <p>جاري التحميل...</p>
      ) : rows.length === 0 ? (
        <p className="muted">مفيش أجهزة.</p>
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>رقم الطلب</th>
                {showCustomer && <th>العميل</th>}
                <th>الجهاز</th>
                <th>IMEI</th>
                <th>الحالة</th>
                <th>تاريخ الاستلام</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((d) => (
                <tr key={d.id} className={isLate(d, now) ? 'late' : ''} onClick={() => navigate(`/devices/${d.id}`)}>
                  <td>
                    <Link to={`/devices/${d.id}`}>
                      <b dir="ltr">{d.order_no}</b>
                    </Link>
                  </td>
                  {showCustomer && (
                    <td>
                      {d.customer_name}
                      <div className="muted small" dir="ltr">
                        {d.customer_phone}
                      </div>
                    </td>
                  )}
                  <td>
                    {d.brand} {d.model}
                  </td>
                  <td dir="ltr" className="mono">
                    {d.imei}
                  </td>
                  <td>
                    <StatusBadge status={d.status} />
                  </td>
                  <td className="small">{formatDateTime(d.received_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
