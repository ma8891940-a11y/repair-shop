import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useTranslation } from 'react-i18next';
import { ArrowLeftRight, Link2, Unlink } from 'lucide-react';
import { useLoad } from '../useLoad';
import { opId, rpc } from '../ledgerApi';
import { useUndoable } from '../correct';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { formatPounds, parsePounds } from '../../lib/money';
import { useFormat } from '../../i18n/format';
import { Button } from '../../ui/Button';
import { Dialog } from '../../ui/Dialog';
import { Field, Input } from '../../ui/Field';
import { Alert } from '../../ui/Feedback';
import { useToast } from '../../ui/Toast';

export interface LinkInfo {
  id: string;
  customer_id: string;
  supplier_id: string;
  customer: string;
  supplier: string;
  receivable: number;
  payable: number;
  net: number;
  max_netting: number;
}

export async function loadLink(kind: 'customer' | 'supplier' | 'link', id: string): Promise<LinkInfo | null> {
  const i = await rpc<LinkInfo | null>('party_link_info', { p_kind: kind, p_id: id });
  return i ? { ...i, receivable: Number(i.receivable), payable: Number(i.payable), net: Number(i.net), max_netting: Number(i.max_netting) } : null;
}

/**
 * ربط عميل بمورد (نفس الشخص): في كشف العميل أو المورد. لو مربوط: الكشف الصافي، والمقاصة، وفك الربط.
 * لو مش مربوط: زرار "اربط" بيختار الطرف التاني.
 */
export function PartyLinkBar({ kind, id, name, onChanged }: { kind: 'customer' | 'supplier'; id: string; name: string; onChanged: () => void }) {
  const { t } = useTranslation();
  const { data, reload } = useLoad(() => loadLink(kind, id), [kind, id]);
  const [pick, setPick] = useState(false);
  const [net, setNet] = useState<LinkInfo | null>(null);
  const undoable = useUndoable();
  const done = () => {
    reload();
    onChanged();
  };
  if (data === undefined) return null;
  return (
    <div className="mb-3 flex flex-wrap items-center gap-2 rounded-md border border-glass-border bg-sunken/40 px-3 py-2 text-sm" data-testid="party-link">
      <Link2 className="size-4 text-fg-3" aria-hidden />
      {data ? (
        <>
          <span className="text-fg-2" data-testid="party-link-with">
            {t(kind === 'customer' ? 'link.withSupplier' : 'link.withCustomer', { name: kind === 'customer' ? data.supplier : data.customer })}
          </span>
          <div className="ms-auto flex flex-wrap gap-2">
            <Link to={`/finance/linked/${data.id}`} className="inline-flex h-8 items-center gap-1.5 rounded-md border border-line px-3 text-xs text-fg-2 hover:border-accent hover:text-fg" data-testid="party-link-net">
              {t('link.netStatement')}
            </Link>
            <Button size="sm" icon={<ArrowLeftRight className="size-4" />} onClick={() => setNet(data)} disabled={data.max_netting <= 0} data-testid="party-link-netting">
              {t('link.netting')}
            </Button>
            <Button
              size="sm"
              variant="ghost"
              icon={<Unlink className="size-4" />}
              onClick={() => undoable({ title: t('link.unlinking'), done: t('link.unlinked'), run: () => rpc('unlink_parties', { p_link: data.id }), onDone: done })}
              data-testid="party-link-unlink"
            >
              {t('link.unlink')}
            </Button>
          </div>
        </>
      ) : (
        <>
          <span className="text-fg-3">{t(kind === 'customer' ? 'link.noneCustomer' : 'link.noneSupplier')}</span>
          <Button size="sm" variant="ghost" className="ms-auto" onClick={() => setPick(true)} data-testid="party-link-add">
            {t(kind === 'customer' ? 'link.linkSupplier' : 'link.linkCustomer')}
          </Button>
        </>
      )}
      <PickDialog open={pick} kind={kind} id={id} name={name} onOpenChange={setPick} onDone={done} />
      <NettingDialog info={net} onOpenChange={(v) => !v && setNet(null)} onDone={done} />
    </div>
  );
}

