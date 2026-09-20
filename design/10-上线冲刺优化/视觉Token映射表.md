---
doc_id: ART-TOKEN-MAP
doc_title: 视觉 Token 映射表（D1/D2/D3 裁决落地的施工前置规格）
doc_version: v1.3（2026-09-16 权威复核更正：`color.gold.text` 只 `MAT_EDGE_LIGHT` 一支；`COLOR_TEXT_TITLE1` 恢复独立 token；`COLOR_TEXT_BODY_GOLD` 终值 `#D4B86A`）
update_date: 2026-09-16
doc_type: 美术 / 技术美术 · 规格文档（P0-4 换肤施工前置）
task_id: PH7-ART-TOKEN-MAP
owner: art-director-2（林绘澄）
inputs: PH7-ART-DECISION-PACK 的 D1/D2/D3 裁决（见 `视觉SSOT决策包.md §0`）；**D2 已由 lead 采样实证更正**
scope: 只读调研 + 出规格；不动代码、不动资产、不执行 git
---

# 《太玄宗门录》视觉 Token 映射表

> **性质**：本表是 **P0-4 换肤阶段的施工前置规格**，把「全仓硬编码 `Color(...)`（1520 处 / 73 文件）」按**语义用途**归类到 SSOT token，
> 使换肤阶段可以「按语义组」而不是「按文件」安全推进。
> **⛔ 色值口径（2026-09-16 更正）**：一律取 **「常量同行注释 + 资产实测一致」**（即**蓝灰族**），**不是**原先写的"代码实际值"（青绿族）。
> 依据：lead 三源采样实证 —— 详见 **§4.4** 与 `视觉SSOT决策包.md §0 D2`。
> **实证基准**：扫描范围 = 全仓 `*.gd`（排除 `.scratch_backup/.godot/.venv/__pycache__/_taixuan_offload/.workbuddy/addons`）。

---

## ⛔ 红线声明（先读这一条）

> **本表是「规格」，不是「替换脚本」。不得据本表批量替换代码。**
> 依据项目既有裁决 —— `ui_theme.gd:1459-1461`（P0-2 立项原文）：
> 「**本轮不做批量替换。旧常量保留、新层同步可用即达成 P0-2 判据；1242 处硬编码的收敛留到 P0-4 换肤阶段**（届时有 `ui_full_accept` 真实渲染验收兜底，**现在批量改等于闭眼改 83 个文件**）」。
> 本表的用途是：① 让换肤阶段「按语义组」分批安全推进；② 暴露无法归类的残项，避免施工时踩雷。**任何批量替换必须逐批前置真实渲染验收。**

---

## 1. 金 token（四档 · D2 更正后终值）

**色值口径**：`常量同行注释 + 资产实测一致（lead 采样）`。金系终值裁定 = **`#C8A86A`**（设计文档「用户锁定权威」+ 资产邻域吻合）。

| token 名 | 中文 | 终值 hex | RGBA8 | **来源** | 用途边界 |
|---|---|---|---|---|---|
| `color.gold.hi` | **强调金** | `#F0DCA0` | `(240,220,160,255)` | `MAT_GOLD_HI` 同行注释值（`:1481`） | 高光带、状态角标、标题描边、选中图标底 |
| `color.gold.text` | **文字金** | `#E8CE8A` | `(232,206,138,255)` | `MAT_EDGE_LIGHT` 同行注释值（`:1478`）＝ `获取金文字色()` 的返回常量 | 正文级金文字、弹窗标题、可点击金标签（暗底对比 ≈ 9.6:1，过 AAA） |
| `color.gold.std` | **常规金** | `#C8A86A` | `(200,168,106,255)` | **设计文档权威值 + 资产实测邻域**（`MAT_GOLD_TOP` 终值，见下） | 主描边 / 边框 / 选中态 / 分隔线 / 核心数值 / 大标题 |
| `color.gold.low` | **弱金** | `#6E5726` | `(110,87,38,255)` | `MAT_EDGE_DARK` 同行注释值（`:1477`） | 外描边、未选中 / 禁用、复兴度低位、克制的分隔 |

> **`color.gold.text` 裁定依据（回应 lead 三候选 `#E8CE8A / #F0DFAE / #FFE096`）**：
> 1. **语义出口已指向它** —— `获取金文字色()`（`ui_theme.gd:1517`）返回 `MAT_EDGE_LIGHT`，其**同行注释值 `#E8CE8A` 即 D2 对齐后的真值**；实参 `#F0DFAE` 属同一 `MAT_*` 漂移族，正是 D2 要修掉的对象。
> 2. ~~**三源一致**~~ **★v1.3 更正** —— 三处**现均为 `#F0DFAE`（同一漂移实际值）**属实，但**权威目标并不相同**：`MAT_EDGE_LIGHT`(`:1478`) → `#E8CE8A`（设计稿 `mockups/p0-5_home_candidates.html:17`）；`COLOR_TEXT_BODY_GOLD`(`:16`) → **`#D4B86A`**（`太玄宗门录_角色与UI美术规范.md:240` ＋ `宗门首页B方案美术规格.md:47`）；`C01_TEXT_GOLD`(`:44`) → **`#D6B16A`**（`P2-宗主玉牒详情页·设计规格.md:211`）。**「三处同收敛到 `#E8CE8A`」不成立**，详见 §1.2。
> 3. `#FFE096` 全仓 `*.gd` **grep 零命中**（无任何出处），且过艳、破「暗金」调性，弃。
> 4. `#E8CE8A` 与 `color.gold.hi #F0DCA0` **明度层可分**，不产生 token 撞值。

