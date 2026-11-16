import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { motion } from 'motion/react';
import { ArrowDown, ArrowUp, Archive, ChevronLeft, FolderPlus, Pencil, Search, ShoppingCart, Sparkles } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useMe } from '../app/auth';
import { useBranch } from '../app/branch';
import { usePerms } from '../app/perms';
import { useLoad } from '../app/useLoad';
import { rpc, type StockRow } from '../app/ledgerApi';
import { useFormat } from '../i18n/format';
import { LineIcon, LINE_ICONS, type LineIconName } from '../ui/fx/LineIcon';
import { Panel } from '../ui/Panel';
import { Field, Input, Select } from '../ui/Field';
import { Button } from '../ui/Button';
import { Dialog } from '../ui/Dialog';
import { Alert, EmptyState, Skeleton } from '../ui/Feedback';
import { useToast } from '../ui/Toast';
import { cn } from '../ui/cn';
import DEFAULTS from '../data/categoryDefaults.json';

export interface Cat {
  id: string;
  parent_id: string | null;
  section: 'products' | 'services';
  name: string;
  icon: string | null;
  sort: number;
  items: number;
  in_stock: number;
}
/** أيقونات التصنيفات المتاحة للاختيار (من أيقونات البرنامج المرسومة) */
export const CATEGORY_ICONS = ['box', 'chip', 'screen', 'battery', 'backglass', 'charge', 'camera', 'speaker', 'flex', 'frame', 'case', 'glass', 'cable', 'earphones', 'powerbank', 'watch', 'screwdriver', 'tool', 'gamepad', 'phone_new', 'tablet', 'brand', 'inspect', 'cleaning', 'software', 'transfer', 'unlock'] as const;
const iconOf = (c: { icon: string | null }): LineIconName => (c.icon && c.icon in LINE_ICONS ? (c.icon as LineIconName) : 'box');

/**
 * K: تصفح التصنيفات: شجرة على الجنب (المنتجات والخدمات)، وبلاطات بأيقونات البرنامج للتصنيفات الفرعية،
 * وجوه كل تصنيف أصنافه (بالمتوفر في الفرع المعروض). وصاحب المحل بيضيف ويعدّل ويرتّب ويأرشف.
 */
