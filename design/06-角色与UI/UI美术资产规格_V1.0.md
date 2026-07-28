---
doc_id: ui_art_asset_spec_v1.0
doc_title: 《太玄宗门录》UI 美术资产规格（V1.0）
doc_version: v1.0
update_date: 2026-07-28
doc_type: UI美术资产规格（执行层 · art-director）
game_formal_name: 太玄宗门录
game_market_name: 开局接手太玄宗
---

# 《太玄宗门录》UI 美术资产规格（V1.0）

> **职责边界**：本文件归 art-director（S1 UI 重构第三条线）所有；记录古风美术资产清单、规格、UITheme 接入点与自检。
> 执行层补充：`UI交互规范_古风经营A版_V1.0.md`（UX/交互）+ `UI硬性约束规范.md`（架构） + `太玄宗门录_角色与UI美术规范.md`（资产层）。
> 冲突优先级遵循 V1.0 规范 §7.3（UI硬性约束 > 本规范 > 美术规范）。

---

## 一、文档信息

- 适用范围：S1 全量 UI 界面重构（核心宫格 / 底部 Tab / 顶部状态栏 / 次功能滚动区 / 面板蒙皮 / 分割线 / 字体）
- 美术定位：竖屏古风修真宗门经营 · 掌教第一视角 · 沉稳克制
- 与 V1.0 规范呼应：§2.4 通用组件规范、§3 古风调性落地、§3.3 装饰占比红线、§4 交互反馈

---

## 二、资产总清单

```
ui/assets/
├── icons/                         ← 线稿图标集 15 个（统一 viewBox 64×64，stroke #C8A86A，stroke-width 4）
│   ├── jianyu.svg        殿宇     建筑宫格 + 建筑 Tab 复用
│   ├── suanpan.svg       算盘     坊市宫格（§3.1 修真器物映射）
│   ├── danhuo.svg        丹火     修炼宫格（鼎中炼化之火）
│   ├── shandong.svg      山洞     洞府宫格（洞天福地）
│   ├── juanshu.svg       卷轴     任务宫格（宗门要务）
│   ├── boce.svg          簿册     账册宫格（区别于卷轴的装帧式账本）
│   ├── zongmen.svg       牌坊     宗门 Tab（门楣匾额）
│   ├── dizi.svg          弟子     弟子 Tab + 弟子资源复用（道冠人形）
│   ├── lilian.svg        历练     历练 Tab（远山+蜿蜒山径）
│   ├── jishi.svg         纪事     纪事 Tab（古籍+狼毫笔，区别卷轴/簿册）
│   ├── lingshi.svg       灵石     灵石资源（晶簇）
│   ├── lingqi.svg        灵气     灵气资源（流动气旋）
│   ├── shichen.svg       时辰     时辰资源（日轮八芒）
│   ├── rili.svg          日历     推演时日按钮（可选，本轮未接入按钮）
│   └── chevron.svg       chevron  CollapsibleCategory 折叠指示（旋转复用）
├── panel_ink.svg                 ← 面板暗纹贴图（自包含蒙皮，9-slice 锁定四角）
├── divider_cloud.svg             ← 分割线细云纹（1px 暗金线 + 云纹意象，横向 64px 单元循环）
└── fonts/                        ← 待补字体落盘点（详见 §五）
    ├── MaShanZheng-Regular.ttf   ← 标题书法（待补）
    └── NotoSerifSC-Regular.otf   ← 正文印刷宋体（待补）
```

> 参考图（design/06-角色与UI/reference/ 下两版 AI 生图）显示 `坊市` 用了"古书"意象，与 V1.0 §3.1 的"坊市=算盘"修真器物映射不一致。**以 V1.0 规范为准**（任务锚定权威规范），本套资产用算盘；参考图 CJK 乱码忽略。

---

## 三、图标规格

### 3.1 统一风格规范

