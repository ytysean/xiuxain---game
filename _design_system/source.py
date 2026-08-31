# -*- coding: utf-8 -*-
"""
《太玄宗门录》设计系统 · 单一数据源 (Single Source of Truth)
================================================================
用途：
  - tokens      对齐 Godot `ui_theme.gd` (Autoload: UITheme) + `theme/main_theme.tres`
  - navigation  底部5Tab + 侧边7入口 + 山门定位决策（外部探索总入口）
  - resource     全局命名红线（废弃词 / 顶栏A方案）
本模块是 00 屏「真·Design Tokens」的代码化载体；Tokens 与导航逻辑
**合并在同一数据源**，由 `render_00_screen.py` 统一渲染输出，确保
数据整合与渲染流程统一处理，9 屏设计稿共享受同一权威。
"""

DESIGN_SYSTEM = {
    "meta": {
        "project": "太玄宗门录",
        "screen": "00 设计系统 · Design Tokens",
        "version": "v1.0",
        "alignment": "Godot ui_theme.gd (Autoload: UITheme) + theme/main_theme.tres",
        "note": ("取代原 00 屏的信息架构占位内容；所有 9 屏设计稿的"
                 "唯一色彩/尺寸/字号/间距/图标基线/导航权责权威。"),
    },

    # ============================================================
    # 一、Design Tokens（对齐 Godot 实际常量）
    # ============================================================
    "tokens": {
        "color": [
            {"token": "底色 Base",        "godot": "COLOR_BG_BASE",        "hex": "#1B272B", "use": "全局最底背景"},
            {"token": "面板底 Panel",     "godot": "COLOR_PANEL_BG",       "hex": "#2C3E45", "use": "深青灰面板/卡片底（降饱和，非墨绿）"},
            {"token": "状态栏/墨底",       "godot": "COLOR_STATUSBAR_BG",   "hex": "#0E1517", "use": "状态栏/底栏墨底"},
            {"token": "顶栏底",           "godot": "COLOR_TOPBAR_BG",      "hex": "#2C3E45@0.85", "use": "顶部栏半透明深青底"},
            {"token": "描边金 Border",     "godot": "COLOR_BORDER_GOLD",    "hex": "#C9A656", "use": "暗金描边（1~2px）"},
            {"token": "文字金 Gold",       "godot": "COLOR_TEXT_GOLD",      "hex": "#FFD77A", "use": "亮金核心数值"},
            {"token": "标题1",            "godot": "COLOR_TEXT_TITLE1",    "hex": "#E6C778", "use": "一级标题"},
            {"token": "标题2",            "godot": "COLOR_TEXT_TITLE2",    "hex": "#F0E6D2", "use": "二级标题/浅米"},
            {"token": "正文暗金",          "godot": "COLOR_TEXT_BODY_GOLD", "hex": "#D4B86A", "use": "正文/数值/辅助统一色"},
            {"token": "正文弱化",          "godot": "COLOR_TEXT_BODY_DIM",  "hex": "#C8B896", "use": "弱化正文"},
            {"token": "禁用灰",           "godot": "COLOR_TEXT_DISABLED",  "hex": "#55554F", "use": "禁用态文字"},
            {"token": "成功/增益绿",       "godot": "COLOR_STATUS_SUCCESS", "hex": "#7ED39A", "use": "增益/成功（进度条 fill 用此绿）"},
            {"token": "警示红",           "godot": "COLOR_TEXT_RED",       "hex": "#E07878", "use": "负值/预警/危险"},
            {"token": "主按钮按下",        "godot": "COLOR_BTN_PRESSED",    "hex": "#141B1C", "use": "主按钮按下态底色"},
            {"token": "主按钮禁用",        "godot": "COLOR_BTN_DISABLED",   "hex": "#2E3232", "use": "禁用态底"},
        ],
        "radius_border": [
            {"token": "面板圆角",   "godot": "RADIUS_PANEL",  "value": "8",  "use": "常规面板/卡片"},
            {"token": "按钮圆角",   "godot": "RADIUS_BUTTON", "value": "6",  "use": "主/次按钮（⚠️ S2 记账：部分处写死 6 vs 规范 8，需统一）"},
            {"token": "描边粗细",   "godot": "BORDER_W",      "value": "1",  "use": "全局描边基准（首页/动态面板用 2px 适配手机）"},
            {"token": "首页面板圆角", "godot": "make_home_panel_stylebox",      "value": "16(2px描边)", "use": "首页悬浮节点"},
            {"token": "动态面板圆角", "godot": "make_dynamics_panel_stylebox",  "value": "12(2px描边)", "use": "宗门动态面板"},
        ],
        "type_scale": [
            {"token": "Display 巨号", "godot": "FONT_DISPLAY", "px": 40, "use": "大标题/splash"},
            {"token": "H1",           "godot": "FONT_H1",      "px": 32, "use": "一级标题"},
            {"token": "Title 标题",   "godot": "FONT_TITLE",   "px": 30, "use": "全局标题基准（apply_title_font 固定 30）"},
            {"token": "H2",           "godot": "FONT_H2",      "px": 22, "use": "二级标题"},
            {"token": "Value 数值",   "godot": "FONT_VALUE",   "px": 18, "use": "战力/资源数值（apply_number_font）"},
            {"token": "Body 正文",    "godot": "FONT_BODY",    "px": 18, "use": "正文"},
            {"token": "Aux 辅助",     "godot": "FONT_AUX",     "px": 14, "use": "辅助说明/小字"},
        ],
        "spacing": [
            {"token": "栅格基准",   "godot": "GRID",          "px": 8,  "use": "栅格基数"},
            {"token": "外边距",     "godot": "MARGIN",        "px": 16, "use": "容器外边距"},
            {"token": "面板内边距", "godot": "PAD_PANEL",     "px": 16, "use": "面板内容边距"},
            {"token": "主按钮高",   "godot": "BTN_H_PRIMARY", "px": 64, "use": "主按钮高度"},
            {"token": "次按钮高",   "godot": "BTN_H_SECONDARY", "px": 48, "use": "次按钮高度"},
            {"token": "Tab 高",     "godot": "TAB_H",         "px": 60, "use": "底部 Tab 高度"},
            {"token": "顶栏高",     "godot": "TOPBAR_H",      "px": 108, "use": "信息栏44 + 资源栏64"},
        ],
        "icon_baseline": {
            "style": "写实国漫油画风 PNG（旧 SVG 线稿已废弃）",
            "dir": "res://art/ui/buttons/（扩展名 .png）",
            "naming": "中文 label → stem 映射见 ui_theme.gd::ICON_BY_LABEL",
            "topbar_icons": {
                "灵石": "res_lingshi", "灵气": "res_lingqi",
                "灵植": "res_lingzhi", "声望": "res_shengwang",
            },
            "bottom_nav": "宗门/弟子/历练/纪事 各有 normal/selected 成对；殿阁用 grid_jz",
            "loader": "UITheme.load_icon(label) / load_tab_icon(label, selected)",
            "design_rule": ("Ardot 图标占位须标注对应 stem 名（如「灵石→res_lingshi」），"
                            "美术交付后直接替换，禁止设计稿自绘最终图标（美术资源由老大后续提供）"),
        },
    },

    # ============================================================
    # 二、导航架构（Navigation）— 与 Tokens 同模块整合
    # ============================================================
    "navigation": {
        "principle": ("底部5Tab = 全局功能分类导航（管理向、列表式）；"
                      "侧边快捷栏 = 高频/沉浸功能入口（场景化）。"
                      "权责分离，不重叠，玩家认知成本最低。"),
        "bottom_tabs": [
            {"name": "宗门", "role": "内部经营主城", "scope": "宗门主城经营页（山门之外的一切内部经营）"},
            {"name": "弟子", "role": "弟子管理",     "scope": "弟子招募/培养/属性"},
            {"name": "殿阁", "role": "建筑经营",     "scope": "殿阁建设与功能"},
            {"name": "历练", "role": "快捷管理页",   "scope": "底部历练Tab=领奖/次数/扫荡（与山门沉浸探索互补不重叠）"},
            {"name": "纪事", "role": "任务+日志+成就","scope": "完整任务+日志+成就体系（与侧边「宗门令」打通）"},
        ],
        "side_entries": [
            {"name": "山门",   "role": "外部探索总入口", "scope": "宗门内外总出入口 → 世界探索/大地图"},
            {"name": "飞书",   "role": "传讯",           "scope": "原邮件（传音符/飞书传讯）"},
            {"name": "仙迹",   "role": "道途里程碑",     "scope": "原成就"},
            {"name": "规制",   "role": "宗门规矩设置",   "scope": "原设置"},
            {"name": "榜单",   "role": "排行榜",         "scope": "天榜（保留）"},
            {"name": "宗门令", "role": "宗门指令任务",   "scope": "原任务（与纪事Tab内部打通）"},
            {"name": "坊市", "role": "珍宝鉴藏",       "scope": "全剧统一命名（与06屏坊市一致，禁用藏宝阁/鉴宝/珍宝阁异名）"},
        ],
        # 山门定位决策（升级A方案，2026-08-09 拍板）
        "shanmen": {
            "decision": ("宗门内外总出入口（升级A方案）：底部「宗门」Tab 管内部经营，"
                         "侧边「山门」管外部探索，权责完全分离，不重叠。"),
            "phase_s1": ("S1：点击山门 → 「外出探索」子页，收口历练（底部历练Tab沉浸入口）+ "
                         "秘境探索 + 预留凡间城镇/据点占位；"),
            "phase_map": ("大地图上线后：山门 → 世界大地图切换枢纽（历练点位 / 秘境洞府 / "
                          "凡间城镇 / 敌对势力 / 己方分据点），成为宗门主城↔大世界唯一切换点。"),
            "reject_b": "B方案（回城/刷新）冗余：底部第一个Tab即宗门主城，无需重复入口。",
            "reject_c": ("C方案（场景热区总入口）层级错位：场景热区载体应是背景画面本身"
                         "（点主殿进殿阁/点丹房进炼丹），侧边栏是全局快捷入口，不应混用。"),
            "visual_hint": "视觉稿可给山门按钮加轻微「向外延伸」暗示，强化出门探索语义。",
            "combat_rule": ("所有历练/秘境均为放置/管理向地图点位选择，不涉及即时战斗操作，"
                            "符合 S1 零战斗触碰铁律。"),
            "landing": ("P0 结构稿不动山门文本/位置；P1 交互标注统一写"
                        "「点击进入世界探索界面，S1开放历练/秘境，后续迭代大地图」，工程侧预留路由扩展。"),
        },
    },

    # ============================================================
    # 三、资源命名红线（Resource Naming）
    # ============================================================
    "resource": {
        "approved": ["仙玉", "香火", "灵石", "灵气", "灵植", "声望", "灵晶"],
        "banned": ["玄玉", "绑定仙玉", "非绑定仙玉"],
        "topbar_a": ["灵石", "灵气", "灵植", "声望"],
        "rule": ("玄玉彻底废弃并入仙玉；仙玉为唯一单轨氪金货币（可充值可游戏内产出）；"
                 "灵晶=独立稀有材料（非货币，归材料背包）；香火=宗门运营货币。"),
        "note": "所有UI文案/图标标注/界面标题统一使用 approved 名称，禁止出现 banned 表述。",
    },
}
