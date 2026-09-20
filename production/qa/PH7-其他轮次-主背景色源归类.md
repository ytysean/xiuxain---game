# PH7 · 「其他」轮次靶子表 —— 逐页主背景色源归类（只读 · v2）

- **产出**：quality-lead-2（严守真）｜ task PH7-QA-20（team-lead 任务B）｜ **v2 修订**（依 team-lead 第二轮指令：把 `make_scene_background` 机制**推广核验到其余页**，并修正 v1 误判）
- **性质**：**只读**。未改任何 `.gd`/`.csv`。全部 `file:line` 为盘上回盘（本轮**复核**，非沿用 v1）。
- **对象**：老大页序「首页→弟子→殿阁→坊市→灵钓→灵兽→**其他**」之「其他」轮次 = `PH7-P0A-21页未变清单.md` 的 **21 页**。
- **口径**：属 **P0-4 换肤**范畴的**只登记、不建议本批修**（team-lead 明示）。
- **页→承载脚本**依据：`ui/game_ui.gd:92-147 ENTRY_SUB_PAGES`（权威路由）。**禁按文件名推**。

---

## 0. 一句话结论（v2）

**机制线索（team-lead 给出，本轮已推广核验到全部 21 页）**：

> 「其他」轮次的"未变"**主因 = 色源分叉**：主底走了 `UITheme.make_scene_background()`（`ui/page_building.gd:165`），其全屏底 = **`SECONDARY_CONTENT_BG`**（`ui_theme.gd:1359`，`Color(0.039,0.071,0.086)` = **`#0A1216`**，**硬编码字面量、不在 P0-A 的 26 行三层 token 内**）⇒ **批2（只改 `MAT_*` 等 26 行）结构上够不着** ⇒ 主背景**逐像素未变**。

**两条并行"页面底色"色源（本轮新增的机制发现）**：

| 色源 | 定义 | 是否 P0-A 26 行内 | 谁在用 |
|---|---|---|---|
| `获取页面底色()` → `_取语义色("bg.page", MAT_BASE_TOP, true)` | `ui_theme.gd:1504-1505` → `MAT_BASE_TOP`（`:1470`） | **在**（批2 已改） | `game_ui.gd:224 _sub_bg`（未自建底页）、`sect_home_page.gd:248` |
| **`SECONDARY_CONTENT_BG`** | `ui_theme.gd:1359`，**直书 `Color(0.039,0.071,0.086)`** | **不在**（批2 未触及） | `make_scene_background()`（**33 个 `.gd`**）＋ `master_detail_page.gd:112` |

⇒ 走工厂的页**绕开 token 体系**，所以 P0-A 全批改完，它们的主底**一个像素都没动**。**这才是它们出现在「21 页未变」里的真因。**

**21 页按主背景色源分四类**：

- **A 类 · 自建全屏底 + **硬编码 `Color(` 字面量**（7 页）** ⇒ **真·「其他」轮次靶子**。
- **D 类 · 自建底走共享工厂 `make_scene_background()` ⇒ `SECONDARY_CONTENT_BG`（`:1359`，硬编码、不在 26 行）（7 页）** ⇒ **靶子（换肤够不着）**。
- **B 类 · 自建底走 `ui_theme` **非 26 行 token**（直接引用）（1 页）** ⇒ 靶子。
- **C 类 · 未自建全屏底 ⇒ 共享 `game_ui.gd:224 _sub_bg`（= 26 行内 `:1470`）（6 页）** ⇒ 其"未变"是 **harness direct-call 盲区**，**不是硬编码债**。

⇒ **「其他」轮次真靶子 = A 类 7 ＋ D 类 7 ＋ B 类 1 = 15 页**；C 类 6 页**无需本批改**（建议实机复核确认，见 §5）。

---

## 1. 靶子表（21 页 × 5 列）

> `站数` = `design/10-上线冲刺优化/P0-4换肤分批方案.md §1` 的硬编码 Color 站点数（该页**全页**，非仅背景）。`—` = 未列入 P0-4 §1。

