import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { usePrefs } from '../app/prefs';
import logo from '../assets/app-logo.png';
import logoSm from '../assets/app-logo-sm.png';

/**
 * لوجو التطبيق (بتاع صاحب المشروع، brand/app-logo.png) كما هو من غير أي تعديل في الشكل أو الألوان أو النسب.
 * مكانه جوه التطبيق بس: الافتتاحية، والدخول، والشريط الجانبي، ومعالج التسجيل. ممنوع على أي حاجة مطبوعة أو بتوصل للعميل.
 * height بالبكسل، والعرض بيتحسب من نسبة اللوجو. intro = ظهور الافتتاحية (أقل من 1.2 ثانية، وبيتلغي مع تقليل الحركة).
 */
export function AppLogo({ height = 28, intro = false }: { height?: number; intro?: boolean }) {
  const { t } = useTranslation();
  const { calm } = usePrefs();
  const src = height > 64 ? logo : logoSm;
  const img = <img src={src} alt={t('app.name')} height={height} style={{ height, width: 'auto' }} className="block select-none" draggable={false} data-testid="app-mark" />;
  if (!intro || calm) return img;
  return (
    <motion.div initial={{ opacity: 0, scale: 0.92, filter: 'blur(6px)' }} animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }} transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}>
      {img}
    </motion.div>
  );
}
