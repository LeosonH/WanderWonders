# Wander Wonders V1 新仓库端到端执行计划（V6）

- 准备日期：2026-08-12
- 执行仓库：/Users/claudia/Documents/Claude/Projects/20260812_wander_wonders_v2_LH
- 产品真相源：WanderWonders_Complete_Product_Spec.md
- 目标：native iPhone / iOS 17+ / Swift 6 / Autumn-only V1 / free beta
- 后端：专用 Supabase 项目 qmsliloouxmybnfzzlks，所有 app table 以 wonder_ 开头
- 执行规则：严格按 Step 0–14 顺序；只有验证通过后才标记 [codex done]

## 1. APPROVE 与 Claude 反馈处置

APPROVE：Claude 的复核与仓库证据一致。V6 采用“保留后端和内容工程，重写 Edge/iOS 产品层”，不全项目重写。

| 反馈 | 处置 | V6 决定 |
|---|---|---|
| 旧实现主体 100% 未被 Git 跟踪 | Accept | Step 0 先录清单；Step 1 只读、窄路径复制；旧目录不写、不清理 |
| 59/59、85/85 只是历史自述 | Accept | 历史完成标记归零；Step 2–3 在新仓库重跑后才建立当前证据 |
| private function 总数是 19 | Accept | inventory 要求 1 个 schema trigger helper + 18 个 domain helper |
| role-level 5s timeout 作用于整个项目 | Accept | 本地可测；远端必须先确认专用性、原 rolconfig、回滚 SQL 和管理操作路径 |
| Autumn 在函数名和 SHA-256 输入中硬编码 | Accept | V1 保留；换季必须新 catalog + app + fixtures，不做自动换季框架 |
| verified-start RPC 仅 service_role | Accept | 保留；客户端只能经 wonder-park-check 间接调用 |
| 不应继续直接使用旧 V5 | Accept | 本文成为新仓库唯一执行记录，以证据门禁替代旧日期门禁 |

没有被拒绝的反馈。唯一调整：外部账号、密钥、公开 URL 和生产美术阻塞真实 provider、发布和 TestFlight，但不阻塞本地 mock Edge/iOS 实现。

## 2. 第一性原理和方案选择

V1 最难的问题是断网、重试、多设备和强退下仍不重复发花、发 Glow 或扣款。因此保留服务端权威、幂等、revision 和离线持久化；其余分层从简。

| 领域 | 现实选项 | V6 决定 |
|---|---|---|
| 旧代码 | 全重写 / 全搬 / 保留可验证资产 | 保留 SQL、tests、catalog、scripts 和最小 iOS scaffold |
| iOS Supabase | 手写 HTTP/Auth / 官方 SDK | 锁定 supabase-swift 2.46.0 |
| iOS 分层 | 每 feature repository/service / 最小核心 | GameStore + WonderClient + WonderPersistence + MutationQueue |
| 离线 | 只读 / 所有操作 / 窄操作集 | 离线读、Wander、花瓶和书架；不可逆经济操作要求在线 |
| UI | 第三方状态库 / SwiftUI Observation | SwiftUI + @Observable @MainActor GameStore |
| 持久化 | 自建 SQLite / SwiftData | iOS 17 原生 SwiftData |
| 系统能力 | 第三方 SDK / 原生 | AuthenticationServices、HealthKit、CoreMotion、CoreLocation、UserNotifications |
| 季节 | 通用引擎 / Autumn-only | Autumn-only；不为未来预构建 |
| 部署 | 边写边推 / 本地全绿后授权 | 后者 |

## 3. 范围

### In scope

- Apple/Google 登录与 Supabase Auth 合约。
- Daily Daisy、park/manual/offline Wander、10/20/30 分钟奖励、Pocket、vase、Pressbook、Glow Shop、flower lifecycle、steps、Hibernate、Settings、account deletion。
- 缓存、可逆离线操作、幂等同步、强退恢复、隐私、安全、可访问性。
- 本地 Supabase/Edge/iOS 测试，以及授权后的远端部署、真机、TestFlight 和 beta 证据。

### Out of scope

- Spring/Summer/Winter 自动轮换、AI、MCP、social、Android、iPad 专属 UI、支付、StoreKit、广告、订阅、公开 App Store。
- 管理后台、通用商品系统、通用规则引擎、通用网络抽象。

## 4. 硬边界

1. 旧目录是未跟踪实现唯一副本：不对它执行 git clean/reset/checkout、删除、格式化、测试、生成或其他写操作。
2. 不搬 .git、.build、DerivedData、xcresult、.DS_Store、supabase/.temp、supabase/.branches、生成的 xcodeproj。
3. 不把 token、p8、OAuth code、secret/API key、邮箱、原始 Health sample、精确坐标、route、place name 或 provider body 写入 Git、SwiftData、Postgres、日志或 fixtures。
4. 未在外部操作当下获得明确授权前，不 link/mutate remote Supabase，不配 provider/secret，不 upload build、submit review 或 invite tester。
5. 模拟器不能替代真实登录、Apple Maps、Health/Watch、Motion、后台/强退、Apple revoke、TestFlight 和触摸 VoiceOver。
6. 历史自述、代码存在、本地绿、远端一致、真机验收和 soak 是独立证据。
7. MacBook Air 无风扇：只启动一个本地 Supabase 栈，排除 studio/logflare/vector/imgproxy，用完停止，先跑最小检查。

