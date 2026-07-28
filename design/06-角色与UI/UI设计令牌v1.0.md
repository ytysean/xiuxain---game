# 《太玄宗门录》UI 设计令牌 v1.0

> **唯一数据源（Single Source of Truth）**
> 本文件是所有 UI 色值 / 数值的唯一权威来源。后续 `main_theme.tres`（原生控件基础样式）、`ui_theme.gd`（字体层级 + 图标 + 动态色）、`UIThemeConfig.gd`（数据驱动色值）**全部从本文档取色值 / 数值**，禁止在代码或 `.tres` 中另立硬编码常量。
>
> - 版本：v1.0
> - 状态：待主理人审批（采用 spec 色板为基线，含 2 处待确认项）
> - 责任人：文策渊（design-strategist）
> - 适用引擎：Godot 4.7（stable build）
> - 设计分辨率：竖屏 480 × 854
> - 现状基线来源：`ui_theme.gd`（Autoload "UITheme"）现有 Color 常量

---

## 0. 设计基调与设计支柱

- **风格**：深青底 + 淡金边 + 古朴修仙；已落地底部 5 Tab、暗青底金边调性、五大模块骨架。
- **设计支柱（3 条，所有令牌不得违背）**：
  1. **古朴沉浸**：深青 + 淡金 + 毛笔标题，营造修真宗门质感。
  2. **清晰可读**：明确的文字层级与对比度，弱对比色（暗红等）在深底上必须保证可读性。
  3. **一致可维护**：单一数据源 + 分层边界（见 §5），杜绝全局主题塞业务样式、杜绝动态色硬编码。

---

## 1. 色彩体系

### 1.1 背景分层（3 层 + 1 派生沉浸层）

| Token ID | 中文 | Hex | 建议变量名(GD / Config) | 用途 / 覆盖关系 |
|---|---|---|---|---|
| `color.bg.page` | 页面底层背景 | `#1B272B` | `COLOR_BG_PAGE` | 最底层页面底色；所有界面根容器 |
| `color.bg.panel` | 面板主底色 | `#243439` | `COLOR_BG_PANEL` | 面板 / 卡片主底（覆盖在 page 之上） |
| `color.bg.content` | 内容底 ★提案 | `#2C3D43` | `COLOR_BG_CONTENT` | 面板内嵌内容面（输入框 / 列表行 / 内卡），比 panel 更亮一档。**spec 未给值，本值为设计提案，待美术确认** |
| `color.bg.immersive` | 墨底 / 状态栏底 ★派生 | `#0E1517` | `COLOR_BG_IMMERSIVE` | 顶部状态栏 / 沉浸态（如开场、过场）。沿用现状 `COLOR_STATUSBAR_BG`，spec 未单列 |

> 层级关系：`page(#1B272B)` < `panel(#243439)` < `content(#2C3D43)` < `immersive(#0E1517 更暗，仅用于状态栏/沉浸)`。
> `content` 与 `immersive` 为 spec 未明示项，已标注 ★，需主理人 / 美术确认。

### 1.2 文字分层

| Token ID | 中文 | Hex | 建议变量名 | 用途 / 占比 |
|---|---|---|---|---|
| `color.text.title1` | 一级标题 | `#E6C778` | `COLOR_TEXT_TITLE1` | 主标题 / 模块大标题（100% 强调） |
| `color.text.title2` | 二级标题 | `#F0E6D2` | `COLOR_TEXT_TITLE2` | 区块标题 / 弹窗小标题（85%） |
| `color.text.body` | 正文主色 | `#E0D5BE` | `COLOR_TEXT_BODY` | 正文主色（75%） |
| `color.text.body-dim` | 次级 / 弱化正文 ★ | `#C8B896` | `COLOR_TEXT_BODY_DIM` | 弱化正文 / 次要信息（spec「文字层级」中 75% 档）。**与 `realm.lianqi` 共用同一值**。见 §8 待确认 |
| `color.text.aux` | 辅助说明 | `#8A7E68` | `COLOR_TEXT_AUX` | 辅助说明 / 占位提示（65%） |
| `color.text.accent` | 强调数字 | `#FFD77A` | `COLOR_TEXT_ACCENT` | 核心数值 / 强调数字（加粗 + 此色） |
| `color.text.disabled` | 禁用灰 | `#55554F` | `COLOR_TEXT_DISABLED` | 禁用态文字 / 图标 |