> **金系物理常量终值总表（= 施工时 `MAT_*` 实参要改成的值）**：

| 常量 | 行 | 原实参（青绿/漂移❌） | 原注释 | **终值（✅）** | 备注 |
|---|---|---|---|---|---|
| `MAT_GOLD_HI` | 1481 | `#F5E7BE` | `#F0DCA0` | **`#F0DCA0`** | 改回注释值 |
| `MAT_EDGE_LIGHT` | 1478 | `#F0DFAE` | `#E8CE8A` | **`#E8CE8A`** | 改回注释值（亮金描边·次级物理值） |
| `MAT_GOLD_TOP` | 1479 | `#D8B86A` | `#C9A656` | **`#C8A86A`** | ★ **唯一「注释值也漂移」者** —— 注释 `#C9A656` 同样判漂移，终值取资产实测邻域 |
| `MAT_GOLD_BOTTOM` | 1480 | `#A08246` | `#8C6E2E` | **`#8C6E2E`** | 改回注释值（金渐变·止·次级物理值） |
| `MAT_EDGE_DARK` | 1477 | `#8A7238` | `#6E5726` | **`#6E5726`** | 改回注释值 |

> **次级物理值（保留为 Primitive，不作语义出口）**：`MAT_EDGE_LIGHT #E8CE8A`（强调金次级）、`MAT_GOLD_BOTTOM #8C6E2E`（弱金次级）。
> **归并关系**：`color.gold.std = #C8A86A` 需**同时吸收**文档层 4 个"权威"值，并**修正注释**：

| 被吸收的值 | 出处 | 处置 |
|---|---|---|
| `#C8A86A` | 太玄UI主题规范 / 写实修仙可执行 / 绘图强制 / 图标规范 / AI生产规范（"用户锁定权威暗金"） | **= 终值本身**（回流为 `color.gold.std`） |
| `#C9A656` | `UI视觉重构方案_深色暗金国风 §2.1` + **`MAT_GOLD_TOP` 同行注释** | **判漂移**，归入 `color.gold.std` |
| `#B89B5A` | `UI硬性约束规范 §3.2` | 归入 `color.gold.std` |
| `#C9A865` | `UI设计令牌v1.0` | 归入 `color.gold.std` |

> **★ 落地 `#C8A86A` 时发现的其它暗金不一致值**（回应 lead 问：「是否与其它暗金引用存在第三个不一致值」→ **是，且不止一个**）：
> 全库金系在代码里至少有 **10 个不同实参值 / 6 个不同注释声明** ——「三值」实为「多值」。

| 常量 | 行 | 注释声称 | **实际值** | 说明 |
|---|---|---|---|---|
| `COLOR_BORDER_GOLD` | 11 | `#C9A656` | `#D8B86A` | 注释即第三套值；终值须 `#C8A86A` |
| `COLOR_TAB_UNSELECTED` | 17 | `#C9A865` | `#BFB07F` | **第四套值**（注释≠实际） |
| `COLOR_TEXT_TITLE1` | 26 | `#E6C778` | `#F2E096` | 注释≠实际 |
| `COLOR_TEXT_GOLD` | 12 | 「亮金」（无 hex） | `#FFE096` | 强调金邻域 |
| `COLOR_TEXT_BODY_GOLD` | 16 | `#D4B86A` | `#F0DFAE` | 注释≠实际 |
| `C01_TEXT_GOLD` | 44 | `#D6B16A` | `#F0DFAE` | **第五套值**（注释≠实际） |
| `C05_TEXT_GOLD` | 136 | — | `#E8C572` | 与 `C05_BTN_GRAD` 同族 |
| `C05_BTN_GRAD` | 132 | — | `#E8C473` | |
| `C05_BTN_GRAD_DK` | 133 | — | `#C99C45` | 与 `#C9A656`/`#C9A865` 同族 |
| `C01_GOLD_LINE` | 42 | — | `#A38A51` | 弱金邻域 |
| `C01_PROG_FILL` | 51 | — | `#E1C37A` | |
| `COLOR_HOME_DIVIDER` | 34 | `#C8A86A` | `#D8B86A` | 注释已是终值，实参须改 |

> ⇒ **结论（v1.3 更正）**：`#C8A86A` 是**常规金（`color.gold.std`）终值**。但**「12 个常量全进四档」不成立** —— lead 权威复核（2026-09-16）判定：**11 个进四出口 + 1 个（`COLOR_TEXT_TITLE1`）恢复为独立文字 token `color.text.title1 = #E6C778`**（`UI设计令牌v1.0.md:43` 值 + `:253` 明文拍板「一级标题独立取 #E6C778」）；该 token 与 `title2 / body / aux / disabled` 同级，**不属金系**。详见 **§1.2**（权威复核表）。

---

### 1.1 三家族常量漂移计数（回应 lead「扩漂移范围」）

> lead 抽查指出漂移**不只发生在 `MAT_*` 家族**。art-director-2 以脚本对 `ui_theme.gd` 做全量比对（正则提取 `const NAME: Color(8) = … # #RRGGBB`，逐条比较**实参 hex vs 同行注释 hex**）：

