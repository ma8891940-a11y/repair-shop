import { useEffect } from 'react';
import { useNavigate } from 'react-router';
import { useTranslation } from 'react-i18next';
import * as DropdownMenu from '@radix-ui/react-dropdown-menu';
import { AlertTriangle, Bell, CalendarClock, CheckCheck, PackageX, Smartphone, type LucideIcon } from 'lucide-react';
import { rpc } from './ledgerApi';
import { useLoad } from './useLoad';
import { useFormat } from '../i18n/format';
import { cn } from '../ui/cn';

export interface Notice {
  key: string;
  kind: 'overdue' | 'due_soon' | 'ready_old' | 'short' | 'unsettled';
  args: Record<string, string | number>;
  link: string;
  at: string;
  read: boolean;
}
const ICON: Record<Notice['kind'], LucideIcon> = { overdue: AlertTriangle, due_soon: CalendarClock, ready_old: Smartphone, short: PackageX, unsettled: AlertTriangle };
const TONE: Record<Notice['kind'], string> = { overdue: 'text-danger', due_soon: 'text-warn', ready_old: 'text-accent', short: 'text-warn', unsettled: 'text-danger' };

/**
 * N: مركز الإشعارات (الجرس فوق): أقساط متأخرة أو قربت، وأجهزة جاهزة من 10 أيام، وأصناف ناقصة، وبيعات محتاجة تسوية.
 * كل مستخدم بيشوف اللي ليه صلاحيته بس (من قاعدة البيانات)، والدوسة بتفتح الحاجة نفسها وبتعلّمها "اتقرت".
 * بيتحدّث لما ترجع للبرنامج وكل 5 دقايق.
 */
export function NotificationsBell() {
  const { t } = useTranslation();
  const f = useFormat();
  const navigate = useNavigate();
  const { data, reload } = useLoad(async () => (await rpc('notifications_feed')) as Notice[], []);
  useEffect(() => {
    const on = () => void reload();
    window.addEventListener('focus', on);
    const iv = window.setInterval(on, 5 * 60_000);
    return () => {
      window.removeEventListener('focus', on);
      window.clearInterval(iv);
    };
  }, [reload]);
  const list = data ?? [];
  const unread = list.filter((n) => !n.read).length;
  async function mark(keys: string[]) {
    if (!keys.length) return;
    await rpc('mark_notifications_read', { p_keys: keys }).catch(() => undefined);
    reload();
  }
  const text = (n: Notice) => {
    const a = { ...n.args };
    if (a.amount != null) a.amount = f.money(Number(a.amount));
    if (a.due) a.due = f.dateNum(String(a.due));
    if (a.qty != null) a.qty = f.number(Number(a.qty));
    if (a.days != null) a.days = f.number(Number(a.days));
    return t(`notify.kinds.${n.kind}`, a);
  };
  return (
    <DropdownMenu.Root>
      <DropdownMenu.Trigger asChild>
        <button
          type="button"
          className="relative grid size-9 place-items-center rounded-md text-fg-2 hover:bg-raised hover:text-fg"
          aria-label={unread ? t('notify.titleN', { n: unread }) : t('notify.title')}
          title={t('notify.title')}
          data-testid="bell"
        >
          <Bell className="size-4" aria-hidden />
          {unread > 0 && (
            <span className="num absolute -end-0.5 -top-0.5 grid h-4 min-w-4 place-items-center rounded-full bg-danger px-1 text-[10px] font-semibold leading-none text-on-accent" data-testid="bell-count">
              {unread > 99 ? '99+' : f.number(unread)}
            </span>
          )}
        </button>
      </DropdownMenu.Trigger>
      <DropdownMenu.Portal>
        <DropdownMenu.Content align="end" sideOffset={6} className="glass-strong z-50 flex max-h-[70vh] w-[min(92vw,380px)] flex-col rounded-md p-1 shadow-2" data-testid="bell-menu">
          <div className="flex items-center justify-between px-2.5 py-1.5">
            <span className="text-sm font-medium text-fg">{t('notify.title')}</span>
            {unread > 0 && (
              <DropdownMenu.Item
                onSelect={(e) => {
                  e.preventDefault();
                  void mark(list.filter((n) => !n.read).map((n) => n.key));
                }}
                className="flex cursor-pointer items-center gap-1 rounded-sm px-1.5 py-0.5 text-2xs text-fg-3 outline-none data-[highlighted]:bg-raised data-[highlighted]:text-fg"
                data-testid="bell-read-all"
              >
                <CheckCheck className="size-3.5" aria-hidden /> {t('notify.readAll')}
              </DropdownMenu.Item>
            )}
          </div>
          <div className="min-h-0 overflow-y-auto">
            {!list.length ? (
              <p className="px-2.5 py-4 text-center text-xs text-fg-3">{t('notify.empty')}</p>
            ) : (
              list.map((n) => {
                const I = ICON[n.kind] ?? Bell;
                return (
                  <DropdownMenu.Item
                    key={n.key}
                    onSelect={() => {
                      void mark([n.key]);
                      navigate(n.link);
                    }}
                    className={cn('flex cursor-pointer items-start gap-2.5 rounded-sm px-2.5 py-2 text-sm outline-none data-[highlighted]:bg-raised', n.read ? 'text-fg-3' : 'text-fg')}
                    data-testid="bell-item"
                    data-kind={n.kind}
                    data-read={n.read || undefined}
                  >
                    <I className={cn('mt-0.5 size-4 shrink-0', TONE[n.kind])} aria-hidden />
                    <span className="min-w-0 flex-1">{text(n)}</span>
                    {!n.read && <span className="mt-1.5 size-2 shrink-0 rounded-full bg-accent" aria-label={t('notify.unread')} />}
                  </DropdownMenu.Item>
                );
              })
            )}
          </div>
        </DropdownMenu.Content>
      </DropdownMenu.Portal>
    </DropdownMenu.Root>
  );
}
