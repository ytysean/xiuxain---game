---
doc_id: ART-P04-RARITY-ART-SPEC
doc_title: color.rarity.* 美术裁定 + 波 4 批 4 替换值回填（1:1 · 只读 · 终值型）
doc_version: v1.1
update_date: 2026-09-17
doc_type: 美术 / 技术美术 · 裁定 + 替换草案（**非施工**：盘上零改动）
task_id: PH7-ART-15
owner: art-director-2（林绘澄）
inputs: 稀有度映射表与色板规格.md（T2 · DESIG11-T2）· ui_theme_config.gd:15-23（7 槽真源）· ui/page_message.gd:372-388（批 4 三站 + 逻辑改动）· main.gd:110-118（物品入口）· ui_theme.gd（三层 token）· 视觉Token映射表.md · P0-4备料-page_message硬编码Color清点.md · 波4-page_message-批12替换草案.md
scope: **只出裁定 + 草案**。全仓 `.gd`/`.csv` **零改动**；不替换、不跑 Godot、未执行 git。
---

# `color.rarity.*` 美术裁定 + 波 4 批 4 替换值回填

> **一句话**：T2（`稀有度映射表与色板规格.md`）把 4 项交来美术线。**本文件给 4 项终裁**（终值型，非选项型），并把 **波 4 批 4 的 3 站**（`ui/page_message.gd:380/:383/:386`）写成**逐字节 1:1 替换草案**，另把 `:378-386` 的**逻辑改动**单列（与批 4 同次写入，落盘交工程线）。

> ⛔ **红线（先读）**：本文件是**裁定 + 草案**，**不是施工**。
> ① 依据 `ui_theme.gd:1459-1461`「本轮不做批量替换」；
> ② 落地须**先落波 1（token 本体）+ 64 页真实渲染基线**；
> ③ **通用 7 槽一个字节都不改**（见 §1）；批 4 三站须走差分（见 §7）。

### v1.1 变更（lead 验收回填 · 2026-09-17）

| # | 变更 | 依据 |
|---|---|---|
| ① | **命名终裁** → 通用层键名 = `QUALITY_COLOR` **既有 7 键名**（`fan/ling/bao/wang/sheng/xian/dao`），**零新造名**；**删除** `color.rarity.epic` / `color.rarity.legend` / `color.rarity.myth`；`R1..R7` **降为文档序位、不进代码** | lead §2：`main.gd:113-116` 已映射 凡阶→`fan`… ⇒ 键名已存在于代码；**有语义名就还会有下一次错位**，故不采纳 `immortal`/`divine` |
| ② | `main.gd:110 get_rarity_color()` 勘误 **lead 已认账**，并升格为「**禁动**」硬约束 | lead §1：全仓定义仅此一处、调用仅 2 处、**在启动器内非 autoload** ⇒ `UITheme` 调不到 |
| ③ | 新增硬约束：`get_rarity_slot()` **返回值必须 ∈ 7 键集或 `.info.*`**，验收断言须含此条 | lead §3 |
| ④ | 新增**排程硬约束**：`UITheme.获取稀有度色()` 须与**波 4 批 4 同一落盘批**，禁单独先落 | lead §3：门3 死函数水位（376 / 396 / 目标 380） |
| ⑤ | 新增**方法栏口径**：凡「保上屏色」的决定**必须附对比度实测** | lead §3（对比度 6.62:1 即例外口子关闭依据） |

---

## 0. 裁定摘要（终值型 · 4 项）

