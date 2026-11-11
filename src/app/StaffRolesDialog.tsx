import { useLayoutEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { rpc } from "./ledgerApi";
import { useLoad, must } from "./useLoad";
import { PERMS_CHANGED } from "./perms";
import { supabase } from "../lib/supabase";
import { errorMessage } from "../lib/errors";
import type { Profile } from "../lib/types";
import {
  PermGrid,
  type PermMap,
  type Role,
} from "../screens/settings/RolesTab";
import { Dialog } from "../ui/Dialog";
import { Button } from "../ui/Button";
import { Checkbox } from "../ui/Checkbox";
import { Alert, Skeleton } from "../ui/Feedback";
import { useToast } from "../ui/Toast";

type Ov = Record<string, boolean>; // "section:op" → allow

/**
 * P: أدوار موظف (دور أو أكتر)، واستثناءات ليه هو بس (مسموح أو ممنوع بعيد عن دوره، وبتبان بلون مختلف).
 * بيتطبق على طول من غير خروج ودخول، ومتسجل في سجل النشاط.
 */
export function StaffRolesDialog({
  user,
  onOpenChange,
  onDone,
}: {
  user: Profile | null;
  onOpenChange: (v: boolean) => void;
  onDone: () => void;
}) {
  const { t } = useTranslation();
  const toast = useToast();
  const data = useLoad(async () => {
    if (!user) return null;
    const [r, sr, ov] = await Promise.all([
      supabase
        .from("roles")
        .select("id, name, preset, base, perms")
        .is("deleted_at", null)
        .order("created_at"),
      supabase
        .from("staff_roles")
        .select("role_id")
        .eq("profile_id", user.id)
        .is("deleted_at", null),
      supabase
        .from("staff_overrides")
        .select("section, op, allow")
        .eq("profile_id", user.id)
        .is("deleted_at", null),
    ]);
    return {
      roles: must(r) as Role[],
      mine: (must(sr) as { role_id: string }[]).map((x) => x.role_id),
      ov: Object.fromEntries(
        (must(ov) as { section: string; op: string; allow: boolean }[]).map(
          (x) => [`${x.section}:${x.op}`, x.allow],
        ),
      ) as Ov,
    };
  }, [user?.id]);
  const [picked, setPicked] = useState<string[]>([]);
  const [ov, setOv] = useState<Ov>({});
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  useLayoutEffect(() => {
    setPicked(data.data?.mine ?? []);
    setOv(data.data?.ov ?? {});
    setErr(null);
  }, [data.data]);
  // صلاحيات الأدوار المختارة (من غير الاستثناءات)
  const fromRoles = useMemo(() => {
    const m: PermMap = {};
    for (const r of data.data?.roles ?? [])
      if (picked.includes(r.id))
        for (const [s, ops] of Object.entries(r.perms ?? {}))
          m[s] = [...new Set([...(m[s] ?? []), ...ops])];
    return m;
  }, [data.data, picked]);
  const cycle = (s: string, o: string) =>
    setOv((cur) => {
      const k = `${s}:${o}`;
      const next = { ...cur };
      // زي الدور ← عكسه (استثناء) ← زي الدور
      const inRole = (fromRoles[s] ?? []).includes(o);
      if (k in next) delete next[k];
      else next[k] = !inRole;
      return next;
    });
  async function save() {
    if (!user) return;
    if (!picked.length) return setErr(t("perm.pickRole"));
    setBusy(true);
    setErr(null);
    try {
      await rpc("set_staff_roles", { p_profile: user.id, p_roles: picked });
      const old = data.data?.ov ?? {};
      for (const k of new Set([...Object.keys(old), ...Object.keys(ov)])) {
        if (old[k] === ov[k]) continue;
        const [s, o] = k.split(":");
        await rpc("set_staff_override", {
          p_profile: user.id,
          p_section: s,
          p_op: o,
          p_allow: k in ov ? ov[k] : null,
        });
      }
      toast({
        tone: "ok",
        title: t("perm.staffRolesSaved", { name: user.full_name }),
      });
      window.dispatchEvent(new Event(PERMS_CHANGED));
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
      open={!!user}
      onOpenChange={onOpenChange}
      title={user ? t("perm.staffRolesTitle", { name: user.full_name }) : ""}
      className="w-[min(96vw,760px)]"
      footer={
        <>
          <Button variant="ghost" onClick={() => onOpenChange(false)}>
            {t("common.cancel")}
          </Button>
          <Button
            variant="primary"
            loading={busy || data.loading}
            needsNet
            onClick={() => void save()}
            data-testid="staff-roles-save"
          >
            {t("common.save")}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-3">
        <div
          className="flex flex-wrap gap-x-4 gap-y-1.5"
          data-testid="staff-roles"
        >
          {(data.data?.roles ?? []).map((r) => (
            <Checkbox
              key={r.id}
              checked={picked.includes(r.id)}
              onChange={(on) =>
                setPicked((p) =>
                  on ? [...p, r.id] : p.filter((x) => x !== r.id),
                )
              }
              label={<span className="text-sm text-fg-2">{r.name}</span>}
            />
          ))}
        </div>
        <div>
          <div className="text-sm font-medium text-fg">
            {t("perm.exceptions")}
          </div>
          <p className="mb-1 text-2xs text-fg-3">{t("perm.exceptionsHint")}</p>
          {/* الجدول بيظهر بعد ما الأدوار والاستثناءات المحفوظة توصل (عشان أي دوسة تبقى على البيانات الحقيقية) */}
          {!data.data ? (
            <Skeleton className="h-40" />
          ) : (
            <PermGrid
              value={fromRoles}
              onToggle={cycle}
              testid="staff-grid"
              base={user?.role === "technician" ? "technician" : "reception"}
              cell={(s, o) => {
                const k = `${s}:${o}`;
                if (k in ov)
                  return {
                    label: `${t("perm.exception")}: ${t(ov[k] ? "perm.allow" : "perm.deny")}`,
                    tone: ov[k] ? "allow" : "deny",
                  };
                return {
                  label: t("perm.inherit"),
                  tone: (fromRoles[s] ?? []).includes(o) ? "on" : "off",
                };
              }}
            />
          )}
        </div>
        {err && <Alert tone="danger">{err}</Alert>}
      </div>
    </Dialog>
  );
}
