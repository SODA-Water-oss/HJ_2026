-- ============================================================
-- 020: AA 账单名称允许所有共享成员编辑
-- ============================================================

drop policy if exists "AA bills updated by creator" on public.aa_bills;
create policy "AA bills updated by members"
on public.aa_bills for update
using (
    creator_id = auth.uid()
    or public.is_aa_bill_member(id)
)
with check (
    creator_id = auth.uid()
    or public.is_aa_bill_member(id)
);
