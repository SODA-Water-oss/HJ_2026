-- ============================================================
-- 022: 共享成员可退出 AA 账单
-- 创建人可删除成员；共享成员可删除自己的关联并退出
-- ============================================================

drop policy if exists "AA members deleted by creator" on public.aa_bill_members;
create policy "AA members deleted by member or creator"
on public.aa_bill_members for delete
using (
    user_id = auth.uid()
    or public.is_aa_bill_creator(bill_id)
);
