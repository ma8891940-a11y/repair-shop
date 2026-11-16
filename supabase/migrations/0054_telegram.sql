-- 0054: C8: إشعارات تيليجرام لصاحب المحل (مجانية واختيارية)، جنب إشعارات البرنامج.
-- صاحب المحل بيعمل بوت من @BotFather (مجاني) ويكتب الـ token ورقم المحادثة. الـ token متخزّن مشفّر في Vault وما بيرجعش للشاشة أبدًا.
-- الرسايل فيها رقم الطلب والموديل والحالة والمبلغ بس، من غير اسم العميل ولا تليفونه (تيليجرام خدمة برا المحل).
-- الإرسال من قاعدة البيانات بـ pg_net (مجاني في Supabase): بيتبعت بعد ما العملية تتحفظ، ولو العملية اتلغت ما بيتبعتش.

-- (في Supabase: Database ← Extensions ← pg_net. لو مش متاحة، الإشعارات بس اللي مش هتشتغل)
do $$ begin
  if exists (select 1 from pg_available_extensions where name = 'pg_net') then
    create extension if not exists pg_net with schema extensions;
  end if;
end $$;

create table public.shop_telegram (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null unique references public.shops(id),
  chat_id text not null check (chat_id ~ '^(-?[0-9]{5,16}|@[A-Za-z0-9_]{5,32})$'),
  token_secret uuid not null,
  events text[] not null default array['intake', 'ready', 'delivered']::text[]
    check (events <@ array['intake', 'ready', 'delivered', 'payment']::text[]),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table public.shop_telegram enable row level security;
create trigger set_updated_at before update on public.shop_telegram for each row execute function public.tg_set_updated_at();
create trigger block_delete before delete on public.shop_telegram for each row execute function public.tg_block_delete();
-- مفيش سياسات: من الدوال بس (فيه مرجع للـ token)

create or replace function public.set_telegram(p_token text, p_chat text, p_events text[]) returns void
language plpgsql security definer set search_path = public as $$
declare s uuid := public.current_shop_id(); cur public.shop_telegram; tok text := nullif(trim(p_token), ''); sec uuid;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into cur from public.shop_telegram where shop_id = s;
  if tok is not null and tok !~ '^[0-9]{5,12}:[A-Za-z0-9_-]{30,64}$' then raise exception 'E_BAD_TOKEN'; end if;
  if tok is null and cur.id is null then raise exception 'E_BAD_TOKEN'; end if;
  if tok is not null then
    if cur.id is null then sec := vault.create_secret(tok, 'telegram-' || s::text, 'Telegram bot token');
    else perform vault.update_secret(cur.token_secret, tok); sec := cur.token_secret; end if;
  else sec := cur.token_secret; end if;
  insert into public.shop_telegram(shop_id, chat_id, token_secret, events, enabled)
  values (s, trim(p_chat), sec, coalesce(p_events, array['intake', 'ready', 'delivered']), true)
  on conflict (shop_id) do update set chat_id = excluded.chat_id, token_secret = excluded.token_secret, events = excluded.events, enabled = true, deleted_at = null;
  insert into public.audit_log(shop_id, actor_id, action, entity, entity_id, after)
  values (s, auth.uid(), 'telegram_set', 'shop_telegram', s, jsonb_build_object('events', p_events));
end $$;
create or replace function public.disable_telegram() returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  update public.shop_telegram set enabled = false where shop_id = public.current_shop_id();
end $$;
-- الحالة من غير الـ token
create or replace function public.telegram_status() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare t public.shop_telegram;
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  select * into t from public.shop_telegram where shop_id = public.current_shop_id() and deleted_at is null;
  if t.id is null then return jsonb_build_object('configured', false); end if;
  return jsonb_build_object('configured', true, 'enabled', t.enabled, 'chat', t.chat_id, 'events', to_jsonb(t.events));
end $$;
revoke execute on function public.set_telegram(text, text, text[]), public.disable_telegram(), public.telegram_status() from public, anon;
grant execute on function public.set_telegram(text, text, text[]), public.disable_telegram(), public.telegram_status() to authenticated;

-- الإرسال (داخلي)
create or replace function public.telegram_send(p_shop uuid, p_event text, p_text text) returns bigint
language plpgsql security definer set search_path = public, extensions, pg_temp as $$
declare t public.shop_telegram; tok text;
begin
  select * into t from public.shop_telegram where shop_id = p_shop and enabled and deleted_at is null;
  if t.id is null or not (p_event = 'test' or p_event = any (t.events)) then return null; end if;
  select d.decrypted_secret into tok from vault.decrypted_secrets d where d.id = t.token_secret;
  if tok is null then return null; end if;
  return net.http_post(
    url := 'https://api.telegram.org/bot' || tok || '/sendMessage',
    body := jsonb_build_object('chat_id', t.chat_id, 'text', left(p_text, 3500), 'disable_web_page_preview', true),
    headers := '{"Content-Type": "application/json"}'::jsonb);
exception when others then
  -- الإشعار ما يوقفش الشغل أبدًا
  return null;
end $$;
revoke execute on function public.telegram_send(uuid, text, text) from public, anon, authenticated;

create or replace function public.telegram_test() returns boolean
language plpgsql security definer set search_path = public as $$
begin
  perform public.ledger_require(array['owner']::public.app_role[]);
  return public.telegram_send(public.current_shop_id(), 'test', 'جوالك: رسالة تجربة. الإشعارات شغالة.') is not null;
end $$;
revoke execute on function public.telegram_test() from public, anon;
grant execute on function public.telegram_test() to authenticated;

-- الأحداث: استلام جهاز، وجاهز، واتسلّم (من غير بيانات العميل)
create or replace function public.tg_telegram_device() returns trigger
language plpgsql security definer set search_path = public as $$
declare ev text; txt text; amt bigint;
begin
  if public.restoring() then return new; end if;
  if not exists (select 1 from public.shop_telegram t where t.shop_id = new.shop_id and t.enabled) then return new; end if;
  if tg_op = 'INSERT' then
    ev := 'intake'; txt := 'جهاز جديد ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || ' (' || left(coalesce(new.issue, ''), 80) || ')';
  elsif new.status is distinct from old.status and new.status = 'ready' then
    ev := 'ready'; txt := 'جاهز للتسليم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model;
  elsif new.status is distinct from old.status and new.status = 'delivered' then
    select c.final_cost into amt from public.device_costs c where c.device_id = new.id and c.deleted_at is null;
    ev := 'delivered'; txt := 'اتسلّم ' || coalesce(new.order_no, '') || ': ' || new.brand || ' ' || new.model || coalesce(' · ' || to_char(amt / 100.0, 'FM999,999,990.00'), '');
  else
    return new;
  end if;
  perform public.telegram_send(new.shop_id, ev, txt);
  return new;
end $$;
create trigger zz_telegram after insert or update of status on public.devices for each row execute function public.tg_telegram_device();
