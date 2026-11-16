import { useTranslation } from 'react-i18next';
import { motion } from 'motion/react';
import { AlertTriangle, CheckCheck } from 'lucide-react';
import { BUILTIN_TEMPLATES, checkKeys, compareChecks, type CheckItem, type CheckItems, type CheckValue, type TemplateItem } from '../lib/checks';
import { useItemLabel } from '../app/checkTemplates';
import { cn } from './cn';

const VALUES: CheckValue[] = ['ok', 'fail', 'na'];
const tone: Record<CheckValue, string> = {
  ok: 'border-[color-mix(in_srgb,var(--ok)_50%,transparent)] bg-ok-soft text-ok',
  fail: 'border-[color-mix(in_srgb,var(--danger)_50%,transparent)] bg-danger-soft text-danger',
  na: 'border-line-strong bg-raised text-fg-2',
};

/** قائمة الفحص السريع: بند في كل سطر وتلات اختيارات (شغال / عطلان / مش متاح). بتتعمل في ثواني بالماوس أو الكيبورد. */
export function QuickCheck({ value, onChange, disabled, items = BUILTIN_TEMPLATES.general }: { value: CheckItems; onChange: (v: CheckItems) => void; disabled?: boolean; items?: TemplateItem[] }) {
  const { t } = useTranslation();
  const label = useItemLabel();
  const set = (item: string, v: CheckValue) => onChange({ ...value, [item]: v });
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-center justify-between">
        <p className="text-2xs text-fg-3">{t('checks.hint')}</p>
        <button
          type="button"
          disabled={disabled}
          onClick={() => onChange({ ...value, ...(Object.fromEntries(items.map((i) => [i.key, 'ok'])) as CheckItems) })}
          className="flex shrink-0 items-center gap-1 rounded-sm px-1.5 py-0.5 text-2xs font-medium text-ok hover:bg-ok-soft"
        >
          <CheckCheck className="size-3.5" /> {t('checks.allOk')}
        </button>
      </div>
      <ul className="grid gap-x-4 gap-y-1 sm:grid-cols-2">
        {items.map(({ key: item }) => (
          <li key={item} className="flex items-center justify-between gap-2 py-0.5">
            <span className="text-sm text-fg">{label(item, null, items)}</span>
            <div className="flex gap-1" role="radiogroup" aria-label={label(item, null, items)}>
              {VALUES.map((v) => (
                <button
                  key={v}
                  type="button"
                  role="radio"
                  aria-checked={value[item as CheckItem] === v}
                  disabled={disabled}
                  onClick={() => set(item, v)}
                  className={cn('h-6 rounded-sm border px-2 text-2xs transition-colors', value[item as CheckItem] === v ? tone[v] : 'border-line text-fg-3 hover:text-fg')}
                >
                  {t(`checks.${v}`)}
                </button>
              ))}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}

/** مقارنة فحص الاستلام بفحص التسليم: اللي كان شغال وباظ بيظهر بالأحمر */
export function CheckCompare({ intake, delivery, items = BUILTIN_TEMPLATES.general, labels }: { intake: CheckItems | null; delivery: CheckItems | null; items?: TemplateItem[]; labels?: Record<string, string> }) {
  const { t } = useTranslation();
  const label = useItemLabel();
  const rows = compareChecks(intake, delivery, checkKeys(items, intake, delivery));
  return (
    <table className="w-full text-sm">
      <thead>
        <tr className="text-xs text-fg-3">
          <th className="py-1 text-start font-medium" />
          <th className="py-1 text-center font-medium">{t('checks.intake')}</th>
          <th className="py-1 text-center font-medium">{t('checks.delivery')}</th>
        </tr>
      </thead>
      <tbody>
        {rows.map((r, i) => (
          <motion.tr key={r.item} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: i * 0.02 }} className={cn('border-t border-glass-border', r.regressed && 'bg-danger-soft')}>
            <td className="py-1.5 text-fg">
              {label(r.item, labels, items)}
              {r.regressed && (
                <span className="ms-2 inline-flex items-center gap-1 text-2xs text-danger">
                  <AlertTriangle className="size-3" /> {t('checks.regressed')}
                </span>
              )}
              {r.fixed && <span className="ms-2 text-2xs text-ok">{t('checks.fixed')}</span>}
            </td>
            {[r.intake, r.delivery].map((v, k) => (
              <td key={k} className="py-1.5 text-center">
                {v ? <span className={cn('rounded-sm border px-1.5 py-0.5 text-2xs', tone[v])}>{t(`checks.${v}`)}</span> : <span className="text-fg-3">{t('common.none')}</span>}
              </td>
            ))}
          </motion.tr>
        ))}
      </tbody>
    </table>
  );
}