> **spec 内部冲突提示**：spec 在「给定目标色值」中写「正文主色 `#E0D5BE`」，在「文字层级」中又写「正文 `#C8B896`(75%)」。二者不一致。本文档处理：**`#E0D5BE` 作为正文主色（`color.text.body`），`#C8B896` 作为弱化正文档（`color.text.body-dim`）**，以保留层级梯度。最终取舍见 §8。

### 1.3 通用边框色

| Token ID | 中文 | Hex | 建议变量名 | 用途 |
|---|---|---|---|---|
| `color.border.gold` | 边框主色（淡金） | `#C9A865` | `COLOR_BORDER_GOLD` | 所有面板 / 按钮 / 分割线描边主色 |

### 1.4 功能色（成功 / 警示）

| Token ID | 中文 | Hex | 建议变量名 | 用途 |
|---|---|---|---|---|
| `color.status.success` | 成功 / 增益 | `#7ED39A` | `COLOR_STATUS_SUCCESS` | 增益、正收益、成功反馈 |
| `color.status.danger` | 警示 / 失败 | `#E07878` | `COLOR_STATUS_DANGER` | 扣减、失败、异常、负值提醒 |

> 表面填充（如成功提示条底色）由 engineering-lead 以本基色取低透明度（约 12%–18% alpha）派生，令牌文档只强制基色 hex，避免脆弱硬编码。

### 1.5 业务色 — 品级（物品 / 装备，8 档）

| Token ID | 中文 | Hex | 建议变量名 | 备注 |
|---|---|---|---|---|
| `tier.fan` | 凡品 | `#D6D6D6` | `COLOR_TIER_FAN` | 白灰色 |
| `tier.liang` | 良品 | `#4CAF7A` | `COLOR_TIER_LIANG` | 绿 |
| `tier.ling` | 灵品 | `#4CAF7A` | `COLOR_TIER_LING` | **与良品同色（spec 明示）。见 §8，建议灵品升一档区分** |
| `tier.bao` | 宝品 | `#5B8BD9` | `COLOR_TIER_BAO` | 蓝 |
| `tier.wang` | 王品 | `#D9A04C` | `COLOR_TIER_WANG` | 金 |
| `tier.sheng` | 圣品 | `#B04CD9` | `COLOR_TIER_SHENG` | 紫 |
| `tier.xian` | 仙品 | `#F0E6B0` | `COLOR_TIER_XIAN` | 浅金 |
| `tier.dao` | 道品 | `#E8F0FF` | `COLOR_TIER_DAO` | 近白冷光 |

### 1.6 业务色 — 境界（5 档）

| Token ID | 中文 | Hex | 建议变量名 | 备注 |
|---|---|---|---|---|
| `realm.lianqi` | 练气 | `#C8B896` | `COLOR_REALM_LIANQI` | 与 `color.text.body-dim` 同值（共用调性） |
| `realm.zhuji` | 筑基 | `#4CAF7A` | `COLOR_REALM_ZHUJI` | 与 `tier.liang/ling` 同值 |
| `realm.jindan` | 金丹 | `#5B8BD9` | `COLOR_REALM_JINDAN` | 与 `tier.bao` 同值 |
| `realm.yuanying` | 元婴 | `#D9A04C` | `COLOR_REALM_YUANYING` | 与 `tier.wang` 同值 |
| `realm.huashen` | 化神 | `#B04CD9` | `COLOR_REALM_HUASHEN` | 与 `tier.sheng` 同值 |

> 境界色与品级中低档（良~圣）刻意共用同一组色值，形成「品级—境界」视觉同源，利于玩家迁移认知；仅「练气 `#C8B896`」与弱化正文共用。此为有意的跨域对齐，非冲突。

### 1.7 派生 / 控制态色（pressed / disabled / 沉浸）

| Token ID | 中文 | Hex | 建议变量名 | 来源 | 用途 |
|---|---|---|---|---|---|
| `color.control.pressed` | 按下态底色 ★派生 | `#141B1C` | `COLOR_CONTROL_PRESSED` | 沿用现状 `COLOR_BTN_PRESSED` | 主/次按钮 pressed 底色；spec 未给 |
| `color.control.disabled` | 禁用态按钮底 ★派生 | `#2E3232` | `COLOR_CONTROL_DISABLED` | 沿用现状 `COLOR_BTN_DISABLED` | 禁用按钮底色；spec 未给（spec 仅给禁用「文字」灰 `#55554F`） |

