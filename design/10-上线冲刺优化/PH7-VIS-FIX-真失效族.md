---
doc_id: ENG-VIS-FIX-DEADFAM
doc_title: 真失效族施工规格 · PH7-VIS-FIX（独立批 · 待老大批 · 排期在老大目视 01–06 之后）
doc_version: v1.0
update_date: 2026-09-17
doc_type: 技术 / 视觉机制 · 施工规格（**非施工**：本轮盘上零改动 · 未跑 Godot · 未 git）
task_id: PH7-VIS-FIX-真失效族
owner: engineering-lead（程基岩）
inputs: |
  ui_theme.gd（143862 B · md5 7ddd01fd433550e6735e2f6dd1b2274f · LF 2632）—— 机制真源；本批**不动**
    · 全局入树钩子 `_入树_包边距`（`:2053`）＋延迟体 `_包边距_延迟`（`:2067`）
    · 钩子链：`_on_节点入树`（`:1933`）→ `:1938 _入树_包边距(c)`；挂点 `:1911 _挂全局手感钩子()`；`project.godot` autoload ⇒ 启动即挂
    · `margin_*` 语义注释 `:1975-1982`（「MarginContainer 专有主题常量」）
  九承载脚本（盘上核证 · §1.3）：main.gd · ui/page_faction.gd · ui/page_zongmen_battle.gd · ui/page_building.gd · ui/page_explore.gd · ui/page_sect_manager.gd · ui/page_disciple.gd · ui/page_quest.gd · ui/battle_scene.gd
  design/10-上线冲刺优化/逐页视觉精修-07其他.md（v2.3 · **登记来源**：§1.5.1 真失效族登记表 ＋ §2.2 登记项）
  design/10-上线冲刺优化/逐页视觉精修-03殿阁页.md（S2 ＝ 丙-a 同处 · 独立互证）
  .workbuddy/_ph7vis/真失效族-vs-幻影族.md（族分判据 · 钩子是否兜住）
  量测脚本：.workbuddy/_pfix_fp.txt（九文件指纹）
scope: **只出规格**。全仓 `.gd`/`.tscn`/`.cs`/`.csv`/资产 **零改动**；未跑 Godot；未执行 git。**未批不施工。**
---

# 真失效族 · 施工规格（PH7-VIS-FIX · 独立批）

> **一句话**：把「**键名/宿主形态错 ⇒ 被引擎或全局钩子静默忽略 ⇒ 版面从未生效**」的一类缺陷（**真失效族**），从 07 批的「登记」升为**独立施工批**——逐族逐处清点、给可落地方案与可证伪核验、划清与「幻影族」的界，**待老大批后施工**。
> **定名**：`PH7-VIS-FIX-真失效族`（**独立批** · **非横切换肤批** · **非 07 批**）。
> **排期**：老大**目视 01–06 之后**（= 页序 01→02→03→04→05→06→其他 之后）。
> 🔴 **未批不施工**：本文件仅规格；决策点见 §6。

> ⛔ **边界（先读）**
> ① **UI 三连**：复用 `ui_theme.gd` 既有组件与 getter；**禁自定义图标、禁硬编码 `Color(...)`**；术语用「负责人 / 成员 / 关闭 / 任命 / 建筑 / 产出」。
> ② **禁横切**：本批**只改布局键名 / 宿主包裹**，**禁全局换色 / 底色统一 / 背景重映射**（不改 `ui_theme.gd` 的 `C01_*` 真源、不改 `获取场景压暗色()`）。
> ③ **文案冻结**：本批**不含任何纯文案改动**（各页标题 / 分词 = 冻结）。
> ④ **红点**：**零红点改动**。
> ⑤ **可验收性**：走「**真实渲染 ＋ 探针（node 计数 / `get_theme_constant` 回读 / 目标控件 `size`）**」；**禁像素差分当主判据**。
> ⑥ **禁令**：**不改 `ui_theme.gd`**；不改 01–07 任何规格；引代码用「**函数名 ＋ `:行号`**」双锚（行号会漂）。

---

## §0 · 机制与口径（★ 先读）

### 0.1 真失效族 vs 幻影族（**本批只做前者**）

| 类别 | 判据 | 运行期 | 处置 |
|---|---|---|---|
| **幻影族** | `margin_*` 挂 **白名单宿主**（`VBoxContainer`/`HBoxContainer`/`GridContainer`） | **已生效**（入树钩子 `_入树_包边距` 自动包 `MarginContainer`） | **一律不修**（≈32 文件 / 220 处） |
| **真失效族** | 键名错 **或** 宿主不在白名单（`Label` / `Control` 属性误用 / 裸键 / 拼写错） | **确认无效（静默忽略）** | **本批施工对象** |

### 0.2 钩子白名单（机制真源 · `ui_theme.gd`）

```
_on_节点入树(n)              # :1933   （node_added 信号，启动即挂）
  └─ if n is Control:        # :1935
        _入树_补折行(c)       # :1937
        _入树_包边距(c)       # :1938  ← 本批机制关
        _入树_补尾垫(c)       # :1939

_入树_包边距(c)              # :2053
  if not (c is VBoxContainer or c is HBoxContainer or c is GridContainer): return   # :2054  ★白名单
  if not (has margin_left|right|top|bottom override): return                        # :2058-2059
  _包边距_延迟.call_deferred(c)   # :2062  ⇒ 原地包一层 MarginContainer（:2073）＋平移 4 常量（:2075-2077）
```

**⇒ 两条推论（本批全部结论之根）**：
1. **只有**「VBox / HBox / Grid 宿主 ＋ `margin_left/right/top/bottom` 键」被钩子兜住；其余**真死**。
2. `MarginContainer` **原生**响应 `margin_*` ⇒「挂真 `MarginContainer`」恒有效（不属本族）。

### 0.3 三空间与阵营（承 07 §0）

| 空间 | 尺寸 | 换算 |
|---|---|---|
| 逻辑 | 480×853 | `逻辑 = 物理 ÷ 2.25` |
| 物理 | 1080×1920 | `物理 = 逻辑 × 2.25` |
| frame | 720×1280 | `frame = 物理 × 0.6667 = 逻辑 × 1.5` |

**阵营**：**B** ＝ 直用 `UITheme.*` 常量 / 裸字面量（**已是物理值**，不再 ×2.25）；**A** ＝ `int(round(N × UI_SCALE))`（`N` 是**逻辑**）。代表值：`GRID 12 → 5.33 逻辑 → 8.0 frame`；`MARGIN 24 → 10.67 → 16.0`；`PAD_PANEL`（＝ `ui_theme.gd` 常量，**物理**）。

---

## §1 · 定名与范围

### 1.1 定名

- **批名**：`PH7-VIS-FIX-真失效族`。
- **性质**：**独立批**；**非横切换肤批**（不触发老大「不许再开新横切批次」禁线 —— 理由见 §1.2）；**非 07 批**（07 只「登记」）。
- **承载脚本**：**9 个**（§1.3），跨 **首页 / 02 弟子 / 03 殿阁 / 长尾页**。

### 1.2 为何单独立批（三条理由）

1. **跨 8–9 文件，含「已交付并锁定帧」的页面**（**首页 `main.gd`**、**03 殿阁页 `page_building.gd`**、及 02 `page_disciple.gd`）⇒ 若并入 07 会**作废已验收帧**（须重拍 + 重验收）。
2. **属「机制真失效（静默忽略）」**，与 07「margin 幻影族」**不同问题类**（幻影族＝钩子已兜住、不修；本族＝真死、须修）。
3. **独立批可独立核验 / 独立回滚**（回滚点方案见 §5.3）；且**修法有分歧**（§3 每族列候选），需老大定夺 ⇒ 不宜塞进任何既有批。

### 1.3 承载文件指纹（盘上 · 2026-09-17）

| 脚本 | bytes | LF | CR | BOM | md5 | `\bColor(` | 归属页 / 批次 |
|---|---:|---:|:--:|:--:|---|---:|---|
| `main.gd` | 278811 | 6129 | 0 | False | `dd440880fb00660f7fee32a45c5e5632` | 126 | **首页 / 主场景**（已交付·锁定帧） |
| `ui/page_faction.gd` | 47971 | 1181 | 0 | False | `6ee378a164e90514783773af93356979` | 11 | 阵营声望（长尾页） |
| `ui/page_zongmen_battle.gd` | 45997 | 1171 | 0 | False | `e501b4ce068737c6b9f963109a1acea7` | 11 | 宗门战（长尾页） |
| `ui/page_building.gd` | 195538 | 4251 | 0 | False | `188e785adabb7bcf9064c8739338a2bd` | 53 | **03 殿阁页**（已交付·锁定帧） |
| `ui/page_explore.gd` | 71704 | 1753 | 0 | False | `1d6f0cd7f6a49e61e58195fcd46aafed` | 13 | TAB 历练（07 批） |
| `ui/page_sect_manager.gd` | 134869 | 3563 | 0 | False | `45e28b61ae29f986033b073ba115eda2` | 17 | 宗主管理（长尾页） |
| `ui/page_disciple.gd` | 92960 | 2054 | 0 | False | `4f32e78472f3c6193fa32e83ddce252d` | 25 | **02 弟子页**（已交付·锁定帧） |
| `ui/page_quest.gd` | 71696 | 1788 | 0 | False | `66cfcbe67a60f78e888804cb2ab28e81` | 27 | 宗务（长尾页） |
| `ui/battle_scene.gd` | 44983 | 1190 | 0 | False | `de140eb55a1eee5ca1e95102a7557bf1` | 77 | 战斗场景（长尾） |

> 注：`page_explore.gd` md5 与 07 规格（v2.3 §1.1）**逐字节一致** ⇒ 自 07 出稿以来盘上未变（互证）。

### 1.4 排期

- **顺序**：老大目视 **01→02→03→04→05→06→其他** 完成后。
- **内部序（建议）**：**丙-b（12 处，最简）→ 丙-a（64 处，量大，可分两批）→ 甲（3 处，需决策）**；**丙-c / 丙-d 盘上为 0，建议直接移出**（§2.6）。

---

## §2 · 逐族现状清点表（**每处给行号** · 盘上实测 2026-09-17）

> 清点口径：`rg 'add_theme_constant_override\("…"'` 逐处核 ＋ 宿主声明逐处读类。
> **可达性**：下表各行**均在正常 `_build*` / `_populate*` / `_make*` / `_构建*` 构建路径**，**未命中 `return` 后 / 死分支** ⇒ 全部**可达**（故均属「真失效但可达」＝**有实际视觉后果**；丙-a/丙-b 已达的页为「内距恒为 0」）。

### 2.0 ★ 逐族计数 · 与派单/07 规格对照（**偏差已明标**）

| 族 | 机制 | 派单/07 规格给的数 | **盘上实测** | 偏差 | 去向 |
|---|---|---|---:|---:|---|
| **丙-a** | `offset_*` 当**主题常量**（`offset_*` 是 `Control` **属性**、非主题常量） | 64 处 / 3 文件 | **64 / 3** | **0 ✓** | **施工** |
| **丙-b** | 裸键 `"margin"`（钩子只查带前缀键） | 12 处 / 2 文件 | **12 / 2** | **0 ✓** | **施工** |
| **丙-c** | `hseparation`/`vseparation` **拼写错** | 2 处 / 1 文件 | **0 / 0** | **−2 ❗** | **建议移出**（已在 02 批修复） |
| **甲** | `margin_*` 挂**白名单外**宿主 | 4 处 / 2 文件 | **3 / 2** | **−1 ❗** | **施工**（需决策） |
| **丙-d** | `shadow_offset_*` 挂 `StyleBoxFlat` | 2 处 / 1 文件 | **0 / 0** | **−2 ❗** | **建议移出**（前提不成立） |
| **可修合计** | | 82 处 / 8 文件 | **79 处 / 7 文件** | **−3 / −1** | |

**三条偏差的盘上实证**（**以盘上实测为准**）：

