import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router';
import { motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { ArrowLeft, FileText, Search, Trash2, Upload } from 'lucide-react';
import { Button } from '../ui/Button';
import { useLoad, must } from '../app/useLoad';
import { PageHeader, useLiveRefresh } from '../app/AppShell';
import { WhatsAppButton, WhatsAppDialog, type MessageTarget } from '../app/messaging';
import { supabase } from '../lib/supabase';
import { buildSearchFilter } from '../lib/search';
import { suggestCategory, type CustomerCategory } from '../lib/customers';
import { sumPiasters } from '../lib/money';
import type { DeviceListRow } from '../lib/types';
import type { DeviceStatus } from '../lib/status';
import { useFormat } from '../i18n/format';
import { useMe } from '../app/auth';
import { Panel, PanelHeader } from '../ui/Panel';
import { StatusBadge } from '../ui/StatusBadge';
import { EmptyState, ErrorState, Skeleton } from '../ui/Feedback';
import { Select } from '../ui/Field';
import { Checkbox } from '../ui/Checkbox';
import { useToast } from '../ui/Toast';
import { errorMessage } from '../lib/errors';
import { cn } from '../ui/cn';
import { DeleteDialog } from '../app/DeleteDialog';
import { useCanCorrect } from '../app/correct';
import { ExportMenu } from '../app/exporting';
import { useSensitiveNames } from '../app/assist';
import { PortalPanel } from '../app/portal/PortalPanel';
import { CustomersImportDialog } from '../app/CustomersImportDialog';
import { usePerms } from '../app/perms';

interface CustomerRow {
  id: string;
  name: string;
  phone: string;
  area: string | null;
  category: CustomerCategory;
  marketing_ok: boolean;
}
const CATS: CustomerCategory[] = ['new', 'regular', 'vip', 'late'];
const catTone: Record<CustomerCategory, string> = {
  new: 'text-fg-2 border-line-strong',
  regular: 'text-accent border-[rgb(var(--accent-rgb)/0.4)]',
  vip: 'text-warn border-[color-mix(in_srgb,var(--warn)_45%,transparent)]',
  late: 'text-danger border-[color-mix(in_srgb,var(--danger)_45%,transparent)]',
};

export function CategoryBadge({ c }: { c: CustomerCategory }) {
  const { t } = useTranslation();
  return <span className={cn('inline-flex h-5 items-center rounded-full border px-2 text-2xs font-medium', catTone[c])}>{t(`customers.categories.${c}`)}</span>;
}

/** قائمة العملاء: كل عميل بعدد أجهزته وإجمالي المدفوع وتصنيفه */
export function CustomersScreen() {
  const { t } = useTranslation();
  const f = useFormat();
  const { shop } = useMe();
  const { can } = usePerms();
  const [importing, setImporting] = useState(false);
  const navigate = useNavigate();
  const [q, setQ] = useState('');
  const [deb, setDeb] = useState('');
  useEffect(() => {
    const tm = setTimeout(() => setDeb(q), 220);
    return () => clearTimeout(tm);
  }, [q]);

  const { data, error, loading, reload } = useLoad(async () => {
    let cq = supabase.from('customers').select('id, name, phone, area, category, marketing_ok').is('deleted_at', null).order('created_at', { ascending: false }).limit(500);
    const sf = buildSearchFilter(deb, ['name', 'phone', 'area']);
    if (sf) cq = cq.or(sf);
    const [c, d] = await Promise.all([cq, supabase.from('devices_list').select('customer_id, final_cost, status, received_at').is('deleted_at', null).limit(5000)]);
    return { customers: must(c) as CustomerRow[], devices: must(d) as Pick<DeviceListRow, 'customer_id' | 'final_cost' | 'status' | 'received_at'>[] };
  }, [deb]);
  useLiveRefresh(reload);
  useSensitiveNames((data?.customers ?? []).map((c) => c.name));

  const stats = useMemo(() => {
    const m = new Map<string, { devices: number; spent: number; last: string | null }>();
    for (const d of data?.devices ?? []) {
      const s = m.get(d.customer_id) ?? { devices: 0, spent: 0, last: null };
      s.devices++;
      if (d.status === 'delivered' && d.final_cost != null) s.spent = sumPiasters([s.spent, d.final_cost]);
      if (!s.last || d.received_at > s.last) s.last = d.received_at;
      m.set(d.customer_id, s);
    }
    return m;
  }, [data]);

  return (
    <div>
      <PageHeader
        title={t('customers.title')}
        sub={t('customers.sub')}
        actions={
          <div className="flex items-center gap-2">
            {can('customers', 'add') && (
              <Button icon={<Upload className="size-4" />} onClick={() => setImporting(true)} data-testid="customers-import">
                {t('custImport.button')}
              </Button>
            )}
            <ExportMenu
              testid="customers-export"
              disabled={!data}
              table={() =>
                data && {
                  title: t('customers.title'),
                  meta: deb ? [t('export.search', { v: deb })] : [],
                  columns: [
                    { header: t('customers.cols.name') },
                    { header: t('customers.cols.phone') },
                    { header: t('customers.cols.area') },
                    { header: t('customers.cols.category') },
                    { header: t('customers.cols.devices'), type: 'int', total: true },
                    { header: t('customers.cols.spent'), type: 'money', total: true },
                    { header: t('customers.cols.last'), type: 'date' },
                  ],
                  rows: data.customers.map((c) => {
                    const s = stats.get(c.id) ?? { devices: 0, spent: 0, last: null };
                    return [c.name, c.phone, c.area, t(`customers.categories.${c.category}`), s.devices, s.spent, s.last];
                  }),
                }
              }
            />
          </div>
        }
      />
      <CustomersImportDialog open={importing} onOpenChange={setImporting} onDone={reload} />
      <Panel className="mb-3 p-3">
        <div className="relative">
          <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
          <input
            autoFocus
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder={t('customers.search')}
            aria-label={t('customers.search')}
            className="h-9 w-full rounded-md border border-line bg-sunken/60 pe-3 ps-9 text-sm text-fg placeholder:text-fg-3 focus:border-accent focus:shadow-[0_0_0_3px_var(--accent-soft)] focus:outline-none"
          />
        </div>
      </Panel>
      {error ? (
        <Panel>
          <ErrorState message={error} onRetry={reload} />
        </Panel>
      ) : loading ? (
        <Panel className="flex flex-col gap-2 p-3">
          {[0, 1, 2, 3].map((k) => (
            <Skeleton key={k} className="h-12 w-full" />
          ))}
        </Panel>
      ) : data!.customers.length === 0 ? (
        <Panel>
          <EmptyState line="shield" title={t('customers.empty')}>
            {t('customers.emptyText')}
          </EmptyState>
        </Panel>
      ) : (
        <Panel className="overflow-hidden">
          <ul className="divide-y divide-glass-border">
            {data!.customers.map((c, i) => {
              const s = stats.get(c.id) ?? { devices: 0, spent: 0, last: null };
              return (
                <motion.li key={c.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: Math.min(i, 15) * 0.015 }}>
                  <button type="button" onClick={() => navigate(`/customers/${c.id}`)} className="grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-3 px-4 py-3 text-start text-sm transition-colors hover:bg-raised/50 sm:grid-cols-[minmax(0,1.4fr)_120px_80px_120px_110px]">
                    <div className="min-w-0">
                      <div className="truncate font-medium text-fg">
                        <bdi>{c.name}</bdi>
                      </div>
                      <div className="truncate text-2xs text-fg-3">
                        <span className="num" dir="ltr">
                          {c.phone}
                        </span>
                        {c.area && ` · ${c.area}`}
                      </div>
                    </div>
                    <CategoryBadge c={c.category} />
                    <span className="num hidden text-fg-2 sm:block">{f.number(s.devices)}</span>
                    <span className="num hidden text-fg-2 sm:block">
                      {f.money(s.spent)} <span className="font-sans text-2xs text-fg-3">{f.currency(shop.currency)}</span>
                    </span>
                    <span className="hidden text-xs text-fg-3 sm:block">{s.last ? f.date(s.last) : t('common.none')}</span>
                  </button>
                </motion.li>
              );
            })}
          </ul>
        </Panel>
      )}
    </div>
  );
}