> ★ 派生项 spec 未定义，沿用现状 `ui_theme.gd` 值，作为提案保留；若主理人希望与 `bg.page` 强关联，可改为 `bg.page` 的进一步压暗值，由 engineering-lead 在 `UIThemeConfig` 中以相对运算处理。

### 1.8 色彩令牌速查总表

```
背景    page=#1B272B  panel=#243439  content=#2C3D43*  immersive=#0E1517*
文字    title1=#E6C778  title2=#F0E6D2  body=#E0D5BE  body-dim=#C8B896*  aux=#8A7E68  accent=#FFD77A  disabled=#55554F
边框    border.gold=#C9A865
功能    success=#7ED39A  danger=#E07878
控制态  pressed=#141B1C*  disabled.btn=#2E3232*
品级    fan=#D6D6D6  liang=#4CAF7A  ling=#4CAF7A*  bao=#5B8BD9  wang=#D9A04C  sheng=#B04CD9  xian=#F0E6B0  dao=#E8F0FF
境界    lianqi=#C8B896  zhuji=#4CAF7A  jindan=#5B8BD9  yuanying=#D9A04C  huashen=#B04CD9
（标 * 者为 spec 未明示 / 提案 / 待确认项）
```

---

## 2. 字体与排版

### 2.1 字体族与恢复说明

| 角色 | 字体 | 资源路径 | 状态 |
|---|---|---|---|
| 标题（毛笔体） | MaShanZheng | `res://ui/assets/fonts/MaShanZheng-Regular.ttf` | 用户已移出项目，**需先跑子集化脚本恢复**（沿用 `ui_theme.gd` 现有 `FONT_TITLE_PATH` 常量位置） |
| 正文（宋体） | NotoSerifSC | `res://ui/assets/fonts/NotoSerifSC-Regular.otf` | 同上，需恢复 |

- **恢复前**：所有文本使用 **Godot 默认回退字体**，保证可运行、不报错。
- **`.tres` 暂不绑定字体文件**（避免引用缺失字体资源报错）；字体绑定在 `ui_theme.gd` 的 `apply_*_font` helper 中按路径探测（缺失则回退），等用户恢复子集字体后再由 engineering-lead 在 `.tres` 补 `default_font` 绑定。

### 2.2 字号阶梯（≥ 5 级，基准以 spec 建议为准）

| Token ID | 名称 | 字号(px) | 建议变量名 | 典型用途 |
|---|---|---|---|---|
| `font.size.display` | 巨号 / 大标题 | 40 | `FONT_DISPLAY` | 主弹窗标题、核心数字放大、 splash |
| `font.size.h1` | 一级标题 | 32 | `FONT_H1` | 模块主标题（对应 `color.text.title1`） |
| `font.size.h2` | 二级标题 | 26 | `FONT_H2` | 区块标题（对应 `color.text.title2`） |
| `font.size.body` | 正文 | 24 | `FONT_BODY` | 正文主色（对应 `color.text.body`） |
| `font.size.caption` | 辅助说明 | 20 | `FONT_CAPTION` | 辅助说明（对应 `color.text.aux`） |
| `font.size.dense` | 密集数值 | 18 | `FONT_DENSE` | 密集表 / 列表单元格 / 次级数值（第 6 级，保证阶梯 ≥5） |

> 现状 `ui_theme.gd` 字号偏小（TITLE 24 / VALUE 18 / BODY 16 / AUX 12）。本文档采 spec 基线整体上调（见 §7 差异）。`FONT_DISPLAY`(40) 为新增巨号档，用于首页 / 弹窗主视觉。

### 2.3 行高 / 字重 / 字距

**行高（line-height 倍数 → Godot `line_spacing` px，= (倍数−1)×字号，取整）**

| 层级 | 推荐倍数 | line_spacing(px) |
|---|---|---|
| display / h1 | 1.25–1.30 | ≈ 10 |
| h2 | 1.35 | ≈ 9 |
| body | 1.50 | ≈ 12 |
| caption / dense | 1.40 | ≈ 8 / 7 |

**字重（映射到 FontFile `weight`，中文以字体本身为准）**

