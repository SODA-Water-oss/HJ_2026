-- ============================================================
-- 013: profiles 增加 name 字段（注册时录入的用户名/昵称）
-- 注册时把 auth.users 的 user_metadata.name 同步到 profiles.name
-- ============================================================

alter table if exists public.profiles
    add column if not exists name text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email, name)
    values (
        new.id,
        coalesce(new.email, ''),
        nullif(new.raw_user_meta_data->>'name', '')
    )
    on conflict (id) do update
        set email = excluded.email,
            name = coalesce(excluded.name, profiles.name);
    return new;
end;
$$;