| 家族 | 常量总数 | 注释≠实参（漂移） | 漂移率 | 说明 |
|---|---|---|---|---|
| `MAT_*`（Primitive 材质色板） | 12 | **12** | 100% | 实参全为青绿族、注释为蓝灰族（§4.3-C 已裁定实参为漂移） |
| `COLOR_*`（旧语义常量） | 22 | **12** | 55% | 同一模式：底色/描边实参偏青绿、金系实参偏黄（例 `COLOR_PANEL_BG` 实参 `#1B3E34` vs 注释 `#2C3E45`） |
| `C0x_*`（C01/C05 兼容层） | 41 | **7** | 17% | 文字色系（`C01_TEXT_*`）最集中 |
| `OTHER` | 8 | 0 | 0% | 非色值/结构常量 |
| **合计** | **83** | **31** | 37% | — |

> **两个可直接落地的锚点**：
> - **`COLOR_HOME_DIVIDER`（`ui_theme.gd:34`）注释 = `#C8A86A`** —— 这是 `#C8A86A`（常规金终值）在代码里的**一处独立声明**（另一处：`addons/taixuan_ui_editor/data_manager.gd:106` 注释 `# 暗金 #C8A86A`），与「资产实测邻域」共同构成**三源互证**；其实参 `#D8B86A` 判漂移，施工时改回注释值。
> - `COLOR_PANEL_BG`(`:8`) / `COLOR_BG_CONTENT`(`:24`) / `COLOR_HOME_BAR_BG`(`:33`) 三处**底色的漂移方向与 `MAT_*` 完全一致**（实参青绿、注释蓝灰）⇒ 批 2 应把这批 `COLOR_*` 底色与 `MAT_*` **同批处理**，避免二次返工。

### 1.2 ★ 权威复核（v1.3 新增 · 逐条引用设计文档）

> **缘起**：lead 指出「目标值不得用距离启发式，须逐条引用设计文档」。复核后**发现并更正两处同类错误**：`COLOR_TEXT_TITLE1`（原误判入金四档）与 `COLOR_TEXT_BODY_GOLD`（原误判收敛 `#E8CE8A`）。
> **权威源**：`design/06-角色与UI/UI设计令牌v1.0.md`（文字/背景/边框 token）· `design/06-角色与UI/mockups/p0-5_home_candidates.html`（Token 全量 CSS 变量，逐条标注常量名）· `太玄宗门录_角色与UI美术规范.md` · `宗门首页B方案美术规格.md` · `完整UX设计规范.md` · `S1-S2 阶段规划与视觉方向锁定.md` · `03-视觉与资产治理优化分册.md`。

| 常量 | 行 | 我上一版目标 | **权威复核终值** | 权威源（文件:行 · 原文） |
|---|---|---|---|---|
| `COLOR_TEXT_TITLE1` | 26 | ~~`#E8CE8A`~~ ❌ | **`#E6C778`** | `UI设计令牌v1.0.md:43`「color.text.title1｜一级标题｜#E6C778」＋ `:253`「采 spec：一级标题独立取 `#E6C778`」 |
| `COLOR_TEXT_BODY_GOLD` | 16 | ~~`#E8CE8A`~~ ❌ | **`#D4B86A`** | `太玄宗门录_角色与UI美术规范.md:240`「暗金正文｜#D4B86A｜COLOR_TEXT_BODY_GOLD」＋ `宗门首页B方案美术规格.md:47`「(0.831,0.722,0.416)｜#D4B86A」 |
| `C01_TEXT_GOLD` | 44 | ~~`#E8CE8A`~~ | **`#D6B16A`**（待裁） | `P2-宗主玉牒详情页·设计规格.md:211`「描边/高亮｜金 `#D6B16A`｜UITheme.COLOR_TEXT_GOLD」＋ mockup `:25`（写作 `#D6B06A`） |
| `MAT_EDGE_LIGHT` | 1478 | `#E8CE8A` ✓ | **`#E8CE8A`** | mockup `p0-5_home_candidates.html:17`「--mat-edge-light:#E8CE8A /* MAT_EDGE_LIGHT */」 |
| `COLOR_BORDER_GOLD` | 11 | `#C8A86A` | **冲突**（`#C9A865` / `#C9A656` / `#C8A86A` 三方） | `UI设计令牌v1.0.md:57`「color.border.gold｜#C9A865」↔ mockup `:21`「#C9A656」↔ D2/资产 `#C8A86A` |
| `MAT_GOLD_TOP` | 1479 | `#C8A86A` | **冲突** | mockup `:18`「#C9A656」↔ D2/资产实测 `#C8A86A` |

> ⇒ **金系四档归一（`#F0DCA0/#E8CE8A/#C8A86A/#6E5726`）的适用边界**：仅 `MAT_*` 家族（mockup 逐条背书）成立；**不适用于 `COLOR_BORDER_GOLD` 与 `COLOR_TEXT_BODY_GOLD`** —— 前者令牌定 `#C9A865`，后者美规定 `#D4B86A`。详见 `批2-ui_theme漂移修正施工清单.md §1.5 冲突清单`。

---

## 2. 深底面板底色阶梯（D1 裁决 · 4 档 · D2 更正后终值）

**色值 = 常量同行注释值**（蓝灰族）。四层严格按「下端明度递增」成立（对齐 `深色暗金国风方案 §3.2` 铁律：`panel #162024 < row #1C262C < card #1F2B31`）。