## 5. 当前基线

- 新旧规格字节级一致。
- 旧实现含 22 个 wonder_ table、24 个 public RPC、19 个 wonder_private function。
- 三个 pgTAP 文件声明 19 + 40 + 26 = 85 个断言，但 V6 开始时当前通过数未验证。
- iOS 生产 Swift 仅 44 行；Edge TypeScript 为 0；production art 为 0。
- catalog 声明 13 花种、12 Autumn Wander 花、5 Shop item；manifest 声明 50 套资产。
- 新仓库 main 已有规格历史；计划开始时 .DS_Store 和进度文档未跟踪。
- 定向 Git 历史没有旧实现的可恢复 commit。

## 6. 权威系统合约

### 6.1 数据和安全

- 恰好 22 个 public wonder_ table，全部 ENABLE + FORCE RLS。
- 撤销 PUBLIC、anon、authenticated 的直接 table access；客户端只通过白名单 SECURITY DEFINER RPC。
- 所有 definer function 使用空 search_path、schema-qualified references、auth.uid owner check 和 per-signature grant。
- offer、event、ledger、product-event 不可 update/delete。
- 删除 auth.users 必须 cascade 清理全部 owner rows。
- Supabase 2026 Data API 默认暴露变化不改变本项目设计：table 主动撤权，只显式 grant RPC execute。

### 6.2 RPC 白名单

Authenticated 23 个：

wonder_auth_gate、wonder_approve_linked_identity、wonder_bootstrap、wonder_refresh_state、wonder_start_manual_wander、wonder_reconcile_wander、wonder_choose_wander_reward、wonder_end_wander、wonder_sync_offline_wander、wonder_assign_flower_to_vase、wonder_remove_flower_from_vase、wonder_press_flower、wonder_sell_flower、wonder_apply_sunshine、wonder_assign_shelf_species、wonder_remove_shelf_species、wonder_purchase_shop_item、wonder_select_vase_pattern、wonder_sync_steps、wonder_enter_hibernate、wonder_exit_hibernate、wonder_update_settings、wonder_record_ui_event。

Service-only 1 个：wonder_start_verified_wander_internal。

### 6.3 Mutation 合约

- wonder_bootstrap 和 wonder_refresh_state 返回 full snapshot。
- 其他 state mutation 返回 request_id、base_revision、state_revision、replayed、delta。
- 相同 UUID + 相同 canonical payload 重放已存响应；相同 UUID + 不同 payload 返回 WW_IDEMPOTENCY_REUSED。
- 客户端只在 local revision 等于 base revision 时 apply delta；否则丢弃 delta 并且恰好 refresh 一次。
- cap、validation、identity、balance、terminal 错误不重试。仅 transport、429、5xx、lock、statement、serialization、deadlock 使用原 UUID 有界重试。

### 6.4 精确 V1 常量

| 合约 | 值 |
|---|---|
| Season/catalog | autumn / version 1 / Daisy + 12 Wander species / weight 100 |
| Duration | Daisy 86,400s；Wander flower 259,200s；session 3,600s |
| Tiers/cap | 10/20 分钟手选；30 分钟自动；owner-local-day cap 6 |
| Offline seed | SHA256(session_uuid + : + catalog_version + :autumn)，再按 SHA256(seed + : + slug) bytes 和 slug 排序取 3 |
| Pocket/vase/shelf | soft 12；vase capacities 1/2/3；shelf 6 |
| Shop | slot_2=600、slot_3=1800、classic_cream=0、meadow_dots=150、blue_vine=200 Glow |
| Sunshine | 20 Glow；displayed + living + non-Hibernate；+86,400s；可叠加 |
| Sale | 5 × max(1, ceil(remaining_seconds / 86400))；stale guard 要求重确认 |
| Steps | floor(max(health_high_water, fallback_high_water)/100)，只补正差额 |
| Apple Maps | Server API Search；Park/NationalPark/Hiking；返回后精确校验 805m；8s |
| Manual copy | I am walking in or near a park. |
| Cap copy | Daily flower limit reached. |
| Telemetry | 每 owner/server-UTC-day 最多 200，超出 accepted=false，不改 revision |
| DB timeouts | mutating RPC lock_timeout=2s；专用项目 authenticated/service_role statement_timeout=5s |
| Edge deletion | total 25s；Apple exchange/revoke 各 5s；仅 network/429/5xx 在 250ms + bounded jitter 后重试一次 |

### 6.5 Autumn-only 门禁

V1 保留 wonder_select_autumn_offers 和哈希输入 :autumn。任何新季节或权重变更必须带新 catalog version、兼容 App、版本化离线算法和新 Swift/server fixtures；禁止 server-only tuning。

## 7. 最小 iOS 结构

WanderWonders/App 保存 App entry、root navigation 和 GameStore。

WanderWonders/Core 保存 Models.swift、WonderClient.swift、WonderPersistence.swift、MutationQueue.swift、SystemServices.swift。

WanderWonders/Features 保存 Onboarding、Home、Pocket、Pressbook、Shop、Wander、Settings。

