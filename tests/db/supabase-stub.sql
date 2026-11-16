-- نسخة مصغّرة من الحاجات اللي Supabase بيوفرها، عشان نختبر الـ SQL على Postgres عادي.
-- (للاختبار بس، مش بتتشغل على Supabase الحقيقي)
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create table auth.users (id uuid primary key, email text, email_confirmed_at timestamptz, created_at timestamptz default now());
-- زي Supabase الحقيقي: الإعداد ممكن يكون فاضي (زائر من غير تسجيل دخول)
create function auth.uid() returns uuid language sql stable as $$
  select nullif(nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub', '')::uuid
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
grant usage on schema auth to anon, authenticated;
grant execute on all functions in schema auth to anon, authenticated;

create schema storage;
create table storage.buckets (id text primary key, name text, public boolean,
  file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects (id uuid primary key default gen_random_uuid(), bucket_id text, name text);
create function storage.foldername(name text) returns text[] language sql immutable as $$
  select (string_to_array(name, '/'))[1:array_length(string_to_array(name, '/'), 1) - 1]
$$;
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated, anon;
grant select, insert on storage.objects to authenticated, anon;

-- نسخة مصغّرة من Supabase Vault (في الاختبار بس؛ الحقيقي بيشفّر القيمة)
create schema vault;
create table vault.secrets (id uuid primary key default gen_random_uuid(), name text, description text, secret text not null);
create function vault.create_secret(new_secret text, new_name text default null, new_description text default '') returns uuid language sql as $$
  insert into vault.secrets(secret, name, description) values ('enc:' || new_secret, new_name, new_description) returning id
$$;
create function vault.update_secret(secret_id uuid, new_secret text default null, new_name text default null, new_description text default null) returns void language sql as $$
  update vault.secrets set secret = coalesce('enc:' || new_secret, secret) where id = secret_id
$$;
create view vault.decrypted_secrets as select id, name, description, secret, substr(secret, 5) as decrypted_secret from vault.secrets;
revoke all on schema vault from public;