| # | T2 交来 | **裁定** | 一句话依据 |
|---|---|---|---|
| ① | R6「传说＝橙」新色值 | **不新造**。通用 7 槽**冻结**；秘闻三色走**并列新增** `color.rarity.info.*`（传说 `#FF8033` / 史诗 `#B04CD9` / 稀有 `#5B8BD9`） | R6 现网 = `tier.xian` = `#F0E6B0`（米黄）；若把 R6 改橙 ⇒ `color.rarity.xian ≠ tier.xian` ⇒ 通用阶梯分裂 ⇒ 经既有入口的**物品「仙品」上屏色被连带改** |
| ② | 回填通用 7 槽 hex | **原值照抄，禁改**：通用层键名 = `QUALITY_COLOR` **既有 7 键名** `color.rarity.fan|ling|bao|wang|sheng|xian|dao`（= `ui_theme_config.gd:15-23` 七值**逐字节 alias**，**零新造名**） | `ui_theme_config.gd:13` 明写「原 8 档含 liang，**S1 已收口为 7 档**」⇒ 再动 = 重造第 9 套；键名沿用既有 stem ⇒ 与唯一真源**同名同位、永不漂移** |
| ③ | `tier.*` 与 `color.rarity.*` 是否同值 | **同源不分化**：`color.rarity.<stem>`（`fan..dao`）**就是** `tier.<stem>`（= `QUALITY_COLOR` stems）的 **alias**，不是第二套值 | 新增独立值 = 「禁新词表」红线的等价违反 |
| ④ | `color.rarity.*` 三层落位 | 见 §4（Primitive 不动 / Semantic：**通用 7 键 alias** + `info.*` / Component 收敛入口） | 命名沿用项目颜色域规范 `color.<域>.<维度>` / `获取<域><维度>色()`；**通用层键名 = 既有 7 stem（lead 终裁 · 零新造名）** |

> **口径 = 终值型（lead 定案）**：这不是审美选择，是**锚定** —— 秘闻「传说」现网上屏色就是 `ui/page_message.gd:380 Color(1.0,0.5,0.2)` ＝ `#FF8033`，**P0-4 是语义化收敛，禁凭空造新色**。

---

## 1. 通用 7 槽 = `QUALITY_COLOR` 逐字节 alias（**冻结 · 禁改**）

> **真源**：`ui_theme_config.gd:15-23` `QUALITY_COLOR`（7 档，**逐字节回盘**）。
> **★ 键名（lead 终裁 · v1.1）**：通用层**直接用 `QUALITY_COLOR` 既有 7 键名**，**零新造名**：
> `color.rarity.fan | color.rarity.ling | color.rarity.bao | color.rarity.wang | color.rarity.sheng | color.rarity.xian | color.rarity.dao`
> 依据：`main.gd:113-116` **已把 凡阶→`fan`、灵阶→`ling`… 道阶→`dao` 映射进代码** ⇒ **这套键名已存在于代码**；沿用 = **零新造名**，且与唯一真源**同名同位、永不漂移**。
> ⇒ 通用层**只做别名，不新增任何 hex、不新增任何语义名**。`R1..R7` **仅本文档内序位标注，不进代码**。

| 序位 | token ID（**通用层键名 · 既有，零新造**） | stem | **hex** | 真源（`ui_theme_config.gd`） | 品阶 |
|---|---|---|---|---|---|
| R1 | `color.rarity.fan` | `fan` | **`#D6D6D6`** | `:16` | 凡品 |
| R2 | `color.rarity.ling` | `ling` | **`#3FA9C9`** | `:17` | 灵品（主理人裁定：青蓝） |
| R3 | `color.rarity.bao` | `bao` | **`#5B8BD9`** | `:18` | 宝品 |
| R4 | `color.rarity.wang` | `wang` | **`#D9A04C`** | `:19` | 王品 |
| R5 | `color.rarity.sheng` | `sheng` | **`#B04CD9`** | `:20` | 圣品 |
| R6 | `color.rarity.xian` | `xian` | **`#F0E6B0`** | `:21` | 仙品 |
| R7 | `color.rarity.dao` | `dao` | **`#E8F0FF`** | `:22` | 道品 |