- GameStore 是唯一 @MainActor @Observable 产品状态 owner。
- WonderClient 是唯一 Supabase SDK 边界，不为每个 feature 建 repository。
- WonderPersistence 是唯一 SwiftData actor 边界，@Model 永不跨 actor。
- MutationQueue 每用户只允许一个权威请求 in flight；interactive 只在下一个 background operation 前优先，不抢占已发送请求。
- telemetry 使用 WonderClient 的 best-effort 方法绕过 queue，不创建专用 TelemetryClient 类。
- 不创建一对一 protocol/mock implementation；测试通过 closure-backed transport 或 URLProtocol 注入。

## 8. 顺序执行步骤

### Step 0 — 冻结旧副本并录取迁移基线

- 前置：none。
- 创建 docs/migration/old-project-inventory.md。
- 记录旧 git status、tracked/untracked、核心文件行数和排除路径；记录新仓库 pre-existing status。
- 清单必须写明 22 tables、24 RPC、19 private functions、85 declared assertions、44 app Swift LOC、0 Edge TS、0 art。
- 验证：完成前后旧目录 git status 完全不变。
- 失败：数字不符则停止复制并先修订计划。

> 2026-08-12 [codex done]：创建 docs/migration/old-project-inventory.md；直接计数为 22 tables、24 public RPC、18 domain private + 1 schema private = 19、85 declared assertions、44 app Swift LOC、0 Edge TS、0 production art。录取前后旧目录 git status 完全一致。

### Step 1 — 窄路径迁移并建立可恢复 Git 基线

- 前置：Step 0。
- 只复制 .gitignore、.swiftformat、.swiftlint.yml、Config、Content、Scripts、WanderWonders、WanderWondersTests、WanderWondersUITests、docs、package.json、Package.resolved、project.yml、supabase。
- 不覆盖新规格、README、进度文档和本计划。
- 将 .DS_Store、.build、generated project、Supabase runtime、真实 xcconfig 加入 ignore。
- 验证：核心源文件 cmp；排除路径为 0；secret pattern scan 无值；git diff --check。
- Git：验证通过后提交 migration baseline。

> 2026-08-12 [codex done]：仅复制了本步白名单路径；44 个旧新文件 `cmp` 一致，排除路径为 0，secret pattern scan 无命中，`git diff --check` 通过，旧目录 status 不变。已在 `codex/wander-v1-end-to-end` 提交可恢复基线 `2e4e99a`。

### Step 2 — 复验内容和 iOS scaffold

- 前置：Step 1 commit。
- 运行 catalog --check、manifest structure validation。
- 查看 Xcode/XcodeGen/Swift 当前版本；从 project.yml 生成项目。
- 运行 Debug/Release build、当前 unit 和 UI test。
- 验证：13/12/5/50 不变；Swift 6 strict concurrency；iOS 17；build/tests 绿。
- 失败：只修工具或生成配置，不顺手重构产品。

> 2026-08-13 [codex done]：catalog 当前校验为 13 active species / 12 Autumn offers / 5 shop items，manifest 结构校验为 50 sets。使用 Xcode 26.6、Swift 6.3.3、XcodeGen 2.45.4 生成工程，iOS 17 + Swift 6 complete concurrency 的 Debug/Release 均构建成功；iPhone 17 / iOS 26.5 上 unit + UI 为 2/2 通过。仅修正 Xcode 26 测试 MainActor 警告和已失效的默认 simulator destination，受影响测试重跑通过且无该警告。

### Step 3 — 重建当前 Supabase 证据

- 前置：Step 2。
- 用 --help 发现 CLI；确认无 project-ref。
- 只启动 wander_wonders_v1_local 的 55320–55329 栈，排除重服务。
- reset 两次；跑全部 pgTAP、lint、concurrency probe、role-timeout probe；停止栈。
- 验证：22 tables、24 RPC、19 private functions；85/85；lint 0 errors；并发恰好 1 success + 1 stale + 1 revision + 1 ledger；lock 为 55P03；两角色约 5s；临时 helper 为 0。
- 失败：停在本步修复，不进入 Edge/iOS。

> 2026-08-13 [codex done]：Supabase CLI 2.113.0，无 project-ref；仅启动 55320–55329 本地栈。迁移变更前后均完成两次 reset，最终 88/88 pgTAP 通过，lint 0 errors。并发为 1 success + 1 stale + revision 1 + ledger 1，lock timeout 为 55P03；authenticated/service_role 分别约 5.03s/5.01s，正常 RPC < 0.1s。测试临时函数、物种、用户均为 0，本地栈已停止。过程中发现 immutable trigger 阻断真实账户级联删除，已用 additive migration 修复并添加直接删除仍拒绝、owner 删除可级联的回归。

### Step 4 — 深审并修复活的 SQL 合约

- 前置：Step 3 全绿。
- 逐个检查 24 RPC 的 owner validation、canonical idempotency、lock order、revision、atomicity、errors、grants、empty search path、offline cap、online reservation、tier-30、expiry/sale/sunshine、steps、Hibernate、telemetry。
- 发现 bug 时用 Supabase CLI 新建 additive migration，不修改已迁移历史。
- 必加回归：two-client contested cap 6/5、protected reservations、duplicate UUID same/different payload、10→20→auto-30、60m close、sale reconfirm、Sunshine guards、telemetry 200/201 + concurrency、Hibernate lost response、steps 99/100/199/200。
- 验证：reset + existing + new tests 全绿，安全 inventory 不回退。

