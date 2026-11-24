-- 0088: (50.2) نموذج القالب: flow (الخانات بالترتيب زي الأول) وfree (حقول بأماكنها بالمللي للمقاسات الثابتة).
-- الفحص في دالة واحدة (print_template_error) بتتنده من trigger، فأي طريق للحفظ بيعدّي عليها. نفسها في src/lib/printLayout.ts واختبار بيطابقهم.
-- القوالب القديمة: mode = flow وlayout فاضي، من غير أي تغيير. والاسترجاع: الخانات القديمة بترجع زي ما هي (الشاشة بتنضّفها)، والـ layout لازم يعدّي.
alter table public.print_templates add column mode text not null default 'flow' check (mode in ('flow', 'free'));
alter table public.print_templates add column layout jsonb not null default '{}'::jsonb check (jsonb_typeof(layout) = 'object');

-- حقول القالب الحر لكل نوع. كشف الحساب والإيصال الحراري بالترتيب بس
create or replace function public.print_free_fields(p_doc text) returns text[]
language sql immutable as $$
  select case
    when p_doc in ('sticker', 'label') then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'warranty', 'terms', 'qr', 'barcode']
    when p_doc = 'receipt-a4' then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'warranty', 'terms', 'qr', 'barcode', 'price', 'paid', 'remaining']
    when p_doc = 'invoice' then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'warranty', 'terms', 'qr', 'barcode', 'price', 'paid', 'remaining', 'parts']
    when p_doc = 'sale' then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'entryNo', 'date', 'customer', 'phone', 'lines', 'price', 'paid', 'remaining', 'terms', 'barcode']
    when p_doc = 'voucher' then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'entryNo', 'date', 'party', 'amount', 'method', 'memo']
    when p_doc = 'barcode' then array['shopName', 'logo', 'shopPhone', 'shopAddress', 'text', 'itemName', 'code', 'price', 'barcode']
    else '{}'::text[] end
