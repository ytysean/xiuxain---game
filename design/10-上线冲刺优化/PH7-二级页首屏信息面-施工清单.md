# PH7 · 二级页首屏信息面 · 节点级施工清单（05 灵钓 / 06 灵兽）

- **任务**：PH7-VOID-2（把 `PH7-二级页首屏信息面设计.md` 转成节点级可施工清单）
- **产出**：文策渊（design-strategist）· 2026-09-17
- **上游**：`design/10-上线冲刺优化/PH7-二级页首屏信息面设计.md`（已验收，md5 `FF7658FB6C61324111B671D5BBE7C46D`）
- **team-lead 裁决已全部落实**：B1（05 保 4 块 / 06 收 2 块，块C 字段零高度承载）｜B2（动作块置首 ＋ 粘连加分隔）｜B3（不新增口子、页内遍历 ＋ 刷新时机护栏）｜B4（C9 降级不删 / C10 不动 / C11 并入品阶分布区）
- **V1–V4 已裁决并回填**（2026-09-17 修订版）：V1 取「甲」但改写为**独立 `Label` 小标**（**禁写进标签文本**，见 §2.4-a）｜V2 **禁红点**、用中性色 `COLOR_TEXT_AUX`｜V3 门槛说明**移入块A**（§1.6）｜V4 **不扩面** `建标签栏`
- **性质**：**只读规格**。**零落盘 `.gd/.csv/资产`；未起 Godot**（同项目禁并发跑 Godot）。
- **本清单只覆盖「新增信息面 ＋ B4 既有内容调整」**；(a) 共享背景层 与 (c) 主题画框**不在本清单**（美术线）。
- **引用一律全路径**（`脚本:行号` 显式带文件名），已过 `verify_cites.py`（exit 见 §5）。

---

## §0 · 口径与基线

### §0.1 量纲三空间（强制）

| 空间 | 尺寸 | 关系 |
|---|---|---|
| `frame` | 720×1280 | 判读帧 PNG 像素 |
| `逻辑` | 480×853 | = `frame` ÷ 1.5 |
| `viewport` | 1080×1920 | = `frame` × 1.5 = `逻辑` × 2.25 |

`UI_SCALE = 2.25`（`ui_theme.gd:145`）是 **逻辑 → viewport** 换算。**凡数字必带空间名。**

### §0.2 颜色口径（★ 硬约束）

- **颜色一律引用 token 名，禁写死色值**（本批刚改过 7 个常量，写死色值立刻过期）。
- **本清单只使用下列已核实存在的 token**（全部为盘上实读，行号为准）：

| 用途 | token | 定义处 |
|---|---|---|
| 正文/数值/辅助统一色（首选） | `UITheme.COLOR_TEXT_BODY_GOLD` | `ui_theme.gd:16` |
| 核心数值/高亮金 | `UITheme.COLOR_TEXT_GOLD` | `ui_theme.gd:12` |
| 旧正文（本批**不改**旧 token，新块一律用上一行） | `UITheme.COLOR_TEXT_BODY` | `ui_theme.gd:14` |
| Tab 计数小标色（V2 指定·中性色）＋ 旧辅助 | `UITheme.COLOR_TEXT_AUX` | `ui_theme.gd:15` |
| 禁用/未达条件 | `UITheme.COLOR_TEXT_DISABLED` | `ui_theme.gd:29` |
| 成功/增益 | `UITheme.COLOR_STATUS_SUCCESS` | `ui_theme.gd:31` |
| 警示（负数/不足） | `UITheme.COLOR_TEXT_RED` | `ui_theme.gd:13` |
| 一级/二级标题 | `UITheme.COLOR_TEXT_TITLE1` / `COLOR_TEXT_TITLE2` | `ui_theme.gd:26` / `ui_theme.gd:27` |

- **红点族（`UITheme.RED_DOT_COLOR` 等）本清单一律不用** —— team-lead 裁决 **V2 禁红点**：红点＝宗主「待裁决队列」专用语义，计数小标属**进度量/状态量**，误用会**贬值红点体系**（不可逆体验损伤）。计数小标色改用 `UITheme.COLOR_TEXT_AUX`（中性色）。
- **优先用语义 getter（更抗换肤）**：`UITheme.获取主文字色()`（`ui_theme.gd:1510`）／`获取次文字色()`（`ui_theme.gd:1512`）／`获取弱文字色()`（`ui_theme.gd:1514`）／`获取金文字色()`（`ui_theme.gd:1516`）／`获取角标色()`（`ui_theme.gd:1560`）。
> **口径**：块内**标签**走 `获取弱文字色()`；**数值**走 `COLOR_TEXT_BODY_GOLD`（或 `获取主文字色()`）；**块标题**走 `COLOR_TEXT_GOLD`（或 `获取金文字色()`）。

