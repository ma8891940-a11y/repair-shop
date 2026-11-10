import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Eraser, Plus, Trash2 } from 'lucide-react';
import { rowCount } from '../lib/gridRows';
import { Button } from '../ui/Button';

/**
 * أدوات سطور الجدول: "عدد السطور" (1 افتراضيًا) و"إضافة سطور" بيزوّد العدد ده بالظبط،
 * و"حذف المحدد"، و"حذف السطور الفاضية".
 */
export function RowsBar({ onAdd, selected, onDeleteSelected, onDeleteBlank, blankCount, testid = 'rows' }: {
  onAdd: (n: number) => void;
  selected: number;
  onDeleteSelected: () => void;
  onDeleteBlank: () => void;
  blankCount: number;
  testid?: string;
}) {
  const { t } = useTranslation();
  const [n, setN] = useState('1');
  return (
    <div className="flex flex-wrap items-center gap-2" data-testid={`${testid}-bar`}>
      <label className="flex items-center gap-1.5 text-xs text-fg-2">
        {t('rows.count')}
        <input
          value={n}
          onChange={(e) => setN(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter') {
              e.preventDefault();
              onAdd(rowCount(n));
            }
          }}
          inputMode="numeric"
          dir="ltr"
          className="num h-8 w-16 rounded-md border border-line bg-sunken/60 px-2 text-center text-sm text-fg focus:border-accent focus:outline-none"
          data-testid={`${testid}-count`}
        />
      </label>
      <Button size="sm" variant="ghost" icon={<Plus className="size-4" />} onClick={() => onAdd(rowCount(n))} data-testid={`${testid}-add`}>
        {t('opening.addRows')}
      </Button>
      <Button size="sm" variant="ghost" icon={<Trash2 className="size-4" />} disabled={!selected} onClick={onDeleteSelected} className="hover:text-danger" data-testid={`${testid}-delete-selected`}>
        {t('rows.deleteSelected', { n: selected })}
      </Button>
      <Button size="sm" variant="ghost" icon={<Eraser className="size-4" />} disabled={!blankCount} onClick={onDeleteBlank} data-testid={`${testid}-delete-blank`}>
        {t('rows.deleteBlank')}
      </Button>
    </div>
  );
}
