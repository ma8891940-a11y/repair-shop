import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, ClipboardCopy, MessageCircle, Printer, QrCode, ScrollText, StickyNote } from 'lucide-react';
import { useMe } from '../auth';
import { useLoad, must } from '../useLoad';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { fillTemplate, waLink } from '../../lib/messages';
import { ACTION_DOC, ACTIONS, printUrl, readPrint, type PrintAction } from '../../lib/printPlan';
import { useMessageVars, useTemplates, type MessageTarget } from '../messaging';
import type { DeviceStatus } from '../../lib/status';
import { useFormat } from '../../i18n/format';
import { Button } from '../../ui/Button';
import { Input } from '../../ui/Field';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';

/** اتعمل إمتى (على الجهاز ده)، لكل جهاز */
const doneKey = (id: string) => `print-done:${id}`;
function readDone(id: string): Partial<Record<PrintAction, number>> {
  try {
    return JSON.parse(localStorage.getItem(doneKey(id)) ?? '{}') as Partial<Record<PrintAction, number>>;
  } catch {
    return {};
  }
}
function writeDone(id: string, v: Partial<Record<PrintAction, number>>) {
  try {
    localStorage.setItem(doneKey(id), JSON.stringify(v));
  } catch {
    /* التخزين مقفول */
  }
}

/** "رقم محفوظ": بيفضل محفوظ على الجهاز ده حتى لو البرنامج اتقفل */
export const SAVED_NUMBER_KEY = 'saved-number';
export function readSavedNumber(): string {
  try {
    return localStorage.getItem(SAVED_NUMBER_KEY) ?? '';
  } catch {
    return '';
  }
}

/**
 * الطباعة من غير ما تسيب الشاشة: صفحة الطباعة بتتفتح في إطار مخفي، وبتطبع، وبتقول "اتطبع".
 * بيشتغل كمان جوه Electron/Tauri/Capacitor (مفيش حاجة خاصة بالمتصفح بس).
 */
export function printInFrame(url: string): Promise<boolean> {
  return new Promise((resolve) => {
    const frame = document.createElement('iframe');
    frame.setAttribute('aria-hidden', 'true');
    frame.tabIndex = -1;
    frame.dataset.testid = 'print-frame';
    Object.assign(frame.style, { position: 'fixed', insetInlineStart: '-10000px', top: '0', width: '800px', height: '1000px', border: '0', visibility: 'hidden' });
    const done = (ok: boolean) => {
      window.removeEventListener('message', onMsg);
      clearTimeout(tm);
      // نسيب الإطار ثانية عشان نافذة الطباعة تكون قفلت
      setTimeout(() => frame.remove(), 1000);
      resolve(ok);
    };
    const onMsg = (e: MessageEvent) => {
      if (e.source === frame.contentWindow && (e.data as { type?: string })?.type === 'gawalak-printed') done(true);
    };
    window.addEventListener('message', onMsg);
    const tm = setTimeout(() => done(false), 60_000);
    frame.src = `${window.location.pathname}${window.location.search}#${url}`;
    document.body.appendChild(frame);
  });
}

const ICON: Record<PrintAction, typeof Printer> = { thermal: ScrollText, paper: Printer, sticker: StickyNote, qr: QrCode, whatsapp: MessageCircle };

/**
 * "طباعة وإرسال" (الاستلام وصفحة الجهاز): إيصال حراري، وإيصال ورقي A4، واستيكر الجهاز، وملصق QR للتتبع،
 * ورسالة واتساب للعميل برابط التتبع. كل زرار بضغطة واحدة وجنبه علامة إنه اتعمل.
 * autoRun: بعد الاستلام، اللي متعلّم في الإعدادات ← الطباعة بيتعمل لوحده بالترتيب.
 */