| 属性 | 规范值 | 备注 |
|---|---|---|
| 视图框 | `viewBox="0 0 64 64"` | 统一基准，Godot 4 原生 SVG 导入为 Texture2D |
| 描边色 | `#C8A86A` | 与 `UITheme.COLOR_BORDER_GOLD` 同源（暗金调性） |
| 描边粗细 | `stroke-width="4"` | 大图标的相对重量 ~6.25%；16px 资源图标栅格化后约 1px |
| 填充 | `fill="none"` | 严格线稿，无填色块（修真器物取意象） |
| 线帽 / 拐角 | `stroke-linecap="round"` + `stroke-linejoin="round"` | 笔意圆融，避免硬直角 |
| 资源图标尺寸 | `Vector2(16, 16)` 占位 | top_bar slot 内显示 |
| 按钮图标尺寸 | `Vector2(isz, isz)` 占位（`isz=SIZE_SM=48` 大 / `24` 小） | action_button 内显示 |
| 折叠指示尺寸 | `Vector2(24, 24)` 占位 | CollapsibleCategory 内显示 |
| 拉伸模式 | `TextureRect.STRETCH_KEEP_ASPECT_CENTERED` | 居中显示不裁切不拉伸 |

### 3.2 修真器物映射（V1.0 §3.1）

| 修真功能 | 器物映射 | 文件 | 备注 |
|---|---|---|---|
| 建筑 | 殿宇（庑殿顶 + 双柱 + 须弥座 + 脊饰） | `jianyu.svg` | 含反宇上翘屋檐 |
| 坊市 | 算盘（框 + 中档 + 4 竖档 + 8 算珠） | `suanpan.svg` | 与参考图"古书"意象冲突，规范优先 |
| 修炼 | 丹火（鼎 + 三足 + 内外焰） | `danhuo.svg` | 取丹道之象 |
| 洞府 | 山洞（圆顶山丘 + 拱形洞门） | `shandong.svg` | 洞天福地 |
| 任务 | 卷轴（主体 + 双轴 + 三行古文） | `juanshu.svg` | 宗门要务 |
| 账册 | 簿册（左右翻页古籍 + 书脊 + 双页正文） | `boce.svg` | 区别于卷轴 |
| 宗门 | 牌坊（庑殿顶 + 中枋 + 双柱 + 匾额） | `zongmen.svg` | 门楣仪制 |
| 弟子 | 道冠人形（冠顶 + 圆首 + 袍肩） | `dizi.svg` | 复用：Tab + 资源槽 |
| 历练 | 远山三峰 + 蜿蜒山径 | `lilian.svg` | 外出历练 |
| 纪事 | 古籍 + 狼毫笔（含笔锋泪滴） | `jishi.svg` | 录事成文（区别卷轴/簿册） |
| 灵石 | 多面晶簇（菱形外轮廓 + 中纵中横 + 侧棱 + 顶角星点） | `lingshi.svg` | 修真货币 |
| 灵气 | 流动气旋（连续流云曲线） | `lingqi.svg` | 天地灵气 |
| 时辰 | 日轮八芒（圆 + 8 向线） | `shichen.svg` | 一日时辰 |
| 推演时日 | 日历（双环装订 + 表头 + 双列三行格） | `rili.svg` | 可选 · 按钮图标待接入 |
| 折叠 | chevron（V 形下指） | `chevron.svg` | 旋转复用 |

### 3.3 装饰占比自检（V1.0 §3.3 红线 ≤ 5%）

- 每个图标绘制约 6–12 个 SVG 元素（线段 / 圆 / 矩形 / 路径），相对 64×64 画布的覆盖面积均在 5% 以下（线稿而非满铺花纹）。
- 没有满铺花纹、浮雕、立体投影、卡通元素，全部 stroke-only line art。

---

## 四、贴图规格

### 4.1 panel_ink.svg — 面板暗纹贴图（自包含蒙皮）

| 属性 | 规范值 |
|---|---|
| 视图框 | `viewBox="0 0 256 256"`（方形，9-slice 自适应任意面板宽高比） |
| 底色 | `#232D2E`（与 `UITheme.COLOR_PANEL_BG` 同源，烤入 SVG 以兼容单 stylebox slot） |
| 圆角 | `rx="16"` |
| 暗金描边 | `#C8A86A`，`stroke-width="4"` |
| 暗纹 | 3 组低透明度墨势（`<path opacity="0.18-0.28">`）+ 2 颗墨点 + 1 组飞白 |
| 装饰占比 | 单面板非金色面积覆盖 < 5%（V1.0 §3.3 红线内） |
| 9-slice 边距 | `set_margin_all(RADIUS_PANEL + 8)` = 16 锁定四角圆角区 |

