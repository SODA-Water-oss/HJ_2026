#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
意见反馈后台查询/导出工具
读取 Supabase 的 feedbacks 表（服务端密钥绕过 RLS，可查看所有用户反馈），
以可读表格或 CSV 展示。

用法:
  python3 scripts/feedback-admin.py                     # 查看最近 20 条
  python3 scripts/feedback-admin.py --limit 100         # 查看最近 100 条
  python3 scripts/feedback-admin.py --days 7            # 只看最近 7 天
  python3 scripts/feedback-admin.py --csv feedback.csv  # 导出 CSV（默认最近 20 条）
  python3 scripts/feedback-admin.py --csv feedback.csv --limit 1000   # 导出更多
  python3 scripts/feedback-admin.py --json              # 输出原始 JSON
  python3 scripts/feedback-admin.py --user <user_id>    # 只看某个用户（id 前缀或完整）

配置来源（按优先级，无需在命令行传密钥）:
  1. 环境变量 SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY
  2. Configs/Local.xcconfig（SUPABASE_URL）
  3. .env.supabase（SERVICE_ROLE_KEY）
"""
import argparse
import csv
import json
import os
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load_key_value_file(path):
    """解析 KEY=VALUE 格式文件（兼容 .env 与 .xcconfig），返回 dict。"""
    result = {}
    if not os.path.isfile(path):
        return result
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or "=" not in line:
                continue
            if line.lstrip().startswith("//") or line.lstrip().startswith("#"):
                continue
            key, _, value = line.partition("=")
            # xcconfig 里 https:/$()/... 的 $() 是空变量占位，等价于 //
            result[key.strip()] = value.strip().strip('"').strip("'").replace("$()", "")
    return result


def get_config():
    env = dict(os.environ)
    xcconfig = load_key_value_file(os.path.join(ROOT, "Configs", "Local.xcconfig"))
    env_file = load_key_value_file(os.path.join(ROOT, ".env.supabase"))
    url = env.get("SUPABASE_URL") or xcconfig.get("SUPABASE_URL") or ""
    key = (
        env.get("SUPABASE_SERVICE_ROLE_KEY")
        or env.get("SERVICE_ROLE_KEY")
        or env_file.get("SERVICE_ROLE_KEY")
        or ""
    )
    return url.rstrip("/"), key


def fetch_feedbacks(url, key, params):
    query = urllib.parse.urlencode(params)
    req = urllib.request.Request(
        f"{url}/rest/v1/feedbacks?{query}",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def print_table(rows):
    if not rows:
        print("暂无反馈。")
        return
    print(f"共 {len(rows)} 条反馈\n")
    for i, row in enumerate(rows, 1):
        created = (row.get("created_at") or "")[:19].replace("T", " ")
        content = (row.get("content") or "").replace("\n", " ").strip()
        contact = row.get("contact") or "-"
        uid = (row.get("user_id") or "")[:8]
        print(f"[{i}] {created}  用户:{uid}  联系方式:{contact}")
        print(f"    {content}")
        print()


def export_csv(rows, path):
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(["创建时间", "用户ID", "联系方式", "反馈内容", "记录ID"])
        for row in rows:
            writer.writerow([
                row.get("created_at") or "",
                row.get("user_id") or "",
                row.get("contact") or "",
                row.get("content") or "",
                row.get("id") or "",
            ])
    print(f"已导出 {len(rows)} 条反馈到 {path}")


def main():
    ap = argparse.ArgumentParser(description="查询/导出 Supabase 用户意见反馈")
    ap.add_argument("--limit", type=int, default=20, help="最多返回条数（默认 20）")
    ap.add_argument("--days", type=int, default=0, help="只看最近 N 天（默认全部）")
    ap.add_argument("--csv", metavar="PATH", help="导出为 CSV 文件路径")
    ap.add_argument("--json", action="store_true", help="输出原始 JSON")
    ap.add_argument("--user", help="只看某个用户的反馈（user_id 前缀或完整 id）")
    args = ap.parse_args()

    url, key = get_config()
    if not url or not key:
        print("错误：未找到 Supabase 配置。", file=sys.stderr)
        print("  - 在 Configs/Local.xcconfig 配置 SUPABASE_URL", file=sys.stderr)
        print("  - 在 .env.supabase 配置 SERVICE_ROLE_KEY", file=sys.stderr)
        print("  - 或设置环境变量 SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        sys.exit(1)

    params = {
        "select": "*",
        "order": "created_at.desc",
        "limit": str(args.limit),
    }
    if args.days > 0:
        since = (datetime.utcnow() - timedelta(days=args.days)).isoformat() + "Z"
        params["created_at"] = f"gte.{since}"
    if args.user:
        user = args.user
        params["user_id"] = f"eq.{user}" if len(user) >= 36 else f"like.{user}%"

    try:
        rows = fetch_feedbacks(url, key, params)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:300]
        print(f"查询失败（HTTP {e.code}）：{body}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"查询失败：{e}", file=sys.stderr)
        sys.exit(1)

    if args.json:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return
    if args.csv:
        export_csv(rows, args.csv)
        return
    print_table(rows)


if __name__ == "__main__":
    main()