> 2026-08-13 [codex done]：完成 24 RPC/owner/lock/revision/idempotency/grant 深审，保持 22 tables + 24 public RPC，private helpers 因必要的 Auth trigger、daily Daisy helper 和隔离的 offline core 由 19 增至 22。用 additive migrations 修复：有历史数据的账户级联删除、Auth identity 自动建立游戏 owner、每日 Daisy/休眠期间不发/退出只发当日、自然凋谢 Pressbook 计数、60 分钟关闭保留已达 tiers、offline 日期/时长/顺序/重复选择 proof、sale reconfirm、Sunshine/Shop typed insufficient Glow、休眠后合法非休眠 steps、flower action 过期边界。最终 reset 后 139/139 pgTAP + lint 0 通过；对抗探针证明 cap 5→6 仅一个成功、另一个 stale，重试持久化 cap rejection，telemetry 并发精确停在 200。

### Step 5 — 实现两个 Edge Functions 和 mock 合约

- 前置：Step 4。真实 credential 不是 mock 前置。
- 创建 shared wonder helper、wonder-park-check、wonder-delete-account、co-located pure modules、tests、deno config。
- park：POST only；JWT + approved identity；lat/lng/accuracy bounds；坐标只在内存；一次 Nearby Search New；6 types、805m、1 result、places.types、8s；匹配后用 secret client 调 service-only RPC；只回 generic result。
- delete：POST + DELETE confirmation；fresh reauth；25s；Apple exchange/revoke 5s；只对 network/429/5xx 重试 revoke 一次；无论 revoke 如何都尝试 Auth Admin delete；验证 cascade；只 log stable fields。
- 测试：auth/input/provider/status/timeout/retry/deletion-right/replay/redaction。
- 验证：deno fmt --check、lint、test 和 secret/privacy scan；不远端 deploy。

> 2026-08-13 [codex done]：实现 `wonder-park-check`、`wonder-delete-account` 和无第三方依赖的 shared helpers；两个函数均保持 JWT 验证。park contract 精确锁定 6 types / 805m / 1 result / `places.types` / 8s，并只用 secret key 调 service-only RPC；delete contract 覆盖 fresh reauth、Apple exchange/revoke、受限重试、Auth Admin delete、cascade 和 replay。`deno fmt --check`、lint、两个 entrypoint check、13/13 tests 全通过；secret value 和坐标/token/code 日志扫描无命中，未执行远端 deploy。

### Step 6 — 实现最小 iOS 数据和 Auth 竖切

- 前置：Step 5。
- 锁定 supabase-swift 2.46.0；从 safe xcconfig 读 URL/publishable key。
- 创建 Models、WonderClient、GameStore；解码 snapshot/error/mutation envelope。
- 实现 session restore、Apple native ID-token、Google native ID-token、auth gate、explicit link approval/quarantine。
- UI phases：signed-out、loading local cache、loading server、onboarding、current、blocking error；延迟 cache 不闪空 Pocket。
- 测试：JSON fixtures、error/retry class、auth matrix、identity quarantine、delayed cache、secret absence。

> 2026-08-13 [codex done]：锁定 supabase-swift 2.46.0 和 GoogleSignIn-iOS 9.1.0；实现 Models、WonderClient、GameStore、safe xcconfig、native Apple/Google ID-token Auth、session restore、auth gate、identity quarantine，以及 local-cache/server 分阶段 loading。JSON/error/retry/auth/quarantine 单元门禁和 secret scan 通过；真实 provider 验证仍属于 Step 13–14。

### Step 7 — 实现 SwiftData 和单一 MutationQueue

- 前置：Step 6。
- 持久化 per-user snapshot、catalog/checksum、active/offline session、offers、tier choices、pending reversible operations、request/ack IDs、overflow dismissal、deletion quarantine。
- queue：先持久化后发送；每 user 一个 in-flight；interactive/background 各自 FIFO；取消、永久错误、重试耗尽后继续；sign-out 销毁 user queue。
- 不另建 SyncCoordinator；GameStore 读取 pending DTO，交给 queue，ack + delta/snapshot 原子写回。
- 测试：two taps、foreground/background race、response loss、force quit each state、user switch、corrupt snapshot、telemetry failure。

> 2026-08-13 [codex done]：实现 per-user SwiftData snapshot/pending/offline/deletion quarantine，以及单一串行 MutationQueue；保证 persist-before-send、interactive 优先且各自 FIFO、最多 3 次尝试、terminal/deferred 后继续、response-loss/force-quit 恢复、成功时 snapshot + ack 原子保存。generation cancellation 防止 sign-out drain 重建 cache；queue 顺序、重试、恢复、原子性、corrupt cache、sign-out 回归通过。

### Step 8 — Home/Pocket/Pressbook/Vase/Shop

- 前置：Step 7。
- Home：Daisy、Wander、Glow、step mode、Hibernate、loading/offline/error。
- Pocket：所有 living flower；server anchor 推导时间；Press/Sell/Sunshine confirmation。
- overflow：超过 12 后在下一次 Home/Pocket 温和提示，不阻塞；只在新日或 living count 上升后重现。
- vase/shelf：仅布局使用可回滚 optimistic overlay。
- Shop：仅五项精确 Glow price，无支付代码。
- 测试：overflow、capacity、pressed/sold、sale reconfirm、shop branches、VoiceOver、Dynamic Type、Reduce Motion。

