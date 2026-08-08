# .tscn Theme 偏离扫描报告

> 生成器：`tools/theme_deviation_scan.py`（只读扫描，**不修改任何文件**，可重跑防回归）  
> 分类原则（继承 P1-C 主理人裁定）：**按语义位置分类，不按 hex 一刀切**。  
> `functional` = 品阶/境界/描边/文字/功能底色 → 必须单源化；  
> `合法微色` = scrim / 遮罩 / 阴影 / 页面氛围暗底 → 保留硬编码 + 加注释，不收口。  
> 锁定 hex（如 `#2C5F52` 主按钮深青玉绿，终裁 §4.1）**只可单源化，绝不可改值**。

## 一、总览

| 项 | 值 |
|---|---|
| 扫描文件数 | 28 |
| 含散色文件数 | 5 |
| 散色总处数 | 18 |
| └ functional·必须单源化 | 12 |
| └ 待裁定 | 0 |
| └ 合法微色·保留+注释 | 0 |
| └ 合法微色·已标注 | 2 |
| └ 恒等无害·忽略 | 4 |
| Token 表色数（合法色源） | 42 |

## 二、按文件汇总

| 作用域 | 文件 | functional | 待裁定 | 合法微色 | 已标注 | 恒等 | 合计 |
|---|---|---:|---:|---:|---:|---:|---:|
| target | `ui/home_page.tscn` **←本轮目标** | 0 | 0 | 0 | 2 | 0 | 2 |
| generated | `art/auto_ui/scenes/disciple_portrait.tscn` | 1 | 0 | 0 | 0 | 3 | 4 |
| generated | `art/auto_ui/scenes/main_menu.tscn` | 8 | 0 | 0 | 0 | 1 | 9 |
| component | `components/toast_item.tscn` | 2 | 0 | 0 | 0 | 0 | 2 |
| root | `宗门首页.tscn` | 1 | 0 | 0 | 0 | 0 | 1 |

## 三、逐处明细

### `ui/home_page.tscn`  <sub>作用域 target</sub>

| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |
|---:|---|---|---|---|---:|---|---|---|
| 58 | `Overlay` | `color` | `Color(0.086, 0.133, 0.114, 0.5)` | `#16221D` 🔒 | 0.50 | **合法微色·已标注** | R0 已带放行标记（非功能色·局部微色·保留（页面氛围暗底 scrim #16221D@0.50，终裁 D 案，不收口）） | 保持现状 |
| 66 | `TopMask` | `color` | `Color(0.055, 0.082, 0.09, 0.45)` | `#0E1517` | 0.45 | **合法微色·已标注** | R0 已带放行标记（非功能色·局部微色·保留（顶部渐隐遮罩 mask @0.45，非 token 语义，不收口）） | 保持现状 |

### `art/auto_ui/scenes/disciple_portrait.tscn`  <sub>作用域 generated</sub>

| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |
|---:|---|---|---|---|---:|---|---|---|
| 18 | `BgColor` | `color` | `Color(0.02, 0.03, 0.03, 1.0)` | `#050808` | 1.00 | **functional·必须单源化** | R8 实心底板节点「BgColor」的 color（面板/栏底色，α=1.00 属半透底板非遮罩） | 新增/复用 Theme token 后收口 |
| 33 | `Bg` | `modulate` | `Color(1, 1, 1, 0.35)` | `#FFFFFF` | 0.35 | **恒等无害·忽略** | R1 白色 modulate（α=0.35）：仅作整体透明度控制，不含色值语义 | 无需处理 |
| 49 | `Portrait` | `modulate` | `Color(1, 1, 1, 1.0)` | `#FFFFFF` | 1.00 | **恒等无害·忽略** | R1 白色 modulate（α=1.00）：仅作整体透明度控制，不含色值语义 | 无需处理 |
| 65 | `AvatarFrame` | `modulate` | `Color(1, 1, 1, 1.0)` | `#FFFFFF` | 1.00 | **恒等无害·忽略** | R1 白色 modulate（α=1.00）：仅作整体透明度控制，不含色值语义 | 无需处理 |