| 页id | 承载脚本 `file:line` | 主背景构造方式 | 站数 | 建议修法 |
|---|---|---|---:|---|
| **A 类 · 自建全屏底 + 硬编码 `Color(` 字面量** | | | | |
| `S01_丹方` | `ui/page_pill_formula.gd:58`（`_bg.color = C_BG_TOP`）← `:8 const C_BG_TOP = Color(0.106,0.153,0.169)` | **硬编码 `Color(`**（本地 const → 全屏 `_bg`） | 11 | 归 **P0-4**（只登记） |
| `S03_傀儡` | `ui/page_puppet.gd:88`（`_bg.color = C_BG_TOP`）← `:8` | 同上 | 10 | 归 **P0-4**（只登记） |
| `S39_药园` | `ui/page_herb_garden.gd:81`（`_bg.color = C_BG_TOP`）← `:8` | 同上 | 12 | 归 **P0-4**（只登记） |
| `S41_藏书阁` | `ui/page_library.gd:89`（`_bg.color = C_BG_TOP`）← `:8` | 同上 | 10 | 归 **P0-4**（只登记） |
| `S42_装备图纸` | `ui/page_equipment_blueprint.gd:76`（`_bg.color = C_BG_TOP`；`_bg` 声明 `:44`）← `:8` | 同上 | 11 | 归 **P0-4**（只登记） |
| `X05_玩家交易` | `ui/page_player_trade.gd:17`（`bg.color = Color(0.08, 0.08, 0.1, 0.95)`） | **硬编码 `Color(`**（全屏底字面量） | 22 | 归 **P0-4**（只登记） |
| `X06_离线管理` | `ui/page_offline_manager.gd:17`（`bg.color = Color(0.086, 0.125, 0.141, 0.95)`） | 同上 | 38 | 归 **P0-4**（只登记） |
| **D 类 · 自建底走 `make_scene_background()` ⇒ `SECONDARY_CONTENT_BG`（`ui_theme.gd:1359`，硬编码 `#0A1216`，不在 26 行）** | | | | |
| `TAB_殿阁` | `ui/page_building.gd:165`（`var content = UITheme.make_scene_background(self)`） | **工厂**：`ui_theme.gd:1362` → `:1373 base.color = SECONDARY_CONTENT_BG`（`:1359`） | 49 | 归 **P0-4**（只登记）；卡片另有 `:306 card_sb.bg_color = Color(0.12,0.10,0.08,0.9)` |
| `S16_宗门典藏` | `ui/page_codex.gd:61`（工厂） | 同上（面板另有 `:126/:164/:367 Color(0.122,0.169,0.192)`，**非主底**） | 15 | 归 **P0-4**（只登记） |
| `S20_宗门舆图` | `ui/page_atlas.gd:53`（工厂） | 同上 | 1 | 归 **P0-4**（只登记） |
| `S04_入山采撷` | `ui/page_hunt.gd:20`（工厂） | 同上 | — | 归 **P0-4**（只登记） |
| `S46_道友` | `ui/page_daoyou.gd:40`（工厂） | 同上（`:310 BarBg.color = C01_TOPBAR_BG` 是**底部 56 高小条**，**非主底**） | 8 | 归 **P0-4**（只登记） |
| `S47_闲情雅趣` | `ui/page_leisure.gd:36`（工厂） | 同上 | — | 归 **P0-4**（只登记） |
| `X04_宗主详情` | `ui/master_detail_page.gd:112`（`bg.color = UITheme.SECONDARY_CONTENT_BG`，**直赋同一 token、非工厂**） | **同色源**（`:1359`） | 4 | 归 **P0-4**（只登记） |
| **B 类 · 自建底走 `ui_theme` 非 26 行 token（直接引用）** | | | | |
| `S22_幻形` | `ui/page_huanxing.gd:71`（`base.color = UITheme.C01_SCENE_BASE`） | **26 行外 token**：`ui_theme.gd:**`:59`** C01_SCENE_BASE` | 13 | 归 **P0-4**（只登记） |
| **C 类 · 未自建全屏底（走共享容器）** | | | | |
| `S21_家族` | `ui/page_family.gd`（**无任何 ColorRect/`.color=`/底色赋值** —— 见 §3） | 未自建 → 共享 `game_ui.gd:224 _sub_bg.color = UITheme.获取页面底色()`（= 26 行内 `:1470`） | 52 | **无需改**（已走 token）；实机复核 |
| `S24_护道人` | `ui/page_guardian.gd`（同上） | 同上 | — | **无需改**；实机复核 |
| `S30_法宝` | `ui/page_treasure.gd`（同上） | 同上 | 38 | **无需改**；实机复核 |
| `S31_灵兽` | `ui/page_beast.gd`（同上） | 同上 | 44 | **无需改**；实机复核 |
| `S38_科技` | `ui/page_tech.gd`（同上） | 同上 | 27 | **无需改**；实机复核 |
| `S51_飞升` | `ui/page_ascension.gd`（同上） | 同上 | — | **无需改**；实机复核 |