| token 名 | 中文 | 终值 hex（**下端**） | 起色（上端） | 来源常量（终值） | 用途 |
|---|---|---|---|---|---|
| `color.bg.page` | **背景** | `#22333A` | — | `MAT_BASE_TOP`（`:1470`）／`获取页面底色()` | 页面最底层 / 场景底 |
| `color.bg.panel` | **面板** | `#162024` | `#22333A` | `MAT_BASE_BOTTOM`（`:1471`）／`获取面板底色()` | 面板 / 容器主底（渐变 起→止） |
| `color.bg.surface` | **浮层** | `#1B272B` | — | `MAT_SURFACE`（`:1472`）／`获取浮层底色()` | 浮层 / 弹窗 / 次级面板 |
| `color.bg.card` | **强调块（卡片）** | `#1F2B31` | `#2B4049` | `MAT_CARD_BOTTOM`（`:1476`）／`MAT_CARD_TOP`（`:1475`） | 卡片 / 列表项 / 内嵌强调块 |
| `color.bg.row` | （列表行，第 5 档） | `#1C262C` | `#273942` | `MAT_ROW_BOTTOM`（`:1474`）／`MAT_ROW_TOP`（`:1473`） | 列表行底 |

> **底/描边物理常量终值总表（= 施工时 `MAT_*` 实参要改成的值）**：

| 常量 | 行 | 原实参（青绿/漂移❌） | **终值（✅ = 同行注释）** |
|---|---|---|---|
| `MAT_BASE_TOP` | 1470 | `#173B32` | **`#22333A`** |
| `MAT_BASE_BOTTOM` | 1471 | `#0F2A23` | **`#162024`** |
| `MAT_SURFACE` | 1472 | `#14362D` | **`#1B272B`** |
| `MAT_ROW_TOP` | 1473 | `#1B4438` | **`#273942`** |
| `MAT_ROW_BOTTOM` | 1474 | `#123027` | **`#1C262C`** |
| `MAT_CARD_TOP` | 1475 | `#224F42` | **`#2B4049`** |
| `MAT_CARD_BOTTOM` | 1476 | `#193E34` | **`#1F2B31`** |

**★ 施工提示（消掉潜在误工）**：本组与金组**只改 `ui_theme.gd` 的 `MAT_*` Color8 实参，不动任何 `art/ui/patch/*.png` 资产** —— 因为资产本来就是对的（蓝灰族）。**零资产返工。**

---

## 3. 字号阶梯 token（D3 裁决 · 1080 基准 4 档）

**现行基准 = 1080 viewport 终值**（`project.godot` viewport 1080×1920）。
换算关系：`1080 = 720 × 1.5`（开发预览窗）；`1080 = 480 × 2.25`（旧逻辑基准）。

| token 名 | 中文 | **1080 基准值** | **720 逻辑值** | 来源常量 | 用途 |
|---|---|---|---|---|---|
| `font.size.title` | **标题** | `45` | `30` | `FONT_TITLE`（`:167`） | 页面主标题 / 弹窗主标题 / 门派名 |
| `font.size.subtitle` | **区块标题** | `33` | `22` | `FONT_H2`（`:175`） | 面板标题 / 卡片组标题 |
| `font.size.body` | **正文** | `27` | `18` | `FONT_BODY`（`:169`）＝ `FONT_VALUE`（`:168`）＝ `FONT_DENSE`（`:176`） | 正文 / 数值 / 列表项 / Tab |
| `font.size.aux` | **辅助** | `21` | `14` | `FONT_AUX`（`:170`） | 辅助说明 / Toast / 领取 / 角标 |

**扩展档（非默认四档，按需）**：

| token 名 | 中文 | 1080 | 720 | 来源 |
|---|---|---|---|---|
| `font.size.display` | 巨号 | `60` | `40` | `FONT_DISPLAY`（`:173`） |
| `font.size.h1` | 一级标题 | `48` | `32` | `FONT_H1`（`:174`） |

> **下限**：`font.size.aux = 21`（1080）为**最小可读下限**，仅承载非关键信息；**关键信息禁仅用 aux 承载**。
> **与旧文档换算对照**：旧 doc 锁 480 基准 `{22,17,18,16,15,13}`，换算到 1080 即 `{49.5, 38.25, 40.5, 36, 33.75, 29.25}` —— 与代码现行档**不对齐**（属口径混用，见决策包 §7.4）。

---

## 4. ★ 语义归并映射表（最重要）

### 4.1 总览（12 组 · 按出现次数降序）

| 语义组 | 出现次数 | 文件数 | distinct 值 | → 归并到 token | 施工难度 |
|---|---|---|---|---|---|
| **金 / 黄**（金边框·金文字·金高光） | **422** | 58 | **172** | `color.gold.hi / .std / .low`（按明度三分） | 高（172 变体） |
| **中性灰**（占位·禁用·次要） | **203** | 32 | 39 | `color.text.disabled` / `color.text.aux` | **极高（语义不明）** |
| **绿 / 青绿**（成功·增益） | **166** | 38 | 78 | `color.state.success`（现 `获取吉色()`） | 中 |
| **暗底 / 面板底** | **149** | 37 | 66 | `color.bg.*` | 中高 |
| **蓝 / 信息 / 灵气** | **115** | 28 | 66 | `color.info.*`（**新 token，须先定义**） | 中 |
| **红 / 朱砂**（危险·警示） | **110** | 31 | 56 | `color.state.danger`（现 `获取凶色()`）+ 红点专用 | 中 |
| **UNPARSED**（引用常量的 α 派生） | **91** | 14 | — | **多数已语义化，保留**；少数须清理 | 低 |
| **白 / 近白** | **76** | 24 | 27 | `color.text.onDark` / 描边高光 | 中 |
| **全透明** | **48** | 15 | 6 | 无（占位 / 隐藏态） | 低 |
| **紫 / 宗门 / 稀有** | **47** | 24 | 31 | `color.rarity.purple` / 宗门类色 | 中 |
| **中性黑**（阴影·遮罩） | **34** | 18 | 19 | `color.shadow` / `color.overlay` | 中 |
| **棕 / 木色** | **33** | 9 | 22 | `color.btn.secondary.bg`（木色） | 低 |
| **青 / 玉石绿** | **26** | 15 | 15 | `color.accent.jade`（玉石绿） | 低 |
| **合计** | **1520** | **73** | **598** | — | — |

