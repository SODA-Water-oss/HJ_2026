-- ============================================================
-- 021: AA 账单更新时间自动刷新
-- 任何共享成员对账单、条目、成员进行增删改，
-- 都会同步刷新 aa_bills.updated_at
-- ============================================================

create or replace function public.touch_aa_bill_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    v_bill_id uuid;
begin
    if tg_table_name = 'aa_bill_items' then
        v_bill_id := coalesce(new.bill_id, old.bill_id);
    elsif tg_table_name = 'aa_bill_members' then
        v_bill_id := coalesce(new.bill_id, old.bill_id);
    else
        v_bill_id := null;
    end if;

    if v_bill_id is not null then
        update public.aa_bills
        set updated_at = now()
        where id = v_bill_id;
    end if;

    return null;
end;
$$;

drop trigger if exists aa_bills_set_updated_at on public.aa_bills;
create trigger aa_bills_set_updated_at
before update on public.aa_bills
for each row execute function public.set_updated_at();

drop trigger if exists aa_bill_items_touch_bill on public.aa_bill_items;
create trigger aa_bill_items_touch_bill
after insert or update or delete on public.aa_bill_items
for each row execute function public.touch_aa_bill_updated_at();

drop trigger if exists aa_bill_members_touch_bill on public.aa_bill_members;
create trigger aa_bill_members_touch_bill
after insert or update or delete on public.aa_bill_members
for each row execute function public.touch_aa_bill_updated_at();
