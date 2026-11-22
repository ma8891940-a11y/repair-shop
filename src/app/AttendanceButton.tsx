import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Clock } from 'lucide-react';
import { useMe } from './auth';
import { useLoad } from './useLoad';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

/** بيتبعت بعد أي حضور أو انصراف، عشان الزرارين (الشريط والشاشة) والجداول يتحدّثوا مع بعض */
export const ATT_CHANGED = 'gawalak:attendance-changed';

/** R2: زرار "حضوري": حضور أو انصراف بضغطة (الوقت من السيرفر). compact = الشريط العلوي (الكلام على الشاشات الكبيرة بس) */
export function AttendanceButton({ compact }: { compact?: boolean }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const { profile } = useMe();
  const [busy, setBusy] = useState(false);
  const { data, reload } = useLoad(async () => {
    const r = await supabase.from('attendance').select('id, clock_in').eq('profile_id', profile.id).is('clock_out', null).is('deleted_at', null).maybeSingle();
    if (r.error) throw r.error;
    return (r.data as { id: string; clock_in: string } | null) ?? null;
  }, [profile.id]);
  useEffect(() => {
    const on = () => reload();
    window.addEventListener(ATT_CHANGED, on);
    return () => window.removeEventListener(ATT_CHANGED, on);
  }, [reload]);
  const open = data ?? null;
  async function toggle() {
    setBusy(true);
    const { error } = open ? await supabase.rpc('clock_out', {}) : await supabase.rpc('clock_in', { p_id: crypto.randomUUID() });
    setBusy(false);
    if (error) {
      toast({ tone: 'danger', title: errorMessage(error) });
      // الحالة ممكن تكون اتغيرت (حضور من جهاز تاني، أو الرد ضاع والطلب وصل): نجيبها من جديد
      window.dispatchEvent(new Event(ATT_CHANGED));
      return;
    }
    toast({ tone: 'ok', title: t(open ? 'att.outDone' : 'att.inDone') });
    window.dispatchEvent(new Event(ATT_CHANGED));
  }
  const label = open ? t('att.inSince', { time: f.time(open.clock_in) }) : t('att.clockIn');
  return (
    <button
      type="button"
      onClick={() => void toggle()}
      disabled={busy || data === undefined}
      className={cn(
        // في الشريط العلوي: من الشاشات المتوسطة وطالع بس (على الموبايل الشريط بيضيق والصفحة كانت بتعرض لبرّه، والحضور من القايمة أو شاشة الحضور)
        compact ? 'hidden h-9 items-center gap-1.5 rounded-md px-2 text-sm hover:bg-raised disabled:opacity-60 sm:flex' : 'flex h-9 items-center gap-1.5 rounded-md px-2 text-sm hover:bg-raised disabled:opacity-60',
        !compact && 'glass px-3',
        open ? 'text-accent' : 'text-fg-2 hover:text-fg',
      )}
      aria-label={open ? `${label} · ${t('att.clockOut')}` : label}
      title={open ? t('att.clockOut') : t('att.clockIn')}
      data-testid={compact ? 'att-button' : 'att-button-page'}
      data-state={open ? 'in' : 'out'}
    >
      <Clock className="size-4" aria-hidden />
      <span className={compact ? 'hidden lg:inline' : undefined}>{open && !compact ? `${label} · ${t('att.clockOut')}` : label}</span>
    </button>
  );
}