> **注**：`ui_theme.gd`（109 处）的 `Color(...)` 是**常量定义本体**（非违规）；`main.gd`（126 处）大部分位于**死代码区**（`R7`：`if 启用新UI:` 即 return，运行时不可达，已登记 207 处违规）。**扣除二者后，活跃 UI 债务 ≈ 1285 处**（与扫描器口径 1240 同量级）。

### 4.2 逐组明细（每组 → token + Top 10 文件）

#### 组 1 · 金 / 黄（422 处 / 58 文件 / 172 distinct）
**→ `color.gold.hi / .std / .low`**（按明度三分：`v>0.85`→hi，`0.6~0.85`→std，`<0.6`→low）

Top 10 文件：
| 文件 | 处数 |
|---|---|
| `ui/disciple_detail_page.gd` | 54 |
| `ui/page_master.gd` | 26 |
| `main.gd` | 23 |
| `ui/page_building.gd` | 22 |
| `ui/page_premium.gd` | 21 |
| `ui/page_offline_manager.gd` | 17 |
| `ui/battle_scene.gd` | 17 |
| `ui/page_family.gd` | 15 |
| `ui/page_world_map.gd` | 14 |
| `ui/page_beast.gd` | 13 |

高频值（Top 12，**这 172 个变体正是"暗金漂移"的物证**）：
`#D9BF80`(16) · `#E6B233`(15) · `#E8C572`(15) · `#E8D499`(15) · `#B2B299`(14) · `#CCB266`(10) · `#FFE680`(10) · `#E6B24C`(9) · `#D4B036`(9) · `#E6CC99`(9) · `#E6CC80`(8) · `#F2BF33`(8)
→ 其中 `#C8A86A`(7) = **本次裁定的常规金终值**（页面已在用的"权威值"）；`#E8C572`(15) = `C05_TEXT_GOLD` 令牌实际值（属强调金邻域）。

#### 组 2 · 中性灰（203 处 / 32 文件 / 39 distinct）—— **最难，见 §4.3**
**→ `color.text.disabled` / `color.text.aux`（须逐处判断，见残项）**

Top 10 文件：`page_family.gd`(21) · `disciple_detail_page.gd`(14) · `page_tech.gd`(13) · `page_beast.gd`(13) · `page_master.gd`(12) · `page_quest.gd`(12) · `page_player_trade.gd`(11) · `page_treasure.gd`(11) · `main.gd`(10) · `page_premium.gd`(9)

#### 组 3 · 绿 / 青绿（166 处 / 38 文件 / 78 distinct）
**→ `color.state.success`**（现 `获取吉色()` = `COLOR_STATUS_SUCCESS #7ED39A`）

Top 10 文件：`main.gd`(18) · `page_master.gd`(15) · `disciple_detail_page.gd`(14) · `page_premium.gd`(12) · `ui_theme.gd`(10) · `battle_scene.gd`(9) · `page_beast.gd`(9) · `page_building.gd`(7) · `page_family.gd`(6) · `page_offline_manager.gd`(5)

#### 组 4 · 暗底 / 面板底（149 处 / 37 文件 / 66 distinct）
**→ `color.bg.page / .panel / .surface / .card`**

Top 10 文件：`ui_theme.gd`(27) · `main.gd`(11) · `page_storage.gd`(10) · `page_shop.gd`(9) · `disciple_detail_page.gd`(8) · `page_herb_garden.gd`(7) · `page_fragment_chest.gd`(7) · `page_library.gd`(6) · `page_equipment_blueprint.gd`(6) · `page_puppet.gd`(6)

#### 组 5 · 蓝 / 信息 / 灵气（115 处 / 28 文件 / 66 distinct）
**→ `color.info.*`（新 token，须先定义；可参考 `C05_REWARD_BLUE #4AA0E0`）**

Top 10 文件：`disciple_detail_page.gd`(34) · `battle_scene.gd`(16) · `main.gd`(8) · `page_master.gd`(7) · `page_disciple.gd`(6) · `page_zongmen_battle.gd`(5) · `page_world_map_visual.gd`(5) · `page_world_map.gd`(4) · `page_beast.gd`(4) · `page_treasure.gd`(3)

#### 组 6 · 红 / 朱砂（110 处 / 31 文件 / 56 distinct）
**→ `color.state.danger`**（现 `获取凶色()` = `COLOR_TEXT_RED #E07878`）+ **红点专用**（`RED_DOT_COLOR #FA4F4F`）