> **C 类本轮已升级取证**：对 6 个脚本做 `ColorRect\.new\(\) | \.color = | 背景 | 底色 | make_scene_background` 检索 → **0 命中**（见 §3）；且 6 者**均不在**「全仓 33 个调用 `make_scene_background` 的 `.gd`」之列 ⇒ **确无自建全屏底**。

---

## 2. 机制证据（盘上原文 · 逐字）

**① 工厂实现**（`ui_theme.gd:1354-1375`）：

```gdscript
# ui_theme.gd:1357-1359
const BG_SCENE_TEX: String = ASSET_DIR + "backgrounds/home_bg_sect_a.png"
const SECONDARY_TOP_BG_H: float = 0.0        # 顶部氛围区高：0 表示彻底关闭氛围图，统一纯色紧凑布局
const SECONDARY_CONTENT_BG: Color = Color(0.039, 0.071, 0.086)   # 内容区纯色底（深青，不透明）
# ui_theme.gd:1362-1375
func make_scene_background(parent: Control) -> Control:
	var bg := Control.new(); bg.name = "SceneBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	...
	var base := ColorRect.new(); base.name = "ContentBase"
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.color = SECONDARY_CONTENT_BG          # ← 全屏底 = 硬编码字面量
	...
```

- `Color(0.039,0.071,0.086)` → **`#0A1216`**（0.039×255≈10=0x0A｜0.071×255≈18=0x12｜0.086×255≈22=0x16）。
- `SECONDARY_TOP_BG_H = 0` ⇒ 氛围图**关闭**，`ContentBase` **独占整屏** ⇒ 主背景 = `#0A1216` **纯色**。

**② 另一条色源**（`ui_theme.gd:1504-1505`）：

```gdscript
func 获取页面底色() -> Color:
	return _取语义色("bg.page", MAT_BASE_TOP, true)   # MAT_BASE_TOP = ui_theme.gd:1470（26 行内）
```

**③ P0-A 的 26 行**（批2 实改范围）：

```
MAT_*    ：ui_theme.gd:1470–1481（12 行）
COLOR_*  ：ui_theme.gd:8 :11 :16 :20 :26 :27 :28 :29 :33 :34（10 行）
C0x_*    ：ui_theme.gd:43 :44 :45 :46（4 行）
```

⇒ **`:1359 SECONDARY_CONTENT_BG` 不在 26 行内** ⇒ **批2 改不到它** ⇒ 走工厂的页主底**逐像素未变**。

**④ 工厂覆盖面**：全仓 **33 个 `.gd`** 调用 `UITheme.make_scene_background(...)`（本轮实检索）；21 页中有 **6 个**（`page_building/page_codex/page_atlas/page_hunt/page_daoyou/page_leisure`）。

---

## 3. 归类取证（本轮实检索 · 可复现）

| 检索 | 命令式 | 结果 |
|---|---|---|
| 工厂调用者（全仓） | `rg make_scene_background ui/*.gd` | **33 个 `.gd`** |
| 21 页中走工厂者 | 同上 ∩ 21 页承载脚本 | **6 个**：`page_hunt:20 / page_codex:61 / page_atlas:53 / page_building:165 / page_daoyou:40 / page_leisure:36` |
| C 类 6 脚本是否自建底 | `rg 'ColorRect\.new\(\)|\.color =|背景|底色|make_scene_background' page_{family,guardian,treasure,beast,tech,ascension}.gd` | **0 命中** ⇒ 确无自建底 |
| B 类 token | `rg 'C01_SCENE_BASE' ui/page_huanxing.gd` | `:71 base.color = UITheme.C01_SCENE_BASE` |
| A 类字面量 | 见 §1 各行 `file:line` | 5 页共用 `:8 C_BG_TOP = Color(0.106,0.153,0.169)` 同源范式 |

**A 类五页同源范式逐字**：

```
ui/page_pill_formula.gd:8        const C_BG_TOP: Color = Color(0.106, 0.153, 0.169)
ui/page_pill_formula.gd:58          _bg.color = C_BG_TOP
ui/page_puppet.gd:8 / :88           （同上）
ui/page_herb_garden.gd:8 / :81      （同上）
ui/page_library.gd:8 / :89          （同上）
ui/page_equipment_blueprint.gd:8 / :76（同上；`_bg` 声明 :44）
```