- **㊀ 丙-c（2→0，已修）**：盘上 `rg 'hseparation|vseparation'` **仅命中 `.bak_*` 备份与文档**，**无任何 live `.gd`**。`ui/page_disciple.gd:1729`/`:1730` 现为**正确键** `h_separation`/`v_separation`（宿主 `grid`＝`GridContainer`，`:1727`）—— 即 **02 弟子页批（Task #30）已修**（02 报告明载「丙-c 修正 Key 名拼写 → 改后复核：两行已是正确键名」）。派单所引 `:1716/:1717` 为**改前行号**。
- **㊁ 甲（4→3）**：派单/07 列的 4 处中，`ui/page_quest.gd:846` **宿主实为 `VBoxContainer`**（`var panel := VBoxContainer.new()`，**`:809`**）⇒ **∈ 钩子白名单 ⇒ 运行期已生效 ⇒ 不属甲**。真·甲 ＝ **3 处**：`main.gd:6117`（`:6113 l := Label.new()`）＋ `ui/page_quest.gd:1738`/`:1739`（`:1732 lab := Label.new()`）。
- **㊂ 丙-d（2→0，前提不成立）**：`ui/battle_scene.gd:673`/`:674` 宿主为 **`Label`**（`:665 var label: Label = _获取飘字()`）。而 `shadow_offset_x`/`shadow_offset_y` **是 `Label` 的合法主题常量**（Godot 4 Label theme constants）⇒ **本处有效、非失效**。全仓 `add_theme_constant_override("shadow_offset_*")` **均挂 `Label`**；`sb.shadow_offset = Vector2(...)` 为 `StyleBoxFlat` **属性**（合法）。⇒ **不存在「`shadow_offset_*` 挂 `StyleBoxFlat`」的失效样本**。

> **旁证（未列族 · 已排除）**：全仓 `GridContainer` **均用正确键** `h_separation`/`v_separation`，**无**「Grid 挂裸 `separation`」变体（§2.7 待核项 1 已核=0）。

### 2.1 丙-a（`offset_*` 当主题常量）· **64 处 / 3 文件**（逐块列 · 每块 4 键）

> 键序恒为 `offset_left / offset_right / offset_top / offset_bottom`；宿主**均为 `VBoxContainer`**；**全部可达**。

**（a1）`ui/page_faction.gd` · 44 处（11 块）**

| # | 块行（4 键） | 宿主 var（声明行） | 宿主类 | 值（左/右/上/下） | 所在函数（:行） |
|---|---|---|---|---|---|
| 1 | `:163 :164 :165 :166` | `弟子阵营vbox`（`:161`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_scroll`（`:136`） |
| 2 | `:222 :223 :224 :225` | `vbox`（`:220`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_faction_card`（`:215`） |
| 3 | `:287 :288 :289 :290` | `vbox`（`:285`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_comprehensive`（`:279`） |
| 4 | `:319 :320 :321 :322` | `item_vbox`（`:317`） | `VBoxContainer` | `12 / 12 / 8 / 8` | `_build_comprehensive`（`:279`） |
| 5 | `:348 :349 :350 :351` | `vbox`（`:345`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_campaign`（`:339`） |
| 6 | `:511 :512 :513 :514` | `vbox`（`:508`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_hostile_npc`（`:502`） |
| 7 | `:626 :627 :628 :629` | `vbox`（`:623`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_npc_list`（`:617`） |
| 8 | `:784 :785 :786 :787` | `NPCvbox`（`:782`） | `VBoxContainer` | `12 / 12 / 8 / 8` | `_update_npc_list`（`:755`） |
| 9 | `:834 :835 :836 :837` | `vbox`（`:831`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_interactive_npc`（`:825`） |
| 10 | `:871 :872 :873 :874` | `dialog_vbox`（`:869`） | `VBoxContainer` | `12 / 12 / 8 / 8` | `_build_interactive_npc`（`:825`） |
| 11 | `:924 :925 :926 :927` | `NPCvbox`（`:922`） | `VBoxContainer` | `12 / 12 / 8 / 8` | `_update_interactive_npc`（`:897`） |

**（a2）`ui/page_zongmen_battle.gd` · 16 处（4 块）**

| # | 块行（4 键） | 宿主 var（声明行） | 宿主类 | 值 | 所在函数（:行） |
|---|---|---|---|---|---|
| 12 | `:214 :215 :216 :217` | `vbox`（`:212`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_team_section`（`:206`） |
| 13 | `:298 :299 :300 :301` | `vbox`（`:296`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_array_section`（`:290`） |
| 14 | `:386 :387 :388 :389` | `vbox`（`:384`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_buff_section`（`:378`） |
| 15 | `:472 :473 :474 :475` | `vbox`（`:470`） | `VBoxContainer` | `PAD_PANEL`×4 | `_build_territory_section`（`:465`） |

**（a3）`ui/page_building.gd` · 4 处（1 块）· ★＝ 03 殿阁页 S2（独立互证）**

| # | 块行（4 键） | 宿主 var（声明行） | 宿主类 | 值 | 所在函数（:行） |
|---|---|---|---|---|---|
| 16 | `:329 :330 :331 :332` | `card_vbox`（`:325`） | `VBoxContainer`（在 `card` 内） | `int(round(16.0 * UI_SCALE))`×4 ＝ **16 逻辑 / 36 物理 / 24.0 frame** | `_build_panorama_view`（`:200`） |

> ★ **独立互证**：`page_building.gd:329-332` **正是 03 殿阁页的 S2** —— engineering-lead 在不知本普查时把 S2 标为「**★升格修复**」，两路独立命中同一处 ⇒ **丙-a 成立无疑**。（宿主 `card_vbox` 挂 `card`（`PanelContainer`，`:322` 有 `add_theme_stylebox_override("panel",…)`）⇒ 见 §3.1 候选 A 的陷阱。）

### 2.2 丙-b（裸键 `"margin"`）· **12 处 / 2 文件**（逐处）

| # | 行 | 宿主 var（声明行） | 宿主类 | 值 | 所在函数（:行） |
|---|---|---|---|---|---|
| 1 | `ui/page_explore.gd:138` | `left_vb`（`:137`） | `VBoxContainer` | `UITheme.GRID` | `_build_main_area`（`:125`） |
| 2 | `ui/page_explore.gd:165` | `_detail_content`（`:19` 声明 / `:164` 赋值） | `VBoxContainer` | `UITheme.GRID` | `_build_main_area`（`:125`） |
| 3 | `ui/page_explore.gd:582` | `card_vb`（`:581`） | `VBoxContainer` | `UITheme.GRID` | `_refresh_detail`（`:336`） |
| 4 | `ui/page_explore.gd:1395` | `内容`（`:1394`） | `VBoxContainer` | `UITheme.GRID * 2` | `_弹出奇遇弹窗`（`:1365`） |
| 5 | `ui/page_explore.gd:1493` | `内容`（`:1492`） | `VBoxContainer` | `UITheme.GRID * 2` | `_显示奇遇结果`（`:1476`） |
| 6 | `ui/page_sect_manager.gd:964` | `vb`（`:962`） | `VBoxContainer` | `UITheme.GRID` | `_make_card`（`:959`） |
| 7 | `ui/page_sect_manager.gd:2469` | `派系vb`（`:2468`） | `VBoxContainer` | `UITheme.GRID` | `_populate_faction_power`（`:2427`） |
| 8 | `ui/page_sect_manager.gd:2736` | `内`（`:2734`） | `VBoxContainer` | `UITheme.GRID` | `_populate_memorial`（`:2717`） |
| 9 | `ui/page_sect_manager.gd:2832` | `内`（`_构建请命卡` 内） | `VBoxContainer` | `UITheme.GRID` | `_构建请命卡`（`:2818`） |
| 10 | `ui/page_sect_manager.gd:2888` | `内`（`_构建执行中卡` 内） | `VBoxContainer` | `UITheme.GRID` | `_构建执行中卡`（`:2874`） |
| 11 | `ui/page_sect_manager.gd:2933` | `内`（`_构建招募中卡` 内） | `VBoxContainer` | `UITheme.GRID` | `_构建招募中卡`（`:2920`） |
| 12 | `ui/page_sect_manager.gd:3321` | `内`（`_构建功勋兑换卡` 内） | `VBoxContainer` | `UITheme.GRID` | `_构建功勋兑换卡`（`:3275`） |

> **`"margin"` 原意判定**：**12 处全部为「标量单值」**（`GRID` 或 `GRID×2`，无左右/上下之分）⇒ **原意 ＝「四周等距」**（MarginContainer 语义），**非**「某一侧」。

### 2.3 丙-c（拼写错）· **0 处 / 0 文件（已修）**

| 原登记 | 盘上实测 | 判定 |
|---|---|---|
| `ui/page_disciple.gd:1716 :1717`（`GridContainer`） | `:1729 h_separation` / `:1730 v_separation`（**正确键**）；全仓无 live `hseparation`/`vseparation` | **已由 02 批修复 ⇒ 本批移除** |

### 2.4 甲（`margin_*` 挂白名单外宿主）· **3 处 / 2 文件**（逐处）

| # | 行 | 宿主 var（声明行） | 宿主类 | 键 | 值 | 逻辑量反推 | 所在函数（:行） |
|---|---|---|---|---|---|---|---|
| 1 | `main.gd:6117` | `l`（`:6113`） | **`Label`** | `margin_bottom` | `4`（裸字面量 · **阵营 B＝物理**） | **4 物理 / 1.78 逻辑 / 2.67 frame** | `小标题`（`:6112`） |
| 2 | `ui/page_quest.gd:1738` | `lab`（`:1732`） | **`Label`** | `margin_left` | `int(round(12.0 * UI_SCALE))`（**阵营 A**） | **N＝12 逻辑 / 27 物理 / 18.0 frame** | `_toast_at`（`:1724`） |
| 3 | `ui/page_quest.gd:1739` | `lab`（`:1732`） | **`Label`** | `margin_right` | `int(round(12.0 * UI_SCALE))`（**阵营 A**） | **N＝12 逻辑 / 27 物理 / 18.0 frame** | `_toast_at`（`:1724`） |

> ⚠ **除名 1 处**：`ui/page_quest.gd:846`（`margin_left`, `int(round(20.0*UI_SCALE))`）**宿主 `panel` ＝ `VBoxContainer`**（`:809`）⇒ 白名单 ⇒ **运行期已生效，不属甲**。

### 2.5 丙-d（`shadow_offset_*`）· **0 处 / 0 文件（前提不成立）**

| 原登记 | 盘上实测 | 判定 |
|---|---|---|
| `ui/battle_scene.gd:673 :674`（挂 `StyleBoxFlat`） | 宿主 ＝ **`Label`**（`:665`）⇒ `shadow_offset_x/y` 是 **Label 合法主题常量** ⇒ **生效** | **非缺陷 ⇒ 本批移除** |

### 2.6 本批施工面（盘上定案）

- **施工**：**丙-a（64）＋ 丙-b（12）＋ 甲（3）＝ 79 处 / 7 文件**。
- **移出**：**丙-c（已修）**、**丙-d（非缺陷）** ⇒ 建议在本规格落 §6 决策后，于 07 §1.5.1/§2.2 与《总表》§2.1 **同步标注**。

### 2.7 待核项（本批零施工 · 仅登记）

1. **Grid 挂裸 `separation`**：已核 **＝ 0**（全仓 `GridContainer` 均用 `h_separation`/`v_separation`）。**结论：无此族**。
2. **`Control` 属性 `offset_*` 的「父为容器时无效」**：见 §3.1 候选 A 陷阱 —— 影响**修法选择**（非新缺陷族）。

---

### 2.8 ★ D1 前置条件（**只读实证 · 盘上 2026-09-17**）

> team-lead 批 B′ 时下达两项**硬前置**：**① 逐块宿主 class 判定**（任一块宿主 ∉ `{VBox,HBox,Grid}` ⇒ 该块须改走候选 C）＋ **② 依赖扫描**（`get_parent()` / `get_index()` / `move_child()` / `reparent` / `add_sibling` / 兄弟序 / **名路径查找**）。两项均已只读跑完，结论如下。

**（前置 1）逐块宿主 class —— 16/16 ∈ 白名单 ⇒ B′ 全适用，无一块需改走 C**

| 文件 | 块号 | 宿主声明行 | 宿主类 | 判定 |
|---|---|---|---|---|
| `page_faction.gd` | 1–11 | `:161 :220 :285 :317 :345 :508 :623 :782 :831 :869 :922` | 全部 `VBoxContainer` | **∈** ✓ |
| `page_zongmen_battle.gd` | 12–15 | `:212 :296 :384 :470` | 全部 `VBoxContainer` | **∈** ✓ |
| `page_building.gd` | 16 | `:325` | `VBoxContainer` | **∈** ✓ |

