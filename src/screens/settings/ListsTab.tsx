import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Plus, X } from 'lucide-react';
import { LIST_KEYS, readListsEdit, useListLabel, useShopList, type ListKey } from '../../app/lists';
import { useMe } from '../../app/auth';
import { supabase } from '../../lib/supabase';
import { errorMessage } from '../../lib/errors';
import { Checkbox } from '../../ui/Checkbox';
import { useToast } from '../../ui/Toast';
import { STATUSES } from '../../lib/status';
import { Panel, PanelHeader } from '../../ui/Panel';
import { Button } from '../../ui/Button';
import { Input } from '../../ui/Field';

/**
 * الإعدادات ← القوائم (صاحب المحل): الماركات، والملحقات، والألوان، وتصنيفات الأصناف، وأسباب الهالك، والحالات الفرعية.
 * الحذف بيخفي البند من الاختيار بس: الأجهزة والأصناف القديمة اللي عليها القيمة دي بتفضل زي ما هي.
 */
export function ListsTab() {
  const { t } = useTranslation();
  return (
    <div className="flex flex-col gap-4">
      <p className="text-sm text-fg-2">{t('lists.sub')}</p>
      <p className="text-xs text-fg-3">{t('lists.elsewhere')}</p>
      <ListsPermission />
      {LIST_KEYS.filter((k) => k !== 'sub_statuses').map((k) => (
        <ListEditor key={k} list={k} />
      ))}
      <Panel data-testid="list-sub_statuses">
        <PanelHeader title={t('lists.names.sub_statuses')} />
        <p className="px-4 pt-3 text-xs text-fg-3">{t('lists.subStatusesHint')}</p>
        <div className="flex flex-col gap-3 p-4">
          {STATUSES.map((s) => (
            <div key={s} className="rounded-md border border-glass-border p-3" data-testid={`sub-status-${s}`}>
              <div className="mb-2 text-sm font-medium text-fg">{t(`status.${s}`)}</div>
              <Chips list="sub_statuses" parent={s} />
            </div>
          ))}
        </div>
      </Panel>
    </div>
  );
}

function ListEditor({ list }: { list: ListKey }) {
  const { t } = useTranslation();
  return (
    <Panel data-testid={`list-${list}`}>
      <PanelHeader title={t(`lists.names.${list}`)} />
      <div className="p-4">
        <Chips list={list} />
      </div>
    </Panel>
  );
}

function Chips({ list, parent = null }: { list: ListKey; parent?: string | null }) {
  const { t } = useTranslation();
  const label = useListLabel();
  const { items, add, remove } = useShopList(list);
  const [v, setV] = useState('');
  const mine = items.filter((i) => i.parent === parent);
  async function submit() {
    if (await add(v, parent)) setV('');
  }
  return (
    <div className="flex flex-col gap-2">
      <ul className="flex flex-wrap gap-1.5">
        {mine.length === 0 && <li className="text-xs text-fg-3">{t('lists.empty')}</li>}
        {mine.map((i) => (
          <li key={i.value} className="inline-flex items-center gap-1 rounded-full border border-glass-border bg-sunken/40 py-0.5 pe-1 ps-2.5 text-sm text-fg" data-testid="list-item">
            <bdi>{label(list, i.value)}</bdi>
            <button type="button" onClick={() => void remove(i)} className="rounded-full p-0.5 text-fg-3 hover:bg-raised hover:text-danger" aria-label={t('lists.remove', { v: label(list, i.value) })} title={t('lists.remove', { v: label(list, i.value) })}>
              <X className="size-3" aria-hidden />
            </button>
          </li>
        ))}
      </ul>
      <form
        className="flex gap-2"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        <Input value={v} onChange={(e) => setV(e.target.value)} maxLength={60} placeholder={t('lists.newItem')} aria-label={t('lists.newItemFor', { list: parent ? t(`status.${parent}`) : t(`lists.names.${list}`) })} className="max-w-xs" />
        <Button type="submit" size="sm" icon={<Plus className="size-4" />} disabled={!v.trim()}>
          {t('lists.add')}
        </Button>
      </form>
    </div>
  );
}

/** مين يقدر يضيف ويشيل من القوايم من أي شاشة (صاحب المحل دايمًا). بيتطبق على طول، ومتسجل في سجل النشاط */
function ListsPermission() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const roles = readListsEdit(shop.extras);
  async function set(role: string, on: boolean) {
    const ex = (shop.extras && typeof shop.extras === 'object' ? shop.extras : {}) as Record<string, unknown>;
    const next = on ? [...new Set([...roles, role])] : roles.filter((r) => r !== role);
    const { error } = await supabase.from('shops').update({ extras: { ...ex, lists_edit: next } }).eq('id', shop.id);
    if (error) return toast({ tone: 'danger', title: errorMessage(error) });
    await refresh();
    toast({ tone: 'ok', title: t('settings.saved') });
  }
  return (
    <Panel data-testid="lists-permission">
      <PanelHeader title={t('lists.permTitle')} />
      <div className="flex flex-col gap-2 p-4">
        <p className="text-xs text-fg-3">{t('lists.permHint')}</p>
        <div className="flex flex-wrap gap-4">
          {(['reception', 'technician'] as const).map((r) => (
            <Checkbox key={r} checked={roles.includes(r)} onChange={(v) => void set(r, v)} label={t(`roles.${r}`)} />
          ))}
        </div>
      </div>
    </Panel>
  );
}
