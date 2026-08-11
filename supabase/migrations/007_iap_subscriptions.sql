-- ============================================================
-- 007: IAP 订阅状态表
-- ============================================================

create table if not exists public.subscriptions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    product_id text not null,
    original_transaction_id text not null unique,
    transaction_id text not null,
    expires_at timestamptz,
    is_active boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists subscriptions_user_idx on public.subscriptions(user_id);
create index if not exists subscriptions_original_tx_idx on public.subscriptions(original_transaction_id);

alter table public.subscriptions enable row level security;

-- 用户只能查看自己的订阅记录
-- 写入由 service_role / Edge Function 完成，客户端不直接写入
create policy "Users can read their own subscriptions"
on public.subscriptions for select
using (auth.uid() = user_id);

-- profiles.is_premium 已由 001_core_schema.sql 创建，此处确保其存在即可
-- 如需从 subscriptions 反查，可创建视图或触发器
