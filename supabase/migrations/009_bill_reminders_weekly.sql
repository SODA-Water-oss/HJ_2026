-- ============================================================
-- 009: 账单提醒支持每周周期
-- 去掉「每季度」新建入口，但保留 quarterly 允许值以兼容旧数据
-- ============================================================

alter table if exists public.bill_reminders
    drop constraint if exists bill_reminders_recurrence_check;

alter table if exists public.bill_reminders
    add constraint bill_reminders_recurrence_check
    check (recurrence in ('monthly', 'yearly', 'once', 'weekly', 'quarterly'));
