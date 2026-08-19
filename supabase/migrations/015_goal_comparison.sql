-- ============================================================
-- 015: 目标达成条件（与目标金额的关系）
-- 支持大于等于 / 小于等于 / 等于，默认大于等于
-- ============================================================

alter table if exists public.goal_targets
    add column if not exists comparison text not null default '大于等于';
