import { useTranslation } from 'react-i18next';
import { useStage } from '../app/stage';
import logo from '../assets/app-logo.png';
import logoSm from '../assets/app-logo-sm.png';

/** نسبة اللوجو (العرض ÷ الارتفاع) بعد شيل الهامش الشفاف، زي ما طلع من brand/build-icons.py */
export const LOGO_RATIO = 1268 / 1130;

/**
 * لوجو التطبيق (بتاع صاحب المشروع، brand/app-logo.png) كما هو من غير أي تعديل في الشكل أو الألوان أو النسب.
 * مكانه جوه التطبيق بس: الافتتاحية، والدخول، والشريط الجانبي، ومعالج التسجيل. ممنوع على أي حاجة مطبوعة أو بتوصل للعميل.
 * shared = المكان اللي اللوجو بيستقر فيه بعد الافتتاحية: وقت الافتتاحية والانتقال بيحجز مكانه (مخفي)،
 * واللوجو بيطير له من نص الشاشة (stage.tsx)، وبعدها بيظهر هنا.
 */
export function AppLogo({ height = 28, shared = false }: { height?: number; shared?: boolean }) {
  const { t } = useTranslation();
  const { phase, target } = useStage();
  const hidden = shared && phase !== 'done';
  return (
    <img
      ref={shared ? target : undefined}
      src={height > 64 ? logo : logoSm}
      alt={t('app.name')}
      draggable={false}
      data-testid="app-mark"
      className="block select-none"
      style={{ height, width: Math.round(height * LOGO_RATIO), visibility: hidden ? 'hidden' : undefined }}
    />
  );
}
