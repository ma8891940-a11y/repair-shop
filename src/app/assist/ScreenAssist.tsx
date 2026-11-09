import { useEffect, useState } from 'react';
import { useLocation } from 'react-router';
import { useTranslation } from 'react-i18next';
import { CircleHelp, Send } from 'lucide-react';
import { Dialog } from '../../ui/Dialog';
import { Button } from '../../ui/Button';
import { Input } from '../../ui/Field';
import { askAssistant, AssistNote, useAssistAllowed, useAssistServer, type AssistError } from '../assist';

/** الشاشة الحالية من الرابط (نفس القايمة اللي السيرفر بيقبلها) */
export function screenOf(pathname: string): string {
  const p = pathname.replace(/^\/+/, '');
  if (!p) return 'dashboard';
  if (p.startsWith('devices/')) return 'device';
  const first = p.split(/[/?]/)[0];
  if (first === 'finance' || first === 'drawer') return 'finance';
  if (first === 'opening') return 'inventory';
  return ['intake', 'devices', 'customers', 'inventory', 'reports', 'partners', 'settings', 'work'].includes(first) ? first : 'other';
}

/**
 * الزرار العايم في كل شاشة: شرح الشاشة دي (مدمج، شغال من غير نت دايمًا)،
 * وسؤال للمساعد عن الشاشة دي (بيتبعت اسم الشاشة والسؤال بس، متنضّف من أي أرقام أو أسماء).
 */
/** الكمبيوتر (md وأكبر) ولا الموبايل */
function useWide(): boolean {
  const q = '(min-width: 768px)';
  const [wide, setWide] = useState(() => (typeof window.matchMedia === 'function' ? window.matchMedia(q).matches : true));
  useEffect(() => {
    if (typeof window.matchMedia !== 'function') return;
    const mq = window.matchMedia(q);
    const on = () => setWide(mq.matches);
    mq.addEventListener('change', on);
    return () => mq.removeEventListener('change', on);
  }, []);
  return wide;
}

/**
 * placement: على الكمبيوتر زرار عايم تحت، وعلى الموبايل زرار في الشريط اللي فوق
 * (عشان ما يغطيش أزرار الصفحة اللي تحت، والشريط السفلي موجود أصلًا).
 */
export function ScreenAssist({ placement }: { placement: 'float' | 'header' }) {
  const wide = useWide();
  if ((placement === 'float') !== wide) return null;
  return <ScreenAssistInner placement={placement} />;
}

function ScreenAssistInner({ placement }: { placement: 'float' | 'header' }) {
  const { t } = useTranslation();
  const location = useLocation();
  const screen = screenOf(location.pathname);
  const allowed = useAssistAllowed('screen');
  const server = useAssistServer();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState('');
  const [busy, setBusy] = useState(false);
  const [answer, setAnswer] = useState<string | null>(null);
  const [err, setErr] = useState<AssistError | null>(null);
  async function ask() {
    setBusy(true);
    setErr(null);
    setAnswer(null);
    const r = await askAssistant('screen', { screen, question: q });
    setBusy(false);
    if (r.ok) setAnswer(r.answer);
    else setErr(r.error);
  }
  return (
    <>
      <button
        type="button"
        onClick={() => {
          setAnswer(null);
          setErr(null);
          setOpen(true);
        }}
        aria-label={t('assist.screen.button')}
        title={t('assist.screen.button')}
        className={
          placement === 'float'
            ? 'glass fixed bottom-4 end-4 z-20 grid size-10 place-items-center rounded-full text-fg-2 shadow-2 transition-[color,transform] hover:text-accent active:scale-95 print:hidden'
            : 'grid size-9 place-items-center rounded-md text-fg-2 transition-colors hover:text-accent print:hidden'
        }
        data-testid="screen-assist"
      >
        <CircleHelp className="size-5" aria-hidden />
      </button>
      <Dialog open={open} onOpenChange={setOpen} title={t('assist.screen.title')} guard={false} description={t(`assist.screen.names.${screen}`)} className="w-[min(94vw,520px)]">
        <div className="flex flex-col gap-3" data-testid="screen-assist-panel" data-screen={screen}>
          <div className="whitespace-pre-wrap rounded-md border border-glass-border bg-sunken/40 p-3 text-sm text-fg-2" data-testid="screen-help">
            {t(`assist.screen.help.${screen}`)}
          </div>
          {allowed && (
            <form
              className="flex gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (q.trim()) void ask();
              }}
            >
              <Input className="flex-1" value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('assist.screen.placeholder')} aria-label={t('assist.screen.placeholder')} maxLength={300} />
              <Button type="submit" variant="primary" icon={<Send className="size-4" />} loading={busy} disabled={server !== 'on' || !q.trim()} data-testid="screen-assist-ask">
                {t('assist.screen.ask')}
              </Button>
            </form>
          )}
          {allowed && <AssistNote state={err ?? server} />}
          {answer && (
            <div className="whitespace-pre-wrap rounded-md border border-glass-border p-3 text-sm text-fg" data-testid="screen-assist-answer">
              {answer}
            </div>
          )}
          <p className="text-2xs text-fg-3">{t('assist.privacyScreen')}</p>
        </div>
      </Dialog>
    </>
  );
}