| 用法 | 字重 | 说明 |
|---|---|---|
| 标题（MaShanZheng） | 装饰体（等效 Bold） | 毛笔体自带笔锋，无需额外加粗 |
| 二级标题 | Medium 500 | NotoSerifSC Medium |
| 正文 / 辅助 / 密集 | Regular 400 | NotoSerifSC Regular |
| 强调数字 | **Bold 700** + `color.text.accent` | 核心数值加粗并以 `#FFD77A` 着色 |

**字距**：中文默认 0；标题（`h1`/`display`）可 +2px 字距增强仪式感（可选，由 `.tres` 控制）。

### 2.4 字体绑定规则（Godot 4.7 兼容）

- 字体文件恢复前：`.tres` / `ui_theme.gd` 均不绑定 `font_file`，使用默认回退。
- 恢复后：`ui_theme.gd` 通过 `FONT_TITLE_PATH` / `FONT_BODY_PATH` 探测加载；`.tres` 的 `default_font` 由 engineering-lead 绑定到已落盘字体，缺失时 Godot 自动回退（不阻断）。

---

## 3. 间距 / 圆角 / 边框阶梯

### 3.1 间距阶梯（4 / 8 / 12 / 16 / 20 / 24 / 32，px）

| Token | 值(px) | 建议变量名 | 用途 |
|---|---|---|---|
| space-1 | 4 | `SPACE_1` | 极紧内距（图标与文字、细分割内距） |
| space-2 | 8 | `SPACE_2` / `GRID` | 8px 栅格基线；紧凑间距 |
| space-3 | 12 | `SPACE_3` | 小组件间距 |
| space-4 | 16 | `SPACE_4` / `MARGIN` / `PAD_PANEL` | 面板内边距、默认外边距 |
| space-5 | 20 | `SPACE_5` | 区块间距 |
| space-6 | 24 | `SPACE_6` | 大区块间距 |
| space-7 | 32 | `SPACE_7` | 页面级留白、模块间距 |

> **8px 栅格基线**：组件外边距 / 尺寸对齐到 8（`GRID=8` 沿用现状）；`space-1`(4) 仅用于组件内部极细间距（半栅格），不参与大块对齐。

### 3.2 圆角阶梯（4 / 6 / 8 / 12 / 16 / 24，px）

| Token | 值(px) | 建议变量名 | 用途 |
|---|---|---|---|
| radius-xs | 4 | `RADIUS_XS` | 标签 / 小徽章 / 芯片 |
| radius-sm | 6 | `RADIUS_BUTTON` | 按钮（沿用现状 `RADIUS_BUTTON=6`） |
| radius-md | 8 | `RADIUS_PANEL` | 面板 / 卡片（沿用现状 `RADIUS_PANEL=8`） |
| radius-lg | 12 | `RADIUS_LG` | 大卡片 / 弹窗内容区 |
| radius-xl | 16 | `RADIUS_XL` | 主弹窗外框 |
| radius-2xl | 24 | `RADIUS_2XL` | 全屏沉浸容器 / 圆角巨卡 |

### 3.3 边框宽度（1 / 2 / 3，px）

| Token | 值(px) | 建议变量名 | 用途 |
|---|---|---|---|
| border-w-1 | 1 | `BORDER_W` | 默认描边（面板 / 按钮，沿用现状 `BORDER_W=1`） |
| border-w-2 | 2 | `BORDER_W2` | 选中 / 强调边框、主按钮 hover |
| border-w-3 | 3 | `BORDER_W3` | 重要分隔 / 主视觉框（少量使用，避免滥用） |

### 3.4 尺寸 / 布局令牌（沿用现状，便于平滑迁移）

| 类别 | Token | 值(px) | 建议变量名 |
|---|---|---|---|
| 图标/资产 | 小/中/大/特大 | 48 / 64 / 120 / 240 | `SIZE_SM` / `SIZE_MD` / `SIZE_LG` / `SIZE_XL` |
| 按钮高 | 主/次 | 64 / 48 | `BTN_H_PRIMARY` / `BTN_H_SECONDARY` |
| 导航 | Tab 高 / 顶栏高 | 64 / 48 | `TAB_H` / `TOPBAR_H` |
| 模块骨架 | 总览区高 / 核心网格高 | 120 / 240 | `OVERVIEW_H` / `CORE_GRID_H` |

---

