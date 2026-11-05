import { useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';
import { useMe } from '../auth/AuthContext';

export function SettingsPage() {
  const { shop, refresh } = useMe();
  const [name, setName] = useState(shop.name);
  const [phone, setPhone] = useState(shop.phone ?? '');
  const [address, setAddress] = useState(shop.address ?? '');
  const [terms, setTerms] = useState(shop.receipt_terms);
  const [warranty, setWarranty] = useState(String(shop.warranty_days));
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function save(e: FormEvent) {
    e.preventDefault();
    const days = Number(warranty);
    if (!Number.isInteger(days) || days < 0 || days > 3650) {
      return setMsg({ ok: false, text: 'مدة الضمان لازم تكون عدد أيام صحيح' });
    }
    setBusy(true);
    const { error } = await supabase
      .from('shops')
      .update({ name: name.trim(), phone: phone.trim() || null, address: address.trim() || null, receipt_terms: terms, warranty_days: days })
      .eq('id', shop.id);
    setBusy(false);
    if (error) return setMsg({ ok: false, text: arabicError(error) });
    setMsg({ ok: true, text: 'اتحفظت الإعدادات' });
    await refresh();
  }

  return (
    <form className="form-page" onSubmit={save}>
      <h1>الإعدادات</h1>
      <section className="card">
        <h2>بيانات المحل (بتظهر على الإيصال والفاتورة)</h2>
        <label>
          اسم المحل
          <input required value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
        </label>
        <div className="row">
          <label className="grow">
            تليفون المحل
            <input dir="ltr" value={phone} onChange={(e) => setPhone(e.target.value)} />
          </label>
          <label className="grow">
            العنوان
            <input value={address} onChange={(e) => setAddress(e.target.value)} />
          </label>
        </div>
      </section>
      <section className="card">
        <h2>شروط الاستلام</h2>
        <p className="muted small">النص ده بيتطبع في آخر إيصال الاستلام. كل سطر شرط.</p>
        <textarea rows={6} value={terms} onChange={(e) => setTerms(e.target.value)} />
      </section>
      <section className="card">
        <h2>الضمان</h2>
        <label>
          مدة الضمان الافتراضية (أيام)
          <input type="number" min={0} max={3650} value={warranty} onChange={(e) => setWarranty(e.target.value)} />
        </label>
      </section>
      {msg && <div className={`alert ${msg.ok ? 'ok' : 'error'}`}>{msg.text}</div>}
      <div className="actions">
        <button type="submit" className="primary" disabled={busy}>
          حفظ
        </button>
      </div>
    </form>
  );
}
