# Wander Wonders 旧项目只读迁移基线

- 录取日期：2026-08-12
- 旧目录：/Users/claudia/Documents/Claude/Projects/20260801_wander_wonders_v1
- 新目录：/Users/claudia/Documents/Claude/Projects/20260812_wander_wonders_v2_LH
- 规则：旧目录保持只读；新仓库验证完成前不清理或删除旧目录

## 1. 旧 Git 状态

旧仓库 HEAD 只跟踪规格、DOCX、旧计划和 .gitignore。实现主体没有可恢复的 Git commit。

Modified tracked files：

- .gitignore
- plans/2026-08-01-build-wander-wonders-v1-autumn-plan-v5.md

Untracked implementation roots/files：

- .swiftformat
- .swiftlint.yml
- Config/
- Content/
- Package.resolved
- Scripts/
- WanderWonders/
- WanderWondersTests/
- WanderWondersUITests/
- docs/
- package.json
- project.yml
- supabase/

因此旧目录是当前实现的唯一副本。禁止对旧目录执行 git clean、git reset、checkout 覆盖、删除、格式化、测试或生成。

## 2. 已实测计数

| 项目 | 2026-08-12 结果 |
|---|---:|
| public wonder_ tables | 22 |
| public wonder_ RPC | 24 |
| wonder_private domain functions | 18 |
| wonder_private schema trigger helpers | 1 |
| wonder_private functions total | 19 |
| pgTAP declared assertions | 85 |
| production app Swift LOC | 44 |
| Edge .ts/.tsx files | 0 |
| production art files | 0 |

pgTAP 声明来自三个文件：19 + 40 + 26 = 85。这里仅证明测试被声明，不证明当前通过。

## 3. 允许迁移的路径

- .gitignore
- .swiftformat
- .swiftlint.yml
- Config/
- Content/
- Package.resolved
- Scripts/
- WanderWonders/
- WanderWondersTests/
- WanderWondersUITests/
- docs/
- package.json
- project.yml
- supabase/

新仓库已有 WanderWonders_Complete_Product_Spec.md、README.md、plans/ 下的新文档，不从旧目录覆盖。

## 4. 明确排除的路径

- .git/
- .build/
- WanderWonders.xcodeproj/
- .DS_Store
- supabase/.DS_Store
- supabase/.temp/
- supabase/.branches/
- 任何非 example xcconfig
- 任何 secret、token、key、p8、OAuth code、tester email 或 provider response

## 5. 迁移后核对

1. 对三份 migration、三份数据库测试、三份 Content JSON、project.yml 和关键 scripts 执行源/目标 cmp。
2. 确认排除路径在新仓库不存在或已被 ignore。
3. 运行 secret-pattern scan 和 git diff --check。
4. 提交新仓库 migration baseline 后，旧目录继续保留为只读安全副本。
