import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { ListCombo } from './ListCombo';
import { isAccessoryType, useListLabel } from './lists';
import { opId, rpc, type StockRow } from './ledgerApi';
import { composeItemName } from '../lib/itemSearch';
import { parsePounds } from '../lib/money';
import { toLatinDigits } from '../lib/digits';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { Field, Input, Select } from '../ui/Field';
import { Button } from '../ui/Button';
import { Alert } from '../ui/Feedback';
import { usePerms } from './perms';

export interface ItemDetails {
  kind: 'part' | 'accessory' | 'service';
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
        <Select value={v.kind} onChange={(e) => set({ kind: e.target.value as ItemDetails['kind'] })} data-testid={`${testid}-kind`}>
          <option value="part">{t('inv.kinds.part')}</option>
          <option value="accessory">{t('inv.kinds.accessory')}</option>
          <option value="service">{t('inv.kinds.service')}</option>
        </Select>
      </Field>
      <Field label={t('item.type')}>
        <ListCombo list="item_types" value={v.item_type} onChange={(x) => set({ item_type: x, ...(isAccessoryType(x) ? { kind: 'accessory' as const } : {}) })} maxLength={60} testid={`${testid}-type`} />
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
export function NewItemInline({ typed, withStock = true, onCreated, onCancel }: { typed: string; withStock?: boolean; onCreated: (row: StockRow) => void; onCancel: () => void }) {
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
  const label = useListLabel();
  // اللون الافتراضي متخزن كود (black)، والاسم بياخد اسمه المعروض
  const composed = useMemo(() => composeItemName({ ...d, color: d.color ? label('colors', d.color) : '' }), [d, label]);
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
      onCreated({
        id: ids.item, kind: d.kind, name: nm, sku: null, sale_price: p, qty: q, avg_cost: q > 0 ? c : null, value: q > 0 && c ? c * q : 0,
        item_type: d.item_type || null, brand: d.brand || null, model: d.model || null, quality: d.quality || null, color: d.color || null, unsettled: 0,
      });
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

/**
 * البيع بكمية أكتر من الرصيد و"السماح بالبيع بدون رصيد" مقفول: البيع موقوف. اللي معاه "المخزون ← المبالغ" يعمل تسوية مخزون بسبب (stock_in)، وبعدين يكمّل البيع.
 */
export function StockInInline({ item, need, onDone }: { item: StockRow; need: number; onDone: (qty: number) => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const [qty, setQty] = useState(String(need));
  const [cost, setCost] = useState(item.avg_cost ? String(item.avg_cost / 100) : '');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [id, setId] = useState(opId);
  // بند 14: تسوية المخزون بصلاحية لوحدها (المخزون ← المبالغ) وسبب، مش جزء من البيع
  const allowed = usePerms().grant('inventory', 'amounts');
  async function save() {
    setErr(null);
    if (!reason.trim()) return setErr(t('errors.E_REASON_REQUIRED'));
    const q = Number(toLatinDigits(qty.trim()));
    if (!Number.isInteger(q) || q <= 0) return setErr(t('inv.errMin'));
    const c = parsePounds(cost);
    if (!c) return setErr(t('item.needCost'));
    setBusy(true);
    try {
      await rpc('stock_in', { p_id: id, p_item: item.id, p_qty: q, p_unit_cost: c, p_note: reason.trim() });
      setId(opId());
      onDone(q);
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <section className="flex flex-col gap-2 rounded-md border border-[color-mix(in_srgb,var(--warn)_45%,transparent)] p-3" data-testid="stock-in-inline">
      <p className="text-xs text-warn">{t(allowed ? 'item.noStock' : 'item.noStockBlocked', { n: f.number(Math.max(item.qty, 0)) })}</p>
      {allowed && (
        <>
          <div className="grid grid-cols-[96px_minmax(0,1fr)_auto] items-end gap-2">
            <Field label={t('inv.cols.qty')}>
              <Input mono inputMode="numeric" value={qty} onChange={(e) => setQty(e.target.value)} data-testid="si-qty" />
            </Field>
            <Field label={t('item.cost')}>
              <Input mono inputMode="decimal" value={cost} onChange={(e) => setCost(e.target.value)} suffix={f.currency()} data-testid="si-cost" />
            </Field>
            <Button size="sm" variant="primary" loading={busy} needsNet onClick={() => void save()} className="mb-0.5" data-testid="si-save">
              {t('item.stockIn')}
            </Button>
          </div>
          <Field label={t('item.adjustReason')} required>
            <Input value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} data-testid="si-reason" />
          </Field>
        </>
      )}
      {err && <Alert tone="danger">{err}</Alert>}
    </section>
  );
}