> **lead 口径原文（照录）**：「`R6` 现网 = `tier.xian` = `#F0E6B0` 米黄。若把 R6 改成橙 ⇒ `color.rarity.xian ≠ tier.xian` ⇒ 通用阶梯被动分裂 ⇒ 经 `main.gd:110 get_rarity_color()` 的既有消费方（**物品「仙品」上屏色**）被连带改色。**我不批。**」⇒ **通用 7 槽一个字节都不动。**
> **★ 命名终裁（v1.1 · lead）**：**不采纳** `immortal`/`divine` —— 改名只是**换一个语义名**，通用层**只要有语义名就还会有下一次错位**。故**通用层键名 = 既有 7 stem**（上表左列），**删除** `color.rarity.epic` / `color.rarity.legend` / `color.rarity.myth` 三个语义键（**均不存在于代码/文档**）；`R1..R7` **仅序位**。⇒ **「命名二选一」问题就此消失：通用层不持语义名，无新名可起。**
> **★ 旧版勘误**：v1.0 曾建议 R6 `legend→immortal` / R7 `myth→divine`；**该建议已被上述终裁取代，不再适用。**

---

## 2. 秘闻三色 → 并列新增 `color.rarity.info.*`（信息档专用槽 · 命名不变）

> **缘起**：通用 R6（`#F0E6B0` 米黄）**不是橙** ⇒ 秘闻「传说」**不能落 R6**。故**并列新增**一小组「信息档专用槽」`color.rarity.info.*`（与通用 7 键并列于 Semantic 层）。
> **命名保留**：`.info.` 是**独立命名空间**，与通用层键名**不冲突、不歧义** ⇒ 维持 `info.legendary | info.epic | info.rare`。

| 档 | token ID | **hex** | 来源 | 相对现网 |
|---|---|---|---|---|
| 传说 | `color.rarity.info.legendary` | **`#FF8033`** | **= `ui/page_message.gd:380` 现网原值** | **零上屏色变更** |
| 史诗 | `color.rarity.info.epic` | **`#B04CD9`** | **= `color.rarity.sheng` 紫（复用，不新造）** | 变更（`#CC66E6 → #B04CD9`） |
| 稀有 | `color.rarity.info.rare` | **`#5B8BD9`** | **= `color.rarity.bao` 蓝（复用，不新造）** | 变更（`#66B3FF → #5B8BD9`） |

> **★ 与通用 7 槽的关系**：`info.epic` / `info.rare` **取 `color.rarity.sheng` / `color.rarity.bao` 的值**（复用，非新色）；**只有 `info.legendary` 是「新槽位、旧色值」**（`#FF8033` 本就是现网上屏色）。⇒ **3 值中仅 1 处需「新增 token」，0 处「新增色值」。**
> **★ 色距（`#FF8033` 与警示/金 天然拉开 · 实测）**：vs `STATE_COLOR.danger #E07878` = **ΔR+31 ΔG+8 ΔB−69**；vs `tier.wang #D9A04C` = **ΔR+38 ΔG−32 ΔB−25** ⇒ 无需新色即可避免「橙＝警示」误读。
> **★ 对比度实测（**方法栏口径 · v1.1**：凡「保上屏色」的决定必须附对比度实测）**：`#FF8033` 在**面板底**上 = **6.62:1**（波 1 后 `#162024`；波 1 前 `#0F2A23` = 6.10:1）；页面底 `#22333A` = 5.23:1；浮层 `#1B272B` = 6.11:1；卡片底 `#1F2B31` = 5.79:1 ⇒ **全部 ≥ 3:1** ⇒ **例外口子未触发，不提议微调**（该项结论 = 无需 1 个候选）。
> **★ 通用 7 槽值 + 键名 —— 冻结，不动**（同 §1）。

---

## 3. `tier.*` 与 `color.rarity.*` → 同源不分化

- `color.rarity.<stem>`（`fan/ling/bao/wang/sheng/xian/dao`）**是** `tier.*` 的 **同名 alias**（`tier.*` = `QUALITY_COLOR` 的 stem 键，见 `ui_theme_config.gd:12` 注释「键 = tier.* 的品级 stem」）。
- ⇒ **`color.rarity.<stem>` 与 `tier.<stem>` 永远同键名、同值、同源、同一 hex**；**不得**为任一者另造第二套值（「禁新词表」红线）。
- ⇒ 二者是**同一色板的两个语义入口**（`tier.*` = 物品品级视角；`color.rarity.*` = 通用稀有度档位视角），**语义并列、键名/值均不分化**。

---

## 4. `color.rarity.*` 三层 token 落位规格（美术线出 · 遵 lead 约束）

