import { useEffect, useState } from 'react';
import { Link } from 'react-router';
import { supabase } from '../lib/supabase';
import { isValidImei, normalizeImei } from '../lib/imei';
import { formatDateTime } from '../lib/dates';

interface Prev {
  id: string;
  order_no: string;
  received_at: string;
}

/** تنبيه لو نفس الـ IMEI دخل قبل كده في نفس المحل (RLS بتضمن إنه نفس المحل بس) */
export function ImeiWarning({ imei, excludeId }: { imei: string; excludeId?: string }) {
  const clean = normalizeImei(imei);
  const [prev, setPrev] = useState<Prev[]>([]);

  useEffect(() => {
    if (clean.length < 14) {
      setPrev([]);
      return;
    }
    let active = true;
    const t = setTimeout(async () => {
      let q = supabase
        .from('devices')
        .select('id, order_no, received_at')
        .eq('imei', clean)
        .is('deleted_at', null)
        .order('received_at', { ascending: false })
        .limit(10);
      if (excludeId) q = q.neq('id', excludeId);
      const { data } = await q;
      if (active) setPrev((data ?? []) as Prev[]);
    }, 300);
    return () => {
      active = false;
      clearTimeout(t);
    };
  }, [clean, excludeId]);

  return (
    <>
      {clean.length > 0 && !isValidImei(clean) && (
        <div className="alert warn small">رقم الـ IMEI شكله مش صحيح (لازم 15 رقم). اتأكد منه، وتقدر تكمّل عادي.</div>
      )}
      {prev.length > 0 && (
        <div className="alert warn">
          <b>تنبيه: الجهاز ده دخل المحل قبل كده ({prev.length} مرة)</b>
          <ul>
            {prev.map((p) => (
              <li key={p.id}>
                <Link to={`/devices/${p.id}`} target="_blank">
                  طلب <span dir="ltr">{p.order_no}</span>
                </Link>{' '}
                — {formatDateTime(p.received_at)}
              </li>
            ))}
          </ul>
        </div>
      )}
    </>
  );
}
