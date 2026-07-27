-- 003: 用户操作日志
create table if not exists public.user_logs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    action text not null,
    detail text not null default '',
    created_at timestamptz not null default now()
);

create index if not exists user_logs_user_date_idx on public.user_logs(user_id, created_at desc);

alter table public.user_logs enable row level security;

create policy "Users can read their own logs"
on public.user_logs for select
using (auth.uid() = user_id);

create policy "Users can insert their own logs"
on public.user_logs for insert
with check (auth.uid() = user_id);
