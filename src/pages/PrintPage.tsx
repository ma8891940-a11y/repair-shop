import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router';
import { supabase } from '../lib/supabase';
import { formatDateTime } from '../lib/dates';
import { formatEGP } from '../lib/money';
import { arabicError } from '../lib/errors';
import type { Customer, Device, DeviceCost } from '../lib/types';
import { useMe } from '../auth/AuthContext';

/**
 * صفحة الطباعة:
 *  receipt = إيصال استلام على الطابعة الحرارية 80مم
 *  invoice = فاتورة على ورق A4
 */
export function PrintPage() {
  const { kind = 'receipt', id = '' } = useParams();
  const { shop } = useMe();
  const navigate = useNavigate();
  const [device, setDevice] = useState<Device | null>(null);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [cost, setCost] = useState<DeviceCost | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      const { data: d, error } = await supabase.from('devices').select('*').eq('id', id).maybeSingle();
      if (error || !d) return setError(error ? arabicError(error) : 'الجهاز مش موجود');
      const [c, k] = await Promise.all([
        supabase.from('customers').select('id, name, phone, area').eq('id', d.customer_id).maybeSingle(),
        supabase.from('device_costs').select('id, device_id, estimated_cost, final_cost').eq('device_id', id).maybeSingle(),
      ]);
      setDevice(d as Device);
      setCustomer((c.data as Customer) ?? null);
      setCost((k.data as DeviceCost) ?? null);
    })();
  }, [id]);

  useEffect(() => {
    if (device) {
      const t = setTimeout(() => window.print(), 300);
      return () => clearTimeout(t);
    }
  }, [device]);

  if (error) return <div className="alert error">{error}</div>;
  if (!device) return <p>جاري التحميل...</p>;

  const isReceipt = kind !== 'invoice';
  const terms = shop.receipt_terms.split('\n').map((s) => s.trim()).filter(Boolean);

  return (
    <div className={isReceipt ? 'print-receipt' : 'print-invoice'}>
      <style>{isReceipt ? '@page { size: 80mm auto; margin: 3mm; }' : '@page { size: A4; margin: 15mm; }'}</style>
      <div className="no-print print-bar">
        <button className="primary" onClick={() => window.print()}>
          طباعة
        </button>
        <button onClick={() => navigate(-1)}>رجوع</button>
        <span className="muted small">
          {isReceipt ? 'اختار الطابعة الحرارية، والمقاس 80mm، والهوامش "بلا"' : 'اختار الطابعة العادية والورق A4'}
        </span>
      </div>

      <header className="p-head">
        <div className="p-shop">{shop.name}</div>
        {(shop.phone || shop.address) && (
          <div className="p-sub">
            {shop.address} {shop.phone && <span dir="ltr">{shop.phone}</span>}
          </div>
        )}
        <div className="p-title">{isReceipt ? 'إيصال استلام جهاز' : 'فاتورة صيانة'}</div>
        <div className="p-order" dir="ltr">
          {device.order_no}
        </div>
      </header>

      <table className="p-table">
        <tbody>
          <tr>
            <th>التاريخ</th>
            <td>{formatDateTime(isReceipt ? device.received_at : (device.delivered_at ?? new Date()))}</td>
          </tr>
          {customer && (
            <>
              <tr>
                <th>العميل</th>
                <td>{customer.name}</td>
              </tr>
              <tr>
                <th>الموبايل</th>
                <td dir="ltr">{customer.phone}</td>
              </tr>
            </>
          )}
          <tr>
            <th>الجهاز</th>
            <td>
              {device.brand} {device.model} {device.color && `— ${device.color}`}
            </td>
          </tr>
          {device.imei && (
            <tr>
              <th>IMEI</th>
              <td dir="ltr">{device.imei}</td>
            </tr>
          )}
          <tr>
            <th>العطل</th>
            <td className="pre">{device.issue}</td>
          </tr>
          {isReceipt && (
            <>
              <tr>
                <th>الملحقات</th>
                <td>{device.accessories.length ? device.accessories.join('، ') : 'بدون'}</td>
              </tr>
              <tr>
                <th>الحالة الشكلية</th>
                <td className="pre">{device.cosmetic_condition || '—'}</td>
              </tr>
              <tr>
                <th>التكلفة التقديرية</th>
                <td>{cost?.estimated_cost != null ? formatEGP(cost.estimated_cost) : 'بعد الفحص'}</td>
              </tr>
            </>
          )}
          {!isReceipt && (
            <>
              <tr className="p-total">
                <th>الإجمالي</th>
                <td>{cost?.final_cost != null ? formatEGP(cost.final_cost) : '—'}</td>
              </tr>
              <tr>
                <th>الضمان</th>
                <td>{shop.warranty_days > 0 ? `${shop.warranty_days} يوم على نفس العطل` : 'بدون ضمان'}</td>
              </tr>
            </>
          )}
        </tbody>
      </table>

      {isReceipt && terms.length > 0 && (
        <section className="p-terms">
          <b>شروط الاستلام</b>
          <ol>
            {terms.map((t, i) => (
              <li key={i}>{t}</li>
            ))}
          </ol>
        </section>
      )}

      <footer className="p-foot">
        <div className="p-sign">توقيع العميل: ..............................</div>
        <div className="muted">شكرًا لتعاملكم معنا</div>
      </footer>
    </div>
  );
}
