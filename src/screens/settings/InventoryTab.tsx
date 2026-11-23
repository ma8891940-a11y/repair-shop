import { useTranslation } from 'react-i18next';
import { useMe } from '../../app/auth';
import { saveExtras } from '../../app/shopExtras';
import { errorMessage } from '../../lib/errors';
import { readAllowNegative } from '../../lib/extras';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Checkbox } from '../../ui/Checkbox';
import { useToast } from '../../ui/Toast';

/** الإعدادات ← المخزون: "السماح بالبيع بدون رصيد" (مقفول افتراضيًا) */
export function InventoryTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const on = readAllowNegative(shop.extras);
  async function toggle(v: boolean) {
    const { error } = await saveExtras({ allow_negative_stock: v });
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  return (
    <Panel data-testid="inventory-settings">
      <PanelHeader title={t('settings.tabs.inventory')} />
      <div className="p-4">
        <Checkbox checked={on} onChange={(v) => void toggle(v)} label={t('item.allowNegative')} />
        <p className="ms-7 mt-0.5 max-w-prose text-2xs text-fg-3">{t('item.allowNegativeHint')}</p>
      </div>
    </Panel>
  );
}