**设计取舍（与 V1.0 §2.4 规范的差距）**：

- V1.0 §2.4 要求 1px 暗金描边。**自包含面板蒙皮的描边随面板 9-slice 等比缩放**，典型 S1 面板（480×120）实测 ~2–3px。
- 原因：PanelContainer 仅支持单 stylebox slot（"panel"），单 slot 无法同时叠加"精确 1px 边框（StyleBoxFlat）+ 暗纹贴图"。在"风格合规"与"规范字面"之间，选择了前者（视觉一致性优先），并提供 `UITheme.make_panel_stylebox(false)` 回退路径。
- 手机端 2–3px 暗金描边的可读性反而更佳；如需严格 1px（小型标签、按需），调用方传 `use_ink=false` 即获严格 StyleBoxFlat。

### 4.2 divider_cloud.svg — 分割线细云纹

| 属性 | 规范值 |
|---|---|
| 视图框 | `viewBox="0 0 256 4"`（横向 64px 一组云纹单元循环，4 组 / 256） |
| 主线 | `#C8A86A`，`stroke-width="1.5"`，贯穿横向（V1.0 §2.4 规范 1px，提升 0.5px 以保留云纹辨识度） |
| 云纹 | 4 组薄云卷（`opacity="0.55"`），单组水平跨 16px，留白 40px |
| 平铺 | `TextureRect.STRETCH_TILE`（建议导入时开启 `Texture2D.repeat = true`；不开则横向拉伸，云纹仍以淡描边保留） |
| 控件高度 | `Vector2(0, BORDER_W + 1)` = 2（略高于 1px 给云纹意象留呼吸，仍属极细装饰） |

### 4.3 贴图落盘路径

| 文件 | res:// 路径 |
|---|---|
| panel_ink.svg | `res://ui/assets/panel_ink.svg` |
| divider_cloud.svg | `res://ui/assets/divider_cloud.svg` |

---

## 五、字体规范（待补）

> 当前环境无法下载字体文件，故 UITheme 仅保留**路径常量**与**字号/颜色 override fallback**（不阻断运行）。字体落盘后 `apply_fonts()` 自动拾取。

### 5.1 字体族选择（基于 V1.0 §3.1 "标题书法 / 正文印刷"）

| 层级 | 字体族 | 类型 | 来源与许可 | 落盘路径 | 取舍 |
|---|---|---|---|---|---|
| 面板大标题（24dp） | **Ma Shan Zheng**（马善政楷书） | 楷书 / 书法体 | Google Fonts · OFL 1.1 开源 | `res://ui/assets/fonts/MaShanZheng-Regular.ttf` | 笔意圆融契合修真世界观，免费可商用，与暗金描边搭调 |
| 正文印刷（16/18/12dp） | **Noto Serif SC**（思源宋体） | 衬线 / 印刷宋体 | Google Fonts / Adobe · OFL 1.1 开源 | `res://ui/assets/fonts/NotoSerifSC-Regular.otf` | V1.0 §3.1 要求"清晰古风印刷类字体"，宋体是修真出版物（玉牒、典籍）的天然承载 |

### 5.2 加载方式

- UITheme 通过 `_ensure_fonts()` 在首次 `apply_*_font` 或 `apply_fonts()` 调用时探测定点文件：
  1. `FileAccess.file_exists(FONT_TITLE_PATH)` → `load(path) as FontFile` 加载标题字体。
  2. 同理加载正文字体。
  3. 任一缺失即静默退回 `add_theme_font_size_override(...) + add_theme_color_override(...)` 的现有行为，不刷错误日志打断运行。
- 启动时调用 `UITheme.apply_fonts()` 即可获知字体是否就位（返回 bool，供启动日志 / 降级提示）。
- **Fallback 行为**：F5 当前阶段（无字体文件）= 字号 + 暗金/浅米/浅灰颜色 override；落盘字体后 = 自动叠加字体 override，组件零改动。

### 5.3 与现有 int 常量的命名区分

> UITheme 已有 `const FONT_TITLE: int = 24`（字号）。为避免与"路径常量"冲突，新增路径常量统一以 `*_PATH` 后缀命名（`FONT_TITLE_PATH` / `FONT_BODY_PATH`）。见 §六集成点。

---

## 六、UITheme 集成点（艺术资产契约）

