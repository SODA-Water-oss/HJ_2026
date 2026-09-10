-- ============================================================
-- 023: AA 分账实时同步
-- 将账单、成员、条目加入 Realtime 发布，供客户端订阅更新
-- ============================================================

alter publication supabase_realtime add table public.aa_bills;
alter publication supabase_realtime add table public.aa_bill_members;
alter publication supabase_realtime add table public.aa_bill_items;