| 层 | 落位（`ui_theme.gd` / `ui_theme_config.gd`） | 内容 | 动/不动的边界 |
|---|---|---|---|
| **Primitive** | `ui_theme_config.gd:15-23` `QUALITY_COLOR.*` | **既有 7 hex** | **不动**（一个字节都不改） |
| **Semantic** | `ui_theme.gd` 语义层（如 `:1504-1528` 区） | `color.rarity.<stem>`（7 键 **alias**，返回 `QUALITY_COLOR` 同值）＋ `color.rarity.info.*`（**并列新增** 3 值） | 通用 7 键 **只读别名**；`info.*` 3 值为新增 token（其中 2 值复用 `sheng`/`bao`） |
| **Component** | `ui_theme.gd` 组件/出口层 | **新增** `UITheme.获取稀有度色(表, 词) -> Color`（**收敛入口**，内部查 `RARITY_MAP` ＋ 通用 7 键 / `info.*`） | 新增函数；**既有物品入口语义不动**（见下） |

- **★ 命名**：一律 `color.<域>.<维度>` / `获取<域><维度>色()`（域在前）—— **不套**词条域规范 `<域>词条·<维度>`（lead 已认账错套，勿复发）。
- **★ 既有物品入口的准确位置（盘上回证 · 勘误 · lead 已认账）**：物品「品阶→色」的既有入口 **不在 `UITheme`**，而在 **`main.gd:110 func get_rarity_color(品阶: String) -> Color`**（`:111` 注释「品阶色唯一数据源 = UIThemeConfig」；`:113-116` 映射 凡阶→`fan`…；`:117-118` 调 `UIThemeConfig.get_quality_color(stem)`）；调用点**仅 2 处** = `main.gd:2130` / `:5968`（均传 `物品.品阶`）。⇒ lead 上轮「复用既有 `UITheme.get_rarity_color()`」**作废**（`UITheme.get_rarity_color` 全仓不存在，grep 零命中；且它在启动器 `main.gd` 内、**非 autoload**，`UITheme` 根本调不到）。**`main.gd:110` 语义域 = 「物品品阶」，与「通用稀有度档位」不同域 ⇒ 禁动、禁顺手统一（read-before-write 红线）。**
- **★ `color.rarity.*` / `获取稀有度色` 均无既有实现**（全仓 grep 零命中）⇒ 本规格为**新建**。新增的 `UITheme.获取稀有度色(表, 词)` **直接读唯一真源 `UIThemeConfig.QUALITY_COLOR`**，与 `main.gd:110` 入口**并存、互不替换**。
- **★ 硬约束（lead 终裁 · v1.1）**：`get_rarity_slot(表, 词)` 的**返回值必须 ∈ 通用层 7 键集 `{fan, ling, bao, wang, sheng, xian, dao}`**（或 `.info.*`）；**任何返回集外值的分支 = 规格错误** —— 验收断言**必须有这一条**（例：`assert(get_rarity_slot("秘闻","传说") in ["fan","ling","bao","wang","sheng","xian","dao","info.legendary","info.epic","info.rare"])`）。

---

## 5. 波 4 批 4 · 三站精确替换草案（**依赖波 1 落盘**）

> **站点**：`ui/page_message.gd` 的秘闻等级标签 3 处硬编码色（ART-13 §1 第 16–18 站）。
> **前置**：**依赖波 1 落盘**（波 1 = 所有波的前置；`P0-4换肤分步方案 §2`）。**落盘前须有 64 页真实渲染基线**。
> **表**：`"秘闻"`（`UITheme.获取稀有度色(表, 词)` 的「表」参；见 §4）。

| 站 | 行 | 盘上原行（repr） | 替换后新行（repr） | 目标出口 | from → to |
|---|---|---|---|---|---|
| 批 4·① | `:380` | `'\t\t\t等级标签.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))'` | `'\t\t\t等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "传说"))'` | `获取稀有度色("秘闻","传说")` = `info.legendary` | `#FF8033 → #FF8033`（**零上屏色变更**） |
| 批 4·② | `:383` | `'\t\t\t等级标签.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9))'` | `'\t\t\t等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "史诗"))'` | `获取稀有度色("秘闻","史诗")` = `info.epic` | `#CC66E6 → #B04CD9`（**上屏色变更**） |
| 批 4·③ | `:386` | `'\t\t\t等级标签.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))'` | `'\t\t\t等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "稀有"))'` | `获取稀有度色("秘闻","稀有")` = `info.rare` | `#66B3FF → #5B8BD9`（**上屏色变更**） |