### §0.3 组件白名单（只用既有 `UITheme` 组件，禁新造）

| 用途 | 组件 / 方法 | 定义处 |
|---|---|---|
| 块容器（实心面板，随内容自适应） | `PanelContainer` ＋ `UITheme.apply_panel_style(面板)` | `ui_theme.gd:527` |
| 块标题字号 | `UITheme.apply_section_title(标签)`（`FONT_H2 33` viewport ｜ 14.7 逻辑） | `ui_theme.gd:435` |
| 行标签字号 | `UITheme.apply_aux_text(标签)`（`FONT_AUX 21` ｜ 9.3） | `ui_theme.gd:444` |
| 数值字号 | `UITheme.apply_value_text(值)`（`FONT_VALUE 27` ｜ 12） | `ui_theme.gd:448` |
| 正文行（无标签对） | `UITheme.apply_body_text(标签)`（`FONT_BODY 27` ｜ 12） | `ui_theme.gd:440` |
| 进度条 | `ProgressBar` ＋ `UITheme.进度缓动(条, 目标)` | `ui_theme.gd:2230` |
| 分隔线 | `UITheme.make_divider_control()` / `UITheme.apply_divider(控件)` | `ui_theme.gd:721` / `ui_theme.gd:739` |
| 空态 | `UITheme.建空态(标题, 说明, 图标, 紧凑)` | `ui_theme.gd:1815` |
| Tab 计数小标（零布局高度） | 独立 `Label`（`add_child` 到 Tab `Button` 之下；字号走 `UITheme.apply_aux_text`；色 `UITheme.COLOR_TEXT_AUX`） | 实现见 §2.4-a |

**间距/尺寸 token（行号一律显式带 `ui_theme.gd`）**：`UITheme.GRID = 12`（`ui_theme.gd:146`）｜`UITheme.GRID_SM = 6`（`ui_theme.gd:147`）｜`UITheme.MARGIN = 24`（`ui_theme.gd:148`）｜`UITheme.PAD_PANEL = 24`（`ui_theme.gd:149`）｜`UITheme.SIZE_SM = 72`（`ui_theme.gd:150`）｜`UITheme.RADIUS_PANEL = 12`（`ui_theme.gd:307`）。

### §0.4 数据刷新时机纪律（B3 护栏 · ★ 硬约束）

- **一律「进页算一次 ＋ 数据变更时重算」**：新增聚合值算好后存**页级缓存变量**，与既有 `_刷新内容()` 同生命周期重建。
  - 05 灵钓：落在 `ui/page_fishing.gd:92-98 func _刷新内容()`（切 Tab / 操作后已有调用）。
  - 06 灵兽：落在 `ui/page_beast.gd:96-120 func _刷新内容()`（切 Tab / 操作后已有调用）。
- **禁止把遍历放进每帧路径** —— 本页（05 灵钓）的 `_process`（`ui/page_fishing.gd:281-307`，驱动张力/渔获条）**禁止**新增任何遍历；06 灵兽**无 `_process`**，同样禁止为此新建。
- **若某字段天然要逐帧更新 ⇒ 先报 team-lead 再谈**（本清单**无**此类字段）。
- **N1 纪律（team-lead 升格）**：`game_state.gd:1455 _库房灵材数量(名)` 是**按物品名计数、不是灵材总数** —— **禁代用**。

### §0.5 开工基线（md5）

| 文件 | md5 |
|---|---|
| `ui/page_fishing.gd` | `17010BC89E5BA8C2BDE93D811DFB0224` |
| `ui/page_beast.gd` | `E01FE66827125FB0691C985C7EB994FA` |

---

## §1 · 05 灵钓 · 施工清单（4 块）

### §1.1 插入点与总布局

- **承载脚本**：`ui/page_fishing.gd`（`func _建_总览` = `ui/page_fishing.gd:104-154`）。
- **插入点**：既有内容**末项 = 参赛钮**（`ui/page_fishing.gd:150-154`）之后 ⇒ **追加在 `ui/page_fishing.gd:154` 之后**。
- **锚点与坐标**：**无绝对坐标**。四个块作为 `_content`（`VBoxContainer`，`ui/page_fishing.gd:75-77`）的**顺序子项**依次追加：
  `[既有 9 段] → 块A「下一步」→ 块B「今日机缘」→ 块C「灵渊探索」→ 块D「图录收录」`。