> **同族旁注**：v1 记 `ui/page_storage.gd:26` 亦用同款 `C_BG_TOP`（**本轮未复验**）；另 `page_storage.gd:94` 调 `make_scene_background(parent)`。`page_storage` = S23 库藏，**不在本 21 页**。P0-4 换肤时建议把这族一起核。

---

## 4. ★ 与 v1 的差异（更正清单）

本轮按 team-lead 的机制线索推广核验后，**v1 有 6 页归类需更正**（v1 的静态扫描**漏了工厂调用**，只找 `ColorRect.new()` 直建底）：

| 页 | v1 归类 | **v2 更正为** | 更正依据 |
|---|---|---|---|
| `TAB_殿阁` | A 类（"card_sb 卡片底"） | **D 类**（工厂 → `SECONDARY_CONTENT_BG :1359`） | `page_building.gd:165` 工厂；`:306 card_sb` 是**卡片**底、非主底 |
| `S16_宗门典藏` | A 类（`sb.bg_color`） | **D 类**（工厂） | `page_codex.gd:61` 工厂；`:126/:164/:367` 是**面板**底 |
| `S20_宗门舆图` | C 类（"未自建底"） | **D 类**（工厂） | `page_atlas.gd:53` 工厂 |
| `S04_入山采撷` | C 类（"未自建底"） | **D 类**（工厂） | `page_hunt.gd:20` 工厂 |
| `S46_道友` | B 类（`C01_TOPBAR_BG`） | **D 类**（工厂）；`C01_TOPBAR_BG` 只是底部 56 高小条 | `page_daoyou.gd:40` 工厂；`:310` 是 `BarBg` |
| `S47_闲情雅趣` | C 类（"未自建底"） | **D 类**（工厂） | `page_leisure.gd:36` 工厂 |

**净影响**：A 类 9→**7**、C 类 9→**6**、B 类 3→**1**、**新增 D 类 7**；靶子（A+B+D）由 v1 的 12 页 → **v2 的 15 页**。

**v1 漏判根因**：v1 §0 的静态检索式是 `ColorRect.new() / _bg|base|bg\.color = / 背景 / 底色 / UITheme.<bg token>`——**未包含 `make_scene_background(`**，故工厂调用者被误判为"未自建底"。**v2 已把工厂调用纳入检索**。

---

## 5. ★ 保留的 QA 发现（C 类 · harness direct-call 盲区）

C 类 6 页"在 P0-A 差分里未变"，**不是**主背景硬编码，而是**采样通道旁路**：

- `_ph0a` / `ui_full_accept` **直接实例化页面脚本节点**截图（见 task PH7-QA-14「入口可达性全量审计（治 harness direct-call 盲区）」）⇒ **绕过 `game_ui._sub_bg`** ⇒ 脚本未自建底的页**截到透明/默认清屏色**，照不到 `_sub_bg`。
- ⇒ C 类页在**真机玩家入口路径**下主底 = `:1470 获取页面底色()` ⇒ **应已随 P0-A 变色**；差分里的"未变"是**采样问题、非缺陷**。
- **待核实**（我起不了 Godot，遵「Godot 独占铁律」）：请 team-lead 排时段，我用**真实玩家入口路径**（**禁** `ui_full_accept.gd:139` direct-call 通道）抽验 1–2 页（建议 `S38_科技` / `S30_法宝`）。
- **未核前，C 类 6 页不列入「其他」轮次靶子**（与 v1 口径一致）。

---

## 6. 边界与未做

- **只登记不建议本批修**：A / B / D 类均属 **P0-4 换肤**范畴；本轮只出**靶子表**，**不派施工**。
- **站数**：取自 P0-4 §1（`scan_color_sites.py` 口径；与 `audit_ui.py` 权威水位口径略差，**仅用于分布**）。
- **未做**：未改任何 `.gd`/`.csv`；未起 Godot；未跑 `gate_all.py` / 战斗探针；未 `--rebase`。
- **C 类**已升级为"检索 0 命中"取证（§3），不再是 v1 的"未逐行通读"软结论。

---

*PH7-QA-20（v2 · 依 team-lead 第二轮指令修订）｜ quality-lead-2 ｜ 只读产出，未落任何代码改动。*