### `art/auto_ui/scenes/main_menu.tscn`  <sub>作用域 generated</sub>

| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |
|---:|---|---|---|---|---:|---|---|---|
| 7 | `StyleBoxFlat#StyleBoxFlat_1` | `bg_color` | `Color(0.07, 0.12, 0.1, 0.96)` | `#121F1A` | 0.96 | **functional·必须单源化** | R6 功能属性 bg_color（描边/文字/StyleBox 功能底色）承载功能语义，未走 token | 新增/复用 Theme token 后收口 |
| 8 | `StyleBoxFlat#StyleBoxFlat_1` | `border_color` | `Color(0.78, 0.66, 0.42, 1.0)` | `#C7A86B` | 1.00 | **functional·必须单源化** | R5 与 token 近似漂移（UITheme.COLOR_HOME_DIVIDER、main_theme.tres[sb_home_panel].border_color = #C8A86A，本处 #C7A86B，Δ=0.0039） | 对齐到 UITheme.COLOR_HOME_DIVIDER（视觉差 <1.5%，可安全归一） |
| 48 | `BgColor` | `color` | `Color(0.06, 0.09, 0.08, 1.0)` | `#0F1714` | 1.00 | **functional·必须单源化** | R5 与 token 近似漂移（UITheme.COLOR_STATUSBAR_BG、main_theme.tres[sb_scroll].bg_color = #0E1517，本处 #0F1714，Δ=0.0118） | 对齐到 UITheme.COLOR_STATUSBAR_BG（视觉差 <1.5%，可安全归一） |
| 93 | `TitleLabel` | `theme_override_colors/font_color` | `Color(0.78, 0.66, 0.42, 1.0)` | `#C7A86B` | 1.00 | **functional·必须单源化** | R5 与 token 近似漂移（UITheme.COLOR_HOME_DIVIDER、main_theme.tres[sb_home_panel].border_color = #C8A86A，本处 #C7A86B，Δ=0.0039） | 对齐到 UITheme.COLOR_HOME_DIVIDER（视觉差 <1.5%，可安全归一） |
| 111 | `SloganLabel` | `theme_override_colors/font_color` | `Color(0.93, 0.9, 0.84, 1.0)` | `#EDE6D6` | 1.00 | **functional·必须单源化** | R6 功能属性 font_color（描边/文字/StyleBox 功能底色）承载功能语义，未走 token | 新增/复用 Theme token 后收口 |
| 127 | `EnterBtn` | `theme_override_colors/font_color` | `Color(1.0, 1.0, 1.0, 1.0)` | `#FFFFFF` | 1.00 | **functional·必须单源化** | R6 功能属性 font_color（描边/文字/StyleBox 功能底色）承载功能语义，未走 token | 新增/复用 Theme token 后收口 |
| 146 | `BtnContinue` | `theme_override_colors/font_color` | `Color(1.0, 1.0, 1.0, 1.0)` | `#FFFFFF` | 1.00 | **functional·必须单源化** | R6 功能属性 font_color（描边/文字/StyleBox 功能底色）承载功能语义，未走 token | 新增/复用 Theme token 后收口 |
| 167 | `FootnoteLabel` | `theme_override_colors/font_color` | `Color(0.93, 0.9, 0.84, 1.0)` | `#EDE6D6` | 1.00 | **functional·必须单源化** | R6 功能属性 font_color（描边/文字/StyleBox 功能底色）承载功能语义，未走 token | 新增/复用 Theme token 后收口 |
| 63 | `BgImage` | `modulate` | `Color(1, 1, 1, 0.55)` | `#FFFFFF` | 0.55 | **恒等无害·忽略** | R1 白色 modulate（α=0.55）：仅作整体透明度控制，不含色值语义 | 无需处理 |

### `components/toast_item.tscn`  <sub>作用域 component</sub>

| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |
|---:|---|---|---|---|---:|---|---|---|
| 4 | `StyleBoxFlat#sb_toast` | `bg_color` | `Color(0.1412, 0.2039, 0.2235, 0.88)` | `#243439` | 0.88 | **functional·必须单源化** | R4 与既有 token 同值（main_theme.tres[sb_btn_normal].bg_color、main_theme.tres[sb_btn_hover].bg_color、main_theme.tres[sb_panel].bg_color = #243439）→ 属冗余硬编码 | 收口：删 override 走全局 Theme / 由脚本引 main_theme.tres[sb_btn_normal].bg_color |
| 5 | `StyleBoxFlat#sb_toast` | `border_color` | `Color(0.7882, 0.6588, 0.3961, 1)` | `#C9A865` | 1.00 | **functional·必须单源化** | R4 与既有 token 同值（UITheme.COLOR_TAB_UNSELECTED、main_theme.tres[sb_btn_normal].border_color、main_theme.tres[sb_btn_disabled].border_color = #C9A865）→ 属冗余硬编码 | 收口：删 override 走全局 Theme / 由脚本引 UITheme.COLOR_TAB_UNSELECTED |

### `宗门首页.tscn`  <sub>作用域 root</sub>

| line | 节点 / 子资源 | 属性 | 色值 | #hex | α | 分类 | 判定理由 | 处置建议 |
|---:|---|---|---|---|---:|---|---|---|
| 26 | `状态栏背景` | `color` | `Color(0.05882353, 0.09411765, 0.08235294, 0.54901963)` | `#0F1815` | 0.55 | **functional·必须单源化** | R5 与 token 近似漂移（UITheme.COLOR_STATUSBAR_BG、main_theme.tres[sb_scroll].bg_color = #0E1517，本处 #0F1815，Δ=0.0118） | 对齐到 UITheme.COLOR_STATUSBAR_BG（视觉差 <1.5%，可安全归一） |

## 四、Token 表（当前合法色源）