> 单文件样式管理（V1.0 §7.3）· 组件零硬编码路径 · 改皮/换套仅动本节。

### 6.1 路径常量（新增节：`美术资产路径`）

```gdscript
const ASSET_DIR: String = "res://ui/assets/"
const ICON_DIR: String = ASSET_DIR + "icons/"
const PANEL_INK_TEX: String = ASSET_DIR + "panel_ink.svg"
const DIVIDER_TEX: String = ASSET_DIR + "divider_cloud.svg"
const FONT_TITLE_PATH: String = ASSET_DIR + "fonts/MaShanZheng-Regular.ttf"
const FONT_BODY_PATH: String = ASSET_DIR + "fonts/NotoSerifSC-Regular.otf"
```

### 6.2 图标 registry（新增）

```gdscript
const ICON_BY_LABEL: Dictionary = {
    "建筑": "jianyu", "坊市": "suanpan", "修炼": "danhuo",
    "洞府": "shandong", "任务": "juanshu", "账册": "boce",
    "宗门": "zongmen", "弟子": "dizi", "历练": "lilian", "纪事": "jishi",
    "灵石": "lingshi", "灵气": "lingqi", "时辰": "shichen",
    "推演时日": "rili", "折叠": "chevron",
}
```

### 6.3 Helper 接口（新增 / 改造）

| Helper | 签名 | 用途 | 改造点 |
|---|---|---|---|
| `load_icon(label: String) -> Texture2D` | 按 Chinese 标签取图标 | 组件统一取图入口 | 新增；label 不在 registry 返 null |
| `load_panel_ink() -> Texture2D` | 加载面板暗纹 | 自包含面板蒙皮 | 新增 |
| `load_divider_cloud() -> Texture2D` | 加载分割线云纹 | 横向平铺细线 | 新增 |
| `load_title_font() -> FontFile` | 加载标题书法字体 | UITheme 内 + 外部探测 | 新增 |
| `load_body_font() -> FontFile` | 加载正文字体 | UITheme 内 + 外部探测 | 新增 |
| `apply_fonts() -> bool` | 字体落盘探测（启动日志） | 一次性探测 | 新增 |
| `_ensure_fonts()` | 内部缓存探针 | 避免对缺失文件重复 load 刷日志 | 新增 |
| `apply_title_font / apply_value_font / apply_body_font / apply_aux_font` | 字体 helper | 叠加字体 override（缺失时退回大小+颜色） | 增强；保持向后兼容 |
| `make_panel_stylebox(use_ink: bool = true) -> StyleBox` | 面板蒙皮（默认用暗纹） | 缺图时退回 StyleBoxFlat | 强化：返回 `StyleBox`（base class），新增 use_ink 形参 |
| `apply_panel_style(control: Control, use_ink: bool = true) -> void` | 应用面板蒙皮 | 兼容 design-strategist 的现有单参调用（默认 use_ink=true） | 强化：新增 use_ink 形参 |
| `make_divider_stylebox() -> StyleBox` | 暗金云纹细线 | 缺图退回 StyleBoxFlat 暗金线 | 强化：返回 `StyleBox`（base class） |
| `make_divider_control() -> Control` | 横向细分割线控件 | TextureRect(STRETCH_TILE) → 缺图退回 ColorRect | 强化 |

### 6.4 组件接入点（本轮改造）

| 组件 | 接入位置 | 改动 |
|---|---|---|
| `ui/action_button.gd` | `_icon = TextureRect.new() + UITheme.load_icon(action_id)` | ColorRect 占位 → 真图标（STRETCH_KEEP_ASPECT_CENTERED，图标缺失静默隐藏） |
| `ui/top_bar.gd` | `_make_slot(id)` 内资源图标 | ColorRect 占位 → TextureRect + `UITheme.load_icon(id)`；「推演时日」按钮 rili 图标本轮未接入（按钮 icon 尺寸约束，下一轮） |
| `ui/bottom_tab_bar.gd` | Tab 构建循环 | `btn.icon = UITheme.load_icon(id)` 暗金线稿 Tab 图标（水平 icon+text；垂直 icon-above-text 待 v2 polish） |
| `ui/collapsible_category.gd` | Header 右下挂 `_chevron` TextureRect | `UITheme.load_icon("折叠")`，`set_open` 旋转 0/180° 切换 |