## 4. 分层边界约定（关键 · 强约束）

UI 系统采用**混合双轨**方案，各方职责严格隔离，任一角色不得越界：

| 层 | 责任方 | 放什么 | 不放什么 |
|---|---|---|---|
| **`.tres`** | engineering-lead（程基岩） | 原生控件**基础样式**：StyleBox（基于本文档色值/数值）、`default_font` 绑定（字体恢复后）、控件默认尺寸 | 业务样式、动态色、品级/境界等业务色 |
| **`ui_theme.gd`** | design-strategist（文策渊） | 字体层级 helper、图标（`ICON_BY_LABEL`）、**动态色** getter（从 `UIThemeConfig` 取） | 业务组件差异样式、硬编码 hex |
| **`UIThemeConfig.gd`** | design-strategist（文策渊） | **数据驱动色值**：以本文档 Token ID 为键的色值表，供运行时读取 / 换皮 | StyleBox 实现、字体绑定 |
| **组件内主题覆盖** | 各业务 UI 作者 | 仅本业务组件的**差异**覆盖（如某列表行高亮态） | 全局通用样式、跨组件业务色 |

**两条禁令（写入代码评审红线）：**
1. ❌ **禁止在全局主题（`.tres` / `project.godot` theme_override）塞业务样式**（品级框、特定弹窗花纹等）。业务差异一律走「组件内主题覆盖」。
2. ❌ **禁止动态色硬编码**（任何 `Color(#...)` / 魔法数字散落在场景或脚本）。动态色一律由 `UIThemeConfig` 提供，静态基础色一律由 `.tres` 提供，二者皆源自本文档。

> 铁律落地：`ui_theme.gd` 顶部原有「业务 UI 一律调用本模块，组件内禁止硬编码颜色/尺寸」继续有效；本文档为其上游数据源。

---

## 5. Godot 4.7 兼容性提示（务必遵守）

- **`Button.icon_max_width` 在用户 Godot 4.7 stable build 中缺失** → 本文档不依赖该属性；图标尺寸统一由 `ui_theme.gd` 的 `load_icon_sized(label, size)` 光栅化控制（现状已用此绕过方案）。
- **`StyleBoxTexture.set_margin_all` 缺失** → 本文档**只定义色值 / 数值常量**，不规定 StyleBox 具体实现；StyleBox（9-slice 边距、content margin 等）由 engineering-lead 在 `.tres` 中按本文档数值实现。
- **字体绑定暂缓** → `.tres` 暂不做 `default_font` 绑定（避免引用缺失字体资源报错），等用户恢复子集字体后由 engineering-lead 补。
- 所有色值以 **hex 字符串 + 0–255 整数** 形式给出，便于 `UIThemeConfig` 与 `.tres` 直接消费，不绑定任何易碎 API。

---

## 6. 与现状 `ui_theme.gd` 差异标注 + 采用建议

> 现状色值由 `ui_theme.gd` 的 `Color(r,g,b)` 浮点常量反推 hex 得到。差异量级：极小（≤3/255）/ 小（≤12）/ 中（≤40）/ 大（>40）。