Top 10 文件：`page_master.gd`(15) · `disciple_detail_page.gd`(12) · `main.gd`(9) · `battle_scene.gd`(8) · `page_dynasty.gd`(8) · `page_building.gd`(7) · `page_beast.gd`(5) · `ui_theme.gd`(4) · `page_treasure.gd`(4) · `page_disciple.gd`(4)

#### 组 7 · 白 / 近白（76 处 / 24 文件 / 27 distinct）
**→ `color.text.onDark`（宣纸亮 #F0E6D2 系）/ 描边高光**

Top 10 文件：`ui_theme.gd`(16) · `disciple_detail_page.gd`(16) · `battle_scene.gd`(9) · `main.gd`(6) · `page_premium.gd`(4) · `page_world_map_visual.gd`(3) · `sect_creation_page.gd`(2) · `radar_chart.gd`(2) · `page_building.gd`(2) · `vfx/vfx_bus.gd`(2)

#### 组 8 · 紫 / 宗门 / 稀有（47 处 / 24 文件 / 31 distinct）
**→ `color.rarity.purple`（`C05_ICON_PURPLE #B57BE8` `/ tier.sheng #B04CD9`）**

Top 10 文件：`disciple_detail_page.gd`(11) · `page_premium.gd`(6) · `page_disciple.gd`(2) · `page_treasure.gd`(2) · `main.gd`(2) · `ui_theme.gd`(2) · `page_quest.gd`(2) · `page_beast.gd`(2) · `page_master.gd`(2) · `page_global_auction.gd`(2)

#### 组 9 · 棕 / 木色（33 处 / 9 文件 / 22 distinct）
**→ `color.btn.secondary.bg`（木色）**

文件：`main.gd`(9) · `disciple_detail_page.gd`(9) · `page_premium.gd`(4) · `ui_theme.gd`(3) · `page_building.gd`(3) · `page_master.gd`(2) · `battle_scene.gd`(1) · `game_ui.gd`(1) · `page_world_map_visual.gd`(1)

#### 组 10 · 青 / 玉石绿（26 处 / 15 文件 / 15 distinct）
**→ `color.accent.jade`（玉石绿 `#8FBF9F` / 青黛 `#6E8F88`）**

文件：`ui_theme.gd`(4) · `disciple_detail_page.gd`(3) · `page_family.gd`(3) · `main.gd`(2) · `page_beast.gd`(2) · `page_treasure.gd`(2) · `page_world_map_visual.gd`(2) · `game_state.gd`(1) · `page_building.gd`(1) · `page_disciple.gd`(1)

#### 组 11 · 中性黑 / 全透明（34 + 48 处）
**→ `color.shadow` / `color.overlay` / 无（隐藏态）**

`#000000|0`（40 处）为透明占位（与 `mouse_filter` 无关），**无需 token**。

#### 组 12 · UNPARSED（91 处 / 14 文件）—— 详见 §4.3

---

### 4.3 ⚠️ 无法归类 / 语义不明 · 残项清单（施工最危险区，显式暴露）

> 这些是「语义无法从值本身判定」的项 —— 施工时**必须逐处人工判断**，禁止按组批量替换。

#### 残项 A · 通用灰阶（135 处 / 30 文件）—— **语义不明，疑似 debug/占位**
`#999999`(53) · `#808080`(37) · `#B2B2B2`(33) · `#CCCCCC`(6) · `#666666`(6)
**判定难点**：同一灰值在不同上下文分别代表「禁用态 / 未达条件 / 次要文字 / 装饰线 / 占位块」，**无法用单一 token 承接**。

`#999999` 全量 file:line（53 处，节选前 20）：
`achievement_system.gd:361` · `main.gd:2334` · `main.gd:2442` · `ui_theme.gd:1341` · `ui/battle_scene.gd:894` · `ui/battle_scene.gd:897` · `ui/disciple_detail_page.gd:3582` · `ui/faction_quest_shop_page.gd:14` · `ui/faction_quest_shop_page.gd:169` · `ui/faction_quest_shop_page.gd:247` · `ui/page_achievement.gd:48` · `ui/page_achievement.gd:293` · `ui/page_beast.gd:314` · `ui/page_beast.gd:451` · `ui/page_beast.gd:618` · `ui/page_beast.gd:681` · `ui/page_beast.gd:789` · `ui/page_codex.gd:45` · `ui/page_codex.gd:400` · `ui/page_dynasty.gd:1791` …（余略）

`#808080` 全量 file:line（37 处，节选前 15）：
`ui/battle_scene.gd:1046` · `ui/faction_quest_shop_page.gd:183` · `ui/faction_quest_shop_page.gd:261` · `ui/page_beast.gd:416` · `ui/page_beast.gd:562` · `ui/page_beast.gd:753` · `ui/page_building.gd:3840` · `ui/page_family.gd:242` · `ui/page_family.gd:409` · `ui/page_family.gd:436` · `ui/page_family.gd:472` · `ui/page_family.gd:530` · `ui/page_family.gd:681` · `ui/page_master.gd:644` · `ui/page_master.gd:676` …

`#B2B2B2` 全量 file:line（33 处，节选前 15）：
`main.gd:2339` · `message_system.gd:491` · `ui/faction_quest_shop_page.gd:206` · `ui/faction_quest_shop_page.gd:284` · `ui/page_beast.gd:93` · `ui/page_beast.gd:278` · `ui/page_beast.gd:571` · `ui/page_beast.gd:746` · `ui/page_building.gd:796` · `ui/page_dynasty.gd:1782` · `ui/page_faction.gd:189` · `ui/page_faction.gd:819` · `ui/page_family.gd:94` · `ui/page_family.gd:197` · `ui/page_family.gd:291` …