⇒ **16/16 命中 `_入树_包边距` 白名单**（`ui_theme.gd:2054`）⇒ **B′ 对全部 16 块成立；本批无需任何块改走 C。**

**（前置 2）依赖扫描 —— 三文件零命中 ⇒ B′ 无「宿主换父」副作用**

| 文件 | `get_parent/get_index/move_child` 命中 | 名路径查找命中 | 判定 |
|---|---|---|---|
| `page_faction.gd` | **0** | **0**（全文件无 `get_node`） | **安全** ✓ |
| `page_zongmen_battle.gd` | **0** | 1 处 `:566 get_node_or_null("MarginRoot/VBoxContainer/HeaderBar/HBoxContainer/JiyuanLabel")` —— 路径 5 段**均非宿主名** | **安全** ✓ |
| `page_building.gd` | `:538 _拖动控件.get_parent()`、`:1404 _list_vbox`、`:1573 _yushou_vbox`、`:2073 vb∈_tab_pages`（`:2071`）**均非宿主 `card_vbox`** | `card_vbox.name = "CardVBox"`（`:326`）；全文件**无** `get_node("CardVBox")` | **安全** ✓ |

⇒ **无一 block 的代码依赖其宿主的「父身份 / 索引 / 兄弟序」⇒ 钩子「原地包 `MarginWrap`、平移 `size_flags`、按原位插回」不破坏任何调用点。**

> **★ 新增子检查（本批新发现，务必保留）**：钩子包裹使 **`宿主.get_parent()` 由「原父」变为 `MarginWrap`** ⇒ 任何 **`父.get_node("<宿主名>")`（名路径）都会失效**。**丙-a 已证三文件零命中；丙-b 的 `page_sect_manager.gd` 有同类模式（`card.get_node("VBox")`），已逐处核验 —— 见 §2.9。**

### 2.9 ★ 丙-b 名路径依赖扫描（**批 1 施工前置 · 只读实证**）

`page_sect_manager.gd` 的 丙-b 宿主 `vb.name="VBox"`（`:963`）、`内.name="VBox"`（`:2735`），全文件共 **33 处 `*.get_node("VBox")`**。逐处核验「取窗时刻」：

- **统一模式**：`var card := _make_card(...)` → **`var vb := card.get_node("VBox")`（此时 `card` 尚未入树）** → 向 `vb` 建子 → **`_content.add_child(card)`（末步才入树）**。
- **33 处 `*.get_node("VBox")` 全部落在 `_make_card(...)` 之后、`_content.add_child(card)` 之前** ⇒ 均发生在 **`card` 入树前** ⇒ 钩子（**入树后才 `call_deferred` 包裹**）**永不早于这些取用** ⇒ **全部安全**。
- `_content.get_children()` 仅 4 处（`:137 :1693 :1795 :1886`），**均配 `queue_free()` 清场，无一处取子后 `get_node("VBox")`**。
- `page_explore.gd`：**0 处 `get_node`**（唯一 `:772 get_node_or_null("VBoxContainer/HBoxContainer/JiyuanLabel")` 与本批 5 宿主无涉）。

⇒ **丙-b 12 处宿主均无「名路径 / 父身份」依赖 ⇒ 候选 A（拆 4 前缀键 → 钩子包裹）安全，批 1 可施工。**

---

## §3 · 改法方案（每族 2 候选 ＋ 推荐 ＋ 布局影响面）

> **通用铁律（承 07 §2.1）**：① **不新增共享 helper**（不改 `ui_theme.gd`）；② **就地修正**；③ **顺序不可反**：`set_anchors_and_offsets_preset()` **会重置 offsets** ⇒ **preset 在前、offsets 在后**；④ **保留** `separation` override（其在 VBox/HBox 上**有效**，不在修正面）。

### 3.0 D1 前置条件（**只读核验 · 施工前必读** · 盘上实测 2026-09-17）

> team-lead 批准 B′ 时**附两个前置条件**（「不许跳过」）。以下逐条核验完毕 —— **纯只读，未起 Godot，未改一行代码**。

**前置条件 1｜16 块宿主 class 逐块判定（必须 ∈ `{VBoxContainer, HBoxContainer, GridContainer}`）**

| 文件 | # | 宿主 var（声明行） | 宿主 class | ∈白名单 |
|---|---|---:|---|:---:|
| `page_faction.gd` | 1 | `弟子阵营vbox`（`:161`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 2 | `vbox`（`:220`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 3 | `vbox`（`:285`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 4 | `item_vbox`（`:317`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 5 | `vbox`（`:345`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 6 | `vbox`（`:508`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 7 | `vbox`（`:623`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 8 | `NPCvbox`（`:782`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 9 | `vbox`（`:831`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 10 | `dialog_vbox`（`:869`） | `VBoxContainer` | ✅ |
| `page_faction.gd` | 11 | `NPCvbox`（`:922`） | `VBoxContainer` | ✅ |
| `page_zongmen_battle.gd` | 12 | `vbox`（`:212`） | `VBoxContainer` | ✅ |
| `page_zongmen_battle.gd` | 13 | `vbox`（`:296`） | `VBoxContainer` | ✅ |
| `page_zongmen_battle.gd` | 14 | `vbox`（`:384`） | `VBoxContainer` | ✅ |
| `page_zongmen_battle.gd` | 15 | `vbox`（`:470`） | `VBoxContainer` | ✅ |
| `page_building.gd` | 16 | `card_vbox`（`:325`） | `VBoxContainer` | ✅ |

**▶ 结论：16 / 16 全部 `VBoxContainer` ∈ 白名单 ⇒ B′ 对**全部 16 块**成立；**无一块需改走候选 C**。**（**逐块判定，非抽样**。判定口径：`rg '=\s*(VBox|HBox|Grid)Container\.new\(\)'` 逐文件核宿主声明行类。）

**前置条件 2｜父链 / 索引 / 兄弟序 / 名路径依赖扫描（扫清方可动工）**

扫描口径：三文件内 `rg 'get_node|get_parent|get_index|move_child|reparent|add_sibling|remove_child'`，**逐条**判定是否涉及 16 宿主。

| 文件 | 命中 | 是否触及宿主 | 判定 |
|---|---|---|---|
| `page_faction.gd` | **0 命中** | — | **干净 ✅** |
| `page_zongmen_battle.gd` | `:566 get_node_or_null("MarginRoot/VBoxContainer/HeaderBar/HBoxContainer/JiyuanLabel")` | **否** —— 该路径**陈旧**：`MarginRoot`（`:51`）之子实为 `BattleScroll`（`:60`）→ `RootVBox`（`:66`），**无** `VBoxContainer` 段 ⇒ 早已返回 `null`（既有死查找，与丙-a 无关；且不含任一丙-a 宿主） | **干净 ✅** |
| `page_building.gd` | `:538 _拖动控件.get_parent()`（`_调试模式` 拖动，非宿主）；`:2071-2073 for vb in _tab_pages.values(): vb.remove_child(c)`（`vb` ＝ 分页容器 `Tab_*`，非宿主） | **否** | **干净 ✅** |

**补充扫描（B′ 同源风险 · `get_node` 名路径）**：带 `name=` 的宿主有 `CampaignList` / `HostileNPCList` / `NPCList` / `InteractiveNPCList` / `TypeVBox` / `CardVBox` 等；全仓**无** `父.get_node("<宿主名>")` 反查（`page_building.gd` 甚至**零** `get_node` 调用）。⇒ **包裹后不存在「按名查宿主」失效。**

**▶ 结论：16 宿主**无一处被父链 / 索引 / 兄弟序 / 名路径依赖**（`ui_theme.gd:2098-2101` 包裹时 `父.remove_child(c)` 后 `父.move_child(包, c.get_index())` **插回原位**，且 `:2078-2079` 平移 `size_flags_horizontal/vertical`）⇒ **包裹零副作用**。）

**副作用记账（运行期新增节点）**：钩子对每个「带 `margin_*` 且 ∈ 白名单」的宿主**各包一层 `MarginContainer`**（`:2073`）⇒ 运行期新增节点数 ＝ **Σ（各块运行期实例化次数）**，**不是 64**（64 ＝ override **行数** ＝ 16 块 × 4，**非节点数**；如 `page_faction._build_faction_card` 每阵营一次、`_build_npc_list` 每 NPC 一次 ⇒ 实例数远大于 1）。⇒ **探针必须先记基线 `nodes=` 再比**（`_scan_page` 已打印每页 `nodes=`）。**B′ 施工后须复算**。

### 3.1 丙-a（`offset_*` → 内距）

**通用**：`offset_*` 作主题常量 ⇒ 静默忽略（真死）；痛点是**内距恒为 0**（内容贴边）。宿主**全为 `VBoxContainer`** ⇒ **∈ 钩子白名单** ⇒ `margin_*` 会被钩子自动包 `MarginContainer`。

- **候选 A｜直接赋 `Control` 属性** `offset_left/right/top/bottom`。
  - ⚠ **陷阱（必须写明）**：`offset_*` **属性**只在「**父级不是 `Container`**」时有意义。本族多数宿主的**父是容器**（如 `page_building` 的 `card_vbox` 父 ＝ `card`（`PanelContainer`）；`page_faction` 的卡片 vbox 父为 `VBoxContainer`）⇒ **属性 offsets 会被父容器布局覆盖 ⇒ 白改**。
  - ⇒ **判为「不通用」**：仅在「父为非容器」的少数处可行，**不建议作统一修法**。
- **候选 B′｜仅把键名从 `offset_*` 改为 `margin_*`（保留 VBox 宿主）**。
  - 机制：VBox ＋ `margin_*` ⇒ **入树钩子 `_入树_包边距` 自动包 `MarginContainer`**（`:2054` 白名单命中）⇒ 内距生效。**零结构改动、零新代码、复用既有基础设施**。
  - 顺序注意：`margin_*` 覆盖须在**入树前**设置（本族现状即在 `add_child` 前 `add_theme_constant_override`，天然满足）。
- **候选 C｜宿主换 `MarginContainer`（或显式外包一层）**。
  - 与 B′ 结果等价（B′ 即钩子代劳），但**改动更大**（`MarginContainer` 只按填满排布子项，需处理 `size_flags` 平移）⇒ **冗余**。

**▶ 推荐：候选 B′**（键名 `offset_*`→`margin_*`，逐处一一对应，值不变；宿主与结构不动，借既有钩子收口）。

**布局影响面**：**可见变化（首次生效）**。修复后各宿主**内距从 0 → 原值**：
- `page_faction` / `page_zongmen_battle`：内距 `PAD_PANEL`（物理）或 `12/12/8/8`（物理）。
- ★ **`page_building:329-332`（03 殿阁页 S2）**：卡片内距 **首次生效 ＝ 16 逻辑 / 36 物理 / 24.0 frame（四边）** ⇒ **卡片内容整体内缩**，可能触发**卡内换行/溢出** ⇒ **必须真机重拍 + 重验收 03 帧**（§4.3）。

### 3.2 丙-b（裸键 `"margin"`）

**通用**：`"margin"` 非 `margin_*` 族任何合法键 ⇒ 钩子不查（真死）；原意 ＝**四周等距**（§2.2）。

- **候选 A｜拆成 4 个带前缀键**：`margin_left/right/top/bottom` ＝ 同值（原标量）。
  - 机制：宿主均 `VBoxContainer` ⇒ 钩子自动包 `MarginContainer` ⇒ **四周等距生效**。
  - **等价改写**、零结构改动、复用钩子。
- **候选 B｜改宿主属性**（`offset_*` 属性 / 换 `MarginContainer`）：同 §3.1 候选 A/C 的陷阱与冗余 ⇒ 不优。

**▶ 推荐：候选 A**（`"margin"` → `margin_left=right=top=bottom=<原值>`，值不变）。

**布局影响面**：**可见变化（首次生效）** —— 各宿主四周内距从 0 → `GRID`（12 物理）或 `GRID×2`（24 物理）。**页面**：`page_explore`（TAB 历练）、`page_sect_manager`（宗主管理）⇒ **须重拍这两页**。

### 3.3 甲（`margin_*` 挂 `Label`）

**通用**：宿主 `Label` ⇒ 不在白名单 ⇒ `margin_*` 真死。`Label` 本身**无任何 margin 语义**。

