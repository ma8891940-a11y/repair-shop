import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { IdCard, Plus, Search, ShieldAlert, ShoppingCart } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { parsePounds } from '../lib/money';
import { isValidImei, normalizeImei } from '../lib/imei';
import { shrinkImage } from '../lib/photos';
import { toLatinDigits } from '../lib/digits';
import { useMe } from '../app/auth';
import { useLoad } from '../app/useLoad';
import { useBranch } from '../app/branch';
import { getBranchHeader } from '../lib/branchHeader';
import { cashboxesFor, loadCashboxes, opId, rpc, useAccountName } from '../app/ledgerApi';
import { useFormat } from '../i18n/format';
import { Panel, PanelHeader } from '../ui/Panel';
import { Field, Input, Select, Textarea } from '../ui/Field';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Alert, EmptyState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';

interface UsedRow {
  id: string;
  item_id: string;
  imei: string;
  brand: string;
  model: string;
  storage: string | null;
  color: string | null;
  condition: string | null;
  branch_id: string | null;
  status: 'in_stock' | 'sold' | 'cancelled';
  bought_at: string;
  buy_price: number | null;
  sale_price: number | null;
  sold_price: number | null;
  sold_at: string | null;
  profit: number | null;
  has_seller_id: boolean;
}
const SELLER_BUCKET = 'seller-ids';

