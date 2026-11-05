import { useEffect, useState } from 'react';
import { Link } from 'react-router';
import { supabase } from '../lib/supabase';
import { computeDashboard, type DashboardDevice, type DashboardStats } from '../lib/dashboard';
import { formatEGP } from '../lib/money';
import { arabicError } from '../lib/errors';
import { useMe } from '../auth/AuthContext';

export function DashboardPage() {
  const { profile } = useMe();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    async function load() {
      // كل الأجهزة اللي لسه في المحل + اللي اتسلّمت آخر يومين (عشان إيراد النهارده)
      const since = new Date(Date.now() - 2 * 86_400_000).toISOString();
      const { data, error } = await supabase
        .from('devices_list')
        .select('status, received_at, delivered_at, final_cost')
        .is('deleted_at', null)
        .or(`status.neq.delivered,delivered_at.gte."${since}"`)
        .limit(5000);
      if (!active) return;
      if (error) return setError(arabicError(error));
      setStats(computeDashboard((data ?? []) as DashboardDevice[], new Date()));
    }
    void load();
    const t = setInterval(load, 60_000);
    return () => {
      active = false;
      clearInterval(t);
    };
  }, []);

  if (error) return <div className="alert error">{error}</div>;
  if (!stats) return <p>جاري التحميل...</p>;

  const showRevenue = profile.role === 'owner';
  return (
    <div>
      <h1>لوحة التحكم</h1>
      <div className="cards">
        <Link className="stat" to="/devices?filter=today">
          <span>أجهزة اليوم</span>
          <b>{stats.today}</b>
        </Link>
        <Link className="stat" to="/devices?filter=under_repair">
          <span>تحت الصيانة</span>
          <b>{stats.underRepair}</b>
        </Link>
        <Link className="stat ok" to="/devices?status=ready">
          <span>جاهزة للاستلام</span>
          <b>{stats.ready}</b>
        </Link>
        <Link className={`stat ${stats.late ? 'danger' : ''}`} to="/devices?filter=late">
          <span>متأخرة (أكتر من 7 أيام)</span>
          <b>{stats.late}</b>
        </Link>
        {showRevenue && (
          <div className="stat money">
            <span>إيراد اليوم</span>
            <b>{formatEGP(stats.revenueToday)}</b>
            <small>مجموع التكلفة النهائية للأجهزة اللي اتسلّمت النهارده</small>
          </div>
        )}
      </div>
    </div>
  );
}