/** اختيار الطرف التاني: بحث بالاسم (والتليفون للعملاء) */
function PickDialog({ open, kind, id, name, onOpenChange, onDone }: { open: boolean; kind: 'customer' | 'supplier'; id: string; name: string; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const toast = useToast();
  const [q, setQ] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const other = kind === 'customer' ? 'suppliers' : 'customers';
  useEffect(() => {
    setQ(name);
    setErr(null);
  }, [open, name]);
  const list = useLoad(async () => {
    if (!open) return [];
    let qb = supabase.from(other).select('id, name, phone').is('deleted_at', null).order('name').limit(20);
    const s = q.trim().replace(/[%_,()]/g, ' ').trim();
    if (s) qb = qb.or(`name.ilike.%${s}%,phone.ilike.%${s}%`);
    return ((await qb).data ?? []) as { id: string; name: string; phone: string | null }[];
  }, [open, q, other]);
  const linkId = useMemo(() => (open ? opId() : ''), [open]);
  async function choose(otherId: string) {
    setErr(null);
    try {
      await rpc('link_parties', { p_id: linkId, p_customer: kind === 'customer' ? id : otherId, p_supplier: kind === 'customer' ? otherId : id });
      toast({ tone: 'ok', title: t('link.linked') });
      onOpenChange(false);
      onDone();
    } catch (e) {
      setErr(errorMessage(e));
    }
  }
  return (
    <Dialog open={open} onOpenChange={onOpenChange} title={t(kind === 'customer' ? 'link.linkSupplier' : 'link.linkCustomer')} description={t('link.hint')}>
      <div className="flex flex-col gap-2">
        <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder={t('link.search')} aria-label={t('link.search')} autoFocus />
        <ul className="max-h-64 divide-y divide-glass-border overflow-auto rounded-md border border-glass-border" data-testid="party-link-options">
          {(list.data ?? []).map((o) => (
            <li key={o.id}>
              <button type="button" onClick={() => void choose(o.id)} className="flex w-full items-center justify-between px-3 py-2 text-start text-sm hover:bg-raised">
                <span className="text-fg">{o.name}</span>
                {o.phone && (
                  <span className="num text-2xs text-fg-3" dir="ltr">
                    {o.phone}
                  </span>
                )}
              </button>
            </li>
          ))}
          {list.data?.length === 0 && <li className="px-3 py-2 text-sm text-fg-3">{t('link.noResults')}</li>}
        </ul>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}

/** المقاصة: بتخصم اللي عليه كعميل من اللي ليه كمورد، لحد أقل رصيد فيهم */
export function NettingDialog({ info, onOpenChange, onDone }: { info: LinkInfo | null; onOpenChange: (v: boolean) => void; onDone: () => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const toast = useToast();
  const [amount, setAmount] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const id = useMemo(() => (info ? opId() : ''), [info]);
  useEffect(() => {
    setAmount(info ? formatPounds(info.max_netting) : '');
    setErr(null);
  }, [info]);
  async function go() {
    if (!info) return;
    const a = parsePounds(amount);
    if (!a || a <= 0 || a > info.max_netting) return setErr(t('link.errAmount', { max: f.money(info.max_netting) }));
    setBusy(true);
    try {
      await rpc('net_parties', { p_id: id, p_link: info.id, p_amount: a });
      toast({ tone: 'ok', title: t('link.netted', { v: f.money(a) }) });
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
      open={!!info}
      onOpenChange={onOpenChange}
      title={t('link.netting')}
      description={t('link.nettingHint')}
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t('common.cancel')}
          </Button>
          <Button variant="primary" loading={busy} onClick={() => void go()} data-testid="netting-confirm">
            {t('link.nettingNow')}
          </Button>
        </>
      }
    >
      {info && (
        <div className="flex flex-col gap-3 text-sm">
          <dl className="grid grid-cols-2 gap-2">
            <dt className="text-fg-3">{t('link.owesUs', { name: info.customer })}</dt>
            <dd className="num text-end text-fg" dir="ltr">
              {f.money(info.receivable)}
            </dd>
            <dt className="text-fg-3">{t('link.weOwe', { name: info.supplier })}</dt>
            <dd className="num text-end text-fg" dir="ltr">
              {f.money(info.payable)}
            </dd>
          </dl>
          <Field label={t('fin.amount')} hint={t('link.max', { max: f.money(info.max_netting) })}>
            <Input mono inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} suffix={f.currency()} data-testid="netting-amount" />
          </Field>
          {err && <Alert tone="danger">{err}</Alert>}
        </div>
      )}
    </Dialog>
  );
}
