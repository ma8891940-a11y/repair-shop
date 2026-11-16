import { useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { MessageCircle, Search } from 'lucide-react';
import { supabase, tokenClient } from '../lib/supabase';
import { waLink } from '../lib/messages';
import { useFormat } from '../i18n/format';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Input } from '../ui/Field';
import { Alert, Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

interface Item {
  id: string;
  name: string;
  kind: 'part' | 'accessory' | 'used';
  price: number;
  image: string | null;
  in_stock: boolean;
  details: { brand: string; model: string; storage: string | null; color: string | null; condition: string | null } | null;
}
interface Catalog {
  shop: { name: string; phone: string | null; currency: string; logo: string | null };
  items: Item[];
}

/** C8: الكتالوج الأونلاين للمحل (صفحة عامة برابط): الاسم والسعر و"متوفر" بس، وزرار سؤال على واتساب المحل */
export function CatalogScreen() {
  const { token = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const [data, setData] = useState<Catalog | null | undefined>(undefined);
  const [imgs, setImgs] = useState<Record<string, string>>({});
  const [q, setQ] = useState('');
  const [kind, setKind] = useState<'all' | Item['kind']>('all');
  useEffect(() => {
    let live = true;
    void supabase.rpc('public_catalog', { p_token: token }).then(async ({ data: d, error }) => {
      if (!live) return;
      const c = error ? null : ((d as Catalog | null) ?? null);
      setData(c);
      const paths = (c?.items ?? []).map((i) => i.image).filter((x): x is string => !!x);
      if (paths.length) {
        const { data: s } = await tokenClient('x-catalog-token', token).storage.from('item-images').createSignedUrls(paths, 3600);
        if (live) setImgs(Object.fromEntries((s ?? []).filter((x) => x.path && x.signedUrl).map((x) => [x.path!, x.signedUrl as string])));
      }
    });
    return () => {
      live = false;
    };
  }, [token]);
  const shown = useMemo(() => {
    const s = q.trim().toLowerCase();
    return (data?.items ?? []).filter((i) => (kind === 'all' || i.kind === kind) && (!s || i.name.toLowerCase().includes(s)));
  }, [data, q, kind]);
  const kinds = useMemo(() => [...new Set((data?.items ?? []).map((i) => i.kind))], [data]);
  const cur = data ? f.currency(data.shop.currency) : '';
  const logo = data?.shop.logo?.startsWith('data:image/') ? data.shop.logo : null;

  return (
    <div className="relative min-h-dvh">
      <div className="mx-auto flex min-h-dvh w-full max-w-5xl flex-col px-4 pb-10">
        <header className="flex items-center justify-between gap-3 py-4">
          <div className="flex min-w-0 items-center gap-2.5">
            {logo && <img src={logo} alt={data?.shop.name ?? ''} className="h-10 max-w-[140px] rounded-md bg-white object-contain p-1" />}
            <h1 className={cn('truncate font-bold text-fg', logo ? 'text-base' : 'text-xl')}>{data?.shop.name ?? t('catalog.title')}</h1>
          </div>
          <div className="flex items-center gap-1">
            <LangToggle />
            <ThemeToggle />
          </div>
        </header>
        {data === undefined ? (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {Array.from({ length: 8 }, (_, i) => (
              <Skeleton key={i} className="h-52 rounded-xl" />
            ))}
          </div>
        ) : data === null ? (
          <div data-testid="catalog-off">
            <Alert tone="warn">{t('catalog.off')}</Alert>
          </div>
        ) : (
          <>
            <div className="mb-4 flex flex-wrap items-center gap-2">
              <div className="relative min-w-0 flex-1">
                <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-fg-3" aria-hidden />
                <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('catalog.search')} className="h-10 ps-9" aria-label={t('catalog.search')} />
              </div>
              {kinds.length > 1 && (
                <div className="flex gap-1" role="tablist">
                  {(['all', ...kinds] as const).map((k) => (
                    <button key={k} type="button" role="tab" aria-selected={kind === k} onClick={() => setKind(k)} className={cn('h-9 rounded-md border px-3 text-sm focus-visible:outline-2 focus-visible:outline-accent', kind === k ? 'border-accent bg-accent-soft text-fg' : 'border-line text-fg-2')}>
                      {k === 'all' ? t('catalog.all') : t(`inv.kinds.${k}`)}
                    </button>
                  ))}
                </div>
              )}
            </div>
            {shown.length === 0 ? (
              <p className="py-10 text-center text-sm text-fg-3">{t('catalog.empty')}</p>
            ) : (
              <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4" data-testid="catalog-items">
                {shown.map((i) => (
                  <li key={i.id} className="glass flex flex-col overflow-hidden rounded-xl" data-testid="catalog-item">
                    <div className="aspect-square bg-sunken">{i.image && imgs[i.image] ? <img src={imgs[i.image]} alt={i.name} className="size-full object-cover" loading="lazy" /> : null}</div>
                    <div className="flex flex-1 flex-col gap-1 p-3">
                      <div className="line-clamp-2 text-sm font-medium text-fg">{i.name}</div>
                      {i.details && <div className="text-2xs text-fg-3">{[i.details.storage, i.details.color, i.details.condition].filter(Boolean).join(t('common.sep'))}</div>}
                      <div className="mt-auto flex items-center justify-between gap-2 pt-1">
                        <span className="num text-base font-semibold text-fg" data-testid="catalog-price">
                          {f.money(i.price)} {cur}
                        </span>
                        <span className={cn('text-2xs', i.in_stock ? 'text-ok' : 'text-fg-3')}>{i.in_stock ? t('catalog.inStock') : t('catalog.ask')}</span>
                      </div>
                      {data.shop.phone && (
                        <a href={waLink(data.shop.phone, t('catalog.waText', { name: i.name })) ?? undefined} target="_blank" rel="noopener noreferrer" className="mt-1 inline-flex h-8 items-center justify-center gap-1.5 rounded-md border border-line text-xs text-fg-2 hover:border-accent hover:text-fg focus-visible:outline-2 focus-visible:outline-accent">
                          <MessageCircle className="size-3.5" aria-hidden /> {t('catalog.askWa')}
                        </a>
                      )}
                    </div>
                  </li>
                ))}
              </ul>
            )}
            <p className="mt-6 text-center text-2xs text-fg-3">{t('catalog.note')}</p>
          </>
        )}
      </div>
    </div>
  );
}
