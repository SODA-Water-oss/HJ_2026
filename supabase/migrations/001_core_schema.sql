create extension if not exists pgcrypto;

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    email text not null,
    is_premium boolean not null default false,
    stripe_customer_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.expenses (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    amount numeric(10, 2) not null check (amount > 0),
    category text not null,
    merchant text not null,
    date timestamptz not null default now(),
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists expenses_user_date_idx on public.expenses(user_id, date desc);
create index if not exists expenses_user_category_idx on public.expenses(user_id, category);
create index if not exists profiles_stripe_customer_idx on public.profiles(stripe_customer_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists expenses_set_updated_at on public.expenses;
create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, coalesce(new.email, ''))
    on conflict (id) do update
        set email = excluded.email;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.expenses enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles for select
using (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Users can read their own expenses" on public.expenses;
create policy "Users can read their own expenses"
on public.expenses for select
using (auth.uid() = user_id);

drop policy if exists "Users can insert their own expenses" on public.expenses;
create policy "Users can insert their own expenses"
on public.expenses for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update their own expenses" on public.expenses;
create policy "Users can update their own expenses"
on public.expenses for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own expenses" on public.expenses;
create policy "Users can delete their own expenses"
on public.expenses for delete
using (auth.uid() = user_id);