$$;
create or replace function public.print_flow_blocks(p_doc text) returns text[]
language sql immutable as $$
  select case
    when p_doc in ('receipt', 'receipt-a4') then array['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'accessories', 'condition', 'estimate', 'terms', 'signature', 'qr', 'sign', 'thanks', 'text']
    when p_doc = 'invoice' then array['header', 'title', 'orderNo', 'date', 'customer', 'phone', 'device', 'imei', 'issue', 'parts', 'total', 'paid', 'remaining', 'warranty', 'signature', 'sign', 'thanks', 'text']
    when p_doc = 'statement' then array['header', 'title', 'party', 'period', 'opening', 'moves', 'closing', 'signature', 'thanks', 'text']
    when p_doc = 'voucher' then array['header', 'title', 'entryNo', 'date', 'party', 'amount', 'method', 'cashbox', 'memo', 'sign', 'thanks', 'text']
    when p_doc = 'sale' then array['header', 'title', 'entryNo', 'date', 'customer', 'phone', 'lines', 'total', 'paid', 'remaining', 'memo', 'sign', 'thanks', 'text']
    when p_doc = 'barcode' then array['header', 'itemName', 'code', 'price', 'text']
    else '{}'::text[] end
$$;

create or replace function public.print_only_keys(p jsonb, p_keys text[]) returns boolean
language sql immutable as $$
  select not exists (select 1 from jsonb_object_keys(p) k where not (k = any (p_keys)))
$$;
create or replace function public.print_int(p jsonb, p_min numeric, p_max numeric) returns boolean
language sql immutable as $$
  select case when p is not null and jsonb_typeof(p) = 'number' then (p #>> '{}')::numeric = trunc((p #>> '{}')::numeric) and (p #>> '{}')::numeric between p_min and p_max else false end
$$;
-- أعشار المللي، أو null لو مش رقم بخانة عشرية واحدة بالكتير
create or replace function public.print_tenths(p jsonb) returns numeric
language sql immutable as $$
  select case when p is not null and jsonb_typeof(p) = 'number' and (p #>> '{}')::numeric * 10 = trunc((p #>> '{}')::numeric * 10) then (p #>> '{}')::numeric * 10 end
$$;
-- [العرض، الطول] بالمللي، أو null لو المقاس غلط
create or replace function public.print_paper(p jsonb) returns integer[]
language plpgsql immutable as $$
declare k text;
begin
  if p is null or jsonb_typeof(p) <> 'object' or jsonb_typeof(p -> 'kind') is distinct from 'string' then return null; end if;
  k := p ->> 'kind';
  if k = 'custom' then
    if not public.print_only_keys(p, array['kind', 'w', 'h']) or not public.print_int(p -> 'w', 20, 300) then return null; end if;
    if jsonb_typeof(p -> 'h') is distinct from 'null' and not public.print_int(p -> 'h', 10, 450) then return null; end if;
    return array[(p ->> 'w')::numeric::int, (p ->> 'h')::numeric::int];
  end if;
  if not public.print_only_keys(p, array['kind']) then return null; end if;
  return case k when '40x30' then array[40, 30] when '58' then array[58, null] when '80' then array[80, null] when 'a4' then array[210, 297] end;
end $$;

-- null = القالب سليم، وإلا كود الغلط (نفس ترتيب templateError في الواجهة)
create or replace function public.print_template_error(p_doc text, p_mode text, p_blocks jsonb, p_layout jsonb) returns text
language plpgsql immutable as $$
declare
  b jsonb; k text; seen text[] := '{}'; size integer[]; free text[]; flow text[]; l numeric; t numeric; w numeric; h numeric;
begin
  if p_doc is null or not (p_doc = any (array['receipt', 'receipt-a4', 'invoice', 'statement', 'voucher', 'sale', 'barcode', 'sticker', 'label'])) then return 'doc'; end if;
  if p_mode is null or p_mode not in ('flow', 'free') then return 'mode'; end if;
  if p_blocks is null or jsonb_typeof(p_blocks) <> 'array' or p_layout is null or jsonb_typeof(p_layout) <> 'object' then return 'type'; end if;
  if octet_length(p_blocks::text) > 68000 or octet_length(p_layout::text) > 68000 then return 'size'; end if;
  if not public.print_only_keys(p_layout, array['lang', 'paper', 'bg', 'fields']) then return 'key'; end if;
  if p_layout ? 'lang' and not coalesce(jsonb_typeof(p_layout -> 'lang') = 'string' and p_layout ->> 'lang' in ('app', 'ar', 'en'), false) then return 'lang'; end if;
  if p_layout ? 'bg' and jsonb_typeof(p_layout -> 'bg') <> 'null'
     and not (jsonb_typeof(p_layout -> 'bg') = 'string' and p_layout ->> 'bg' ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(png|jpg)$') then return 'bg'; end if;
  if p_layout ? 'paper' then
    size := public.print_paper(p_layout -> 'paper');
    if size is null then return 'paper'; end if;
  end if;

  if p_mode = 'flow' then
    if p_layout ? 'fields' then return 'key'; end if;
    if jsonb_array_length(p_blocks) > 60 then return 'count'; end if;
    flow := public.print_flow_blocks(p_doc);
    for b in select x from jsonb_array_elements(p_blocks) x loop
      if jsonb_typeof(b) <> 'object' then return 'type'; end if;
      if not public.print_only_keys(b, array['key', 'show', 'size', 'align', 'bold', 'text', 'font', 'pt']) then return 'key'; end if;
      k := b ->> 'key';
      if jsonb_typeof(b -> 'key') is distinct from 'string' or not (k = any (flow)) then return 'field'; end if;
      if k <> 'text' and k = any (seen) then return 'duplicate'; end if;
      seen := seen || k;
      if jsonb_typeof(b -> 'show') is distinct from 'boolean' or jsonb_typeof(b -> 'bold') is distinct from 'boolean'
         or not coalesce(b ->> 'size' in ('sm', 'md', 'lg') and b ->> 'align' in ('start', 'center', 'end'), false) then return 'value'; end if;
      if b ? 'font' and not coalesce(b ->> 'font' in ('sans', 'mono', 'system'), false) then return 'font'; end if;
      if b ? 'pt' and not public.print_int(b -> 'pt', 5, 72) then return 'pt'; end if;
      if not public.print_text_ok(b) then return 'text'; end if;
    end loop;
    return null;
  end if;

  free := public.print_free_fields(p_doc);
  if cardinality(free) = 0 then return 'mode'; end if;
  if jsonb_array_length(p_blocks) > 0 then return 'key'; end if;
  if size is null or size[2] is null then return 'paper'; end if;
  if jsonb_typeof(p_layout -> 'fields') is distinct from 'array' then return 'type'; end if;
  if jsonb_array_length(p_layout -> 'fields') not between 1 and 60 then return 'count'; end if;
  for b in select x from jsonb_array_elements(p_layout -> 'fields') x loop
    if jsonb_typeof(b) <> 'object' then return 'type'; end if;
    if not public.print_only_keys(b, array['key', 'x', 'y', 'w', 'h', 'font', 'pt', 'align', 'bold', 'text']) then return 'key'; end if;
    k := b ->> 'key';
    if jsonb_typeof(b -> 'key') is distinct from 'string' or not (k = any (free)) then return 'field'; end if;
    if k <> 'text' and k = any (seen) then return 'duplicate'; end if;
    seen := seen || k;
    if jsonb_typeof(b -> 'bold') is distinct from 'boolean' or not coalesce(b ->> 'align' in ('start', 'center', 'end'), false) then return 'value'; end if;
    if not coalesce(b ->> 'font' in ('sans', 'mono', 'system'), false) then return 'font'; end if;
    if not public.print_int(b -> 'pt', 5, 72) then return 'pt'; end if;
    l := public.print_tenths(b -> 'x'); t := public.print_tenths(b -> 'y'); w := public.print_tenths(b -> 'w'); h := public.print_tenths(b -> 'h');
    if l is null or t is null or w is null or h is null then return 'number'; end if;
    if l < 0 or t < 0 or w < 10 or h < 10 or l + w > size[1] * 10 or t + h > size[2] * 10 then return 'bounds'; end if;
    if not public.print_text_ok(b) then return 'text'; end if;
  end loop;
  return null;
end $$;
-- النص للخانة "text" بس، ولحد 300 حرف
create or replace function public.print_text_ok(p jsonb) returns boolean
language sql immutable as $$
  select case when p ->> 'key' = 'text' then coalesce(jsonb_typeof(p -> 'text') = 'string' and length(p ->> 'text') <= 300, false) else not (p ? 'text') end
$$;

create or replace function public.tg_print_template_valid() returns trigger
language plpgsql set search_path = public as $$
declare e text;
begin
  -- نسخة احتياطية من قبل 0088: من غير العمودين
  new.mode := coalesce(new.mode, 'flow');
  new.layout := coalesce(new.layout, '{}'::jsonb);
  if tg_op = 'UPDATE' and (new.doc, new.mode, new.blocks, new.layout) is not distinct from (old.doc, old.mode, old.blocks, old.layout) then return new; end if;
  if octet_length(new.blocks::text) > 68000 then raise exception 'E_TEMPLATE' using detail = 'size'; end if;
  -- الاسترجاع: الخانات القديمة زي ما هي، والـ layout بيتفحص
  e := public.print_template_error(new.doc, new.mode, case when public.restoring() and new.mode = 'flow' then '[]'::jsonb else new.blocks end, new.layout);
  if e is not null then raise exception 'E_TEMPLATE' using detail = e; end if;
  return new;
end $$;
create trigger valid_template before insert or update on public.print_templates for each row execute function public.tg_print_template_valid();

do $$
declare f text;
begin
  foreach f in array array['print_free_fields(text)', 'print_flow_blocks(text)', 'print_only_keys(jsonb, text[])', 'print_int(jsonb, numeric, numeric)', 'print_tenths(jsonb)', 'print_paper(jsonb)',
                           'print_text_ok(jsonb)', 'print_template_error(text, text, jsonb, jsonb)'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
revoke execute on function public.tg_print_template_valid() from public, anon, authenticated;
