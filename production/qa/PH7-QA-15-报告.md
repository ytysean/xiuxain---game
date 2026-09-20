# PH7-QA-15 · 报告（门0复算 A ＋ GO3复验预案 B ＋ 归零路径 C ＋ 日志清单 D）

> **轮次**：PH7-QA-15 ｜ **执行**：quality-lead-2（严守真）｜ **性质**：A 已跑（只读）／B·C 只写不跑／D 仅登记
> **纪律**：A 之外未启动 Godot；未碰任何 `.gd`/`.csv`；闸门运行期未写 `.workbuddy/`
> **产物**：`production/qa/qa15_gate0_recount.py`(+`_qa15_gate0_recount.txt`) ／ `qa15_go3_verify.py` ／ `qa15_placeholder_x06.py` ／ 本文件

---

## §A · 门0 扫描范围【独立复算】—— PASS

**方法**：自建 `os.walk` ＋ 自写 before/after 判据（**不复用**门0函数）＋ 再用 `importlib` 加载门0真实 `is_skipped()` **三方交叉校验**。脚本 `production/qa/qa15_gate0_recount.py`，输出 `_qa15_gate0_recount.txt`。

### A1 修前 → 修后对照

| 读数 | 修前（`go3_gate0_before_fix.txt`） | 修后（`go3_gate0_after_fix.txt`） | 我的独立复算 | 判 |
|---|---|---|---|---|
| 门0 `.gd` 扫描范围 | **473** | **261** | before=**473** / after=**261** / 门0真实=`**261**`** | ✅ 三方一致 |
| `config/*.csv` | 132 | 132 | 132（不变） | ✅ |
| 门0 判定 `[A][B][C][E]` | 全 0 / PASS | 全 0 / PASS | — | ✅ |

### A2 三问逐一作答（独立证据）

1. **修后 `.gd` 是否回落 268 量级？** → **回落成功，但精确值是 `261`，不是 268。**
   - **`261` = 门0口径**（`SKIP_DIRS` 含 `addons` ⇒ 剔除 addons）；**`268` = 门1口径**（门1 `**/*.gd` glob **不**剔 `addons`）。
   - **261 ＋ addons 7 = 268** ⇒ 你的校核式 `473 = 268 + 212 − 7` **成立且自洽**：其中 `268` 是门1含 addons 的净数，`−7` 正是门0 又剔掉的 addons。**建议口径订正为**：`门0: 473 → 261`；`门1: 268（不变）`；`261 + 7 = 268`。
2. **212 个 scratch `.gd` 是否真被排除？** → **是。** 实测被新排除文件 **212 个，全部 ∈ `.scratch_backup/`**（命中数 212）。
3. **是否产生连带翻转？** → **无。** 证据三条：
   - 被新排除的 212 个中，**非 `.scratch_backup` 者 = 0**；
   - **嵌套 `.workbuddy` 命中（非顶层）= 0**（改后 `SKIP_PATH_PARTS` 按任意路径层匹配，未误伤任何产品文件）；
   - 其余门覆盖数（门1 `268`、门3 `268`、门5 `261`、门6 `261`）与 GO1/GO2 **一致**（工程线 `GO3_report.md §4` 亦报同结论）。

### A3 口径分布（自证无隐藏改动）

```
全仓 .gd（已剪 SKIP_DIRS）= 527
  261 计入 = (root)84 + tests84 + ui83 + components8 + tools1 + vfx1
  212 排除 = .scratch_backup/**
   54 排除 = .workbuddy/**
  (addons 7 于 SKIP_DIRS 剪枝阶段即剔除，两门均不计入 527)
527 − 212(scratch) − 54(.workbuddy) = 261 ✓
```

### A4 残留口径不齐（登记，非缺陷）
修后 `门0/门5/门6 = 261`，`门1 = 268`，**差 7 = `addons/taixuan_ui_editor/*.gd`**。此为**门0 与门1 的既有设计差异**（门0 剔 `addons`、门1 不剔），**非本次修复引入**。是否统一门1 口径（+`addons` 进其跳过集）属**工程线**，交其裁。

**§A 判定：PASS。**

---

## §B · GO3 11 站独立复验【预案 · 写而不跑】

**脚本**：`production/qa/qa15_go3_verify.py`（待你「关闸」信号后跑：`python production/qa/qa15_go3_verify.py --out <utf8.txt>`）

**数据来源（硬口径）**：改前快照 `.workbuddy/_ph7go3/snapshot_before/` ＋ GO2 冻结基线 `_baseline_current.json`（tag `GO2后`）＋ 期望改动表 `GO3_expected_changes.tsv`。

