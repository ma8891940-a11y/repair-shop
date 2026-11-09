import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Truck } from 'lucide-react';
import { rpc, type StockRow } from '../ledgerApi';
import { parseJsonAnswer, purchaseBody, purchaseSuggestions, readPurchaseAnswer, type StockItem } from '../../lib/assistPayloads';
import { useFormat } from '../../i18n/format';
import { Button } from '../../ui/Button';
import { AssistBox } from '../assist';

type Lines = { supplier: string; lines: { item: string; qty: number }[] };

/**
 * المخزون: اقتراحات الشراء. المحلي (الحد الأدنى وبيع آخر 30 يوم) شغال من غير نت،
 * والذكاء بيكتب اقتراح من أسماء الأصناف وكمياتها بس. "تطبيق" بيفتح فاتورة الشراء متملية، والحفظ بإيدك.
 */
export function PurchaseAssist({ items, onApply }: { items: StockRow[]; onApply: (p: Lines) => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const [sold, setSold] = useState<Map<string, number>>(new Map());
  useEffect(() => {
    let live = true;
    void rpc<{ item_id: string; qty: number }[]>('items_sold30')
      .then((r) => live && setSold(new Map(r.map((x) => [x.item_id, Number(x.qty)]))))
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, []);
  const stock: StockItem[] = items.map((i) => ({ id: i.id, name: i.name, qty: Number(i.qty), min_qty: i.min_qty ?? 0, avg_cost: i.avg_cost == null ? null : Number(i.avg_cost), sold30: sold.get(i.id) ?? 0, supplier_id: i.supplier_id ?? null }));
  const local = purchaseSuggestions(stock);
  const apply = (lines: { item: StockItem; qty: number }[]) => onApply({ supplier: lines.find((l) => l.item.supplier_id)?.item.supplier_id ?? '', lines: lines.map((l) => ({ item: l.item.id, qty: l.qty })) });
  if (!items.length) return null;

  const fallback = (
    <div className="flex flex-col gap-1.5" data-testid="purchase-local">
      <div className="text-2xs text-fg-3">{t('assist.purchase.local')}</div>
      {local.length === 0 ? (
        <p className="text-xs text-fg-3">{t('assist.purchase.none')}</p>
      ) : (
        <>
          <ul className="text-sm">
            {local.slice(0, 8).map((l) => (
              <li key={l.item.id} className="flex justify-between gap-2 py-0.5">
                <span className="text-fg">{l.item.name}</span>
                <span className="num text-fg-2">
                  +{f.number(l.qty)} <span className="text-2xs text-fg-3">({t('assist.purchase.have', { n: f.number(l.item.qty), s: f.number(l.item.sold30 ?? 0) })})</span>
                </span>
              </li>
            ))}
          </ul>
          <Button size="sm" className="self-start" icon={<Truck className="size-4" />} onClick={() => apply(local.slice(0, 8))} data-testid="purchase-local-apply">
            {t('assist.purchase.apply')}
          </Button>
        </>
      )}
    </div>
  );

  return (
    <AssistBox
      area="inventory"
      kind="purchase"
      className="mb-3"
      title={t('assist.purchase.title')}
      askLabel={t('assist.purchase.ask')}
      testid="assist-purchase"
      privacy={t('assist.privacyItems')}
      build={() => purchaseBody(stock.filter((s) => s.qty <= (s.min_qty ?? 0) * 2 || (s.sold30 ?? 0) > 0))}
      fallback={fallback}
      render={(answer) => {
        const r = readPurchaseAnswer(parseJsonAnswer(answer), stock);
        if (!r.lines.length) return <p className="whitespace-pre-wrap">{r.note || answer}</p>;
        return (
          <div className="flex flex-col gap-2">
            <ul>
              {r.lines.map((l) => (
                <li key={l.item.id} className="py-0.5">
                  <span className="text-fg">{l.item.name}</span> <span className="num text-accent">+{f.number(l.qty)}</span>
                  {l.why && <span className="text-2xs text-fg-3"> · {l.why}</span>}
                </li>
              ))}
            </ul>
            {r.note && <p className="text-xs text-fg-2">{r.note}</p>}
            <Button size="sm" variant="primary" className="self-start" icon={<Truck className="size-4" />} onClick={() => apply(r.lines)} data-testid="assist-purchase-apply">
              {t('assist.purchase.apply')}
            </Button>
          </div>
        );
      }}
    />
  );
}