export function PrintSendPanel({ deviceId, autoRun = false, className }: { deviceId: string; autoRun?: boolean; className?: string }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, profile } = useMe();
  const toast = useToast();
  const settings = readPrint(shop.extras);
  const [done, setDone] = useState(() => readDone(deviceId));
  const [busy, setBusy] = useState<PrintAction | null>(null);
  const [saved, setSaved] = useState(readSavedNumber);
  const [useSaved, setUseSaved] = useState(false);
  const { get } = useTemplates();

  const { data } = useLoad(async () => {
    const d = must(await supabase.from('devices').select('id, order_no, brand, model, status, tracking_token, customer_id').eq('id', deviceId).maybeSingle()) as {
      id: string; order_no: string; brand: string; model: string; status: DeviceStatus; tracking_token: string; customer_id: string;
    } | null;
    if (!d) return null;
    const c = must(await supabase.from('customers').select('id, name, phone').eq('id', d.customer_id).maybeSingle()) as { id: string; name: string; phone: string } | null;
    return { d, c };
  }, [deviceId]);
  const target: MessageTarget | null = data?.c
    ? { deviceId, customerId: data.c.id, customerName: data.c.name, phone: data.c.phone, orderNo: data.d.order_no, device: `${data.d.brand} ${data.d.model}`, status: data.d.status, token: data.d.tracking_token, cost: null }
    : null;
  const vars = useMessageVars(target);

  const mark = (a: PrintAction) => {
    const next = { ...readDone(deviceId), [a]: Date.now() };
    writeDone(deviceId, next);
    setDone(next);
  };

  async function run(a: PrintAction): Promise<void> {
    if (a === 'whatsapp') {
      if (!target) return;
      const text = fillTemplate(get('received'), vars);
      const link = waLink(target.phone, text);
      if (!link) return void toast({ tone: 'danger', title: t('wa.noPhone') });
      const w = window.open(link, '_blank', 'noopener');
      if (w === null && !navigator.userAgent.includes('Electron')) {
        // المتصفح منع النافذة (بعد الحفظ التلقائي مثلًا): المستخدم يدوس الزرار
        toast({ tone: 'warn', title: t('printSend.popupBlocked') });
      }
      const { error } = await supabase.from('message_log').insert({ id: crypto.randomUUID(), shop_id: profile.shop_id, device_id: deviceId, customer_id: target.customerId, template_key: 'received', body: text });
      if (error) toast({ tone: 'warn', title: errorMessage(error) });
      mark('whatsapp');
      return;
    }
    setBusy(a);
    const ok = await printInFrame(printUrl(ACTION_DOC[a], deviceId, { embed: true, no: a === 'sticker' && useSaved && saved.trim() ? saved.trim() : undefined }));
    setBusy(null);
    if (ok) mark(a);
    else toast({ tone: 'warn', title: t('printSend.failed') });
  }

  // بعد الاستلام: اللي متعلّم "تلقائي" بيتعمل لوحده مرة واحدة، بالترتيب
  const ran = useRef(false);
  useEffect(() => {
    if (!autoRun || ran.current || !data) return;
    ran.current = true;
    void (async () => {
      for (const a of ACTIONS) if (settings.auto[a] && !readDone(deviceId)[a]) await run(a);
    })();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [autoRun, data]);

  const saveNumber = (v: string) => {
    setSaved(v);
    try {
      localStorage.setItem(SAVED_NUMBER_KEY, v);
    } catch {
      /* التخزين مقفول */
    }
  };

  return (
    <div className={cn('flex flex-col gap-3', className)} data-testid="print-send">
      <div className="text-sm font-semibold text-fg">{t('printSend.title')}</div>
      <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
        {ACTIONS.map((a) => {
          const Icon = ICON[a];
          const at = done[a];
          return (
            <div key={a} className="flex items-center gap-2">
              <Button
                size="sm"
                variant={a === 'whatsapp' ? 'secondary' : 'outline'}
                icon={<Icon className={cn('size-4', a === 'whatsapp' && 'text-ok')} />}
                loading={busy === a}
                disabled={!data || (a === 'whatsapp' && !target)}
                needsNet={a === 'whatsapp'}
                onClick={() => void run(a)}
                className="flex-1 justify-start"
                data-testid={`ps-${a}`}
              >
                {t(`printSend.actions.${a}`)}
              </Button>
              <span className={cn('flex w-20 shrink-0 items-center gap-1 text-2xs', at ? 'text-ok' : 'text-fg-3')} data-testid={`ps-${a}-done`} data-done={at ? 'true' : 'false'}>
                {at ? (
                  <>
                    <Check className="size-3.5" aria-hidden /> {t(a === 'whatsapp' ? 'printSend.sent' : 'printSend.printed')}
                  </>
                ) : (
                  t('printSend.notYet')
                )}
              </span>
            </div>
          );
        })}
      </div>
      {/* رقم محفوظ: بيفضل على الجهاز ده، وتقدر تنسخه أو تطبعه على الاستيكر بدل رقم الطلب */}
      <div className="flex flex-wrap items-end gap-2 rounded-md border border-glass-border p-2" data-autosave>
        <label className="flex min-w-[150px] flex-1 flex-col gap-1 text-2xs text-fg-3">
          {t('printSend.savedNumber')}
          <Input value={saved} onChange={(e) => saveNumber(e.target.value)} dir="ltr" mono className="h-8" data-testid="saved-number" />
        </label>
        <Button
          size="sm"
          variant="ghost"
          icon={<ClipboardCopy className="size-4" />}
          disabled={!saved.trim()}
          onClick={() => {
            void navigator.clipboard?.writeText(saved.trim()).then(
              () => toast({ tone: 'ok', title: t('printSend.copied') }),
              () => undefined,
            );
          }}
          data-testid="saved-number-copy"
        >
          {t('printSend.copy')}
        </Button>
        <Button size="sm" variant={useSaved ? 'primary' : 'ghost'} aria-pressed={useSaved} disabled={!saved.trim()} onClick={() => setUseSaved((v) => !v)} data-testid="saved-number-use">
          {t('printSend.useOnSticker')}
        </Button>
      </div>
      {done.sticker && <p className="text-2xs text-fg-3">{t('printSend.lastAt', { at: f.time(new Date(done.sticker)) })}</p>}
    </div>
  );
}