| 断言组 | 覆盖 | 期望 |
|---|---|---|
| **① 11 站双向** | F1 7 站（`main.gd` 832/1113/2220/2938/3069/3126 ＋ `page_disciple.gd:551`）＋ B-20 4 行（`game_state.gd` 15739/15740/15742/15744） | 每站「**原串全文件残留=0**」＋「**该行含新串**」；另全仓 `.gd` 「开启测灵大典」文件数 **=0** |
| **② 字节账** | `main.gd` / `ui/page_disciple.gd` / `game_state.gd` | Δsize = **+0 / +0 / +12**；ΔLF 全 **0**；**CR=0 / BOM=False**；与 GO2 基线交叉 LF 不变 |
| **③ 反向断言（4 组）** | **R1** `main.gd:832` 同行 `招.name="Button_开启接引大典"`（＋全 main.gd 计数 **=4**）；**R2** `game_state.gd` 15738/15741/15743/15745 四行逐字未变；**R3** `ui/page_storage.gd` 整文 md5 = `e37e23aa…`（QA-13 继承）；**R4/R4′ 跨批污染守卫**（见下） | R1–R3「一字节未变」；R4/R4′ 口径=**零 UNEXPECTED** |

> **R4 / R4′ 明细（收窄版 · 以 team-lead 裁定 2 为准）**
> - **R4 = GO2 落盘那 `9` 个文件**（非 2 个）：`ui/page_building.gd`／`ui/page_global_auction.gd`／`ui/page_sect_manager.gd`／`ui/page_shop.gd`／`dynasty_system.gd`／`config/dynasty_counter_config.csv`／`config/auction_ai_config.csv`／**`main.gd`／`game_state.gd`（此二者取 GO3-after，非 GO2-after）**；另**并入 GO3 落盘件 `ui/page_disciple.gd`**（供 GO7/GO8 守卫）。
> - **R4′ = `ui/page_explore.gd`「GO7∪GO8 落盘前冻结基线」= `1d6f0cd7…`（71704 B）**，**与 GO2 无关**。
> - **★ 断言口径（关键）**：R4/R4′ **不要求「必须不变」**，要求 **「若变，则必须在 GO7/GO8 的 `expected_changes.tsv` 内有据」**——有据⇒合法放行；**无据⇒越权⇒FAIL 停批**。价值 = **零 UNEXPECTED**，而非零变化（GO7 本就要动 `page_sect_manager`/`page_building`、GO8 动 `game_ui.gd`）。
> - **★ 排程坑（已在脚本内规避）**：GO2 与 GO3 都改 `game_state.gd`/`main.gd` ⇒ **GO3 后值 ≠ GO2 后值**；脚本对这两行取 **GO3-after**，否则关闸后必假 FAIL。
> - **✅ 盘上预核**：11 件基线全部与盘上现值逐字节一致（`MISMATCH=0`，dry 校验）。

> **★ 数据完整性订正（我核出、已按权威值实现）**：team-lead 冻结表有 2 处须订正 ——
> ① `main.gd` 冻结 md5 写作 `dd440880fb006660f7fee32a45c5e5632`（**33 字符**，多一个 `6`）；**权威值 = `dd440880fb00660f7fee32a45c5e5632`（32 字符）**（源 `GO3_final_stats.txt` ＋我盘上复核）。
> ② `dynasty_system.gd` 写作 `ui/dynasty_system.gd`；**实际位于仓库根 `dynasty_system.gd`**（`ui/` 下无此件）。
> 脚本已按**订正后**值实现（见 `qa15_go3_verify.py` 内注释）。

> **B 不跑**：战斗红线（`tests/combat/test_combat.py`，期望 93/0、文件 md5 `109f229612b6c15be524a640061e3440`／21063B／LF394／CR0）、门0–6 全门，均**留给关闸后**按你时序执行。

---

## §C · `page_placeholder` 归零路径 ＋ X06 修后回归判据【写而不跑】

**脚本**：`production/qa/qa15_placeholder_x06.py`

### C1 归零路径（回答你的三问）

