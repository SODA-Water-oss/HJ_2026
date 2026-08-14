-- ============================================================
-- 008: 账单提醒支持一次性（指定日期时间）模式
-- ============================================================

-- 一次性提醒的日期时间（recurrence = 'once' 时使用）
alter table if exists public.bill_reminders
    add column if not exists once_date timestamptz;

-- recurrence 增加 once 允许值
alter table if exists public.bill_reminders
    drop constraint if exists bill_reminders_recurrence_check;

alter table if exists public.bill_reminders
    add constraint bill_reminders_recurrence_check
    check (recurrence in ('monthly', 'quarterly', 'yearly', 'once'));
