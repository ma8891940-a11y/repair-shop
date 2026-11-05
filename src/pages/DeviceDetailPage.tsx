import { useCallback, useEffect, useState } from 'react';
import { Link, useParams, useSearchParams } from 'react-router';
import { supabase } from '../lib/supabase';
import { STATUS_LABELS, nextStatusesFor, type DeviceStatus } from '../lib/status';
import { formatDateTime } from '../lib/dates';
import { formatEGP, formatPounds, parsePounds } from '../lib/money';
import { arabicError } from '../lib/errors';
import { MAX_PHOTOS, signedPhotoUrls, uploadDevicePhoto } from '../lib/photos';
import type { Customer, Device, DeviceCost } from '../lib/types';
import { useMe } from '../auth/AuthContext';
import { StatusBadge } from '../components/StatusBadge';
import { ImeiWarning } from '../components/ImeiWarning';

interface LogRow {
  id: string;
  old_status: DeviceStatus | null;
  new_status: DeviceStatus;
  created_at: string;
  profiles: { full_name: string } | null;
}
interface NoteRow {
  id: string;
  body: string;
  created_at: string;
  profiles: { full_name: string } | null;
}
interface PhotoRow {
  id: string;
  storage_path: string;
}

export function DeviceDetailPage() {
  const { id = '' } = useParams();
  const [params] = useSearchParams();
  const { profile } = useMe();
  const front = profile.role !== 'technician';

  const [device, setDevice] = useState<Device | null>(null);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [cost, setCost] = useState<DeviceCost | null>(null);
  const [log, setLog] = useState<LogRow[]>([]);
  const [notes, setNotes] = useState<NoteRow[]>([]);
  const [photos, setPhotos] = useState<PhotoRow[]>([]);
  const [urls, setUrls] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [notFound, setNotFound] = useState(false);
  const [busy, setBusy] = useState(false);

  const [estimateInput, setEstimateInput] = useState('');
  const [finalInput, setFinalInput] = useState('');
  const [noteInput, setNoteInput] = useState('');

  const load = useCallback(async () => {
    const { data: d, error: de } = await supabase.from('devices').select('*').eq('id', id).is('deleted_at', null).maybeSingle();
    if (de) return setError(arabicError(de));
    if (!d) return setNotFound(true);
    setDevice(d as Device);

    const [c, k, l, n, p] = await Promise.all([
      front ? supabase.from('customers').select('id, name, phone, area').eq('id', d.customer_id).maybeSingle() : Promise.resolve({ data: null }),
      front ? supabase.from('device_costs').select('id, device_id, estimated_cost, final_cost').eq('device_id', id).is('deleted_at', null).maybeSingle() : Promise.resolve({ data: null }),
      supabase.from('status_log').select('id, old_status, new_status, created_at, profiles(full_name)').eq('device_id', id).order('created_at'),
      supabase.from('device_notes').select('id, body, created_at, profiles(full_name)').eq('device_id', id).is('deleted_at', null).order('created_at'),
      supabase.from('device_photos').select('id, storage_path').eq('device_id', id).is('deleted_at', null).order('created_at'),
    ]);
    setCustomer((c.data as Customer) ?? null);
    const kc = (k.data as DeviceCost) ?? null;
    setCost(kc);
    setEstimateInput(kc?.estimated_cost != null ? formatPounds(kc.estimated_cost).replace(/,/g, '') : '');
    setFinalInput(kc?.final_cost != null ? formatPounds(kc.final_cost).replace(/,/g, '') : '');
    setLog((l.data ?? []) as unknown as LogRow[]);
    setNotes((n.data ?? []) as unknown as NoteRow[]);
    const ph = (p.data ?? []) as PhotoRow[];
    setPhotos(ph);
    try {
      setUrls(await signedPhotoUrls(ph.map((x) => x.storage_path)));
    } catch {
      /* الصور مش ضرورية لعرض الصفحة */
    }
  }, [id, front]);

  useEffect(() => {
    void load();
  }, [load]);

  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await fn();
      await load();
    } catch (e) {
      setError(arabicError(e));
    } finally {
      setBusy(false);
    }
  }

  function changeStatus(to: DeviceStatus) {
    if (to === 'delivered' && !confirm('تأكيد تسليم الجهاز للعميل؟')) return;
    void run(async () => {
      const { error } = await supabase.from('devices').update({ status: to }).eq('id', id);
      if (error) throw error;
    });
  }

  function saveCosts() {
    const est = estimateInput.trim() ? parsePounds(estimateInput) : null;
    const fin = finalInput.trim() ? parsePounds(finalInput) : null;
    if (estimateInput.trim() && est === null) return setError('التكلفة التقديرية مش رقم صحيح');
    if (finalInput.trim() && fin === null) return setError('التكلفة النهائية مش رقم صحيح');
    void run(async () => {
      if (cost) {
        const { error } = await supabase.from('device_costs').update({ estimated_cost: est, final_cost: fin }).eq('id', cost.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('device_costs')
          .insert({ shop_id: profile.shop_id, device_id: id, estimated_cost: est, final_cost: fin });
        if (error) throw error;
      }
    });
  }

  function addNote() {
    const body = noteInput.trim();
    if (!body) return;
    void run(async () => {
      const { error } = await supabase.from('device_notes').insert({ shop_id: profile.shop_id, device_id: id, body });
      if (error) throw error;
      setNoteInput('');
    });
  }

  function addPhotos(files: File[]) {
    const room = MAX_PHOTOS - photos.length;
    void run(async () => {
      for (const f of files.slice(0, room)) await uploadDevicePhoto(profile.shop_id, id, f);
    });
  }

  function removePhoto(p: PhotoRow) {
    if (!confirm('إخفاء الصورة دي؟')) return;
    void run(async () => {
      const { error } = await supabase.from('device_photos').update({ deleted_at: new Date().toISOString() }).eq('id', p.id);
      if (error) throw error;
    });
  }

  if (notFound) return <div className="alert error">الجهاز مش موجود.</div>;
  if (!device) return error ? <div className="alert error">{error}</div> : <p>جاري التحميل...</p>;

  const next = nextStatusesFor(device.status, profile.role);
  const photoFail = Number(params.get('photoFail') ?? 0);

  return (
    <div className="detail">
      {params.get('new') && (
        <div className="alert ok">
          اتسجّل الجهاز برقم طلب <b dir="ltr">{device.order_no}</b>.{' '}
          <Link to={`/print/receipt/${device.id}`}>اطبع إيصال الاستلام</Link>
        </div>
      )}
      {photoFail > 0 && <div className="alert warn">{photoFail} صورة ما اترفعتش. جرّب ترفعها تاني من تحت.</div>}

      <div className="page-head">
        <h1>
          طلب <span dir="ltr">{device.order_no}</span> <StatusBadge status={device.status} />
        </h1>
        {front && (
          <div className="row">
            <Link className="button" to={`/print/receipt/${device.id}`}>
              🖨 إيصال 80مم
            </Link>
            <Link className="button" to={`/print/invoice/${device.id}`}>
              🖨 فاتورة A4
            </Link>
          </div>
        )}
      </div>

      {error && <div className="alert error">{error}</div>}

      <section className="card">
        <h2>تغيير الحالة</h2>
        {next.length === 0 ? (
          <p className="muted">مفيش حالة تالية متاحة ليك.</p>
        ) : (
          <div className="row wrap">
            {next.map((s) => (
              <button key={s} className={`status-btn st-${s}`} disabled={busy} onClick={() => changeStatus(s)}>
                ← {STATUS_LABELS[s]}
              </button>
            ))}
          </div>
        )}
      </section>

      <div className="grid2">
        <section className="card">
          <h2>بيانات الجهاز</h2>
          <dl>
            {front && customer && (
              <>
                <dt>العميل</dt>
                <dd>
                  {customer.name} — <span dir="ltr">{customer.phone}</span> {customer.area && `(${customer.area})`}
                </dd>
              </>
            )}
            <dt>الجهاز</dt>
            <dd>
              {device.brand} {device.model} {device.color && `— ${device.color}`}
            </dd>
            <dt>IMEI</dt>
            <dd dir="ltr" className="mono">
              {device.imei || '—'}
            </dd>
            <dt>الملحقات</dt>
            <dd>{device.accessories.length ? device.accessories.join('، ') : 'بدون'}</dd>
            <dt>العطل</dt>
            <dd className="pre">{device.issue}</dd>
            <dt>الحالة الشكلية</dt>
            <dd className="pre">{device.cosmetic_condition || '—'}</dd>
            <dt>الاستلام</dt>
            <dd>{formatDateTime(device.received_at)}</dd>
            {device.delivered_at && (
              <>
                <dt>التسليم</dt>
                <dd>{formatDateTime(device.delivered_at)}</dd>
              </>
            )}
          </dl>
          {device.imei && <ImeiWarning imei={device.imei} excludeId={device.id} />}
        </section>

        {front && (
          <section className="card">
            <h2>التكلفة</h2>
            <label>
              التكلفة التقديرية (جنيه)
              <input dir="ltr" inputMode="decimal" value={estimateInput} onChange={(e) => setEstimateInput(e.target.value)} />
            </label>
            <label>
              التكلفة النهائية (جنيه)
              <input dir="ltr" inputMode="decimal" value={finalInput} onChange={(e) => setFinalInput(e.target.value)} />
            </label>
            <p className="muted small">
              الحالي: تقديري {cost?.estimated_cost != null ? formatEGP(cost.estimated_cost) : '—'} / نهائي{' '}
              {cost?.final_cost != null ? formatEGP(cost.final_cost) : '—'}. لازم التكلفة النهائية قبل التسليم، وأي تعديل بيتسجّل.
            </p>
            <button disabled={busy} onClick={saveCosts}>
              حفظ التكلفة
            </button>
          </section>
        )}
      </div>

      <section className="card">
        <h2>
          الصور ({photos.length}/{MAX_PHOTOS})
        </h2>
        <div className="photos">
          {photos.map((p) => (
            <figure key={p.id}>
              {urls[p.storage_path] ? (
                <a href={urls[p.storage_path]} target="_blank" rel="noreferrer">
                  <img src={urls[p.storage_path]} alt="صورة الجهاز" />
                </a>
              ) : (
                <div className="ph-missing">صورة</div>
              )}
              {front && (
                <button className="link small" onClick={() => removePhoto(p)}>
                  إخفاء
                </button>
              )}
            </figure>
          ))}
        </div>
        {front && photos.length < MAX_PHOTOS && (
          <input
            type="file"
            accept="image/*"
            multiple
            capture="environment"
            disabled={busy}
            onChange={(e) => {
              addPhotos(Array.from(e.target.files ?? []));
              e.target.value = '';
            }}
          />
        )}
      </section>

      <div className="grid2">
        <section className="card">
          <h2>ملاحظات داخلية</h2>
          <p className="muted small">للفريق بس. العميل ما بيشوفهاش.</p>
          <ul className="notes">
            {notes.map((n) => (
              <li key={n.id}>
                <div className="pre">{n.body}</div>
                <small className="muted">
                  {n.profiles?.full_name ?? '—'} — {formatDateTime(n.created_at)}
                </small>
              </li>
            ))}
          </ul>
          <textarea rows={2} value={noteInput} onChange={(e) => setNoteInput(e.target.value)} placeholder="اكتب ملاحظة..." maxLength={2000} />
          <button disabled={busy || !noteInput.trim()} onClick={addNote}>
            إضافة ملاحظة
          </button>
        </section>

        <section className="card">
          <h2>سجل الحالات</h2>
          <ol className="timeline">
            {log.map((l) => (
              <li key={l.id}>
                <b>{l.old_status ? `${STATUS_LABELS[l.old_status]} ← ${STATUS_LABELS[l.new_status]}` : STATUS_LABELS[l.new_status]}</b>
                <small className="muted">
                  {' '}
                  — {l.profiles?.full_name ?? '—'} — {formatDateTime(l.created_at)}
                </small>
              </li>
            ))}
          </ol>
        </section>
      </div>
    </div>
  );
}
