-- ============================================================
-- 016: AA 分账共享账单
-- 多人共享同一账单，可添加条目；只能编辑/删除自己添加的条目
-- ============================================================

create table if not exists public.aa_bills (
    id uuid primary key default gen_random_uuid(),
    creator_id uuid not null references auth.users(id) on delete cascade,
    name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create table if not exists public.aa_bill_members (
    id uuid primary key default gen_random_uuid(),
    bill_id uuid not null references public.aa_bills(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    email text not null,
    created_at timestamptz not null default now(),
    unique (bill_id, user_id)
);

create table if not exists public.aa_bill_items (
    id uuid primary key default gen_random_uuid(),
    bill_id uuid not null references public.aa_bills(id) on delete cascade,
    user_id uuid not null references auth.users(id) on delete cascade,
    record_id uuid references public.records(id) on delete set null,
    name text not null,
    category text,
    amount numeric(12,2) not null check (amount > 0),
    note text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists aa_bills_creator_idx on public.aa_bills(creator_id);
create index if not exists aa_bill_members_bill_idx on public.aa_bill_members(bill_id);
create index if not exists aa_bill_members_user_idx on public.aa_bill_members(user_id);
create index if not exists aa_bill_items_bill_idx on public.aa_bill_items(bill_id);
create index if not exists aa_bill_items_user_idx on public.aa_bill_items(user_id);

alter table public.aa_bills enable row level security;
alter table public.aa_bill_members enable row level security;
alter table public.aa_bill_items enable row level security;

drop policy if exists "AA bills readable by members" on public.aa_bills;
create policy "AA bills readable by members"
on public.aa_bills for select
using (
    creator_id = auth.uid()
    or exists (
        select 1 from public.aa_bill_members m
        where m.bill_id = id and m.user_id = auth.uid()
    )
);

drop policy if exists "AA bills created by self" on public.aa_bills;
create policy "AA bills created by self"
on public.aa_bills for insert
with check (creator_id = auth.uid());

drop policy if exists "AA bills updated by creator" on public.aa_bills;
create policy "AA bills updated by creator"
on public.aa_bills for update
using (creator_id = auth.uid());

drop policy if exists "AA bills deleted by creator" on public.aa_bills;
create policy "AA bills deleted by creator"
on public.aa_bills for delete
using (creator_id = auth.uid());

drop policy if exists "AA members readable by bill members" on public.aa_bill_members;
create policy "AA members readable by bill members"
on public.aa_bill_members for select
using (
    exists (
        select 1 from public.aa_bills b
        where b.id = bill_id
          and (b.creator_id = auth.uid()
               or exists (
                   select 1 from public.aa_bill_members m2
                   where m2.bill_id = b.id and m2.user_id = auth.uid()
               ))
    )
);

-- 用户只能把自己加入账单；邀请其他用户通过 Edge Function 使用 service_role 写入
drop policy if exists "No client insert AA members" on public.aa_bill_members;
create policy "No client insert AA members"
on public.aa_bill_members for insert
with check (user_id = auth.uid());

drop policy if exists "AA members managed by creator" on public.aa_bill_members;
create policy "AA members managed by creator"
on public.aa_bill_members for update
using (
    exists (
        select 1 from public.aa_bills b
        where b.id = bill_id and b.creator_id = auth.uid()
    )
);

drop policy if exists "AA members deleted by creator" on public.aa_bill_members;
create policy "AA members deleted by creator"
on public.aa_bill_members for delete
using (
    exists (
        select 1 from public.aa_bills b
        where b.id = bill_id and b.creator_id = auth.uid()
    )
);

drop policy if exists "AA items readable by bill members" on public.aa_bill_items;
create policy "AA items readable by bill members"
on public.aa_bill_items for select
using (
    exists (
        select 1 from public.aa_bills b
        where b.id = bill_id
          and (b.creator_id = auth.uid()
               or exists (
                   select 1 from public.aa_bill_members m
                   where m.bill_id = b.id and m.user_id = auth.uid()
               ))
    )
);

drop policy if exists "AA items inserted by bill members" on public.aa_bill_items;
create policy "AA items inserted by bill members"
on public.aa_bill_items for insert
with check (
    exists (
        select 1 from public.aa_bills b
        where b.id = bill_id
          and (b.creator_id = auth.uid()
               or exists (
                   select 1 from public.aa_bill_members m
                   where m.bill_id = b.id and m.user_id = auth.uid()
               ))
    )
);

drop policy if exists "AA items updated by owner" on public.aa_bill_items;
create policy "AA items updated by owner or creator"
on public.aa_bill_items for update
using (
    (user_id = auth.uid() or exists (
        select 1 from public.aa_bills b2
        where b2.id = bill_id and b2.creator_id = auth.uid()
    ))
    and exists (
        select 1 from public.aa_bills b
        where b.id = bill_id
          and (b.creator_id = auth.uid()
               or exists (
                   select 1 from public.aa_bill_members m
                   where m.bill_id = b.id and m.user_id = auth.uid()
               ))
    )
);

drop policy if exists "AA items deleted by owner" on public.aa_bill_items;
create policy "AA items deleted by owner or creator"
on public.aa_bill_items for delete
using (
    (user_id = auth.uid() or exists (
        select 1 from public.aa_bills b2
        where b2.id = bill_id and b2.creator_id = auth.uid()
    ))
    and exists (
        select 1 from public.aa_bills b
        where b.id = bill_id
          and (b.creator_id = auth.uid()
               or exists (
                   select 1 from public.aa_bill_members m
                   where m.bill_id = b.id and m.user_id = auth.uid()
               ))
    )
);