> 2026-08-13 [codex done]：完成可操作的 Home、Pocket、Pressbook、vase 和五项固定价格 Shop；Press/Sell/Sunshine confirmation 走权威 RPC。overflow 提示可关闭，只在 living count 上升或 owner-local 次日重现，回归通过；capacity/press/sale reconfirm/shop/Sunshine 分支由当前 139 条 DB 门禁覆盖。UI 使用原生控件和 SF Symbols；50 套生产美术仍明确留在 Step 12–13。

### Step 9 — Resilient Wander

- 前置：Step 8。
- 支持 verified、manual server、online then offline、fully offline、fallback-step、time-only。
- process 内 monotonic clock；relaunch 用 server UTC；client clock 不解锁 tier。
- session/offers/operations 在显示 active/success 前持久化。
- 10→20→automatic 30；60m 结束；reached choice 不丢；signal loss 不重抽；offline projected cap 和逐 tier 结果。
- Core Location 只取一次合格坐标交 Edge，随后丢弃；notifications 不含敏感或 guilt copy。
- 测试：全部分钟边界、3/2/1/0 cap、force quit/background/midnight/time-zone/clock rollback、offer tamper/version/order、missing restore、exact copy。

> 2026-08-13 [codex done]：实现 verified/manual server、online→offline 和 fully-offline Wander；offline offer/choice 先持久化，SHA-256 顺序与 fixture 一致，断网奖励选择保持 deferred 并在后续 refresh 重放。在线 tier 使用 server anchor + process uptime，离线使用持久化 monotonic anchor，client wall clock 不解锁 10/20/30/60 边界；hash、timer、queue recovery 回归通过。真机 location/background/signal-loss 验收仍属于 Step 14。

### Step 10 — Steps/Glow/Hibernate

- 前置：Step 9。
- Health 只读 steps；HKStatistics options 恰好 cumulativeSum，不含 separateBySource；使用合并总数。
- today + prior six owner-local days；减 Hibernate intervals；任一 slice 失败则整天不提交。
- 只保留 nonnegative aggregate；不保留 samples/source/device/route。
- Core Motion 只统计 active Wander intervals；无 Motion 不影响时间奖励。
- Hibernate enter/exit 在线；服务端一次延长 deadlines；active 时禁 Wander/Daisy/Sunshine/step Glow。
- 测试：options、interval/DST、99/100/199/200、high-water、decrease/reinstall/double sync、response loss。

> 2026-08-13 [codex done]：HealthKit 只请求 steps，并仅使用 cumulativeSum；按 owner-local 今日和前六天切分，扣除 Hibernate interval，任一 slice 失败即不提交。active Wander 缺 Health 时使用 CMPedometer，Hibernate enter/exit 走在线权威 mutation。DST interval 单元回归通过；99/100/199/200、high-water、Hibernate 和 response-loss 由 DB/queue 门禁覆盖，真机 Health/Watch/Motion 留在 Step 14。

### Step 11 — Settings/Delete/Privacy/Accessibility

- 前置：Step 10。
- Settings：identities、permissions、notifications、Hibernate、privacy/support、sign out、delete。
- Delete UI：easy to find；fresh reauth；typed DELETE；success/manual_required/quarantine；删除后清 session、SwiftData、Keychain app values、notifications。
- 创建 PrivacyInfo.xcprivacy、privacy-data-map.md、account-deletion-runbook.md。
- OSLog redaction；typed event allowlist；无 arbitrary analytics dictionary。
- 完成 VoiceOver、large Dynamic Type、contrast、Reduce Motion、44pt。
- 测试全部 deletion/log/event/accessibility branches。

> 2026-08-13 [codex done]：Settings 展示 provider identity、permissions、notifications、Hibernate、privacy/support、sign out 和易发现的 delete。删除使用 typed DELETE + fresh reauth，success 清 session/SwiftData/app storage/notifications，manual_required 进入 quarantine；完成 PrivacyInfo.xcprivacy、data map、deletion runbook、typed events 和日志敏感值扫描。原生控件保留 VoiceOver/Dynamic Type/44pt 基础，13/13 Edge、13/13 iOS unit、1/1 UI smoke 通过；public URLs/provider/真机辅助功能仍属于 Step 13–14。

### Step 12 — 统一本地验证和发布预检

- 前置：Step 11。
- 创建 run_wonder_checks.sh、audit_wonder_schema.sql、local-release-report.md、dependency/license inventory。
- runner：DB/Edge/Swift tests、Debug/Release、schema/grant/RLS/FK/function/role audit、PostgREST probes、secret/privacy/season/payment/placeholder scans、50 art validation、archive dry run。
- 从 clean reset 完整跑两次。
- 生产 art、final signing 或 public URLs 缺失时可以 code-complete，但不得标本步 done。

