-- ============================================================
-- 012: 收支目标（云端长期存储，关联用户，跨设备同步）
-- ============================================================

create table if not exists public.goal_targets (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null default '',
    category text not null,
    time_dimension text not null,
    amount numeric(12,2) not null check (amount > 0),
    start_date timestamptz,
    end_date timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists goal_targets_user_idx on public.goal_targets(user_id);

alter table public.goal_targets enable row level security;

create policy "Users can read their own goals"
on public.goal_targets for select
using (auth.uid() = user_id);

create policy "Users can insert their own goals"
on public.goal_targets for insert
with check (auth.uid() = user_id);

create policy "Users can update their own goals"
on public.goal_targets for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own goals"
on public.goal_targets for delete
using (auth.uid() = user_id);

drop trigger if exists goal_targets_set_updated_at on public.goal_targets;
create trigger goal_targets_set_updated_at
before update on public.goal_targets
for each row execute function public.set_updated_at();