| #hex | 来源（token / 全局 Theme 条目） |
|---|---|
| `#0E1517` | UITheme.COLOR_STATUSBAR_BG、main_theme.tres[sb_scroll].bg_color |
| `#121A24` | main_theme.tres[sb_top_bg].bg_color |
| `#141B1C` | UITheme.COLOR_BTN_PRESSED、main_theme.tres[sb_btn_pressed].bg_color |
| `#1A2633` | main_theme.tres[sb_fold].bg_color |
| `#1A2638` | main_theme.tres[sb_lv].bg_color |
| `#1B272B` | UITheme.COLOR_BG_BASE、main_theme.tres[sb_tab_unselected].bg_color |
| `#1E2B28` | UITheme.COLOR_HOME_BAR_BG、main_theme.tres[sb_home_panel].bg_color |
| `#1F2B3B` | main_theme.tres[sb_nav_btn].bg_color |
| `#243342` | main_theme.tres[sb_avatar].bg_color |
| `#243439` | main_theme.tres[sb_btn_normal].bg_color、main_theme.tres[sb_btn_hover].bg_color、main_theme.tres[sb_panel].bg_color、main_theme.tres[sb_tab_selected].bg_color |
| `#263647` | main_theme.tres[sb_res_bg].bg_color |
| `#2C3D43` | UITheme.COLOR_BG_CONTENT、main_theme.tres[sb_pbar_bg].bg_color |
| `#2C3E45` | UITheme.COLOR_PANEL_BG、UITheme.COLOR_TOPBAR_BG |
| `#2E3232` | UITheme.COLOR_BTN_DISABLED、main_theme.tres[sb_btn_disabled].bg_color |
| `#2E4052` | main_theme.tres[sb_nav_active].bg_color |
| `#3FA9C9` | UIThemeConfig.QUALITY_COLOR['ling'] |
| `#4CAF7A` | UIThemeConfig.REALM_COLOR['zhuji'] |
| `#55554F` | UITheme.COLOR_TEXT_DISABLED、UIThemeConfig.STATE_COLOR['disabled']、main_theme.tres[resource].Button/colors/font_disabled_color |
| `#5B8BD9` | UIThemeConfig.QUALITY_COLOR['bao']、UIThemeConfig.REALM_COLOR['jindan'] |
| `#7ED39A` | UITheme.COLOR_STATUS_SUCCESS、UIThemeConfig.STATE_COLOR['success']、main_theme.tres[sb_pbar_fill].bg_color |
| `#8A7E68` | UITheme.COLOR_TEXT_AUX、UIThemeConfig.STATE_COLOR['hint']、main_theme.tres[resource].TabBar/colors/font_color |
| `#947A47` | main_theme.tres[sb_fold].border_color |
| `#948052` | main_theme.tres[sb_res_bg].border_color |
| `#A68C52` | main_theme.tres[sb_nav_btn].border_color |
| `#B04CD9` | UIThemeConfig.QUALITY_COLOR['sheng']、UIThemeConfig.REALM_COLOR['huashen'] |
| `#C7A861` | main_theme.tres[sb_lv].border_color |
| `#C8A86A` | UITheme.COLOR_HOME_DIVIDER、main_theme.tres[sb_home_panel].border_color |
| `#C8B896` | UITheme.COLOR_TEXT_BODY_DIM、UIThemeConfig.REALM_COLOR['lianqi']、main_theme.tres[resource].TabBar/colors/font_hover_color |
| `#C9A656` | UITheme.COLOR_BORDER_GOLD |
| `#C9A865` | UITheme.COLOR_TAB_UNSELECTED、main_theme.tres[sb_btn_normal].border_color、main_theme.tres[sb_btn_disabled].border_color、main_theme.tres[sb_panel].border_color、main_theme.tres[sb_tab_selected].border_color、main_theme.tres[sb_grabber].bg_color |
| `#D4B86A` | UITheme.COLOR_TEXT_BODY_GOLD |
| `#D6D6D6` | UIThemeConfig.QUALITY_COLOR['fan'] |
| `#D9A04C` | UIThemeConfig.QUALITY_COLOR['wang']、UIThemeConfig.REALM_COLOR['yuanying'] |
| `#E07878` | UITheme.COLOR_TEXT_RED、UIThemeConfig.STATE_COLOR['danger']、UIThemeConfig.STATE_COLOR['warn'] |
| `#E0C26B` | main_theme.tres[sb_nav_active].border_color |
| `#E0D1A6` | main_theme.tres[sb_avatar].border_color |
| `#E0D5BE` | UITheme.COLOR_TEXT_BODY、main_theme.tres[resource].Button/colors/font_color、main_theme.tres[resource].Label/colors/font_color |
| `#E6C778` | UITheme.COLOR_TEXT_TITLE1、UIThemeConfig.STATE_COLOR['gold']、main_theme.tres[sb_btn_hover].border_color、main_theme.tres[sb_btn_pressed].border_color、main_theme.tres[sb_grabber_pressed].bg_color、main_theme.tres[resource].Button/colors/font_pressed_color、main_theme.tres[resource].TabBar/colors/font_selected_color |
| `#E8F0FF` | UIThemeConfig.QUALITY_COLOR['dao'] |
| `#F0E6B0` | UIThemeConfig.QUALITY_COLOR['xian'] |
| `#F0E6D2` 🔒 | UITheme.COLOR_TEXT_TITLE2、main_theme.tres[resource].Button/colors/font_hover_color |
| `#FFD77A` | UITheme.COLOR_TEXT_GOLD、main_theme.tres[sb_grabber_hover].bg_color |

## 五、无散色文件

共 23 个：`ui/bottom_tab_bar.tscn`、`ui/sect_home_page.tscn`、`ui/top_bar.tscn`、`components/BasePanel.tscn`、`components/ConfirmDialog.tscn`、`components/ItemSlot.tscn`、`components/ListItem.tscn`、`main.tscn`、`node_2d.tscn`、`ui/action_button.tscn`、`ui/collapsible_category.tscn`、`ui/core_action_grid.tscn`、`ui/game_ui.tscn`、`ui/page_battlepass.tscn`、`ui/page_building.tscn`、`ui/page_chronicle.tscn`、`ui/page_disciple.tscn`、`ui/page_explore.tscn`、`ui/page_quest.tscn`、`ui/page_shop.tscn`、`ui/page_storage.tscn`、`ui/page_xianyu.tscn`、`ui/sect_creation_page.tscn`