- **候选 A｜把 `Label` 移入白名单容器**（包一层 `MarginContainer`，或放进一个 VBox 后再给 VBox `margin_*`）。
  - ⚠ **约束（须逐处判）**：`main.gd:6112 小标题()` **返回 `Label`** —— 调用点可能对返回值做 `.text` / `add_theme_color_override` 等 **`Label` 专属操作**；若改为返回包裹容器 ⇒ **返回类型变更、可能破坏调用点**。⇒ **需先盘点调用点**（`rg '小标题\('`）再定。
  - `page_quest.gd:1732 lab` 为函数内局部、**未对外返回** ⇒ 包裹**安全**。
- **候选 B｜改 `Control` 属性 offsets**：宿主 `Label` 的父为容器（VBox/Panel）⇒ **属性 offsets 被覆盖 ⇒ 无效**（同 §3.1 候选 A 陷阱）⇒ **不推荐**。

**▶ 推荐：候选 A（分治）**：
- `page_quest.gd:1738/:1739`（`lab`）：**包一层 `MarginContainer`（左右 = 12 逻辑 / 27 物理 / 18.0 frame）**，或等价地**给 `lab` 的父行加左右内距**。
- `main.gd:6117`（`小标题` 返回 `Label`）：**先盘点调用点**再在
  （i）**函数内包 `MarginContainer` 并改返回类型**（须调用点兼容），或
  （ii）**改由调用点补下间距**（在 `小标题(...)` 之后插入 4 物理 spacer）之间择一 → **列 §6 决策点**。

**布局影响面**：**可见变化（首次生效）** ——
- `page_quest` toast 文本左右内缩 **18.0 frame / 27 物理**（原 0）。
- `main.gd 小标题` 下间距 **4 物理 / 2.67 frame**（原 0）；**若改返回类型 ⇒ 首页布局须整体重拍**。

### 3.4 丙-c / 丙-d

**丙-c**：**盘上已修（0 处）⇒ 无改法**；建议标 **closed**。
**丙-d**：**前提不成立（0 处）⇒ 无改法**；建议标 **not-a-defect**；若老大坚持「统一 shadow 写法」，另立**风格批**（非本批）。

---

## §4 · 核验方案（**逐文件真渲染 ＋ 探针** · 禁像素差分当主判据）

### 4.1 方法与口径

- **主判据＝探针绝对量**：① 目标宿主**入树后的父链**（应出现 `MarginWrap` / `MarginContainer`）；② **`get_theme_constant` 回读**（键存在且值正确）；③ 目标控件 **`size` / 首屏内容起止 x**（应出现内距带宽）。
- **禁**：像素差分当**主**判据（承 07 §3：`S18`/`S25` 差分含实时内容、不可作判据）。
- **Godot 严格串行**；真实渲染**不加 `--headless`**（dummy 渲染器不出帧）。
- **辅助判据**（可选用）：结构带 / 近零行段（几何类）；**色族不计**（本批零改色）。

### 4.2 可证伪断言（「必须成立的数值关系」· 逐文件）

| 族 / 文件 | 断言（改后**必须成立**） |
|---|---|
| **丙-a · `page_faction.gd`** | 每块宿主入树后**父 ＝ `MarginContainer`（`MarginWrap`）**，且 `包.get_theme_constant("margin_left") == 原 `offset_left` 值`；卡片内容左起 x 内缩 ≥ `PAD_PANEL`（物理）。 |
| **丙-a · `page_zongmen_battle.gd`** | 同式（4 块）。 |
| **丙-a · `page_building.gd`（03）** | ★ `card_vbox` 内容四边内缩 **＝ 36 物理 / 24.0 frame**；**卡内无溢出**（子项 `size.x ≤ 卡内宽`）；03 帧重拍。 |
| **丙-b · `page_explore.gd`** | 5 处宿主父 ＝ `MarginContainer`，`margin_left == margin_right == margin_top == margin_bottom`（等距）＝ 原标量（`GRID` / `GRID×2`）。 |
| **丙-b · `page_sect_manager.gd`** | 同式（7 处）。 |
| **甲 · `page_quest.gd`（toast）** | `lab` 左起 x 相对父内缩 **＝ 27 物理 / 18.0 frame**（左右各一）。 |
| **甲 · `main.gd`（首页）** | 依 §3.3 选定方案后：**「小标题」下方间距 ＝ 4 物理 / 2.67 frame**，且**首页无布局回归**（重拍）。 |
| **丙-c / 丙-d** | **不改动 ⇒ 断言 ＝ 逐字节不变**（或明确标注为 closed / not-a-defect）。 |

### 4.3 已锁定帧页（改动后**须重拍 + 重验收**）

| 文件 | 页 | 锁定帧状态 | 处置 |
|---|---|---|---|
| `main.gd` | **首页** | 已交付·锁定 | **重拍**（若 甲·`小标题` 改返回类型 ⇒ 整体重拍） |
| `ui/page_building.gd` | **03 殿阁页** | 已交付·锁定 | **重拍**（S2 卡片内距首次生效） |
| `ui/page_disciple.gd` | 02 弟子页 | 已交付·锁定 | **不改动**（丙-c 已修 ⇒ 无需重拍） |

> 其余（`page_faction` / `page_zongmen_battle` / `page_explore` / `page_sect_manager` / `page_quest`）为长尾 / 07 批页 ⇒ **改后逐页重拍核对**即可。

---

## §5 · 风险与缓解

### 5.1 主要风险

