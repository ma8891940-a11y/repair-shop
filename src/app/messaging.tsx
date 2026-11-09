import { useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ExternalLink, MessageCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { daysSince } from '../lib/dates';
import { TEMPLATE_KEYS, fillTemplate, trackingUrl, waLink, type TemplateKey } from '../lib/messages';
import type { DeviceStatus } from '../lib/status';
import { useFormat } from '../i18n/format';
import { useMe } from './auth';
import { useDuration } from './tech/names';
import { useLoad } from './useLoad';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Field, Select, Textarea } from '../ui/Field';
import { Alert } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { appBase, urlProblem } from '../lib/publicUrl';
import { AssistBox, useSensitiveNames } from './assist';
import { whatsappBody } from '../lib/assistPayloads';

/** قوالب المحل (لو صاحب المحل عدّلها) وإلا الافتراضي باللغة الحالية */
export function useTemplates() {
  const { t } = useTranslation();
  const { data, reload } = useLoad(async () => {
    const { data } = await supabase.from('message_templates').select('key, body').is('deleted_at', null);
    return Object.fromEntries((data ?? []).map((r) => [r.key, r.body])) as Partial<Record<TemplateKey, string>>;
  }, []);
  const get = (k: TemplateKey) => data?.[k] ?? t(`wa.defaults.${k}`);
  return { get, custom: data ?? {}, reload };
}

export interface MessageTarget {
  /** فاضي لرسالة مش عن جهاز معيّن (زي تذكير بالدين) */
  deviceId: string | null;
  customerId: string;
  customerName: string;
  phone: string;
  orderNo: string;
  device: string;
  status: DeviceStatus;
  token: string | null;
  /** اسم الفني الحالي (الرسايل باسمه) */
  tech?: string | null;
  /** المدة المتوقعة بالدقايق */
  etaMinutes?: number | null;
  /** الرصيد المستحق على العميل (للتذكير بالدين) */
  balance?: number | null;
  cost: number | null;
  readySince?: string | null;
  warrantyUntil?: string | null;
}

/** المتغيرات اللي القوالب بتتملى بيها */
export function useMessageVars(target: MessageTarget | null) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const dur = useDuration();
  return useMemo(() => {
    if (!target) return {};
    return {
      name: target.customerName.split(' ')[0],
      order: target.orderNo,
      device: target.device,
      status: t(`status.${target.status}`),
      cost: target.cost != null ? `${f.money(target.cost)} ${f.currency(shop.currency)}` : '',
      link: target.token ? trackingUrl(appBase(shop.extras, window.location.href), target.token) : '',
      shop: shop.name,
      days: target.readySince ? String(daysSince(target.readySince, new Date())) : '',
      warranty: target.warrantyUntil ? f.date(target.warrantyUntil) : '',
      tech: target.tech || t('wa.team'),
      eta: target.etaMinutes ? dur(target.etaMinutes) : '',
      balance: target.balance != null ? `${f.money(target.balance)} ${f.currency(shop.currency)}` : '',
    };
  }, [target, t, f, shop, dur]);
}

/** نافذة رسالة واتساب: اختار القالب، عدّل لو عايز، وافتح واتساب. الرسالة بتتسجل في سجل الرسايل. */
export function WhatsAppDialog({ open, onOpenChange, target, initial }: { open: boolean; onOpenChange: (v: boolean) => void; target: MessageTarget | null; initial?: TemplateKey }) {
  const { t } = useTranslation();
  const { profile, shop } = useMe();
  const toast = useToast();
  const { get } = useTemplates();
  const vars = useMessageVars(target);
  useSensitiveNames([target?.customerName]);
  const [key, setKey] = useState<TemplateKey>(initial ?? 'status');
  const [text, setText] = useState('');
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (open && initial) setKey(initial);
  }, [open, initial]);
  // القالب بيتملي لما الرسالة تتفتح أو القالب يتغيّر بس. (vars بيتعمل من جديد مع كل رسم، فبنقارن بمحتواه،
  // عشان أي تعديل بإيدك أو "تطبيق" للمسودة ما يترجعش للقالب تاني)
  const varsKey = JSON.stringify(vars);
  useEffect(() => {
    if (open) setText(fillTemplate(get(key), vars));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, key, varsKey]);

  const link = target ? waLink(target.phone, text) : null;

  async function send() {
    if (!target || !link) return setErr(t('wa.noPhone'));
    window.open(link, '_blank', 'noopener');
    const { error } = await supabase.from('message_log').insert({ id: crypto.randomUUID(), shop_id: profile.shop_id, device_id: target.deviceId, customer_id: target.customerId, template_key: key, body: text });
    if (error) toast({ tone: 'warn', title: errorMessage(error) });
    else toast({ tone: 'ok', title: t('wa.logged') });
    onOpenChange(false);
  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('wa.title')}
      description={target ? `${target.customerName} · ${target.phone}` : undefined}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" icon={<ExternalLink className="size-4" />} onClick={() => void send()} disabled={!link}>
            {t('wa.open')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('wa.template')}>
          <Select value={key} onChange={(e) => setKey(e.target.value as TemplateKey)}>
            {TEMPLATE_KEYS.map((k) => (
              <option key={k} value={k}>
                {t(`wa.keys.${k}`)}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t('wa.preview')}>
          <Textarea rows={6} value={text} onChange={(e) => setText(e.target.value)} />
        </Field>
        {/* مسودة بالذكاء: بتتكتب بمتغيرات ({name}، {order}...) والبرنامج بيملاها هنا، فالاسم والرقم ما بيخرجوش */}
        {target && (
          <AssistBox
            compact
            area="customers"
            kind="whatsapp"
            title={t('assist.wa.title')}
            askLabel={t('assist.wa.ask')}
            testid="assist-wa"
            privacy={t('assist.privacyNoCustomer')}
            build={() => whatsappBody({ purpose: key, status: target.status, names: [target.customerName] })}
            render={(answer) => {
              const filled = fillTemplate(answer, vars);
              return (
                <div className="flex flex-col gap-2">
                  <p className="whitespace-pre-wrap">{filled}</p>
                  <Button size="sm" variant="primary" className="self-start" onClick={() => setText(filled)} data-testid="assist-wa-apply">
                    {t('assist.apply')}
                  </Button>
                </div>
              );
            }}
          />
        )}
        {(err || (target && !link)) && <Alert tone="danger">{err ?? t('wa.noPhone')}</Alert>}
        {/* البند 12: الرابط لو localhost أو شبكة داخلية، العميل مش هيعرف يفتحه */}
        {vars.link && urlProblem(appBase(shop.extras, window.location.href)) && (
          <div data-testid="wa-local-link">
            <Alert tone="warn">{t('publicUrl.waWarn')}</Alert>
          </div>
        )}
      </div>
    </Dialog>
  );
}

export function WhatsAppButton({ onClick, size = 'sm' }: { onClick: () => void; size?: 'sm' | 'md' }) {
  const { t } = useTranslation();
  return (
    <Button size={size} variant="secondary" icon={<MessageCircle className="size-4 text-ok" />} onClick={onClick}>
      {t('wa.send')}
    </Button>
  );
}
