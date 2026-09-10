-- ============================================================
-- 018: AA 账单名称唯一（同一创建者内不允许重名）
-- ============================================================

create unique index if not exists aa_bills_creator_name_idx
on public.aa_bills(creator_id, name);
