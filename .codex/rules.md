# 花计2046 项目规则 — Codex 每次启动必须读

## 安全修改流程

### 备份与恢复（教训：不要覆盖已有功能）

1. **修改前** — 先 `git diff` 看当前的改动，理解哪些是已实现但未提交的功能
2. **备份** — `cp file.swift file.swift.bak` 后，再 `git stash` 或 `git checkout` 之前，先用 `diff file.swift.bak file.swift` 确认备份包含所有已有功能
3. **恢复旧版** — 如果必须从 git 恢复旧版本恢复某个模块：
   - 先 `git show HEAD:file.swift > /tmp/old_version.swift`
   - 然后 `diff /tmp/old_version.swift file.swift.bak` 对比备份和旧版的差异
   - 列出 "备份有但旧版没有" 的功能清单 → 这些必须在恢复后手动加回来
   - **确认清单上的每一项都恢复后，再编译**
4. **编译前** — 对备份做 `grep -n` 检查关键功能关键词（如水印 `RecordWatermark`、侧边色条 `overlay`、类别颜色 `categoryColor` 等）是否还在

## 修改登记（防丢）

每次提交前：
1. 跑 `git status` 看改了哪些文件
2. 对每个改动的文件，用 `grep` 确认已知的关键功能标记没被误删
3. 提交信息写清楚改了什么

## 字体标准（搜索模块统一用这套）

- 类型按钮（全部/收入/支出）：17 Medium
- 名称/备注搜索输入框：17
- 搜索框放大镜图标：15
- 年份/月份/类别标签：17
- 筛选摘要文字：17 Medium
- 清除筛选按钮：15
- 批量操作文字：15
- 批量操作菜单按钮：17 Medium
- 空状态提示：15
- 金额文字：支出 textSecondary，收入 green

## 金额显示标准

- 支出金额：AppTheme.textSecondary（#6B7280 中灰），前缀 "-"
- 收入金额：.green，前缀 "+"
- 编辑页金额录入：切换收支时金额颜色同步切换

# Last verified: 2026-07-20 00:03 Git push OK

## 当前已知完好版本备份
最后一次完整备份: 9050487 2026-07-20 00:23:07 +0800
提交: chore: full backup before further development
恢复方式: git checkout <hash> -- <file>