| # | 风险 | 说明 | 缓解 |
|---|---|---|---|
| R1 | **布局会变（首次生效）** | 所有「静默忽略的间距」修后**首次生效** ⇒ 内容内缩，可能触发**换行 / 溢出 / 卡内挤压** | **分批 + 逐页真机重拍**；**先修简族（丙-b）**验流程；**03 卡片内距**单独慢验 |
| R2 | **`page_faction.gd` 44 处量大** | 单文件占 丙-a 的 **68.75%**（44/64） | **建议分两批**：① 面板级（`PAD_PANEL` 块，共 7 块=28 处）；② 卡片/条目级（`12/12/8/8` 块，共 4 块=16 处）；或按**区块**（`_build_scroll` / `_build_comprehensive` / …）切 |
| R3 | **候选 A 陷阱（§3.1/§3.3）** | `Control` 属性 offsets 在「容器父」下无效 ⇒ 若误选候选 A ⇒ **白改且有假阳性** | 统一走 **候选 B′/A（借钩子）**；核验断言以 **`MarginWrap` 父链**为准 |
| R4 | **`main.gd 小标题` 返回类型** | 包裹会改返回类型 ⇒ 可能破坏调用点 | 施工前 `rg '小标题\('` 盘点调用点；列 §6 决策 |
| R5 | **钩子依赖** | B′/A 依赖 `_入树_包边距` 运行期生效（**已被 07 v2.3 探针证实**：合成复现 `parent=MarginWrap class=MarginContainer`、边距 24 生效；真实挂载 `page_explore` 内容容器 `x=54 物理=24 逻辑×2.25`） | 保留该证据引用；**不改 `ui_theme.gd`** |
| R6 | **跨 run HUD/尺寸漂移** | 承 06 教训：跨 run 判读帧存在**非页面因素偏移**（HUD Y 等）⇒ 差分不可信 | 核验以**同 run 内探针**为准；帧作辅助 |
| R7 | **git autocrlf 折返（登记项 · 本批不处理）** | `git config core.autocrlf = true` 且**无 `.gitattributes`** ⇒ 工作区无 CR，但 **stage/diff 会转 CRLF** ⇒ 未来 `git status` / `diff` 行尾会「飘」（假全文件变更） | 本批**仅登记**；后续统一加 `.gitattributes`（`*.gd text eol=lf`）或设 `core.autocrlf=false`；**勿据转换后 diff 判改动面** |
| R8 | **门禁工具盲区（P2 · 预存 · 与 P0 无关 · 本批不修）** | `gdscript_type_check.py:60` 的 `re.match(r'^\w+\(', …) → 'call'` **排在** `:66 RAND_FUNC` 与 `:64 cast` **之前** ⇒ 裸 `randi()` / `randf()` / `int(n)` **永不走 RAND_FUNC/cast**、一律判 safe（**门3 #1 存在不可达分支**） | **先记不修**：把**调用形态判定移到 `randi`/`randf`/`int`/cast 之后**，或**先做白名单函数名匹配、再做通用 call 判定**。**影响面**：正控样本**禁** `randi()` / 裸标识符（会假 PASS），改用 `1 + 2` / `arr[0]` / `"%d" % n` |
| R9 | **工作区重量回涨（已实际发生）** | 09-17 实证 19,749→20,913 卡死 3h+；根因＝一次性外迁**无持续约束** | 已建五层机制：**L1** 外迁 `E:\Xiuxian\_taixuan_scratch\` / **L3** `ws_guard.py --offload` / **L4** automation 每 4h / **L5** 回传 ≤20 行；**批次收尾必跑 `ws_guard.py --check`**，管控线 **files<18000 & ctl<4000MB** |

### 5.2 分批建议

1. **批 1 · 丙-b（12 处 / 2 文件）**：最简、等距改写、范围小 ⇒ **先做，验流程与核验脚本**。
2. **批 2 · 丙-a 面板级（28 处 / 3 文件）**：`PAD_PANEL` 块。
3. **批 3 · 丙-a 卡片级（16 处 / 1 文件 page_faction）** ＋ **另 4 处 page_zongmen_battle + page_building**（可按需并入批 2）。
4. **批 4 · 甲（3 处 / 2 文件）**：待 §6 决策后。

### 5.3 回滚点方案（承既有 `before_*` 惯例）

- **备份命名**：`<file>.gd.before_fix<族>_<YYYYMMDD_HHMMSS>`（如 `page_faction.gd.before_fixca_20260918_101500`）。
- **粒度**：**逐文件**备份（非全局快照）；每批一份 **manifest**（文件 / md5 / 行数）。
- **回滚**：按 manifest 覆盖回退；**不改 `ui_theme.gd`** ⇒ 无共享面回滚需求。
- **不 add / 不 commit**（至老大放行）。

---

## §6 · 待批事项（**未批不施工**）

> 🔴 **本批未获老大批准前，一行代码不改、不起 Godot。** 以下为需老大拍板的决策点：

| # | 决策点 | 选项 | 工程建议 |
|---|---|---|---|
| **D1** | **丙-a 改法** | A（Control 属性） / **B′（改键名 `offset_*`→`margin_*`，借钩子）** / C（换宿主 `MarginContainer`） | **选 B′**：零结构改动、复用既有钩子、避 A 的「容器父无效」陷阱 |
| **D2** | **`page_faction.gd` 是否分两批** | 一次 44 处 / **拆两批（面板级 28 ＋ 卡片级 16）** | **拆两批**（R2：单文件量大、回滚与核验粒度更细） |
| **D3** | **丙-c 处置** | **直接移出（已修）** / 保留登记 | **移出并标注 closed**（盘上 0 处 · 02 批已修） |
| **D4** | **丙-d 处置** | **直接移出（非缺陷）** / 另立「shadow 风格批」 | **移出并标注 not-a-defect**（Label 合法键） |
| **D5** | **甲 · `main.gd 小标题` 处置** | (i) 函数内包 `MarginContainer` 并改返回类型 / (ii) 调用点补下间距 spacer | **已盘点（只读）**：`小标题(` **调用点 9 处**（`:1089 :1594 :2532 :2566 :2603 :4291 :4321 :4411 :6128`），定义 `:6112`。其中 **`:1594 var 题: Label = 小标题(...)` 为唯一强类型 `Label` 绑定** ⇒ 若改返回类型**须同步该处**。按 team-lead 规则（**>3 ⇒ 取 (i)**）⇒ **择 (i)，并同步改 `:1594`**；备选 (ii)（保持返回 `Label`、调用点补 4 物理 spacer）改动更小但仍 9 处。**待你最终拍（D5 属 甲 批，排期在目视后）** |
| **D6** | **排期** | 老大目视 01–06 之后 / 指定 | 按 §1.4 内部序：丙-b → 丙-a → 甲 |
| **D7** | **是否同步文档** | 07 §1.5.1/§2.2 ＋《总表》§2.1 同步「丙-c=0 / 丙-d=0 / 甲=3」 | **建议同步**（盘上真值以本规格 §2 为准） |

---

## 附 · 本规格自证

- **盘上零改动**（本轮只写本文件）；**未跑 Godot**；**未 git**。
- 清点**逐处给行号**（丙-a 16 块 64 键全列；丙-b 12 处全列；甲 3 处全列）。
- 引代码一律 **「函数名 ＋ `:行号`」双锚**（行号会漂）。
- 三处偏差（丙-c / 甲 / 丙-d）**均在 §2.0 明标**并附盘上实证。

---

## §7 · 批 1（丙-b）施工记录（**已施工 · 2026-09-17**）

> team-lead 开工令：**批 1 ＝ 丙-b（12 处 / 2 文件），现在做**（丙-a / 甲 排到老大目视之后）。本节记录落地与核验。

### 7.1 施工内容（裸键 `"margin"` → 4 条同值 `margin_left/right/top/bottom`）

**改法**：`"margin"` 为**标量单值**（无左右/上下之分，§2.2 判定「四周等距」）⇒ 等价改写为 **4 条同值**；宿主全 `VBoxContainer` ∈ 钩子白名单 ⇒ 入树钩子原包 `MarginContainer`(`MarginWrap`) 使内距生效。
**值不变**（`UITheme.GRID` = **12** / `UITheme.GRID * 2` = **24**，`ui_theme.gd:146`）。

| # | 文件（函数） | 改前 `:行号` | 改后区间 | 宿主 var | 新值（L/R/T/B） |
|---|---|---|---|---|---|
| 1 | `page_explore.gd`（`_build_main_area`） | `:138` | `138-141` | `left_vb` | `GRID`×4 = 12 |
| 2 | `page_explore.gd`（`_build_main_area`） | `:165` | `168-171` | `_detail_content` | `GRID`×4 = 12 |
| 3 | `page_explore.gd`（`_refresh_detail`） | `:582` | `588-591` | `card_vb` | `GRID`×4 = 12 |
| 4 | `page_explore.gd`（`_弹出奇遇弹窗`） | `:1395` | `1404-1407` | `内容` | `GRID*2`×4 = 24 |
| 5 | `page_explore.gd`（`_显示奇遇结果`） | `:1493` | `1505-1508` | `内容` | `GRID*2`×4 = 24 |
| 6 | `page_sect_manager.gd`（`_make_card`） | `:964` | `964-967` | `vb`（name=`VBox`） | `GRID`×4 = 12 |
| 7 | `page_sect_manager.gd`（`_populate_faction_power`） | `:2469` | `2472-2475` | `派系vb` | `GRID`×4 = 12 |
| 8 | `page_sect_manager.gd`（`_populate_memorial`） | `:2736` | `2742-2745` | `内` | `GRID`×4 = 12 |
| 9 | `page_sect_manager.gd`（`_构建请命卡`） | `:2832` | `2841-2844` | `内` | `GRID`×4 = 12 |
| 10 | `page_sect_manager.gd`（`_构建执行中卡`） | `:2888` | `2900-2903` | `内` | `GRID`×4 = 12 |
| 11 | `page_sect_manager.gd`（`_构建招募中卡`） | `:2933` | `2948-2951` | `内` | `GRID`×4 = 12 |
| 12 | `page_sect_manager.gd`（`_构建功勋兑换卡`） | `:3321` | `3339-3342` | `内` | `GRID`×4 = 12 |

> 行号：左为**改前**原始行，右为**改后**区间（后续行随 +3 漂移，逐处以盘上为准）。

### 7.2 承载文件指纹（改前 → 改后）

| 文件 | 改前 md5 | 改后 md5 | bytes | LF |
|---|---|---|---|---|
| `ui/page_explore.gd` | `1d6f0cd7f6a49e61e58195fcd46aafed` | **`1bd7f3e5570708d40a7239fbbb41f814`** | 71704 → 72777 | 1753 → 1768 (+15=5×3) |
| `ui/page_sect_manager.gd` | `45e28b61ae29f986033b073ba115eda2` | **`7afee07a2bd461d8266be0073b1c7417`** | 134869 → 136256 | 3563 → 3584 (+21=7×3) |

- **改前备份**（逐文件）：`ui/page_explore.gd.before_fix乙b_20260917_191614`、`ui/page_sect_manager.gd.before_fix乙b_20260917_191614`（CR 0 · noBOM）。
- **另 1 文件（测试搭车探针）**：`tests/ui_full_accept.gd` 加 `_probe_pfix_b1()` ＋ 2 处调用（`TAB_历练` / `SUB_宗主管理`）——**搭车探针，不新增 .gd**（承 02–05 批惯例）。
- `ui_theme.gd` **未改**；`.tscn`/`.csv`/资产 **未动**。

### 7.3 门禁与真实渲染（禁像素差分当主判据）

- **`gate_all.py` → EXIT 0**（门0–门6 全 PASS；门1 `ALL GDScript PARSE OK (269 files)`；门6 P0=0；死函数 376/376）。
- **`run_headless_chain.py` → 异常 0 / 7**（import/compile_all/main_enter/ui_compile/ui_decouple/smoke/gate_all 全 exit=0）。
- **`ui_compile` 编译失败 0**：`>>> 扫描 ui/*.gd 83 个  编译失败 0`（`UIC_EXIT=0`）；`compile_all` 另证 `全项目 .gd 177 个 编译失败 0`。
- **真实渲染**（非 headless · 账号冻结档 `profiles/acc_full` = `e1c9b38eb3db790cb940556ac16d5ccd`，跑前跑后一致）：
  - AFTER 帧 → `.workbuddy/_pfix_b1/after/`（64 PNG，EXIT=0）；BEFORE 帧 → `.workbuddy/_pfix_b1/before/`（64 PNG，EXIT=0）。
  - ★ **帧为跨 run 变体**（同代码两次 before 帧 md5 即不同：`47e990f0…` vs `67ad5c38…`）⇒ **不作判据**（R6 已列）；判据取**结构探针绝对量**（下）。

### 7.4 探针绝对量（BEFORE vs AFTER · 同一 harness）

搭车探针 `_probe_pfix_b1` 枚举「margin 宿主」（裸键 `"margin"` / 带前缀 `margin_*`）＋ 父链 ＋ `MarginWrap` 计数：

| 页 | 指标 | BEFORE | AFTER | Δ |
|---|---|---:|---:|---:|
| **TAB_历练**（`page_explore`） | 裸键 `"margin"` 计数 | **2** | **0** | −2 |
| | 带前缀 `margin_*` 计数 | 3 | 7 | +4 |
| | `MarginWrap` 计数 | 1 | 3 | +2 |
| | `_detail_content.get_parent()` | `@PanelContainer` | **`MarginWrap`/`MarginContainer`** | — |
| **SUB_宗主管理**（`page_sect_manager`） | 裸键 `"margin"` 计数 | **1** | **0** | −1 |
| | 带前缀 `margin_*` 计数 | 4 | 6 | +2 |
| | `MarginWrap` 计数 | 1 | 2 | +1 |
| | `card.get_child(0)` | `VBox`/`VBoxContainer` | **`MarginWrap`/`MarginContainer`** | — |

- 被包裹宿主的 `get_parent()` 回读边距 = **12 / 12 / 12 / 12**（＝ `GRID`）—— 与 §7.1 设定值一致（实测，非读码）。
- **逐处核验状态**：本批 12 处**同机制**；真渲染默认视图**实际实例化并实测**者 = `left_vb` / `_detail_content`（explore）＋ `_make_card vb`（sect）＝ **3 处探针直证**；其余 9 处（explore `card_vb`/`内容`×2 属「进行中卡/奇遇弹窗」；sect `派系vb`/`内`×5 属**非默认 tab**）**默认视图未实例化** ⇒ 仅有**代码级同机制证据**（同钩子 · 同键名 · 同宿主类）。**如需 12/12 全实测，须扩 harness 切 tab / 触发弹窗（另立范围）。**
- ⚠ **澄清 team-lead 口述「MarginWrap 出现计数 == 本批改动处数」**：**不等于 12** —— `MarginWrap` 增量 = **本页运行期实际实例化的改动处数**（explore +2、sect +1）。12 是**代码处数**，非运行期节点数（承 §3.0 副作用记账）。

### 7.5 断言核验（「必须成立的数值关系」）

| 断言 | 结果 |
|---|---|
| 各页裸键 `"margin"` 计数 **改后 = 0** | ✅（explore 2→0、sect 1→0） |
| 被包裹宿主 `get_parent()` **＝ `MarginContainer` 名 `MarginWrap`** | ✅ |
| 包裹层 `margin_left/right/top/bottom` **＝ 原值**（12 或 24） | ✅（实测 12/12/12/12） |
| `card.get_child(0)` **由 `VBox` 变 `MarginWrap`** | ✅ |
| `card.get_node("VBox")`（34 处，**均在入树前**调用）**不被包裹破坏** | ✅（结构未改调用时序：`get_node` 恒在 `_content.add_child(card)` 之前） |
| `ui_theme.gd` **逐字节不变** | ✅（未纳入本批改动） |

### 7.6 状态

**未 add · 未 commit**；改前备份就绪（可一键回滚）；**Godot 严格串行**。

---

## §8 · 收口补完（**追加式** · 2026-09-17 · 承 team-lead 裁定）

> **本节为追加式补完**，**不改动 §0–§7 任何既有文字**。两项：**(A) 机制漏引补全**（补 §0.2 机制口径 ＋ §3.1 / §3.2 副作用栏）；**(B) D1 两前置条件逐块判定结论**（补 §2.8 / §3.0 的「逐块结论」形态）。
> **来源**：team-lead「丙-b 四项全裁」＋ `.workbuddy/_ph7vis/QUERYFIX_第二方复算_20260917_192530.md`（art-director 第二方独立复算）。
> **只读依据**：直读 `ui_theme.gd:2064-2104`；三承载文件宿主声明行；盘上指纹见 §8 末。

### 8.1 ★ 机制漏引补全：钩子包裹后**强制改写宿主自身 `size_flags`**（承 team-lead ⑥-1）

> **补 §0.2（机制口径）与 §3.1 / §3.2（候选改法 · 副作用栏）之缺引。** 规格原仅引 `ui_theme.gd:2078-2079`（把宿主 `size_flags` **平移**给包裹 `MarginWrap`），**漏引 `:2103-2104`**。

**盘上原文（`ui_theme.gd` · 逐字）**：

```gdscript
# :2067 _包边距_延迟(c)
包.name = "MarginWrap"                                          # :2074
包.size_flags_horizontal = c.size_flags_horizontal             # :2078  ← 规格 e 已引（平移给「包」）
包.size_flags_vertical   = c.size_flags_vertical                # :2079
父.remove_child(c); 父.add_child(包); 父.move_child(包, 位); 包.add_child(c)   # :2098-2102
c.size_flags_horizontal = Control.SIZE_EXPAND_FILL              # :2103  ★漏引：覆写「宿主自身」
c.size_flags_vertical   = Control.SIZE_EXPAND_FILL              # :2104  ★漏引
```

**副作用定性**：包裹完成后，钩子**无条件把宿主 `c` 自身的 `size_flags_horizontal/vertical` 覆写为 `SIZE_EXPAND_FILL`** ⇒ **宿主原本的 `size_flags` 被静默丢弃**。（`ui_theme.gd:2065` 注释称「整体平移原节点 `size_flags` … 对布局零副作用」——**该断言仅对「包」成立，对「宿主自身」不成立**。）

**对丙-b 12 处（及丙-a 16 块）的实际影响**：
- 本批宿主（`page_explore` 5 ＋ `page_sect_manager` 7）**父均为 `Container`**（`PanelContainer` / `ScrollContainer` / `VBoxContainer`）⇒ **父容器恒按自身规则排布子项**，宿主是否 `EXPAND_FILL` **在本批场景观察不到差异**（与第二方复算 `§5` 结论一致）。
- **但属「布局影响面（潜在）」**：若将来把本机制套到「**父为非容器**」或「**宿主靠 `SHRINK_BEGIN/CENTER` 定位**」的场景，`:2103-2104` 会成为**可观察**的行为改变 ⇒ **候选 B′（§3.1）/ 候选 A（§3.2）之副作用栏必须记此条**，否则易被误判为「零副作用」。

**处置**：本条为**机制事实补录**（**非本批改动面**）⇒ **不改 `ui_theme.gd`**；仅补入 §3.1 / §3.2 副作用栏。

### 8.2 ★ D1 两前置条件 · **逐块判定结论**（承 team-lead ⑥-2）

> 补 §2.8 / §3.0 的「**逐块判定结论**」形态（§3.0 已含 16 行表；本节给**逐块「是否满足」＋ 第二方对账**）。

**前置 1｜宿主 class 逐块判定（16 块 · 逐块直读 · 盘上 2026-09-17 · 判定口径：声明行 `= <Class>.new()`）**

| # | 文件 | 宿主 var（声明行） | 该类 | 满足 ∈{`VBox`,`HBox`,`Grid`}？ |
|---:|---|---|---|:---:|
| 1 | `page_faction.gd` | `弟子阵营vbox`（`:161`） | `VBoxContainer` | **是** ✅ |
| 2 | `page_faction.gd` | `vbox`（`:220`） | `VBoxContainer` | **是** ✅ |
| 3 | `page_faction.gd` | `vbox`（`:285`） | `VBoxContainer` | **是** ✅ |
| 4 | `page_faction.gd` | `item_vbox`（`:317`） | `VBoxContainer` | **是** ✅ |
| 5 | `page_faction.gd` | `vbox`（`:345`） | `VBoxContainer` | **是** ✅ |
| 6 | `page_faction.gd` | `vbox`（`:508`） | `VBoxContainer` | **是** ✅ |
| 7 | `page_faction.gd` | `vbox`（`:623`） | `VBoxContainer` | **是** ✅ |
| 8 | `page_faction.gd` | `NPCvbox`（`:782`） | `VBoxContainer` | **是** ✅ |
| 9 | `page_faction.gd` | `vbox`（`:831`） | `VBoxContainer` | **是** ✅ |
| 10 | `page_faction.gd` | `dialog_vbox`（`:869`） | `VBoxContainer` | **是** ✅ |
| 11 | `page_faction.gd` | `NPCvbox`（`:922`） | `VBoxContainer` | **是** ✅ |
| 12 | `page_zongmen_battle.gd` | `vbox`（`:212`） | `VBoxContainer` | **是** ✅ |
| 13 | `page_zongmen_battle.gd` | `vbox`（`:296`） | `VBoxContainer` | **是** ✅ |
| 14 | `page_zongmen_battle.gd` | `vbox`（`:384`） | `VBoxContainer` | **是** ✅ |
| 15 | `page_zongmen_battle.gd` | `vbox`（`:470`） | `VBoxContainer` | **是** ✅ |
| 16 | `page_building.gd` | `card_vbox`（`:325`） | `VBoxContainer` | **是** ✅ |

**▶ 前置 1 结论：16 / 16 满足**（**逐块判定，非抽样**）⇒ **B′ 对全部 16 块成立；无一块需改走候选 C。**

**前置 2｜父链 / 索引 / 兄弟序 / 名路径依赖 —— 逐文件判定**

| 文件 | 扫描命中 | 是否触及任一宿主 | 满足（扫清）？ |
|---|---|---|---|
| `page_faction.gd` | **0 命中**（全文件亦无 `get_node`） | — | **是** ✅ |
| `page_zongmen_battle.gd` | 1 处 `:566 get_node_or_null("MarginRoot/VBoxContainer/HeaderBar/HBoxContainer/JiyuanLabel")` | **否**（路径**陈旧恒 `null`**，5 段无一指向 4 宿主） | **是** ✅ |
| `page_building.gd` | 5 处（`:538 :1404 :1573 :2073 :2076`，均为 `_拖动控件` / `_list_vbox` / `_yushou_vbox` / `Tab_*` / `_header_holder`） | **否**（**无一处＝宿主 `card_vbox`**；且全文件无 `get_node("CardVBox")`） | **是** ✅ |

**▶ 前置 2 结论：三文件全部命中均**不触及**任一宿主 ⇒ 前置 1、前置 2 **双双满足** ⇒ **B′（借钩子）安全，无调用点破坏。**

**第二方对账（`.workbuddy/_ph7vis/QUERYFIX_第二方复算_20260917_192530.md` · art-director 独立直读）**：
- 前置 1：**16 / 16 一致**（无差异）；
- 前置 2：**逐文件一致**（faction 0 · zongmen_battle 1 陈旧死查找 · building 5 命中均非宿主）；
- 差异仅 **1 项「补全性」** ⇒ 即 §8.1 的 `ui_theme.gd:2103-2104`（**非矛盾**）。
⇒ **两方结论一致 ＋ 1 项补全；无相互矛盾项。**

**本节自证**：**追加式**（未改 §0–§7）；未改任何 `.gd`；未起 Godot；未 git。

### 8.3 ★ §7.1「改后」行号列更正（盘上实测 · **追加式**）

> ⚠ **§7.1 表右列「改后区间」系统性少计插入漂移** —— `"margin"`（1 键）→ `margin_*`（4 键）每处 **+3 行**，同文件内**逐处累加**；§7.1 右列未正确累加 ⇒ **12 行中 7 行错**。**以盘上实测为准**（本节即时逐处复核 `rg 'margin_left'`）：

| # | 文件 | 宿主 var | §7.1 原标「改后」 | **盘上实测（AFTER · 即时复核）** | 偏移 |
|---:|---|---|---|---|---|
| 1 | `page_explore.gd` | `left_vb` | `138-141` | **`138-141`** | ✓ |
| 2 | `page_explore.gd` | `_detail_content` | `165-168` | **`168-171`** | −3（少计） |
| 3 | `page_explore.gd` | `card_vb` | `585-588` | **`588-591`** | −3 |
| 4 | `page_explore.gd` | `内容`（奇遇弹窗） | `1404-1407` | **`1404-1407`** | ✓ |
| 5 | `page_explore.gd` | `内容`（奇遇结果） | `1505-1508` | **`1505-1508`** | ✓ |
| 6 | `page_sect_manager.gd` | `vb` | `964-967` | **`964-967`** | ✓ |
| 7 | `page_sect_manager.gd` | `派系vb` | `2469-2472` | **`2472-2475`** | −3 |
| 8 | `page_sect_manager.gd` | `内`（`_populate_memorial`） | `2736-2739` | **`2742-2745`** | −6 |
| 9 | `page_sect_manager.gd` | `内`（`_构建请命卡`） | `2832-2835` | **`2841-2844`** | −9 |
| 10 | `page_sect_manager.gd` | `内`（`_构建执行中卡`） | `2888-2891` | **`2900-2903`** | −12 |
| 11 | `page_sect_manager.gd` | `内`（`_构建招募中卡`） | `2933-2936` | **`2948-2951`** | −15 |
| 12 | `page_sect_manager.gd` | `内`（`_构建功勋兑换卡`） | `3321-3324` | **`3339-3342`** | −18 |

> ⇒ **纪律**：本规格此后凡涉**改后定位，一律「内容特征 ＋ 即时 `rg` 复核行号」双锚**（行号会漂，内容特征不漂）。§7.1 左列「改前原始行」不受影响。

---

## §9 · 收口（丙-b · 主判据定稿 ＋ 帧轴升格定量 ＋ 帧映射更正 · **追加式** · 2026-09-17 · 承 team-lead Task#86b-B）

> **重号消歧 + 插入史（2026-09-17 · team-lead 裁定）**：紧随其后的 **§9b** 为工程侧原 append，因**本节插入**而顺延至其后 ⇒ **块序 ≠ 时序**。两节互补、合读方为完整收口。

> **追加式**补完，**不改 §0–§8 任何既有文字**。三件事：**(A) 主判据 C 口径定稿**；**(B) 帧轴由「仅方向性」升格「定量吻合」——独立复算 `+8 帧px = GRID(12) × 0.666667` 成立（精确 8.00）**；**(C) 帧映射更正**（`page_explore.gd` ↔ `TAB_历练.png`，非 `S04_入山采撷.png`）。
> **两路并取（非二选一）**：(B) 的算术链为 engineering-lead **自算**；verifier 独立带测（`.workbuddy/_vrf/`）另列，二者互证。

### 9.1 主判据（C 口径 · 定稿 · **不依赖帧**）

| 判据 | 断言 | 结果 |
|---|---|---|
| ⓐ 机制生效 | 两页裸键 `"margin"` 计数 **改后 = 0** | ✅（explore 2→0、sect 1→0） |
| ⓑ 静态 12/12 | 12 处均 `"margin"` → 4 键同值、值等价 | ✅（verifier 独立复算 12/12；最小包围盒 diff = replace 12 / delete 0 / insert 0 / 非 margin hunk 0） |
| ⓒ 宿主∈白名单 | 12 处宿主全 `VBoxContainer` | ✅（verifier 独立复算 12/12） |

**可观测上限 = 5**：默认视图仅实例化 explore `left_vb` / `_detail_content` ＋ sect `_make_card vb` 等 = 探针直证 **5** 处；其余 7 处（explore `card_vb` / `内容`×2 属进行中卡 / 奇遇弹窗；sect `派系vb` / `内`×5 属**非默认 tab**）默认视图**未实例化** ⇒ 仅**代码级同机制证据**。

### 9.2 帧轴：由「方向性佐证」升格「定量吻合」

> 原口径（§4.1 / §7.3）「帧不作主判据，仅结构探针」**保持不变**（跨 run 变体 ⇒ 禁**裸**像素差分当主判据）；但**分带 ＋ 刚性对齐**后帧轴**恢复定量判别力** ⇒ 本节**追加**定量结论。

**(1) 三空间（盘上实证）**

| 空间 | 尺寸 | 来源 |
|---|---|---|
| 设计基准（逻辑） | 480×854 | `ui_theme.gd:143` |
| 渲染 / viewport | **1080×1920** | `project.godot:46-47` `window/size/viewport_*` |
| 窗口 / 帧 PNG | **720×1280** | `project.godot:48-49` `window_*_override`；**64 帧实测全 720×1280** |

换算因子：设计→渲染 = 1080/480 = **2.25**（= `UI_SCALE`，`ui_theme.gd:145`）；渲染→帧 = 720/1080 = **2/3 = 0.666667**（1080/1920 与 720/1280 同比，各向同性）；设计→帧 = 720/480 = **1.5**。

**(2) 独立复算（engineering-lead 自算 · 不引他方算术）**

三条候选路径（V = `GRID` = 12）：

| 路径 | 解释 | 值 | 命中观测量 +8？ |
|---|---|---|---|
| A | 12 属**设计**空间 → ×1.5 | **18.0000** | ✗ |
| B | 12 属**渲染 / viewport** 空间 → ×0.666667 | **8.0000** | ✅ |
| C | 12 已在**帧**空间 → ×1 | 12.0000 | ✗ |

`12 × 720/1080 = 8.0000`（＝`12 × 2/3`，**整除、无舍入**）；`12 × 0.6667 = 8.0004`（四舍五入值差 4e-4）。
▶ **`+8 帧px = GRID(12) × 0.666667` → 成立（精确 8.00）**；且**判别力充分**：路径 A（设计空间 = 18）与路径 C（= 12）**均被观测排除**。

**(3) 实测（engineering-lead 独立 2D 刚性搜索 · PIL · 只读）**

对 `TAB_历练.png`（before / after 同 harness）做 **2D SSD 平移搜索（±12）**：

| 区域 | best (dx,dy) | meanSSD | 判别 |
|---|---|---|---|
| 左上「太玄宗」logo | **(0,0)** | **0.00** | 逐像素相同（未动） |
| 顶栏时间牌 | **(0,0)** | **0.00** | 未动 |
| **左面板卡片文本区** x[18,300] y[242,512] | **(+8,+8)** | **0.00** | **刚性平移 +8,+8（精确）** |
| 底部 Tab 栏 | (0,0) | 7.63 | 未动（±1 邻域 ≥418） |

- **(+8,+8) 处 meanSSD = 0.00**：after 帧该区 = before 帧**精确平移 (+8,+8)**（无抗锯齿残差）；邻域 (+7,+8)/(+9,+8)=305、(+8,+9)=578 ⇒ **极小值唯一且尖锐**。⇒ 位移**精确 +8 帧px、两轴皆然**（`margin_left/right/top/bottom` 四键同值 ⇒ 左＋上 各内缩 8）。
- **方法判别力自证**：logo / 顶栏 / Tab 栏 = **(0,0)**，卡片内容 = **(+8,+8)** ⇒ 该方法**能区分「该动 / 不该动」**。

**(4) verifier 独立带测（第二路 · `.workbuddy/_vrf/` · 独立复算）**

- `TAB_历练` y[265-615] best **(+8,+8)**（残差 6.52 vs (0,0) 28.35，**降 77.0%**）；`S13_宗主管理` y[400-700] best **(+8,+8)**；
- **全 64 对帧 best == (+8,+8) 者仅 `TAB_历练` 一帧**（唯一性）；对照页 `S04_入山采撷` best (0,0) = 0.0000。

▶ **两路一致、互证**。综合结论：**丙-b 帧证据由「方向性」升格「定量吻合」**（刚性 (+8,+8) 精确 = `GRID × 0.666667`），且**唯一性**成立。

**(5) 底噪口径更正（承 verifier）**：**不再用**「整帧 `mean|Δ|` 中位 0.0284」当门槛（该数被少数重噪页拉高）；**正确姿势 = 先 (dx,dy) 刚性对齐、再看残差**（对齐后大量未改动帧残差 = 0.0000）。

### 9.3 帧映射更正（★ 写入规格 · 承 team-lead ③）

| 页 | 脚本 | **正确帧** | 错误帧（弃用） |
|---|---|---|---|
| 历练（Tab） | `ui/page_explore.gd` | **`TAB_历练.png`** | ~~`S04_入山采撷.png`~~ |
| 宗主管理（二级页） | `ui/page_sect_manager.gd` | **`S13_宗主管理.png`** | — |

**锚**：`ui/game_ui.gd:278`（`"历练" → PageExploreScene`）；`tests/ui_full_accept.gd:119`（Tab 页 → `TAB_%s.png`）、`:174`（二级页 → `S%02d_%s.png`）。
▶ `S04_入山采撷` 是**二级页**（属 `page_hunt.gd`），**非** `page_explore`。凡按 `S04` 判丙-b 效果者一律更正。

### 9.4 证据边界（防口径失真）

1. **`GRID*2 → +16` 从未被观测**：explore 两处 `GRID*2`（`内容` · `:1404` / `:1505`）在**奇遇弹窗**内，本批 64 帧未打开该弹窗 ⇒ **只有 `GRID → +8` 那一半被定量证实**，**勿写成「12 处全部帧验」**。
2. **面板左缘 Δ = 0**：卡片面板左缘两帧均 `x = 16`、Δ = 0（engineering-lead 独立复现）——被包裹者是**面板内**内容，**面板本身不动**。
3. **单位链命名注意**：`GRID` 在 `ui_theme.gd` 内**绝大多数按渲染系裸用**（`set_content_margin_all(GRID)` `:621/631/…`、`separation, GRID` `:2600`）；**唯一例外** `:1819` 用 `GRID*1.5*UI_SCALE`（疑双重缩放；**非本批改动面，仅登记为观察项**）。⇒ 本批 `margin_*` override 按**渲染系裸值 12** 生效（探针回读 12/12/12/12），故帧上 **8.00** 成立。

### 9.5 本节自证

**追加式**（未改 §0–§8）；本文件外**零改动**（本轮）；未起 Godot；未 git。绑定指纹：
`ui/page_explore.gd` = `1bd7f3e5570708d40a7239fbbb41f814`（72777B/LF1768）；
`ui/page_sect_manager.gd` = `7afee07a2bd461d8266be0073b1c7417`（136256B/LF3584，**丙-b-P0 补丁前态**）；
`ui_theme.gd` = `7ddd01fd433550e6735e2f6dd1b2274f`（逐字节未改）。

---

## §10 · 丙-b-P0 补丁记录（34 处 `find_child` 化 · **追加式** · 2026-09-17）

> **独立小批**，与 §7–§9 丙-b **分开记账**。**落盘时刻 2026-09-17 20:04:06**（**并发第二实例**执行）；engineering-lead **独立校验一致**（byte-identical）。

### 10.1 改动

- 文件：`ui/page_sect_manager.gd`；规则：**`X.get_node("VBox")` → `X.find_child("VBox", true, false)`**（`owned` **必须 `false`**：代码创建节点 `owner==null`，默认 `true` 查不到）；处数 **34**（机械 1:1 **同行**替换）。
- 指纹：`7afee07a2bd461d8266be0073b1c7417`（136256B/LF3584）→ **`5f5a98249a4bc720c8fb1870b702b569`（136766B/LF3584）**；**+510B = 34×15**；**LF 不变**、CR0、noBOM。
- 备份：`ui/page_sect_manager.gd.p0bak_20260917_200406`（＝`7afee07a…`，**P0 前态**）。

### 10.2 契约（verifier 34/34 逐处审计）

> `<卡片>.get_node("VBox")` **仅在 `<卡片>` 进入场景树之前**有效。`add_child(card)` 之后的**同一同步块内**查询仍安全（deferred 未跑）；**任何跨帧、或同帧但晚于 deferred** 的查询**必然失败**（此时 `<卡片>` 直接子已为 `"MarginWrap"`）。

34 处**今天安全的保证类型 = (a)**：形态为 `var card := _make_card(...)` 的**下一行立刻** `card.get_node("VBox")`，而 `add_child(card)` 在**其后很远**；「赋值→查询」间 `await = 0`（34/34）⇒ 查询在**卡片入树之前**、`tree.node_added` 从未触发 ⇒ **本补丁为防御性，非「已在悬崖边」**（风险等级可下调，契约仍须登记）。
全仓 269 `.gd` 中 `get_node/find_child/has_node("VBox")` **仅在本文件**（34 处，**无外溢**）；本文件 `get_child(0)` = **0**。

### 10.3 等价性

未包裹态：`find_child("VBox", true, false)` 返回**同一节点**（`card` 直接子即 `"VBox"`）；已包裹态：**穿透 `MarginWrap`** 命中同一 `"VBox"` ⇒ **严格更宽松、向后兼容、今天行为零变化**。

### 10.4 验收

- **静态**：`get_node("VBox")` = **0**、`find_child("VBox", true, false)` = **34**（P0 后态）；**逐行替换施加于 `p0bak` 后 md5 == 盘上 md5（byte-identical）**；行数 **3585 不变**、内容不同行数 **= 34**。
- **`gate_all.py` = EXIT 0**（门0–门6 全 PASS；门1 `ALL GDScript PARSE OK (269 files)`；门6 P0=0）。
- **`run_headless_chain.py`**：`import` / `compile_all` / `main_enter` / **`ui_compile`** 均 **exit=0**；`compile_all`：`全项目 .gd 177 个  编译失败 0`；`ui_compile`：**`扫描 ui/*.gd 83 个  编译失败 0`**。（链在第 5 步前被**外部超时 SIGTERM**——**非闸门失败**；`ui_decouple` / `smoke` 未跑。）
- **探针**：`tests/_probe_margin_hook.gd:76` `_找名(p2, "VBox", …)` 为**按名递归**（`String(n.name) == 名` 后遍历子孙），**路径无关** ⇒ 包裹后仍命中，**无需改**（原「须改 `find_child`」的担心**不成立**）。
- **证据**：`.workbuddy/_pfix_p0/`（after 副本 ＋ `manifest_P0.json` ＋ gate/chain 日志 ＋ 进程计数）。

### 10.5 本节自证

未 add、未 commit；未改 `ui_theme.gd`；**Godot 串行**（跑前 **20:09:41 COUNT=0**、跑后 **20:17:05 COUNT=0**，无孤儿）。

---

## §9b · 丙-b 收口（**追加式** · 2026-09-17 · 承 team-lead 裁定 Task#86b-B）

> **重号消歧 + 插入史**：本节写于 §9 **之前**，因 §9 由另一写入者**插入**而被下推。两节互补：§9 独有「`GRID*2 → +16` 从未被观测」，§9b 独有「探针 `:76` 无需改」与完整指纹表。

> **追加式**：本节不改 §0–§8 任何既有文字。承 team-lead「丙-b 静态轴 CLOSED ＋ 帧映射更正 ＋ `+8` 定量复算」令。
> **自证**：本节只写本文件；**未改任何 `.gd`**；**未起 Godot**；**未 git**。

### 9b.0 收口口径（C 口径）

- **主判据（三项合取）**：ⓐ 机制生效 ＝ 各页裸键 `"margin"` 计数 **改后 = 0**；ⓑ 静态 **12/12** 改对（4 键同值）；ⓒ 宿主 **12/12 ∈ 钩子白名单**（`VBoxContainer`）。
- **可观测上限 = 5**：运行期「默认视图」下实际实例化的 `MarginWrap` 总数 = **5**（explore 3 ＋ sect 2；其中本批新增 2＋1＝3）。
  - ⚠ **12 是「代码处数」，5 是「运行期可观测数」**——二者**非同量**，勿混。
- 本批 12 处**同机制**；默认视图未实例化者（explore 的 `card_vb`/`内容`×2；sect 的 `派系vb`/`内`×5）仅有**代码级同机制证据**（同钩子 · 同键名 · 同宿主类）。

### 9b.1 ★ 帧映射更正（**必须**）

- **`ui/page_explore.gd` ↔ `TAB_历练.png`**（**不是** `S04_入山采撷.png`）。
  - 链路：`ui/game_ui.gd:278`（tab「历练」→ `PageExploreScene` ＝ `page_explore.gd`）＋ `tests/ui_full_accept.gd:115-119`（按 `TABS` 逐 tab `_show_page` 后 `_shot("TAB_%s.png" % tab)`）。
- **`S04_入山采撷.png` 系二级页命名**（`tests/ui_full_accept.gd:174` `_shot("S%02d_%s.png" % [idx, id])`）；「入山采撷」属 `page_hunt.gd` 范畴（`main.gd:953 _填_入山采撷页`），**与 `page_explore` 无关**。
- `page_sect_manager.gd` 对应帧 = **`S13_宗主管理.png`**（二级页「宗主管理」，`tests/ui_full_accept.gd:172-174`）。
- ⇒ **凡按 `S04_入山采撷.png` 判丙-b 效果者，一律更正为 `TAB_历练.png`。**

### 9b.2 ★ `+8` 定量复算（**独立自算** · 本批最高价值增量）

**（A）三空间与因子（自算，未引 verifier / team-lead 算术）**

| 空间 | 宽度 | 来源 | 到 frame 的因子 |
|---|---:|---|---:|
| 逻辑 / 设计基准 | 480 | `ui_theme.gd:143`（设计基准 `480×854`） | 720/480 = **1.5** |
| 渲染 / viewport | 1080 | `project.godot:46` `viewport_width`（＝480×2.25 = `UI_SCALE`） | 720/1080 = **2/3 = 0.666667** |
| frame（窗口） | 720 | `project.godot:48` `window_width_override` | 1 |

**（B）GRID 所在空间**：`ui_theme.gd:144` 明称 GRID 为「**派生渲染系常量**」；且本批 12 处 override 以**裸 `GRID`** 施于 `MarginContainer`（`:2075-2077` 原值转抄）⇒ **GRID 属渲染 / viewport 系**。

**（C）换算**：
- `12 × 2/3 = **8.00**`（**精确**；2/3 为精确分数）⇒ 与观测 **+8 帧px** 吻合。
- **反证**：若 GRID 属**逻辑系** ⇒ `12 × 1.5 = **18**`（等价 `12×2.25×2/3 = 18`）≠ 8 ⇒ **逻辑系不成立**。

**（D）自测（独立、非引他人算术）** —— 对 `.workbuddy/_pfix_b1/{before,after}/TAB_历练.png` 做 **2D 平移检验（SSD 最小化，搜索 ±12）**：

| 分区（frame 720×1280） | patch (x0,y0)-(x1,y1) | 最佳 (dx,dy) | meanSSD |
|---|---|---:|---:|
| **卡片文本区**（左面板） | (18,242)-(300,512) | **(+8,+8)** | **0.00** |
| 左上 logo 区（对照 · 应不动） | (18,40)-(200,110) | (0,0) | 0.00 |
| 顶栏时间牌（对照 · 应不动） | (200,40)-(300,110) | (0,0) | 0.00 |
| 底部 Tab 栏（对照 · 应不动） | (40,1150)-(660,1240) | (0,0) | 7.63 |

- 卡片文本区在 **(dx,dy)=(+8,+8)** 处 **meanSSD = 0.00（逐像素精确平移）**；邻域 (±1) 迅速退化（`(7,8)/(9,8)→305`、`(8,9)→578`）⇒ **极小点尖锐唯一**。
- 对照区均 **(0,0)**（且 SSD≈0）⇒ **方法具判别力**：证明 before/after **仅差「被 margin 影响的内容」的 `(+8,+8)` 平移**。
- **面板左缘 `x=16`，两帧 `Δ=0`**（独立复现 team-lead 基线）。
- **x / y 两轴各 +8** ⇒ 与「四键同值 `12`（左/右/上/下）」一致（`margin_top` 亦致 **+8 下移**）。
- `page_sect_manager`（`S13_宗主管理.png`）瓦片位移图在卡片区亦见 **(+8,+8)**（整体场更杂，因**逐卡包裹 → 列表回流**；与其机制相符）。

**▶ 结论：`+8 帧px = GRID(12) × 0.6667` —— 成立（精确 `= 8.00`；2D 平移检验 `(dx,dy)=(+8,+8)` 处 `meanSSD=0.00`）。**
⇒ 丙-b **帧证据由「方向性佐证」升级为「定量吻合（精确）」**。

**与 verifier「分带平移检验最佳位移恒 (0,0)」的关系（不矛盾）**：band 级被**不移的版面**（面板边框 / 顶栏 / 底栏）主导 ⇒ `(0,0)`；本地 patch **隔离出**被 margin 影响的内容 ⇒ `(+8,+8)`。二者**作用域不同** ⇒ 页级定量在**单页本地 patch** 下可达 `SSD=0`。

**（E）备注（单位命名观察 · 非本批改动面）**：`ui_theme.gd:1819` 是全文件**唯一**把 GRID 再乘 `UI_SCALE` 之处（`int(GRID * 1.5 * UI_SCALE)` = 40）；本批 override 则用**裸 GRID**。二者对「GRID 是否需 ×UI_SCALE」**口径不一致** ⇒ 记为**观察项（潜在 P 项）**。**不影响本批**（本批为「值保持」等价改写）。

### 9b.3 静态轴：直接引用 verifier 独立复算（**不重复论证**）

采信 verifier 独立复算**全绿**：**12/12 改对 · 裸键 0 残留 · 反向核 before 全裸键 · 值等价 · 最小包围盒 diff（replace 12 / delete 0 / insert 0 / 非 margin hunk 0）· 字节账闭合（explore +1073 B / sectmgr +1387 B）· 宿主 12/12 ∈ 白名单 · 入树顺序 12/12 晚于 override 四行**。绑 AFTER 指纹见 §9b.5。

### 9b.4 帧轴定性基线（按 verifier 定性）

- 全量 **64 对帧**：**不具定量判别力、仅作方向性佐证** —— 仅 **2/64** 帧逐像素相同；`mean|Δ|` 中位 **0.0284**（P75 0.3106 / P90 1.1161 / max 4.6888）。
- （§9b.2 的**单页本地 patch** 例外：达 `SSD=0` ⇒ **页级定量在该页可用**。）

### 9b.5 收口时点文件指纹

| 文件 | md5 | bytes | LF | 备注 |
|---|---|---:|---:|---|
| `ui/page_explore.gd` | `1bd7f3e5570708d40a7239fbbb41f814` | 72777 | 1768 | AFTER |
| `ui/page_sect_manager.gd` | `7afee07a2bd461d8266be0073b1c7417` | 136256 | 3584 | AFTER |
| `ui_theme.gd` | `7ddd01fd433550e6735e2f6dd1b2274f` | 143862 | 2632 | **未改** |
| `tests/ui_full_accept.gd` | `2f8380b872c3bb697fe69ab6de78d870` | 30049 | 689 | 搭车探针 |
| 本规格（§9 写前） | `36beb1c63daa8ab924d0cafc4b977118` | 54449 | 638 | — |
| `tests/_probe_margin_hook.gd` | `efbaa2ff771084ea96e6e20527618af3` | 4725 | 119 | 见 §9b.6 |

### 9b.6 `tests/_probe_margin_hook.gd:76` 核（承团队令 ⑦）

- **结论：无需改**。`_找名`（`:102-106`）是**深度无关的递归名字扫描**（`if String(n.name)==名: 出.append(n); for c in n.get_children(): _找名(c,名,出)`），**不依赖路径/层级** ⇒ 包裹后 `VBox` 虽下沉一层（`card → MarginWrap → VBox`），**仍会被扫到** ⇒ **不会假红**。
- 故令 ⑦「探针也要用 `find_child`，否则假红」的**前提不成立**（该探针并非按路径 `get_node` 查找，而是全子树按名递归）⇒ **本批不动该文件**。

### 9b.7 状态

**未 add · 未 commit**；**丙-b 改动集（`1bd7f3e5…` / `7afee07a…`）与后续 P0 补丁改动集分开记账**（P0 见 §10，另出）。

> **本节自证**：追加式（未改 §0–§8）；未改任何 `.gd`；未起 Godot；未 git。

---

## §10b · 丙-b-P0 补丁记录（**追加式** · 2026-09-17 · 承 team-lead 令 ⑤）

> **独立小批**，与丙-b 主批**分开记账**。承令：`_make_card` 工厂宿主被钩子包裹后，`card` 直接子节点由 `"VBox"` 变 `"MarginWrap"` ⇒ 全仓 34 处 `get_node("VBox")` 成「由本批改动激活的隐性时序契约」。

### 10.1 动机

- `page_sect_manager.gd:959 _make_card`：`card(PanelContainer)` → `vb(VBoxContainer, name="VBox")`；丙-b **第 6 处宿主＝ `vb` 自身** ⇒ 入树钩子包裹 ⇒ `card` 直接子由 `"VBox"` → `"MarginWrap"`。
- 全仓 `get_node("VBox")` **34 处全部在 `ui/page_sect_manager.gd`**（逐处带前缀 `card`/`card2`/`事件卡`/`政策卡`）。

### 10.2 改法（机械 · 1:1 同行替换）

- `X.get_node("VBox")` → **`X.find_child("VBox", true, false)`**（**`owned=false`**：代码创建节点 `owner==null`，默认 `true` 查不到）。
- **等价性**：未包裹态 `find_child` 返回**同一节点**；已包裹态**穿透 `MarginWrap`** ⇒ **严格更宽松、向后兼容、今日行为零变化**。
- 返回类型均 `Node` ⇒ `var vb := …` 与 `var vb: VBoxContainer = …` 两种写法的**类型行为不变**。

### 10.3 指纹与字节账

| 项 | pre（＝丙-b AFTER） | post |
|---|---|---|
| md5 | `7afee07a2bd461d8266be0073b1c7417` | **`5f5a98249a4bc720c8fb1870b702b569`** |
| bytes | 136256 | 136766（**+510 = 34 × 15**） |
| LF | 3584 | **3584（不变）** |
| CR / BOM | 0 / False | 0 / False |

- **改前文件级备份**：`ui/page_sect_manager.gd.p0bak_20260917_200406`（136256 B）。

### 10.4 断言

- `get_node("VBox")`：**34 → 0** ✓
- `find_child("VBox", true, false)`：**0 → 34** ✓
- **LF / 行数不变** ✓（1:1 同行替换，非增删行）

### 10.5 闸门（**Godot 排队**：起 Godot 前 `Get-CimInstance Win32_Process | ? Name -like 'Godot*'` → COUNT=**0**；完成后释放 `.workbuddy/_pfix_LOCK`）

- **`gate_all.py` → 7/7 PASS**：门0 BOM=0 / CRLF=0 / 非法控制字节=0；门1 `ALL GDScript PARSE OK (269 files)`；门6 `P0=0`。
- **链 `compile_all` + `ui_compile` → 异常 0 / 2**：
  - `全项目 .gd 177 个  编译失败 0`；
  - `扫描 ui/*.gd 83 个  编译失败 0`。

### 10.6 探针 `tests/_probe_margin_hook.gd:76` —— **不改**（承令 ⑦ 之更正，见 §9b.6）

- `_找名` 系**深度无关**的递归名字扫描 ⇒ 包裹后 `VBox` 仍被扫到 ⇒ **不会假红** ⇒ 本批**不动**该文件。

### 10.7 状态

- **未 add · 未 commit**：`git diff --cached` 空；HEAD `b4fdb0e`；`ui/page_explore.gd` 与 `ui/page_sect_manager.gd` 均 `' M'`（未暂存）；补丁备份 `??`。
- **丙-b 改动集（`1bd7f3e5…` / `7afee07a…`）与 P0 改动集（`5f5a9824…`）分开记账**。

> **本节自证**：追加式；P0 仅动 `ui/page_sect_manager.gd`；复跑 Godot 链前 COUNT=0；未 git。

---

## §11 · 编号消歧总表

> **追加式**（不改 §0–§10b 任何既有**正文**；块序 14 仅**标题行** `§10`→`§10b`）。**目的**：一表消解本文档「重号 ＋ 乱序」。
> **块序 ≠ 时序**：下表按**盘上物理块序**（`grep -n "^## "` 顺序）编号，与各节**写作/施工时序**无关。
> **本表不设「写入时行号」列** —— 行号随编辑漂移、非稳定锚；稳定锚以**标题/首句特征串**为准。

| 块序 | 现编号 | 唯一锚串（块内首句特征串） | 真实主题 | 是否重号/乱序 | 处置 |
|---|---|---|---|---|---|
| 1 | §0 | `机制与口径（★ 先读）` | 机制口径：真失效族 vs 幻影族定义 ＋ 入树钩子机制 | 无 | 不改 |
| 2 | §1 | `定名与范围` | 本批定名与范围 | 无 | 不改 |
| 3 | §2 | `逐族现状清点表` | 逐族现状清点（每处给行号 · 盘上实测） | 无 | 不改 |
| 4 | §3 | `改法方案` | 每族 2 候选 ＋ 推荐 ＋ 布局影响面 | 无 | 不改 |
| 5 | §4 | `核验方案` | 逐文件真渲染 ＋ 探针 · 禁像素差分当主判据 | 无 | 不改 |
| 6 | §5 | `风险与缓解` | 主要风险（R1–R9）＋ 分批建议 ＋ 回滚点 | 无 | 不改 |
| 7 | §6 | `待批事项` | 待批决策点 D1–D7 | 无 | 不改 |
| 8 | 附 | `本规格自证` | 本规格自证（**无 `§` 号，不属编号体系**） | 无 | 不改 |
| 9 | §7 | `批 1（丙-b）施工记录` | 丙-b 12 处施工记录（已施工） | 无 | 不改 |
| 10 | §8 | `收口补完` | 收口补完（机制漏引补全 ＋ D1 逐块结论） | 无 | 不改 |
| 11 | §9 | `收口（丙-b · 主判据定稿` | 丙-b 收口：主判据定稿 ＋ 帧轴升格定量 ＋ 帧映射更正 | 无（当时唯一） | 不改 |
| 12 | §10 | `丙-b-P0 补丁记录（34 处` | 丙-b-P0 补丁记录（34 处 `find_child` 化） | **重号**（与块序 14 同号） | 不改（保留原号） |
| 13 | §9b | `丙-b 收口` | 丙-b 收口（探针 `:76` 无需改 ＋ 完整指纹表） | **乱序**（物理块序在 §10 之后） | 不改（令：**§9b 不动**） |
| 14 | **§10b**（原 §10） | `丙-b-P0 补丁记录（**追加式** · 2026-09-17 · 承 team-lead 令 ⑤）` | 丙-b-P0 补丁记录（承令 ⑤） | **重号**（与块序 12 同号） ＋ 乱序 | **改名 `§10b`** |

### 11.1 消歧裁定

- **重号**：块序 12 与块序 14 原同为 `## §10`。**裁定：块序 14 改名 `## §10b`**（块序 12 保留 `§10`）。改后 `§9`/`§9b` 与 `§10`/`§10b` **成对、各唯一**。
- **乱序**：块序 13（`§9b`）物理位置在块序 12（`§10`）之后，但其**写作时序在 §9 之前**（因 §9 由另一写入者**插入**而被下推）；编号含后缀 `b` 即自标识「同主题第二块」，**不受块序影响** ⇒ **不改号**。
- **块序 ≠ 时序**：全表按物理块序 1→14 排列；时序对应见各节首行「插入史」指针（`§9` 首行 ↔ `§9b` 首行）。
- **最小空闲号核对**：现有 `## §N` 占号 = {0,1,2,3,4,5,6,7,8,9,10} ∪ {9b,10}；无「未用的 `§N`」需新分配 ⇒ 块序 14 直接取**同号者的 `b` 后缀** `§10b`。

### 11.2 本表自证

- **追加式**：未改 §0–§10b 任何既有**正文**（仅块序 14 **标题行** `§10`→`§10b`）；未改任何 `.gd`；未起 Godot；未 git。
