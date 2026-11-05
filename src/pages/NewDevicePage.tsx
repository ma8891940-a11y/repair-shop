import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router';
import { supabase } from '../lib/supabase';
import { normalizeEgyptPhone } from '../lib/phone';
import { normalizeImei } from '../lib/imei';
import { parsePounds } from '../lib/money';
import { arabicError } from '../lib/errors';
import { MAX_PHOTOS, uploadDevicePhoto } from '../lib/photos';
import type { Customer } from '../lib/types';
import { useMe } from '../auth/AuthContext';
import { ImeiWarning } from '../components/ImeiWarning';

const ACCESSORIES = ['شريحة', 'جراب', 'كارت ذاكرة', 'شاحن', 'سماعة', 'علبة'];
const BRANDS = ['Samsung', 'iPhone', 'Xiaomi', 'Oppo', 'Realme', 'Vivo', 'Infinix', 'Tecno', 'Huawei', 'Honor', 'Nokia'];

export function NewDevicePage() {
  const { profile } = useMe();
  const navigate = useNavigate();

  const [phone, setPhone] = useState('');
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [lookedUp, setLookedUp] = useState(false);
  const [custName, setCustName] = useState('');
  const [custArea, setCustArea] = useState('');

  const [brand, setBrand] = useState('');
  const [model, setModel] = useState('');
  const [imei, setImei] = useState('');
  const [color, setColor] = useState('');
  const [accessories, setAccessories] = useState<string[]>([]);
  const [otherAcc, setOtherAcc] = useState('');
  const [issue, setIssue] = useState('');
  const [condition, setCondition] = useState('');
  const [estimate, setEstimate] = useState('');
  const [photos, setPhotos] = useState<File[]>([]);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function lookup() {
    setError(null);
    const n = normalizeEgyptPhone(phone);
    if (!n) {
      setError('رقم الموبايل مش صحيح. لازم يكون 11 رقم ويبدأ بـ 010 أو 011 أو 012 أو 015');
      return;
    }
    setPhone(n);
    const { data, error } = await supabase
      .from('customers')
      .select('id, name, phone, area')
      .eq('phone', n)
      .is('deleted_at', null)
      .maybeSingle();
    if (error) return setError(arabicError(error));
    setCustomer((data as Customer) ?? null);
    setLookedUp(true);
  }

  function toggleAcc(a: string) {
    setAccessories((cur) => (cur.includes(a) ? cur.filter((x) => x !== a) : [...cur, a]));
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const n = normalizeEgyptPhone(phone);
    if (!n) return setError('اكتب رقم موبايل العميل الأول ودوس "بحث"');
    if (!lookedUp) return setError('دوس "بحث" عشان نشوف العميل متسجّل ولا لأ');
    if (!customer && !custName.trim()) return setError('اكتب اسم العميل');
    let estimated: number | null = null;
    if (estimate.trim()) {
      estimated = parsePounds(estimate);
      if (estimated === null) return setError('التكلفة التقديرية مش رقم صحيح (مثال: 350 أو 350.50)');
    }

    setBusy(true);
    try {
      let customerId = customer?.id;
      if (!customerId) {
        customerId = crypto.randomUUID();
        const { error } = await supabase.from('customers').insert({
          id: customerId,
          shop_id: profile.shop_id,
          name: custName.trim(),
          phone: n,
          area: custArea.trim() || null,
        });
        if (error) throw error;
      }
      const deviceId = crypto.randomUUID();
      const acc = [...accessories, ...otherAcc.split(/[،,]/).map((s) => s.trim()).filter(Boolean)];
      const { error: devErr } = await supabase.from('devices').insert({
        id: deviceId,
        shop_id: profile.shop_id,
        customer_id: customerId,
        brand: brand.trim(),
        model: model.trim(),
        imei: normalizeImei(imei) || null,
        color: color.trim() || null,
        accessories: acc,
        issue: issue.trim(),
        cosmetic_condition: condition.trim() || null,
      });
      if (devErr) throw devErr;
      const { error: costErr } = await supabase
        .from('device_costs')
        .insert({ shop_id: profile.shop_id, device_id: deviceId, estimated_cost: estimated });
      if (costErr) throw costErr;

      const failed: string[] = [];
      for (const f of photos.slice(0, MAX_PHOTOS)) {
        try {
          await uploadDevicePhoto(profile.shop_id, deviceId, f);
        } catch {
          failed.push(f.name);
        }
      }
      navigate(`/devices/${deviceId}?new=1${failed.length ? `&photoFail=${failed.length}` : ''}`);
    } catch (err) {
      setError(arabicError(err));
      setBusy(false);
    }
  }

  return (
    <form onSubmit={submit} className="form-page">
      <h1>استلام جهاز</h1>

      <section className="card">
        <h2>العميل</h2>
        <div className="row">
          <label className="grow">
            رقم الموبايل (واتساب)
            <input
              dir="ltr"
              inputMode="tel"
              required
              autoFocus
              value={phone}
              onChange={(e) => {
                setPhone(e.target.value);
                setLookedUp(false);
                setCustomer(null);
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  void lookup();
                }
              }}
              placeholder="01xxxxxxxxx"
            />
          </label>
          <button type="button" onClick={() => void lookup()}>
            بحث
          </button>
        </div>
        {lookedUp && customer && (
          <div className="alert ok">
            عميل متسجّل: <b>{customer.name}</b> {customer.area && `— ${customer.area}`}
          </div>
        )}
        {lookedUp && !customer && (
          <>
            <p className="muted small">عميل جديد. اكتب بياناته:</p>
            <div className="row">
              <label className="grow">
                الاسم
                <input required value={custName} onChange={(e) => setCustName(e.target.value)} maxLength={120} />
              </label>
              <label className="grow">
                المنطقة
                <input value={custArea} onChange={(e) => setCustArea(e.target.value)} />
              </label>
            </div>
          </>
        )}
      </section>

      <section className="card">
        <h2>الجهاز</h2>
        <div className="row">
          <label className="grow">
            النوع
            <input list="brands" required value={brand} onChange={(e) => setBrand(e.target.value)} maxLength={60} />
            <datalist id="brands">
              {BRANDS.map((b) => (
                <option key={b} value={b} />
              ))}
            </datalist>
          </label>
          <label className="grow">
            الموديل
            <input required value={model} onChange={(e) => setModel(e.target.value)} maxLength={80} />
          </label>
          <label className="grow">
            اللون
            <input value={color} onChange={(e) => setColor(e.target.value)} />
          </label>
        </div>
        <label>
          IMEI
          <input dir="ltr" inputMode="numeric" value={imei} onChange={(e) => setImei(e.target.value)} placeholder="اطلب *#06# من الجهاز" />
        </label>
        <ImeiWarning imei={imei} />
        <fieldset>
          <legend>الملحقات المستلمة</legend>
          <div className="checks">
            {ACCESSORIES.map((a) => (
              <label key={a} className="check">
                <input type="checkbox" checked={accessories.includes(a)} onChange={() => toggleAcc(a)} /> {a}
              </label>
            ))}
          </div>
          <input placeholder="حاجة تانية (افصل بفاصلة)" value={otherAcc} onChange={(e) => setOtherAcc(e.target.value)} />
        </fieldset>
      </section>

      <section className="card">
        <h2>العطل والحالة</h2>
        <label>
          العطل كما وصفه العميل
          <textarea required rows={3} value={issue} onChange={(e) => setIssue(e.target.value)} maxLength={1000} />
        </label>
        <label>
          الحالة الشكلية (خدوش، كسر...)
          <textarea rows={2} value={condition} onChange={(e) => setCondition(e.target.value)} />
        </label>
        <label>
          التكلفة التقديرية (جنيه)
          <input inputMode="decimal" dir="ltr" value={estimate} onChange={(e) => setEstimate(e.target.value)} placeholder="0" />
        </label>
      </section>

      <section className="card">
        <h2>صور الجهاز (حتى {MAX_PHOTOS} صور)</h2>
        <input
          type="file"
          accept="image/*"
          multiple
          capture="environment"
          onChange={(e) => {
            const files = Array.from(e.target.files ?? []);
            setPhotos((cur) => [...cur, ...files].slice(0, MAX_PHOTOS));
            e.target.value = '';
          }}
          disabled={photos.length >= MAX_PHOTOS}
        />
        {photos.length > 0 && (
          <ul className="file-list">
            {photos.map((f, i) => (
              <li key={i}>
                {f.name}{' '}
                <button type="button" className="link" onClick={() => setPhotos((cur) => cur.filter((_, j) => j !== i))}>
                  شيل
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      {error && <div className="alert error">{error}</div>}
      <div className="actions">
        <button type="submit" className="primary big" disabled={busy}>
          {busy ? 'جاري الحفظ...' : 'حفظ الاستلام'}
        </button>
      </div>
    </form>
  );
}