- **不变断言（逐站）**：行数 1→1 ✓｜缩进 TAB 3→3 ✓｜前缀 `'\t\t\t等级标签.add_theme_color_override("font_color", '` 逐字节不变 ✓｜后缀 `')'` 逐字节不变 ✓｜仅中段 `Color(...)` → `UITheme.获取稀有度色(...)` ✓。
- **字节**：`from` = 原值 half-up 近似 hex（**一律以浮点实参为准**）；`to` = `info.*` 常量值。
- **★ 唯一需差分的 = ② ③**；① **零上屏色变更**（`#FF8033` 原样）⇒ **① 不进差分清单**（lead 明令）。

---

## 6. ★ 逻辑改动 · 单列清单（**非色替换** · 与批 4 同次写入）

> lead 口径：`ui/page_message.gd:378-386` 的修复是**两件事同批同次写入** —— ① 三色替换（§5，色替换）；② `else` 分支改为**不建等级标签**（普通档不显示）。② 是**逻辑改动**，规格由美术线出、**落盘由工程线在 GO 批做**。**务必与 §5 同次写入**（同文件两次写入若不合并 ⇒ 二次返工）。

**单列清单（一行）：**

| 编号 | 位置 | 内容 | 标记 | 落盘方 |
|---|---|---|---|---|
| **L1** | `ui/page_message.gd:377-388` | `else` 分支改为**不建等级标签**（普通档不显示）；`稀有` 提升为**显式分支** | `# 逻辑改动 · 非色替换 · 与批 4 同次写入` | **工程线**（GO 批） |

**规格（改写后结构 · 供工程线 1:1 落实；含 §5 三色替换）：**

```gdscript
	# 显示秘闻等级（★ T2 §5-① 修复：普通档不建标签；稀有改为显式分支）
	var 等级标签: Label = null
	if 秘闻等级 == "传说":
		等级标签 = Label.new()
		等级标签.text = "【传说】"
		等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "传说"))
	elif 秘闻等级 == "史诗":
		等级标签 = Label.new()
		等级标签.text = "【史诗】"
		等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "史诗"))
	elif 秘闻等级 == "稀有":
		等级标签 = Label.new()
		等级标签.text = "【稀有】"
		等级标签.add_theme_color_override("font_color", UITheme.获取稀有度色("秘闻", "稀有"))
	# 普通 / 未知档：不建等级标签（不显示）
	if 等级标签 != null:
		UITheme.apply_project_font(等级标签, UITheme.FONT_BODY, false)
		发送者行.add_child(等级标签)
```

- **行为变更（须随 GO 批断言）**：`秘闻等级 == "普通"`（`message_system.gd:185` 默认值）时，**不再**建标签、**不再**上屏「【稀有】」（堵 T2 §5-①「普通错标【稀有】」bug）。
- **与「批 4 色替换」的边界**：§5 三行**只改颜色实参**；本条**改控制流**（`else`→显式分支 + `null` 守卫）。**不得**把本条的「删 `else` 分支」混进 §5 表当等价替换。
- **★ 本条的 `稀有` 分支色 = `info.rare`**（= `#5B8BD9`）—— 与 §5·③ 同色同源，**一次写入**。

---

## 7. 上屏色变更 + 对比度实测（差分 `--expect` 用 · 批 4）