**高发文件**：`ui/page_family.gd`(21) · `ui/page_beast.gd`(13) · `ui/page_tech.gd`(13) · `ui/page_master.gd`(12) · `ui/page_quest.gd`(12) · `ui/page_player_trade.gd`(11) · `ui/page_treasure.gd`(11)
**建议**：新增 `color.neutral.disabled` / `color.neutral.placeholder` / `color.neutral.weak` 三个中立 token 后**逐处**归类；在归类完成前**保持原样**。

#### 残项 B · UNPARSED（91 处 / 14 文件）—— 其中**仅 6 处是真残项**
91 处按性质拆分：

| 子类 | 数量 | 处置 |
|---|---|---|
| 合法常量 α 派生（`Color(UITheme.XXX, a)` / `Color(常量.r, .g, .b, a)`） | ~70 | **保留**（已语义化，非违规） |
| 局部变量 α 派生（`Color(金环.r, …, 0.35)` / `Color(暗化.r, …, 0.6)`） | ~13 | **保留**（渲染态派生） |
| **真残项：死代码 / 注释 / 截断串** | **6** | **须清理** |

**真残项 6 处（file:line，全部在 `main.gd` / `ui_theme.gd` 注释或死代码区）**：
- `main.gd:38` —— `Color(...)`（注释占位）
- `main.gd:77` —— `Color(0.10,0.09,0.08,0.55/0.60)`（注释文本，非代码）
- `main.gd:79` —— `Color(0.06,0.06,0.08,X)`（注释文本）
- `ui_theme.gd:1314` —— `Color(0.6,…)`（注释内截断）
- `ui_theme.gd:1588` —— `Color(...)`（注释）
- `ui_theme.gd:1574 / 1585 / 1590` —— 含 `clampf(...)` 的合法派生表达式（**保留**；此处仅因正则未闭合而落入 UNPARSED）

#### 残项 C · ★ 色相家族冲突 —— **✅ 已裁定（lead 采样实证，2026-09-16）**

**旧判定**：`MAT_*` 常量实参（青绿族） vs 注释/文档/页面硬编码（蓝灰族），两套并存，须工程采样裁定。
**裁定结果**：**蓝灰族为真；青绿族是 `MAT_*` 实参的漂移。**
处置：**把 `MAT_*` 的 Color8 实参改回其注释所写值**（见 §1/§2 终值总表），**不动任何 `art/ui/patch` 资产**（资产本来就是蓝灰族）。

**举证来源（lead 三源独立采样）**：

| 举证 | 结论 | 来源文件 |
|---|---|---|
| ① 4 张底色 patch 资产中心区众数 | `panel_bg #182428` / `card_bg #24343C` / `card_row_bg #203038` / `btn_frame #222B2D` → **4/4 判蓝灰**，距蓝灰族 d² 27~75，距青绿族 142~291（差 4–10 倍） | `.workbuddy/_sample_patch_family.py` → `_patch_family_result.txt` |
| ② 金色像素专测 | 文档 `#C8A86A` 得 5 票，代码实参 `#D8B86A` 得 **0 票** | `.workbuddy/_sample_patch_family2.py` → `_patch_family_result2.txt` |
| ③ 真实渲染截图（`accept_shots_full/`） | **蓝灰 70 页 vs 青绿 10 页**；10 页「青绿」众数全为 `#173B32`（=`MAT_BASE_TOP` 实参），文件名清一色 `P_FIX_底座换色_*`/`P_FIX_背景补全_*`/`P_FIX_观景_*` ⇒ 那是**背景图自身颜色**，非 UI 面板色 | `.workbuddy/_sample_render_family.py` → `_render_family_result.txt` |
| ④ `ui_theme.gd:1468` 注释（契约） | 「Primitive：P0-1 材质色板（**与 `art/ui/patch/*.png` 源图逐像素一致，单一真源**）」+ `:1532`「改资产必须同步改这里」⇒ **契约是「代码跟资产一致」，实参违反了契约** | 代码 |
| ⑤ 页面硬编码 | 蓝灰族硬编码 **64 处**（`#1F2B31` 24 / `#273942` 19 / `#162024` 9 / `#1B272B` 12） | 见 §4.2 组 1/组 4 |

**五源一致指向蓝灰，唯 `MAT_*` 的 Color8 实参是异类。**

---

### 4.4 ★ 第三套值：「常量同行注释」≠「设计文档值」（新增，2026-09-16）

此前只发现两套（代码实参 vs 文档）。lead 采样进一步确认存在**第三套** —— **`MAT_*` 的行内注释 hex 与设计文档标注值也不是同一个值**。以金为例：

| 层 | 金值 | 判定 |
|---|---|---|
| 代码 `Color8` 实参 | `#D8B86A` | ❌ 漂移 |
| **常量同行注释** | **`#C9A656`** | ❌ **也是漂移**（第三套值，此前无人提及） |
| 设计文档（`深色暗金国风 §2.1`） | `#C9A656` | 与同行注释同值 |
| **资产实测邻域** | `panel_bg` 金众数 `#C4B078`、`btn_fill` Top 色含 `#C8A860` | ✅ 指向 `#C8A86A` |
| 设计文档「用户锁定权威暗金」 | `#C8A86A` | ✅ **终值** |