> 概览面板（`ui/sect_home_page.gd`）的图标 slot 由 `design-strategist` 接入，本轮保留占位与改动接口，无需 art-director 改动。

---

## 七、约束与已决策项

### 7.1 红线自检

| 红线（V1.0 §3.3） | 本轮落地状态 |
|---|---|
| 装饰占比 ≤ 5% | ✅ 图标线稿 + 单面板暗纹占比均 < 5% |
| 严禁满铺花纹 | ✅ panel_ink.svg 暗纹为低 op 笔触 + 墨点，非满铺 |
| 严禁满屏炫光 | ✅ 无任何渐变 / 投影 / 粒子 |
| 严禁卡通 Q 版 | ✅ 全部修真器物线稿 |
| 严格 1px 暗金描边 | ⚠️ 自包含面板蒙皮的描边随 9-slice 缩放约 2–3px（手机端可读性优先）；可调用 `make_panel_stylebox(false)` 退回严格 1px StyleBoxFlat |
| 8px 栅格全部对齐 | ✅ 图标 viewBox 64 = 8×8；按钮 / Tab / 状态栏固定高度均 8 倍数 |

### 7.2 已记录的取舍（与 design-strategist 沟通对齐）

1. **面板描边** 由严格 1px → 蒙皮 2–3px（自适应手机端），代价"规范字面 vs 视觉一致性"，选择后者；提供 `use_ink=false` 回退。
2. **Tab 图标布局** 由规范"上下排布" → 实际"水平 icon-left + text"（v1 单行实现），v2 polish 改垂直排布（新增 VBox 子节点 + Label 重写 apply_tab_style）。
3. **「推演时日」按钮** rili 图标本轮未接入（Button.icon 尺寸约束），资产已就位（`ui/assets/icons/rili.svg`），v2 重构按钮 + icon_max_width 时接入。
4. **font title/body** 当前未落盘，UITheme 已预留路径与 fallback；落盘后零代码改动即可生效。

---

## 八、与 design-strategist / eng-lead 的衔接

| 协作点 | 当前状态 | 待对方配合 |
|---|---|---|
| 概览面板（OverviewPlaceholder）图标 slot | sect_home_page.gd 当前是 `PanelContainer + 占位 Label`；`apply_panel_style(overview)` 已自动叠加暗纹蒙皮 + 暗金描边 | design-strategist 填充内容时，若需插入图标（如月产出趋势箭头、状态标签"宗门安定"的小图标），请通过 `UITheme.load_icon(...)` 取图，自包含即可 |
| 御兽占位槽（BeastSlot） | 同样自动叠加暗纹蒙皮 | 同上 |
| 自包含面板蒙皮的描边粗细 2–3px | 由 art-director 决策（非严格 1px） | design-strategist 若要严格 1px → 调用 `UITheme.apply_panel_style(control, false)` 显式退化 StyleBoxFlat |
| 底部 Tab 图标垂直排布 | v1 实现为水平 icon-left | v2 polish 时由 design-strategist 在 Tab 内容布局层做 VBox 拆分，UITheme.apply_tab_style 不变 |
| `.uid` 自动管理 | 各 .gd / .tscn 由 Godot 编辑器自动维护 | eng-lead 接入 F5 时让编辑器首次扫描 UI 资产即可（Godot 4 自动生成 `.import` / `.uid`） |

---

## 九、后续待补（V1.1+）

1. **字体落盘**：将 `MaShanZheng-Regular.ttf` 与 `NotoSerifSC-Regular.otf` 放入 `ui/assets/fonts/`，F5 后 `UITheme.apply_fonts()` 自动切换（无需改组件代码）。
2. **Tab 图标垂直排布**：v2 polish 改 VBox 容器包裹 TextureRect + Label，apply_tab_style 增加 Label 版重载。
3. **推演时日按钮 rili 图标接入**：v2 用 `btn.icon_max_width/height` 限缩 icon 尺寸或重构为 HBox 包裹 TextRect + Label。
4. **遮罩 / 字幕用小号楷体**：未来弹窗、字幕层可补 `NotoSerifSC-Bold.otf` 作为强调权重（§5.1 未列）。

---

## 文档版本

- v1.0 · 2026-07-28 · 初版 · art-director · 与 S1 UI 重构第三条线落地配套
