import { useCallback, useEffect, useMemo, useState } from 'react';
import { useParams } from 'react-router';
import { useTranslation } from 'react-i18next';
import { Minus, Plus, Send } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { errorMessage } from '../lib/errors';
import { useFormat } from '../i18n/format';
import { LangToggle, ThemeToggle } from '../ui/ThemeToggle';
import { Textarea } from '../ui/Field';
import { Button } from '../ui/Button';
import { Alert, Skeleton } from '../ui/Feedback';
import { cn } from '../ui/cn';

interface Portal {
  shop: { name: string; branch?: string | null; phone: string | null; currency: string; logo: string | null };
  customer: { name: string };
  balance: number;
  entries: { at: string; type: string; no: number; debit: number; credit: number }[];
  orders: { id: string; at: string; status: 'new' | 'seen' | 'done' | 'cancelled'; lines: { name: string; qty: number }[]; note: string | null }[];
  items: { id: string; name: string; price: number }[];
}

/** C8: بوابة عميل الجملة (رابط خاص): كشف حسابه هو بس، وطلبياته، وطلبية جديدة من أصناف الكتالوج */
export function PortalScreen() {
  const { token = '' } = useParams();
  const { t } = useTranslation();
  const f = useFormat();
  const [data, setData] = useState<Portal | null | undefined>(undefined);
  const [cart, setCart] = useState<Record<string, number>>({});
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ ok: boolean; text: string } | null>(null);
  const load = useCallback(async () => {
    const { data: d, error } = await supabase.rpc('public_portal', { p_token: token });
    setData(error ? null : ((d as Portal | null) ?? null));
  }, [token]);
  useEffect(() => {
    void load();
  }, [load]);
  const lines = useMemo(() => Object.entries(cart).filter(([, q]) => q > 0), [cart]);
  const total = useMemo(() => lines.reduce((a, [id, q]) => a + q * (data?.items.find((i) => i.id === id)?.price ?? 0), 0), [lines, data]);
  const add = (id: string, d: number) => setCart((c) => ({ ...c, [id]: Math.max(0, Math.min(10000, (c[id] ?? 0) + d)) }));
  async function send() {
    if (!lines.length) return;
    setBusy(true);
    setMsg(null);
    const { error } = await supabase.rpc('portal_order', { p_token: token, p_lines: lines.map(([item, qty]) => ({ item, qty })), p_note: note.trim() || null });
    setBusy(false);
    if (error) return setMsg({ ok: false, text: errorMessage(error) });
    setCart({});
    setNote('');
    setMsg({ ok: true, text: t('portal.sent') });
    await load();
  }
  const cur = data ? f.currency(data.shop.currency) : '';
  let running = data?.balance ?? 0;
  return (
    <div className="relative min-h-dvh">
      <div className="mx-auto flex min-h-dvh w-full max-w-3xl flex-col gap-4 px-4 pb-10">
        <header className="flex items-center justify-between py-4">
          <div className="min-w-0">
            <div className="truncate text-lg font-bold text-fg">
              {data?.shop.name ?? t('portal.title')}
              {data?.shop.branch && <span className="ms-2 text-sm font-normal text-fg-3">{data.shop.branch}</span>}
            </div>
            {data && <div className="text-sm text-fg-3">{t('portal.hello', { name: data.customer.name })}</div>}
          </div>
          <div className="flex items-center gap-1">
            <LangToggle />
            <ThemeToggle />
          </div>
        </header>
        {data === undefined ? (
          <Skeleton className="h-60 w-full rounded-2xl" />
        ) : data === null ? (
          <div data-testid="portal-off">
            <Alert tone="warn">{t('portal.closed')}</Alert>
          </div>
        ) : (
          <>
            <section className="glass rounded-2xl p-5" data-testid="portal-balance">
              <div className="readout-label">{t('portal.balance')}</div>
              <div className={cn('num text-2xl', data.balance > 0 ? 'text-warn' : 'text-fg')} data-testid="portal-balance-value">
                {f.money(Math.abs(data.balance))} {cur}
              </div>
              <div className="text-xs text-fg-3">{data.balance > 0 ? t('portal.youOwe') : data.balance < 0 ? t('portal.weOwe') : t('portal.settled')}</div>
            </section>

            {data.items.length > 0 && (
              <section className="glass rounded-2xl p-5" data-testid="portal-order-form">
                <h2 className="text-sm font-semibold text-fg">{t('portal.newOrder')}</h2>
                <ul className="mt-3 divide-y divide-line">
                  {data.items.map((i) => (
                    <li key={i.id} className="flex items-center gap-2 py-2 text-sm" data-testid="portal-item">
                      <span className="min-w-0 flex-1 truncate text-fg">{i.name}</span>
                      <span className="num text-fg-2">
                        {f.money(i.price)} {cur}
                      </span>
                      <button type="button" onClick={() => add(i.id, -1)} aria-label={t('portal.less', { name: i.name })} className="grid size-8 place-items-center rounded-md border border-line text-fg-2 hover:text-fg">
                        <Minus className="size-3.5" />
                      </button>
                      <span className="num w-8 text-center text-fg" data-testid="portal-qty">
                        {cart[i.id] ?? 0}
                      </span>
                      <button type="button" onClick={() => add(i.id, 1)} aria-label={t('portal.more', { name: i.name })} className="grid size-8 place-items-center rounded-md border border-line text-fg-2 hover:text-fg">
                        <Plus className="size-3.5" />
                      </button>
                    </li>
                  ))}
                </ul>
                <Textarea rows={2} value={note} onChange={(e) => setNote(e.target.value)} placeholder={t('portal.notePh')} className="mt-3" aria-label={t('comm.note')} />
                <div className="mt-3 flex items-center justify-between gap-2">
                  <span className="num text-sm text-fg-2">
                    {t('portal.estimate')}: {f.money(total)} {cur}
                  </span>
                  <Button variant="primary" loading={busy} disabled={!lines.length} onClick={() => void send()} icon={<Send className="size-4" />} data-testid="portal-send">
                    {t('portal.send')}
                  </Button>
                </div>
                {msg && (
                  <div className="mt-3">
                    <Alert tone={msg.ok ? 'ok' : 'danger'}>{msg.text}</Alert>
                  </div>
                )}
              </section>
            )}

            {data.orders.length > 0 && (
              <section className="glass rounded-2xl p-5">
                <h2 className="text-sm font-semibold text-fg">{t('portal.myOrders')}</h2>
                <ul className="mt-2 divide-y divide-line text-sm" data-testid="portal-my-orders">
                  {data.orders.map((o) => (
                    <li key={o.id} className="flex items-center justify-between gap-2 py-2">
                      <span className="min-w-0 flex-1 truncate text-fg">{o.lines.map((l) => `${l.name} × ${l.qty}`).join(t('common.sep'))}</span>
                      <span className="text-2xs text-fg-3">{f.date(o.at)}</span>
                      <span className="rounded-sm bg-raised px-1.5 py-0.5 text-2xs text-fg-2">{t(`portal.s.${o.status}`)}</span>
                    </li>
                  ))}
                </ul>
              </section>
            )}

            <section className="glass rounded-2xl p-5">
              <h2 className="text-sm font-semibold text-fg">{t('portal.statement')}</h2>
              {data.entries.length === 0 ? (
                <p className="mt-2 text-xs text-fg-3">{t('portal.noEntries')}</p>
              ) : (
                <div className="mt-2 overflow-x-auto">
                  <table className="w-full min-w-[420px] text-sm [&_td]:py-1.5 [&_th]:py-1.5 [&_th]:text-start [&_th]:font-medium" data-testid="portal-entries">
                    <thead className="text-2xs text-fg-3">
                      <tr>
                        <th>{t('portal.date')}</th>
                        <th>{t('portal.kind')}</th>
                        <th>{t('portal.debit')}</th>
                        <th>{t('portal.credit')}</th>
                        <th>{t('portal.after')}</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.entries.map((e) => {
                        const after = running;
                        running -= Number(e.debit) - Number(e.credit);
                        return (
                          <tr key={e.no} className="border-t border-line">
                            <td className="text-fg-2">{f.date(e.at)}</td>
                            <td>{t(`fin.src.${e.type}`, { defaultValue: t('entry.other') })}</td>
                            <td className="num">{Number(e.debit) ? f.money(Number(e.debit)) : ''}</td>
                            <td className="num">{Number(e.credit) ? f.money(Number(e.credit)) : ''}</td>
                            <td className="num">{f.money(after)}</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </>
        )}
      </div>
    </div>
  );
}
