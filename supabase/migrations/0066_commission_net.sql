-- ============================================================
-- 0066: قرار صاحب المشروع (2026-11-23): عمولة الفني على السعر قبل الضريبة.
-- - المصنعية = (التكلفة النهائية − الضريبة اللي جواها) − تكلفة القطع.
-- - الضريبة بنفس طريقة قيد التسليم بالظبط (vat_of بنسبة المحل وقت التسليم)، فالعمولة والقيد دايمًا متطابقين.
-- - المحل اللي الضريبة عنده مقفولة: مفيش أي فرق (vat_of = 0).
-- - العمولات القديمة اللي اتسجلت قبل الملف ده ما بتتغيرش (القيود ما بتتعدلش).
-- ============================================================

-- commission_preview: (src: 0056_branch_features.sql) + المصنعية من غير الضريبة
create or replace function public.commission_preview(p_device uuid) returns table(technician_id uuid, amount bigint)
language plpgsql stable security definer set search_path = public as $$
declare d public.devices; techs uuid[]; n int; base bigint; fc bigint; r public.commission_rules; t uuid; share bigint;
begin
  select * into d from public.devices where id = p_device;
  if d.id is null then return; end if;
  techs := public.device_technicians(p_device);
  n := coalesce(array_length(techs, 1), 0);
  if n = 0 then return; end if;
  fc := coalesce((select c.final_cost from public.device_costs c where c.device_id = p_device and c.deleted_at is null), 0);
  base := greatest(fc - public.vat_of(fc, public.vat_bp(d.shop_id)) - public.device_parts_cost(p_device), 0);
  foreach t in array techs loop
    r := public.commission_rule_for(d.shop_id, t, d.route_id, d.branch_id);
    continue when r.id is null;
    share := case when r.mode = 'fixed' then r.value else (base / n) * r.value / 10000 end;
    if share > 0 then technician_id := t; amount := share; return next; end if;
  end loop;
end $$;
revoke execute on function public.commission_preview(uuid) from public, anon, authenticated;