- **块间距**：`Control` 间隔件，高 = `UITheme.GRID`（12 viewport ｜ 5.3 逻辑）；或 `_content.add_theme_constant_override("separation", UITheme.GRID)`。
- **B2 附加**：若实机截图显示「参赛钮」与「块A」**视觉粘连**（无分隔、像同一块）⇒ **在两者之间加分隔**（`UITheme.make_divider_control()`，`ui_theme.gd:721`）或加 `GRID` 高留白；**不许改块序**。
- **刷新时机**：全部 4 块在 `ui/page_fishing.gd:92-98 _刷新内容()` 内算一次并缓存（§0.4）。

**块容器统一规格（4 块同）：**

| 元素 | 控件 | 形制 | 备注 |
|---|---|---|---|
| 块容器 | `PanelContainer` | 调 `UITheme.apply_panel_style(面板)`（`ui_theme.gd:527`） | 满足铁律「数据＝实心面板」；随内容自适应高 |
| 块内宿主 | `VBoxContainer` | `separation = UITheme.GRID_SM`（6 ｜ 2.7） | 标题在下述行之上 |
| 块标题 | `Label` | `UITheme.apply_section_title`（`FONT_H2 33` ｜ 14.7）＋ 色 `UITheme.COLOR_TEXT_GOLD` | 文案见各块表 |
| 块内边距 | — | `PAD_PANEL`（24 ｜ 10.7） | 走 `apply_panel_style` 自带内距，勿再手加 |

### §1.2 块A「下一步」（1 行 · 动作块）

| 元素 | 控件 | 形制（字号 · 颜色 token） | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `下一步` | — | — |
| 指引行 | `Label`（`autowrap_mode = AUTOWRAP_WORD_SMART`） | `apply_body_text`（`FONT_BODY 27` ｜ 12）· `COLOR_TEXT_BODY_GOLD` | `今宜·%s`（`%s` = 判定链命中文案，见 §1.6） | **兜底必出**：`今宜·抛竿入水，静待鱼讯` | 见 §1.6 逐条 |

### §1.3 块B「今日机缘」（2 行 · 状态块）

| 元素 | 控件 | 形制 | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `今日机缘` | — | — |
| 行1 标签 | `Label` | `apply_aux_text`（`FONT_AUX 21` ｜ 9.3）· `获取弱文字色()` | `今日尚可垂钓` | 同（数值为 0 时整体色转 `COLOR_TEXT_DISABLED`） | — |
| 行1 进度条 | `ProgressBar` | 高 `Vector2(0, 24)` viewport（＝10.7 逻辑，同页先例 `ui/page_fishing.gd:191`）；调 `UITheme.进度缓动(条, 剩余)` | 无文字 | 值 0 | `fishing_system.gd:1958 获取剩余机缘次数()` ／ `fishing_system.gd:1950 获取每日机缘次数()` |
| 行1 数值 | `Label` | `apply_value_text`（`FONT_VALUE 27` ｜ 12）· `COLOR_TEXT_BODY_GOLD` | `%d / %d 次`（剩余 / 总） | `0 / %d 次` | 同上 |
| 行2 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `连续垂钓` | 同 | — |
| 行2 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d 日` | `0 日` | `fishing_system.gd:1941 获取连续钓鱼天数()` |

- 行1 合用 `HBoxContainer`（标签 ＋ 进度条 `SIZE_EXPAND_FILL` ＋ 数值），`separation = UITheme.GRID_SM`。
- **team-lead 裁决 V3（解释归块A）**：本块**零小字**，行2 保持纯数字 `%d 日`。「仙阶机缘需连续满 15 日」这一**门槛说明**属「为什么这个数重要」，移入块A 判定链（§1.6）；**同一信息禁在两块重复**。

### §1.4 块C「灵渊探索」（2 行 · 状态块）

| 元素 | 控件 | 形制 | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `灵渊探索` | — | — |
| 行1 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `已探灵渊` | 同 | — |
| 行1 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d / %d 处`（已解锁 / 全部） | `1 / 4 处`（初始必解锁第 0 层） | `fishing_system.gd:242 可钓灵渊()`（取 `.size()`）／ `fishing_system.gd:13 const 灵渊表`（取 `.size()`） |
| 行2 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `下一处灵渊` | — | — |
| 行2 内容 | `Label`（`AUTOWRAP_WORD_SMART`） | `apply_body_text` · `COLOR_TEXT_BODY_GOLD` | `%s（需钓道【%s】）`（下一处未解锁灵渊名 / 其所需钓道境界名） | **全解锁**：`诸渊尽探` | 判定口径同 **同页既有实现** `ui/page_fishing.gd:166-169`（`灵渊表` 各项 `需境界` × `fishing_system.gd:192 var 钓道境界`） |