> 2026-08-13 阻塞证据：最终 `run_wonder_checks.sh --code-only` 通过 content、Edge 13/13、Debug/Release、iOS unit 13/13、UI 1/1、plist 和扫描门禁；数据库在 iOS-only 改动前保持 reset + 139/139 + lint 0 + 对抗探针通过。真实文件 gate 以干净 exit 1 精确报告 50/50 production PNG 缺失，因此未跑 archive，也未把本步标为 done；没有用重复 full run 制造虚假绿灯。

> 2026-08-13 [codex done]：owner 确认 50 张 production art 与发布使用权后，修复两项只在完整门禁暴露的测试问题：洛杉矶当日 Daisy 断言的重复时区转换，以及 adversarial probe 对并发输家 session 的固定假设；同时用原生生成 Launch Screen 与四方向配置消除 archive 发布警告。随后将 50 张美术接入 Launch/Auth/Home/Pocket/Pressbook/Shop/Wander 和 App Icon，并以一个共享 UIKit loader 修复 loose bundle PNG 在 SwiftUI 中空白的根因；模拟器稳定截图、50/50 bundle load test 和 branded UI smoke 均确认真实渲染。代码变化后再次从停止状态独立执行两次 `run_wonder_checks.sh --full`，两次均通过 Edge 13/13、iOS unit 15/15、UI 1/1、clean reset + pgTAP 139/139、lint 0、22 table / 24 RPC / 22 helper / FORCE RLS 与撤权 audit、并发/对抗/role-timeout probes、50/50 实体美术检查和无签名 archive。

### Step 13 — Owner/provider/art readiness

- 可与 Step 2–11 并行，但在 Step 12 后闭合。
- 需要 final App ID/bundle/team/App Store record/TestFlight group、Apple Maps 与 Apple/Google Auth provider IDs、vault-backed secrets、public Privacy/Support URLs、review metadata、50 production art + rights。
- 只记录 safe identifiers/status，不记录 secret values。
- signed-out browser 验 URL 200；validator 检真实 art；owner 签认 data map、rights、metadata。
- 任一缺失则保持未完成，不伪造 placeholder 证据。

> 2026-08-15 readiness 进度：50/50 production art、两轮视觉验收、项目/发布使用权、accountable art owner（Judy — Product Owner / Final Art Approver）和 USD 0 additional-spend budget 均已确认。剩余 owner blocker 为 final App ID/bundle/team/App Store/TestFlight、Apple/Google provider identifiers 与 vault secrets、专用 Supabase project 确认、public Privacy/Support URLs、review/feedback contact 与 beta cohort metadata；本步保持未完成。

> 2026-08-17 项目变更：owner 明确改用新建专用项目 `qmsliloouxmybnfzzlks`（独立 Org `ilwcbtpsthckxclqqipz`），并授权该项目相关远端操作；旧项目 `aaajakflsjcwemcxjqhq` 不再作为本计划部署目标且保持不动。

> 2026-08-17 readiness 进度：专用 Supabase 已部署并通过远端 schema/security/事务冒烟，local ignored xcconfig 已接入新 URL/publishable key。实测发现旧 generated Info.plist 丢弃自定义字段、旧 UI smoke 只验证配置错误页；现改为 XcodeGen 明确生成 Info.plist，并让 1/1 UI smoke 验证真实 signed-out Auth surface，unified code-only gate 通过 Edge 13/13、iOS 15/15、UI 1/1、Debug/Release。Google Cloud 项目 `wander-wonders-v1-2026` 已创建。owner 仍需 final bundle/team、Google billing、公开 contact/URLs 和 Apple 登录/密钥动作，因此本步不标记完成。

> 2026-08-17 provider 变更：owner 批准将收费的 Google Places 替换为 Apple Maps Server API。实现保留 Core Location、805m、manual fallback、服务端验证和 service-role RPC 边界；Google Cloud 仅继续承担 Google Auth OAuth，不再需要 Places 或 Maps billing。Apple Maps ID/Key 与真机验证仍属于 owner/physical gate，因此本步不标记完成。

> 2026-08-17 provider 实施证据：复用现有无依赖 ES256 签名器完成 Apple Maps auth-token/access-token/Search 流程，类别限定 Park/NationalPark/Hiking，provider 结果返回后再做 805m haversine 校验；精确 provider/距离测试与统一 code-only gate 通过 Edge 15/15、iOS 15/15、UI 1/1、Debug/Release。`wonder-park-check` 已部署为远端 v2 且匿名 401；Apple Maps secrets 与真机公园查询仍待 owner 完成，因此本步不标记完成。

> 2026-08-17 Apple Maps credential 证据：Team `ALF5X476P3`、Maps ID `maps.com.judy.wanderwonders`、Key ID `TT8D4RTNUU` 已建立；下载的 PKCS#8 key 通过 OpenSSL 校验，三个自定义 secret 已写入 `qmsliloouxmybnfzzlks` 并由远端摘要清单确认。项目同一套签名与 Search 代码完成真实 Apple access-token 请求，并在 Golden Gate Park 坐标返回 `nearbyPark=true`；secret/token 未进入 Git 或日志。首把未保存私钥的 Key `6S2B527TY9` 待 owner 明确确认后撤销。Apple/Google Auth、公开 URL/review contact、App Store/TestFlight 和真机验收仍未完成，因此本步不标记完成。