export function CategoriesScreen() {
  const { t, i18n } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const navigate = useNavigate();
  const { profile, shop } = useMe();
  const br = useBranch();
  const { grant } = usePerms();
  const owner = profile.role === 'owner';
  const manage = owner || grant('item_create', 'add');
  const [params, setParams] = useSearchParams();
  const sel = params.get('c');
  const [q, setQ] = useState('');
  const [edit, setEdit] = useState<{ mode: 'add' | 'edit'; cat?: Cat; parent: string | null; section: Cat['section'] } | null>(null);
  const [ordering, setOrdering] = useState(false);
  const [busy, setBusy] = useState(false);

  const { data, error, reload } = useLoad(async () => {
    const [cats, items] = await Promise.all([
      rpc('category_tree', { p_branch: br.filter }) as Promise<Cat[]>,
      rpc('items_stock', br.filter ? {} : { p_all: br.multi }, { branch: br.filter }) as Promise<StockRow[]>,
    ]);
    const { data: links } = await supabase.from('items').select('id, category_id').is('deleted_at', null).not('category_id', 'is', null);
    const catOf = new Map(((links ?? []) as { id: string; category_id: string }[]).map((x) => [x.id, x.category_id]));
    return { cats: cats.map((c) => ({ ...c, items: Number(c.items), in_stock: Number(c.in_stock) })), items: items.map((i) => ({ ...i, qty: Number(i.qty), category_id: catOf.get(i.id) ?? null })) };
  }, [br.filter, br.multi]);

  const cats = data?.cats ?? [];
  const current = cats.find((c) => c.id === sel) ?? null;
  const parent = current?.parent_id ? (cats.find((c) => c.id === current.parent_id) ?? null) : null;
  const tops = (section: Cat['section']) => cats.filter((c) => !c.parent_id && c.section === section);
  const children = current ? cats.filter((c) => c.parent_id === current.id) : [];
  const search = q.trim().toLowerCase();
  const items = useMemo(() => {
    if (!data) return [];
    if (search) return data.items.filter((i) => (i.kind as string) !== 'used' || i.qty > 0).filter((i) => i.name.toLowerCase().includes(search)).slice(0, 60);
    if (!current) return [];
    return data.items.filter((i) => i.category_id === current.id && ((i.kind as string) !== 'used' || i.qty > 0));
  }, [data, current, search]);
  const go = (id: string | null) => {
    setQ('');
    setOrdering(false);
    setParams(id ? { c: id } : {}, { replace: false });
  };
  // أول ما الشاشة تفتح: أول تصنيف رئيسي
  useEffect(() => {
    if (!sel && cats.length) setParams({ c: tops('products')[0]?.id ?? cats[0].id }, { replace: true });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [cats.length, sel]);

  async function seed() {
    setBusy(true);
    try {
      const tree = i18n.language === 'en' ? DEFAULTS.en : DEFAULTS.ar;
      const n = (await rpc('seed_categories', { p_tree: tree })) as number;
      toast({ tone: 'ok', title: t('cats.seeded', { n }) });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  }
  async function archive(c: Cat) {
    const { error: e } = await supabase.from('categories').update({ deleted_at: new Date().toISOString() }).eq('id', c.id);
    if (e) return toast({ tone: 'danger', title: errorMessage(e) });
    toast({ tone: 'ok', title: t('cats.archived', { name: c.name }) });
    go(c.parent_id);
    reload();
  }
  async function move(list: Cat[], i: number, d: number) {
    const j = i + d;
    if (j < 0 || j >= list.length) return;
    const ids = list.map((x) => x.id);
    [ids[i], ids[j]] = [ids[j], ids[i]];
    try {
      await rpc('reorder_categories', { p_ids: ids });
      reload();
    } catch (e) {
      toast({ tone: 'danger', title: errorMessage(e) });
    }
  }

  const cur = f.currency(shop.currency);
  const tiles = current && !current.parent_id ? children : [];
  return (
    <div className="flex min-h-0 flex-col gap-4 lg:flex-row-reverse" data-testid="categories">
      {/* المحتوى */}
      <div className="min-w-0 flex-1">
        <div className="mb-3 flex flex-wrap items-center gap-2">
          <nav className="flex min-w-0 basis-full items-center gap-1 text-sm sm:basis-auto sm:flex-1" aria-label={t('cats.path')}>
            {parent && (
              <>
                <button type="button" onClick={() => go(parent.id)} className="truncate text-fg-3 hover:text-fg">
                  {parent.name}
                </button>
                <ChevronLeft className="size-3.5 shrink-0 text-fg-3 ltr:rotate-180" aria-hidden />
              </>
            )}
            <h1 className="truncate text-lg font-semibold text-fg" data-testid="cats-title">
              {search ? t('cats.results') : (current?.name ?? t('cats.title'))}
            </h1>
            {current && !search && (
              <span className="num shrink-0 rounded-sm border border-line px-1.5 text-2xs text-fg-3" data-testid="cats-count">
                {t('cats.count', { n: current.items })}
              </span>
            )}
          </nav>
          <div className="relative min-w-0 flex-1 sm:flex-none">
            <Search className="pointer-events-none absolute start-2 top-1/2 size-3.5 -translate-y-1/2 text-fg-3" aria-hidden />
            <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('cats.search')} className="h-8 w-full ps-7 text-sm sm:w-52" aria-label={t('cats.search')} data-testid="cats-search" />
          </div>
          {manage && current && !search && (
            <div className="flex flex-wrap gap-1">
              {!current.parent_id && (
                <Button size="sm" onClick={() => setEdit({ mode: 'add', parent: current.id, section: current.section })} icon={<FolderPlus className="size-3.5" />} data-testid="cats-add-sub">
                  {t('cats.addSub')}
                </Button>
              )}
              <Button size="sm" variant="ghost" onClick={() => setEdit({ mode: 'edit', cat: current, parent: current.parent_id, section: current.section })} icon={<Pencil className="size-3.5" />} data-testid="cats-edit">
                {t('cats.edit')}
              </Button>
              {owner && tiles.length > 1 && (
                <Button size="sm" variant="ghost" aria-pressed={ordering} onClick={() => setOrdering((o) => !o)} data-testid="cats-order">
                  {ordering ? t('cats.orderDone') : t('cats.order')}
                </Button>
              )}
              <Button size="sm" variant="ghost" disabled={current.items > 0 || children.length > 0} title={current.items > 0 || children.length > 0 ? t('cats.notEmpty') : undefined} onClick={() => void archive(current)} icon={<Archive className="size-3.5" />} data-testid="cats-archive">
                {t('cats.archive')}
              </Button>
            </div>
          )}
        </div>

        {error ? (
          <Alert tone="danger">{error}</Alert>
        ) : !data ? (
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-5">
            {Array.from({ length: 10 }, (_, i) => (
              <Skeleton key={i} className="h-36 rounded-xl" />
            ))}
          </div>
        ) : cats.length === 0 ? (
          <Panel>
            <EmptyState line="box" title={t('cats.empty')} action={owner ? <Button variant="primary" loading={busy} onClick={() => void seed()} icon={<Sparkles className="size-4" />} data-testid="cats-seed">{t('cats.seed')}</Button> : undefined}>
              {t('cats.emptyHint')}
            </EmptyState>
          </Panel>
        ) : (
          <>
            {/* التصنيفات الفرعية */}
            {!search && tiles.length > 0 && (
              <ul className="grid grid-cols-2 gap-3 sm:grid-cols-4 xl:grid-cols-5" data-testid="cats-tiles">
                {tiles.map((c, i) => (
                  <motion.li key={c.id} layout transition={{ duration: 0.18 }} className="relative">
                    <button
                      type="button"
                      onClick={() => !ordering && go(c.id)}
                      className={cn('glass group flex h-full w-full flex-col items-center gap-1.5 rounded-xl p-3 text-center transition-colors focus-visible:outline-2 focus-visible:outline-accent sm:gap-2 sm:p-4', !ordering && 'hover:border-accent')}
                      data-testid="cats-tile"
                    >
                      {c.icon === 'brand' ? (
                        <span className="grid h-12 w-full place-items-center rounded-lg bg-sunken px-2 text-base font-bold tracking-wide text-fg sm:h-14" dir="ltr">
                          {c.name}
                        </span>
                      ) : (
                        <LineIcon name={iconOf(c)} size={56} draw={false} className="size-10 text-fg-2 transition-colors group-hover:text-accent sm:size-14" />
                      )}
                      {/* الماركة اسمها جوه البلاطة، فمش بيتكرر */}
                      {c.icon !== 'brand' && <span className="line-clamp-2 text-sm font-medium text-fg">{c.name}</span>}
                      <span className="num text-2xs text-fg-3">
                        {t('cats.count', { n: c.items })}
                        {c.items > 0 && c.section === 'products' && ` · ${t('cats.available', { n: c.in_stock })}`}
                      </span>
                    </button>
                    {ordering && (
                      <div className="absolute end-1 top-1 flex gap-0.5">
                        <button type="button" onClick={() => void move(tiles, i, -1)} disabled={i === 0} aria-label={t('checksTpl.up')} className="grid size-7 place-items-center rounded-sm bg-raised text-fg-2 disabled:opacity-30">
                          <ArrowUp className="size-3.5" />
                        </button>
                        <button type="button" onClick={() => void move(tiles, i, 1)} disabled={i === tiles.length - 1} aria-label={t('checksTpl.down')} className="grid size-7 place-items-center rounded-sm bg-raised text-fg-2 disabled:opacity-30">
                          <ArrowDown className="size-3.5" />
                        </button>
                      </div>
                    )}
                  </motion.li>
                ))}
              </ul>
            )}

            {/* الأصناف */}
            {(search || items.length > 0 || (current && tiles.length === 0)) && (
              <section className={cn(tiles.length > 0 && !search && 'mt-5')}>
                {tiles.length > 0 && !search && items.length > 0 && <h2 className="mb-2 text-sm font-medium text-fg-2">{t('cats.direct')}</h2>}
                {items.length === 0 ? (
                  <Panel>
                    <EmptyState line="box" title={search ? t('cats.noResults') : t('cats.noItems')}>
                      {!search && manage ? t('cats.noItemsHint') : null}
                    </EmptyState>
                  </Panel>
                ) : (
                  <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-4" data-testid="cats-items">
                    {items.map((i) => {
                      const service = (i.kind as string) === 'service';
                      const ok = service || i.qty > 0;
                      return (
                        <li key={i.id} className="glass flex flex-col gap-1 rounded-xl p-3" data-testid="cats-item">
                          <div className="line-clamp-2 min-h-[2.5rem] text-sm font-medium text-fg">{i.name}</div>
                          <div className="flex items-center justify-between gap-2">
                            <span className="num text-sm text-fg">{i.sale_price != null ? `${f.money(i.sale_price)} ${cur}` : '—'}</span>
                            <span className={cn('text-2xs', service ? 'text-accent' : ok ? 'text-ok' : 'text-fg-3')}>{service ? t('cats.service') : ok ? t('cats.inStock', { n: i.qty }) : t('cats.out')}</span>
                          </div>
                          <div className="mt-1 flex gap-1">
                            {(ok || service) && (
                              <Button size="sm" variant="secondary" className="flex-1 justify-center" onClick={() => navigate(`/inventory?do=sale&item=${i.id}`)} icon={<ShoppingCart className="size-3.5" />} data-testid="cats-sell">
                                {t('cats.sell')}
                              </Button>
                            )}
                          </div>
                        </li>
                      );
                    })}
                  </ul>
                )}
              </section>
            )}
          </>
        )}
      </div>

      {/* الشجرة (على الموبايل فوق كشرائح) */}
      {/* على الموبايل فوق (شرائح)، وعلى الكمبيوتر على الجنب */}
      <aside className="order-first shrink-0 lg:order-none lg:w-64" aria-label={t('cats.title')}>
        <Panel className="p-2">
          {(['products', 'services'] as const).map((sec) => {
            const list = tops(sec);
            return (
              <div key={sec} className="mb-2 last:mb-0">
                <div className="flex items-center justify-between px-2 py-1.5">
                  <span className="text-xs font-semibold text-fg-2">{t(`cats.sections.${sec}`)}</span>
                  {manage && (
                    <button type="button" onClick={() => setEdit({ mode: 'add', parent: null, section: sec })} aria-label={t('cats.addTop', { section: t(`cats.sections.${sec}`) })} className="grid size-6 place-items-center rounded-sm text-fg-3 hover:bg-raised hover:text-fg" data-testid={`cats-add-${sec}`}>
                      <FolderPlus className="size-3.5" />
                    </button>
                  )}
                </div>
                <ul className="flex gap-1 overflow-x-auto pb-1 lg:flex-col lg:overflow-visible lg:pb-0">
                  {list.map((c, i) => {
                    const active = c.id === sel || c.id === current?.parent_id;
                    return (
                      <li key={c.id} className="flex shrink-0 items-center gap-1">
                        <button
                          type="button"
                          onClick={() => go(c.id)}
                          aria-current={active ? 'page' : undefined}
                          className={cn('flex min-w-0 flex-1 items-center gap-2 rounded-md px-2 py-1.5 text-start text-sm focus-visible:outline-2 focus-visible:outline-accent', active ? 'bg-accent-soft text-fg' : 'text-fg-2 hover:bg-raised hover:text-fg')}
                          data-testid="cats-top"
                        >
                          <LineIcon name={iconOf(c)} size={20} draw={false} className="shrink-0" />
                          <span className="truncate">{c.name}</span>
                          <span className="num ms-auto text-2xs text-fg-3">{c.items}</span>
                        </button>
                        {owner && ordering && !current?.parent_id && (
                          <span className="hidden gap-0.5 lg:flex">
                            <button type="button" onClick={() => void move(list, i, -1)} disabled={i === 0} aria-label={t('checksTpl.up')} className="grid size-6 place-items-center rounded-sm text-fg-3 disabled:opacity-30">
                              <ArrowUp className="size-3" />
                            </button>
                            <button type="button" onClick={() => void move(list, i, 1)} disabled={i === list.length - 1} aria-label={t('checksTpl.down')} className="grid size-6 place-items-center rounded-sm text-fg-3 disabled:opacity-30">
                              <ArrowDown className="size-3" />
                            </button>
                          </span>
                        )}
                      </li>
                    );
                  })}
                  {list.length === 0 && <li className="px-2 py-1 text-2xs text-fg-3">{t('cats.none')}</li>}
                </ul>
              </div>
            );
          })}
        </Panel>
        {owner && cats.length > 0 && (
          <Button size="sm" variant="ghost" loading={busy} onClick={() => void seed()} icon={<Sparkles className="size-3.5" />} className="mt-2 w-full justify-center" data-testid="cats-seed-more">
            {t('cats.seedMore')}
          </Button>
        )}
      </aside>

      <CategoryDialog state={edit} onClose={() => setEdit(null)} onSaved={(id) => (setEdit(null), reload(), id && go(id))} />
    </div>
  );
}

function CategoryDialog({ state, onClose, onSaved }: { state: { mode: 'add' | 'edit'; cat?: Cat; parent: string | null; section: Cat['section'] } | null; onClose: () => void; onSaved: (id: string | null) => void }) {
  const { t } = useTranslation();
  const [name, setName] = useState('');
  const [icon, setIcon] = useState<string>('box');
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useEffect(() => {
    setName(state?.cat?.name ?? '');
    setIcon(state?.cat?.icon ?? (state?.section === 'services' ? 'tool' : 'box'));
    setErr(null);
  }, [state]);
  async function save() {
    if (!state) return;
    setErr(null);
    if (!name.trim()) return setErr(t('cats.needName'));
    setBusy(true);
    const id = state.cat?.id ?? crypto.randomUUID();
    const r = state.mode === 'edit'
      ? await supabase.from('categories').update({ name: name.trim(), icon }).eq('id', id)
      : await supabase.from('categories').insert({ id, parent_id: state.parent, section: state.section, name: name.trim(), icon });
    setBusy(false);
    if (r.error) return setErr(/duplicate|unique/i.test(r.error.message) ? t('cats.dup') : errorMessage(r.error));
    onSaved(state.mode === 'add' ? id : null);
  }
  return (
    <Dialog
      open={!!state}
      onOpenChange={(v) => !v && onClose()}
      title={state?.mode === 'edit' ? t('cats.edit') : state?.parent ? t('cats.addSub') : t('cats.addTop', { section: t(`cats.sections.${state?.section ?? 'products'}`) })}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} onClick={() => void save()} data-testid="cat-save">
            {t('common.save')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <Field label={t('cats.name')} required>
          <Input value={name} onChange={(e) => setName(e.target.value)} maxLength={60} autoFocus data-testid="cat-name" />
        </Field>
        <div>
          <div className="mb-1.5 text-xs text-fg-2">{t('cats.icon')}</div>
          <div className="grid grid-cols-6 gap-1.5 sm:grid-cols-9" role="radiogroup" aria-label={t('cats.icon')}>
            {CATEGORY_ICONS.map((k) => (
              <button key={k} type="button" role="radio" aria-checked={icon === k} aria-label={t(`cats.icons.${k}`)} onClick={() => setIcon(k)} className={cn('grid aspect-square place-items-center rounded-md border focus-visible:outline-2 focus-visible:outline-accent', icon === k ? 'border-accent bg-accent-soft text-fg' : 'border-line text-fg-3 hover:text-fg')}>
                <LineIcon name={k} size={26} draw={false} />
              </button>
            ))}
          </div>
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** K: اختيار التصنيف (رئيسي ← فرعي) في فورم الصنف */
export function CategorySelect({ value, onChange, testid = 'item-category-id' }: { value: string; onChange: (id: string) => void; testid?: string }) {
  const { t } = useTranslation();
  const { data } = useLoad(async () => ((await supabase.from('categories').select('id, parent_id, section, name, sort').is('deleted_at', null).order('sort')).data ?? []) as Pick<Cat, 'id' | 'parent_id' | 'section' | 'name' | 'sort'>[], []);
  const tops = (data ?? []).filter((c) => !c.parent_id);
  return (
    <Select value={value} onChange={(e) => onChange(e.target.value)} data-testid={testid} aria-label={t('cats.pick')}>
      <option value="">{t('cats.noCategory')}</option>
      {tops.map((top) => (
        <optgroup key={top.id} label={top.name}>
          <option value={top.id}>{top.name}</option>
          {(data ?? [])
            .filter((c) => c.parent_id === top.id)
            .map((c) => (
              <option key={c.id} value={c.id}>
                {`${top.name} ← ${c.name}`}
              </option>
            ))}
        </optgroup>
      ))}
    </Select>
  );
}