| # | 语义 | 现状 hex（ui_theme.gd） | spec hex | 差异量级 | 采用建议 |
|---|---|---|---|---|---|
| 1 | 页面底 bg | `#1C2628` | `#1B272B` | 极小 | **采 spec** |
| 2 | 面板底 panel | `#232D2E`（注：代码注释标「占位色」） | `#243439` | 小 | **采 spec**（现状本为占位，正合时机替换） |
| 3 | 边框金 border | `#C8A86A` | `#C9A865` | 极小 | **采 spec** |
| 4 | 一级标题 | 现状用 `border.gold #C8A86A` 作标题色 | `#E6C778` | 中（更亮金） | **采 spec**：一级标题独立取 `#E6C778`，边框维持 `#C9A865` |
| 5 | 正文 | `#E8E0CE` | `#E0D5BE` | 小（更暖更暗） | **采 spec** |
| 6 | 辅助 | `#A8A8A0`（中性灰） | `#8A7E68`（暖金灰） | 中 | **采 spec**（更贴合古朴调性） |
| 7 | 警示/异常红 | `#8B3A3A`（暗红，作负值/异常） | `#E07878`（亮红） | 大（对比度↑） | **采 spec**：暗红在深青底对比不足（≈1.9:1），亮红 `#E07878` 可读性显著更优 |
| 8 | 核心数值/选中金（原 `COLOR_TEXT_GOLD`） | `#F0CE6B` | 强调数字 `#FFD77A` | 小（更亮） | **采 spec**：映射到 `color.text.accent` 角色（值/选中态） |
| 9 | 禁用 | 现状仅禁用按钮底 `#2E3232` | 禁用文字 `#55554F` | 新增文字禁用色 | **采 spec 新增 `text.disabled`**；禁用按钮底保留为派生 `color.control.disabled` |
| 10 | 成功/增益 | 现状无 | `#7ED39A` | 新增 | **采 spec 新增 `status.success`** |
| 11 | 二级标题 / 强调数字 | 现状无 | `#F0E6D2` / `#FFD77A` | 新增 | **采 spec 新增 `title2` / `accent`** |
| 12 | 内容底 | 现状无 | （spec 未给） | 新增★提案 | **提案 `#2C3D43`，待美术确认** |
| 13 | 墨底/状态栏 | `#0E1517` | spec 未给 | 沿用 | **沿用现状派生 `bg.immersive`** |
| 14 | 按下/禁用按钮底 | `#141B1C` / `#2E3232` | spec 未给 | 沿用 | **沿用现状派生 `control.pressed` / `control.disabled`** |

**字号差异（现状 → spec 基线）**：TITLE 24→(h1 32) / VALUE 18→(dense 18 保留，accent 用 body 24 加粗) / BODY 16→24 / AUX 12→20。整体上调，采 spec。

**结论**：除 §8 两处待确认项外，**色板完全采用 spec**；与现状差异均为小幅/预期内，且现状多处为「占位色」，替换成本低、无大面积返工风险。

---

## 7. 待补充 / 待确认令牌清单

| 项 | 类型 | 说明 | 建议处理 |
|---|---|---|---|
| **A. 正文色冲突** | spec 内部冲突 | spec 同时给「正文主色 `#E0D5BE`」与「文字层级 正文 `#C8B896`」 | 本文档已分置为 `body(#E0D5BE)` + `body-dim(#C8B896)`。**请主理人确认此拆分是否成立**，或指定 `#C8B896` 的正式语义 |
| **B. 灵品 = 良品同色** | 品级歧义 | spec 明示 `灵品 #4CAF7A` 与 `良品 #4CAF7A` 同值 | 保留 spec 值，但**建议灵品升一档区分**（如青蓝 `#3FA9C9`）或保持同色仅以图标/描边区分。待主理人裁定 |
| **C. 内容底 `bg.content`** | spec 未给 | 面板内嵌面底色 | 提案 `#2C3D43`，待美术确认 |
| **D. 控制态派生色** | spec 未给 | `control.pressed #141B1C`、`control.disabled #2E3232` | 沿用现状，作为提案；若要与 `bg.page` 强关联可改为相对运算 |

> 以上 A/B 为需主理人拍板的**语义级**决策；C/D 为数值级提案，可先按本文档落地、后续微调。

---

## 8. 附录：令牌 → Godot 主题属性 / UIThemeConfig 键 映射建议

| 令牌类别 | `UIThemeConfig.gd` 键（建议） | 主要消费处 |
|---|---|---|
| 所有 `color.*` / `tier.*` / `realm.*` | `"color.bg.page"` 等（点分 Token ID 直作键） | `ui_theme.gd` getter、`UIThemeConfig` 查表、`UIThemeConfig` 驱动换皮 |
| 所有 `font.size.*` | `"font.size.body"` 等 | `ui_theme.gd` `apply_*_font` 的 `font_size` override |
| `space*` / `radius*` / `border-w*` | `"space.4"` / `"radius.md"` / `"border.w.1"` 等 | `.tres` StyleBox、`ui_theme.gd` 控件 helper |
| 尺寸/布局 | `"btn.h.primary"` 等 | `.tres` 控件 `custom_minimum_size` |

> 迁移路径：本 v1.0 文档定稿后 → 由 design-strategist 据此重写 `ui_theme.gd` 常量（替换现状浮点常量）→ 由 design-strategist 生成 `UIThemeConfig.gd` 数据表 → 由 engineering-lead 在 `main_theme.tres` 以本文档数值落地 StyleBox 基础样式。三者皆以本文档为唯一数据源。
