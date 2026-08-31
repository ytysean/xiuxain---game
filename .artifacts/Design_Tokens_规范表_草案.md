# Design Tokens 规范表（S1 草案 · 待定稿）

> 对齐来源：Godot `ui_theme.gd`（Autoload: UITheme）全部常量 + `theme/main_theme.tres`（唯一 Theme 权威）。
> 本表为 Ardot 设计稿（00 设计系统屏 + 全 9 屏）的**唯一色彩/尺寸/字号/间距/图标基线权威**，取代当前 00 屏的"信息架构占位内容"。
> 所有色值以 `#RRGGBB` 给出（Ardot 设计稿用 0-1 浮点 / 16 进制均可，落地时换算）。

## 一、色板（Color）

| Token | Godot 常量 | Hex | 用途 |
| :--- | :--- | :--- | :--- |
| 底色 Base | `COLOR_BG_BASE` | `#1B272B` | 全局最底背景 |
| 面板底 Panel | `COLOR_PANEL_BG` | `#2C3E45` | 深青灰面板/卡片底（降饱和，非墨绿） |
| 状态栏/墨底 | `COLOR_STATUSBAR_BG` | `#0E1517` | 状态栏/底栏墨底 |
| 顶栏底 | `COLOR_TOPBAR_BG` | `#2C3E45`@0.85 | 顶部栏半透明深青底 |
| 描边金 Border | `COLOR_BORDER_GOLD` | `#C9A656` | 暗金描边（1~2px） |
| 文字金 Gold | `COLOR_TEXT_GOLD` | `#FFD77A` | 亮金核心数值 |
| 标题1 | `COLOR_TEXT_TITLE1` | `#E6C778` | 一级标题 |
| 标题2 | `COLOR_TEXT_TITLE2` | `#F0E6D2` | 二级标题/浅米 |
| 正文暗金 | `COLOR_TEXT_BODY_GOLD` | `#D4B86A` | 正文/数值/辅助统一色 |
| 正文弱化 | `COLOR_TEXT_BODY_DIM` | `#C8B896` | 弱化正文 |
| 禁用灰 | `COLOR_TEXT_DISABLED` | `#55554F` | 禁用态文字 |
| 成功/增益绿 | `COLOR_STATUS_SUCCESS` | `#7ED39A` | 增益/成功（进度条 fill 用此绿） |
| 警示红 | `COLOR_TEXT_RED` | `#E07878` | 负值/预警/危险 |
| 主按钮按下 | `COLOR_BTN_PRESSED` | `#141B1C` | 主按钮按下态底色 |
| 主按钮禁用 | `COLOR_BTN_DISABLED` | `#2E3232` | 禁用态底 |

## 二、圆角 / 描边（Radius & Border）

| Token | Godot 常量 | 值 | 用途 |
| :--- | :--- | :--- | :--- |
| 面板圆角 | `RADIUS_PANEL` | **8** | 常规面板/卡片 |
| 按钮圆角 | `RADIUS_BUTTON` | **6** | 主/次按钮（⚠️ S2 记账项：部分处写死 6 vs 规范 8，需统一） |
| 描边粗细 | `BORDER_W` | **1** | 全局描边基准（首页面板/动态面板用 2px 适配手机可读性） |
| 首页面板圆角 | `make_home_panel_stylebox` | 16（2px 描边） | 首页悬浮节点 |
| 动态面板圆角 | `make_dynamics_panel_stylebox` | 12（2px 描边） | 宗门动态面板 |

## 三、字号阶梯（Type Scale）

| Token | Godot 常量 | px | 用途 |
| :--- | :--- | :--- | :--- |
| Display 巨号 | `FONT_DISPLAY` | 40 | 大标题/ splash |
| H1 | `FONT_H1` | 32 | 一级标题 |
| Title 标题 | `FONT_TITLE` | 30 | 全局标题基准（apply_title_font 固定 30） |
| H2 | `FONT_H2` | 22 | 二级标题 |
| Value 数值 | `FONT_VALUE` | 18 | 战力/资源数值（apply_number_font） |
| Body 正文 | `FONT_BODY` | 18 | 正文 |
| Aux 辅助 | `FONT_AUX` | 14 | 辅助说明/小字 |

> ⚠️ **P1-D 待办**：`.gd` 中 112 处 `add_theme_font_size_override` + `ui_theme.gd` 越界常量（FONT_TITLE30/AUX14/DISPLAY40/H1-32）需在 Godot 冲刺独立轮次收敛，设计稿侧先按上表锁死。

## 四、间距栅格（Spacing · 8px Grid）

| Token | Godot 常量 | px | 用途 |
| :--- | :--- | :--- | :--- |
| Grid 基准 | `GRID` | 8 | 栅格基数 |
| Margin 外边距 | `MARGIN` | 16 | 容器外边距 |
| Panel 内边距 | `PAD_PANEL` | 16 | 面板内容边距 |
| 主按钮高 | `BTN_H_PRIMARY` | 64 | 主按钮高度 |
| 次按钮高 | `BTN_H_SECONDARY` | 48 | 次按钮高度 |
| Tab 高 | `TAB_H` | 60 | 底部 Tab 高度 |
| 顶栏高 | `TOPBAR_H` | 108 | 信息栏44 + 资源栏64 |

## 五、图标基线（Icon Baseline）

| 项 | 规范 |
| :--- | :--- |
| 风格 | **写实国漫油画风 PNG**（旧 SVG 线稿已废弃） |
| 目录 | `res://art/ui/buttons/`（扩展名 `.png`） |
| 命名 | 中文 label → stem 映射见 `ui_theme.gd::ICON_BY_LABEL` |
| 顶栏资源图标 | 灵石`res_lingshi` / 灵气`res_lingqi` / 灵植`res_lingzhi` / 声望`res_shengwang` |
| 底部导航 | 宗门/弟子/历练/纪事 各有 normal/selected 成对；殿阁用 `grid_jz` |
| 取图 | `UITheme.load_icon(label)` / `load_tab_icon(label, selected)` |
| 设计稿要求 | Ardot 图标占位须标注对应 stem 名（如「灵石→res_lingshi」），美术交付后直接替换，禁止设计稿自绘最终图标（美术资源由老大后续提供） |

## 六、待补到 00 设计系统屏的内容

1. 上述色板/圆角/字号/间距的**可视化色卡 + 标注**（替换当前 00 屏的信息架构占位）
2. 图标基线条例（风格/尺寸/命名规则）
3. 控件状态规范（normal/pressed/disabled/selected 的描边+底色对照）
4. 与 `main_theme.tres` 的**双向校验**：若 `.tres` 与 `ui_theme.gd` 常量有任何偏差，以 `ui_theme.gd` 为准并反向修正 `.tres`