| 问 | 答（实读证据） |
|---|---|
| ① **谁引用** | **仅 1 处**：`ui/game_ui.gd:24` `const PagePlaceholderScene: PackedScene = preload("res://ui/page_placeholder.tscn")`。全仓 live `.gd` 再无第二处（`.bak*` 不计）。另 `ui/page_placeholder.tscn:3` 引用自身脚本（随文件存亡）。 |
| ② **preload 常量有无被兜底消费** | **无（零消费）**。`_on_首页入口` 兜底是 `ENTRY_SUB_PAGES.get(entry_id, **null**)`（`game_ui.gd:863`）＋ 尾部 `_toast("【%s】系统即将开放")`（`:875`）—— **不引用 `PagePlaceholderScene`**；`_show_sub_page(id, scene)` 的场景由调用方传入、**无默认占位**。 |
| ③ **删除要动哪几行** | `del ui/page_placeholder.gd`；`del ui/page_placeholder.tscn`；`del ui/game_ui.gd:24`（const 声明）。**无需改 `ENTRY_SUB_PAGES`**（无条目指向它）。**连带销项**：术语表 P3「系统即将开放，敬请期待」(`page_placeholder.gd:57`)。 |

**结论**：技术上**零依赖、可安全删除**（前置核证脚本 C1–C4 全 PASS 才建议执行）。**本阶段维持「不删」**——按 team-lead 裁定 4：**不并入 P0-4**（`game_ui.gd` 正是 P0-4 波4 与 P0-A `:1316` 都要动的同一文件，混入只会抢文件/增返工）；**降为「发布前清理批（GO-LAST）」成员**，与 21 处开发态日志清理 ＋ `GO3_B_review` 的 `_toast` 占位族**同批**，**执行时机 = F5 验收通过后、出包前**。

### C2 X06 修后回归判据（修完一键复算）

| 判据 | 内容 |
|---|---|
| **X1** | `_open_offline_manager_page` **产品 code 调用点 ≥ 1**（排除 `func` 定义行、排除 `print("…被调用")` 自日志、排除 `tests/`）。**现状 PENDING（=0）**，修完应翻真。 |
| **X2** | 3 处 harness 直达字符串**保持不变**：`tests/ui_full_accept.gd:139`、`tests/_t_btnsweep.gd:116`、`tests/_t_deadkey.gd:117`。 |
| **X3** | 入口接线落点 `ui/game_ui.gd:~1316`（闭关设置分发）**已改真调用** `_open_offline_manager_page()`（现状仍为占位 toast ⇒ PENDING）。 |
| 复算 | `page_offline_manager.gd` 应从「仅 harness」升「可达」（复用 `audit_entry_reachability.py`）。 |

> 我复核现状：`game_ui.gd:1316` **仍为** `_toast("【闭关设置】系统即将开放")` ⇒ X06 **尚未修**，与 QA-14 审计「孤儿=1」一致。

---

## §D · 开发态日志清理清单（登记 · 不落盘 · 交设计线 F10 族）

**对象**：`ui/game_ui.gd` 的 `print(...)` 开发态日志。**只登记 + 移交，未自行改。**
**★ 登记口径（team-lead 裁定 3）= `21 处`**（全 `[GameUI]` 追踪日志、**剔 `_toast` 回显**）＝ D1(10) ＋ D2(11)。理由：清理目的是**发布前去噪音**，companion「已打开/已隐藏」同为噪音，只登记 10 处会漏一半。

### D1 主登记：`print("[GameUI] _open_* 被调用")` —— **10 处**（纯开发追踪标记）

| # | file:行 | 内容 |
|---|---|---|
| 1 | `ui/game_ui.gd:1077` | `_open_master_detail 被调用` |
| 2 | `ui/game_ui.gd:1101` | `_open_message_center 被调用` |
| 3 | `ui/game_ui.gd:1129` | `_open_chat_page 被调用` |
| 4 | `ui/game_ui.gd:1157` | `_open_player_trade_page 被调用` |
| 5 | `ui/game_ui.gd:1185` | `_open_world_map_page 被调用` |
| 6 | `ui/game_ui.gd:1213` | `_open_offline_manager_page 被调用` |
| 7 | `ui/game_ui.gd:1241` | `_open_disciple_detail 被调用` |
| 8 | `ui/game_ui.gd:1267` | `_open_skin_shop 被调用` |
| 9 | `ui/game_ui.gd:1273` | `_open_master_skin_shop 被调用` |
| 10 | `ui/game_ui.gd:1279` | `_open_faction_quest_shop 被调用` |

### D2 附登记：companion「已打开/已隐藏」状态打印 —— **11 处**
`:1093 已隐藏 _sub_top_bg` ／ `:1097 宗主详情页已打开` ／ `:1125 消息中心已打开` ／ `:1153 宗门频道已打开` ／ `:1181 商队交易已打开` ／ `:1209 世界大地图（可视化）已打开` ／ `:1237 闭关嘱托已打开` ／ `:1263 弟子详情页已打开` ／ `:1269 仙衣阁皮肤商店页已打开` ／ `:1275 宗主皮肤商店页已打开` ／ `:1289 阵营任务和商店页面已打开`

