-- ============================================================
-- 002: 收入支持 — expenses → records 迁移 + type 字段
-- ============================================================

-- 1. 重命名表 + 增加 type 列
ALTER TABLE IF EXISTS public.expenses RENAME TO records;
ALTER TABLE IF EXISTS public.records ADD COLUMN type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('expense', 'income'));

-- 2. 旧索引改名
ALTER INDEX IF EXISTS expenses_user_date_idx RENAME TO records_user_date_idx;
ALTER INDEX IF EXISTS expenses_user_category_idx RENAME TO records_user_category_idx;

-- 3. 新增按 type 查询的索引
CREATE INDEX IF NOT EXISTS records_user_month_idx ON public.records(user_id, (to_char(date, 'YYYY-MM')));
CREATE INDEX IF NOT EXISTS records_user_type_idx ON public.records(user_id, type);

-- 4. 触发器改名
DROP TRIGGER IF EXISTS expenses_set_updated_at ON public.records;
CREATE TRIGGER records_set_updated_at
BEFORE UPDATE ON public.records
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 5. RLS 策略
ALTER TABLE IF EXISTS public.records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own expenses" ON public.records;
CREATE POLICY "Users can read their own records"
ON public.records FOR SELECT
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own expenses" ON public.records;
CREATE POLICY "Users can insert their own records"
ON public.records FOR INSERT
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own expenses" ON public.records;
CREATE POLICY "Users can update their own records"
ON public.records FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own expenses" ON public.records;
CREATE POLICY "Users can delete their own records"
ON public.records FOR DELETE
USING (auth.uid() = user_id);

-- 6. 兼容旧 policy 名（如果迁移前已存在）
DROP POLICY IF EXISTS "Users can read their own expenses" ON public.records;
DROP POLICY IF EXISTS "Users can insert their own expenses" ON public.records;
DROP POLICY IF EXISTS "Users can update their own expenses" ON public.records;
DROP POLICY IF EXISTS "Users can delete their own expenses" ON public.records;
