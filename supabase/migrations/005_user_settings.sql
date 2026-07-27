-- ============================================================
-- 005: 用户设置云端同步
-- ============================================================

create table if not exists public.user_settings (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    settings jsonb not null default '{}'::jsonb,
    updated_at timestamptz not null default now(),
    unique(user_id)
);

alter table public.user_settings enable row level security;

drop policy if exists "Users can read their own settings" on public.user_settings;
create policy "Users can read their own settings"
on public.user_settings for select
using (auth.uid() = user_id);

drop policy if exists "Users can upsert their own settings" on public.user_settings;
create policy "Users can upsert their own settings"
on public.user_settings for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own settings" on public.user_settings;
create policy "Users can update their own settings"
on public.user_settings for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