/** C4: الأجهزة المستعملة: شراء من بائع (ببياناته وصورة بطاقته)، وبيع، وربح كل جهاز. كله قيود متوازنة في الدفتر */
export function UsedDevicesScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { profile } = useMe();
  const owner = profile.role === 'owner';
  const br = useBranch();
  const [q, setQ] = useState('');
  const [filter, setFilter] = useState<'in_stock' | 'sold' | 'all'>('in_stock');
  const [buying, setBuying] = useState(false);
  const [selling, setSelling] = useState<UsedRow | null>(null);
  const [seller, setSeller] = useState<UsedRow | null>(null);
  const { data, error, reload } = useLoad(async () => ((await rpc('used_devices_list')) ?? []) as UsedRow[], []);
  const rows = useMemo(() => {
    const s = normalizeImei(toLatinDigits(q)) || q.trim().toLowerCase();
    return (data ?? [])
      .filter((r) => filter === 'all' || r.status === filter)
      .filter((r) => !s || r.imei.includes(s) || `${r.brand} ${r.model}`.toLowerCase().includes(s));
  }, [data, q, filter]);
  const totals = useMemo(() => {
    const sold = (data ?? []).filter((r) => r.status === 'sold');
    return { stock: (data ?? []).filter((r) => r.status === 'in_stock').length, profit: sold.reduce((a, r) => a + Number(r.profit ?? 0), 0) };
  }, [data]);
  const showMoney = (data ?? []).some((r) => r.buy_price != null);
  const cur = f.currency(useMe().shop.currency);

  return (
    <div className="mx-auto flex w-full max-w-6xl flex-col gap-4 p-4" data-testid="used-screen">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold text-fg">{t('used.title')}</h1>
          <p className="text-sm text-fg-3">{t('used.sub')}</p>
        </div>
        <Button variant="primary" onClick={() => setBuying(true)} icon={<Plus className="size-4" />} data-testid="used-buy">
          {t('used.buy')}
        </Button>
      </div>
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        <Panel className="p-4">
          <div className="readout-label">{t('used.inStock')}</div>
          <div className="num text-2xl text-fg" data-testid="used-stock-count">
            {data ? totals.stock : '—'}
          </div>
        </Panel>
        {showMoney && (
          <Panel className="p-4">
            <div className="readout-label">{t('used.profitTotal')}</div>
            <div className={cn('num text-2xl', totals.profit < 0 ? 'text-danger' : 'text-fg')} data-testid="used-profit-total">
              {f.money(totals.profit)} {cur}
            </div>
          </Panel>
        )}
      </div>
      <Panel>
        <PanelHeader
          title={t('used.list')}
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <div className="relative">
                <Search className="pointer-events-none absolute start-2 top-1/2 size-3.5 -translate-y-1/2 text-fg-3" aria-hidden />
                <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('used.search')} className="h-8 w-56 ps-7 text-sm" aria-label={t('used.search')} data-testid="used-search" />
              </div>
              <Select value={filter} onChange={(e) => setFilter(e.target.value as typeof filter)} className="h-8 text-sm" aria-label={t('used.filter')}>
                {(['in_stock', 'sold', 'all'] as const).map((k) => (
                  <option key={k} value={k}>
                    {t(`used.f.${k}`)}
                  </option>
                ))}
              </Select>
            </div>
          }
        />
        {error ? (
          <div className="p-4">
            <Alert tone="danger">{error}</Alert>
          </div>
        ) : !data ? (
          <div className="flex flex-col gap-2 p-4">
            <Skeleton className="h-10 w-full" />
            <Skeleton className="h-10 w-full" />
          </div>
        ) : rows.length === 0 ? (
          <EmptyState line="phone" title={t('used.empty')} action={<Button onClick={() => setBuying(true)}>{t('used.buy')}</Button>}>
            {t('used.emptyHint')}
          </EmptyState>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full min-w-[680px] text-sm">
              <thead>
                <tr className="border-b border-line text-xs text-fg-3">
                  <th className="px-3 py-2 text-start font-medium">{t('used.device')}</th>
                  <th className="px-3 py-2 text-start font-medium">IMEI</th>
                  {br.multi && <th className="px-3 py-2 text-start font-medium">{t('used.branch')}</th>}
                  <th className="px-3 py-2 text-start font-medium">{t('used.status')}</th>
                  {showMoney && <th className="px-3 py-2 text-end font-medium">{t('used.buyPrice')}</th>}
                  <th className="px-3 py-2 text-end font-medium">{t('used.price')}</th>
                  {showMoney && <th className="px-3 py-2 text-end font-medium">{t('used.profit')}</th>}
                  <th className="px-3 py-2" />
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-b border-line last:border-0" data-testid="used-row">
                    <td className="px-3 py-2">
                      <div className="text-fg">
                        {r.brand} {r.model}
                      </div>
                      <div className="text-2xs text-fg-3">{[r.storage, r.color, f.date(r.bought_at)].filter(Boolean).join(t('common.sep'))}</div>
                    </td>
                    <td className="num px-3 py-2 text-fg-2" dir="ltr">
                      {r.imei}
                    </td>
                    {br.multi && <td className="px-3 py-2 text-fg-2">{br.name(r.branch_id ?? '')}</td>}
                    <td className="px-3 py-2">
                      <span className={cn('rounded-sm px-1.5 py-0.5 text-2xs', r.status === 'in_stock' ? 'bg-accent-soft text-accent' : r.status === 'sold' ? 'bg-ok-soft text-ok' : 'bg-raised text-fg-3')}>{t(`used.s.${r.status}`)}</span>
                    </td>
                    {showMoney && <td className="num px-3 py-2 text-end">{r.buy_price != null ? f.money(Number(r.buy_price)) : '—'}</td>}
                    <td className="num px-3 py-2 text-end">{r.sold_price != null ? f.money(Number(r.sold_price)) : r.sale_price != null ? f.money(Number(r.sale_price)) : '—'}</td>
                    {showMoney && (
                      <td className={cn('num px-3 py-2 text-end', r.profit != null && Number(r.profit) < 0 ? 'text-danger' : 'text-fg')} data-testid="used-profit">
                        {r.profit != null ? f.money(Number(r.profit)) : '—'}
                      </td>
                    )}
                    <td className="px-3 py-2">
                      <div className="flex justify-end gap-1">
                        {r.status === 'in_stock' && (
                          <Button size="sm" onClick={() => setSelling(r)} icon={<ShoppingCart className="size-3.5" />} data-testid="used-sell">
                            {t('used.sell')}
                          </Button>
                        )}
                        {owner && (
                          <Button size="sm" variant="ghost" onClick={() => setSeller(r)} icon={<IdCard className="size-3.5" />} data-testid="used-seller">
                            {t('used.sellerBtn')}
                          </Button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Panel>
      <BuyDialog open={buying} onOpenChange={setBuying} onDone={reload} />
      <SellDialog row={selling} onClose={() => setSelling(null)} onDone={reload} />
      <SellerDialog row={seller} onClose={() => setSeller(null)} />
    </div>
  );
}

function useCashboxOptions() {
  return useLoad(async () => cashboxesFor(await loadCashboxes(), getBranchHeader()), []);
}

function BuyDialog({ open, onOpenChange, onDone }: { open: boolean; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const { shop } = useMe();
  const accName = useAccountName();
  const cbs = useCashboxOptions();
  const blank = { brand: '', model: '', imei: '', storage: '', color: '', condition: '', price: '', ask: '', name: '', phone: '', nid: '' };
  const [v, setV] = useState(blank);
  const [cashbox, setCashbox] = useState('');
  const [photo, setPhoto] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const set = (k: keyof typeof blank) => (e: { target: { value: string } }) => setV((x) => ({ ...x, [k]: e.target.value }));
  const imei = normalizeImei(toLatinDigits(v.imei));
  const box = cashbox || cbs.data?.[0]?.id || '';

  async function save() {
    setErr(null);
    const price = parsePounds(v.price);
    const ask = v.ask.trim() ? parsePounds(v.ask) : null;
    if (!v.brand.trim() || !v.model.trim()) return setErr(t('used.needModel'));
    if (imei.length < 14) return setErr(t('used.needImei'));
    if (!price || price <= 0) return setErr(t('used.needPrice'));
    if (v.ask.trim() && ask == null) return setErr(t('used.needPrice'));
    if (v.name.trim().length < 2) return setErr(t('used.needSeller'));
    const nid = toLatinDigits(v.nid).replace(/\D/g, '');
    if (nid && nid.length !== 14) return setErr(t('used.badNid'));
    setBusy(true);
    const id = opId();
    try {
      await rpc('buy_used_device', {
        p_id: id,
        p_device: { brand: v.brand, model: v.model, imei, storage: v.storage, color: v.color, condition: v.condition, buy_price: price, sale_price: ask },
        p_cashbox: box,
        p_seller: { name: v.name, phone: toLatinDigits(v.phone), nid },
      });
      if (photo) {
        const blob = await shrinkImage(photo);
        const path = `${shop.id}/${id}/${crypto.randomUUID()}.jpg`;
        const up = await supabase.storage.from(SELLER_BUCKET).upload(path, blob, { contentType: 'image/jpeg', upsert: false });
        if (up.error) throw up.error;
        await rpc('set_seller_photo', { p_used: id, p_path: path });
      }
      toast({ tone: 'ok', title: t('used.bought') });
      setV(blank);
      setPhoto(null);
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={t('used.buy')}
      className="w-[min(94vw,640px)]"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()} data-testid="used-buy-save">
            {t('used.buySave')}
          </Button>
        </>
      }
    >
      <div className="grid gap-3 sm:grid-cols-2">
        <Field label={t('used.brand')} required>
          <Input value={v.brand} onChange={set('brand')} />
        </Field>
        <Field label={t('used.model')} required>
          <Input value={v.model} onChange={set('model')} />
        </Field>
        <Field label="IMEI" required hint={imei && !isValidImei(imei) ? t('intake.imeiBad') : undefined}>
          <Input dir="ltr" mono inputMode="numeric" value={v.imei} onChange={set('imei')} />
        </Field>
        <div className="grid grid-cols-2 gap-2">
          <Field label={t('used.storage')}>
            <Input value={v.storage} onChange={set('storage')} />
          </Field>
          <Field label={t('used.color')}>
            <Input value={v.color} onChange={set('color')} />
          </Field>
        </div>
        <Field label={t('used.condition')} className="sm:col-span-2">
          <Textarea rows={2} value={v.condition} onChange={set('condition')} />
        </Field>
        <Field label={t('used.buyPrice')} required>
          <Input mono inputMode="decimal" value={v.price} onChange={set('price')} />
        </Field>
        <Field label={t('used.askPrice')}>
          <Input mono inputMode="decimal" value={v.ask} onChange={set('ask')} />
        </Field>
        <Field label={t('used.payFrom')} className="sm:col-span-2">
          <Select value={box} onChange={(e) => setCashbox(e.target.value)}>
            {(cbs.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {accName(c)}
              </option>
            ))}
          </Select>
        </Field>
      </div>
      <fieldset className="mt-4 rounded-md border border-line p-3">
        <legend className="px-1 text-sm font-medium text-fg">{t('used.seller')}</legend>
        <Alert tone="info">
          <span className="inline-flex items-start gap-1.5" data-testid="used-privacy">
            <ShieldAlert className="mt-0.5 size-4 shrink-0" aria-hidden /> {t('used.privacy')}
          </span>
        </Alert>
        <div className="mt-3 grid gap-3 sm:grid-cols-2">
          <Field label={t('used.sellerName')} required>
            <Input value={v.name} onChange={set('name')} autoComplete="off" />
          </Field>
          <Field label={t('used.sellerPhone')}>
            <Input dir="ltr" mono inputMode="tel" value={v.phone} onChange={set('phone')} autoComplete="off" />
          </Field>
          <Field label={t('used.nid')} hint={t('used.nidHint')}>
            <Input dir="ltr" mono inputMode="numeric" maxLength={14} value={v.nid} onChange={set('nid')} autoComplete="off" />
          </Field>
          <Field label={t('used.idPhoto')}>
            <input type="file" accept="image/*" capture="environment" onChange={(e) => setPhoto(e.target.files?.[0] ?? null)} className="text-sm text-fg-2" data-testid="used-id-photo" />
          </Field>
        </div>
      </fieldset>
      {err && (
        <div className="mt-3">
          <Alert tone="danger">{err}</Alert>
        </div>
      )}
    </Dialog>
  );
}

function SellDialog({ row, onClose, onDone }: { row: UsedRow | null; onClose: () => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const accName = useAccountName();
  const cbs = useCashboxOptions();
  const [price, setPrice] = useState('');
  const [cashbox, setCashbox] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const box = cashbox || cbs.data?.[0]?.id || '';
  const open = !!row;
  const initial = row?.sale_price != null ? String(Number(row.sale_price) / 100) : '';
  async function save() {
    if (!row) return;
    setErr(null);
    const p = parsePounds(price || initial);
    if (p == null || p <= 0) return setErr(t('used.needPrice'));
    setBusy(true);
    try {
      await rpc('sell_used_device', { p_id: opId(), p_used: row.id, p_price: p, p_cashbox: box });
      toast({ tone: 'ok', title: t('used.soldOk') });
      setPrice('');
      onClose();
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Dialog
      open={open}
      onOpenChange={(v) => !v && onClose()}
      title={row ? `${t('used.sell')}: ${row.brand} ${row.model}` : ''}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" needsNet loading={busy} onClick={() => void save()} data-testid="used-sell-save">
            {t('used.sell')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('used.price')} required>
          <Input mono inputMode="decimal" value={price} placeholder={initial} onChange={(e) => setPrice(e.target.value)} data-testid="used-sell-price" />
        </Field>
        <Field label={t('used.payTo')}>
          <Select value={box} onChange={(e) => setCashbox(e.target.value)}>
            {(cbs.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {accName(c)}
              </option>
            ))}
          </Select>
        </Field>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

function SellerDialog({ row, onClose }: { row: UsedRow | null; onClose: () => void }) {
  const { t } = useTranslation();
  const { data, error } = useLoad(async () => {
    if (!row) return null;
    const r = (((await rpc('seller_info', { p_used: row.id })) ?? []) as { seller_name: string; seller_phone: string | null; nid: string | null; photo: string | null }[])[0];
    const url = r?.photo ? ((await supabase.storage.from(SELLER_BUCKET).createSignedUrl(r.photo, 600)).data?.signedUrl ?? null) : null;
    return { ...r, url };
  }, [row?.id]);
  return (
    <Dialog open={!!row} onOpenChange={(v) => !v && onClose()} title={t('used.seller')} description={t('used.sellerNote')} guard={false}>
      {error ? (
        <Alert tone="danger">{error}</Alert>
      ) : !data ? (
        <Skeleton className="h-24 w-full" />
      ) : (
        <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm" data-testid="seller-info">
          <dt className="text-fg-3">{t('used.sellerName')}</dt>
          <dd className="text-fg">{data.seller_name}</dd>
          <dt className="text-fg-3">{t('used.sellerPhone')}</dt>
          <dd className="num text-fg" dir="ltr">
            {data.seller_phone ?? '—'}
          </dd>
          <dt className="text-fg-3">{t('used.nid')}</dt>
          <dd className="num text-fg" dir="ltr" data-testid="seller-nid">
            {data.nid ?? '—'}
          </dd>
          {data.url && (
            <>
              <dt className="text-fg-3">{t('used.idPhoto')}</dt>
              <dd>
                <img src={data.url} alt={t('used.idPhoto')} className="max-h-48 rounded-md border border-line" />
              </dd>
            </>
          )}
        </dl>
      )}
    </Dialog>
  );
}
