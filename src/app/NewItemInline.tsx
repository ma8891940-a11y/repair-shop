import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ListCombo } from './ListCombo';
import { ACCESSORY_TYPES } from './lists';
import { opId, rpc } from './ledgerApi';
import { composeItemName } from '../lib/itemSearch';
import { parsePounds } from '../lib/money';
import { toLatinDigits } from '../lib/digits';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Field, Input, Select } from '../ui/Field';
import { Button } from '../ui/Button';
import { Alert } from '../ui/Feedback';

export interface ItemDetails {
  kind: 'part' | 'accessory';
  item_type: string;
  brand: string;
  model: string;
  quality: string;
  color: string;
}

/** خانات الصنف بالتفصيل (النوع والماركة والموديل والجودة واللون)، وكل خانة قايمة ملء سريع */
export function ItemDetailFields({ v, set, testid = 'item' }: { v: ItemDetails; set: (p: Partial<ItemDetails>) => void; testid?: string }) {
  const { t } = useTranslation();
  return (
    <div className="grid grid-cols-2 gap-2 sm:grid-cols-3">
      <Field label={t('inv.cols.kind')}>
        <Select value={v.kind} onChange={(e) => set({ kind: e.target.value as 'part' | 'accessory' })} data-testid={`${testid}-kind`}>
          <option value="part">{t('inv.kinds.part')}</option>
          <option value="accessory">{t('inv.kinds.accessory')}</option>
        </Select>
      </Field>
      <Field label={t('item.type')}>
        <ListCombo list="item_types" value={v.item_type} onChange={(x) => set({ item_type: x, ...(ACCESSORY_TYPES.includes(x.trim()) ? { kind: 'accessory' as const } : {}) })} maxLength={60} testid={`${testid}-type`} />
      </Field>
      <Field label={t('inv.brand')}>
        <ListCombo list="brands" value={v.brand} onChange={(x) => set({ brand: x })} maxLength={60} dir="auto" testid={`${testid}-brand`} />
      </Field>
      <Field label={t('item.model')}>
        <ListCombo list="models" value={v.model} onChange={(x) => set({ model: x })} maxLength={80} dir="auto" testid={`${testid}-model`} />
      </Field>
      <Field label={t('item.quality')}>
        <ListCombo list="qualities" value={v.quality} onChange={(x) => set({ quality: x })} maxLength={60} testid={`${testid}-quality`} />
      </Field>
      <Field label={t('item.color')}>
        <ListCombo list="colors" value={v.color} onChange={(x) => set({ color: x })} maxLength={40} testid={`${testid}-color`} />
      </Field>
    </div>
  );
}

export const emptyDetails = (): ItemDetails => ({ kind: 'part', item_type: '', brand: '', model: '', quality: '', color: '' });

/**
 * "إضافة صنف جديد «...»" جوه نفس النافذة: الخانات، والاسم بيتكوّن لوحده (وتقدر تعدّله)، والتكلفة وسعر البيع والكمية اللي عندك.
 * بيتحفظ (create_item) ويتختار على طول عشان تكمّل البيع أو الشراء.
 */
export function NewItemInline({ typed, withStock = true, onCreated, onCancel }: { typed: string; withStock?: boolean; onCreated: (id: string) => void; onCancel: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const [d, setD] = useState<ItemDetails>(emptyDetails);
  const [name, setName] = useState(typed);
  const [nameEdited, setNameEdited] = useState(!!typed);
  const [cost, setCost] = useState('');
  const [price, setPrice] = useState('');
  const [qty, setQty] = useState(withStock ? '1' : '0');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [ids] = useState(() => ({ item: opId(), stock: opId() }));
  const composed = useMemo(() => composeItemName(d), [d]);
  const shownName = nameEdited ? name : composed;
  const set = (p: Partial<ItemDetails>) => {
    setD((c) => ({ ...c, ...p }));
    // الاسم اللي اتكتب في البحث بيتغيّر لوحده أول ما تختار خانة (إلا لو عدّلته بإيدك هنا)
    if (nameEdited && name === typed) setNameEdited(false);
  };
  async function save() {
    setErr(null);
    const nm = shownName.trim();
    if (!nm) return setErr(t('inv.errName'));
    const q = Number(toLatinDigits(qty.trim() || '0'));
    if (!Number.isInteger(q) || q < 0) return setErr(t('inv.errMin'));
    const c = cost.trim() ? parsePounds(cost) : null;
    const p = price.trim() ? parsePounds(price) : null;
    if ((cost.trim() && c == null) || (price.trim() && p == null)) return setErr(t('fin.errAmount'));
    if (q > 0 && !c) return setErr(t('item.needCost'));
    setBusy(true);
    try {
      await rpc('create_item', {
        p_id: ids.item, p_kind: d.kind, p_name: nm, p_item_type: d.item_type || null, p_brand: d.brand || null, p_model: d.model || null,
        p_quality: d.quality || null, p_color: d.color || null, p_sale_price: p, p_qty: q, p_unit_cost: c, p_stock_id: ids.stock,
      });
      onCreated(ids.item);
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="flex flex-col gap-2 rounded-md border border-[rgb(var(--accent-rgb)/0.4)] bg-accent-soft/30 p-3" data-testid="new-item-inline">
      <div className="text-sm font-medium text-fg">{t('item.newTitle')}</div>
      <ItemDetailFields v={d} set={set} testid="ni" />
      <Field label={t('item.name')} hint={t('item.nameHint')}>
        <Input
          value={shownName}
          onChange={(e) => {
            setName(e.target.value);
            setNameEdited(true);
          }}
          maxLength={160}
          data-testid="ni-name"
        />
      </Field>
      <div className="grid grid-cols-3 gap-2">
        <Field label={t('item.cost')}>
          <Input mono inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} suffix={f.currency()} data-testid="ni-cost" />
        </Field>
        <Field label={t('inv.cols.price')}>
          <Input mono inputMode="decimal" value={price} onChange={(e) => setPrice(e.target.value)} suffix={f.currency()} data-testid="ni-price" />
        </Field>
        <Field label={t('item.onHand')}>
          <Input mono inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="ni-qty" />
        </Field>
      </div>
      {err && <Alert tone="danger">{err}</Alert>}
      <div className="flex justify-end gap-2">
        <Button size="sm" variant="ghost" onClick={onCancel}>
          {t('common.cancel')}
        </Button>
        <Button size="sm" variant="primary" loading={busy} needsNet onClick={() => void save()} data-testid="ni-save">
          {t('item.saveAndPick')}
        </Button>
      </div>
    </section>
  );
}
