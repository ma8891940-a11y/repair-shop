import { useEffect, useMemo, useRef, useState, useLayoutEffect } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { AlertTriangle, Barcode as BarcodeIcon, Camera, FileUp, MessageCircle, PackageMinus, PackagePlus, Plus, Printer, RotateCcw, ScanBarcode, Search, ShoppingCart, Trash2, Truck, Undo2 } from 'lucide-react';
import { PageHeader, useLiveRefresh } from '../../app/AppShell';
import { useLoad, must } from '../../app/useLoad';
import { useMe } from '../../app/auth';
import { useBranch } from '../../app/branch';
import { BranchStock } from '../../app/finance/BranchStock';
import { loadCashboxes, opId, rpc, useAccountName, type Cashbox, type StockRow } from '../../app/ledgerApi';
import { supabase } from '../../lib/supabase';
import { parsePounds } from '../../lib/money';
import { toLatinDigits } from '../../lib/digits';
import { waLink } from '../../lib/messages';
import { shortageOrders } from '../../lib/inventory';
import { errorMessage } from '../../lib/errors';
import { useFormat } from '../../i18n/format';
import { Panel } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input, Select } from '../../ui/Field';
import { Alert, EmptyState, ErrorState, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';
import { cn } from '../../ui/cn';
import { DeleteDialog } from '../../app/DeleteDialog';
import { useListLabel, useShopList } from '../../app/lists';
import { ListCombo } from '../../app/ListCombo';
import { BulkEditDialog, ImportDialog, InvOpDialog, ItemMoves, ScanDialog, type InvOp, type InvSummary } from './InventoryOps';
import { PeriodFilter, usePeriod } from '../../app/finance/PeriodFilter';
import { newInternalEan13 } from '../../lib/barcode';
import { plainPounds, toCsv } from '../../lib/ledger';
import { ExportMenu } from '../../app/exporting';
import { shouldQueue, useSync } from '../../offline/sync';
import { PurchaseAssist } from '../../app/assist/PurchaseAssist';
import type { ExportTable } from '../../lib/xlsx';
import { Checkbox } from '../../ui/Checkbox';
import { ItemPicker } from '../../app/ItemPicker';
import { usePerms } from '../../app/perms';
import { ItemDetailFields, NewItemInline, StockInInline, emptyDetails, type ItemDetails } from '../../app/NewItemInline';
import { composeItemName, matches } from '../../lib/itemSearch';
import { readAllowNegative } from '../../lib/extras';
import { logoUploadError, prepareLogoUpload } from '../../lib/brandImage';
import { CategorySelect } from '../CategoriesScreen';

interface Supplier {
  id: string;
  name: string;
  phone: string | null;
}

/** المخزون (القطع والإكسسوارات) بالكمية والمتوسط المرجّح، والموردين */
export function InventoryScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile, shop } = useMe();
  const owner = profile.role === 'owner';
  // P (المرحلة التانية): اللي صاحب المحل اداه للموظف زيادة على دوره
  const { grant } = usePerms();
  const canBuy = grant('purchases', 'add');
  const canSup = grant('purchases', 'view');
  const canSupReturn = grant('purchases', 'edit');
  const canWriteOff = grant('inventory', 'delete');
  const amounts = grant('inventory', 'amounts');
  const canReports = grant('reports');
  const [tab, setTab] = useState<'items' | 'suppliers' | 'summary'>('items');
  const [q, setQ] = useState('');
  const [cat, setCat] = useState('');
  const [brandF, setBrandF] = useState('');
  // S6: فلاتر بالنوع والموديل والجودة
  const [typeF, setTypeF] = useState('');
  const [modelF, setModelF] = useState('');
  const [qualF, setQualF] = useState('');
  const [sel, setSel] = useState<Set<string>>(new Set());
  const [bulk, setBulk] = useState<string[] | null>(null);
  const [invOp, setInvOp] = useState<InvOp | null>(null);
  const [importing, setImporting] = useState(false);
  const [scan, setScan] = useState(false);
  const [preset, setPreset] = useState<{ supplier: string; lines: { item: string; qty: number }[] } | null>(null);
  const front = profile.role === 'owner' || profile.role === 'reception';
  // من القايمة الجانبية: ?do=sale|purchase|write_off بيفتح العملية على طول، و?tab=suppliers بيفتح الموردين
  const [params, setParams] = useSearchParams();
  const want = params.get('do');
  const wantItem = params.get('item');
  const wantTab = params.get('tab');
  useEffect(() => {
    if ((wantTab === 'suppliers' && canSup) || (wantTab === 'summary' && canReports)) setTab(wantTab);
    else if (!want) setTab((t0) => (t0 === 'suppliers' && !wantTab ? 'items' : t0));
    if (want === 'sale' && front) {
      // K: ?do=sale&item=<id> من تصفح التصنيفات بيفتح البيع بالصنف ده
      if (wantItem) setPreset({ supplier: '', lines: [{ item: wantItem, qty: 1 }] });
      setDlg('sale');
    }
    else if (want === 'purchase' && canBuy) setDlg('purchase');
    else if ((want === 'write_off' && canWriteOff) || (want === 'supplier_return' && canSupReturn)) setInvOp(want);
    else if (want === 'sale_return' && front) setInvOp('sale_return');
  }, [want, wantTab, wantItem, owner, front, canSup, canReports, canBuy, canWriteOff, canSupReturn]);
  // لما العملية تتقفل، الرابط يرجع للمخزون عادي (عشان "رجوع" ما يفتحهاش تاني)
  const clearDo = () => want && setParams({}, { replace: true });
  const [dlg, setDlg] = useState<'item' | 'purchase' | 'sale' | 'supplier' | null>(null);
  const [onlyShort, setOnlyShort] = useState(false);
  const [detail, setDetail] = useState<StockRow | null>(null);
  const br = useBranch();
  const { data, error, loading, reload } = useLoad(async () => {
    // B: الفرع الشغال، أو كل الفروع لو العرض "كل الفروع"
    const items = await rpc<StockRow[]>('items_stock', br.view === 'all' && br.multi ? { p_all: true } : {});
    const suppliers = canSup ? (must(await supabase.from('suppliers').select('id, name, phone').is('deleted_at', null).order('name')) as Supplier[]) : [];
    const bal = canSup && grant('finance') ? await rpc<{ party_id: string; balance: number }[]>('party_balances', { p_kind: 'suppliers' }) : [];
    return { items: items.map((i) => ({ ...i, qty: Number(i.qty), avg_cost: i.avg_cost == null ? null : Number(i.avg_cost), value: i.value == null ? null : Number(i.value), unsettled: Number(i.unsettled ?? 0) })), suppliers, bal: new Map(bal.map((b) => [b.party_id, Number(b.balance)])) };
    // البند 14: آخر نسخة بتتحفظ على الجهاز، فالمخزون والبيع بيفتحوا من غير نت
  }, [owner, canSup, br.view], { cacheKey: `inventory:${profile.id}:${br.view}` });
  useLiveRefresh(reload);
  const cur = f.currency(shop.currency);
  const totalValue = (data?.items ?? []).reduce((a, i) => a + (i.value ?? 0), 0);
  const shortCount = (data?.items ?? []).filter((i) => i.short).length;
  const orders = useMemo(() => (data ? shortageOrders(data.items, data.suppliers) : []), [data]);
  const cats = useMemo(() => [...new Set((data?.items ?? []).map((i) => i.category).filter((c): c is string => !!c))].sort(), [data]);
  // الماركات: من قايمة الماركات (نفس اللي في الاستلام) + اللي على الأصناف فعلًا
  const brandList = useShopList('brands').items;
  const brands = useMemo(() => [...new Set([...brandList.map((b) => b.value), ...(data?.items ?? []).map((i) => i.brand).filter((b): b is string => !!b)])].sort(), [brandList, data]);
  const distinct = (k: 'item_type' | 'model' | 'quality') => [...new Set((data?.items ?? []).map((i) => i[k]).filter((x): x is string => !!x))].sort();
  const types = useMemo(() => distinct('item_type'), [data]); // eslint-disable-line react-hooks/exhaustive-deps
  const models = useMemo(() => distinct('model'), [data]); // eslint-disable-line react-hooks/exhaustive-deps
  const quals = useMemo(() => distinct('quality'), [data]); // eslint-disable-line react-hooks/exhaustive-deps
  const unsettledCount = (data?.items ?? []).filter((i) => (i.unsettled ?? 0) > 0).length;
  // البحث: جزء من الكلمة، بالعربي أو الإنجليزي، في الاسم والنوع والماركة والموديل والجودة والباركود (نفس بحث خانة الصنف)
  const shown = (data?.items ?? []).filter(
    (i) => (!onlyShort || i.short) && (!cat || i.category === cat) && (!brandF || i.brand === brandF) && (!typeF || i.item_type === typeF) && (!modelF || i.model === modelF) && (!qualF || i.quality === qualF) && matches(i, q),
  );
  /** قارئ الباركود بيكتب الرقم ويدوس Enter: لو مطابق لصنف، بيفتح تفاصيله على طول */
  function onCode(code: string) {
    const c = toLatinDigits(code.trim());
    setQ(c);
    const hit = data?.items.find((i) => i.barcode === c || i.sku === c);
    if (!hit || !owner) return;
    // التركيز لسه في خانة البحث: لو النافذة اتفتحت على طول، بتعتبره "ضغط برا" وتتقفل. فبنسيب الخانة الأول
    (document.activeElement as HTMLElement | null)?.blur();
    setTimeout(() => setDetail(hit), 0);
  }
  function exportCsv() {
    if (!data) return;
    const head = [t('inv.cols.name'), t('inv.cols.kind'), t('inv.category'), t('barcode.code'), t('inv.cols.qty'), t('inv.minQty'), t('inv.cols.price')];
    if (amounts) head.push(t('inv.cols.avg'), t('inv.cols.value'));
    const rows = shown.map((i) => {
      const r: (string | number)[] = [i.name, t(`inv.kinds.${i.kind}`), i.category ?? '', i.barcode ?? '', i.qty, i.min_qty ?? 0, i.sale_price != null ? plainPounds(i.sale_price) : ''];
      if (amounts) r.push(i.avg_cost != null ? plainPounds(i.avg_cost) : '', plainPounds(i.value ?? 0));
      return r;
    });
    const blob = new Blob([toCsv([head, ...rows])], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `inventory-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  }
  // Excel وPDF: نفس الأصناف الظاهرة (بالبحث والتصنيف و"الناقص بس")، ونفس أعمدة ملف CSV
  const itemsTable = (): ExportTable => ({
    title: t('inv.title'),
    meta: [cat ? t('export.filter', { v: cat }) : '', onlyShort ? t('export.filter', { v: t('inv.onlyShort') }) : '', q.trim() ? t('export.search', { v: q.trim() }) : ''].filter(Boolean),
    columns: [
      { header: t('inv.cols.name') },
      { header: t('inv.cols.kind') },
      { header: t('inv.category') },
      { header: t('barcode.code') },
      { header: t('inv.cols.qty'), type: 'int', total: true },
      { header: t('inv.minQty'), type: 'int' },
      { header: t('inv.cols.price'), type: 'money' },
      ...(amounts ? [{ header: t('inv.cols.avg'), type: 'money' as const }, { header: t('inv.cols.value'), type: 'money' as const, total: true }] : []),
    ],
    rows: shown.map((i) => [i.name, t(`inv.kinds.${i.kind}`), i.category, i.barcode, i.qty, i.min_qty ?? 0, i.sale_price, ...(amounts ? [i.avg_cost, i.value ?? 0] : [])]),
  });
  const suppliersTable = (): ExportTable | null | undefined =>
    data && {
      title: t('inv.tabs.suppliers'),
      columns: [{ header: t('inv.cols.name') }, { header: t('customers.cols.phone') }, { header: t('fin.balances.suppliers'), type: 'money', total: true }],
      rows: data.suppliers.map((s) => [s.name, s.phone, data.bal.get(s.id) ?? 0]),
    };
  const toggle = (id: string) =>
    setSel((cur) => {
      const n = new Set(cur);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });

  return (
    <div className="max-w-6xl">
      <PageHeader
        title={t('inv.title')}
        sub={amounts ? t('inv.subOwner', { v: `${f.money(totalValue)} ${cur}` }) : t('inv.sub')}
        actions={
          <div className="flex flex-wrap gap-2">
            {front && (
              <Button size="sm" icon={<ShoppingCart className="size-4" />} onClick={() => setDlg('sale')} data-testid="op-sale">
                {t('inv.sale')}
              </Button>
            )}
            {front && (
              <Button size="sm" variant="ghost" icon={<Undo2 className="size-4" />} onClick={() => setInvOp('sale_return')} data-testid="op-sale_return">
                {t('invop.title.sale_return')}
              </Button>
            )}
            {canWriteOff && (
              <Button size="sm" variant="ghost" icon={<PackageMinus className="size-4" />} onClick={() => setInvOp('write_off')} data-testid="op-write_off">
                {t('invop.title.write_off')}
              </Button>
            )}
            {canSupReturn && (
              <Button size="sm" variant="ghost" icon={<RotateCcw className="size-4" />} onClick={() => setInvOp('supplier_return')} data-testid="op-supplier_return">
                {t('invop.title.supplier_return')}
              </Button>
            )}
            {canBuy && (
              <Button size="sm" icon={<Truck className="size-4" />} onClick={() => setDlg('purchase')}>
                {t('inv.purchase')}
              </Button>
            )}
            {(owner || (tab === 'suppliers' && grant('purchases', 'add'))) && (
              <>
                <Button size="sm" variant="primary" icon={<Plus className="size-4" />} onClick={() => setDlg(tab === 'items' ? 'item' : 'supplier')}>
                  {tab === 'items' ? t('inv.addItem') : t('inv.addSupplier')}
                </Button>
              </>
            )}
          </div>
        }
      />
      {(canSup || canReports) && (
        <div className="glass mb-3 inline-flex rounded-md p-1" role="tablist">
          {(['items', 'suppliers', 'summary'] as const).filter((k) => k === 'items' || (k === 'suppliers' ? canSup : canReports)).map((k) => (
            <button key={k} type="button" role="tab" aria-selected={tab === k} onClick={() => setTab(k)} className={cn('h-7 rounded-sm px-3 text-sm', tab === k ? 'bg-accent-soft text-fg' : 'text-fg-3 hover:text-fg')}>
              {t(`inv.tabs.${k}`)}
            </button>
          ))}
        </div>
      )}
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading || !data ? (
        <Skeleton className="h-48 w-full" />
      ) : tab === 'items' ? (
        <>
        {owner && (
          <PurchaseAssist
            items={data.items}
            onApply={(p) => {
              setPreset(p);
              setDlg('purchase');
            }}
          />
        )}
        {unsettledCount > 0 && (
          <div className="mb-3" data-testid="unsettled-banner">
            <Alert tone="danger">{t('item.unsettledBanner', { n: unsettledCount })}</Alert>
          </div>
        )}
        {shortCount > 0 && (
          <Panel className="mb-3 flex flex-wrap items-center gap-3 border-[color-mix(in_srgb,var(--warn)_40%,var(--glass-border))] p-3" data-testid="shortages">
            <AlertTriangle className="size-4 text-warn" aria-hidden />
            <span className="text-sm text-fg">{t('inv.shortages', { n: shortCount })}</span>
            <button type="button" onClick={() => setOnlyShort((v) => !v)} aria-pressed={onlyShort} className={cn('h-7 rounded-sm px-2.5 text-xs', onlyShort ? 'bg-accent-soft text-fg' : 'text-fg-3 hover:text-fg')}>
              {t('inv.onlyShort')}
            </button>
            {canBuy && (
              <div className="ms-auto flex flex-wrap gap-2">
                {orders.map((o) => (
                  <Button key={`buy-${o.supplierId}`} size="sm" icon={<Truck className="size-3.5" />} onClick={() => { setPreset({ supplier: o.supplierId, lines: o.lines.map((l) => ({ item: l.itemId, qty: l.qty })) }); setDlg('purchase'); }} data-testid="buy-short">
                    {t('inv.buyShort', { s: o.name })}
                  </Button>
                ))}
                {orders.map((o) => {
                  const link = o.phone ? waLink(o.phone, `${t('inv.orderMsg', { shop: shop.name })}\n${o.lines.map((l) => `- ${l.name}: ${l.qty}`).join('\n')}`) : null;
                  return link ? (
                    <a key={o.supplierId} href={link} target="_blank" rel="noopener noreferrer" className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-xs text-fg-2 hover:border-accent hover:text-fg" data-testid="order-link">
                      <MessageCircle className="size-3.5 text-ok" aria-hidden /> {t('inv.orderFrom', { s: o.name })}
                    </a>
                  ) : (
                    <span key={o.supplierId} className="text-2xs text-fg-3">{t('inv.noSupplierPhone', { s: o.name })}</span>
                  );
                })}
              </div>
            )}
          </Panel>
        )}
        <Panel className="mb-3 flex flex-wrap items-center gap-2 p-3">
          <div className="relative min-w-[200px] flex-1">
            <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
            <input
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key !== 'Enter') return;
                e.preventDefault();
                onCode(q);
              }}
              placeholder={t('inv.search')}
              aria-label={t('inv.search')}
              className="h-8 w-full rounded-md border border-line bg-sunken/60 pe-3 ps-9 text-sm text-fg placeholder:text-fg-3 focus:border-accent focus:outline-none"
              data-testid="inv-search"
            />
          </div>
          {cats.length > 0 && (
            <Select value={cat} onChange={(e) => setCat(e.target.value)} aria-label={t('inv.category')} className="h-8 w-auto">
              <option value="">{t('inv.allCats')}</option>
              {cats.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </Select>
          )}
          <Select value={brandF} onChange={(e) => setBrandF(e.target.value)} aria-label={t('inv.brand')} className="h-8 w-auto" data-testid="inv-brand-filter">
            <option value="">{t('inv.allBrands')}</option>
            {brands.map((b) => (
              <option key={b} value={b}>
                {b}
              </option>
            ))}
          </Select>
          {(
            [
              [types, typeF, setTypeF, 'item.allTypes', 'inv-type-filter'],
              [models, modelF, setModelF, 'item.allModels', 'inv-model-filter'],
              [quals, qualF, setQualF, 'item.allQualities', 'inv-quality-filter'],
            ] as const
          ).map(([opts, v, setV, lbl, tid]) =>
            opts.length > 0 ? (
              <Select key={tid} value={v} onChange={(e) => setV(e.target.value)} aria-label={t(lbl)} className="h-8 w-auto" data-testid={tid}>
                <option value="">{t(lbl)}</option>
                {opts.map((o) => (
                  <option key={o} value={o}>
                    {o}
                  </option>
                ))}
              </Select>
            ) : null,
          )}
          <Button size="sm" variant="ghost" icon={<Camera className="size-4" />} onClick={() => setScan(true)}>
            {t('scan.title')}
          </Button>
          <ExportMenu table={itemsTable} csv={exportCsv} testid="inv-export" />
          {owner && (
            <Button size="sm" variant="ghost" icon={<FileUp className="size-4" />} onClick={() => setImporting(true)} data-testid="inv-import">
              {t('import.title')}
            </Button>
          )}
          {owner && sel.size > 0 && (
            <Button size="sm" variant="primary" onClick={() => setBulk([...sel])} data-testid="bulk-edit">
              {t('bulk.title', { n: sel.size })}
            </Button>
          )}
        </Panel>
        {data.items.length === 0 ? (
          <Panel>
            <EmptyState line="chip" title={t('inv.empty')}>
              {t('inv.emptyText')}
            </EmptyState>
          </Panel>
        ) : (
          <Panel className="overflow-x-auto">
            <table className="w-full min-w-[560px] text-sm">
              <thead className="text-2xs text-fg-3">
                <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                  {owner && (
                    <th className="w-8">
                      <span className="sr-only">{t('bulk.select')}</span>
                    </th>
                  )}
                  <th>{t('inv.cols.name')}</th>
                  <th>{t('inv.cols.kind')}</th>
                  <th className="!text-end">{t('inv.cols.qty')}</th>
                  {amounts && <th className="!text-end">{t('inv.cols.avg')}</th>}
                  {amounts && <th className="!text-end">{t('inv.cols.value')}</th>}
                  {(profile.role === 'owner' || profile.role === 'reception') && <th className="!text-end">{t('inv.cols.price')}</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-glass-border">
                {shown.map((i) => (
                  <tr key={i.id} className={cn('[&_td]:px-3 [&_td]:py-2', owner && 'cursor-pointer hover:bg-raised/50')} data-testid="item-row" onClick={() => owner && setDetail(i)}>
                    {owner && (
                      <td onClick={(e) => e.stopPropagation()}>
                        <Checkbox checked={sel.has(i.id)} onChange={() => toggle(i.id)} label={<span className="sr-only">{i.name}</span>} />
                      </td>
                    )}
                    <td className="text-fg">
                      {owner ? (
                        <button type="button" className="text-start hover:text-accent" onClick={() => setDetail(i)}>
                          {i.name}
                        </button>
                      ) : (
                        i.name
                      )}
                      {(i.unsettled ?? 0) > 0 && (
                        <span className="ms-2 rounded-full border border-[color-mix(in_srgb,var(--danger)_50%,transparent)] px-1.5 text-2xs text-danger" title={t('item.unsettledHint')} data-testid="item-unsettled">
                          {t('item.unsettled', { n: f.number(i.unsettled ?? 0) })}
                        </span>
                      )}
                      {i.short && <span className="ms-2 rounded-full border border-[color-mix(in_srgb,var(--warn)_45%,transparent)] px-1.5 text-2xs text-warn">{t('inv.short')}</span>}
                      {(i.barcode || i.sku) && (
                        <span className="num ms-2 text-2xs text-fg-3" dir="ltr">
                          {i.barcode ?? i.sku}
                        </span>
                      )}
                    </td>
                    <td className="text-fg-2">
                      {t(`inv.kinds.${i.kind}`)}
                      {i.category && <div className="text-2xs text-fg-3">{i.category}</div>}
                    </td>
                    <td className={cn('num text-end', i.qty <= 0 ? 'text-danger' : 'text-fg')}>{f.number(i.qty)}</td>
                    {amounts && <td className="num text-end text-fg-2">{i.avg_cost != null ? f.money(i.avg_cost) : t('common.none')}</td>}
                    {amounts && <td className="num text-end text-fg">{f.money(i.value ?? 0)}</td>}
                    {(profile.role === 'owner' || profile.role === 'reception') && <td className="num text-end text-fg-2">{i.sale_price != null ? f.money(i.sale_price) : t('common.none')}</td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </Panel>
        )}
        </>
      ) : tab === 'summary' ? (
        <InventorySummary />
      ) : (
        <>
        <div className="mb-2 flex justify-end">
          <ExportMenu table={suppliersTable} testid="suppliers-export" />
        </div>
        {data.suppliers.length === 0 ? (
        <Panel>
          <EmptyState line="store" title={t('inv.noSuppliers')} />
        </Panel>
      ) : (
        <Panel>
          <ul className="divide-y divide-glass-border">
            {data.suppliers.map((s) => (
              <li key={s.id}>
                <Link to={`/finance/supplier/${s.id}`} className="flex items-center gap-3 px-4 py-2.5 text-sm hover:bg-raised/50" data-testid="supplier-row">
                  <span className="min-w-0 flex-1 truncate text-fg">
                    <bdi>{s.name}</bdi>
                  </span>
                  {s.phone && (
                    <span className="num text-xs text-fg-3" dir="ltr">
                      {s.phone}
                    </span>
                  )}
                  <span className="num w-28 text-end text-fg">{f.money(data.bal.get(s.id) ?? 0)}</span>
                </Link>
              </li>
            ))}
          </ul>
        </Panel>
        )}
        </>
      )}
      <ItemDialog open={dlg === 'item'} onOpenChange={(v) => !v && setDlg(null)} onDone={reload} suppliers={data?.suppliers ?? []} />
      <ItemDetailDialog item={detail} onOpenChange={(v) => !v && setDetail(null)} suppliers={data?.suppliers ?? []} onDone={reload} />
      <SupplierDialog open={dlg === 'supplier'} onOpenChange={(v) => !v && setDlg(null)} onDone={reload} />
      {data && (
        <LinesDialog
          mode="purchase"
          open={dlg === 'purchase'}
          preset={preset}
          onOpenChange={(v) => {
            if (!v) {
              setDlg(null);
              setPreset(null);
              clearDo();
            }
          }}
          items={data.items}
          suppliers={data.suppliers}
          onDone={reload}
        />
      )}
      <InvOpDialog
        op={invOp}
        items={data?.items ?? []}
        suppliers={data?.suppliers ?? []}
        onOpenChange={(v) => {
          if (!v) {
            setInvOp(null);
            clearDo();
          }
        }}
        onDone={reload}
      />
      <BulkEditDialog
        ids={bulk}
        onOpenChange={(v) => !v && setBulk(null)}
        onDone={() => {
          setSel(new Set());
          reload();
        }}
      />
      <ImportDialog open={importing} onOpenChange={setImporting} existing={data?.items ?? []} onDone={reload} />
      <ScanDialog open={scan} onOpenChange={setScan} onCode={onCode} />
      {data && (
        <LinesDialog
          mode="sale"
          open={dlg === 'sale'}
          onOpenChange={(v) => {
            if (!v) {
              setDlg(null);
              setPreset(null);
              clearDo();
            }
          }}
          items={data.items}
          suppliers={[]}
          preset={wantItem ? preset : null}
          onDone={reload}
        />
      )}
    </div>
  );
}

function ItemDialog({ open, onOpenChange, onDone, suppliers }: { open: boolean; onOpenChange: (v: boolean) => void; onDone: () => void; suppliers: Supplier[] }) {
  const { t } = useTranslation();
  const { shop } = useMe();
  const f = useFormat();
  const toast = useToast();
  const [d, setD] = useState<ItemDetails>(emptyDetails);
  const [name, setName] = useState('');
  const [nameEdited, setNameEdited] = useState(false);
  const [sku, setSku] = useState('');
  const [newCat, setNewCat] = useState('');
  const [price, setPrice] = useState('');
  const [minQty, setMinQty] = useState('0');
  const [supplier, setSupplier] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (open) {
      setD(emptyDetails());
      setName('');
      setNameEdited(false);
      setSku('');
      setNewCat('');
      setPrice('');
      setMinQty('0');
      setSupplier('');
      setErr(null);
    }
  }, [open]);
  // S6: الاسم بيتكوّن لوحده من الخانات، وتقدر تعدّله
  const listLabel = useListLabel();
  const shownName = nameEdited ? name : composeItemName({ ...d, color: d.color ? listLabel('colors', d.color) : '' });
  async function save() {
    const nm = shownName.trim();
    if (!nm) return setErr(t('inv.errName'));
    const p = price.trim() ? parsePounds(price) : null;
    if (price.trim() && p == null) return setErr(t('fin.errAmount'));
    const mq = Number(toLatinDigits(minQty.trim() || '0'));
    if (!Number.isInteger(mq) || mq < 0) return setErr(t('inv.errMin'));
    setBusy(true);
    const { error } = await supabase.from('items').insert({
      id: crypto.randomUUID(), shop_id: shop.id, kind: d.kind, name: nm, sku: toLatinDigits(sku.trim()) || null, sale_price: p, min_qty: mq, supplier_id: supplier || null,
      brand: d.brand.trim() || null, category_id: newCat || null, item_type: d.item_type.trim() || null, model: d.model.trim() || null, quality: d.quality.trim() || null, color: d.color.trim() || null,
    });
    setBusy(false);
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('inv.itemAdded') });
    onOpenChange(false);
    onDone();
  }
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('inv.addItem')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <ItemDetailFields v={d} set={(x) => setD((c) => ({ ...c, ...x }))} testid="new-item" />
        <Field label={t('inv.cols.name')} hint={t('item.nameHint')} required>
          <Input
            value={shownName}
            onChange={(e) => {
              setName(e.target.value);
              setNameEdited(true);
            }}
            maxLength={160}
            data-testid="new-item-name"
          />
        </Field>
        <Field label={t('inv.category')}>
          <CategorySelect value={newCat} onChange={setNewCat} testid="new-item-category" />
        </Field>
        <Field label={t('inv.sku')}>
          <Input dir="ltr" mono value={sku} onChange={(e) => setSku(e.target.value)} />
        </Field>
        <Field label={t('inv.cols.price')}>
          <Input dir="ltr" inputMode="decimal" mono value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0" suffix={f.currency(shop.currency)} className="text-start" />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label={t('inv.minQty')} hint={t('inv.minQtyHint')}>
            <Input dir="ltr" inputMode="numeric" mono value={minQty} onChange={(e) => setMinQty(e.target.value)} className="text-start" />
          </Field>
          <Field label={t('inv.defaultSupplier')}>
            <Select value={supplier} onChange={(e) => setSupplier(e.target.value)}>
              <option value="">{t('common.none')}</option>
              {suppliers.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.name}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

function SupplierDialog({ open, onOpenChange, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const { shop } = useMe();
  const toast = useToast();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [err, setErr] = useState<string | null>(null);
  // تهيئة النافذة قبل ما تترسم: اللي بيتكتب أول ما تفتح ما يتمسحش
  useLayoutEffect(() => {
    if (open) {
      setName('');
      setPhone('');
      setErr(null);
    }
  }, [open]);
  async function save() {
    if (!name.trim()) return setErr(t('inv.errName'));
    const { error } = await supabase.from('suppliers').insert({ id: crypto.randomUUID(), shop_id: shop.id, name: name.trim(), phone: toLatinDigits(phone.trim()) || null });
    if (error) return setErr(errorMessage(error));
    toast({ tone: 'ok', title: t('inv.supplierAdded') });
    onOpenChange(false);
    onDone();
  }
  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('inv.addSupplier')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet onClick={() => void save()}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('inv.supplierName')} required>
          <Input autoFocus value={name} onChange={(e) => setName(e.target.value)} />
        </Field>
        <Field label={t('fin.phone')}>
          <Input dir="ltr" mono inputMode="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

interface Line {
  item: string;
  qty: string;
  price: string;
}

/** شراء من مورد (نقدي أو آجل) أو بيع على الكاونتر: سطر لكل صنف */
function LinesDialog({ mode, open, onOpenChange, items, suppliers, onDone, preset }: { mode: 'purchase' | 'sale'; open: boolean; onOpenChange: (v: boolean) => void; items: StockRow[]; suppliers: Supplier[]; onDone: () => void; preset?: { supplier: string; lines: { item: string; qty: number }[] } | null }) {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const sync = useSync();
  const toast = useToast();
  const navigate = useNavigate();
  const accName = useAccountName();
  const [lines, setLines] = useState<Line[]>([]);
  const [supplier, setSupplier] = useState('');
  const [cashbox, setCashbox] = useState('');
  const [cbs, setCbs] = useState<Cashbox[]>([]);
  // "سجّل" بيستنى قايمة الخزن (من السيرفر أو من النسخة اللي على الجهاز) عشان الخزنة تبقى متختارة فعلًا
  const [cbsReady, setCbsReady] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [id, setId] = useState(opId);
  // S6: الأصناف اللي اتعملت من النافذة دي، والكمية اللي اتسجلت (stock_in)، لحد ما قايمة المخزون تتحدث
  const [extra, setExtra] = useState<StockRow[]>([]);
  const [stocked, setStocked] = useState<Record<string, number>>({});
  const [creating, setCreating] = useState<{ line: number; typed: string } | null>(null);
  // قرار صاحب المشروع: "إضافة صنف جديد" صلاحية لوحدها (صاحب المحل دايمًا، والموظف لو اتفتحتله)
  const canCreate = usePerms().grant('item_create', 'add');
  const allowNeg = readAllowNegative(shop.extras);
  useEffect(() => setStocked({}), [items]);
  const all = useMemo(() => [...extra.filter((x) => !items.some((y) => y.id === x.id)), ...items].map((x) => (stocked[x.id] ? { ...x, qty: x.qty + stocked[x.id] } : x)), [extra, items, stocked]);
  // K: الصنف اللي جاي من تصفح التصنيفات: سعره بيتحط أول ما بيانات الأصناف توصل (لو النافذة اتفتحت قبلها)
  useEffect(() => {
    if (!open || mode !== 'sale' || !preset?.lines.length) return;
    setLines((ls) =>
      ls.map((l) => {
        if (l.price !== '' || !l.item) return l;
        const sp = items.find((x) => x.id === l.item)?.sale_price;
        return sp != null ? { ...l, price: String(Number(sp) / 100) } : l;
      }),
    );
  }, [open, mode, preset, items]);
  // قبل ما النافذة تترسم (زي OpDialog): اللي بيتكتب بسرعة ما يتمسحش
  useLayoutEffect(() => {
    if (!open) return;
    setId(opId());
    setCreating(null);
    setExtra([]);
    // K: من تصفح التصنيفات: الصنف بسعر البيع بتاعه
    const priceOf = (id: string) => (mode === 'sale' ? items.find((x) => x.id === id)?.sale_price : null);
    setLines(preset?.lines.length ? preset.lines.map((l) => ({ item: l.item, qty: String(l.qty), price: priceOf(l.item) != null ? String(Number(priceOf(l.item)) / 100) : '' })) : [{ item: '', qty: '1', price: '' }]);
    setSupplier(preset?.supplier ?? suppliers[0]?.id ?? '');
    setErr(null);
    setCbsReady(false);
    void loadCashboxes()
      .then((c) => {
        setCbs(c);
        setCashbox(mode === 'purchase' ? '' : (c[0]?.id ?? ''));
      })
      .catch(() => undefined)
      .finally(() => setCbsReady(true));
    // بيتصفّر لما الفورم يتفتح بس (مش مع كل تحديث للصفحة، وإلا السطور بتضيع وانت بتكتب)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, mode]);
  // قايمة الموردين ممكن توصل بعد ما الفورم يتفتح (زي بعد إضافة مورد على طول): أول مورد يتختار،
  // عشان اللي ظاهر في الخانة هو نفسه اللي هيتسجل
  useEffect(() => {
    if (open && !supplier && suppliers.length) setSupplier(suppliers[0].id);
  }, [open, supplier, suppliers]);

  const parsed = useMemo(
    () =>
      lines.map((l) => {
        const qty = Number(toLatinDigits(l.qty));
        const price = l.price.trim() === '0' ? 0 : parsePounds(l.price);
        return { item: l.item, qty: Number.isInteger(qty) && qty > 0 ? qty : null, price };
      }),
    [lines],
  );
  const total = parsed.reduce((a, l) => a + (l.qty && l.price != null ? l.qty * l.price : 0), 0);
  const upd = (i: number, p: Partial<Line>) => setLines((ls) => ls.map((l, j) => (j === i ? { ...l, ...p } : l)));
  const [scan, setScan] = useState('');
  const scanRef = useRef<HTMLInputElement>(null);
  // قارئ الباركود بيكتب الكود وبعده Enter: الصنف بيتضاف (أو كميته بتزيد)
  function addByCode(code: string) {
    const c = toLatinDigits(code.trim());
    if (!c) return;
    const it = all.find((x) => (x.sku && x.sku === c) || (x.barcode && x.barcode === c));
    setScan('');
    if (!it) return setErr(t('inv.codeNotFound', { c }));
    setErr(null);
    setLines((ls) => {
      const at = ls.findIndex((l) => l.item === it.id);
      if (at >= 0) return ls.map((l, j) => (j === at ? { ...l, qty: String(Number(toLatinDigits(l.qty) || '0') + 1) } : l));
      const price = it.sale_price != null ? String(it.sale_price / 100) : '';
      const blank = ls.findIndex((l) => !l.item);
      if (blank >= 0) return ls.map((l, j) => (j === blank ? { item: it.id, qty: '1', price } : l));
      return [...ls, { item: it.id, qty: '1', price }];
    });
    scanRef.current?.focus();
  }

  async function save() {
    setErr(null);
    if (parsed.some((l) => !l.item || !l.qty || l.price == null)) return setErr(t('inv.errLines'));
    if (mode === 'purchase' && !supplier) return setErr(t('fin.errParty'));
    if (mode === 'sale' && !cashbox) return setErr(t('fin.errCashbox'));
    if (mode === 'sale' && !allowNeg) {
      const need = new Map<string, number>();
      for (const l of parsed) need.set(l.item, (need.get(l.item) ?? 0) + (l.qty ?? 0));
      // K: الخدمة من غير مخزون
      const it = all.find((x) => x.kind !== 'service' && (need.get(x.id) ?? 0) > Math.max(x.qty, 0));
      if (it) return setErr(t('item.noStock', { n: f.number(Math.max(it.qty, 0)) }));
    }
    setBusy(true);
    const saleArgs = { p_id: id, p_lines: parsed.map((l) => ({ item: l.item, qty: l.qty, price: l.price })), p_cashbox: cashbox };
    const queueSale = async () => {
      await sync.queue('sale', id, saleArgs);
      toast({ tone: 'warn', title: t('sync.queued'), description: `${f.money(total)} ${f.currency(shop.currency)}` });
      onOpenChange(false);
      onDone();
    };
    if (mode === 'sale' && !navigator.onLine) {
      await queueSale();
      setBusy(false);
      return;
    }
    let saleEntry: string | null = null;
    try {
      if (mode === 'purchase') {
        await rpc('record_purchase', { p_id: id, p_supplier: supplier, p_lines: parsed.map((l) => ({ item: l.item, qty: l.qty, unit_cost: l.price })), p_cashbox: cashbox || null });
      } else {
        saleEntry = (await rpc('record_sale', saleArgs)) as string;
      }
      toast({
        tone: 'ok',
        title: t(mode === 'purchase' ? 'inv.purchased' : 'inv.sold'),
        description: `${f.money(total)} ${f.currency(shop.currency)}`,
        // 6ب: فاتورة البيع على طول
        ...(saleEntry ? { action: { label: t('saleInv.print'), onClick: () => navigate(`/print/sale/${saleEntry}`) } } : {}),
      });
      onOpenChange(false);
      onDone();
    } catch (e) {
      if (mode === 'sale' && shouldQueue(e)) await queueSale();
      else setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t(mode === 'purchase' ? 'inv.purchase' : 'inv.sale')}
      description={t(mode === 'purchase' ? 'inv.purchaseHint' : 'inv.saleHint')}
      className="w-[min(94vw,620px)]"
      footer={
        <>
          <span className="me-auto text-sm text-fg-2">
            {t('fin.total')}: <span className="num text-fg">{f.money(total)}</span>
          </span>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy || !cbsReady} onClick={() => void save()} needsNet={mode === 'purchase'} data-testid="lines-save">
            {t('fin.record')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        {mode === 'purchase' && (
          <Field label={t('fin.supplier')}>
            <Select value={supplier} onChange={(e) => setSupplier(e.target.value)}>
              {suppliers.length === 0 && <option value="">{t('inv.noSuppliers')}</option>}
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name}
                </option>
              ))}
            </Select>
          </Field>
        )}
        <Field label={mode === 'purchase' ? t('inv.payFrom') : t('fin.cashbox')}>
          <Select value={cashbox} onChange={(e) => setCashbox(e.target.value)}>
            {mode === 'purchase' && <option value="">{t('inv.onCredit')}</option>}
            {cbs.map((c) => (
              <option key={c.id} value={c.id}>
                {accName(c)}
              </option>
            ))}
          </Select>
        </Field>
        {mode === 'sale' && (
          <Field label={t('inv.barcode')} hint={t('inv.barcodeHint')}>
            <Input
              ref={scanRef}
              dir="ltr"
              mono
              leading={<ScanBarcode className="size-4" aria-hidden />}
              value={scan}
              onChange={(e) => setScan(e.target.value)}
              onKeyDown={(e) => {
                if (e.key !== 'Enter') return;
                e.preventDefault();
                addByCode(scan);
              }}
            />
          </Field>
        )}
        <div className="flex flex-col gap-2" role="group" aria-label={t('inv.lines')}>
          {lines.map((l, i) => {
            const it = l.item ? all.find((x) => x.id === l.item) : undefined;
            // البيع: الكمية المطلوبة من الصنف ده في كل السطور، مقارنة باللي متاح
            const want = it ? parsed.reduce((a, p) => a + (p.item === it.id ? (p.qty ?? 0) : 0), 0) : 0;
            const short = mode === 'sale' && it && it.kind !== 'service' && want > Math.max(it.qty, 0) && lines.findIndex((x) => x.item === it.id) === i ? want - Math.max(it.qty, 0) : 0;
            return (
              <div key={i} className="flex flex-col gap-2">
                <div className="grid grid-cols-[minmax(0,1fr)_64px_100px_auto] items-end gap-2" data-testid="line">
                  <Field label={i === 0 ? t('inv.cols.name') : ''}>
                    <ItemPicker
                      items={all}
                      value={l.item}
                      testid="line-item"
                      onPick={(x) => {
                        setCreating(null);
                        // البيع: سعر البيع بيتملى لوحده بسعر الصنف (زي الأول)
                        upd(i, { item: x.id, price: mode === 'sale' && x.sale_price != null ? String(x.sale_price / 100) : l.price });
                      }}
                      onCreate={canCreate ? (typed) => setCreating({ line: i, typed }) : undefined}
                      createDenied={!canCreate}
                    />
                  </Field>
                  <Field label={i === 0 ? t('inv.cols.qty') : ''}>
                    <Input aria-label={t('inv.cols.qty')} dir="ltr" inputMode="numeric" mono value={l.qty} onChange={(e) => upd(i, { qty: e.target.value })} className="text-start" />
                  </Field>
                  <Field label={i === 0 ? (mode === 'purchase' ? t('inv.unitCost') : t('inv.unitPrice')) : ''}>
                    <Input aria-label={mode === 'purchase' ? t('inv.unitCost') : t('inv.unitPrice')} dir="ltr" inputMode="decimal" mono value={l.price} onChange={(e) => upd(i, { price: e.target.value })} placeholder="0" className="text-start" />
                  </Field>
                  <button type="button" onClick={() => setLines((ls) => (ls.length > 1 ? ls.filter((_, j) => j !== i) : ls))} className="mb-1 grid size-8 place-items-center rounded-md text-fg-3 hover:bg-raised hover:text-danger" aria-label={t('inv.removeLine')}>
                    <Trash2 className="size-4" aria-hidden />
                  </button>
                </div>
                {creating?.line === i && (
                  <NewItemInline
                    key={creating.typed}
                    typed={creating.typed}
                    withStock={mode === 'sale'}
                    onCancel={() => setCreating(null)}
                    onCreated={(row) => {
                      setExtra((xs) => [...xs, row]);
                      setCreating(null);
                      upd(i, { item: row.id, price: mode === 'sale' && row.sale_price != null ? String(row.sale_price / 100) : l.price });
                      toast({ tone: 'ok', title: t('item.created', { name: row.name }) });
                      onDone();
                    }}
                  />
                )}
                {it && short > 0 && !allowNeg && (
                  <StockInInline
                    key={it.id}
                    item={it}
                    need={short}
                    onDone={(q) => {
                      setStocked((m) => ({ ...m, [it.id]: (m[it.id] ?? 0) + q }));
                      toast({ tone: 'ok', title: t('item.stockInDone') });
                      onDone();
                    }}
                  />
                )}
                {it && short > 0 && allowNeg && (
                  <p className="text-2xs text-danger" data-testid="line-unsettled">
                    {t('item.unsettled', { n: f.number(short) })}. {t('item.unsettledHint')}
                  </p>
                )}
              </div>
            );
          })}
          <Button size="sm" variant="ghost" icon={<PackagePlus className="size-4" />} onClick={() => setLines((ls) => [...ls, { item: '', qty: '1', price: '' }])} className="self-start">
            {t('inv.addLine')}
          </Button>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** تفاصيل الصنف (صاحب المحل): أسعار الموردين ومقارنتها، والحد الأدنى، والمورد الأساسي، وسعر البيع */
function ItemDetailDialog({ item, onOpenChange, suppliers, onDone }: { item: StockRow | null; onOpenChange: (v: boolean) => void; suppliers: Supplier[]; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [minQty, setMinQty] = useState('0');
  const [supplier, setSupplier] = useState('');
  const [price, setPrice] = useState('');
  const [name, setName] = useState('');
  const [category, setCategory] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [brand, setBrand] = useState('');
  const [det, setDet] = useState({ item_type: '', model: '', quality: '', color: '' });
  const [barcode, setBarcode] = useState('');
  const [img, setImg] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [del, setDel] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const prices = useLoad(
    async () => (item ? rpc<{ supplier_id: string; supplier: string; last_cost: number; min_cost: number; last_at: string; total_qty: number }[]>('item_suppliers', { p_item: item.id }) : []),
    [item?.id],
  );
  useEffect(() => {
    if (!item) return;
    setMinQty(String(item.min_qty ?? 0));
    setSupplier(item.supplier_id ?? '');
    setName(item.name);
    setCategory(item.category ?? '');
    setCategoryId((item as { category_id?: string | null }).category_id ?? '');
    setBrand(item.brand ?? '');
    setDet({ item_type: item.item_type ?? '', model: item.model ?? '', quality: item.quality ?? '', color: item.color ?? '' });
    setBarcode(item.barcode ?? '');
    setImg(null);
    if (item.image_path) void supabase.storage.from('item-images').createSignedUrl(item.image_path, 3600).then((r) => setImg(r.data?.signedUrl ?? null));
    setPrice(item.sale_price != null ? String(item.sale_price / 100) : '');
    setErr(null);
  }, [item]);
  async function save() {
    if (!item) return;
    const mq = Number(toLatinDigits(minQty.trim() || '0'));
    if (!Number.isInteger(mq) || mq < 0) return setErr(t('inv.errMin'));
    const p = price.trim() ? parsePounds(price) : null;
    if (price.trim() && p == null) return setErr(t('fin.errAmount'));
    if (!name.trim()) return setErr(t('common.required'));
    const bc = toLatinDigits(barcode.trim()) || null;
    if (bc && !/^[0-9A-Za-z-]{4,32}$/.test(bc)) return setErr(t('barcode.bad'));
    const { error } = await supabase.from('items').update({ name: name.trim(), ...(categoryId ? { category_id: categoryId } : { category_id: null, category: category.trim() || null }), brand: brand.trim() || null, barcode: bc, min_qty: mq, supplier_id: supplier || null, sale_price: p,
      item_type: det.item_type.trim() || null, model: det.model.trim() || null, quality: det.quality.trim() || null, color: det.color.trim() || null }).eq('id', item.id);
    if (error) return setErr(/items_barcode_unique/.test(error.message) ? t('barcode.dup') : errorMessage(error));
    toast({ tone: 'ok', title: t('settings.saved') });
    onOpenChange(false);
    onDone();
  }
  /** صورة الصنف: بتتصغّر لو كبيرة، وبتتحفظ في Storage تحت رقم المحل */
  async function upload(file: File) {
    if (!item) return;
    setErr(null);
    setUploading(true);
    try {
      if (!/^image\/(png|jpeg|webp)$/.test(file.type)) throw new Error('mime type not supported');
      const url = URL.createObjectURL(file);
      const el = new Image();
      el.src = url;
      await el.decode();
      const ready = await prepareLogoUpload(file, el);
      URL.revokeObjectURL(url);
      const { data: me } = await supabase.from('items').select('shop_id').eq('id', item.id).maybeSingle();
      const key = `${(me as { shop_id: string } | null)?.shop_id}/${item.id}-${Date.now()}.${ready.ext}`;
      const up = await supabase.storage.from('item-images').upload(key, ready.blob, { contentType: ready.type, upsert: false });
      if (up.error) throw up.error;
      const { error } = await supabase.from('items').update({ image_path: key }).eq('id', item.id);
      if (error) throw error;
      const u = await supabase.storage.from('item-images').createSignedUrl(key, 3600);
      setImg(u.data?.signedUrl ?? null);
      onDone();
    } catch (e) {
      setErr(t(logoUploadError(e)));
    } finally {
      setUploading(false);
    }
  }
  const rows = (prices.data ?? []).map((r) => ({ ...r, last_cost: Number(r.last_cost), min_cost: Number(r.min_cost), total_qty: Number(r.total_qty) }));
  const best = rows.length ? Math.min(...rows.map((r) => r.last_cost)) : null;
  return (
    <Dialog
      open={!!item}
      onOpenChange={onOpenChange}
      title={item?.name ?? ''}
      description={item ? `${t(`inv.kinds.${item.kind}`)} · ${t('inv.cols.qty')}: ${f.number(item.qty)}` : undefined}
      className="w-[min(94vw,560px)]"
      footer={
        <>
          <Button variant="ghost" className="me-auto text-danger" icon={<Trash2 className="size-4" />} onClick={() => setDel(true)} data-testid="item-delete">
            {t('del.delete')}
          </Button>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet onClick={() => void save()}>
            {t('common.save')}
          </Button>
        </>
      }
    >
      <DeleteDialog
        target={del && item ? { kind: 'item', id: item.id, name: item.name } : null}
        onOpenChange={setDel}
        onDone={() => {
          onOpenChange(false);
          onDone();
        }}
      />
      <div className="flex flex-col gap-3">
        {item && <BranchStock item={item} onDone={onDone} />}
        <div className="flex gap-3">
          <label className="group relative grid size-20 shrink-0 cursor-pointer place-items-center overflow-hidden rounded-md border border-dashed border-line bg-sunken/50 text-2xs text-fg-3 hover:border-accent" title={t('inv.image')}>
            {img ? <img src={img} alt={item?.name ?? ''} className="size-full object-cover" /> : uploading ? t('common.loading') : t('inv.image')}
            <input type="file" accept="image/png,image/jpeg,image/webp" className="sr-only" onChange={(e) => e.target.files?.[0] && void upload(e.target.files[0])} data-testid="item-image" />
          </label>
          <div className="grid min-w-0 flex-1 gap-3 sm:grid-cols-2">
            <Field label={t('inv.name')}>
              <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={120} data-testid="item-name" />
            </Field>
            <Field label={t('inv.category')}>
              <CategorySelect value={categoryId} onChange={setCategoryId} testid="item-category" />
            </Field>
            <Field label={t('inv.brand')}>
              <ListCombo list="brands" value={brand} onChange={setBrand} maxLength={60} dir="auto" testid="item-brand" />
            </Field>
            {/* S6: تفاصيل الصنف (اختيارية، والاسم القديم ما بيتغيّرش لوحده) */}
            <Field label={t('item.type')}>
              <ListCombo list="item_types" value={det.item_type} onChange={(v) => setDet((c) => ({ ...c, item_type: v }))} maxLength={60} testid="item-type" />
            </Field>
            <Field label={t('item.model')}>
              <ListCombo list="models" value={det.model} onChange={(v) => setDet((c) => ({ ...c, model: v }))} maxLength={80} dir="auto" testid="item-model" />
            </Field>
            <Field label={t('item.quality')}>
              <ListCombo list="qualities" value={det.quality} onChange={(v) => setDet((c) => ({ ...c, quality: v }))} maxLength={60} testid="item-quality" />
            </Field>
            <Field label={t('item.color')}>
              <ListCombo list="colors" value={det.color} onChange={(v) => setDet((c) => ({ ...c, color: v }))} maxLength={40} testid="item-color" />
            </Field>
          </div>
        </div>
        <Field label={t('barcode.code')} hint={t('barcode.hint')}>
          <div className="flex gap-2">
            <Input mono dir="ltr" value={barcode} onChange={(e) => setBarcode(e.target.value)} className="text-start" data-testid="item-barcode" />
            <Button size="sm" variant="ghost" icon={<BarcodeIcon className="size-4" />} onClick={() => setBarcode(newInternalEan13())} data-testid="barcode-generate">
              {t('barcode.generate')}
            </Button>
            {item?.barcode && (
              <Link to={`/print/barcode/${item.id}`} className="inline-flex h-8 shrink-0 items-center gap-1.5 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg" data-testid="barcode-print">
                <Printer className="size-4" aria-hidden /> {t('barcode.print')}
              </Link>
            )}
          </div>
        </Field>
        <div>
          <div className="readout-label mb-1.5">{t('inv.supplierPrices')}</div>
          {rows.length === 0 ? (
            <p className="text-xs text-fg-3">{t('inv.noPurchases')}</p>
          ) : (
            <table className="w-full text-sm" data-testid="supplier-prices">
              <thead className="text-2xs text-fg-3">
                <tr className="[&_th]:py-1 [&_th]:text-start [&_th]:font-medium">
                  <th>{t('fin.supplier')}</th>
                  <th>{t('inv.lastCost')}</th>
                  <th>{t('inv.minCost')}</th>
                  <th>{t('inv.lastAt')}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-glass-border">
                {rows.map((r) => (
                  <tr key={r.supplier_id} className="[&_td]:py-1.5">
                    <td className="text-fg">
                      {r.supplier}
                      {r.last_cost === best && rows.length > 1 && <span className="ms-2 text-2xs text-ok">{t('inv.cheapest')}</span>}
                    </td>
                    <td className="num text-fg">{f.money(r.last_cost)}</td>
                    <td className="num text-fg-2">{f.money(r.min_cost)}</td>
                    <td className="text-xs text-fg-3">{f.date(r.last_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
        <div className="grid grid-cols-3 gap-3">
          <Field label={t('inv.minQty')}>
            <Input dir="ltr" inputMode="numeric" mono value={minQty} onChange={(e) => setMinQty(e.target.value)} className="text-start" />
          </Field>
          <Field label={t('inv.defaultSupplier')}>
            <Select value={supplier} onChange={(e) => setSupplier(e.target.value)}>
              <option value="">{t('common.none')}</option>
              {suppliers.map((x) => (
                <option key={x.id} value={x.id}>
                  {x.name}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={t('inv.cols.price')}>
            <Input dir="ltr" inputMode="decimal" mono value={price} onChange={(e) => setPrice(e.target.value)} className="text-start" />
          </Field>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
        {item && (
          <div>
            <div className="readout-label mb-1.5">{t('moves.title')}</div>
            <ItemMoves itemId={item.id} />
          </div>
        )}
      </div>
    </Dialog>
  );
}

/** حسابات المخزون لوحده (صاحب المحل): المبيعات، والتكلفة، والهالك، وفرق المرتجعات، والربح للفترة، وأكتر الأصناف بيعًا */
function InventorySummary() {
  const { t } = useTranslation();
  const f = useFormat();
  const br = useBranch();
  const { shop } = useMe();
  const { period, range, set } = usePeriod();
  // S6: فلتر التقرير بالنوع والماركة والموديل والجودة (بيأثر على أكتر الأصناف مبيعًا ومخزونها)
  const [flt, setFlt] = useState({ item_type: '', brand: '', model: '', quality: '' });
  const opts = useLoad(async () => {
    const items = await rpc<StockRow[]>('items_stock');
    const d = (k: 'item_type' | 'brand' | 'model' | 'quality') => [...new Set(items.map((i) => i[k]).filter((x): x is string => !!x))].sort();
    return { item_type: d('item_type'), brand: d('brand'), model: d('model'), quality: d('quality') };
  }, []);
  const fkey = JSON.stringify(flt);
  const hasF = Object.values(flt).some(Boolean);
  const { data, error, reload } = useLoad(
    async () => {
      const r = await rpc<InvSummary>('inventory_summary', { p_from: range.from.toISOString(), p_to: range.to.toISOString(), p_branch: br.filter, p_filter: hasF ? flt : null });
      const n = (k: keyof InvSummary) => Number(r[k] ?? 0);
      return { ...r, sales: n('sales'), sales_cost: n('sales_cost'), wastage: n('wastage'), return_diff: n('return_diff'), cost_adjust: n('cost_adjust'), parts_used: n('parts_used'), purchases: n('purchases'), stock_value: n('stock_value'), stock_qty: n('stock_qty'), profit: n('profit') };
    },
    [range.from.getTime(), range.to.getTime(), br.filter, fkey],
  );
  useLiveRefresh(reload);
  const cur = f.currency(shop.currency);
  const cards: { k: keyof InvSummary; tone?: 'ok' | 'danger' }[] = [
    { k: 'sales' },
    { k: 'sales_cost' },
    { k: 'wastage' },
    { k: 'return_diff' },
    { k: 'profit', tone: data && data.profit < 0 ? 'danger' : 'ok' },
    { k: 'stock_value' },
    { k: 'purchases' },
    { k: 'parts_used' },
  ];
  return (
    <div>
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <PeriodFilter value={period} onChange={set} />
        <div className="flex flex-wrap items-center gap-2" data-testid="invsum-filters">
          {(
            [
              ['item_type', 'item.allTypes'],
              ['brand', 'inv.allBrands'],
              ['model', 'item.allModels'],
              ['quality', 'item.allQualities'],
            ] as const
          ).map(([k, lbl]) =>
            opts.data && opts.data[k].length > 0 ? (
              <Select key={k} value={flt[k]} onChange={(e) => setFlt((c) => ({ ...c, [k]: e.target.value }))} aria-label={t(lbl)} className="h-8 w-auto" data-testid={`invsum-${k}`}>
                <option value="">{t(lbl)}</option>
                {opts.data[k].map((o) => (
                  <option key={o} value={o}>
                    {o}
                  </option>
                ))}
              </Select>
            ) : null,
          )}
        </div>
        <ExportMenu
          testid="invsum-export"
          disabled={!data}
          table={() =>
            data && {
              title: t('inv.tabs.summary'),
              meta: [t('export.period', { from: f.dateNum(range.days[0], { plain: true }), to: f.dateNum(range.days.at(-1)!, { plain: true }) })],
              columns: [{ header: t('export.cols.item') }, { header: t('inv.cols.qty'), type: 'int' }, { header: t('fin.cols.amount'), type: 'money' }],
              rows: [
                ...cards.map(({ k }) => [t(`invsum.${k}`), null, data[k] as number]),
                ...data.top.map((x) => [`${t('invsum.top')}: ${x.name}`, Number(x.qty), Number(x.cost)]),
              ],
            }
          }
        />
      </div>
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            {cards.map(({ k, tone }) => (
              <Panel key={k} className="p-4" data-testid={`inv-sum-${k}`}>
                <div className="readout-label">{t(`invsum.${k}`)}</div>
                <div className={cn('num mt-2 text-xl font-semibold', tone === 'danger' ? 'text-danger' : tone === 'ok' ? 'text-ok' : 'text-fg')}>
                  {data ? f.money(data[k] as number) : <Skeleton className="h-7 w-24" />}
                </div>
                <div className="mt-1 text-2xs text-fg-3">
                  {cur} · {t(`invsum.cap.${k}`)}
                </div>
              </Panel>
            ))}
          </div>
          <p className="mt-2 text-xs text-fg-3">{t('invsum.formula')}</p>
          {hasF && data?.filtered && (
            <Panel className="mt-3 flex flex-wrap items-center gap-4 p-3 text-sm" data-testid="invsum-filtered">
              <span className="text-fg-2">{t('item.filteredTitle')}</span>
              <span>
                {t('item.filteredItems')}: <span className="num text-fg">{f.number(Number(data.filtered.items))}</span>
              </span>
              <span>
                {t('inv.cols.qty')}: <span className="num text-fg">{f.number(Number(data.filtered.stock_qty))}</span>
              </span>
              <span>
                {t('invsum.stock_value')}: <span className="num text-fg">{f.money(Number(data.filtered.stock_value))}</span> {cur}
              </span>
            </Panel>
          )}
          {data && data.top.length > 0 && (
            <Panel className="mt-3 overflow-x-auto">
              <table className="w-full text-sm" data-testid="inv-top">
                <thead className="text-2xs text-fg-3">
                  <tr className="[&_th]:px-3 [&_th]:py-2 [&_th]:text-start [&_th]:font-medium">
                    <th>{t('invsum.top')}</th>
                    <th className="!text-end">{t('inv.cols.qty')}</th>
                    <th className="!text-end">{t('invsum.sales_cost')}</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-glass-border">
                  {data.top.map((x) => (
                    <tr key={x.id} className="[&_td]:px-3 [&_td]:py-2">
                      <td className="text-fg">{x.name}</td>
                      <td className="num text-end text-fg">{f.number(Number(x.qty))}</td>
                      <td className="num text-end text-fg-2">{f.money(Number(x.cost))}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Panel>
          )}
        </>
      )}
    </div>
  );
}