| 行 | 语义 | from（盘上） | to（`info.*`） | 变更性质 | 对比度（面板底 `#162024`） |
|---|---|---|---|---|---|
| `:380` | 秘闻「【传说】」 | `#FF8033` | `#FF8033` | **零上屏色变更**（`info.legendary` 即原值） | 6.62:1（≥3 ✓） |
| `:383` | 秘闻「【史诗】」 | `#CC66E6` | `#B04CD9` | **上屏色变更**（紫·归一 `sheng`） | 3.86:1（≥3 ✓） |
| `:386` | 秘闻「【稀有】」 | `#66B3FF` | `#5B8BD9` | **上屏色变更**（蓝·归一 `bao`） | 4.85:1（≥3 ✓） |

- **对比度口径**：WCAG 相对亮度比（sRGB 线性化）；背景取 `获取面板底色()` = `MAT_BASE_BOTTOM`（波 1 后 `#162024`）。**全部 ≥ 3:1** ⇒ 无微调。
- **★ 方法栏（v1.1 · lead 确立）**：**凡「保上屏色」的决定，必须附对比度实测**（背景取 `获取面板底色()`；≥3:1 方可保，<3:1 才提议 1 个量化微调候选）。
- **布局预期**：三站全为**文字色** ⇒ **不产生布局位移**，差分应为 `COLOR_DELTA`/微 `MICRO_DELTA`，**无 `LAYOUT_SHIFT`**。
- **逻辑改动预期**：普通档秘闻**少一处标签** ⇒ 该卡片可能 **`LAYOUT_SHIFT` 或 `SIZE` 微变**（标签从 `发送者行` 移除）⇒ 差分须把**普通档卡片**纳入观察（这是 **L1 的预期影响**，非色差）。

---

## 8. 依赖与接口

| 项 | 说明 |
|---|---|
| **波 1 落盘** | 硬前置（token 本体）。§5 三站**依赖波 1 落盘**；`ui_theme.gd` 加 `color.rarity.*` / `获取稀有度色()` 属**语义/组件层新增**，需与波 1 一并规划落位 |
| **真实渲染基线** | 三站改后须 `ui_full_accept` 64 页差分（含 `X03_传讯中心`）；**无基线不得落** |
| **`RARITY_MAP` 单一真源** | T2 建议落 `UIThemeConfig`（`const RARITY_MAP` ＋ `get_rarity_slot(表, 词)`）；`UITheme.获取稀有度色(表, 词)` 为其**取色**封装。★ `get_rarity_slot()` **返回值必须 ∈ 7 键集或 `.info.*`**（见 §4 硬约束） |
| **★ 排程硬约束（v1.1 · lead）** | `UITheme.获取稀有度色()` 是**新函数**，受**门3 死函数水位**（当前 **376** / 水位 **396** / 目标 **380**）约束 ⇒ **必须与波 4 批 4「同一落盘批」**（同批新增 ＋ 立刻接线），**禁止单独先落**（否则无调用方 → 推高死函数数 → 被门3 抓） |
| **`main.gd:110 get_rarity_color`** | 物品入口，**禁动**（语义域 = 物品品阶，与通用稀有度档位不同域；见 §4 勘误） |
| **禁新词表** | 不得为 `color.rarity.*` 造第二套 hex、也不得造第二套语义键名（同 §1/§3） |

---

## 9. 交付自检（只读佐证）

- **纯文档**：全仓 `.gd`/`.csv` **零改动**、未执行 git、未跑 Godot。
- **盘上回证**：7 槽值逐字节核于 `ui_theme_config.gd:15-23`；`:380/:383/:386` 原文逐字节核于 `ui/page_message.gd`；`main.gd:110-118` 入口已核（`:113-116` 阶→stem 映射已核）。
- **本文件元数据（盘上实测 · 订正后）**：`bytes=16110 / lines=186 / LF=186 / CR=0 / BOM=False / md5=39b4dcbbcefb1c6fe9bf95e6899c4102`（路径 `design/10-上线冲刺优化/color.rarity美术裁定-波4批4替换草案.md`）。

---

*本裁定 + 草案由 art-director-2（林绘澄）于 PH7-ART-15 产出，**只读**：未改任何 `.gd`/`.csv`/资产、未执行 git、未跑 Godot。7 槽真源逐字节回盘；替换行号与原文 repr 均逐条回盘。据本草案落盘须先落波 1 + 64 页真实渲染基线，改后逐页差分。*
