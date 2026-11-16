import { useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { useMe } from "../../app/auth";
import { supabase } from "../../lib/supabase";
import { errorMessage } from "../../lib/errors";
import { toLatinDigits } from "../../lib/digits";
import { Panel, PanelHeader } from "../../ui/Panel";
import { Field, Input } from "../../ui/Field";
import { Button } from "../../ui/Button";
import { Alert } from "../../ui/Feedback";
import { useToast } from "../../ui/Toast";
import { TelegramPanel } from "./TelegramPanel";

export function readReminderDays(extras: unknown): number {
  const r =
    extras && typeof extras === "object"
      ? (extras as Record<string, unknown>).reminders
      : null;
  const d =
    r && typeof r === "object"
      ? Number((r as Record<string, unknown>).days)
      : NaN;
  return Number.isInteger(d) && d >= 0 && d <= 30 ? d : 3;
}

/** الإعدادات ← التنبيهات: الأقساط بتبان "قرب" قبل ميعادها بكام يوم */
export function AlertsTab() {
  const { t } = useTranslation();
  const { shop, refresh } = useMe();
  const toast = useToast();
  const [days, setDays] = useState(String(readReminderDays(shop.extras)));
  const [err, setErr] = useState<string | null>(null);
  useEffect(
    () => setDays(String(readReminderDays(shop.extras))),
    [shop.extras],
  );
  async function save() {
    setErr(null);
    const d = Number(toLatinDigits(days.trim()));
    if (!Number.isInteger(d) || d < 0 || d > 30)
      return setErr(t("notify.daysHint"));
    const raw = (
      shop.extras && typeof shop.extras === "object" ? shop.extras : {}
    ) as Record<string, unknown>;
    const prev = (
      raw.reminders && typeof raw.reminders === "object" ? raw.reminders : {}
    ) as Record<string, unknown>;
    const { error } = await supabase
      .from("shops")
      .update({ extras: { ...raw, reminders: { ...prev, days: d } } })
      .eq("id", shop.id);
    if (error) return setErr(errorMessage(error));
    await refresh();
    toast({ tone: "ok", title: t("settings.saved") });
  }
  return (
    <div className="flex flex-col gap-4">
      <Panel data-testid="alerts-settings">
        <PanelHeader title={t("settings.tabs.alerts")} />
        <div className="flex flex-col gap-3 p-4">
          <div className="flex flex-wrap items-end gap-2">
            <Field label={t("notify.days")} hint={t("notify.daysHint")}>
              <Input
                mono
                inputMode="numeric"
                value={days}
                onChange={(e) => setDays(e.target.value)}
                className="w-24"
                data-testid="reminder-days"
              />
            </Field>
            <Button
              variant="primary"
              onClick={() => void save()}
              className="mb-5"
            >
              {t("common.save")}
            </Button>
          </div>
          {err && <Alert tone="danger">{err}</Alert>}
        </div>
      </Panel>
      <TelegramPanel />
    </div>
  );
}
