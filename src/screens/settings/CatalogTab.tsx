import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Copy, Globe, Share2 } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { appBase } from '../../lib/publicUrl';
import { useMe } from '../../app/auth';
import { useLoad } from '../../app/useLoad';
import { useBranch } from '../../app/branch';
import { rpc, type StockRow } from '../../app/ledgerApi';
import { useFormat } from '../../i18n/format';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Input } from '../../ui/Field';
import { Button } from '../../ui/Button';
import { Alert, Skeleton } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

export function catalogUrl(base: string, token: string): string {
  return `${base.replace(/#.*$/, '').replace(/\/$/, '')}/#/c/${token}`;
}

/** C8: الإعدادات ← الكتالوج: فتح وقفل الرابط العام، والمشاركة، واختيار الأصناف اللي تظهر */
export function CatalogTab() {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const { shop } = useMe();
  const [q, setQ] = useState('');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const br = useBranch();
  const { data, reload } = useLoad(async () => {
    const [s, items, flags, brs] = await Promise.all([
      supabase.from('shops').select('catalog_token').eq('id', shop.id).maybeSingle(),
      rpc('items_stock') as Promise<StockRow[]>,
      supabase.from('items').select('id, in_catalog').is('deleted_at', null),
      supabase.from('branches').select('id, catalog_token').is('deleted_at', null),
    ]);
    const on = new Map(((flags.data ?? []) as { id: string; in_catalog: boolean }[]).map((x) => [x.id, x.in_catalog]));
    return {
      token: (s.data as { catalog_token: string | null } | null)?.catalog_token ?? null,
      branches: new Map(((brs.data ?? []) as { id: string; catalog_token: string | null }[]).map((b) => [b.id, b.catalog_token])),
      items: items.map((i) => ({ ...i, in_catalog: on.get(i.id) ?? false })),
    };
  }, [shop.id]);
  const base = appBase(shop.extras, window.location.href);
  const shown = useMemo(() => (data?.items ?? []).filter((i) => !q.trim() || i.name.toLowerCase().includes(q.trim().toLowerCase())), [data, q]);

  async function toggle(on: boolean, branch: string | null = null) {
    setErr(null);
    setBusy(true);
    try {
      await rpc('set_catalog', { p_on: on, p_branch: branch });
      reload();
    } catch (e) {
      setErr(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }
  async function pick(id: string, v: boolean) {
    const { error } = await supabase.from('items').update({ in_catalog: v }).eq('id', id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    reload();
  }

  return (
    <Panel data-testid="catalog-settings">
      <PanelHeader title={t('settings.tabs.catalog')} />
      <div className="flex flex-col gap-3 p-4">
        <p className="text-xs text-fg-3">{t('catalog.hint')}</p>
        {!data ? (
          <Skeleton className="h-24 w-full" />
        ) : (
          <>
            {/* رابط كل الفروع، ولو المحل فروع: رابط لكل فرع (التوفر من مخزون الفرع ده) */}
            <LinkRow label={br.multi ? t('catalog.allBranches') : null} token={data.token} base={base} shopName={shop.name} busy={busy} onToggle={(on) => void toggle(on)} testid="catalog" />
            {br.multi &&
              br.all.map((b) => (
                <LinkRow key={b.id} label={b.name} token={data.branches.get(b.id) ?? null} base={base} shopName={`${shop.name} - ${b.name}`} busy={busy} onToggle={(on) => void toggle(on, b.id)} testid={`catalog-${b.id}`} />
              ))}
            {err && <Alert tone="danger">{err}</Alert>}
            <div className="mt-2 flex items-center justify-between gap-2">
              <span className="text-sm font-medium text-fg">{t('catalog.pick')}</span>
              <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('catalog.search')} className="h-8 w-48 text-sm" aria-label={t('catalog.search')} />
            </div>
            {shown.length === 0 ? (
              <p className="text-xs text-fg-3">{t('catalog.noItems')}</p>
            ) : (
              <ul className="max-h-96 divide-y divide-line overflow-y-auto rounded-md border border-line">
                {shown.map((i) => (
                  <li key={i.id} className="flex items-center gap-2 px-3 py-1.5 text-sm" data-testid="catalog-pick">
                    <input type="checkbox" checked={i.in_catalog} onChange={(e) => void pick(i.id, e.target.checked)} className="size-4 accent-[var(--accent)]" aria-label={i.name} disabled={i.sale_price == null} />
                    <span className="min-w-0 flex-1 truncate text-fg">{i.name}</span>
                    <span className="text-2xs text-fg-3">{t(`inv.kinds.${i.kind}`)}</span>
                    <span className="num w-20 text-end text-fg-2">{i.sale_price != null ? f.money(i.sale_price) : t('catalog.noPrice')}</span>
                  </li>
                ))}
              </ul>
            )}
          </>
        )}
      </div>
    </Panel>
  );
}

function LinkRow({ label, token, base, shopName, busy, onToggle, testid }: { label: string | null; token: string | null; base: string; shopName: string; busy: boolean; onToggle: (on: boolean) => void; testid: string }) {
  const { t } = useTranslation();
  const toast = useToast();
  const url = token ? catalogUrl(base, token) : null;
  return (
    <div className="flex flex-col gap-2 rounded-md border border-line p-3" data-testid={`${testid}-row`}>
      {label && <div className="text-sm font-medium text-fg">{label}</div>}
      {url ? (
        <>
          <div className="flex flex-wrap items-center gap-2">
            <Input readOnly value={url} dir="ltr" className="min-w-0 flex-1 text-xs" aria-label={t('catalog.link')} data-testid={`${testid}-link`} />
            <Button size="sm" onClick={() => void navigator.clipboard?.writeText(url).then(() => toast({ tone: 'ok', title: t('catalog.copied') }))} icon={<Copy className="size-3.5" />}>
              {t('catalog.copy')}
            </Button>
          </div>
          <div className="flex flex-wrap gap-2">
            <a href={`https://wa.me/?text=${encodeURIComponent(`${shopName}: ${url}`)}`} target="_blank" rel="noopener noreferrer" className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-xs text-fg-2 hover:text-fg">
              <Share2 className="size-3.5" aria-hidden /> {t('catalog.shareWa')}
            </a>
            <a href={`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`} target="_blank" rel="noopener noreferrer" className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-xs text-fg-2 hover:text-fg">
              <Share2 className="size-3.5" aria-hidden /> {t('catalog.shareFb')}
            </a>
            <Button size="sm" variant="ghost" loading={busy} onClick={() => onToggle(false)} data-testid={`${testid}-off-btn`}>
              {t('catalog.turnOff')}
            </Button>
          </div>
        </>
      ) : (
        <Button variant={label ? 'secondary' : 'primary'} loading={busy} onClick={() => onToggle(true)} icon={<Globe className="size-4" />} className="self-start" data-testid={`${testid}-on`}>
          {t('catalog.turnOn')}
        </Button>
      )}
    </div>
  );
}