/** ملف العميل: بياناته، وتصنيفه، وأجهزته السابقة، وإجمالي اللي دفعه */
export function CustomerProfileScreen() {
  const { id = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const { shop, profile } = useMe();
  const toast = useToast();
  const location = useLocation();
  const navigate = useNavigate();
  const canCorrect = useCanCorrect()('customers');
  const [del, setDel] = useState(false);
  const [wa, setWa] = useState(false);
  const { data, error, loading, reload } = useLoad(async () => {
    const [c, d] = await Promise.all([
      supabase.from('customers').select('id, name, phone, area, category, marketing_ok').eq('id', id).maybeSingle(),
      supabase.from('devices').select('id, order_no, brand, model, status, received_at, delivered_at, tracking_token, warranty_until').eq('customer_id', id).is('deleted_at', null).order('received_at', { ascending: false }),
    ]);
    const devices = (must(d) ?? []) as { id: string; order_no: string; brand: string; model: string; status: DeviceStatus; received_at: string; delivered_at: string | null; tracking_token: string; warranty_until: string | null }[];
    const costs = devices.length ? must(await supabase.from('device_costs').select('device_id, final_cost').in('device_id', devices.map((x) => x.id))) : [];
    return { customer: must(c) as CustomerRow | null, devices, costs: (costs ?? []) as { device_id: string; final_cost: number | null }[] };
  }, [id]);
  useSensitiveNames([data?.customer?.name]);

  if (error) return <ErrorState message={error} onRetry={reload} />;
  if (loading || !data) return <Skeleton className="h-40 w-full" />;
  if (!data.customer) return <EmptyState line="scan" title={t('device.notFound')} />;
  const c = data.customer;
  const delivered = new Set(data.devices.filter((d) => d.status === 'delivered').map((d) => d.id));
  const spent = sumPiasters(data.costs.filter((x) => delivered.has(x.device_id)).map((x) => x.final_cost));
  const suggestion = suggestCategory({ devices: data.devices.length, spentMinor: spent });
  const last = data.devices[0];
  const target: MessageTarget | null = last
    ? { deviceId: last.id, customerId: c.id, customerName: c.name, phone: c.phone, orderNo: last.order_no, device: `${last.brand} ${last.model}`, status: last.status, token: last.tracking_token, cost: null, warrantyUntil: last.warranty_until }
    : null;

  async function update(patch: Partial<CustomerRow>) {
    const { error: e } = await supabase.from('customers').update(patch).eq('id', c.id);
    if (e) return toast({ tone: 'danger', title: errorMessage(e) });
    toast({ tone: 'ok', title: t('customers.saved') });
    reload();
  }

  return (
    <div className="max-w-5xl">
      <button type="button" onClick={() => navigate('/customers')} className="mb-3 inline-flex items-center gap-1.5 text-sm text-fg-3 hover:text-fg">
        <ArrowLeft className="size-4 rtl:-scale-x-100" aria-hidden /> {t('customers.title')}
      </button>
      <Panel elevated glow className="mb-4 p-5">
        <div className="flex flex-wrap items-center gap-4">
          <div className="grid size-12 place-items-center rounded-lg border border-glass-border bg-raised text-lg font-semibold text-fg-2">{c.name.trim().charAt(0)}</div>
          <div className="min-w-0 flex-1">
            <h1 className="truncate text-xl font-semibold text-fg">
              <bdi>{c.name}</bdi>
            </h1>
            <div className="text-sm text-fg-3">
              <span className="num" dir="ltr">
                {c.phone}
              </span>
              {c.area && ` · ${c.area}`}
            </div>
          </div>
          {profile.role === 'owner' && (
            <Link to={`/finance/customer/${c.id}`} className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-sm text-fg-2 hover:border-accent hover:text-fg">
              <FileText className="size-4" aria-hidden /> {t('fin.statement')}
            </Link>
          )}
          {target && <WhatsAppButton onClick={() => setWa(true)} />}
          {canCorrect && (
            <Button size="sm" variant="ghost" icon={<Trash2 className="size-4" />} onClick={() => setDel(true)} data-testid="customer-delete">
              {t('del.delete')}
            </Button>
          )}
        </div>
        <DeleteDialog target={del ? { kind: 'customer', id: c.id, name: c.name } : null} onOpenChange={setDel} onDone={() => navigate('/customers')} />
        <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Stat label={t('customers.visits')} value={f.number(data.devices.length)} />
          <Stat label={t('customers.spent')} value={`${f.money(spent)} ${f.currency(shop.currency)}`} />
          <div className="col-span-2 flex flex-col gap-1.5 rounded-md border border-glass-border bg-sunken/40 px-3 py-2">
            <span className="readout-label">{t('customers.cols.category')}</span>
            <div className="flex items-center gap-2">
              <Select value={c.category} onChange={(e) => void update({ category: e.target.value as CustomerCategory })} aria-label={t('customers.cols.category')} className="h-8">
                {CATS.map((k) => (
                  <option key={k} value={k}>
                    {t(`customers.categories.${k}`)}
                  </option>
                ))}
              </Select>
              {suggestion !== c.category && <span className="shrink-0 text-2xs text-fg-3">{t('customers.suggested', { c: t(`customers.categories.${suggestion}`) })}</span>}
            </div>
          </div>
        </div>
        <Checkbox className="mt-3" checked={c.marketing_ok} onChange={(v) => void update({ marketing_ok: v })} label={t('customers.marketing')} />
      </Panel>
      {/* C8: بوابة عميل الجملة (اختياري) */}
      <PortalPanel customerId={c.id} phone={c.phone} />
      <Panel>
        <PanelHeader title={t('customers.history')} />
        <ul className="divide-y divide-glass-border">
          {data.devices.map((d) => (
            <li key={d.id}>
              <Link to={`/devices/${d.id}`} state={{ bg: location }} className="flex items-center gap-3 px-4 py-2.5 text-sm hover:bg-raised/50">
                <span className="num w-[86px] shrink-0 text-fg" dir="ltr">
                  {d.order_no}
                </span>
                <span className="min-w-0 flex-1 truncate text-fg">
                  {d.brand} {d.model}
                </span>
                <StatusBadge status={d.status} size="sm" />
                <span className="hidden w-24 text-end text-xs text-fg-3 sm:block">{f.date(d.received_at)}</span>
              </Link>
            </li>
          ))}
        </ul>
      </Panel>
      <WhatsAppDialog open={wa} onOpenChange={setWa} target={target} initial="status" />
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-md border border-glass-border bg-sunken/40 px-3 py-2">
      <div className="readout-label">{label}</div>
      <div className="num mt-0.5 truncate text-md text-fg">{value}</div>
    </div>
  );
}
