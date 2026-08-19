-- ============================================================
-- 014: 服务端每日 AI 解析次数限制
-- 防止用户绕过客户端限制刷默认智能体额度
-- ============================================================

create table if not exists public.parse_usage (
    user_id uuid not null references auth.users(id) on delete cascade,
    usage_date date not null,
    count integer not null default 1,
    updated_at timestamptz not null default now(),
    primary key (user_id, usage_date)
);

alter table public.parse_usage enable row level security;

-- 客户端不需要读写该表，仅 Edge Function 通过 service_role 访问
create policy "No client access to parse usage"
on public.parse_usage for select
using (false);

create policy "No client insert to parse usage"
on public.parse_usage for insert
with check (false);

create policy "No client update to parse usage"
on public.parse_usage for update
using (false);

create policy "No client delete to parse usage"
on public.parse_usage for delete
using (false);
