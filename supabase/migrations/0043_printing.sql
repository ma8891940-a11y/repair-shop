-- 0043: U5: الطابعات ومصمم الطباعة.
-- المتصفح ما بيقدرش يعرض الطابعات المتوصلة، فكل طابعة "ملف" بمقاسها وهوامشها، والطباعة بتفتح نافذة الطباعة على المقاس الصح.
-- القالب بيتحكم في الشكل بس (الخانات وترتيبها وحجم الخط والمحاذاة). الأرقام والبيانات دايمًا من البرنامج.

create table public.printers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  name text not null check (length(trim(name)) between 1 and 60),
  kind text not null check (kind in ('thermal58', 'thermal80', 'label', 'a4', 'a5', 'dot')),
  model text check (model is null or length(model) <= 60),
  width_mm integer not null check (width_mm between 20 and 300),
  height_mm integer check (height_mm is null or height_mm between 10 and 450),
  margin_mm integer not null default 3 check (margin_mm between 0 and 30),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.print_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  branch_id uuid references public.branches(id),
  doc text not null check (doc in ('sticker', 'receipt', 'receipt-a4', 'invoice', 'label', 'sale', 'statement', 'barcode', 'voucher')),
  printer_id uuid references public.printers(id),
  name text not null check (length(trim(name)) between 1 and 60),
  blocks jsonb not null check (jsonb_typeof(blocks) = 'array' and jsonb_array_length(blocks) <= 60),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
-- افتراضي واحد لكل نوع ورقة في كل فرع (أو للمحل كله لو مفيش فرع)
create unique index print_templates_default on public.print_templates(shop_id, doc, coalesce(branch_id, '00000000-0000-0000-0000-000000000000'::uuid)) where is_default and deleted_at is null;

alter table public.printers enable row level security;
alter table public.print_templates enable row level security;
create trigger set_updated_at before update on public.printers for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.print_templates for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.printers for each row execute function public.tg_block_delete();
create trigger block_delete before delete on public.print_templates for each row execute function public.tg_block_delete();
create trigger a_force_shop_id before insert or update on public.printers for each row execute function public.tg_force_shop_id();
create trigger a_force_shop_id before insert or update on public.print_templates for each row execute function public.tg_force_shop_id();
create trigger zz_audit after insert or update on public.printers for each row execute function public.tg_audit();
create trigger zz_audit after insert or update on public.print_templates for each row execute function public.tg_audit();

-- القراية للمحل كله (كل اللي بيطبع محتاج القالب)، والتعديل لصاحب المحل بس
create policy printers_select on public.printers for select to authenticated using (shop_id = public.current_shop_id());
create policy printers_insert on public.printers for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy printers_update on public.printers for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_select on public.print_templates for select to authenticated using (shop_id = public.current_shop_id());
create policy templates_insert on public.print_templates for insert to authenticated with check (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
create policy templates_update on public.print_templates for update to authenticated using (shop_id = public.current_shop_id() and public.current_app_role() = 'owner');
grant select, insert, update on public.printers, public.print_templates to authenticated;