> 2026-08-17 Apple/App Store readiness 证据：注册 App ID `com.judy.wanderwonders`（Team `ALF5X476P3`，Sign in with Apple + HealthKit），把 Key `TT8D4RTNUU` 限定为 Maps + Sign in with Apple，并撤销未保存私钥的旧 Key `6S2B527TY9`。Supabase Apple provider 已为 native client ID 启用，account-revocation 的四项 Edge secret 已存在。App Store Connect app `6802547488` 与 `Wander Wonders Internal` 内测组已建立，自动分发开启，beta 描述与 feedback address 已保存；当前 0 build / 0 tester。XcodeGen source-of-truth 已锁定 final bundle、Team、automatic signing 与 Apple/HealthKit entitlements；模拟器 Debug 与 `-allowProvisioningUpdates` generic-iPhone Debug build 均通过，后者经沙箱外 `codesign --verify --deep --strict` 确认有效，签名 entitlement 为 Team `ALF5X476P3`、bundle `com.judy.wanderwonders`、Sign in with Apple + HealthKit。Google Auth 停在 owner 必须亲自接受的 Google API Services User Data Policy，public Privacy/Support URL、完整 review contact、真机/archive/soak 仍缺，因此本步不标记完成。

> 2026-08-18 Google/TestFlight readiness 证据：owner 接受 Google 用户数据条款后，建立专用 iOS 与 Web OAuth client；Supabase Google provider 以 Web-first + iOS client IDs、Web secret、Skip nonce=true、allow-without-email=false 启用，公开 Auth settings 返回 Apple=true、Google=true。ignored `Config/Secrets.xcconfig` 已写入 iOS/server/reversed client IDs，client secret 未进入 App/Git；signed generic-iPhone Debug build 通过且最终 Info.plist 三项值精确匹配。Google OAuth audience 仍为 External/Testing 且 0 test users，因此真实 Google 登录未验证。owner 同时锁定只做 TestFlight 分享、不公开上架或销售；现有 App Store Connect record 仅作为 TestFlight 基础设施。public Privacy/Support URL、完整 review contact、Google test user、真机/archive/soak 仍缺，本步不标记完成。

### Step 14 — 授权远端、真机、TestFlight 和 beta

- 前置：Step 12 + 13，以及每个外部 mutation 的明确授权。
- Phase A 只读：重查 docs/changelog；remote ref、专用性、migrations、functions、grants、RLS、rolconfig、schemas、extensions、providers、advisors、backups、limits；记录两角色原 rolconfig 和回滚 SQL。
- Stop：共享项目迹象、collision、无回滚值、未解决 advisor、需要大于 5s 的管理操作却无安全 session 路径。
- Phase B：备份/回滚准备；apply migrations + catalog；配 providers/secrets；deploy Edge；核对 22 tables / 24 public RPCs / 22 additive private helpers、RLS/grants/FK/timeouts/advisors；两个 disposable accounts 测 security/cap/telemetry/delete。
- Phase C：archive exact commit；保留 xcarchive/dSYM；internal TestFlight；真 iPhone 测 Auth、location/manual、signal loss、force quit、Wander、Pocket/lifecycle/shop、steps/Hibernate、delete、VoiceOver、reinstall。
- Phase D：至少 24h internal smoke；检查 TestFlight feedback + Organizer；repeatable core crash 阻塞；授权后提交 TestFlight App Review。
- Phase E：build 获批后邀请 30–50 位成人，只记录数量/cohort。
- Rollback：stop testing；disable 最小 entry；restore Edge/app；DB forward repair；restore rolconfig；reload PostgREST；rotate secret；重跑受影响门禁。

> 2026-08-13 authorization blocker：未收到远端 Supabase mutation/deploy、provider 配置、build upload/review/invite 的逐项授权，也没有物理 iPhone、24h soak 或 TestFlight 证据；本步保持未完成。

> 2026-08-17 Phase A/B 进度：新专用项目从空基线应用 10 migrations + catalog，部署两个 verify-JWT Edge Functions；远端确认 22 tables / 24 RPC / 22 helpers、FORCE RLS、零客户端表授权、两角色 5s、13 species / 5 shop items、Edge 未认证 401，rollback-only bootstrap/manual/replay/refresh 冒烟通过；Security Advisor 无 error、Performance 0/0。Apple/Google provider secrets、真机、TestFlight、24h soak/review/beta 尚未完成，本步不标记完成。

## 9. 文件清单

