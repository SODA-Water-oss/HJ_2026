-- ============================================================
-- 010: 意见反馈表（App 内提交反馈，云端存档）
-- ============================================================

create table if not exists public.feedbacks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    content text not null,
    contact text,
    created_at timestamptz not null default now()
);

create index if not exists feedbacks_user_idx on public.feedbacks(user_id);

alter table public.feedbacks enable row level security;

create policy "Users can insert their own feedback"
on public.feedbacks for insert
with check (auth.uid() = user_id);

create policy "Users can read their own feedback"
on public.feedbacks for select
using (auth.uid() = user_id);
