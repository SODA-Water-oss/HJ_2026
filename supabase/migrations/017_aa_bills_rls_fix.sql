-- ============================================================
-- 017: 修复 AA 分账 RLS 循环递归
-- aa_bills 与 aa_bill_members 的 SELECT 策略互相引用，
-- 导致 INSERT ... RETURNING / SELECT 时触发 infinite recursion。
-- 改用 security definer 辅助函数查询成员关系，断开递归。
-- ============================================================

create or replace function public.is_aa_bill_member(p_bill_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.aa_bill_members m
    where m.bill_id = p_bill_id and m.user_id = auth.uid()
  );
$$;

create or replace function public.is_aa_bill_creator(p_bill_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.aa_bills b
    where b.id = p_bill_id and b.creator_id = auth.uid()
  );
$$;

grant execute on function public.is_aa_bill_member(uuid) to anon, authenticated;
grant execute on function public.is_aa_bill_creator(uuid) to anon, authenticated;

drop policy if exists "AA bills readable by members" on public.aa_bills;
create policy "AA bills readable by members"
on public.aa_bills for select
using (creator_id = auth.uid() or public.is_aa_bill_member(id));

drop policy if exists "AA members readable by bill members" on public.aa_bill_members;
create policy "AA members readable by bill members"
on public.aa_bill_members for select
using (public.is_aa_bill_creator(bill_id) or public.is_aa_bill_member(bill_id));

drop policy if exists "AA members managed by creator" on public.aa_bill_members;
create policy "AA members managed by creator"
on public.aa_bill_members for update
using (public.is_aa_bill_creator(bill_id));

drop policy if exists "AA members deleted by creator" on public.aa_bill_members;
create policy "AA members deleted by creator"
on public.aa_bill_members for delete
using (public.is_aa_bill_creator(bill_id));

drop policy if exists "AA items readable by bill members" on public.aa_bill_items;
create policy "AA items readable by bill members"
on public.aa_bill_items for select
using (public.is_aa_bill_creator(bill_id) or public.is_aa_bill_member(bill_id));

drop policy if exists "AA items inserted by bill members" on public.aa_bill_items;
create policy "AA items inserted by bill members"
on public.aa_bill_items for insert
with check (public.is_aa_bill_creator(bill_id) or public.is_aa_bill_member(bill_id));

drop policy if exists "AA items updated by owner or creator" on public.aa_bill_items;
create policy "AA items updated by owner or creator"
on public.aa_bill_items for update
using (
  (user_id = auth.uid() or public.is_aa_bill_creator(bill_id))
  and (public.is_aa_bill_creator(bill_id) or public.is_aa_bill_member(bill_id))
);

drop policy if exists "AA items deleted by owner or creator" on public.aa_bill_items;
create policy "AA items deleted by owner or creator"
on public.aa_bill_items for delete
using (
  (user_id = auth.uid() or public.is_aa_bill_creator(bill_id))
  and (public.is_aa_bill_creator(bill_id) or public.is_aa_bill_member(bill_id))
);