### D3 ★ 慎动（**不在清理范围**）：`ui/game_ui.gd:1299` `print("[GameUI] %s" % text)`（位于 `_toast`）
`:1298` 注释**明示**「**保留 print：验收探针与人工排查都依赖日志里的 `[GameUI]` 断言**」—— **有意保留，禁扫**。

### D4 ★ 计数订正（重要）
- 你 QA-15 D 写「**13 处** `print("[GUI]…被调用")`」。**实测不符**：
  - `print("[GameUI] _open_* 被调用")` = **10 处**（上 D1；亦与你 QA-14 回执里点名的 10 个行号**逐一吻合**）；
  - 全 `print("[GameUI] …")`（含 companion ＋ `_toast` 回显）= **22 处**；
  - `_open_*` 方法共 **12 个**，其中 **`_open_全服拍卖`(`:958`)、`_open_雅趣`(`:964`) 无该标记**（故「13 个 `_open_*` 首行全是 print」中的计数与「全是」均不成立）。
- **请裁**：登记口径取 **D1（10 处·纯标记）** 还是 **D1+D2（21 处·全 `[GameUI]` 追踪日志，剔 `_toast`）**？

### D5 QA 卫生关联（供门3 派生断言）
D1 这 10 个「自日志」标记，**正是你 v2 探针被「凑出假调用点」的元凶**（每个开工器 def 下一行即一个假 caller）。⇒ **门3 派生断言①（孤儿判定）必须内建「剔除 `print("…被调用")` 自日志串」**，否则判据自身恒假。此与 QA-14 反向自检铁律同源。

---

## §E · team-lead 裁定回收 + 遗留待办

**裁定已回收（本报告已按此修订）**：
1. **A**：门1 口径**不与门0 对齐** → 改「**口径具名化**」（门0 打印 `261(剔 addons)`／门1 打印 `268(含 addons)` 并注「差 7 = addons，设计差异非漂移」）。→ **工程线执行**，我已在 `PH7-口径说明与漂移自查.md §三` 落定要求。
2. **B**：接受 **R3**；**追加 R4**（跨批污染守卫）→ 已并入 `qa15_go3_verify.py`（R1/R2/R3/R4 四组齐备）。
3. **D**：登记口径 = **21 处**（剔 `_toast` 回显），已更新 §D。
4. **C**：`page_placeholder` 归零**不授权 P0-4**，降为 **GO-LAST 发布前清理批**，已更新 §C。

**遗留待办 / 新开**：
- **✔ 已裁（裁定 2 收窄）**：`ui/page_explore.gd` 确**非** GO2 落盘；team-lead 采纳 (b) 并**新立 R4′**（=「GO7∪GO8 落盘前冻结基线」`1d6f0cd7…`，与 GO2 无关）；**R4 收窄为 GO2 那 9 文件**；口径改为 **「零 UNEXPECTED」（变则须有据）**。已在 `qa15_go3_verify.py` ＋ §B 全面落实。
- **★ 我核出 2 处 team-lead 冻结表笔误**（均已按**权威值**实现、并盘上预核 `MISMATCH=0`）：① `main.gd` 冻结 md5 写成 **33 字符**（多一个 `6`；权威 32 字符 = `dd440880fb00660f7fee32a45c5e5632`）；② `dynasty_system.gd` 路径写成 `ui/dynasty_system.gd`（实际在**仓库根**）。
- **工程线待办**：门0/门1 输出加「口径具名化」行；`scan_player_text.py` 的 `UI_SINK` 增 `_toast\(`（见关联发现）。
- **GO-LAST 清单**：`page_placeholder` 归零 ＋ 21 处日志清理 ＋ `_toast` 占位族。

**关联发现（转呈）**：工程线 `GO3_B_review.md` 报「扫描器缺口 —— `scan_player_text.py` 的 `UI_SINK` 未含 `_toast` ⇒ 4 站被降级 A2、实为玩家可见」。**这是「检查器自身匹配口径也是一类扫描盲区」的又一实例**，已并入新建的 `production/qa/PH7-口径说明与漂移自查.md §四`（与 QA-14 反向自检铁律、§D QA 卫生同族）。

**新增产物**：`production/qa/PH7-口径说明与漂移自查.md`（team-lead 要求的口径说明 ＋ 已登记 9 条口径差目录 ＋ 检查器自检铁则）。

**纪律声明**：本轮未启动 Godot、未碰任何 `.gd`/`.csv`、未在闸门运行期写 `.workbuddy/`；A 的复算只读；B/C 脚本仅写未跑；临时探针文件已清理。