### §1.5 块D「图录收录」（2 行 · 状态块）

| 元素 | 控件 | 形制 | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `图录收录` | — | — |
| 行1 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `鱼获图录` | 同 | — |
| 行1 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d / %d 种`（已收录 / 总数） | `0 / %d 种` | `fishing_system.gd:1631 获取鱼获分类统计()`（`["鱼获图鉴"]["已收录"]` / `["鱼获图鉴"]["总数"]`） |
| 行2 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `神兽图录` | 同 | — |
| 行2 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d / %d 种`（已降服 / 总数） | `0 / %d 种` | `fishing_system.gd:1631 获取鱼获分类统计()`（`["神兽图鉴"]["已降服"]` / `["神兽图鉴"]["总数"]`） |
| 行2 追加 | 同 `HBoxContainer` 内 | `apply_aux_text` · `获取弱文字色()` | `仙缘图录　%d / %d 种`（已结缘 / 总数） | `0 / %d 种` | `fishing_system.gd:1631 获取鱼获分类统计()`（`["仙缘图鉴"]["已结缘"]` / `["仙缘图鉴"]["总数"]`） |

> **上屏词 vs 映射键勿混**（team-lead 已钉）：**后端键 = 图鉴**（`fishing_system.gd:1631` 返回 `鱼获图鉴/神兽图鉴/仙缘图鉴`）；**上屏词 = 图录**（与 Tab 名 `ui/page_fishing.gd:10` 的 `TABS=["总览","垂钓","图录"]` 对齐）。

### §1.6 块A「下一步」判定链（**展开为可实现优先级列表 · 命中即止**）

> 规则：**自上而下判，命中即出该条文案并停止**。最后一条为**兜底，必出**。

| 序 | 判定条件 | 取值口（`脚本:行号` + 函数名/字段） | 命中文案原文 | 命中时数值注入 |
|---|---|---|---|---|
| 1 | 剩余机缘 ≤ 0 | `fishing_system.gd:1958 获取剩余机缘次数()` | `今宜·机缘已尽，明日再来` | 无 |
| 2 | 可钓灵渊数 ＜ 灵渊总数 | `fishing_system.gd:242 可钓灵渊()` ／ `fishing_system.gd:13 const 灵渊表` | `今宜·精进钓道，以探更深灵渊` | 无 |
| 3 | 本周大赛参与 ＜ 3 | `fishing_system.gd:195 var 本周大赛参与`（上限见 `fishing_system.gd:2077`） | `今宜·本周大赛尚余 %d 次`（= 3 − 已参与） | `%d` = `3 − 本周大赛参与` |
| 4 | 鱼获图鉴 已收录 ＜ 总数 | `fishing_system.gd:1631 获取鱼获分类统计()` | `今宜·续竿以补图录（尚缺 %d 种）` | `%d` = `总数 − 已收录` |
| 5 | 连续垂钓 ＜ 15 日 | `fishing_system.gd:1941 获取连续钓鱼天数()`（门槛 15 见 `fishing_system.gd:1676`） | `今宜·续钓不辍，仙阶机缘需连续满 15 日` | 无（当前值已在块B 行2 显示，**禁重复**） |
| **6（兜底·必出）** | 以上皆不成立 | — | `今宜·抛竿入水，静待鱼讯` | 无 |

- **V3 落实与位置说明**：team-lead 建议把「仙阶 15 日」条放「境界」条附近；本清单**置于末位非兜底条（序 5）**，理由：`连续垂钓 < 15` 对多数玩家**近乎恒真**，若前置会**吃掉**「大赛尚余 / 图录尚缺」等**更可行动作**的指引。**若要前移，仅需改序、其余不动**。
- **不判「钓具可否晋阶」**：该判定需「库房灵材总数」，现无公开口子（见上游 §3 N1）；**禁臆测可行性**。
- 命中文案统一拼为块A 行：`今宜·%s` 的完整串（例：`今宜·本周大赛尚余 2 次`）。

### §1.7 05 空态/零值文案总表

