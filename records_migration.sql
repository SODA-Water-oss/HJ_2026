-- ============================================================
-- 花计2046 — 数据库迁移：expenses → records
-- ============================================================

-- 1. 创建新表 records（合并收支，type 区分）
CREATE TABLE IF NOT EXISTS records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'expense' CHECK (type IN ('expense', 'income')),
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    category TEXT NOT NULL DEFAULT '其他',
    merchant TEXT NOT NULL DEFAULT '',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. 索引（不建按月索引，TIMESTAMPTZ 不能用表达式索引）
CREATE INDEX IF NOT EXISTS idx_records_user_date 
    ON records(user_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_records_user_type 
    ON records(user_id, type);

-- 3. 迁移旧数据
INSERT INTO records (id, user_id, type, amount, category, merchant, date, note, created_at)
SELECT id, user_id, 'expense' AS type, amount, category, merchant, date, note, created_at
FROM expenses
ON CONFLICT (id) DO NOTHING;

-- 4. RLS 策略
ALTER TABLE records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "用户访问自己的记录" ON records;
CREATE POLICY "用户访问自己的记录" ON records
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
