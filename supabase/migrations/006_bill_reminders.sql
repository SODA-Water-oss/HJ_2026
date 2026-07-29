-- ============================================================
-- 006: 定期账单提醒
-- ============================================================

create table if not exists public.bill_reminders (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    amount numeric(10,2) not null check (amount > 0),
    due_day integer not null check (due_day between 1 and 31),
    due_month integer not null default 0,
    recurrence text not null default 'monthly' check (recurrence in ('monthly', 'quarterly', 'yearly')),
    is_enabled boolean not null default true,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists bill_reminders_user_idx on public.bill_reminders(user_id);

alter table public.bill_reminders enable row level security;

create policy "Users can read their own bill reminders"
on public.bill_reminders for select
using (auth.uid() = user_id);

create policy "Users can insert their own bill reminders"
on public.bill_reminders for insert
with check (auth.uid() = user_id);

create policy "Users can update their own bill reminders"
on public.bill_reminders for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their own bill reminders"
on public.bill_reminders for delete
using (auth.uid() = user_id);

drop trigger if exists bill_reminders_set_updated_at on public.bill_reminders;
create trigger bill_reminders_set_updated_at
before update on public.bill_reminders
for each row execute function public.set_updated_at();

-- 007: 增加货币字段
alter table if exists public.bill_reminders add column if not exists currency text not null default '¥';