| 位置 | 零值/空态文案 | 颜色处置 |
|---|---|---|
| 块A 行 | 兜底 `今宜·抛竿入水，静待鱼讯`（**必出**） | `COLOR_TEXT_BODY_GOLD` |
| 块B 行1 | `今日尚可垂钓　0 / %d 次` | 数值转 `COLOR_TEXT_DISABLED` |
| 块B 行2 | `连续垂钓　0 日` | 数值转 `COLOR_TEXT_DISABLED` |
| 块C 行1 | `已探灵渊　1 / 4 处` | 正常色（初始必 ≥1） |
| 块C 行2 | `诸渊尽探` | `COLOR_TEXT_GOLD` |
| 块D 行1 | `鱼获图录　0 / %d 种` | 正常色 |
| 块D 行2 | `神兽图录　0 / %d 种　仙缘图录　0 / %d 种` | 正常色 |

---

## §2 · 06 灵兽 · 施工清单（2 块 ＋ 零高度承载）

### §2.1 插入点与总布局

- **承载脚本**：`ui/page_beast.gd`（`func _填总览` = `ui/page_beast.gd:124-220`）。
- **插入点**：既有内容**末项 = 催办钮**（`ui/page_beast.gd:216-220`）之后 ⇒ **追加在 `ui/page_beast.gd:220` 之后**。
- **锚点与坐标**：**无绝对坐标**。两块作为 `_content`（`VBoxContainer`，`ui/page_beast.gd:73-75`）的**顺序子项**追加：
  `[既有 10 段] → 块A「下一步」→ 块B「在孵与引育」`。
- **块数 = 2（B1 硬上限）**：void = 212 逻辑，2 块 ≈ 200 逻辑 ⇒ **正好填满、不引入滚动**。**禁加第 3 块**。
- **块间距 / B2 粘连处置**：同 §1.1（`GRID` 间隔；粘连则加 `UITheme.make_divider_control()`，`ui_theme.gd:721`；**不许改块序**）。
- **刷新时机**：两块在 `ui/page_beast.gd:96-120 _刷新内容()` 内算一次并缓存（§0.4）。
- **块容器/块标题/行形制**：与 §1.1 同规格（`PanelContainer` ＋ `apply_panel_style`；`apply_section_title`；`apply_aux_text` / `apply_value_text`）。
- **恒显示**：孵化/引育与「有无灵兽」无关（蛋与队列可独立存在）⇒ 本页无灵兽时**这两块仍显示**，走零值文案；既有「尚无灵兽入册」空态（`ui/page_beast.gd:166`）不受影响。

### §2.2 块A「下一步」（1 行 · 动作块）

| 元素 | 控件 | 形制 | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `下一步` | — | — |
| 指引行 | `Label`（`AUTOWRAP_WORD_SMART`） | `apply_body_text` · `COLOR_TEXT_BODY_GOLD` | `今宜·%s` | **兜底必出**：`今宜·苑中无事，可往「引育计划」补一条` | 见 §2.5 逐条 |

### §2.3 块B「在孵与引育」（2 行 · 状态块）

