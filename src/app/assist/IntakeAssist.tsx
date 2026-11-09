import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { History } from 'lucide-react';
import { supabase } from '../../lib/supabase';
import { intakeBody, intakeHints, parseJsonAnswer, readIntakeAnswer, type IssueHint, type PastDevice } from '../../lib/assistPayloads';
import { useFormat } from '../../i18n/format';
import { Button } from '../../ui/Button';
import { AssistBox } from '../assist';

/**
 * الاستلام: اقتراحات من تاريخ المحل (أكتر أعطال الموديل ده ومتوسط تكلفتها، شغالة من غير نت)،
 * و"اقترح بالذكاء" (من غير اسم العميل ولا رقمه). أي اقتراح بيتحط في الفورم بـ "تطبيق" بس.
 */
export function IntakeAssist({ brand, model, issue, names, onApply }: { brand: string; model: string; issue: string; names: string[]; onApply: (v: { issue: string; cost: number | null }) => void }) {
  const { t } = useTranslation();
  const f = useFormat();
  const [hints, setHints] = useState<IssueHint[]>([]);
  useEffect(() => {
    if (!brand || model.trim().length < 2) return setHints([]);
    let live = true;
    const tm = setTimeout(async () => {
      // العطل من جدول الأجهزة، والتكلفة النهائية من القايمة (نفس اللي الاستقبال بيشوفه)
      const { data: devs } = await supabase.from('devices').select('id, brand, model, issue').is('deleted_at', null).ilike('model', model.trim()).limit(300);
      const rows = (devs ?? []) as { id: string; brand: string; model: string; issue: string | null }[];
      const { data: costs } = rows.length ? await supabase.from('devices_list').select('id, final_cost').in('id', rows.map((r) => r.id)) : { data: [] };
      const cost = new Map(((costs ?? []) as { id: string; final_cost: number | null }[]).map((c) => [c.id, c.final_cost == null ? null : Number(c.final_cost)]));
      const past: PastDevice[] = rows.map((r) => ({ brand: r.brand, model: r.model, issue: r.issue, final_cost: cost.get(r.id) ?? null }));
      if (live) setHints(intakeHints(past, brand, model));
    }, 350);
    return () => {
      live = false;
      clearTimeout(tm);
    };
  }, [brand, model]);
  if (!brand || model.trim().length < 2) return null;

  const local = hints.length > 0 && (
    <div className="flex flex-col gap-1.5" data-testid="intake-hints">
      <div className="flex items-center gap-1.5 text-2xs text-fg-3">
        <History className="size-3.5" aria-hidden /> {t('assist.intake.hints')}
      </div>
      <div className="flex flex-wrap gap-1.5">
        {hints.map((h) => (
          <button
            key={h.issue}
            type="button"
            onClick={() => onApply({ issue: h.issue, cost: h.cost })}
            className="h-7 rounded-sm border border-line px-2.5 text-xs text-fg-2 transition-[border-color,color] hover:border-accent hover:text-fg"
            data-testid="intake-hint"
          >
            {h.issue}
            <span className="ms-1.5 text-fg-3">
              ×{f.number(h.count)}
              {h.cost != null && ` · ${f.money(h.cost)}`}
            </span>
          </button>
        ))}
      </div>
    </div>
  );

  return (
    <AssistBox
      compact
      area="intake"
      kind="intake"
      title={t('assist.intake.title')}
      askLabel={t('assist.intake.ask')}
      testid="assist-intake"
      privacy={t('assist.privacyNoCustomer')}
      build={() => intakeBody({ brand, model, issue, hints, names })}
      fallback={local}
      render={(answer) => {
        const a = readIntakeAnswer(parseJsonAnswer(answer));
        if (!a) return <p className="whitespace-pre-wrap">{answer}</p>;
        return (
          <div className="flex flex-col gap-2">
            <p>
              <span className="text-fg-3">{t('intake.issue')}: </span>
              {a.issue}
            </p>
            {a.cost != null && (
              <p>
                <span className="text-fg-3">{t('intake.estimate')}: </span>
                <span className="num">{f.money(a.cost)}</span>
              </p>
            )}
            {a.questions.length > 0 && (
              <ul className="list-disc ps-5 text-xs text-fg-2">
                {a.questions.map((q) => (
                  <li key={q}>{q}</li>
                ))}
              </ul>
            )}
            <Button size="sm" variant="primary" className="self-start" onClick={() => onApply({ issue: a.issue, cost: a.cost })} data-testid="assist-intake-apply">
              {t('assist.apply')}
            </Button>
          </div>
        );
      }}
    />
  );
}
