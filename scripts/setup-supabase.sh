#!/usr/bin/env bash
# ============================================================
# 花计2046 — Supabase 一键「迁移 + 部署函数 + 设置密钥」
#
# 用法:
#   ./scripts/setup-supabase.sh
#   或指定项目: PROJECT_REF=xxxx ./scripts/setup-supabase.sh
#
# 前置条件:
#   1. 已安装 supabase CLI
#        brew install supabase/tap/supabase
#   2. 已创建 Supabase 项目
#   3. 已准备好密钥文件 .env.supabase（复制 .env.supabase.example 填写）
#
# 说明:
#   - 首次运行会引导登录 + 关联项目
#   - 数据库迁移按 001~011 顺序应用到远程
#   - 部署 3 个 Edge Functions 并注入环境变量
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

ENV_FILE=".env.supabase"
FUNCTIONS=("parse-expense" "verify-transaction" "delete-account")

echo "📋 花计2046 Supabase 部署脚本"
echo "================================"

# ---------- 1. 检查 CLI ----------
if ! command -v supabase >/dev/null 2>&1; then
  echo "❌ 未找到 supabase CLI，请先安装: brew install supabase/tap/supabase"
  exit 1
fi
echo "✅ supabase CLI 已安装"

# ---------- 2. 登录 ----------
if [ ! -f "$HOME/.supabase/access-token" ]; then
  echo "🔑 请完成 Supabase 登录（浏览器会打开）..."
  supabase login
fi
echo "✅ 已登录"

# ---------- 3. 解析项目 ref ----------
PROJECT_REF="${PROJECT_REF:-}"
if [ -z "$PROJECT_REF" ]; then
  if [ -f "Configs/Local.xcconfig" ]; then
    URL_VAL=$(grep -E '^SUPABASE_URL[[:space:]]*=' "Configs/Local.xcconfig" 2>/dev/null | head -1 | sed -E 's/^[^=]*=[[:space:]]*//')
    PROJECT_REF=$(echo "$URL_VAL" | sed -E 's|https?://([^.]*)\..*|\1|' 2>/dev/null || true)
  fi
fi
if [ -z "$PROJECT_REF" ] || [ "$PROJECT_REF" = "your-project" ]; then
  echo "❌ 无法确定 Supabase 项目 ref。"
  echo "   方式一：PROJECT_REF=你的项目ref ./scripts/setup-supabase.sh"
  echo "   方式二：在 Configs/Local.xcconfig 中配置真实 SUPABASE_URL"
  echo "   （项目 ref 可在 Supabase 控制台 → Project Settings → API 中查看）"
  exit 1
fi
echo "✅ 项目 ref: $PROJECT_REF"

# ---------- 4. 关联项目 ----------
if [ "$(cat supabase/.temp/project-ref 2>/dev/null || echo '')" != "$PROJECT_REF" ]; then
  echo "🔗 关联项目..."
  supabase link --project-ref "$PROJECT_REF"
fi

# ---------- 5. 数据库迁移 ----------
echo "🗄️  执行数据库迁移（001~011）..."
echo "    ⚠️ 如果此前已在 SQL Editor 手动执行过全部迁移，可跳过（输入 n）"
read -r -p "    继续执行迁移? [Y/n] " RUN_MIGRATION
if [[ ! "$RUN_MIGRATION" =~ ^[Nn]$ ]]; then
  supabase db push
  echo "✅ 迁移完成"
else
  echo "⏭️  已跳过迁移"
fi

# ---------- 6. 检查密钥文件 ----------
if [ ! -f "$ENV_FILE" ]; then
  echo "⚠️  未找到 $ENV_FILE"
  echo "   请复制模板并填写后重新运行: cp .env.supabase.example $ENV_FILE"
  echo "   继续部署函数（密钥将在稍后手动设置）..."
fi

# ---------- 7. 部署函数 ----------
for fn in "${FUNCTIONS[@]}"; do
  echo "🚀 部署函数: $fn"
  supabase functions deploy "$fn"
done
echo "✅ 函数部署完成"

# ---------- 8. 设置环境变量 ----------
if [ -f "$ENV_FILE" ]; then
  echo "🔐 设置函数环境变量（对所有函数生效）..."
  supabase secrets set --env-file "$ENV_FILE"
  echo "✅ 环境变量设置完成"
else
  echo "ℹ️  请手动设置密钥: supabase secrets set --env-file $ENV_FILE"
fi

echo ""
echo "🎉 全部完成！可在 Supabase 控制台验证："
echo "   - 数据库: 7 张核心表（profiles/records/user_settings/bill_reminders/subscriptions/user_logs + 系统表）"
echo "   - Edge Functions: ${FUNCTIONS[*]}"