| 元素 | 控件 | 形制 | 上屏文案原文 | 零值/空态文案 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 标题 | `Label` | `apply_section_title` · `COLOR_TEXT_GOLD` | `在孵与引育` | — | — |
| 行1 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `孵化中` | 同 | — |
| 行1 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d 只（最快 %d 日）` | `0 只`（**零值时括号段整段省略**） | 只数 `beast_management_system.gd:75 获取灵兽统计()`（`["孵化中数"]`）；最快剩余日 遍历 `game_state.gd:209 var 灵兽蛋列表` × `beast.gd:125 var 剩余天数` 取最小 |
| 行2 标签 | `Label` | `apply_aux_text` · `获取弱文字色()` | `引育计划` | 同 | — |
| 行2 数值 | `Label` | `apply_value_text` · `COLOR_TEXT_BODY_GOLD` | `%d 项（启用 %d）` | `0 项`（**零值时括号段整段省略**） | `beast_management_system.gd:5 var 灵兽兑换队列`（计 `启用` 布尔；写入见 `beast_management_system.gd:31`，启停见 `beast_management_system.gd:34-40`） |

### §2.4 块C 字段的「零额外高度」承载（**B1 硬约束 · V1 已裁取「甲」**）

> **B1 要求**：块C 字段**一个都不许丢**，但**不许以第 3 块形式出现**（会引入滚动）。
> **team-lead 裁决 V1**：取**方案甲**，但**实现方式改写**为「**Tab 钮下挂独立 `Label` 小标**」——**绝不是**把计数写进 `建标签栏` 的标签文本（理由见下「四键同一」证据）。

#### §2.4-a 方案甲（V1 已裁采用）：Tab 计数小标（独立 `Label`，零布局高度）

**★ 红线（照抄会出 DEAD 级 bug）**：**禁把计数写进 `建标签栏` 的标签文本**（如把 `TABS` 项改成 `"繁殖 2"`）。
`ui_theme.gd` 的 `建标签栏`（`ui_theme.gd:1317`）里，**四个东西是同一个字符串 `名`**：
- `ui_theme.gd:1321` `b.text = str(名)` —— 页签**显示文本**
- `ui_theme.gd:1330` `b.pressed.connect(回调.bind(名))` —— **回调实参**
- `ui_theme.gd:1332` `表[str(名)] = b` —— **返回字典键**
- `ui_theme.gd:1341` `... if str(k) == str(当前)` —— **高亮匹配键**（`刷新标签高亮`，`ui_theme.gd:1337`）

⇒ 一旦标签文本变 `"繁殖 2"`，则**页签回调里 `名 == "繁殖"` 分支失配**（点了没反应，即 DEAD 45 条那类「按钮亮着却静默 return」），且 `刷新标签高亮(表, 当前)` 必须跟着传 `"繁殖 2"` 才亮。**故计数绝不进标签文本。**

| 字段 | 挂载点 | 组件 | 形制 | 上屏内容 | 数据源（`脚本:行号` + 函数名） |
|---|---|---|---|---|---|
| 繁殖中 N | **「繁殖」Tab 钮**右上角 | 独立 `Label`（**子节点** `add_child` 到该 `Button` 之下；字号走 `UITheme.apply_aux_text`，`ui_theme.gd:444`） | 色 = `UITheme.COLOR_TEXT_AUX`（`ui_theme.gd:15`，**V2 指定中性色·禁红点**）；锚 `PRESET_TOP_RIGHT`；**不设 `custom_minimum_size`** ⇒ **零布局高度** | 纯数字（= 对数） | `game_state.gd:6357 var 繁殖中灵兽`（取 `.size()`） |
| 苑中待出战 N | **「出战绑定」Tab 钮**右上角 | 同上 | 同上 | 纯数字（= 待出战只数） | `beast_management_system.gd:75 获取灵兽统计()`（`["库存数"]` − `["出战数"]`） |
| 可进化 N | **不占小标**，仅进块A 判定链（§2.5 第 1 条） | — | — | 由块A 文案承载 | `beast_management_system.gd:4 var 灵兽库存` × `beast_management_system.gd:241 获取灵兽进化消耗()`（`["是否可进化"]`；判定式 `beast_management_system.gd:255`） |

- **挂载方式（相对锚点）**：Tab 钮由 `UITheme.建标签栏(...)`（`ui_theme.gd:1317`）生成并返回字典（本页存于 `ui/page_beast.gd:15 var _tab_btns`，赋值点 `ui/page_beast.gd:60`）。**在建标签栏调用之后**，取 `_tab_btns["繁殖"]` / `_tab_btns["出战绑定"]`，把该 `Label` `add_child` 到对应 `Button` 之下，锚 `PRESET_TOP_RIGHT`，offset 约 `(−4, 4)` viewport。
- **免额外压暗处理（子节点随父）**：`刷新标签高亮`（`ui_theme.gd:1337`）以 `b.modulate`（`ui_theme.gd:1341`）压暗未选页签；`Label` 是 `Button` 的**子节点** ⇒ 自动同被压暗，**语义自洽、零额外处理**。
- **显隐 / 刷新**：计数 ≤ 0 ⇒ `label.visible = false`；> 0 ⇒ 显示（避免「0」小标噪音）；刷新即 `label.text = str(N)`。
- **禁改共享组件（V4 已裁：不扩面）**：`ui_theme.gd` 的 `建标签栏`（`ui_theme.gd:1317`）**不得改动**；小标在**页面侧**挂载。理由：该组件被约 25 个二级页共用，扩角标能力＝**一次横切改动**（需全站回归），而老大已明令**禁开新横切批**。
- **禁红点（V2）**：红点＝宗主「待裁决队列」专用；「繁殖中 / 待出战 / 可进化」是**进度量/状态量**，用红点会**贬值红点体系**。**禁 `make_red_dot_number`、禁新组件**；颜色只用 `COLOR_TEXT_AUX`。

#### §2.4-b 方案乙（**未采用 · 留档备查**）：并入块B 的紧凑第 3 行

- 原设想：块B 内加第 3 行、数值 `%d 对　苑中待出战 %d 只　可进化 %d 只`，多 ≈24 逻辑、仍不触发滚动。
- **V1 已裁取「甲」** ⇒ 本方案**不施工**；仅留档，便于后续若 Tab 小标方案被否决时回退。

#### §2.4-c 块C 字段的完整取值口（方案甲使用）

| 字段 | 取值口（`脚本:行号` + 函数名） | 剩余日口径 |
|---|---|---|
| 繁殖中 对数 | `game_state.gd:6357 var 繁殖中灵兽`（取 `.size()`） | 同 `ui/page_beast.gd:679-680`（`完成日` − `game_state.gd:3635 var 累计游戏日` 取最小） |
| 苑中待出战 | `beast_management_system.gd:75 获取灵兽统计()`（`["库存数"]` − `["出战数"]`） | — |
| 可进化 | `beast_management_system.gd:4 var 灵兽库存` × `beast_management_system.gd:241 获取灵兽进化消耗()`（`["是否可进化"]`） | — |

### §2.5 块A「下一步」判定链（**展开为可实现优先级列表 · 命中即止**）

| 序 | 判定条件 | 取值口（`脚本:行号` + 函数名/字段） | 命中文案原文 | 命中时数值注入 |
|---|---|---|---|---|
| 1 | 可进化灵兽数 ＞ 0 | 遍历 `beast_management_system.gd:4 var 灵兽库存` × `beast_management_system.gd:241 获取灵兽进化消耗()`（`["是否可进化"]`，判定式 `beast_management_system.gd:255`） | `今宜·苑中 %d 只灵兽可进化，可往「灵兽库」` | `%d` = 可进化只数 |
| 2 | 苑中待出战 ＞ 0 | `beast_management_system.gd:75 获取灵兽统计()`（`["库存数"]` − `["出战数"]`） | `今宜·苑中 %d 只灵兽待出战，可往「出战绑定」` | `%d` = 待出战只数 |
| 3 | 引育队列停用项 ＞ 0 | `beast_management_system.gd:5 var 灵兽兑换队列`（`["启用"] == false` 的条数） | `今宜·有 %d 项引育计划停用，宜启用` | `%d` = 停用项数 |
| 4 | 孵化中数 ＞ 0 | `beast_management_system.gd:75 获取灵兽统计()`（`["孵化中数"]`） | `今宜·%d 只灵兽孵化中，静候破壳` | `%d` = 孵化中只数 |
| 5 | 繁殖中列表非空 | `game_state.gd:6357 var 繁殖中灵兽` | `今宜·%d 对灵兽繁殖中` | `%d` = 对数 |
| **6（兜底·必出）** | 以上皆不成立 | — | `今宜·苑中无事，可往「引育计划」补一条` | 无 |

- 顺序理由：**「可进化 / 待出战」是玩家当场可完成的动作**（优先级最高）；「引育停用」次之；「孵化 / 繁殖」为**等待型**（只作状态告知）；兜底引导到引育。

### §2.6 06 空态/零值文案总表

| 位置 | 零值/空态文案 | 颜色处置 |
|---|---|---|
| 块A 行 | 兜底 `今宜·苑中无事，可往「引育计划」补一条`（**必出**） | `COLOR_TEXT_BODY_GOLD` |
| 块B 行1 | `孵化中　0 只`（省略「最快 N 日」） | 数值转 `COLOR_TEXT_DISABLED` |
| 块B 行2 | `引育计划　0 项`（省略「启用 N」） | 数值转 `COLOR_TEXT_DISABLED` |
| Tab 计数小标（§2.4-a） | 计数 ≤ 0 ⇒ `label.visible = false` | 色 `COLOR_TEXT_AUX` |

---

## §3 · 既有内容调整（落实 B4 裁决）

> team-lead 裁决：**C9 降级不删 / C10 原样不动 / C11 并入品阶分布区**。本节只给**位置与保留要求**；**字号层级由美术线 H4 统一**（避免与美术线冲突），本清单不重复定义字号。

| 项 | 对象 | 处置 | 盘上位置 | 硬约束 |
|---|---|---|---|---|
| C9 | 灵兽统计 9 项中的 `总道行 / 平均等级 / 最高等级 / 最高道行` | **降级**（主区 → 次级/折叠） | `ui/page_beast.gd:140-143`（`_添加信息项` 调用序，依次为 总道行 / 平均等级 / 最高等级 / 最高道行） | **禁删除**（「最高道行」是玩家成长反馈）；不新增字段。注：上屏词 `总道行`/`最高道行` 对应后端键 `总战力`/`最高战力`，属 F8「战力→道行」上屏口径，**勿改键名** |
| C10 | `类型分布` | **原样不动**（本批不动、也不替换） | `ui/page_beast.gd:169-179` | 文案/形制已冻结 ⇒ **零改动** |
| C11 | `神兽血脉数` | **并入品阶分布区**，不单列 | 现单列于 `ui/page_beast.gd:144`；品阶分布区在 `ui/page_beast.gd:151-166` | 只移位置、**不改数值口径** |

> **删除任何现网字段 ⇒ 必须回来问 team-lead**（本清单不含任何删除项）。

---

## §4 · 待确认小项（V1–V4 **已全部裁决**）

| 号 | 事项 | 裁决（team-lead 2026-09-17） |
|---|---|---|
| V1 | 06 块C 承载二选一 | **取甲**（Tab 计数小标）；但实现改写为**独立 `Label` 子节点、零布局高度**，**禁写进标签文本**（四键同一证据见 §2.4-a） |
| V2 | 计数小标颜色 | **禁红点**；用中性色 `UITheme.COLOR_TEXT_AUX`（`ui_theme.gd:15`）；禁新组件、禁改共享组件 |
| V3 | 05 门槛小字 | **不在块B 加小字**；门槛说明**移入块A 判定链**（§1.6 序 5），块B 行2 保持纯数字 |
| V4 | `建标签栏` 是否扩面 | **不扩面**；页面侧挂载（该组件约 25 页共用，扩面＝横切改动，老大已禁开新横切批） |

> 四项**均已裁决**，可据本清单直接交工程线施工。

---

## §5 · 自检与元数据

### §5.1 自检

- ✅ **只读产出**：仅写盘本 MD；**未改任何 `.gd/.csv/资产`**；**未起 Godot**。
- ✅ **颜色零写死**：全文只引 token 名 / 语义 getter（清单见 §0.2），无 `Color(...)` 字面量。
- ✅ **组件零新造**：只引既有 `UITheme` 组件（清单见 §0.3）。
- ✅ **每块标了数据刷新时机**（§0.4 ＋ 各块「刷新时机」行）；**遍历禁入每帧路径**已写明。
- ✅ **块A 判定链已展开**为可实现优先级列表，两条链**均给兜底文案**（§1.6 第 6 条 / §2.5 第 6 条），无留空。
- ✅ **B1/B2/B3/B4 逐条落实**；**V1–V4 裁决全部回填**；块C 字段**零丢失**（§2.4）；计数小标用 `Label`（Godot 内置）＋ `apply_aux_text`，**未引红点族、未造新组件**。
- ✅ **引用全路径**；`verify_cites.py` 结果见 §5.2；并按 team-lead 令**人工抽查 3+ 条**（§5.4）。

### §5.2 元数据

```
file    = design/10-上线冲刺优化/PH7-二级页首屏信息面-施工清单.md
bytes   = 见交付回传
lines   = 见交付回传
LF / CR = 纯 LF（CR = 0）
BOM     = False
md5     = 见交付回传（文件自嵌 md5 天然不自洽，以回传为准）
verify  = 见交付回传
```

### §5.3 承载脚本（未改）

| 文件 | md5 |
|---|---|
| `ui/page_fishing.gd` | `17010BC89E5BA8C2BDE93D811DFB0224` |
| `ui/page_beast.gd` | `E01FE66827125FB0691C985C7EB994FA` |

### §5.4 引用人工抽查（假绿补偿控制 · team-lead 2026-09-17 令）

> 背景：`verify_cites.py` 存在「**全角冒号 ＋ 阿拉伯数字**」被 `BARE_RE` 误绑的**假绿**缺陷（本轮已登记待办、本轮不修）⇒「校验通过」**不再等于**「引用正确」。**凡用 `verify_cites.py` 出结论的报告，必须人工抽查 ≥3 条引用并留痕。** 本次抽查（读盘时刻 2026-09-17）：

| # | 引用 | 盘上原文摘录（逐字） |
|---|---|---|
| 1 | `fishing_system.gd:1941` | `func 获取连续钓鱼天数() -> int:` |
| 2 | `fishing_system.gd:1676` | `	if 连续钓鱼天数 < 15:` |
| 3 | `beast_management_system.gd:241` | `func 获取灵兽进化消耗(灵兽索引: int) -> Dictionary:` |
| 4 | `ui_theme.gd:1321`（§2.4-a 四键同一证据） | `		b.text = str(名)` |

- 四条**逐字命中**、行号与内容一致 ⇒ 抽查通过。
- 另：`ui_theme.gd:1319/1330/1332/1341` 见 §2.4-a（由 team-lead 读盘提供，我复读 `ui_theme.gd:1317-1341` 逐字一致）。

---

*（文策渊 · PH7-VOID-2 · 节点级施工清单 · v2 含 V1–V4 回填 · 结构：口径 → 05 灵钓 4 块 → 06 灵兽 2 块＋零高度承载 → B4 既有调整 → 已裁决 → 自检＋抽查）*
