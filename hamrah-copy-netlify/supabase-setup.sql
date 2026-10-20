-- Run this in Supabase Dashboard -> SQL Editor.
-- Private per-user clipboard records. Never use a service_role key in the browser.
create table if not exists public.clipboard_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('text','image')),
  text_content text,
  file_path text,
  file_name text,
  file_size bigint,
  created_at timestamptz not null default now(),
  constraint clipboard_items_payload_check check (
    (type = 'text' and text_content is not null and file_path is null)
    or (type = 'image' and text_content is null and file_path is not null)
  )
);
create index if not exists clipboard_items_user_created_idx
  on public.clipboard_items(user_id, created_at desc);
alter table public.clipboard_items enable row level security;
revoke all on public.clipboard_items from anon;
grant select, insert, delete on public.clipboard_items to authenticated;
drop policy if exists "read own clipboard items" on public.clipboard_items;
create policy "read own clipboard items" on public.clipboard_items
  for select to authenticated using ((select auth.uid()) = user_id);
drop policy if exists "insert own clipboard items" on public.clipboard_items;
create policy "insert own clipboard items" on public.clipboard_items
  for insert to authenticated with check ((select auth.uid()) = user_id);
drop policy if exists "delete own clipboard items" on public.clipboard_items;
create policy "delete own clipboard items" on public.clipboard_items
  for delete to authenticated using ((select auth.uid()) = user_id);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('clipboard-images', 'clipboard-images', false, 2097152, array['image/png','image/jpeg','image/gif','image/webp'])
on conflict (id) do update set public = false, file_size_limit = 2097152,
  allowed_mime_types = array['image/png','image/jpeg','image/gif','image/webp'];

drop policy if exists "users read own clipboard images" on storage.objects;
create policy "users read own clipboard images" on storage.objects
  for select to authenticated using (
    bucket_id = 'clipboard-images' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "users upload own clipboard images" on storage.objects;
create policy "users upload own clipboard images" on storage.objects
  for insert to authenticated with check (
    bucket_id = 'clipboard-images' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
drop policy if exists "users delete own clipboard images" on storage.objects;
create policy "users delete own clipboard images" on storage.objects
  for delete to authenticated using (
    bucket_id = 'clipboard-images' and (storage.foldername(name))[1] = (select auth.uid())::text
  );
