import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import * as RD from '@radix-ui/react-dialog';
import { AnimatePresence, motion } from 'motion/react';
import { useTranslation } from 'react-i18next';
import { CornerDownLeft, Search, Smartphone } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { buildSearchFilter } from '../lib/search';
import type { DeviceStatus } from '../lib/status';
import { StatusBadge } from './StatusBadge';
import { Kbd } from './Kbd';
import { cn } from './cn';

export interface Command {
  id: string;
  label: string;
  hint?: string;
  icon?: ReactNode;
  shortcut?: string;
  run: () => void;
}

interface DeviceHit {
  id: string;
  order_no: string;
  brand: string;
  model: string;
  status: DeviceStatus;
  customer_name: string | null;
}

/** لوحة الأوامر (Ctrl+K): أوامر سريعة + بحث فوري في الأجهزة، والتنقل كله بالكيبورد */
export function CommandPalette({ open, onOpenChange, commands, onOpenDevice, showCustomer }: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  commands: Command[];
  onOpenDevice: (id: string) => void;
  showCustomer: boolean;
}) {
  const { t, i18n } = useTranslation();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<DeviceHit[]>([]);
  const [searching, setSearching] = useState(false);
  const [active, setActive] = useState(0);
  const listRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) {
      setQ('');
      setHits([]);
      setActive(0);
    }
  }, [open]);

  useEffect(() => {
    const cols = showCustomer ? ['order_no', 'imei', 'customer_name', 'customer_phone', 'model'] : ['order_no', 'imei', 'model'];
    const f = buildSearchFilter(q, cols);
    if (!f) {
      setHits([]);
      return;
    }
    let live = true;
    setSearching(true);
    const tm = setTimeout(async () => {
      const { data } = await supabase.from('devices_list').select('id, order_no, brand, model, status, customer_name').is('deleted_at', null).or(f).order('received_at', { ascending: false }).limit(6);
      if (!live) return;
      setHits((data ?? []) as DeviceHit[]);
      setSearching(false);
    }, 160);
    return () => {
      live = false;
      clearTimeout(tm);
    };
  }, [q, showCustomer]);

  const filtered = useMemo(() => {
    const s = q.trim().toLowerCase();
    return s ? commands.filter((c) => c.label.toLowerCase().includes(s) || c.hint?.toLowerCase().includes(s)) : commands;
  }, [q, commands]);

  const items: { kind: 'device' | 'cmd'; id: string; run: () => void }[] = [
    ...hits.map((h) => ({ kind: 'device' as const, id: h.id, run: () => onOpenDevice(h.id) })),
    ...filtered.map((c) => ({ kind: 'cmd' as const, id: c.id, run: c.run })),
  ];

  useEffect(() => setActive(0), [q, hits.length]);
  useEffect(() => {
    listRef.current?.querySelector(`[data-idx="${active}"]`)?.scrollIntoView({ block: 'nearest' });
  }, [active]);

  const choose = (i: number) => {
    const it = items[i];
    if (!it) return;
    onOpenChange(false);
    setTimeout(it.run, 0);
  };

  return (
    <RD.Root open={open} onOpenChange={onOpenChange}>
      <AnimatePresence>
        {open && (
          <RD.Portal forceMount>
            <RD.Overlay asChild forceMount>
              <motion.div className="fixed inset-0 z-50 bg-[rgb(4_8_10/0.5)] backdrop-blur-[3px]" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.15 }} />
            </RD.Overlay>
            <RD.Content asChild forceMount aria-describedby={undefined}>
              <motion.div
                dir={i18n.dir()}
                initial={{ opacity: 0, y: -12, scale: 0.98 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -8, scale: 0.98 }}
                transition={{ duration: 0.18, ease: [0.2, 0.8, 0.2, 1] }}
                className="glass-strong fixed left-1/2 top-[12vh] z-50 w-[min(94vw,620px)] -translate-x-1/2 overflow-hidden rounded-xl focus:outline-none"
                onKeyDown={(e) => {
                  if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    setActive((a) => Math.min(items.length - 1, a + 1));
                  } else if (e.key === 'ArrowUp') {
                    e.preventDefault();
                    setActive((a) => Math.max(0, a - 1));
                  } else if (e.key === 'Enter') {
                    e.preventDefault();
                    choose(active);
                  }
                }}
              >
                <RD.Title className="sr-only">{t('palette.title')}</RD.Title>
                <div className="flex items-center gap-3 border-b border-glass-border px-4">
                  <Search className={cn('size-4 shrink-0', searching ? 'animate-pulse text-accent' : 'text-fg-3')} aria-hidden />
                  <input
                    autoFocus
                    value={q}
                    onChange={(e) => setQ(e.target.value)}
                    placeholder={showCustomer ? t('palette.placeholder') : t('palette.placeholderTech')}
                    className="h-14 flex-1 bg-transparent text-md text-fg placeholder:text-fg-3 focus:outline-none"
                    role="combobox"
                    aria-expanded
                    aria-controls="palette-list"
                    aria-activedescendant={items[active] ? `pal-${active}` : undefined}
                  />
                  <Kbd>Esc</Kbd>
                </div>
                <div ref={listRef} id="palette-list" role="listbox" className="max-h-[52vh] overflow-y-auto p-2">
                  {hits.length > 0 && <div className="readout-label px-2 pb-1 pt-1.5">{t('palette.devices')}</div>}
                  {hits.map((h, i) => (
                    <Row key={h.id} idx={i} active={active === i} onHover={() => setActive(i)} onClick={() => choose(i)}>
                      <Smartphone className="size-4 text-fg-3" aria-hidden />
                      <span className="num text-sm text-fg" dir="ltr">
                        {h.order_no}
                      </span>
                      <span className="min-w-0 flex-1 truncate text-sm text-fg-2">
                        {h.brand} {h.model}
                        {showCustomer && h.customer_name ? ` · ${h.customer_name}` : ''}
                      </span>
                      <StatusBadge status={h.status} size="sm" />
                    </Row>
                  ))}
                  {filtered.length > 0 && <div className="readout-label px-2 pb-1 pt-2">{t('palette.actions')}</div>}
                  {filtered.map((c, j) => {
                    const i = hits.length + j;
                    return (
                      <Row key={c.id} idx={i} active={active === i} onHover={() => setActive(i)} onClick={() => choose(i)}>
                        <span className="text-fg-3">{c.icon}</span>
                        <span className="flex-1 text-sm text-fg">{c.label}</span>
                        {c.hint && <span className="text-xs text-fg-3">{c.hint}</span>}
                        {c.shortcut && <Kbd>{c.shortcut}</Kbd>}
                      </Row>
                    );
                  })}
                  {items.length === 0 && !searching && <div className="px-3 py-8 text-center text-sm text-fg-3">{t('palette.empty')}</div>}
                </div>
                <div className="flex items-center gap-3 border-t border-glass-border px-4 py-2 text-2xs text-fg-3">
                  <span className="flex items-center gap-1">
                    <Kbd>↑</Kbd>
                    <Kbd>↓</Kbd> {t('palette.navigate')}
                  </span>
                  <span className="flex items-center gap-1">
                    <Kbd>
                      <CornerDownLeft className="size-3" />
                    </Kbd>{' '}
                    {t('palette.open')}
                  </span>
                </div>
              </motion.div>
            </RD.Content>
          </RD.Portal>
        )}
      </AnimatePresence>
    </RD.Root>
  );
}

function Row({ idx, active, onHover, onClick, children }: { idx: number; active: boolean; onHover: () => void; onClick: () => void; children: ReactNode }) {
  return (
    <div
      id={`pal-${idx}`}
      data-idx={idx}
      role="option"
      aria-selected={active}
      onPointerMove={onHover}
      onClick={onClick}
      className={cn('relative flex h-10 cursor-pointer items-center gap-3 rounded-md px-3 transition-colors', active ? 'bg-accent-soft' : 'hover:bg-raised/60')}
    >
      {active && <motion.span layoutId="palette-active" className="absolute inset-y-2 start-0 w-0.5 rounded-full bg-accent" transition={{ duration: 0.15 }} />}
      {children}
    </div>
  );
}