| 路径 | 动作 |
|---|---|
| .gitignore | 修改排除 macOS/build/generated/Supabase runtime/secret config |
| Config、project.yml、Package.resolved | 迁移并锁定依赖 |
| Content/*.json | 迁移 catalog、fixtures、asset contract |
| supabase/migrations | 迁移；发现 bug 时只加 migration |
| supabase/tests/database | 迁移并扩展对抗回归 |
| supabase/functions | 新建 park/delete 和 tests |
| WanderWonders/App | 迁移后重写 App root/GameStore |
| WanderWonders/Core | 新建四个核心边界和 models/system services |
| WanderWonders/Features | 新建 V1 UI |
| WanderWonders/Resources/PrivacyInfo.xcprivacy | 新建 |
| tests 和 Scripts | 扩展 contract/unit/UI/runner |
| docs/migration、docs/evidence、privacy/delete/deploy/rollback/TestFlight | 新建或更新 |

## 10. 错误、并发、隐私和观测

- Stable error codes 至少包括 WW_AUTH_REQUIRED、WW_IDENTITY_NOT_APPROVED、WW_REQUIRES_CONNECTION、WW_STALE_REVISION、WW_IDEMPOTENCY_REUSED、WW_DAILY_FLOWER_CAP、WW_INSUFFICIENT_GLOW、WW_FLOWER_EXPIRED、WW_SALE_VALUE_CHANGED、WW_HIBERNATING、WW_LOCK_TIMEOUT、WW_STATEMENT_TIMEOUT、WW_UNSUPPORTED_SEASON、WW_CATALOG_MISMATCH、WW_CATALOG_CORRUPT。
- DB 使用固定锁顺序，idempotency response 与状态同事务。
- iOS 每 user 权威请求串行；telemetry 唯一绕 queue；step sync 改 Glow，必须排队和 revisioned。
- 单设备两个快点导致 mismatch 是 release blocker；多设备 stale 是正常冲突。
- Product events 仅 onboarding_completed、daily_daisy_granted、wander_started、wander_tier_resolved、wander_tier_cap_rejected、flower_action_completed、shop_purchase_completed、hibernate_changed、refresh_after_revision_mismatch。
- Edge log 只含 request ID、stable outcome/operation、attempt count、duration bucket/support code。
- 不宣称“无 crash”，只记录实际窗口、build 和数据源。

## 11. 测试矩阵

- Database：schema/RLS/grants/ownership/FK/cascade/immutability/idempotency/revision/lock/cap/offline/online offers/lifecycle/shop/steps/Hibernate/telemetry/timeouts。
- Edge：auth/input/rate/Apple Maps request exactness/805m/provider outcomes/timeout/no persistence/Apple revoke/delete right/cascade/replay/redaction。
- Swift：JSON、retry、delta/replay/revision、queue、persistence recovery、timer、offline hash/cap、sale/Glow/steps/Hibernate math。
- UI/simulator：onboarding/loading/Auth quarantine/Home/Pocket/Shop/Pressbook/Wander/Settings/delete/offline disabled/accessibility/exact copy/no non-Autumn/payment。
- Physical：provider sign-in、location/Apple Maps、Health/Watch/Motion、background/force quit、signal loss、Apple revoke、TestFlight、touch VoiceOver。

## 12. 执行检查表

- [x] Step 0 — 旧副本冻结和录取完成。[codex done]
- [x] Step 1 — 窄迁移、排除验证和 Git 基线完成。[codex done]
- [x] Step 2 — catalog/manifest/iOS scaffold 当前验证完成。[codex done]
- [x] Step 3 — 两次 reset、85+ DB tests、lint/concurrency/timeouts 当前通过。[codex done]
- [x] Step 4 — SQL 深审和对抗回归完成。[codex done]
- [x] Step 5 — Edge Functions/mock tests/privacy scan 完成。[codex done]
- [x] Step 6 — iOS models/client/Auth/loading vertical slice 完成。[codex done]
- [x] Step 7 — SwiftData/MutationQueue/sync/recovery 完成。[codex done]
- [x] Step 8 — Home/Pocket/Pressbook/Vase/Shop 完成。[codex done]
- [x] Step 9 — resilient Wander 完成，模拟器门禁通过。[codex done]
- [x] Step 10 — Steps/Glow/Hibernate 完成，非真机门禁通过。[codex done]
- [x] Step 11 — Settings/Delete/Privacy/Accessibility 完成。[codex done]
- [x] Step 12 — unified runner 从 clean reset 完整通过两次。[codex done]
- [ ] Step 13 — owner/provider/public URL/review metadata 通过；50 art/rights 已验收。
- [ ] Step 14 — authorized remote + physical + soak + TestFlight review + beta 完成。

## 13. Definition of done

- Step 0–14 全有 [codex done] 和证据，不用本地结果替代远端、真机或 TestFlight。
- 旧目录未被修改，新仓库可从 Git 恢复。
- 22 tables、24 public RPC、22 additive private helpers、RLS/grants/FK/timeouts 一致；19 是迁移前基线，不是最终门禁。
- 断网、response loss、duplicate tap、multi-device cap、force quit 不产生重复、负数或越权状态。
- App 完成规格第 26 章 10 类验收，保持 Autumn-only、free、no-payment。
- 50 production assets、privacy、deletion、accessibility、archive/dSYM 全验证。
- 远端专用性、rolconfig/rollback、advisors、smoke 通过；TestFlight review 批准后才邀请 beta。

## 14. 执行模型交接

从头到尾读完本文并将本文作为唯一执行记录。每步前检查 Git status；只在该步代码、测试、安全和证据全通过后把 checkbox 改为 [x] 并追加 [codex done] 与简短命令结果。旧项目只读。优先复用已迁移 SQL、catalog、scripts 和 tests。iOS 仅使用 GameStore、WonderClient、WonderPersistence、MutationQueue 四个核心边界，不新增一对一 protocol/repository/service/coordinator。不得简化输入验证、owner authorization、RLS/grants、幂等、revision、离线持久化、删除、隐私或可访问性。任何远端修改、provider/secret 配置、build upload/review/invite 都在操作当下要求明确授权。现实与计划冲突时停在该步，记录证据，不自行改变产品、安全或部署决策。
