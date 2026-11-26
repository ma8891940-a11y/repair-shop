-- 0089: (50.3) صور خلفية القوالب: مكان خاص لكل محل، والرفع بصلاحية قوالب الطباعة (0083)، والقراية لأي حد في المحل بيطبع.
-- layout.bg بقى كائن: {file, stock, w, h}: اسم الملف، وطريقة الورق (preprinted: البيانات بس، blank: الصورة والبيانات)، ومقاس الصورة بالبكسل.
-- وإزاحة الطابعة يمين وشمال وفوق وتحت بالمللي (فاضي = صفر).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('print-backgrounds', 'print-backgrounds', false, 2097152, array['image/png', 'image/jpeg'])
on conflict (id) do nothing;
create policy print_backgrounds_read on storage.objects for select to authenticated
  using (bucket_id = 'print-backgrounds' and (storage.foldername(name))[1] = (select public.current_shop_id())::text);
-- من غير تعديل ولا حذف: كل صورة ملف جديد (القوالب القديمة بتفضل بصورتها)
create policy print_backgrounds_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'print-backgrounds'
    and name ~ ('^' || (select public.current_shop_id())::text || '/[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(png|jpg)$')
    and ((select public.current_app_role()) = 'owner' or ((select public.current_app_role()) = 'reception' and (select public.has_perm('print_templates', 'edit')))));

alter table public.printers add column offset_x numeric(4,1) check (offset_x between -10 and 10);
alter table public.printers add column offset_y numeric(4,1) check (offset_y between -10 and 10);

create or replace function public.print_bg_ok(p jsonb) returns boolean
language sql immutable as $$
  select case when jsonb_typeof(p) = 'object' then coalesce(public.print_only_keys(p, array['file', 'stock', 'w', 'h'])
    and jsonb_typeof(p -> 'file') = 'string' and p ->> 'file' ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}\.(png|jpg)$'
    and jsonb_typeof(p -> 'stock') = 'string' and p ->> 'stock' in ('preprinted', 'blank')
    and public.print_int(p -> 'w', 1, 10000) and public.print_int(p -> 'h', 1, 10000), false) else false end
$$;
revoke execute on function public.print_bg_ok(jsonb) from public, anon;
grant execute on function public.print_bg_ok(jsonb) to authenticated;

-- print_template_error: (src: 0088_print_layout.sql) + شكل الخلفية ونسبتها
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
  if p_layout ? 'bg' and jsonb_typeof(p_layout -> 'bg') <> 'null' and not public.print_bg_ok(p_layout -> 'bg') then return 'bg'; end if;
  if p_layout ? 'paper' then
    size := public.print_paper(p_layout -> 'paper');
    if size is null then return 'paper'; end if;
  end if;
  -- الصورة بعرض الورقة: طولها = طول الورقة بسماح نص مللي
  if jsonb_typeof(p_layout -> 'bg') = 'object' and not coalesce(size[2] is not null
     and 2 * abs(size[1] * (p_layout #>> '{bg,h}')::numeric - size[2] * (p_layout #>> '{bg,w}')::numeric) <= (p_layout #>> '{bg,w}')::numeric, false) then return 'bgsize'; end if;

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