**结论**：金系终值 = **`#C8A86A`**；`#D8B86A`（实参）与 `#C9A656`（注释+文档）**两者皆判漂移**。
**施工影响**：`MAT_GOLD_TOP` 是**唯一「改回注释值也不对」的常量** —— 其终值须取 `#C8A86A`（资产实测），**同时修正其注释**。其余 10 个 `MAT_*` 常量均可「改实参 = 注释值」一步到位。

---

## 5. 施工顺序建议（按语义组分批，附前置依赖与验收判据）

> **铁则**：按「语义组」分批，**不按文件**。每批前置「该组 token 已定 + 该组无跨组耦合」。

| 批 | 语义组 | 量级 | 前置依赖 | 验收判据 |
|---|---|---|---|---|
| **批 0** | **口径判定** | — | ✅ **已完成（lead 采样实证）** —— 裁定「蓝灰为真、青绿为漂移」（见 §4.3-C） | ✅ 已出具「资产实际值」结论；终值已锁入 §1/§2 |
| **批 1** | 金 / 黄（组 1） | 422 处 / 58 文件 | **本阶段已裁定终值 ✓ + `ui_full_accept` 64 页基线截图 ✓** | 全仓无金色字面量；仅存 `color.gold.hi/std/low` 三出口；**改后跑 `ui_full_accept` 与基线逐页差分，金边框无色差** |
| **批 2** | 暗底 / 面板底（组 4） | 149 处 / 37 文件 | **本阶段已裁定终值 ✓ + `ui_full_accept` 64 页基线截图 ✓**（同批 1） | 全底板走 `获取*底色()`；无裸底色字面量；四层明度梯度成立；**改后与基线逐页差分** |
| **批 3** | 状态语义色（组 3 绿 + 组 6 红） | 276 处 / ~45 文件 | 独立（+ 基线截图） | 绿→`获取吉色()`、红→`获取凶色()`；红点仅用 `RED_DOT_COLOR` |
| **批 4** | 品类色（组 5 蓝 + 组 8 紫 + 组 10 青） | 188 处 / ~45 文件 | 须先**新增** `color.info.*` token 表（+ 基线截图） | 信息蓝 / 宗门紫 / 玉石绿各有唯一出口；`UI设计令牌` 品阶 7 档对齐 |
| **批 5** | 中性文字（组 7 白 + 组 11 黑） | 110 处 / ~30 文件 | 独立（+ 基线截图） | 浅字仅落在深底语义上；遮罩/阴影统一 `color.overlay/shadow` |
| **批 6** | **残项 A 灰阶**（最难） | 135 处 / 30 文件 | 新增 `color.neutral.*` 三 token | 逐处人工归类完成；无 `#999999/#808080/#B2B2B2` 字面量 |
| **批 7** | 死代码清理（残项 B + `main.gd` 207 处） | 6 + 207 处 | `R7` 立项 | `main.gd` 死代码区整体删除或明确排除 |

> **★ 批 0→批 1 的门槛（必须点明，施工时最易漏）**：改 `MAT_*` 是**上屏色**变更，**`--headless` 验不出颜色**（项目铁律）。
> 故批 1/批 2 的**第一步** = 改色**之前**先跑一次 `ui_full_accept` 存 64 页**基线截图**；改后再跑一次，**逐页差分比对**。无基线不得开批 1。
> **跨批共享前置**：每批完成后跑 `ui_full_accept` 真实渲染验收（64 页，六计数器归零）+ 棘轮 `audit_ui.py` 计数单调下降。

---

## 6. 附录 · 实证口径

| 项 | 值 |
|---|---|
| 扫描范围 | 全仓 `*.gd`（排除 `.scratch_backup/.godot/.venv/__pycache__/_taixuan_offload/.workbuddy/addons`） |
| `Color()/Color8()` 字面量总数 | **1520** |
| 涉及文件数 | **73**（含 `ui_theme.gd` 常量本体 109 处、`main.gd` 死代码 126 处） |
| 归一化去重后 distinct 值 | **598** |
| 活跃 UI 债务（扣除 `ui_theme.gd` + `main.gd`） | **≈ 1285 处**（扫描器棘轮口径记 1240） |
| 每文件 Top 5 | `ui/disciple_detail_page.gd`(198) · `main.gd`(126) · `ui_theme.gd`(109) · `ui/page_master.gd`(80) · `ui/battle_scene.gd`(77) |
| 色值裁定采源 | lead 三源采样：`.workbuddy/_sample_patch_family.py` / `_sample_patch_family2.py` / `_sample_render_family.py`（结果对应 3 个 `_*_result*.txt`） |

**相关文档**：`视觉SSOT决策包.md`（本表为其 §0 D1/D2/D3 裁决的施工前置）· `UI视觉重构方案_深色暗金国风_v1.0.md`（Token 三层架构）· `ui_theme.gd:1440-1760`（Primitive/Semantic/Component 实现）。

---

*本表由 art-director-2（林绘澄）于 PH7 上线冲刺批次产出，仅为规格；全程只读，未改任何代码/资产、未执行 git。v1.1 按 lead 采样实证更正色值口径（青绿→蓝灰、金终值 `#C8A86A`）；v1.2 增补金 token 第四档 `color.gold.text = #E8CE8A` 与 §1.1 三家族漂移计数。据本表批量替换须逐批前置真实渲染验收。*
