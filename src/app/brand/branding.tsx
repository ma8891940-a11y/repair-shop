import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../../lib/supabase';
import { useLoad } from '../useLoad';
import { useMe } from '../auth';
import type { Shop } from '../../lib/types';

export interface Branding {
  id: string;
  shop_id: string;
  name_en: string | null;
  tagline: string | null;
  phones: string[];
  whatsapp: string | null;
  socials: Partial<Record<'facebook' | 'instagram' | 'tiktok' | 'website', string>>;
  logo_path: string | null;
  logo_color: string | null;
  logo_thermal: string | null;
  thermal_contrast: number;
  thermal_custom: boolean;
  show_powered_by: boolean;
}
export const BRANDING_COLUMNS = 'id, shop_id, name_en, tagline, phones, whatsapp, socials, logo_path, logo_color, logo_thermal, thermal_contrast, thermal_custom, show_powered_by';

/** هوية المحل (محفوظة على الجهاز كمان، عشان الطباعة تشتغل بدون نت) */
/**
 * الهوية اتغيّرت (لوجو جديد مثلًا): كل الشاشات المفتوحة بتقرأها من جديد على طول، حتى في تبويب تاني.
 */
const BRANDING_EVENT = 'branding-changed';
let channel: BroadcastChannel | null = null;
try {
  channel = new BroadcastChannel('gawalak-branding');
} catch {
  channel = null;
}
export function brandingChanged() {
  window.dispatchEvent(new Event(BRANDING_EVENT));
  channel?.postMessage(1);
}

export function useBranding() {
  const { shop } = useMe();
  const loaded = useLoad(
    async () => {
      const { data, error } = await supabase.from('shop_branding').select(BRANDING_COLUMNS).eq('shop_id', shop.id).maybeSingle();
      if (error) throw error;
      return (data as Branding | null) ?? null;
    },
    [shop.id],
    { cacheKey: `branding:${shop.id}` },
  );
  const { reload } = loaded;
  useEffect(() => {
    const on = () => reload();
    window.addEventListener(BRANDING_EVENT, on);
    channel?.addEventListener('message', on);
    return () => {
      window.removeEventListener(BRANDING_EVENT, on);
      channel?.removeEventListener('message', on);
    };
  }, [reload]);
  return loaded;
}

/** التليفونات اللي هتتطبع: تليفون المحل الأساسي وبعده الإضافية من غير تكرار */
export function shopPhones(shop: Pick<Shop, 'phone'>, b: Branding | null): string[] {
  return [...new Set([shop.phone, ...(b?.phones ?? [])].map((x) => (x ?? '').trim()).filter(Boolean))];
}

/**
 * رأس الإيصال الحراري 80مم: لوجو المحل أبيض وأسود، أو اسمه كبير لو مفيش لوجو. ألوان ثابتة (أسود على أبيض) للطابعة.
 */
export function ThermalHeader({ shop, b }: { shop: Shop; b: Branding | null }) {
  const phones = shopPhones(shop, b);
  return (
    <div className="text-center" data-testid="shop-header-thermal">
      {b?.logo_thermal ? (
        <img src={b.logo_thermal} alt={shop.name} className="mx-auto mb-1 h-[18mm] w-auto max-w-full object-contain" data-testid="shop-logo-thermal" />
      ) : (
        <div className="text-[22px] font-extrabold leading-tight" data-testid="shop-name-big">
          {shop.name}
        </div>
      )}
      {b?.logo_thermal && <div className="text-[14px] font-bold">{shop.name}</div>}
      {b?.tagline && <div className="text-[11px]">{b.tagline}</div>}
      {(shop.address || phones.length > 0) && (
        <div className="text-[11px]">
          {shop.address}
          {phones.length > 0 && (
            <span dir="ltr" className="ms-1 font-mono">
              {phones.join(' / ')}
            </span>
          )}
        </div>
      )}
    </div>
  );
}

/** رأس الفاتورة A4 والكشوف: لوجو المحل الملون، والاسم بالعربي والإنجليزي، والشعار، وطرق التواصل */
export function ColorHeader({ shop, b, title, sub }: { shop: Shop; b: Branding | null; title?: string; sub?: string }) {
  const phones = shopPhones(shop, b);
  const socials = Object.entries(b?.socials ?? {}).filter(([, v]) => v);
  return (
    <header className="flex items-start justify-between gap-6 border-b-2 border-black pb-4" data-testid="shop-header-color">
      <div className="flex items-center gap-4">
        {b?.logo_color ? <img src={b.logo_color} alt={shop.name} className="h-20 w-auto max-w-[70mm] object-contain" data-testid="shop-logo-color" /> : null}
        <div>
          <div className={b?.logo_color ? 'text-[20px] font-bold' : 'text-[26px] font-extrabold'} data-testid={b?.logo_color ? undefined : 'shop-name-big'}>
            {shop.name}
          </div>
          {b?.name_en && (
            <div className="text-[13px] font-semibold tracking-wide" dir="ltr">
              {b.name_en}
            </div>
          )}
          {b?.tagline && <div className="text-[12px] text-neutral-700">{b.tagline}</div>}
          <div className="mt-1 text-[11px] text-neutral-700">
            {shop.address}
            {phones.length > 0 && (
              <span dir="ltr" className="ms-2 font-mono">
                {phones.join(' / ')}
              </span>
            )}
            {b?.whatsapp && (
              <span dir="ltr" className="ms-2 font-mono">
                WhatsApp {b.whatsapp}
              </span>
            )}
          </div>
          {socials.length > 0 && (
            <div className="text-[10px] text-neutral-600" dir="ltr">
              {socials.map(([, v]) => v).join(' · ')}
            </div>
          )}
        </div>
      </div>
      {(title || sub) && (
        <div className="text-end">
          {title && <div className="text-[15px] font-semibold">{title}</div>}
          {sub && <div className="text-[11px] text-neutral-700">{sub}</div>}
        </div>
      )}
    </header>
  );
}

/** سطر "بواسطة [اسم التطبيق]": مقفول افتراضيًا، وصاحب المحل بيفعّله من الإعدادات */
export function PoweredBy({ b }: { b: Branding | null }) {
  const { t } = useTranslation();
  if (!b?.show_powered_by) return null;
  return (
    <div className="mt-2 text-center text-[9px] text-neutral-500" data-testid="powered-by">
      {t('identity.poweredBy', { app: t('app.name') })}
    </div>
  );
}
