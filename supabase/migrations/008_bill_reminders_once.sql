-- ============================================================
-- 008: 账单提醒支持一次性模式 + 自定义提醒时间
-- ============================================================

-- 一次性提醒的日期（recurrence = 'once' 时使用）
alter table if exists public.bill_reminders
    add column if not exists once_date timestamptz;

-- 自定义提醒时间（时:分，"HH:mm"，周期/一次性通用）
alter table if exists public.bill_reminders
    add column if not exists reminder_time text;

-- recurrence 增加 once 允许值
alter table if exists public.bill_reminders
    drop constraint if exists bill_reminders_recurrence_check;

alter table if exists public.bill_reminders
    add constraint bill_reminders_recurrence_check
    check (recurrence in ('monthly', 'quarterly', 'yearly', 'once'));

-- 闭环：已付/完成状态
alter table if exists public.bill_reminders
    add column if not exists paid_period_key text;
alter table if exists public.bill_reminders
    add column if not exists paid_date timestamptz;
