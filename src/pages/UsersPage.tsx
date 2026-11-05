import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { supabase } from '../lib/supabase';
import { arabicError } from '../lib/errors';
import { ROLE_LABELS, type Profile } from '../lib/types';
import { formatDateTime } from '../lib/dates';
import { useMe } from '../auth/AuthContext';

interface Invite {
  id: string;
  email: string;
  full_name: string;
  role: 'reception' | 'technician';
  created_at: string;
}

export function UsersPage() {
  const { profile: me } = useMe();
  const [users, setUsers] = useState<Profile[]>([]);
  const [invites, setInvites] = useState<Invite[]>([]);
  const [email, setEmail] = useState('');
  const [name, setName] = useState('');
  const [role, setRole] = useState<'reception' | 'technician'>('reception');
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);

  const load = useCallback(async () => {
    const [u, i] = await Promise.all([
      supabase.from('profiles').select('id, shop_id, full_name, email, role, deleted_at').order('created_at'),
      supabase
        .from('staff_invites')
        .select('id, email, full_name, role, created_at')
        .is('accepted_at', null)
        .is('deleted_at', null)
        .order('created_at'),
    ]);
    setUsers((u.data ?? []) as Profile[]);
    setInvites((i.data ?? []) as Invite[]);
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function invite(e: FormEvent) {
    e.preventDefault();
    setMsg(null);
    const em = email.trim().toLowerCase();
    const { error } = await supabase
      .from('staff_invites')
      .insert({ shop_id: me.shop_id, email: em, full_name: name.trim(), role });
    if (error) {
      const text = /staff_invites_open/.test(error.message) ? 'فيه دعوة مفتوحة للإيميل ده بالفعل' : arabicError(error);
      return setMsg({ ok: false, text });
    }
    setMsg({
      ok: true,
      text: `اتعملت الدعوة. قول لـ ${name.trim()} يفتح البرنامج ويعمل "حساب جديد" بالإيميل ${em}، وهيدخل على المحل تلقائيًا.`,
    });
    setEmail('');
    setName('');
    await load();
  }

  async function setActive(u: Profile, active: boolean) {
    if (!active && !confirm(`إيقاف حساب ${u.full_name}؟ مش هيقدر يدخل البرنامج.`)) return;
    const { error } = await supabase
      .from('profiles')
      .update({ deleted_at: active ? null : new Date().toISOString() })
      .eq('id', u.id);
    if (error) setMsg({ ok: false, text: arabicError(error) });
    await load();
  }

  async function cancelInvite(i: Invite) {
    const { error } = await supabase.from('staff_invites').update({ deleted_at: new Date().toISOString() }).eq('id', i.id);
    if (error) setMsg({ ok: false, text: arabicError(error) });
    await load();
  }

  return (
    <div className="form-page">
      <h1>المستخدمين</h1>
      <section className="card">
        <h2>إضافة موظف</h2>
        <form onSubmit={invite}>
          <div className="row">
            <label className="grow">
              الاسم
              <input required value={name} onChange={(e) => setName(e.target.value)} maxLength={120} />
            </label>
            <label className="grow">
              الإيميل
              <input type="email" dir="ltr" required value={email} onChange={(e) => setEmail(e.target.value)} />
            </label>
            <label>
              الدور
              <select value={role} onChange={(e) => setRole(e.target.value as 'reception' | 'technician')}>
                <option value="reception">{ROLE_LABELS.reception}</option>
                <option value="technician">{ROLE_LABELS.technician}</option>
              </select>
            </label>
          </div>
          <button type="submit" className="primary">
            إرسال دعوة
          </button>
        </form>
        {msg && <div className={`alert ${msg.ok ? 'ok' : 'error'}`}>{msg.text}</div>}
      </section>

      {invites.length > 0 && (
        <section className="card">
          <h2>دعوات لسه ما اتقبلتش</h2>
          <table>
            <tbody>
              {invites.map((i) => (
                <tr key={i.id}>
                  <td>{i.full_name}</td>
                  <td dir="ltr">{i.email}</td>
                  <td>{ROLE_LABELS[i.role]}</td>
                  <td className="small">{formatDateTime(i.created_at)}</td>
                  <td>
                    <button className="link" onClick={() => void cancelInvite(i)}>
                      إلغاء
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      )}

      <section className="card">
        <h2>فريق المحل</h2>
        <table>
          <thead>
            <tr>
              <th>الاسم</th>
              <th>الإيميل</th>
              <th>الدور</th>
              <th>الحالة</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td>{u.full_name}</td>
                <td dir="ltr">{u.email}</td>
                <td>{ROLE_LABELS[u.role]}</td>
                <td>{u.deleted_at ? <span className="badge st-unrepairable">موقوف</span> : <span className="badge st-ready">نشط</span>}</td>
                <td>
                  {u.id !== me.id &&
                    (u.deleted_at ? (
                      <button className="link" onClick={() => void setActive(u, true)}>
                        تفعيل
                      </button>
                    ) : (
                      <button className="link" onClick={() => void setActive(u, false)}>
                        إيقاف
                      </button>
                    ))}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>
    </div>
  );
}
