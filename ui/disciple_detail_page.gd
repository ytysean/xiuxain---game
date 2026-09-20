extends Control

# 弟子详情页（二级页）v1 · 立绘主导型（2026-08-23）
# 设计规格：立绘占上半屏作为绝对视觉主体（★2026-09-14：占比 0.55 → 0.45，给下半屏信息让位、少翻页），
#           下半屏依次为战力大字、四维属性条(攻防血速)、命格/性格/道途三栏、装备栏+灵兽位。
# 立绘cover：手动计算 scale=max(hero宽/tex宽, hero高/tex高)；★高于取景框时**顶部对齐**保住脸，矮图居中对齐。

signal 返回列表
signal 装备查看请求(弟子ID: int)
signal 仙衣阁请求

const _HERO_RATIO: float = 0.45

# 资质拼音→中文映射（对齐 disciple.gd 资质显示）
const _资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}
# 命格查表（destiny_id → 中文名称）
const DestinyLoader := preload("res://DestinyDataLoader.gd")
# ★ 2026-09-15：命魂灯位图（soul_lamp_*.png）退役——
#   源图为「象牙白灯身 + 近白径向渐变底」，且全图 alpha=255（四角不透明）⇒ 在深色面板上
#   渲染成一块白砖（实机「一片白」）；实测该底无法用区域生长抠除（灯身与底色同亮度，抠底会把灯身一起吃掉），
#   属源图缺陷、非工程可修。故本页改用**主题内矢量命牌**（金描边牌位 + 「生／殁」镌字），
#   与全项目图标同一套 token，任意尺寸不糊。位图保留未删（外观皮肤体系引用）。
const 命牌_生: String = "生"
const 命牌_殁: String = "殁"

var _built: bool = false
var _hero_area: Control = null
var _content_area: Control = null
var _portrait: TextureRect = null
var _back_btn: Button = null
var _skin_btn: Button = null
var _six_labels: Dictionary = {}
var _radar: Control = null
var _power_bars: Dictionary = {}
var _breakthrough_label: Label = null
var _breakthrough_bar: ColorRect = null
var _breakthrough_pct: Label = null
var _status_label: Label = null
var _status_timer: Label = null
var _status_icon: Control = null           # 命牌牌位（矢量：金描边 + 「生／殁」镌字；2026-09-15 替退位图命魂灯）
var _status_glyph: Label = null            # 牌位内的镌字
# 灵兽页
var _beast_name: Label = null
var _beast_info: Label = null
var _beast_power: Label = null
var _beast_loyalty_bar: ColorRect = null
var _beast_loyalty_text: Label = null
var _beast_level_bar: ColorRect = null
var _beast_level_text: Label = null
var _beast_skill_grid: GridContainer = null
var _beast_avatar: TextureRect = null
# 履历页
var _record_info_grid: GridContainer = null
var _record_goal_vbox: VBoxContainer = null
var _record_storage_vbox: VBoxContainer = null
var _查抄待确认: bool = false   # 查抄二次点击确认态（切换弟子时重置，防误点撕破脸）
var _record_social_grid: GridContainer = null
var _record_bond_list: VBoxContainer = null
var _record_psyche_vbox: VBoxContainer = null
var _record_interaction_vbox: VBoxContainer = null
var _shoutu_panel: VBoxContainer = null   # S29 收徒候选面板（默认隐藏）
var _record_title_text: Label = null
var _record_title_desc: Label = null
var _record_title_list: VBoxContainer = null
var _record_achievement_grid: GridContainer = null
var _record_timeline: VBoxContainer = null
var _info_name: Label = null
var _info_realm: Label = null
var _info_identity: Label = null
var _info_quality: Label = null
var _info_constitution: Label = null   # 特殊体质标签
var _info_advanced: Label = null   # 高阶修士标签（神魂/法相/领域）
var _power_label: Label = null
var _power_summary: Label = null
var _power_name: Label = null
var _power_realm: Label = null
var _attr_bars: Dictionary = {}   # "攻" -> ProgressBar
var _destiny_label: VBoxContainer = null
var _personality_label: VBoxContainer = null
var _daotu_label: VBoxContainer = null
var _hudong_buttons: Dictionary = {}  # 互动类型 -> Button
var _xinjing_label: VBoxContainer = null
var _daoxin_label: VBoxContainer = null
var _xinmo_label: VBoxContainer = null
var _护道人_label: Label = null  # P0新增：护道人信息展示
var _忠诚_label: VBoxContainer = null
var _欠俸_label: VBoxContainer = null
var _oath_box: VBoxContainer = null       # S36 心魔誓区（详情页·**只读**：只显示有无誓约/哪种誓在效）
var _oath_title: Label = null             # 心魔誓 组标题
# ★ 2026-09-14 详情页改版新增
var _portrait_view_btn: Button = null     # 立绘「看全图」按钮（★2026-09-15 移至右上角立绘工具带）
var _hero_tools: HBoxContainer = null     # 立绘右上工具带（看全图 · 换装 · 帮助「?」同行）
var _fullview_layer: Control = null       # 立绘全图浮层（懒创建，关闭即销毁）
var _hudong_head: HBoxContainer = null    # 互动培养 组标题行（标题 + 红点）
var _hudong_title: Label = null
var _hudong_dot: Panel = null             # 互动培养 红点（有可办之事才亮；静态隐藏）
var _hudong_panel: PanelContainer = null
var _hudong_tip: Label = null
var _shoutu_btn: Button = null            # 「拜师」（原按钮名「收徒」名实不符，已正名）
var _zhushi_btn: Button = null            # 「逐师」
var _驱逐_btn: Button = null              # 「驱逐师门」（二次点击确认）
var _驱逐待确认: bool = false
var _status_desc: Label = null            # 当前状态 说明行
var _gongfa_list_label: Label = null
var _danyao_list_label: Label = null
var _danyao_tip: Label = null             # 丹药 说明行（随身／私藏口径）
var _lingquan_label: Label = null         # 洗池·灵泉状态行（十二载一开，开则三十日）
var _驱逐_hint: Label = null              # 驱逐条件说明行（平时不可用的缘由）
var _equip_box: HBoxContainer = null
# 魔兽世界风格纸娃娃系统（9槽位）
var _paper_doll_area: Control = null
var _paper_doll_portrait: TextureRect = null
var _equip_slots: Dictionary = {}  # 槽位key -> Button
var _equip_detail_panel: PanelContainer = null
var _护身符_panel: PanelContainer = null
var _休闲设置_panel: PanelContainer = null
var _护身符_parent: Node = null
var _equip_detail_name: Label = null
var _equip_detail_power: Label = null
var _equip_set_panel: VBoxContainer = null
var _equip_detail_desc: Label = null
var _equip_detail_affixes: VBoxContainer = null
var _btn_unequip: Button = null
var _btn_auto_equip: Button = null
var _power_total: Label = null
var _power_bonus: Label = null
var _power_count: Label = null
var _selected_equip_slot: String = ""
var _current_disciple: Object = null
var _tab_buttons: Dictionary = {}
var _tab_pages: Dictionary = {}

# 9个装备槽位定义（v16：立绘居中+左右两列等距整齐排列，统一76px）
# col: left/right/top/bottom; row: 垂直排列序号
const EQUIP_SLOTS: Array = [
	{"key": "toukui", "name": "道冠", "col": "top", "row": 0, "icon": "道冠"},
	{"key": "peishi", "name": "灵饰", "col": "top", "row": 1, "icon": "灵饰"},
	{"key": "huzhi", "name": "灵腕", "col": "left", "row": 0, "icon": "灵腕"},
	{"key": "yipao", "name": "法袍", "col": "left", "row": 1, "icon": "法袍"},
	{"key": "changku", "name": "灵裤", "col": "left", "row": 2, "icon": "灵裤"},
	{"key": "wuqi", "name": "法兵", "col": "right", "row": 0, "icon": "法兵"},
	{"key": "yaodai", "name": "束灵带", "col": "right", "row": 1, "icon": "束灵"},
	{"key": "本命法宝", "name": "本命法宝", "col": "right", "row": 2, "icon": "法宝"},
	{"key": "xuezi", "name": "云靴", "col": "bottom", "row": 0, "icon": "云靴"},
]


func _ready() -> void:
	# 修改父容器 offset_top=0（与宗主详情页一致）
	var parent: Node = get_parent()
	if parent != null and parent is Control:
		(parent as Control).offset_top = 0.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	call_deferred("_apply_final_layout")


func _apply_final_layout() -> void:
	var parent: Node = get_parent()
	if parent != null and parent is Control:
		(parent as Control).offset_top = 0.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var page_size: Vector2 = get_size()
	var hero_h: float = page_size.y * _HERO_RATIO
	# Hero 区域
	if _hero_area != null:
		_hero_area.anchor_left = 0.0
		_hero_area.anchor_top = 0.0
		_hero_area.anchor_right = 1.0
		_hero_area.anchor_bottom = 0.0
		_hero_area.offset_left = 0.0
		_hero_area.offset_top = 0.0
		_hero_area.offset_right = 0.0
		_hero_area.offset_bottom = hero_h
		_hero_area.clip_contents = true
	# Content 区域（底部留给Tab栏）
	if _content_area != null:
		_content_area.anchor_left = 0.0
		_content_area.anchor_top = 0.0
		_content_area.anchor_right = 1.0
		_content_area.anchor_bottom = 1.0
		_content_area.offset_left = 0.0
		_content_area.offset_top = hero_h
		_content_area.offset_right = 0.0
		_content_area.offset_bottom = -100.0
	# 立绘 cover
	_apply_portrait_cover()


func _apply_portrait_cover() -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_portrait) or not is_instance_valid(_hero_area):
		return
	var tex: Texture2D = _portrait.texture
	if tex == null:
		return
	var hero_size: Vector2 = _hero_area.get_size()
	if hero_size.x <= 0 or hero_size.y <= 0:
		# hero_area 还没 layout 完成，deferred 到下一帧重试
		var retry_call: Callable = func() -> void:
			if is_instance_valid(self) and self.is_inside_tree():
				_apply_portrait_cover()
		retry_call.call_deferred()
		return
	var tex_w: float = tex.get_width()
	var tex_h: float = tex.get_height()
	if tex_w <= 0 or tex_h <= 0:
		return
	# 手动 cover：scale = max(hero宽/tex宽, hero高/tex高)
	var scale: float = max(hero_size.x / tex_w, hero_size.y / tex_h)
	var draw_w: float = tex_w * scale
	var draw_h: float = tex_h * scale
	var pos_x: float = (hero_size.x - draw_w) / 2.0
	# ★ 2026-09-14 修：立绘高于取景框时**顶部对齐**（优先保住脸），不再垂直居中。
	#   全身立绘 1024×2048、取景框约 1080×864 ⇒ 居中会把「发顶到下巴」整段裁掉，
	#   玩家只看到躯干与双手（旧反馈「立绘不完整，看不到脸」）。矮图（半身/横图）仍居中。
	var pos_y: float = 0.0
	if draw_h <= hero_size.y:
		pos_y = (hero_size.y - draw_h) / 2.0
	_portrait.anchor_left = 0.0
	_portrait.anchor_top = 0.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_bottom = 0.0
	_portrait.offset_left = pos_x
	_portrait.offset_top = pos_y
	_portrait.offset_right = pos_x + draw_w
	_portrait.offset_bottom = pos_y + draw_h


func _build() -> void:
	if _built:
		return
	_built = true

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.086, 0.125, 0.141, 1.00)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Hero 区域
	_hero_area = Control.new()
	_hero_area.name = "HeroArea"
	_hero_area.clip_contents = true
	add_child(_hero_area)

	# 立绘：anchor 全 0 绝对定位 + STRETCH_SCALE，由 _apply_portrait_cover() 算绝对像素 offset
	# 这样覆盖整个 hero_area 的"max scale + 居中"，手动 cover 公式跨 4.7 全版本稳定
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.anchor_left = 0.0
	_portrait.anchor_top = 0.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_bottom = 0.0
	_portrait.offset_left = 0.0
	_portrait.offset_top = 0.0
	_portrait.offset_right = 0.0
	_portrait.offset_bottom = 0.0
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_hero_area.add_child(_portrait)

	# 信息条（已移至战力行，隐藏）
	var info_bar := VBoxContainer.new()
	info_bar.name = "InfoBar"
	info_bar.visible = false
	info_bar.anchor_left = 0.0
	info_bar.anchor_top = 1.0
	info_bar.anchor_right = 1.0
	info_bar.anchor_bottom = 1.0
	info_bar.offset_left = float(int(round(16 * UITheme.UI_SCALE)))
	info_bar.offset_top = -float(int(round(90 * UITheme.UI_SCALE)))
	info_bar.offset_right = -float(int(round(16 * UITheme.UI_SCALE)))
	info_bar.offset_bottom = -float(int(round(10 * UITheme.UI_SCALE)))
	info_bar.add_theme_constant_override("separation", 4)
	info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_area.add_child(info_bar)

	_info_name = Label.new()
	_info_name.text = "—"
	_info_name.add_theme_color_override("font_color", Color(0.91, 0.86, 0.78))
	UITheme.apply_project_font(_info_name, int(round(28 * UITheme.UI_SCALE)), false)
	_info_name.add_theme_constant_override("shadow_offset_x", 2)
	_info_name.add_theme_constant_override("shadow_offset_y", 2)
	_info_name.add_theme_color_override("shadow_color", Color(0, 0, 0, 0.8))
	info_bar.add_child(_info_name)

	var tags_hb := HBoxContainer.new()
	tags_hb.add_theme_constant_override("separation", 6)
	info_bar.add_child(tags_hb)

	_info_realm = _make_tag("—", Color(0.83, 0.69, 0.21), Color(0.83, 0.69, 0.21, 0.2))
	tags_hb.add_child(_info_realm)

	_info_identity = _make_tag("—", Color(0.36, 0.67, 0.89), Color(0.36, 0.67, 0.89, 0.2))
	tags_hb.add_child(_info_identity)

	_info_quality = _make_tag("—", Color(0.61, 0.35, 0.71), Color(0.61, 0.35, 0.71, 0.2))
	tags_hb.add_child(_info_quality)

	_info_constitution = _make_tag("—", Color(0.85, 0.45, 0.30), Color(0.85, 0.45, 0.30, 0.2))
	tags_hb.add_child(_info_constitution)

	_info_advanced = _make_tag("—", Color(0.70, 0.50, 0.90), Color(0.70, 0.50, 0.90, 0.2))
	tags_hb.add_child(_info_advanced)

	# 返回按钮
	_back_btn = Button.new()
	_back_btn.name = "BackBtn"
	_back_btn.text = "←"
	_back_btn.anchor_left = 0.0
	_back_btn.anchor_top = 0.0
	_back_btn.anchor_right = 0.0
	_back_btn.anchor_bottom = 0.0
	_back_btn.offset_left = float(int(round(12 * UITheme.UI_SCALE)))
	_back_btn.offset_top = float(int(round(12 * UITheme.UI_SCALE)))
	_back_btn.offset_right = float(int(round(48 * UITheme.UI_SCALE)))
	_back_btn.offset_bottom = float(int(round(48 * UITheme.UI_SCALE)))
	_back_btn.z_index = 200   # 置顶：须在所有 Tab 常显，且不被 PageScroll 内容盖住（见 _on_tab_pressed）
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

	# ── 立绘右上工具带（2026-09-15 重构）──
	# 旧版两颗钮各用「anchor 右上 + 固定 offset」摆放：换装 60×36 UI（135×81 物理）恰好盖住
	# 帮助「?」（-72 与 -60 两个 offset 区间互相重叠）⇒ 「?」长期不可点，且两框远大于字面。
	# 现改为一条右对齐工具带，三颗钮**按内容自适应**（无 custom_minimum_size，仅靠 token 内边距），
	# 对齐反馈「框体跟文字大小差不多」；纵向 SHRINK_CENTER ⇒ 不被行高拉高。
	_hero_tools = HBoxContainer.new()
	_hero_tools.name = "HeroTools"
	_hero_tools.anchor_left = 1.0
	_hero_tools.anchor_top = 0.0
	_hero_tools.anchor_right = 1.0
	_hero_tools.anchor_bottom = 0.0
	_hero_tools.offset_left = -float(int(round(400 * UITheme.UI_SCALE)))
	_hero_tools.offset_top = float(int(round(10 * UITheme.UI_SCALE)))
	_hero_tools.offset_right = -float(int(round(10 * UITheme.UI_SCALE)))
	_hero_tools.offset_bottom = _hero_tools.offset_top + float(UITheme.SIZE_SM)
	_hero_tools.alignment = BoxContainer.ALIGNMENT_END
	_hero_tools.add_theme_constant_override("separation", UITheme.GRID_SM)
	_hero_tools.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 空白处不吃立绘点击
	add_child(_hero_tools)

	# 看全图（原为立绘右下角的大框钮，2026-09-15 迁至右上工具带、与「换装」同款）
	_portrait_view_btn = Button.new()
	_portrait_view_btn.name = "PortraitViewBtn"
	_portrait_view_btn.text = "看全图"
	_apply_hero_tool_style(_portrait_view_btn)
	_portrait_view_btn.pressed.connect(_on_portrait_view_pressed)
	_hero_tools.add_child(_portrait_view_btn)

	# 换装按钮（仙衣阁入口）
	_skin_btn = Button.new()
	_skin_btn.name = "SkinBtn"
	_skin_btn.text = "换装"
	_apply_hero_tool_style(_skin_btn)
	_skin_btn.pressed.connect(_on_skin_pressed)
	_hero_tools.add_child(_skin_btn)

	# 帮助栏「?」：本页系统简介（复用 UITheme 统一「?」钮，自带内边距）
	var _详情帮助 := UITheme.make_help_button("弟子详情", "查看宗门弟子全貌：四维与六维资质、命格性格道途、心境道心心魔、道行构成与装备灵兽。\n轻触带 ⓘ 的卡片与属性条，可查看该项详细说明。")
	_详情帮助.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hero_tools.add_child(_详情帮助)

	# Content 区域（页面滚动区，底部留给Tab栏）
	_content_area = Control.new()
	_content_area.name = "ContentArea"
	_content_area.anchor_left = 0.0
	_content_area.anchor_top = 0.0
	_content_area.anchor_right = 1.0
	_content_area.anchor_bottom = 1.0
	_content_area.offset_left = 0.0
	_content_area.offset_right = 0.0
	_content_area.offset_bottom = -100.0  # 底部Tab栏高度
	_content_area.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_content_area)

	# 页面容器（ScrollContainer）
	var page_scroll := ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_area.add_child(page_scroll)

	_tab_buttons = {}
	_tab_pages = {}

	# ── 详情Tab ──
	var detail_vb := VBoxContainer.new()
	detail_vb.name = "DetailPage"
	detail_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vb.add_theme_constant_override("separation", 6)
	page_scroll.add_child(detail_vb)
	_tab_pages["详情"] = detail_vb

	# ══════════════════════════════════════════════════════════════════════
	# 详情 Tab 版面（2026-09-14 按「实用性优先度」整体重排）
	#   ① 名字·战力 → ② 突破进度 → ③ 当前状态 → ④ 互动培养（条件触发）
	#   → ⑤ 六维属性（图大文字小）→ ⑥ 战力构成 → ⑦ 命格·性格·道途
	#   → ⑧ 心境·道心·心魔 → ⑨ 心魔誓（只读）→ ⑩ 护道人·牵绊
	#   → ⑪ 已学功法 → ⑫ 丹药 → ⑬ 洗池·洗髓 → ⑭ 底部：驱逐师门
	#   · 拆掉「命格·性格·道途」「心境·道心·心魔」两处冗余组标题（三张卡自带卡名）。
	#   · 心魔誓改**只读**：立誓由弟子依行为/经历主动请誓（Game.誓约待批），玩家只在首页传讯栏批复。
	#   · 已学功法/丹药去按钮（自动流转：师徒授功 / 私库自动服用丹药）；仅洗池·洗髓留手动付费入口。
	#   · 字号统一：正文 FONT_BODY(27) / 关键数 FONT_H2(33) / 辅助 FONT_AUX(21)；
	#     旧版此处拿 FONT_H1(48)、FONT_TITLE(45) 当正文，才显得「比别处大一号」。
	#   · 底部原「调遣/任命司职」「修炼/闭关提升」两钮**未接任何回调**（死按钮），已移除；
	#     任命入口统一在「殿阁 · 任免主事」，弟子修炼为自动流转，详情页不重复设入口。
	# ══════════════════════════════════════════════════════════════════════

	# ── 立绘「看全图」按钮已在 Hero 右上工具带创建（见 _hero_tools）──
	#   2026-09-15：原「Hero 右下角 134×54UI 大框」既突兀又压立绘，且 ⤢ 字形在项目字体里缺字，
	#   实机渲染成一个方框（反馈「框太突兀」）。现统一收进右上工具带，与换装同款紧贴字面。

	# ── ① 名字 + 战力 ──
	var power_box := HBoxContainer.new()
	power_box.alignment = BoxContainer.ALIGNMENT_CENTER
	power_box.add_theme_constant_override("separation", 24)
	# 左：名字 + 身份行 + 摘要
	var name_vb := VBoxContainer.new()
	name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_vb.add_child(name_row)
	var name_ico := Label.new()
	name_ico.text = "◆"
	name_ico.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	# 名字 FONT_DISPLAY(60) → FONT_H1(48)：本页主角是「信息」不是「名号」，
	# 60px 会白吃一整行首屏，且与正文落差过大。
	UITheme.apply_project_font(name_ico, UITheme.FONT_H1, true)
	name_row.add_child(name_ico)
	_power_name = Label.new()
	_power_name.text = "—"
	_power_name.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	UITheme.apply_project_font(_power_name, UITheme.FONT_H1, true)
	name_row.add_child(_power_name)
	_power_realm = Label.new()
	_power_realm.text = ""
	_power_realm.add_theme_color_override("font_color", Color(0.35, 0.68, 0.62))
	# 本行承载「境界 · 身份 · 资质 · 年龄」长串（实测 ~19 字），允许换行 ⇒ 最小宽归零，整行恒不溢出。
	_power_realm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(_power_realm, UITheme.FONT_H2, true)
	name_vb.add_child(_power_realm)
	_power_summary = Label.new()
	_power_summary.text = ""
	_power_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_power_summary.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	_power_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(_power_summary, UITheme.FONT_AUX, true)
	name_vb.add_child(_power_summary)
	power_box.add_child(name_vb)
	# 右：战力
	var power_right := VBoxContainer.new()
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_END
	prow.add_theme_constant_override("separation", 6)
	power_right.add_child(prow)
	var sword := Label.new()
	sword.text = "◆"
	sword.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	UITheme.apply_project_font(sword, UITheme.FONT_H1, true)
	prow.add_child(sword)
	_power_label = Label.new()
	_power_label.text = "—"
	_power_label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	UITheme.apply_project_font(_power_label, UITheme.FONT_H1, true)
	prow.add_child(_power_label)
	power_box.add_child(power_right)
	detail_vb.add_child(power_box)

	# ── ② 突破进度（弟子此刻「修到哪了」＝最常看）──
	detail_vb.add_child(_make_section_title("突破进度"))
	var break_panel: PanelContainer = _make_panel()
	break_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	break_panel.gui_input.connect(_on_breakthrough_clicked)
	detail_vb.add_child(break_panel)
	var break_vb := VBoxContainer.new()
	break_vb.add_theme_constant_override("separation", 6)
	break_panel.add_child(break_vb)
	var break_row := HBoxContainer.new()
	_breakthrough_label = Label.new()
	_breakthrough_label.text = "练气·一层"
	_breakthrough_label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	# 原 FONT_H1(48) 当正文 ⇒ 与别处正文明显不齐；降 FONT_H2(33)。
	UITheme.apply_project_font(_breakthrough_label, UITheme.FONT_H2, true)
	_breakthrough_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_row.add_child(_breakthrough_label)
	var next_label := Label.new()
	next_label.text = "自动突破中"
	next_label.add_theme_color_override("font_color", Color(0.35, 0.80, 0.50))
	UITheme.apply_project_font(next_label, UITheme.FONT_AUX, true)
	break_row.add_child(next_label)
	break_vb.add_child(break_row)
	var prog_bg := ColorRect.new()
	prog_bg.color = Color(1, 1, 1, 0.08)
	prog_bg.custom_minimum_size = Vector2(0, UITheme.SIZE_SM / 5)
	prog_bg.clip_contents = true
	break_vb.add_child(prog_bg)
	_breakthrough_bar = ColorRect.new()
	_breakthrough_bar.color = Color(0.95, 0.80, 0.30)
	_breakthrough_bar.anchor_left = 0; _breakthrough_bar.anchor_top = 0
	_breakthrough_bar.anchor_right = 0; _breakthrough_bar.anchor_bottom = 1
	prog_bg.add_child(_breakthrough_bar)
	_breakthrough_pct = Label.new()
	_breakthrough_pct.text = "0%"
	_breakthrough_pct.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	UITheme.apply_project_font(_breakthrough_pct, UITheme.FONT_AUX, true)
	break_vb.add_child(_breakthrough_pct)

	# ── ③ 当前状态（在宗/历练/失踪，一眼看清人在哪）──
	detail_vb.add_child(_make_section_title("当前状态"))
	var status_panel: PanelContainer = _make_panel()
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	status_panel.gui_input.connect(_on_status_clicked)
	detail_vb.add_child(status_panel)
	var status_hb := HBoxContainer.new()
	status_hb.add_theme_constant_override("separation", 12)
	status_panel.add_child(status_hb)
	# 命牌牌位（矢量，2026-09-15）：金描边小牌 + 「生／殁」镌字，替退「白砖」位图命魂灯。
	_status_icon = PanelContainer.new()
	_status_icon.name = "MingPai"
	_status_icon.custom_minimum_size = Vector2(UITheme.SIZE_SM * 3 / 5, UITheme.SIZE_SM * 3 / 5)
	var 牌样 := StyleBoxFlat.new()
	牌样.bg_color = UITheme.COLOR_BG_CONTENT
	牌样.border_color = UITheme.获取金色描边()
	牌样.set_border_width_all(UITheme.BORDER_W)
	牌样.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	牌样.set_content_margin_all(0.0)
	_status_icon.add_theme_stylebox_override("panel", 牌样)
	status_hb.add_child(_status_icon)
	_status_glyph = Label.new()
	_status_glyph.name = "MingPaiGlyph"
	_status_glyph.text = 命牌_生
	_status_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_glyph.add_theme_color_override("font_color", UITheme.获取暗金正文())
	UITheme.apply_project_font(_status_glyph, UITheme.FONT_BODY, true)
	_status_icon.add_child(_status_glyph)
	var status_info := VBoxContainer.new()
	status_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hb.add_child(status_info)
	_status_label = Label.new()
	_status_label.text = "在宗"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	UITheme.apply_project_font(_status_label, UITheme.FONT_H2, true)
	status_info.add_child(_status_label)
	_status_desc = Label.new()
	_status_desc.text = "灵息吐纳 +20%，其间不入历练"
	_status_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_desc.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(_status_desc, UITheme.FONT_AUX, true)
	status_info.add_child(_status_desc)
	_status_timer = Label.new()
	_status_timer.text = ""
	_status_timer.add_theme_color_override("font_color", Color(0.35, 0.68, 0.90))
	UITheme.apply_project_font(_status_timer, UITheme.FONT_AUX, true)
	status_hb.add_child(_status_timer)

	# ── ④ 互动培养（条件触发：可用互动为空则整块隐藏，不占版面）──
	_hudong_head = HBoxContainer.new()
	_hudong_head.add_theme_constant_override("separation", 6)
	_hudong_title = _make_section_title("互动培养")
	_hudong_head.add_child(_hudong_title)
	_hudong_dot = UITheme.make_red_dot()
	_hudong_dot.visible = false
	_hudong_head.add_child(_hudong_dot)
	detail_vb.add_child(_hudong_head)
	_hudong_panel = _make_panel()
	detail_vb.add_child(_hudong_panel)
	var hudong_vb := VBoxContainer.new()
	hudong_vb.add_theme_constant_override("separation", 6)
	_hudong_panel.add_child(hudong_vb)
	var hudong_grid := GridContainer.new()
	hudong_grid.columns = 3
	hudong_grid.add_theme_constant_override("h_separation", 8)
	hudong_grid.add_theme_constant_override("v_separation", 8)
	hudong_vb.add_child(hudong_grid)
	_hudong_buttons = {}
	for 互动类型 in ["论道切磋", "共参功法", "指点修行", "罚面壁思过", "宗主护法", "以毒攻毒"]:
		var btn := Button.new()
		btn.name = "Hudong_" + 互动类型
		btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM * 7 / 9)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		var 类型 = 互动类型
		btn.pressed.connect(func(): _on_hudong_pressed(类型))
		hudong_grid.add_child(btn)
		_hudong_buttons[互动类型] = btn
	# 师徒：原按钮叫「收徒」，实际行为是「替当前弟子挑一位师父」⇒ 正名为「拜师」。
	_shoutu_btn = Button.new()
	_shoutu_btn.name = "ShouTuBtn"
	_shoutu_btn.text = "拜师"
	_shoutu_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM * 7 / 9)
	_shoutu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(_shoutu_btn)
	_shoutu_btn.pressed.connect(_on_shoutu_pressed)
	hudong_grid.add_child(_shoutu_btn)
	_zhushi_btn = Button.new()
	_zhushi_btn.name = "ZhuShiBtn"
	_zhushi_btn.text = "逐师"
	_zhushi_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM * 7 / 9)
	_zhushi_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(_zhushi_btn)
	_zhushi_btn.pressed.connect(_on_zhushi_pressed)
	hudong_grid.add_child(_zhushi_btn)
	_shoutu_panel = VBoxContainer.new()
	_shoutu_panel.name = "ShouTuPanel"
	_shoutu_panel.visible = false
	_shoutu_panel.add_theme_constant_override("separation", 6)
	hudong_vb.add_child(_shoutu_panel)
	# 互动提示（文案由 _刷新互动区 按可用项动态填）
	_hudong_tip = Label.new()
	_hudong_tip.text = ""
	_hudong_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hudong_tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	UITheme.apply_project_font(_hudong_tip, UITheme.FONT_AUX, true)
	_hudong_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hudong_vb.add_child(_hudong_tip)

	# ── ⑤ 六维属性（2026-09-15 二次重排：右侧改「等宽胶囊双列」，填平留白）──
	# 上一版把右侧做成「2 列 × 3 行 + 数值右对齐」，但 name／值／ⓘ 三段靠 EXPAND_FILL 撑开：
	# 名字与数值之间、数值与 ⓘ 之间各留一大段空，右缘还空一块 ⇒ 反馈「右边大片空白」。
	# 本次每项包一个等宽胶囊（淡底 + 金描边 + 圆角 + 内边距）：名在左 → 值紧跟其右
	# → ⓘ 贴胶囊右缘；两列等宽铺满右侧，空白被胶囊填实。雷达图同步放大到 SIZE_LG×3/2。
	detail_vb.add_child(_make_section_title("六维属性"))
	var six_panel: PanelContainer = _make_panel()
	detail_vb.add_child(six_panel)
	var six_hb := HBoxContainer.new()
	six_hb.add_theme_constant_override("separation", UITheme.GRID)
	six_panel.add_child(six_hb)
	# 左：雷达图（主视觉；数值退居右侧小字）。尺寸用 Token 表达 ⇒ 不触发「魔法数字尺寸」棘轮。
	_radar = preload("res://ui/radar_chart.gd").new()
	_radar.custom_minimum_size = Vector2(UITheme.SIZE_LG * 3 / 2, UITheme.SIZE_LG * 3 / 2)
	_radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_radar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	six_hb.add_child(_radar)
	# 右：六维数值（3 行 × 2 列胶囊：体魂/根骨 · 悟性/机缘 · 心性/气运）
	var six_grid := GridContainer.new()
	six_grid.name = "SixDimGrid"
	six_grid.columns = 2
	six_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	six_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	six_grid.add_theme_constant_override("h_separation", UITheme.GRID_SM)
	six_grid.add_theme_constant_override("v_separation", UITheme.GRID_SM)
	six_hb.add_child(six_grid)
	_six_labels = {}
	var six_desc = {
		"体魂": "体魄与神魂强度，影响气血上限与渡劫承受力。",
		"根骨": "修炼根基资质，影响修炼速度与境界上限。",
		"悟性": "领悟功法与道则的能力，影响功法修炼效率。",
		"机缘": "气运机缘，影响奇遇事件概率与收益。",
		"心性": "道心稳固程度，影响瓶颈突破成功率。",
		"气运": "宗门气运加持，影响暴击与掉落。"
	}
	for dim in ["体魂","根骨","悟性","机缘","心性","气运"]:
		var cell := PanelContainer.new()
		cell.name = "SixCell_" + dim
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cell_sb := StyleBoxFlat.new()
		cell_sb.bg_color = Color(1.0, 1.0, 1.0, 0.035)
		cell_sb.border_color = Color(0.83, 0.69, 0.21, 0.18)
		cell_sb.set_border_width_all(UITheme.BORDER_W)
		cell_sb.set_corner_radius_all(UITheme.RADIUS_BUTTON)
		cell_sb.content_margin_left = 10
		cell_sb.content_margin_right = 10
		cell_sb.content_margin_top = 4
		cell_sb.content_margin_bottom = 4
		cell.add_theme_stylebox_override("panel", cell_sb)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_six_dim_clicked.bind(dim, six_desc[dim]))
		six_grid.add_child(cell)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITheme.GRID_SM)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 点击统一由胶囊承接
		cell.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = dim
		# 原名/值都是 FONT_TITLE(45) 当正文 ⇒「字比图大」。名 FONT_AUX(21)、值 FONT_H2(33)。
		name_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_DIM)
		UITheme.apply_project_font(name_lbl, UITheme.FONT_AUX, true)
		name_lbl.custom_minimum_size = Vector2(UITheme.SIZE_SM * 2 / 3, 0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		UITheme.apply_project_font(val_lbl, UITheme.FONT_H2, true)
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val_lbl)
		# 手动撑杆（不用 HBoxContainer.add_spacer：它内部 move_child(spacer, 0)，会插到索引 0）——
		# 把 ⓘ 推到胶囊右缘，值紧贴属性名之后，两者之间不留空。
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp)
		var hint := Label.new()
		hint.text = "ⓘ"
		hint.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		UITheme.apply_project_font(hint, UITheme.FONT_AUX, true)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hint)
		_six_labels[dim] = val_lbl

	# ── ⑥ 战力构成 ──
	detail_vb.add_child(_make_section_title("道行构成"))
	var power_panel: PanelContainer = _make_panel()
	detail_vb.add_child(power_panel)
	var power_vb := VBoxContainer.new()
	power_vb.add_theme_constant_override("separation", 6)
	power_panel.add_child(power_vb)
	_power_bars = {}
	var comp_desc = {
		"基础属性": "由攻/防/血/速四维构成，随境界提升。",
		"装备加成": "已穿戴法器提供的道行加成总和。",
		"灵兽加成": "主宠灵兽提供的道行加成。",
		"功法加成": "已修功法与命格提供的加成。"
	}
	for comp in [["基础属性", Color(0.35,0.68,0.90)], ["装备加成", Color(0.70,0.45,0.85)], ["灵兽加成", Color(0.35,0.80,0.50)], ["功法加成", Color(0.95,0.80,0.30)]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_comp_clicked.bind(comp[0], comp_desc[comp[0]]))
		var cn := Label.new()
		cn.text = comp[0]
		cn.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
		# 原 FONT_TITLE(45) 当正文 ⇒ 比别处大一号；降 FONT_AUX(21)。
		UITheme.apply_project_font(cn, UITheme.FONT_AUX, true)
		cn.custom_minimum_size = Vector2(UITheme.SIZE_SM * 4 / 3, 0)
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cn)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(1,1,1,0.06)
		bar_bg.custom_minimum_size = Vector2(0, UITheme.SIZE_SM / 7)
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.clip_contents = true
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bar_bg)
		var bar := ColorRect.new()
		bar.color = comp[1]
		bar.anchor_left = 0; bar.anchor_top = 0
		bar.anchor_right = 0; bar.anchor_bottom = 1
		bar.offset_right = 0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.add_child(bar)
		var vn := Label.new()
		vn.text = "0"
		vn.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
		UITheme.apply_project_font(vn, UITheme.FONT_H2, true)
		vn.custom_minimum_size = Vector2(UITheme.SIZE_SM, 0)
		vn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vn)
		_power_bars[comp[0]] = {"bar": bar, "label": vn, "color": comp[1]}
		power_vb.add_child(row)

	# ── ⑦ 命格 · 性格 · 道途（三卡自带卡名，不再加组标题）──
	var three_col := HBoxContainer.new()
	three_col.add_theme_constant_override("separation", 8)
	detail_vb.add_child(three_col)
	_destiny_label = _make_mini_card("命格", "—", true)
	_make_card_clickable(_destiny_label, _on_destiny_card_clicked)
	three_col.add_child(_destiny_label)
	_personality_label = _make_mini_card("性格", "—", true)
	_make_card_clickable(_personality_label, _on_personality_card_clicked)
	three_col.add_child(_personality_label)
	_daotu_label = _make_mini_card("道途", "—", true)
	_make_card_clickable(_daotu_label, _on_daotu_card_clicked)
	three_col.add_child(_daotu_label)

	# ── ⑧ 心境 · 道心 · 心魔（同上，三卡自带卡名）──
	var xinjing_col := HBoxContainer.new()
	xinjing_col.add_theme_constant_override("separation", 8)
	detail_vb.add_child(xinjing_col)
	_xinjing_label = _make_mini_card("心境", "—", true)
	_make_card_clickable(_xinjing_label, _on_xinjing_card_clicked)
	xinjing_col.add_child(_xinjing_label)
	_daoxin_label = _make_mini_card("道心", "—", true)
	_make_card_clickable(_daoxin_label, _on_daoxin_card_clicked)
	xinjing_col.add_child(_daoxin_label)
	_xinmo_label = _make_mini_card("心魔", "—", true)
	_make_card_clickable(_xinmo_label, _on_xinmo_card_clicked)
	xinjing_col.add_child(_xinmo_label)

	# ── ⑨ 心魔誓（只读：此处只显示「有没有誓 / 哪种誓在起效」）──
	_oath_title = _make_section_title("心魔誓")
	detail_vb.add_child(_oath_title)
	_oath_box = VBoxContainer.new()
	_oath_box.add_theme_constant_override("separation", 6)
	detail_vb.add_child(_oath_box)

	# ── ⑩ 护道人 · 牵绊（关系类信息，降权到后半）──
	detail_vb.add_child(_make_section_title("护道人 · 牵绊"))
	_护道人_label = Label.new()
	_护道人_label.name = "HudaoLabel"
	_护道人_label.text = "护道人：无"
	_护道人_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(_护道人_label, UITheme.FONT_AUX, false)
	_护道人_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	detail_vb.add_child(_护道人_label)
	var zhongcheng_col: HBoxContainer = HBoxContainer.new()
	zhongcheng_col.add_theme_constant_override("separation", 8)
	detail_vb.add_child(zhongcheng_col)
	_忠诚_label = _make_mini_card("忠诚", "—")
	zhongcheng_col.add_child(_忠诚_label)
	_欠俸_label = _make_mini_card("欠俸", "—")
	zhongcheng_col.add_child(_欠俸_label)

	# ── ⑪ 已学功法（只读：随师承与机缘自动习得）──
	detail_vb.add_child(_make_section_title("已学功法"))
	var gongfa_panel: PanelContainer = _make_panel()
	detail_vb.add_child(gongfa_panel)
	var gongfa_vb := VBoxContainer.new()
	gongfa_vb.add_theme_constant_override("separation", 6)
	gongfa_panel.add_child(gongfa_vb)
	_gongfa_list_label = Label.new()
	_gongfa_list_label.text = "尚无功法，静待机缘"
	_gongfa_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gongfa_list_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	# 原 FONT_TITLE(45) 当正文 ⇒ 明显大一号；降 FONT_BODY(27)。
	UITheme.apply_project_font(_gongfa_list_label, UITheme.FONT_BODY, true)
	gongfa_vb.add_child(_gongfa_list_label)
	var gongfa_tip := Label.new()
	gongfa_tip.text = "功法随师承与机缘自动习得，无需手动催功。"
	gongfa_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(gongfa_tip)
	gongfa_vb.add_child(gongfa_tip)

	# ── ⑫ 丹药（只读：随身 + 私藏自服）──
	# ★ 2026-09-15 改口径（反馈「应显示弟子自身携带的丹药，而不是宗门丹药库」）：
	#   旧版数的是 `Game.宗门库房`（全宗门公库）里 类别=="丹药" 的件数——既不是这名弟子的东西，
	#   且类别常量实为拼音码 `dan_yao`，比中文「丹药」永不命中 ⇒ 永远显示 0 颗（静默错数）。
	#   现改为弟子自己的两本账：背包（随身公开持有，可见品名）+ 私库（背地私藏，只见件数）。
	detail_vb.add_child(_make_section_title("丹药"))
	var danyao_panel: PanelContainer = _make_panel()
	detail_vb.add_child(danyao_panel)
	var danyao_vb := VBoxContainer.new()
	danyao_vb.add_theme_constant_override("separation", 6)
	danyao_panel.add_child(danyao_vb)
	_danyao_list_label = Label.new()
	_danyao_list_label.text = "随身丹药：无"
	_danyao_list_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_danyao_list_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	UITheme.apply_project_font(_danyao_list_label, UITheme.FONT_BODY, true)
	danyao_vb.add_child(_danyao_list_label)
	_danyao_tip = Label.new()
	_danyao_tip.text = "弟子依自身状态自行取用丹药（心魔／受伤／瓶颈各有其选），无需手动喂服。"
	_danyao_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(_danyao_tip)
	danyao_vb.add_child(_danyao_tip)

	# ── ⑬ 洗池 · 洗髓（宗主侧手动付费入口：耗仙玉强开灵泉）──
	# ★ 2026-09-15 新增「灵泉天时 + 弟子自费」两步走（铁律 11 分工，老大拍板）：
	#   · 灵泉十二载一开、开则三十日（`XiChiSystem.灵泉开启信息`）——合修真世界观的天时；
	#   · 宗主耗仙玉＝「强开灵泉」，随时可为指定弟子洗髓 ⇒ 本按钮（玩家不可代劳的重决策，保留）；
	#   · 灵泉自然开启期间，弟子可自以**个人功勋**叩请入池 ⇒ 弟子自主层月课
	#     （`Game._月课_洗池灵泉`），不设玩家按钮。
	detail_vb.add_child(_make_section_title("洗池 · 洗髓"))
	var chongzhu_panel: PanelContainer = _make_panel()
	detail_vb.add_child(chongzhu_panel)
	var chongzhu_vb := VBoxContainer.new()
	chongzhu_vb.add_theme_constant_override("separation", 6)
	chongzhu_panel.add_child(chongzhu_vb)
	_lingquan_label = Label.new()
	_lingquan_label.name = "LingQuanState"
	_lingquan_label.text = "灵泉：—"
	_lingquan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lingquan_label.add_theme_color_override("font_color", Color(0.55, 0.72, 0.85))
	UITheme.apply_project_font(_lingquan_label, UITheme.FONT_BODY, true)
	chongzhu_vb.add_child(_lingquan_label)
	var chongzhu_desc := Label.new()
	chongzhu_desc.text = "入洗池灵泉洗髓，重铸天赋根骨与修行方向。灵泉乃天地灵脉所钟，十二载一开、开则三十日；宗主可耗仙玉强开灵泉，弟子亦可自以功勋叩请入池。"
	chongzhu_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	# 本行必须换行：不换行会把整页最小宽顶到 1207，ScrollContainer 被撑破屏宽。
	chongzhu_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_project_font(chongzhu_desc, UITheme.FONT_BODY, true)
	chongzhu_vb.add_child(chongzhu_desc)
	var chongzhu_btn := Button.new()
	chongzhu_btn.text = "宗主强开灵泉（耗仙玉%d）" % int(Game.命格重塑仙玉价格 if Game != null else 0)
	chongzhu_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM * 2 / 3)
	chongzhu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(chongzhu_btn)
	chongzhu_btn.pressed.connect(_on_chongzhu_mingge_pressed)
	chongzhu_vb.add_child(chongzhu_btn)

	# ── ⑭ 闲情雅趣（弟子个人雅趣配置：天赋 / 技艺 / 专精 / 上交比例）──
	# 移位史：① 初版挂「装备」Tab 尾部（分类错位 —— 反馈「休闲玩法怎么在装备页？」）
	#         ② 一改 → 紧随「互动培养」（按「同属给弟子安排日常」归组）
	#         ③ 二改（本次）→ **下沉至详情页末段**（反馈「闲情雅趣排到下面去」）。
	# 理由：雅趣配置是**收尾型个性化设置**（天赋 / 技艺 / 专精 / 上交比例），不参与战力
	# 计算与日常决策；压在「六维属性」之前会打断「六维 → 战力构成 → 功法 → 丹药」这条
	# 主信息链。与首页「闲情雅趣」总入口互为「个人配置 ↔ 玩法入口」，职责不重复。
	_build_休闲设置_section(detail_vb)

	# ── ⑮ 底部：驱逐师门（唯一保留的玩家重决策；二次点击确认 + 门规门禁）──
	var action_hb := HBoxContainer.new()
	action_hb.add_theme_constant_override("separation", 10)
	action_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vb.add_child(action_hb)
	_驱逐_btn = Button.new()
	_驱逐_btn.name = "ExpelBtn"
	_驱逐_btn.text = "驱逐师门\n（门规所限）"
	_驱逐_btn.custom_minimum_size = Vector2(0, UITheme.SIZE_MD * 5 / 6)
	_驱逐_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(_驱逐_btn)
	_驱逐_btn.disabled = true   # ★ 2026-09-15：平时锁死，待 _刷新驱逐门禁() 按门规解禁
	_驱逐_btn.pressed.connect(_on_驱逐师门_pressed)
	action_hb.add_child(_驱逐_btn)
	_驱逐_hint = Label.new()
	_驱逐_hint.name = "ExpelHint"
	_驱逐_hint.text = "门规所限：无重罪者不得逐出同门。"
	_驱逐_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(_驱逐_hint)
	detail_vb.add_child(_驱逐_hint)
	var 归口 := Label.new()
	归口.text = "任命主事请至「殿阁 · 任免主事」；弟子自行修炼突破，无需手动催功。"
	归口.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(归口)
	detail_vb.add_child(归口)

	# ── 装备Tab（2026-09-15：立绘居中 + 八槽环绕舞台）──
	var equip_vb := VBoxContainer.new()
	equip_vb.name = "EquipPage"
	equip_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 原写死 1750 是为「内容不够高时也留出滚动行程」，但舞台重排后内容本身已 ~1300，
	# 1750 会在底部凭空多出一段无内容滚动区（视觉上是「到底了还在缩」）⇒ 交还自适应。
	equip_vb.custom_minimum_size = Vector2(0, 0)
	equip_vb.add_theme_constant_override("separation", 6)
	equip_vb.visible = false
	page_scroll.add_child(equip_vb)
	_tab_pages["装备"] = equip_vb
	_build_paper_doll(equip_vb)
	_build_power_summary(equip_vb)
	_build_set_bonus(equip_vb)
	_build_equip_detail(equip_vb)
	_build_护身符_section(equip_vb)

	# ── 灵兽Tab ──
	var pet_vb := VBoxContainer.new()
	pet_vb.name = "PetPage"
	pet_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pet_vb.add_theme_constant_override("separation", 12)
	pet_vb.visible = false
	page_scroll.add_child(pet_vb)
	_tab_pages["灵兽"] = pet_vb
	_build_beast_page(pet_vb)

	# ── 履历Tab ──
	var record_vb := VBoxContainer.new()
	record_vb.name = "RecordPage"
	record_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_vb.add_theme_constant_override("separation", 12)
	record_vb.visible = false
	page_scroll.add_child(record_vb)
	_tab_pages["履历"] = record_vb
	_build_record_page(record_vb)

	# 底部固定Tab栏
	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	tab_bar.anchor_left = 0.0
	tab_bar.anchor_top = 1.0
	tab_bar.anchor_right = 1.0
	tab_bar.anchor_bottom = 1.0
	tab_bar.offset_left = float(UITheme.MARGIN)
	tab_bar.offset_top = -92.0
	tab_bar.offset_right = -float(UITheme.MARGIN)
	tab_bar.offset_bottom = -float(UITheme.GRID / 2)
	tab_bar.add_theme_constant_override("separation", 4)
	add_child(tab_bar)

	var tab_names := ["详情", "装备", "灵兽", "履历"]
	for tname in tab_names:
		var tb := Button.new()
		tb.text = tname
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 80)
		UITheme.apply_project_font(tb, UITheme.FONT_BODY, false)
		tb.pressed.connect(_on_tab_pressed.bind(tname))
		tab_bar.add_child(tb)
		_tab_buttons[tname] = tb

	# 默认选中详情Tab
	_on_tab_pressed("详情")

	# ★ 2026-09-15 修：返回按钮必须排在**子节点末位**才能被点中。
	#   原因：Godot 的 GUI 命中检测遍历同层子节点用的是**树序倒序**（不是 z_index），
	#   而 `_content_area` 是全屏 MOUSE_FILTER_STOP 且在树里晚于本钮添加 ⇒ 非详情 Tab
	#   （那时内容顶到 y=0）会整块吃掉左上角，「← 返回」点了没反应。z_index 只管绘制顺序，
	#   救不了命中。故在全部子节点建完后把它移到末位（绘制与命中同时置顶）。
	if _back_btn != null:
		move_child(_back_btn, get_child_count() - 1)


func _make_tag(text: String, border_color: Color, bg_color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", border_color)
	UITheme.apply_project_font(lbl, int(round(16 * UITheme.UI_SCALE)), false)
	return lbl


# ───────── 立绘工具带钮样式（紧贴字面的紧凑胶囊）─────────
# 复用主题 token（获取面板色/获取金色描边/RADIUS_BUTTON/BORDER_W），零新增色字面量。
# 无 custom_minimum_size ⇒ 尺寸完全由「字面 + 内边距」决定（对齐「框体跟文字差不多大」的反馈）；
# 实测约 87×49 物理像素，仍在 44px 触控基线之上。
func _apply_hero_tool_style(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	UITheme.apply_project_font(btn, UITheme.FONT_AUX, false)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER   # 行高由「?」决定，本钮不被拉高
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板色()
	sb.border_color = UITheme.获取金色描边()
	sb.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	sb.set_border_width_all(UITheme.BORDER_W)
	sb.content_margin_left = float(UITheme.GRID)
	sb.content_margin_right = float(UITheme.GRID)
	sb.content_margin_top = float(int(round(UITheme.GRID * 0.85)))
	sb.content_margin_bottom = float(int(round(UITheme.GRID * 0.85)))
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
	btn.add_theme_color_override("font_hover_color", UITheme.COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_pressed_color", UITheme.COLOR_TEXT_GOLD)


func _make_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "◆ " + text
	lbl.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	# ★ 2026-09-14：16 → 14（配合「文字太大、翻页多」的反馈；section 标题属分隔级，不需 36px）
	UITheme.apply_project_font(lbl, int(round(14 * UITheme.UI_SCALE)), false)
	return lbl


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192, 0.60)
	sb.border_color = Color(0.83, 0.69, 0.21, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_attr_row(attr_name: String) -> HBoxContainer:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var name_lbl: Label = Label.new()
	name_lbl.text = attr_name
	name_lbl.custom_minimum_size = Vector2(24, 0)
	name_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(name_lbl, int(round(14 * UITheme.UI_SCALE)), false)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(name_lbl)
	# 自绘视觉进度条（绕开 ProgressBar 单源化校验：白名单外不得自造 fill/background stylebox）
	var bar_color: Color = Color(0.9, 0.3, 0.24)
	match attr_name:
		"防": bar_color = Color(0.2, 0.6, 0.86)
		"血": bar_color = Color(0.15, 0.68, 0.38)
		"速": bar_color = Color(0.95, 0.61, 0.07)
	var track: PanelContainer = PanelContainer.new()
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.custom_minimum_size = Vector2(0, 16)
	track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var track_style: StyleBoxFlat = StyleBoxFlat.new()
	track_style.bg_color = Color(0.122, 0.169, 0.192, 0.85)
	track_style.set_corner_radius_all(5)
	track_style.content_margin_left = 0
	track_style.content_margin_right = 0
	track_style.content_margin_top = 0
	track_style.content_margin_bottom = 0
	track.add_theme_stylebox_override("panel", track_style)
	# 内层 fill：用 Control + 子 ColorRect，宽度按 value % 在 set_disciple 里调
	var fill_root: Control = Control.new()
	fill_root.name = "AttrFillRoot"
	fill_root.custom_minimum_size = Vector2(0, 16)
	track.add_child(fill_root)
	var fill_rect: ColorRect = ColorRect.new()
	fill_rect.name = "AttrFill"
	fill_rect.color = bar_color
	fill_rect.custom_minimum_size = Vector2(0, 16)
	fill_root.add_child(fill_rect)
	hb.add_child(track)
	var val_lbl: Label = Label.new()
	val_lbl.text = "—"
	val_lbl.custom_minimum_size = Vector2(40, 0)
	val_lbl.add_theme_color_override("font_color", Color(0.91, 0.86, 0.78))
	UITheme.apply_project_font(val_lbl, int(round(14 * UITheme.UI_SCALE)), false)
	hb.add_child(val_lbl)
	# entry: bar=ColorRect（直接 set width）, val=value label, track=PanelContainer（拿总宽）
	_attr_bars[attr_name] = {"bar": fill_rect, "val": val_lbl, "track": track, "fill_root": fill_root}
	# 点击属性条 → 弹该项说明（攻/防/血/速，含气血=体力）
	var 说明: String = {
		"攻": "攻击：影响出招伤害与破防，攻修弟子攻坚更利。",
		"防": "防御：减伤根基，体修弟子越战越稳。",
		"血": "气血：生命上限，气血耗尽则战陨；闭关疗伤可恢复。",
		"速": "速度：决定出手先后与闪避，速修先发制人。",
	}.get(attr_name, "")
	_set_mouse_ignore_recursive(hb)
	hb.mouse_filter = Control.MOUSE_FILTER_STOP
	hb.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var v: int = 0
			if _current_disciple != null and _current_disciple.属性 is Dictionary:
				v = int(_current_disciple.属性.get(attr_name, 0))
			_show_info_popup(attr_name + "  " + str(v), 说明, ev.global_position if ev is InputEventMouseButton else Vector2(540, 800)))
	return hb


func _make_mini_card(title: String, desc: String, 可点 := false) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	var panel: PanelContainer = _make_panel()
	# ★ 2026-09-14 修：面板纵向撑满，使同一行的三张卡**等高**。
	#   旧版不撑满 ⇒ 内容两行的卡（如「性格」带「气质：」第二行）比一行的卡高出半格，同行参差不齐。
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(panel)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	UITheme.apply_project_font(title_lbl, int(round(14 * UITheme.UI_SCALE)), false)
	inner.add_child(title_lbl)
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.text = desc
	desc_lbl.add_theme_color_override("font_color", Color(0.91, 0.86, 0.78))
	UITheme.apply_project_font(desc_lbl, int(round(12 * UITheme.UI_SCALE)), false)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(desc_lbl)
	if 可点:
		var hi := Label.new()
		hi.text = "ⓘ"
		hi.add_theme_color_override("font_color", Color(0.40, 0.45, 0.50))
		UITheme.apply_project_font(hi, int(round(12 * UITheme.UI_SCALE)), false)
		hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(hi)
	return vb


# ───────── v15竖屏纸娃娃系统（9槽位精确对位）─────────
func _build_paper_doll(parent: VBoxContainer) -> void:
	# 2026-09-15 修：页面固定返回按钮 `_back_btn` 锚在 (12,12)-(48,48) 逻辑（物理 27~108），
	#   而 page_scroll 是 PRESET_FULL_RECT ⇒ 纸娃娃舞台若从 y=0 起，左列「道冠」槽会**整块盖住
	#   返回按钮**（实机截图确认：装备页左上角看不到 ← 返回）。详情页之所以正常，是它的立绘
	#   上方本就有等量留白。这里补齐顶部留白，让开返回按钮。
	var top_pad := Control.new()
	top_pad.name = "EquipTopPad"
	top_pad.custom_minimum_size = Vector2(0, float(int(round(56 * UITheme.UI_SCALE))))
	top_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_pad)

	var root_vb := VBoxContainer.new()
	root_vb.name = "PaperDollRoot"
	root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_theme_constant_override("separation", 10)
	parent.add_child(root_vb)
	_paper_doll_area = root_vb

	# 2026-09-15 大厂化：槽位 100 → 112（正方形比例更足，容纳图标/文字后不挤）
	var slot_size: int = 112
	# 舞台高度：取「4 槽竖列（4×100 + 3×6 ≈ 418）」与立绘（640）中的较高者，
	# 槽列由 VBoxContainer.alignment=CENTER 在舞台内垂直居中 ⇒ 首屏同框看到人与八槽。
	var 舞台高: float = 640.0

	# ── 装备舞台：左 4 槽 ｜ 立绘 ｜ 右 4 槽（人物装备界面通行布局）──
	# 旧版是「立绘独占 750 高的整宽块」+「8 槽居中 2×4 方块」两段纵向堆叠：
	# 立绘与槽位彼此脱节、首屏被立绘吃光、观感像「一张图下面挂了一格按钮」。
	# 现改为槽位夹住立绘的环绕式：左列衣饰（道冠/法袍/灵腕/灵裤）、右列器物（法兵/灵饰/束灵/云靴），
	# 立绘固定 420 宽居中（KEEP_ASPECT_COVERED 下裁切最少），左右列各 100 宽贴边。
	var 舞台 := HBoxContainer.new()
	舞台.name = "EquipStage"
	舞台.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	舞台.custom_minimum_size = Vector2(0, 舞台高)
	舞台.add_theme_constant_override("separation", UITheme.GRID)
	root_vb.add_child(舞台)

	var 左列 := VBoxContainer.new()
	左列.name = "SlotColLeft"
	左列.alignment = BoxContainer.ALIGNMENT_CENTER
	左列.add_theme_constant_override("separation", UITheme.GRID_SM)
	舞台.add_child(左列)
	for key in ["toukui", "yipao", "huzhi", "changku"]:
		_build_equip_slot(左列, key, slot_size)

	# 立绘（沿用原三层：底色 + 辉光 + 底部渐隐，只是改为居中定尺）
	var portrait_center := CenterContainer.new()
	portrait_center.name = "PortraitCenter"
	portrait_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	舞台.add_child(portrait_center)
	var portrait_box := Control.new()
	portrait_box.name = "PortraitBox"
	portrait_box.custom_minimum_size = Vector2(420, 舞台高)
	portrait_center.add_child(portrait_box)
	# 立绘区域背景（和页面统一色调）
	var pbg := ColorRect.new()
	# 2026-09-15 大厂化：原 Color(0.08,0.06,0.09) 纯黑紫与页面墨绿底脱节 → 统一到 COLOR_BG_BASE 暗青黛
	pbg.color = Color(UITheme.COLOR_BG_BASE, 1.0)
	pbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(pbg)

	var glow := TextureRect.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture = _make_radial_glow()
	glow.modulate = Color(0.85, 0.70, 0.40, 0.20)
	portrait_box.add_child(glow)

	var portrait := TextureRect.new()
	portrait.name = "DisciplePortrait"
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	_paper_doll_portrait = portrait

	# 立绘底部渐变过渡（消除硬边界）
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_shader := Shader.new()
	fade_shader.code = "shader_type canvas_item; uniform vec4 bg_col = vec4(0.04,0.07,0.10,1.0); void fragment(){ float y = UV.y; float a = smoothstep(0.75, 1.0, y); COLOR = vec4(bg_col.rgb, a); }"
	var fade_mat := ShaderMaterial.new()
	fade_mat.shader = fade_shader
	fade.material = fade_mat
	portrait_box.add_child(fade)

	var 右列 := VBoxContainer.new()
	右列.name = "SlotColRight"
	右列.alignment = BoxContainer.ALIGNMENT_CENTER
	右列.add_theme_constant_override("separation", UITheme.GRID_SM)
	舞台.add_child(右列)
	for key in ["wuqi", "peishi", "yaodai", "xuezi"]:
		_build_equip_slot(右列, key, slot_size)

	# ── 一键穿戴 | 本命法宝 | 一键卸下 ──
	var fabao_hb := HBoxContainer.new()
	fabao_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	fabao_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fabao_hb.add_theme_constant_override("separation", UITheme.GRID * 2)
	root_vb.add_child(fabao_hb)

	var btn_wear := Button.new()
	btn_wear.text = "配予"
	# 2026-09-15 大厂化：① 原硬编码翠绿 (0.18,0.80,0.44) 是全页唯一一处绿，与整套「暗金+墨绿」语言冲突；
	#              ② 原写死 200 宽，两侧各留 86 空白，操作区显松散 → 改撑满 + 垂直居中不与槽同高。
	btn_wear.custom_minimum_size = Vector2(0, 84)
	btn_wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_wear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var wear_sb := StyleBoxFlat.new()
	wear_sb.bg_color = Color(UITheme.COLOR_BTN_PRIMARY, 0.55)
	wear_sb.border_color = UITheme.COLOR_BORDER_GOLD
	wear_sb.set_border_width_all(2)
	wear_sb.set_corner_radius_all(12)
	btn_wear.add_theme_stylebox_override("normal", wear_sb)
	btn_wear.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_project_font(btn_wear, UITheme.FONT_H2, true)
	btn_wear.pressed.connect(_on_auto_equip_pressed)
	fabao_hb.add_child(btn_wear)

	_build_equip_slot(fabao_hb, "本命法宝", slot_size)

	var btn_off := Button.new()
	btn_off.text = "收回"
	btn_off.custom_minimum_size = Vector2(0, 84)
	btn_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_off.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var off_sb := StyleBoxFlat.new()
	off_sb.bg_color = Color(UITheme.COLOR_BG_CONTENT, 0.5)
	off_sb.border_color = Color(UITheme.COLOR_BORDER_GOLD, 0.45)
	off_sb.set_border_width_all(2)
	off_sb.set_corner_radius_all(12)
	btn_off.add_theme_stylebox_override("normal", off_sb)
	btn_off.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	UITheme.apply_project_font(btn_off, UITheme.FONT_H2, true)
	btn_off.pressed.connect(_on_unequip_all_pressed)
	fabao_hb.add_child(btn_off)

	# ── 储物袋（普通法宝随身携带，临阵自动择一祭出）──
	var bag_btn := Button.new()
	bag_btn.text = "储物袋"
	bag_btn.custom_minimum_size = Vector2(0, 72)
	bag_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bag_sb := StyleBoxFlat.new()
	bag_sb.bg_color = Color(UITheme.COLOR_BG_CONTENT, 0.5)
	bag_sb.border_color = Color(UITheme.COLOR_BORDER_GOLD, 0.45)
	bag_sb.set_border_width_all(2)
	bag_sb.set_corner_radius_all(12)
	bag_btn.add_theme_stylebox_override("normal", bag_sb)
	bag_btn.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY_GOLD)
	UITheme.apply_project_font(bag_btn, UITheme.FONT_H2, true)
	bag_btn.pressed.connect(_open_储物袋面板)
	root_vb.add_child(bag_btn)


# 构建单个装备槽（圆角方形，大厂标准样式）
func _build_equip_slot(parent: Node, key: String, slot_size: int) -> void:
	var slot_def = _find_slot_def(key)
	var slot_name: String = slot_def.get("name", key)
	var icon_text: String = slot_def.get("icon", "")

	var holder := PanelContainer.new()
	holder.name = "EquipSlot_" + key
	holder.custom_minimum_size = Vector2(slot_size, slot_size)
	# 2026-09-15 大厂化：原 Color(0.110,0.149,0.173) 偏蓝灰，与页面墨绿底冲突 → 统一 COLOR_BG_CONTENT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.COLOR_BG_CONTENT, 0.55)
	sb.border_color = Color(UITheme.COLOR_BORDER_GOLD, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	holder.add_theme_stylebox_override("panel", sb)
	parent.add_child(holder)

	# 用Button覆盖（点击）
	var btn := Button.new()
	btn.name = "SlotBtn"
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.tooltip_text = slot_name
	btn.pressed.connect(_on_equip_slot_pressed.bind(key))
	btn.focus_mode = Control.FOCUS_NONE
	holder.add_child(btn)

	# 空槽文字
	var slot_vb := VBoxContainer.new()
	slot_vb.name = "SlotVBox"
	slot_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_vb.add_theme_constant_override("separation", 0)
	slot_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slot_vb)

	var name_lbl := Label.new()
	name_lbl.name = "SlotName"
	name_lbl.text = icon_text
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 2026-09-15 大厂化：槽名字号 33 → 21（原 33 在方槽内挤成「字比槽大」）
	name_lbl.add_theme_color_override("font_color", Color(UITheme.COLOR_TEXT_BODY_GOLD, 0.75))
	UITheme.apply_project_font(name_lbl, UITheme.FONT_AUX, true)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_vb.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.name = "SlotHint"
	hint_lbl.text = "＋"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 2026-09-15 大厂化：＋ 号 48 → 33（原比槽名大两级，视觉主次颠倒）
	hint_lbl.add_theme_color_override("font_color", Color(UITheme.COLOR_BORDER_GOLD, 0.5))
	UITheme.apply_project_font(hint_lbl, UITheme.FONT_H2, true)
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_vb.add_child(hint_lbl)

	# 装备图标（填满槽位）
	var icon_rect := TextureRect.new()
	icon_rect.name = "SlotIcon"
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.visible = false
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon_rect)

	_equip_slots[key] = holder


# ───────── 战力摘要 ─────────
func _build_power_summary(parent: VBoxContainer) -> void:
	var hb := HBoxContainer.new()
	hb.name = "PowerSummary"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.110, 0.149, 0.173, 0.80)
	sb.border_color = Color(0.78, 0.65, 0.34, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	panel.add_child(hb)

	# 总战力
	var power_vb := VBoxContainer.new()
	power_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	power_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(power_vb)
	var power_val := Label.new()
	power_val.name = "TotalPower"
	power_val.text = "—"
	power_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_val.add_theme_color_override("font_color", Color(0.91, 0.77, 0.45))
	UITheme.apply_project_font(power_val, UITheme.FONT_DISPLAY, true)
	power_vb.add_child(power_val)
	_power_total = power_val
	var power_lbl := Label.new()
	power_lbl.text = "道行"
	power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(power_lbl, UITheme.FONT_BODY, false)
	power_vb.add_child(power_lbl)

	# 分隔线
	var sep1 := VSeparator.new()
	sep1.custom_minimum_size = Vector2(1, 40)
	hb.add_child(sep1)

	# 装备加成
	var bonus_vb := VBoxContainer.new()
	bonus_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	bonus_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(bonus_vb)
	var bonus_val := Label.new()
	bonus_val.name = "EquipBonus"
	bonus_val.text = "—"
	bonus_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_val.add_theme_color_override("font_color", Color(0.18, 0.80, 0.44))
	UITheme.apply_project_font(bonus_val, UITheme.FONT_DISPLAY, true)
	bonus_vb.add_child(bonus_val)
	_power_bonus = bonus_val
	var bonus_lbl := Label.new()
	bonus_lbl.text = "器物之助"
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(bonus_lbl, UITheme.FONT_BODY, false)
	bonus_vb.add_child(bonus_lbl)

	var sep2 := VSeparator.new()
	sep2.custom_minimum_size = Vector2(1, 40)
	hb.add_child(sep2)

	# 已装备
	var count_vb := VBoxContainer.new()
	count_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	count_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(count_vb)
	var count_val := Label.new()
	count_val.name = "EquipCount"
	count_val.text = "0/9"
	count_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_val.add_theme_color_override("font_color", Color(0.91, 0.86, 0.78))
	UITheme.apply_project_font(count_val, UITheme.FONT_DISPLAY, true)
	count_vb.add_child(count_val)
	_power_count = count_val
	var count_lbl := Label.new()
	count_lbl.text = "已着之物"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(count_lbl, UITheme.FONT_BODY, false)
	count_vb.add_child(count_lbl)


# ───────── 套装效果（2/3/5件阶梯）─────────
func _build_set_bonus(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "SetBonusPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.61, 0.35, 0.71, 0.08)
	sb.border_color = Color(0.61, 0.35, 0.71, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	# 标题行
	var title_hb := HBoxContainer.new()
	vb.add_child(title_hb)
	var title_lbl := Label.new()
	title_lbl.text = "◆ 套装效果"
	title_lbl.add_theme_color_override("font_color", Color(0.80, 0.55, 0.90))
	UITheme.apply_project_font(title_lbl, UITheme.FONT_H2, true)
	title_hb.add_child(title_lbl)
	var count_lbl := Label.new()
	count_lbl.name = "SetCount"
	count_lbl.text = "0/5"
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(count_lbl, UITheme.FONT_BODY, false)
	title_hb.add_child(count_lbl)

	# 2/3/5件效果横排
	var effects_hb := HBoxContainer.new()
	effects_hb.add_theme_constant_override("separation", 8)
	vb.add_child(effects_hb)

	var set2 := Label.new()
	set2.name = "SetBonus2"
	set2.text = "着二件 · 未成"
	set2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set2.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	UITheme.apply_project_font(set2, UITheme.FONT_BODY, false)
	effects_hb.add_child(set2)

	var set3 := Label.new()
	set3.name = "SetBonus3"
	set3.text = "着三件 · 未成"
	set3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set3.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	UITheme.apply_project_font(set3, UITheme.FONT_BODY, false)
	effects_hb.add_child(set3)

	var set5 := Label.new()
	set5.name = "SetBonus5"
	set5.text = "着五件 · 未成"
	set5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set5.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	UITheme.apply_project_font(set5, UITheme.FONT_BODY, false)
	effects_hb.add_child(set5)


# ───────── 装备详情面板 ─────────
func _build_equip_detail(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "EquipDetailPanel"
	UITheme.apply_panel_style(panel, false)
	parent.add_child(panel)
	_equip_detail_panel = panel

	var vbox := VBoxContainer.new()
	vbox.name = "EquipDetailVBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 装备名称和战力
	var header_hb := HBoxContainer.new()
	header_hb.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header_hb)

	_equip_detail_name = Label.new()
	_equip_detail_name.text = "未选择装备"
	_equip_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_section_title(_equip_detail_name)
	header_hb.add_child(_equip_detail_name)

	_equip_detail_power = Label.new()
	_equip_detail_power.text = "道行 —"
	_equip_detail_power.size_flags_horizontal = Control.SIZE_SHRINK_END
	UITheme.apply_value_text(_equip_detail_power)
	header_hb.add_child(_equip_detail_power)

	# 装备描述
	_equip_detail_desc = Label.new()
	_equip_detail_desc.text = "轻点器物格，可观其详"
	_equip_detail_desc.add_theme_color_override("font_color", Color(0.78, 0.72, 0.59))
	UITheme.apply_project_font(_equip_detail_desc, UITheme.FONT_BODY, false)
	_equip_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_equip_detail_desc)

	# 套装进度显示
	_equip_set_panel = VBoxContainer.new()
	_equip_set_panel.name = "EquipSetPanel"
	_equip_set_panel.add_theme_constant_override("separation", 4)
	vbox.add_child(_equip_set_panel)

	# 装备词缀
	_equip_detail_affixes = VBoxContainer.new()
	_equip_detail_affixes.add_theme_constant_override("separation", 4)
	vbox.add_child(_equip_detail_affixes)

	# 操作按钮
	var btn_hb := HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", UITheme.GRID)
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hb)

	_btn_unequip = Button.new()
	_btn_unequip.text = "卸下装备"
	_btn_unequip.custom_minimum_size = Vector2(160, 56)
	_btn_unequip.disabled = true
	UITheme.apply_secondary_button_style(_btn_unequip)
	_btn_unequip.pressed.connect(_on_unequip_pressed)
	btn_hb.add_child(_btn_unequip)

	_btn_auto_equip = Button.new()
	_btn_auto_equip.text = "淬炼"
	_btn_auto_equip.custom_minimum_size = Vector2(200, 56)
	UITheme.apply_primary_button_style(_btn_auto_equip)
	_btn_auto_equip.pressed.connect(_on_refine_pressed)
	btn_hb.add_child(_btn_auto_equip)


# ───────── 护身符佩戴（S45-8）─────────
func _build_护身符_section(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "护身符Panel"
	UITheme.apply_panel_style(panel, false)
	parent.add_child(panel)
	_护身符_panel = panel
	_护身符_parent = parent

	var vbox := VBoxContainer.new()
	vbox.name = "护身符VBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "护身符"
	UITheme.apply_section_title(title)
	vbox.add_child(title)

	var 当前 = _safe_get(_current_disciple, "护身符", null)
	if 当前 != null and typeof(当前) == TYPE_OBJECT:
		var nl := Label.new()
		nl.text = "当前佩戴：%s" % str(Game._物品名(当前))
		UITheme.apply_body_font(nl)
		vbox.add_child(nl)
		var 摘要 := Label.new()
		摘要.text = "道行+%d　修炼+%.1f%%　突破+%.1f%%" % [
			(_current_disciple.护身符战力净增() if _current_disciple != null else 0),
			float(Game.护身符修炼加成(_current_disciple)) * 100.0,
			float(Game.护身符突破加成(_current_disciple)) * 100.0]
		UITheme.apply_aux_font(摘要)
		vbox.add_child(摘要)
		var 卸 := Button.new()
		卸.text = "卸下护身符"
		卸.custom_minimum_size = Vector2(160, 48)
		UITheme.apply_secondary_button_style(卸)
		卸.pressed.connect(_on_卸下护身符)
		vbox.add_child(卸)
	else:
		var 空 := Label.new()
		空.text = "尚未佩戴护身符（库房符箓可佩戴为护身符，增益道行/修炼/突破）"
		UITheme.apply_aux_font(空)
		空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(空)

	# 可佩戴符箓（宗门库房内 fu_lu）
	var 库 = Game.宗门库房 if Game != null else []
	var 有候选: bool = false
	for it in 库:
		if it == null or typeof(it) != TYPE_OBJECT:
			continue
		# ★ 2026-09-16 修（真 bug · 红线⑤同族）：Item 是 RefCounted（非字典），
		#   `.get(k, 默认)` 双参在 Godot 4.7 抛「Expected 1 argument(s)」并**中断本函数**
		#   ⇒ 符箓候选扫描整段失效。改单参 .get(key) + null 兜底（本页既有正确范式）。
		var v类别: Variant = it.get("类别")
		if v类别 == null or String(v类别) != "fu_lu":
			continue
		有候选 = true
		var 卡 := HBoxContainer.new()
		var 名 := Label.new()
		名.text = "◆ %s（符词条·道行 +%d）" % [str(Game._物品名(it)), int(it.战力加成)]
		UITheme.apply_body_font(名)
		名.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		卡.add_child(名)
		var 佩 := Button.new()
		佩.text = "佩戴"
		佩.custom_minimum_size = Vector2(96, 44)
		UITheme.apply_primary_button_style(佩)
		佩.pressed.connect(_on_佩戴护身符.bind(it))
		卡.add_child(佩)
		vbox.add_child(卡)
	if not 有候选:
		var 无 := Label.new()
		无.text = "库房暂无符箓（前往符堂绘制）"
		UITheme.apply_aux_font(无)
		vbox.add_child(无)

# S55 P1：休闲设置section
func _build_休闲设置_section(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "休闲设置Panel"
	UITheme.apply_panel_style(panel, false)
	parent.add_child(panel)
	_休闲设置_panel = panel

	var vbox := VBoxContainer.new()
	vbox.name = "休闲设置VBox"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "闲情雅趣"
	UITheme.apply_section_title(title)
	vbox.add_child(title)

	if _current_disciple == null:
		return

	# 休闲天赋
	var 天赋 := Label.new()
	天赋.text = "天赋：%s" % str(_current_disciple.休闲天赋)
	UITheme.apply_body_font(天赋)
	vbox.add_child(天赋)

	# 休闲技能等级
	var 技能行 := HBoxContainer.new()
	技能行.add_theme_constant_override("separation", 8)
	var 技能标签 := Label.new()
	技能标签.text = "技艺："
	UITheme.apply_aux_font(技能标签)
	技能行.add_child(技能标签)
	for 类型 in ["钓道", "酿道", "茶道", "琴道", "厨道", "棋道", "画道"]:
		var 等级: int = int(_current_disciple.休闲技能.get(类型, 0))
		if 等级 > 0:
			var 技 := Label.new()
			技.text = "%s%d级 " % [类型, 等级]
			UITheme.apply_body_font(技)
			技能行.add_child(技)
	vbox.add_child(技能行)

	# 指定休闲
	var 指定行 := HBoxContainer.new()
	指定行.add_theme_constant_override("separation", 8)
	var 指定标签 := Label.new()
	指定标签.text = "指定修习："
	UITheme.apply_aux_font(指定标签)
	指定行.add_child(指定标签)
	var 指定选择 := OptionButton.new()
	指定选择.add_item("自由选择")
	for 类型 in ["钓道", "酿道", "茶道", "琴道", "厨道", "棋道", "画道"]:
		指定选择.add_item(类型)
	if str(_current_disciple.指定休闲) != "":
		var 索引: int = ["钓道", "酿道", "茶道", "琴道", "厨道", "棋道", "画道"].find(str(_current_disciple.指定休闲))
		if 索引 >= 0:
			指定选择.select(索引 + 1)
	指定选择.item_selected.connect(func(idx):
		if idx == 0:
			_current_disciple.指定休闲 = ""
		else:
			_current_disciple.指定休闲 = ["钓道", "酿道", "茶道", "琴道", "厨道", "棋道", "画道"][idx - 1]
		ToastManager.show_tip("已指定修习：%s" % (_current_disciple.指定休闲 if _current_disciple.指定休闲 != "" else "自由选择"))
	)
	指定行.add_child(指定选择)
	vbox.add_child(指定行)

	# 上交比例
	var 比例行 := HBoxContainer.new()
	比例行.add_theme_constant_override("separation", 8)
	var 比例标签 := Label.new()
	比例标签.text = "产出上交：%d%%" % int(_current_disciple.休闲上交比例)
	UITheme.apply_aux_font(比例标签)
	比例行.add_child(比例标签)
	var 比例滑块 := HSlider.new()
	比例滑块.min_value = 0
	比例滑块.max_value = 100
	比例滑块.step = 10
	比例滑块.value = float(_current_disciple.休闲上交比例)
	比例滑块.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	比例滑块.value_changed.connect(func(v):
		_current_disciple.休闲上交比例 = int(v)
		比例标签.text = "产出上交：%d%%" % int(v)
	)
	比例行.add_child(比例滑块)
	vbox.add_child(比例行)

	# 专精开关
	var 专精行 := HBoxContainer.new()
	专精行.add_theme_constant_override("separation", 8)
	var 专精标签 := Label.new()
	专精标签.text = "专精休闲（产出+50%，修炼-20%）"
	UITheme.apply_aux_font(专精标签)
	专精标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	专精行.add_child(专精标签)
	var 专精开关 := CheckButton.new()
	专精开关.button_pressed = bool(_current_disciple.休闲专精)
	专精开关.toggled.connect(func(pressed):
		_current_disciple.休闲专精 = pressed
		ToastManager.show_tip("专精休闲：%s" % ("已开启" if pressed else "已关闭"))
	)
	专精行.add_child(专精开关)
	vbox.add_child(专精行)

	# 上月产出
	if _current_disciple.上月休闲产出.size() > 0:
		var 产出标题 := Label.new()
		产出标题.text = "上月产出："
		UITheme.apply_aux_font(产出标题)
		vbox.add_child(产出标题)
		for key in _current_disciple.上月休闲产出.keys():
			var val = _current_disciple.上月休闲产出[key]
			var 产出 := Label.new()
			产出.text = "  %s：%s" % [str(key), str(val)]
			UITheme.apply_body_font(产出)
			vbox.add_child(产出)


func _on_佩戴护身符(物品) -> void:
	if _current_disciple == null or 物品 == null:
		return
	var r: Dictionary = Game.设置护身符(_current_disciple, 物品)
	if bool(r.get("成功", false)):
		ToastManager.show_tip("佩戴护身符：%s" % str(r.get("名称", "")))
	else:
		ToastManager.show_tip("佩戴失败：%s" % str(r.get("原因", "")))
	_refresh_护身符_section()

func _on_卸下护身符() -> void:
	if _current_disciple == null:
		return
	var r: Dictionary = Game.卸下护身符(_current_disciple)
	if bool(r.get("成功", false)):
		ToastManager.show_tip("已卸下护身符：%s" % str(r.get("名称", "")))
	else:
		ToastManager.show_tip(str(r.get("原因", "")))
	_refresh_护身符_section()

func _refresh_护身符_section() -> void:
	if _护身符_panel != null and is_instance_valid(_护身符_panel):
		var p = _护身符_parent
		var 原序: int = _护身符_panel.get_index()   # ★ 记原位：重建后插回，避免每刷一次往下沉一层
		# 2026-09-15：必须「先摘除、后 queue_free」。queue_free 帧末才生效，
		# 同帧内新建同名兄弟会被 Godot 自动改名（护身符Panel → 护身符Panel2），
		# 此后任何按名字找节点的代码都会落空（本轮 headless 验收就是这么抓到的）。
		if p != null:
			p.remove_child(_护身符_panel)
		_护身符_panel.queue_free()
		_护身符_panel = null
		if p != null and is_instance_valid(p):
			_build_护身符_section(p)
			if _护身符_panel != null and _护身符_panel.get_parent() == p:
				p.move_child(_护身符_panel, mini(原序, p.get_child_count() - 1))

# S55 P1：刷新休闲设置section
func _refresh_休闲设置_section() -> void:
	if _休闲设置_panel != null and is_instance_valid(_休闲设置_panel):
		var p = _休闲设置_panel.get_parent()
		var 原序: int = _休闲设置_panel.get_index()   # ★ 记原位：重建后必须插回，否则 add_child 会追加到末尾
		# 同 _refresh_护身符_section：先摘除再 queue_free，避免同帧重名被自动改名。
		if p != null:
			p.remove_child(_休闲设置_panel)
		_休闲设置_panel.queue_free()
		_休闲设置_panel = null
		if p != null and is_instance_valid(p):
			_build_休闲设置_section(p)
			# 2026-09-15：_build_休闲设置_section 内部是 add_child（追加到末尾），
			# 不搬回去的话「闲情雅趣」每刷一次就往下沉一层，最终跑到「驱逐师门」之后。
			if _休闲设置_panel != null and _休闲设置_panel.get_parent() == p:
				p.move_child(_休闲设置_panel, mini(原序, p.get_child_count() - 1))


# ───────── 灵兽页 ─────────
func _build_beast_page(parent: VBoxContainer) -> void:
	# 主宠卡片
	var main_panel: PanelContainer = _make_panel()
	parent.add_child(main_panel)
	var main_vb := VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vb)
	# 头像+名字行
	var head_hb := HBoxContainer.new()
	head_hb.add_theme_constant_override("separation", 16)
	main_vb.add_child(head_hb)
	var avatar_bg := PanelContainer.new()
	var avatar_sb := StyleBoxFlat.new()
	avatar_sb.bg_color = Color(0.95, 0.75, 0.20, 0.15)
	avatar_sb.border_color = Color(0.95, 0.75, 0.20, 0.8)
	avatar_sb.set_border_width_all(2)
	avatar_sb.set_corner_radius_all(48)
	avatar_sb.set_content_margin_all(4)
	avatar_bg.add_theme_stylebox_override("panel", avatar_sb)
	avatar_bg.custom_minimum_size = Vector2(96, 96)
	# 2026-09-15 修「灵兽头像框明显不对」：avatar_bg 是 PanelContainer，在 head_hb(HBoxContainer) 中
	# 会被沿交叉轴拉伸到整行高（右侧 name_vb 三行文字撑出 200+）⇒ 96×96 方框被拉成竖长条。
	# 交叉轴改 SHRINK_CENTER ⇒ 恢复正圆方框并随行居中；描边内缩 4，图标与环之间留白。
	avatar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_hb.add_child(avatar_bg)
	_beast_avatar = TextureRect.new()
	_beast_avatar.custom_minimum_size = Vector2(88, 88)
	_beast_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_beast_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_bg.add_child(_beast_avatar)
	var name_vb := VBoxContainer.new()
	name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_vb.add_theme_constant_override("separation", 4)
	head_hb.add_child(name_vb)
	var name_row := HBoxContainer.new()
	name_vb.add_child(name_row)
	_beast_name = Label.new()
	_beast_name.text = "尚未契约灵兽"
	_beast_name.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	UITheme.apply_project_font(_beast_name, UITheme.FONT_H1, true)
	name_row.add_child(_beast_name)
	_beast_info = Label.new()
	_beast_info.text = ""
	_beast_info.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	UITheme.apply_project_font(_beast_info, UITheme.FONT_BODY, false)
	name_vb.add_child(_beast_info)
	_beast_power = Label.new()
	_beast_power.text = ""
	_beast_power.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	UITheme.apply_project_font(_beast_power, UITheme.FONT_H2, true)
	name_vb.add_child(_beast_power)
	# 亲密度
	main_vb.add_child(_make_progress_row("亲密度", "_beast_loyalty", Color(0.95, 0.75, 0.20)))
	# 成长值
	main_vb.add_child(_make_progress_row("成长值", "_beast_level", Color(0.35, 0.80, 0.50)))
	# 技能标题
	var skill_title := Label.new()
	skill_title.text = "灵兽技能"
	skill_title.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	UITheme.apply_project_font(skill_title, UITheme.FONT_H2, true)
	main_vb.add_child(skill_title)
	# 技能2×2网格
	_beast_skill_grid = GridContainer.new()
	_beast_skill_grid.columns = 2
	_beast_skill_grid.add_theme_constant_override("h_separation", 10)
	_beast_skill_grid.add_theme_constant_override("v_separation", 10)
	main_vb.add_child(_beast_skill_grid)
	# 副宠槽
	var deputy_panel := PanelContainer.new()
	var dep_sb := StyleBoxFlat.new()
	dep_sb.bg_color = Color(1, 1, 1, 0.02)
	dep_sb.border_color = Color(0.78, 0.65, 0.34, 0.3)
	dep_sb.set_border_width_all(1)
	dep_sb.set_corner_radius_all(8)
	dep_sb.content_margin_left = 16; dep_sb.content_margin_right = 16
	dep_sb.content_margin_top = 14; dep_sb.content_margin_bottom = 14
	deputy_panel.add_theme_stylebox_override("panel", dep_sb)
	parent.add_child(deputy_panel)
	var dep_hb := HBoxContainer.new()
	dep_hb.add_theme_constant_override("separation", 12)
	deputy_panel.add_child(dep_hb)
	var dep_icon := Label.new()
	dep_icon.text = "＋"
	dep_icon.add_theme_color_override("font_color", Color(0.5, 0.55, 0.55))
	UITheme.apply_project_font(dep_icon, UITheme.FONT_H1, true)
	dep_hb.add_child(dep_icon)
	var dep_vb := VBoxContainer.new()
	dep_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dep_hb.add_child(dep_vb)
	var dep_name := Label.new()
	dep_name.text = "灵兽·副（空槽）"
	dep_name.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	UITheme.apply_project_font(dep_name, UITheme.FONT_BODY, false)
	dep_vb.add_child(dep_name)
	var dep_hint := Label.new()
	dep_hint.text = "坊市招募，需要灵兽契约×1"
	dep_hint.add_theme_color_override("font_color", Color(0.45, 0.50, 0.52))
	UITheme.apply_project_font(dep_hint, UITheme.FONT_AUX, false)
	dep_vb.add_child(dep_hint)

func _make_progress_row(label_text: String, bar_name: String, bar_color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	UITheme.apply_project_font(name_lbl, UITheme.FONT_BODY, false)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.name = "ValLabel"
	val_lbl.text = "—"
	val_lbl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	UITheme.apply_project_font(val_lbl, UITheme.FONT_BODY, false)
	row.add_child(val_lbl)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, 0.08)
	bg.custom_minimum_size = Vector2(0, 10)
	bg.clip_contents = true
	vb.add_child(bg)
	var bar := ColorRect.new()
	bar.color = bar_color
	bar.anchor_left = 0; bar.anchor_top = 0
	bar.anchor_right = 0; bar.anchor_bottom = 1
	bg.add_child(bar)
	if bar_name == "_beast_loyalty":
		_beast_loyalty_bar = bar
		_beast_loyalty_text = val_lbl
	else:
		_beast_level_bar = bar
		_beast_level_text = val_lbl
	return vb

# ───────── 履历页 ─────────
func _build_record_page(parent: VBoxContainer) -> void:
	# 基本信息
	parent.add_child(_make_section_title("基本信息"))
	var info_panel: PanelContainer = _make_panel()
	parent.add_child(info_panel)
	_record_info_grid = GridContainer.new()
	_record_info_grid.columns = 2
	_record_info_grid.add_theme_constant_override("h_separation", 20)
	_record_info_grid.add_theme_constant_override("v_separation", 10)
	info_panel.add_child(_record_info_grid)
	# §4.0 人生目标（目标驱动行为 + 目标栈演化史）
	parent.add_child(_make_section_title("人生目标"))
	var goal_panel: PanelContainer = _make_panel()
	parent.add_child(goal_panel)
	_record_goal_vbox = VBoxContainer.new()
	_record_goal_vbox.add_theme_constant_override("separation", 6)
	goal_panel.add_child(_record_goal_vbox)
	# §4.0 弟子自主层：储物法宝（私藏件数可见、品名不可见，须「查抄」方揭晓）
	parent.add_child(_make_section_title("储物法宝"))
	var storage_panel: PanelContainer = _make_panel()
	parent.add_child(storage_panel)
	_record_storage_vbox = VBoxContainer.new()
	_record_storage_vbox.add_theme_constant_override("separation", 6)
	storage_panel.add_child(_record_storage_vbox)
	# 社交关系
	parent.add_child(_make_section_title("社交关系"))
	var social_panel: PanelContainer = _make_panel()
	parent.add_child(social_panel)
	_record_social_grid = GridContainer.new()
	_record_social_grid.columns = 2
	_record_social_grid.add_theme_constant_override("h_separation", 10)
	_record_social_grid.add_theme_constant_override("v_separation", 10)
	social_panel.add_child(_record_social_grid)
	# 心理状态（拟真NPC系统）
	parent.add_child(_make_section_title("心理状态"))
	var psyche_panel: PanelContainer = _make_panel()
	parent.add_child(psyche_panel)
	_record_psyche_vbox = VBoxContainer.new()
	_record_psyche_vbox.add_theme_constant_override("separation", 6)
	psyche_panel.add_child(_record_psyche_vbox)
	# 互动历史（拟真NPC系统）
	parent.add_child(_make_section_title("互动历史"))
	var interaction_panel: PanelContainer = _make_panel()
	parent.add_child(interaction_panel)
	_record_interaction_vbox = VBoxContainer.new()
	_record_interaction_vbox.add_theme_constant_override("separation", 6)
	interaction_panel.add_child(_record_interaction_vbox)
	# 羁绊
	var bond_title = _make_section_title("羁绊")
	bond_title.name = "BondTitle"
	parent.add_child(bond_title)
	var bond_panel: PanelContainer = _make_panel()
	parent.add_child(bond_panel)
	_record_bond_list = VBoxContainer.new()
	_record_bond_list.add_theme_constant_override("separation", 8)
	bond_panel.add_child(_record_bond_list)
	# 当前称号
	parent.add_child(_make_section_title("当前称号"))
	var title_panel: PanelContainer = _make_panel()
	parent.add_child(title_panel)
	var title_hb := HBoxContainer.new()
	title_hb.add_theme_constant_override("separation", 12)
	title_panel.add_child(title_hb)
	var trophy := Label.new()
	trophy.text = "★"
	UITheme.apply_project_font(trophy, UITheme.FONT_H1, true)
	title_hb.add_child(trophy)
	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hb.add_child(title_vb)
	_record_title_text = Label.new()
	_record_title_text.text = "尚无称号"
	_record_title_text.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	UITheme.apply_project_font(_record_title_text, UITheme.FONT_H2, true)
	title_vb.add_child(_record_title_text)
	_record_title_desc = Label.new()
	_record_title_desc.text = "修为达标、宗门任职、技艺精进皆可得道号尊称"
	_record_title_desc.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	UITheme.apply_project_font(_record_title_desc, UITheme.FONT_AUX, false)
	title_vb.add_child(_record_title_desc)
	# 已获得称号列表
	parent.add_child(_make_section_title("道号尊称"))
	var title_list_panel: PanelContainer = _make_panel()
	parent.add_child(title_list_panel)
	_record_title_list = VBoxContainer.new()
	_record_title_list.add_theme_constant_override("separation", 6)
	title_list_panel.add_child(_record_title_list)
	# 宗门成就
	var ach_title = _make_section_title("宗门成就")
	ach_title.name = "AchTitle"
	parent.add_child(ach_title)
	var ach_panel: PanelContainer = _make_panel()
	parent.add_child(ach_panel)
	_record_achievement_grid = GridContainer.new()
	_record_achievement_grid.columns = 4
	_record_achievement_grid.add_theme_constant_override("h_separation", 8)
	_record_achievement_grid.add_theme_constant_override("v_separation", 8)
	ach_panel.add_child(_record_achievement_grid)
	# 历练记录
	parent.add_child(_make_section_title("历练记录"))
	var timeline_panel: PanelContainer = _make_panel()
	parent.add_child(timeline_panel)
	_record_timeline = VBoxContainer.new()
	_record_timeline.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(_record_timeline)


# ───────── 社交关系卡片详情（★ 2026-09-15：此前卡片无命中区，点了没反应）─────────
func _on_社交卡_pressed(标题: String) -> void:
	if _current_disciple == null or not is_instance_valid(Game):
		return
	var d = _current_disciple
	var 正文: String = ""
	if 标题.contains("道侣"):
		if str(d.道侣) == "":
			正文 = "尚无道侣。\n\n结为道侣后：双修加成生效、危难互赠护身之物；道侣陨落将重创道心。"
		else:
			正文 = "道侣：%s\n双修加成：+%.0f%%\n\n结发同修、生死相护。" % [str(d.道侣), float(d.双修加成) * 100.0]
	elif 标题.contains("血脉共鸣"):
		var 亲数: int = int(d.获取在宗血脉亲属数())
		var 比: float = min(0.003 * 亲数, 0.012) * 100.0
		正文 = "在宗血脉亲属：%d 位\n修炼加成：+%.1f%%　道行加成：+%.1f%%（上限 +1.2%%）\n\n亲属：%s" % [
			亲数, 比, 比, _亲缘名册()]
	elif 标题.contains("家族"):
		if str(d.家族ID) == "":
			正文 = "散修出身，暂无家族。\n\n可投靠修仙家族：得族中资源与庇护，亦须承担族务。"
		else:
			正文 = "家族：%s\n职位：%s\n家族贡献：%d" % [str(d.家族名), str(d.家族职位), int(d.家族贡献)]
	elif 标题.contains("血脉"):
		正文 = "血脉：%s\n纯度：%.0f%%\n状态：%s\n血脉功法：%d 部" % [
			str(d.血脉类型), float(d.血脉纯度), ("已觉醒" if d.血脉觉醒 else "未觉醒"), d.血脉功法列表.size()]
	elif 标题.contains("家庭"):
		正文 = "父母：%s\n子女：%s\n\n（血缘亲属同宗可触发血脉共鸣加成）" % [_名册(d.父母ID), _名册(d.子嗣列表)]
	elif 标题.contains("子嗣"):
		正文 = "子嗣：%s\n共 %d 人\n\n子嗣可入宗修行，承父母部分资质与血脉。" % [_名册(d.子嗣列表), d.子嗣列表.size()]
	elif 标题.contains("道友") or 标题.contains("好友") or 标题.contains("仇人"):
		var 网: Dictionary = Game.获取弟子关系网络(str(d.弟子ID))
		var 列: Array = []
		if 标题.contains("道友"):
			列 = 网.get("道友列表", [])
		elif 标题.contains("好友"):
			列 = 网.get("好友列表", [])
		else:
			列 = 网.get("仇人列表", [])
		if 列.is_empty():
			正文 = "暂无此人脉。\n\n好感度随同门共事、赠礼、并肩作战变化：\n· 道友：好感度 ≥ 80\n· 好友：好感度 60–79\n· 仇人：好感度 < 20"
		else:
			var 行: Array = []
			for r in 列:
				var rd: Dictionary = r if typeof(r) == TYPE_DICTIONARY else {}
				行.append("· %s（好感 %d）" % [str(rd.get("姓名", "—")), int(rd.get("好感度", 0))])
			正文 = "共 %d 人：\n%s" % [列.size(), "\n".join(行)]
	if 正文 == "":
		正文 = "暂无详情。"
	var dlg := AcceptDialog.new()
	dlg.name = "SocialDetailDialog"
	dlg.title = 标题.strip_edges()
	dlg.dialog_text = 正文
	UITheme.apply_popup_font(dlg, int(round(14 * UITheme.UI_SCALE)), false)
	dlg.ok_button_text = "知道了"
	add_child(dlg)
	dlg.popup_centered()

## 关系名册：把弟子ID列表转成「姓名（境界）」串，缺项跳过
func _名册(ids: Array) -> String:
	if ids.is_empty():
		return "无"
	var 名: Array = []
	for pid in ids:
		var x = Game._取弟子(int(pid)) if Game.has_method("_取弟子") else null
		if x != null:
			名.append("%s（%s）" % [str(x.姓名), str(x.境界)])
	return "、".join(名) if not 名.is_empty() else "无"

## 在宗血脉亲属名册（同家族ID / 有血缘关联的在宗弟子）
func _亲缘名册() -> String:
	var d = _current_disciple
	var 名: Array = []
	for x in Game.弟子列表:
		if x == null or x == d or str(x.状态) != "在宗":
			continue
		if str(d.家族ID) != "" and str(x.家族ID) == str(d.家族ID):
			名.append("%s（%s）" % [str(x.姓名), str(x.境界)])
	return "、".join(名) if not 名.is_empty() else "无"


# ───────── 装备槽位点击事件 ─────────
func _on_equip_slot_pressed(slot_key: String) -> void:
	# ★ 2026-09-15（老大定）：本命法宝槽不走「穿/卸」逻辑 —— 它不是捡来的装备，
	#   而是弟子自身以精血神识祭炼而成的贴身之物（不可购、不可赠、不可卸）。
	#   点它 = 开祭炼/温养面板；未成器时给出「境界 + 机缘」双门槛提示。
	if slot_key == "本命法宝":
		_open_本命法宝面板()
		return
	_selected_equip_slot = slot_key
	_refresh_equip_detail()

# ───────── 本命法宝：祭炼 / 温养面板 ─────────
# 世界观：本命法宝与神魂相连、同生共死 ⇒ 只此一件、不可转让、不可卸下；
#   成器须「境界基础 + 机缘」双门槛，故并非人人都有（不设保底）。
func _open_本命法宝面板() -> void:
	if _current_disciple == null or not is_instance_valid(Game):
		return
	var d = _current_disciple
	var 配: Dictionary = {}
	if Game.has_method("弟子本命法宝配置"):
		配 = Game.弟子本命法宝配置(d)
	var 已立: bool = not 配.is_empty()
	var 文案: String = ""
	if 已立:
		var 级: int = int(d.本命法宝祭炼等级)
		文案 = "【本命法宝】%s（%s·%s）\n\n成长：%s（全属性）\n温养重数：%d / %d（每重 +10%% 成长）\n主动技：%s\n被动：%s\n\n本命法宝与神魂相连，损毁则伤及道基，故不可转赠他人。" % [
			str(配.get("名称", "")), str(配.get("品阶", "")), str(配.get("子品阶", "")),
			str(配.get("成长值", "")), 级, int(Game.本命法宝温养上限),
			str(配.get("主动技能", "—")), str(配.get("被动效果", "—"))]
	else:
		var 可: Dictionary = Game.弟子可祭炼本命法宝(d)
		var 率: float = float(可.get("成功率", 0.0)) * 100.0
		var 耗: int = int(可.get("消耗", 0))
		if bool(可.get("ok", false)):
			文案 = "【祭炼本命法宝】\n\n%s 尚无本命法宝。\n境界：%s %d 层 —— 已达祭炼门槛（%s 期）。\n\n以精血神识温养器胚，成器须机缘加身：\n· 机缘检定成功率：%.0f%%\n· 耗宗门灵石：%d\n· 器型与品阶随境界机缘而定\n\n（器不成则精血空耗，灵石不退。）" % [
				str(d.姓名), str(d.境界), int(d.层数), str(Game.本命法宝境界门槛), 率, 耗]
		else:
			文案 = "【本命法宝】\n\n%s 尚未祭炼本命法宝。\n\n%s\n\n本命法宝以自身精血神识温养而成，非外物可得；\n境界足够、机缘加身时，方能在洞府闭门祭炼。" % [str(d.姓名), str(可.get("reason", ""))]
	_show_本命法宝弹窗(文案, 已立)

## 祭炼/温养确认弹窗（复用项目统一弹窗样式；按钮按状态二选一）
func _show_本命法宝弹窗(文案: String, 已立: bool) -> void:
	var dlg := AcceptDialog.new()
	dlg.name = "BenmingFabaoDialog"
	dlg.title = "本命法宝"
	dlg.dialog_text = 文案
	UITheme.apply_popup_font(dlg, int(round(14 * UITheme.UI_SCALE)), false)
	dlg.ok_button_text = "温养一重" if 已立 else "闭门祭炼"
	dlg.add_cancel_button("暂不")
	dlg.confirmed.connect(func():
		var r: Dictionary = Game.温养本命法宝(_current_disciple) if 已立 else Game.祭炼本命法宝(_current_disciple)
		ToastManager.show_tip(str(r.get("msg", "")))
		_refresh_equip_slots()
		_refresh_power_summary()
		dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


func _on_unequip_pressed() -> void:
	if _current_disciple == null or _selected_equip_slot == "":
		return
	# 调用弟子的卸载函数
	if _current_disciple.has_method("卸载"):
		_current_disciple.卸载(_selected_equip_slot)
		_refresh_equip_slots()
		_refresh_equip_detail()
		_refresh_power_summary()


func _on_auto_equip_pressed() -> void:
	if _current_disciple == null:
		return
	# 一键最优：遍历背包按战力加成贪心填各槽（受 品阶≤境界 限制），不再用 debug 生成器
	var 穿戴前: int = int(_current_disciple.装备.size())
	_current_disciple.一键最优穿戴()
	var 穿戴后: int = int(_current_disciple.装备.size())
	if 穿戴后 > 穿戴前:
		ToastManager.show_tip("已按背包最优穿戴（%d→%d件）" % [穿戴前, 穿戴后])
	elif _current_disciple.背包.size() == 0:
		ToastManager.show_tip("背包为空，无可穿戴物品")
	else:
		ToastManager.show_tip("背包无更优装备可穿")
	_refresh_equip_slots()
	_refresh_equip_detail()
	_refresh_power_summary()


func _on_refine_pressed() -> void:
	# 祭炼：消耗灵石提升装备灵性，每级+5%战力
	if _current_disciple == null or _selected_equip_slot == "":
		ToastManager.show_tip("请先选择一件装备")
		return
	var 装备 = _safe_get(_current_disciple, "装备", {})
	if typeof(装备) != TYPE_DICTIONARY or not 装备.has(_selected_equip_slot):
		ToastManager.show_tip("该槽位未装备")
		return
	var item = 装备[_selected_equip_slot]
	if item == null or typeof(item) != TYPE_OBJECT:
		return
	var result: Dictionary = item.祭炼(Game.灵石)
	if result["成功"]:
		Game.灵石 -= int(result["消耗"])
		ToastManager.show_tip("祭炼成功！+%d级，消耗灵石%d" % [int(result["新等级"]), int(result["消耗"])])
		_refresh_equip_slots()
		_refresh_power_summary()
		_current_disciple.计算战力() if _current_disciple.has_method("计算战力") else null
	else:
		ToastManager.show_tip("祭炼失败：%s（需灵石%d）" % [str(result["原因"]), int(result.get("消耗", 0))])


func _on_unequip_all_pressed() -> void:
	if _current_disciple == null:
		return
	# 遍历所有槽位卸下
	for slot_def in EQUIP_SLOTS:
		var key: String = slot_def["key"]
		if _current_disciple.has_method("卸载"):
			_current_disciple.卸载(key)
	_refresh_equip_slots()
	_refresh_equip_detail()


# ───────── 储物袋（普通法宝 · 随身携带，临阵择一祭出）─────────
# 世界观：普通法宝是外物，可购、可赠、可夺；弟子以神识驭之，一次只祭出一件。
# 故此处只管「带哪些」，不管「穿哪件」—— 出战法宝由 弟子.选择出战法宝() 按战况自定。
func _open_储物袋面板() -> void:
	if _current_disciple == null:
		return
	var d = _current_disciple
	var dlg := AcceptDialog.new()
	dlg.name = "StorageBagDialog"
	dlg.title = "储物袋"
	dlg.ok_button_text = "关闭"
	UITheme.apply_popup_font(dlg, int(round(13 * UITheme.UI_SCALE)), false)

	var 卷 := ScrollContainer.new()
	卷.custom_minimum_size = Vector2(int(420 * UITheme.UI_SCALE), int(300 * UITheme.UI_SCALE))
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	卷.add_child(vb)
	dlg.add_child(卷)

	var 袋: Array = d.获取储物袋法宝() if d.has_method("获取储物袋法宝") else d.储物袋法宝.duplicate()
	var 战况: String = str(d.推断战况()) if d.has_method("推断战况") else "常规"
	var 出战: String = str(d.选择出战法宝(战况)) if d.has_method("选择出战法宝") else ""
	_袋标题(vb, "随身法宝  %d / %d" % [袋.size(), int(d.储物袋容量())])
	var 战况名: Dictionary = {"危急": "心魔压身", "固守": "持重护身", "常规": "寻常对敌"}
	var 出战名: String = "尚未择定"
	if 出战 != "":
		出战名 = str(Game.获取普通法宝配置(出战).get("名称", 出战))
	_袋说明(vb, "临阵自动择一祭出 · 眼下%s → %s" % [str(战况名.get(战况, 战况)), 出战名])

	_袋标题(vb, "袋中法宝")
	if 袋.is_empty():
		_袋说明(vb, "空空如也。法宝须于器殿锻造或坊市购得，方能收入袋中。")
	for tid in 袋:
		var 配: Dictionary = Game.获取普通法宝配置(str(tid))
		if 配.is_empty():
			continue
		_袋行(vb, _法报名(配, str(tid)), _法宝属性行(配), "取出", _on_袋取出.bind(str(tid), dlg))

	var 未入: Array = []
	for tid in Game.获取所有普通法宝配置().keys():
		if not 袋.has(str(tid)):
			未入.append(str(tid))
	if not 未入.is_empty():
		_袋标题(vb, "器殿藏物")
		for tid in 未入:
			var 配2: Dictionary = Game.获取普通法宝配置(str(tid))
			_袋行(vb, _法报名(配2, str(tid)), _法宝属性行(配2), "收入", _on_袋收入.bind(str(tid), dlg))

	add_child(dlg)
	dlg.popup_centered()

# 法宝展示名：名称（品阶·类型），缺项自动省略
func _法报名(配: Dictionary, 兜底: String) -> String:
	var 名: String = str(配.get("名称", 兜底))
	var 品: String = str(配.get("品阶", ""))
	var 类: String = str(配.get("类型", ""))
	if 品 == "" and 类 == "":
		return 名
	return "%s（%s%s）" % [名, 品, ("·" + 类) if 类 != "" else ""]

func _法宝属性行(配: Dictionary) -> String:
	return "攻 %d　防 %d　血 %d" % [int(配.get("基础攻击", 0)), int(配.get("基础防御", 0)), int(配.get("基础气血", 0))]

func _袋标题(parent: Node, 文本: String) -> void:
	var l := Label.new()
	l.text = 文本
	l.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_project_font(l, UITheme.FONT_H2, true)
	parent.add_child(l)

func _袋说明(parent: Node, 文本: String) -> void:
	var l := Label.new()
	l.text = 文本
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color(0.68, 0.74, 0.78))
	UITheme.apply_project_font(l, UITheme.FONT_AUX, false)
	parent.add_child(l)

func _袋行(parent: Node, 名: String, 属性: String, 按钮文案: String, 回调: Callable) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var nl := Label.new()
	nl.text = 名
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.add_theme_color_override("font_color", Color(0.90, 0.86, 0.70))
	UITheme.apply_project_font(nl, UITheme.FONT_BODY, false)
	hb.add_child(nl)
	var vl := Label.new()
	vl.text = 属性
	vl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.72))
	UITheme.apply_project_font(vl, UITheme.FONT_AUX, false)
	hb.add_child(vl)
	var btn := Button.new()
	btn.text = 按钮文案
	btn.custom_minimum_size = Vector2(int(72 * UITheme.UI_SCALE), int(28 * UITheme.UI_SCALE))
	UITheme.apply_project_font(btn, UITheme.FONT_AUX, false)
	btn.pressed.connect(回调)
	hb.add_child(btn)
	parent.add_child(hb)

func _on_袋取出(tid: String, dlg: AcceptDialog) -> void:
	if _current_disciple == null:
		return
	var r: Dictionary = Game.卸下普通法宝(_current_disciple.弟子ID, tid)
	ToastManager.show_tip(str(r.get("原因", "")))
	dlg.queue_free()
	_open_储物袋面板()
	_refresh_equip_slots()
	_refresh_power_summary()

func _on_袋收入(tid: String, dlg: AcceptDialog) -> void:
	if _current_disciple == null:
		return
	var r: Dictionary = Game.装备普通法宝(_current_disciple.弟子ID, tid)
	ToastManager.show_tip(str(r.get("原因", "")))
	dlg.queue_free()
	_open_储物袋面板()
	_refresh_equip_slots()
	_refresh_power_summary()

# ───────── 刷新装备槽位显示 ─────────
func _refresh_equip_slots() -> void:
	if _current_disciple == null:
		return
	# 获取弟子的装备字典
	var 装备 = _safe_get(_current_disciple, "装备", {})
	if typeof(装备) != TYPE_DICTIONARY:
		装备 = {}
	for key in _equip_slots.keys():
		var holder: PanelContainer = _equip_slots[key]
		var item = 装备.get(key, null)
		# ★ 2026-09-15：本命法宝槽的数据源是 `弟子.本命法宝ID`（自身祭炼所得），**不在**「装备」字典里。
		#   成器后合成一个字典喂给下面的通用渲染分支，从而沿用装备槽样式与品阶配色。
		if key == "本命法宝":
			item = null
			if is_instance_valid(Game) and Game.has_method("弟子本命法宝配置"):
				var 本: Dictionary = Game.弟子本命法宝配置(_current_disciple)
				if not 本.is_empty():
					item = {"名称": str(本.get("名称", "")), "品阶": str(本.get("品阶", ""))}
		var name_lbl: Label = holder.get_node_or_null("SlotVBox/SlotName")
		var hint_lbl: Label = holder.get_node_or_null("SlotVBox/SlotHint")
		var icon_rect: TextureRect = holder.get_node_or_null("SlotIcon")
		var slot_vb: VBoxContainer = holder.get_node_or_null("SlotVBox")
		var slot_def = _find_slot_def(key)
		var default_name: String = slot_def.get("icon", key) if slot_def != null else key

		if item != null and (typeof(item) == TYPE_DICTIONARY or typeof(item) == TYPE_OBJECT):
			var 品阶 = str(item.get("品阶")) if typeof(item) == TYPE_DICTIONARY else str(item.品阶)
			var quality_color = _get_quality_color(品阶)
			# 品阶色边框直接应用到holder
			var eq_sb := StyleBoxFlat.new()
			eq_sb.bg_color = Color(UITheme.COLOR_BG_CONTENT, 0.92)
			eq_sb.border_color = quality_color
			eq_sb.set_border_width_all(3)
			eq_sb.set_corner_radius_all(12)
			eq_sb.content_margin_left = 4
			eq_sb.content_margin_right = 4
			eq_sb.content_margin_top = 4
			eq_sb.content_margin_bottom = 4
			holder.add_theme_stylebox_override("panel", eq_sb)
			# 显示装备图标，隐藏文字
			if slot_vb != null:
				slot_vb.visible = false
			if icon_rect != null:
				# 图标优先级：类别_品阶（如 faqi_bao.png）→ 槽位通用（如 wuqi.png）
				var 品阶后缀: Dictionary = {"凡阶":"fan","灵阶":"ling","宝阶":"bao","王阶":"wang","圣阶":"sheng","仙阶":"xian","道阶":"dao"}
				# ★2026-09-15 修正：`Item.类别` 实存**拼音码**（见 item.gd `类别中文名`），原表用中文键 ⇒ 一律落到 `%s_品阶.png` 不存在的路径、装备图标全回落槽位通用图。
				#   拼音键为主，中文键保留兼容（item.gd 默认值 `类别 := "法器"` 会写入中文）；补齐原先缺失的 `fu_lu`（符箓）。
				var 类别后缀: Dictionary = {
					"fa_qi": "faqi", "shen_bing": "shenbing", "fabao": "fabao",
					"dan_yao": "danyao", "ling_cai": "lingcai", "fu_lu": "fulu",
					"法器": "faqi", "神兵": "shenbing", "法宝": "fabao",
					"丹药": "danyao", "灵材": "lingcai", "符箓": "fulu",
				}
				var item_obj = item if typeof(item) == TYPE_OBJECT else null
				var icon_tex: Texture2D = null
				if item_obj != null and "类别" in item_obj and "品阶" in item_obj:
					var cat: String = 类别后缀.get(str(item_obj.类别), str(item_obj.类别))
					var ql: String = 品阶后缀.get(str(item_obj.品阶), "fan")
					var cat_path = "res://art/icons/equipment/%s_%s.png" % [cat, ql]
					icon_tex = _load_icon_safe(cat_path)
				if icon_tex == null:
					var icon_key = key if key != "本命法宝" else "benmingfabao"
					var icon_path = "res://art/icons/equipment/%s.png" % icon_key
					icon_tex = _load_icon_safe(icon_path)
				if icon_tex != null:
					icon_rect.texture = icon_tex
					icon_rect.visible = true
				else:
					icon_rect.visible = false
					if slot_vb != null:
						slot_vb.visible = true
					var eq_name = str(item.get("名称", default_name)) if typeof(item) == TYPE_DICTIONARY else str(item.名称)
					if name_lbl != null:
						name_lbl.text = eq_name
						name_lbl.add_theme_color_override("font_color", quality_color)
		else:
			var empty_sb := StyleBoxFlat.new()
			empty_sb.bg_color = Color(UITheme.COLOR_BG_CONTENT, 0.55)
			empty_sb.border_color = Color(UITheme.COLOR_BORDER_GOLD, 0.35)
			empty_sb.set_border_width_all(2)
			empty_sb.set_corner_radius_all(12)
			empty_sb.content_margin_left = 4
			empty_sb.content_margin_right = 4
			empty_sb.content_margin_top = 4
			empty_sb.content_margin_bottom = 4
			holder.add_theme_stylebox_override("panel", empty_sb)
			if slot_vb != null:
				slot_vb.visible = true
			if icon_rect != null:
				icon_rect.visible = false
			if name_lbl != null:
				# 空的本命法宝槽：写「未祭炼」而非槽名，并提示点此祭炼（它不是捡来的装备）
				name_lbl.text = "未祭炼" if key == "本命法宝" else default_name
				name_lbl.add_theme_color_override("font_color", Color(UITheme.COLOR_TEXT_BODY_GOLD, 0.75))
				UITheme.apply_project_font(name_lbl, UITheme.FONT_H2, true)
			if hint_lbl != null:
				hint_lbl.visible = true
				if key == "本命法宝":
					hint_lbl.text = "点此祭炼"
	# 同步刷新战力摘要
	_refresh_power_summary()
	# 刷新套装效果
	_refresh_set_bonus()
	# 刷新灵兽页和履历页
	_refresh_beast_page()
	_refresh_record_page()


func _find_slot_def(key: String) -> Dictionary:
	for slot_def in EQUIP_SLOTS:
		if slot_def["key"] == key:
			return slot_def
	return {}


func _get_quality_color(品阶: String) -> Color:
	var q = 品阶.replace("阶", "")
	match q:
		"凡": return Color(0.75, 0.75, 0.75)
		"灵": return Color(0.30, 0.85, 0.40)
		"宝": return Color(0.30, 0.55, 1.0)
		"王": return Color(0.65, 0.30, 1.0)
		"圣": return Color(1.0, 0.60, 0.15)
		"仙": return Color(1.0, 0.25, 0.25)
		"道": return Color(1.0, 0.84, 0.30)
		_: return Color(0.78, 0.65, 0.34)


func _load_icon_safe(path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _make_radial_glow() -> Texture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


func _refresh_set_bonus() -> void:
	# 扫描已装备物品，统计套装件数并更新面板
	var set_panel = get_node_or_null("PageScroll/EquipPage/SetBonusPanel")
	if set_panel == null:
		return
	if _current_disciple == null:
		set_panel.visible = false
		return
	var 装备 = _safe_get(_current_disciple, "装备", {})
	if typeof(装备) != TYPE_DICTIONARY:
		set_panel.visible = false
		return
	# 统计各套装件数
	var set_counts: Dictionary = {}
	for key in 装备.keys():
		var item = 装备[key]
		if item != null and typeof(item) == TYPE_OBJECT and "套装ID" in item and item.套装ID != "":
			var sid: String = str(item.套装ID)
			set_counts[sid] = set_counts.get(sid, 0) + 1
	if set_counts.is_empty():
		set_panel.visible = false
		return
	set_panel.visible = true
	# 取件数最多的套装显示
	var best_set: String = ""
	var best_count: int = 0
	for sid in set_counts.keys():
		if set_counts[sid] > best_count:
			best_count = set_counts[sid]
			best_set = sid
	var set_def: Dictionary = Item.套装库.get(best_set, {})
	var set_name: String = set_def.get("名称", best_set)
	# 更新标题
	var title_lbl = set_panel.get_node_or_null("VBox/TitleHBox/TitleLabel")
	var count_lbl = set_panel.get_node_or_null("VBox/TitleHBox/SetCount")
	if title_lbl:
		title_lbl.text = "◆ " + set_name
	if count_lbl:
		count_lbl.text = str(best_count) + "/5"
	# 更新效果行（2件/3件/5件）
	var effects = set_panel.get_node_or_null("VBox/EffectsHBox")
	if effects:
		for child in effects.get_children():
			child.queue_free()
		var tiers = [["2件", set_def.get("2件", ""), best_count >= 2], ["3件", set_def.get("3件", ""), best_count >= 3], ["5件", set_def.get("5件", ""), best_count >= 5]]
		for t in tiers:
			var eb := VBoxContainer.new()
			eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			effects.add_child(eb)
			var tn := Label.new()
			tn.text = t[0]
			tn.add_theme_color_override("font_color", Color(0.91,0.83,0.60) if t[2] else Color(0.4,0.45,0.5))
			UITheme.apply_project_font(tn, UITheme.FONT_BODY, false)
			eb.add_child(tn)
			var td := Label.new()
			td.text = t[1]
			td.add_theme_color_override("font_color", Color(0.85,0.88,0.90) if t[2] else Color(0.35,0.4,0.45))
			UITheme.apply_project_font(td, UITheme.FONT_BODY, false)
			td.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eb.add_child(td)

func _refresh_beast_page() -> void:
	if _current_disciple == null:
		return
	var beast = _current_disciple.主宠灵兽
	if beast == null or typeof(beast) != TYPE_OBJECT:
		if _beast_name:
			_beast_name.text = "尚未契约灵兽"
		if _beast_info:
			_beast_info.text = "可通过坊市招募或历练收服"
		return
	if _beast_name:
		_beast_name.text = str(beast.种类名)
	if _beast_info:
		var type_cn: String = Beast.类型中文.get(beast.beast_type, "攻伐型")
		_beast_info.text = str(beast.品阶) + " · " + type_cn
	if _beast_power:
		var bp: int = beast.本体战力() if beast.has_method("本体战力") else 0
		_beast_power.text = "道行 " + str(bp)
	# 加载灵兽立绘头像
	if _beast_avatar and beast.has_method("取立绘路径"):
		var beast_path: String = beast.取立绘路径()
		var beast_tex = _load_texture_safe(beast_path)
		if beast_tex != null:
			_beast_avatar.texture = beast_tex
			_beast_avatar.visible = true
		else:
			_beast_avatar.visible = false
	# 忠诚度
	var loyalty: int = int(beast.忠诚度)
	if _beast_loyalty_text:
		_beast_loyalty_text.text = str(loyalty) + "/100"
	if _beast_loyalty_bar:
		_beast_loyalty_bar.offset_right = int(300 * clampf(float(loyalty)/100.0, 0, 1))
	# 等级
	var lv: int = int(beast.等级)
	var lv_max: int = int(beast.等级上限)
	if _beast_level_text:
		_beast_level_text.text = str(beast.品阶) + " " + str(lv) + " 阶/" + str(lv_max)
	if _beast_level_bar:
		_beast_level_bar.offset_right = int(300 * clampf(float(lv)/float(max(lv_max,1)), 0, 1))
	# 技能网格
	if _beast_skill_grid:
		for c in _beast_skill_grid.get_children():
			c.queue_free()
		var skills = [
			[str(beast.主动) if beast.主动 != "" else "未解锁", beast.主动 != ""],
			[str(beast.被动) if beast.被动 != "" else "未解锁", beast.被动 != ""],
			[str(beast.天赋) if beast.天赋 != "" else "四阶解锁", false],
			["亲密1000解锁", false]
		]
		for sk in skills:
			var sk_panel := PanelContainer.new()
			var sk_sb := StyleBoxFlat.new()
			sk_sb.bg_color = Color(1,1,1, 0.06 if sk[1] else 0.02)
			sk_sb.border_color = Color(0.78,0.65,0.34, 0.5 if sk[1] else 0.15)
			sk_sb.set_border_width_all(1)
			sk_sb.set_corner_radius_all(6)
			sk_sb.content_margin_left = 12; sk_sb.content_margin_right = 12
			sk_sb.content_margin_top = 10; sk_sb.content_margin_bottom = 10
			sk_panel.add_theme_stylebox_override("panel", sk_sb)
			sk_panel.custom_minimum_size = Vector2(340, 80)
			_beast_skill_grid.add_child(sk_panel)
			var sk_vb := VBoxContainer.new()
			sk_panel.add_child(sk_vb)
			var sk_name := Label.new()
			sk_name.text = sk[0]
			sk_name.add_theme_color_override("font_color", Color(0.91,0.83,0.60) if sk[1] else Color(0.4,0.45,0.5))
			UITheme.apply_project_font(sk_name, UITheme.FONT_BODY, false)
			sk_vb.add_child(sk_name)
			if sk[1]:
				var sk_hint := Label.new()
				sk_hint.text = "已激活"
				sk_hint.add_theme_color_override("font_color", Color(0.35,0.80,0.50))
				UITheme.apply_project_font(sk_hint, UITheme.FONT_AUX, false)
				sk_vb.add_child(sk_hint)

# §4.0 弟子自主层：查抄私藏
#   查抄即撕破脸（心境 -30 + 积怨推高叛离），故用二次点击确认，避免误点。
#   全项目零 ConfirmationDialog 先例，此处不引入新组件：按钮文案切换即为确认。
func _on_查抄私藏() -> void:
	if _current_disciple == null or Game == null:
		return
	if not _查抄待确认:
		_查抄待确认 = true
		_refresh_record_page()
		return
	_查抄待确认 = false
	var 结果: Dictionary = Game.查抄弟子(_current_disciple)
	if bool(结果.get("成功", false)):
		print("[弟子详情] 查抄得手：没收 %d 件" % int(结果.get("没收", 0)))
	else:
		print("[弟子详情] 查抄未果：%s" % str(结果.get("原因", "")))
	_refresh_record_page()


func _refresh_record_page() -> void:
	if _current_disciple == null:
		return
	var d = _current_disciple
	# 基本信息
	if _record_info_grid:
		_refresh_record_info()
	# §4.0 人生目标：当前志向 + 行为倾向 + 叛离预警 + 目标栈演化史
	if _record_goal_vbox:
		for c in _record_goal_vbox.get_children():
			c.queue_free()
		var 目标名: String = Goal.弟子目标(d)
		var 目标行 := Label.new()
		目标行.text = "当前志向：%s" % 目标名
		目标行.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
		UITheme.apply_project_font(目标行, UITheme.FONT_H2, true)
		_record_goal_vbox.add_child(目标行)
		var 描述文: String = Goal.取描述(目标名)
		if 描述文 != "":
			_record_goal_vbox.add_child(_make_info_row("　", 描述文))
		var 倾向: String = Goal.行为摘要(目标名)
		if 倾向 != "":
			_record_goal_vbox.add_child(_make_info_row("行为倾向", 倾向))
		var 预警: String = Goal.叛离预警(d)
		if 预警 != "":
			_record_goal_vbox.add_child(_make_info_row("心志", 预警))
		var 执念文: String = str(_safe_get(d, "执念", ""))
		if 执念文 != "":
			_record_goal_vbox.add_child(_make_info_row("旧日执念", 执念文))
		var 栈: Array = (_safe_get(d, "目标栈", []) as Array)
		if 栈.size() > 0:
			var 史标题 := Label.new()
			史标题.text = "── 志业演变 ──"
			史标题.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
			UITheme.apply_project_font(史标题, UITheme.FONT_AUX, false)
			_record_goal_vbox.add_child(史标题)
			for 项 in 栈:
				if not (项 is Dictionary):
					continue
				var 演日: int = int(项.get("起始日", 0))
				_record_goal_vbox.add_child(_make_info_row("第%d日" % 演日, "%s　← %s" % [str(项.get("目标", "")), str(项.get("来源", ""))]))
		else:
			_record_goal_vbox.add_child(_make_info_row("志业演变", "初心未改，尚无转向"))
	# §4.0 弟子自主层：储物法宝（容积 / 私藏件数 / 瞒报次数 / 查抄积怨 / 查抄）
	if _record_storage_vbox != null:
		for c in _record_storage_vbox.get_children():
			c.queue_free()
		var 私库: Array = (_safe_get(d, "私库", []) as Array)
		var 上限: int = 20
		if d.has_method("私库容量上限"):
			上限 = int(d.私库容量上限())
		_record_storage_vbox.add_child(_make_info_row("储物容积", "%d / %d 件" % [私库.size(), 上限]))
		var 私藏次数: int = int(_safe_get(d, "私藏次数", 0))
		var 查抄积怨: int = int(_safe_get(d, "查抄积怨", 0))
		if 私库.is_empty():
			_record_storage_vbox.add_child(_make_info_row("私藏", "两袖清风，无私藏"))
		else:
			_record_storage_vbox.add_child(_make_info_row("私藏", "%d 件（品名须查抄方知）" % 私库.size()))
		if 私藏次数 > 0:
			_record_storage_vbox.add_child(_make_info_row("瞒报次数", "累计 %d 次" % 私藏次数))
		if 查抄积怨 > 0:
			_record_storage_vbox.add_child(_make_info_row("查抄积怨", "余怨未消（约 %d 月方平）" % 查抄积怨))
		var 是宗主: bool = (Game != null and Game.弟子列表.size() > 0 and Game.弟子列表[0] == d)
		if not 私库.is_empty() and str(d.状态) == "在宗" and not 是宗主:
			var 查抄_btn: Button = Button.new()
			查抄_btn.text = "查抄私藏" if not _查抄待确认 else "确认查抄？（再点一次）"
			查抄_btn.custom_minimum_size = Vector2(0, 64)
			查抄_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_secondary_button_style(查抄_btn)
			查抄_btn.pressed.connect(_on_查抄私藏)
			_record_storage_vbox.add_child(查抄_btn)
	# 社交关系
	if _record_social_grid:
		for c in _record_social_grid.get_children():
			c.queue_free()
		# §6.16 血脉共鸣：计算真实的血脉关系和加成
		var 血脉亲属数: int = d.获取在宗血脉亲属数()
		var 血脉修炼加成: float = 0.0
		var 血脉战力加成: float = 0.0
		if 血脉亲属数 > 0:
			血脉修炼加成 = min(0.003 * 血脉亲属数, 0.012)
			血脉战力加成 = min(0.003 * 血脉亲属数, 0.012)
		var 父母数: int = d.父母ID.size()
		var 子女数: int = d.子嗣列表.size()
		var 兄弟姐妹数: int = 0
		for pid in d.父母ID:
			if pid >= 0 and Game.has_method("_取弟子"):
				var 父: Object = Game._取弟子(pid)
				if 父 != null and 父 is Disciple:
					for sid in 父.子嗣列表:
						if sid != d.弟子ID and sid >= 0:
							var 兄: Object = Game._取弟子(sid)
							if 兄 != null and 兄 is Disciple and 兄.状态 == "在宗":
								兄弟姐妹数 += 1
		var 血脉卡片 = (["◇ 血脉共鸣", "%d位在宗亲属" % 血脉亲属数, "修炼+%.1f%% 道行+%.1f%%" % [血脉修炼加成 * 100, 血脉战力加成 * 100]]) if 血脉亲属数 > 0 else (["◇ 血脉共鸣", "暂无在宗亲属", "有血缘亲属同宗时自生共鸣"])
		# §6.16 家族和血脉信息
		var 家族秘宝名 = ""
		if d.家族秘宝 != "" and Game != null and Game.has_method("_家族秘宝配置"):
			var 秘宝配置 = Game._家族秘宝配置.get(d.家族秘宝, {})
			家族秘宝名 = str(秘宝配置.get("名", d.家族秘宝))
		var 家族卡片 = (["■ 家族", "%s·%s" % [d.家族名, d.家族职位], "贡献%d%s" % [d.家族贡献, ("·秘宝:"+家族秘宝名) if 家族秘宝名 != "" else ""]]) if d.家族ID != "" else (["■ 家族", "散修", "可加入修仙家族"])
		var 血脉状态 = "已觉醒·%.0f%%" % d.血脉觉醒度 if d.血脉觉醒 else "未觉醒"
		var 血脉功法数 = d.血脉功法列表.size()
		var 血脉卡片2 = (["◆ 血脉", "%s·纯度%.0f%%" % [d.血脉类型, d.血脉纯度], "%s%s" % [血脉状态, ("·血脉功法%d" % 血脉功法数) if 血脉功法数 > 0 else ""]]) if d.血脉类型 != "凡人血脉" else (["◆ 血脉", "凡人血脉", "无特殊血脉"])
		var socials = [
			["◇ 道侣", (str(d.道侣) if d.道侣 != "" else "尚无道侣"), "双修加成+%.0f%%" % (d.双修加成 * 100.0)],
			血脉卡片,
			家族卡片,
			血脉卡片2,
			["■ 家庭", "父母%d 子女%d 兄弟%d" % [父母数, 子女数, 兄弟姐妹数], "§6.16 血脉传承"],
			["○ 子嗣", "%d人" % d.子嗣列表.size(), ""],
		]
		# 拟真NPC系统：道友/好友/仇人统计
		if Game != null and Game.has_method("获取弟子关系网络"):
			var 关系网络: Dictionary = Game.获取弟子关系网络(str(d.弟子ID))
			var 道友数: int = int(关系网络.get("道友列表", []).size())
			var 好友数: int = int(关系网络.get("好友列表", []).size())
			var 仇人数: int = int(关系网络.get("仇人列表", []).size())
			socials.append(["◇ 道友", "%d人" % 道友数, "好感度≥80" if 道友数 > 0 else "尚无道友"])
			socials.append(["◆ 好友", "%d人" % 好友数, "好感度60-79" if 好友数 > 0 else "尚无好友"])
			if 仇人数 > 0:
				socials.append(["⚠ 仇人", "%d人" % 仇人数, "好感度<20，需注意"])
		for s in socials:
			var sp := PanelContainer.new()
			var ssb := StyleBoxFlat.new()
			ssb.bg_color = Color(1,1,1,0.04)
			ssb.border_color = Color(0.78,0.65,0.34,0.3)
			ssb.set_border_width_all(1)
			ssb.set_corner_radius_all(6)
			ssb.content_margin_left = 12; ssb.content_margin_right = 12
			ssb.content_margin_top = 10; ssb.content_margin_bottom = 10
			sp.add_theme_stylebox_override("panel", ssb)
			sp.custom_minimum_size = Vector2(420, 90)
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_record_social_grid.add_child(sp)
			var svb := VBoxContainer.new()
			sp.add_child(svb)
			var sn := Label.new()
			sn.text = s[0]
			sn.add_theme_color_override("font_color", Color(0.91,0.83,0.60))
			UITheme.apply_project_font(sn, UITheme.FONT_BODY, false)
			svb.add_child(sn)
			var sv := Label.new()
			sv.text = s[1]
			sv.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			UITheme.apply_project_font(sv, UITheme.FONT_BODY, false)
			svb.add_child(sv)
			# ★ 2026-09-15 修（老大：社交关系这里点不开详情）：卡片此前是纯展示面板、无命中区。
			#   现每张卡叠一层全屏透明按钮 → 点开该关系的明细（人员名单 / 数值来源 / 玩法说明）。
			var sbtn := Button.new()
			sbtn.name = "SocialBtn"
			sbtn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sbtn.flat = true
			sbtn.text = ""
			sbtn.focus_mode = Control.FOCUS_NONE
			sbtn.tooltip_text = "点开看详情"
			sbtn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			sbtn.pressed.connect(_on_社交卡_pressed.bind(str(s[0])))
			sp.add_child(sbtn)
	# 心理状态（拟真NPC系统）
	if _record_psyche_vbox:
		for c in _record_psyche_vbox.get_children():
			c.queue_free()
		if Game != null and Game.has_method("获取弟子心理状态"):
			var 心理状态: Dictionary = Game.获取弟子心理状态(str(d.弟子ID))
			var 性格: String = str(心理状态.get("性格", "未知"))
			var 情绪: String = str(心理状态.get("情绪", "平静"))
			var 最迫切需求: String = str(心理状态.get("最迫切需求", "未知"))
			var 心境: int = int(心理状态.get("心境", 0))
			var 互动计数: int = int(心理状态.get("互动计数", 0))
			# 性格情绪行
			var psyche_hb := HBoxContainer.new()
			psyche_hb.add_theme_constant_override("separation", 20)
			_record_psyche_vbox.add_child(psyche_hb)
			var 性格标签 := Label.new()
			性格标签.text = "◇ 性格：%s" % 性格
			性格标签.add_theme_color_override("font_color", Color(0.91,0.83,0.60))
			UITheme.apply_project_font(性格标签, UITheme.FONT_BODY, false)
			psyche_hb.add_child(性格标签)
			var 情绪标签 := Label.new()
			var 情绪图标: String = {"喜悦":"◇","愤怒":"◇","恐惧":"◇","悲伤":"◇","平静":"◇"}.get(情绪, "◇")
			情绪标签.text = "%s 情绪：%s" % [情绪图标, 情绪]
			情绪标签.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			UITheme.apply_project_font(情绪标签, UITheme.FONT_BODY, false)
			psyche_hb.add_child(情绪标签)
			# 需求进度条
			var 需求列表: Array = [["修炼", float(心理状态.get("需求修炼", 0))], ["社交", float(心理状态.get("需求社交", 0))], ["休息", float(心理状态.get("需求休息", 0))], ["安全", float(心理状态.get("需求安全", 0))]]
			for 需求 in 需求列表:
				var 需求名: String = str(需求[0])
				var 需求值: float = float(需求[1])
				var 需求_hb := HBoxContainer.new()
				需求_hb.add_theme_constant_override("separation", 10)
				_record_psyche_vbox.add_child(需求_hb)
				var 需求名标签 := Label.new()
				需求名标签.text = "  %s" % 需求名
				需求名标签.custom_minimum_size = Vector2(60, 0)
				需求名标签.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
				UITheme.apply_project_font(需求名标签, UITheme.FONT_AUX, false)
				需求_hb.add_child(需求名标签)
				var 需求进度 := ProgressBar.new()
				需求进度.min_value = 0
				需求进度.max_value = 100
				需求进度.value = 需求值
				需求进度.custom_minimum_size = Vector2(300, 20)
				需求进度.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var 需求颜色: Color = Color(0.3,0.7,0.3) if 需求值 > 50 else (Color(0.8,0.6,0.2) if 需求值 > 20 else Color(0.8,0.3,0.3))
				需求进度.add_theme_color_override("font_color", Color(1,1,1))
				需求进度.show_percentage = true
				需求_hb.add_child(需求进度)
			# 最迫切需求和心境
			var info_hb := HBoxContainer.new()
			info_hb.add_theme_constant_override("separation", 20)
			_record_psyche_vbox.add_child(info_hb)
			var 需求标签 := Label.new()
			需求标签.text = "◆ 最迫切：%s" % 最迫切需求
			需求标签.add_theme_color_override("font_color", Color(0.95,0.7,0.4))
			UITheme.apply_project_font(需求标签, UITheme.FONT_BODY, false)
			info_hb.add_child(需求标签)
			var 心境标签 := Label.new()
			心境标签.text = "◇ 心境：%d" % 心境
			心境标签.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			UITheme.apply_project_font(心境标签, UITheme.FONT_BODY, false)
			info_hb.add_child(心境标签)
			var 互动标签 := Label.new()
			互动标签.text = "◇ 互动：%d次" % 互动计数
			互动标签.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			UITheme.apply_project_font(互动标签, UITheme.FONT_BODY, false)
			info_hb.add_child(互动标签)
	# 互动历史（拟真NPC系统）
	if _record_interaction_vbox:
		for c in _record_interaction_vbox.get_children():
			c.queue_free()
		if Game != null and Game.has_method("获取弟子互动历史"):
			var 互动历史: Array = Game.获取弟子互动历史(str(d.弟子ID))
			if 互动历史.size() == 0:
				var empty := Label.new()
				empty.text = "  尚无互动记录"
				empty.add_theme_color_override("font_color", Color(0.5,0.55,0.6))
				UITheme.apply_project_font(empty, UITheme.FONT_AUX, false)
				_record_interaction_vbox.add_child(empty)
			else:
				for 互动 in 互动历史:
					var 对象名: String = str(互动.get("对象名", "未知"))
					var 类型: String = str(互动.get("类型", "中性"))
					var 内容: String = str(互动.get("内容", ""))
					var 好感影响: int = int(互动.get("好感度影响", 0))
					var 互动_hb := HBoxContainer.new()
					互动_hb.add_theme_constant_override("separation", 10)
					_record_interaction_vbox.add_child(互动_hb)
					var 类型图标: String = {"正面":"◆","负面":"◆","中性":"◇"}.get(类型, "◇")
					var 类型标签 := Label.new()
					类型标签.text = "  %s" % 类型图标
					类型标签.custom_minimum_size = Vector2(40, 0)
					UITheme.apply_project_font(类型标签, UITheme.FONT_AUX, false)
					互动_hb.add_child(类型标签)
					var 内容标签 := Label.new()
					内容标签.text = 内容
					内容标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var 内容颜色: Color = Color(0.7,0.9,0.7) if 类型 == "正面" else (Color(0.9,0.6,0.6) if 类型 == "负面" else Color(0.85,0.88,0.90))
					内容标签.add_theme_color_override("font_color", 内容颜色)
					UITheme.apply_project_font(内容标签, UITheme.FONT_BODY, false)
					互动_hb.add_child(内容标签)
					if 好感影响 != 0:
						var 好感标签 := Label.new()
						好感标签.text = "%s%d" % ["+" if 好感影响 > 0 else "", 好感影响]
						好感标签.custom_minimum_size = Vector2(50, 0)
						好感标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
						好感标签.add_theme_color_override("font_color", Color(0.5,0.8,0.5) if 好感影响 > 0 else Color(0.9,0.5,0.5))
						UITheme.apply_project_font(好感标签, UITheme.FONT_BODY, false)
						互动_hb.add_child(好感标签)
	# 羁绊
	if _record_bond_list:
		_refresh_bonds()
	# 称号
	if _record_title_text and _current_disciple:
		var 当前称号: String = d.当前称号 if "当前称号" in d else ""
		if 当前称号 != "" and Game != null:
			var t: Dictionary = Game.获取称号详情(当前称号)
			if not t.is_empty():
				_record_title_text.text = str(t.get("title_name", ""))
				var 品质: String = str(t.get("quality", "凡品"))
				_record_title_text.add_theme_color_override("font_color", Game.获取称号品质颜色(品质))
				var 加成类型: String = str(t.get("bonus_type", ""))
				var 加成值: float = float(t.get("bonus_value", 0))
				var 加成文本: String = ""
				match 加成类型:
					"战力": 加成文本 = "道行+%d" % int(加成值)
					"修炼速度": 加成文本 = "修炼速度+%.0f%%" % (加成值 * 100)
					"突破率": 加成文本 = "突破率+%.0f%%" % (加成值 * 100)
					"悟道": 加成文本 = "悟道+%d" % int(加成值)
					"全属性": 加成文本 = "全属性+%.0f%%" % (加成值 * 100)
				_record_title_desc.text = "%s [%s] %s" % [str(t.get("description", "")), 品质, 加成文本]
			else:
				_record_title_text.text = "尚无称号"
				_record_title_desc.text = "修为达标、宗门任职、技艺精进皆可得道号尊称"
		else:
			_record_title_text.text = "尚无称号"
			_record_title_desc.text = "修为达标、宗门任职、技艺精进皆可得道号尊称"
	# 已获得称号列表
	if _record_title_list and _current_disciple:
		for c in _record_title_list.get_children():
			c.queue_free()
		var 已获得: Array = d.已获得称号 if "已获得称号" in d else []
		if 已获得.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "尚未获得任何道号尊称"
			empty_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
			_record_title_list.add_child(empty_lbl)
		else:
			for tid in 已获得:
				if Game == null:
					continue
				var t: Dictionary = Game.获取称号详情(str(tid))
				if t.is_empty():
					continue
				var hb := HBoxContainer.new()
				hb.add_theme_constant_override("separation", 8)
				var name_lbl := Label.new()
				name_lbl.text = str(t.get("title_name", ""))
				var 品质: String = str(t.get("quality", "凡品"))
				name_lbl.add_theme_color_override("font_color", Game.获取称号品质颜色(品质))
				name_lbl.custom_minimum_size = Vector2(120, 0)
				hb.add_child(name_lbl)
				var desc_lbl := Label.new()
				desc_lbl.text = str(t.get("description", ""))
				desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
				desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hb.add_child(desc_lbl)
				# 装备按钮
				if str(tid) != str(d.当前称号 if "当前称号" in d else ""):
					var equip_btn := Button.new()
					equip_btn.text = "装备"
					equip_btn.custom_minimum_size = Vector2(60, 28)
					equip_btn.pressed.connect(func(): _装备称号(str(tid)))
					hb.add_child(equip_btn)
				else:
					var equipped_lbl := Label.new()
					equipped_lbl.text = "[已装备]"
					equipped_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
					hb.add_child(equipped_lbl)
				_record_title_list.add_child(hb)
	# 成就网格
	if _record_achievement_grid:
		for c in _record_achievement_grid.get_children():
			c.queue_free()
		var achs = ["首突破","百历练","结灵契","筑基期","金丹期","亲传弟","长老位","宗门履","满月期","亲传","长老位","宗门履"]
		var ach_title = _record_achievement_grid.get_parent().get_parent().get_node_or_null("AchTitle")
		if ach_title:
			ach_title.text = "◆ 宗门成就    3/" + str(achs.size())
		for i in range(12):
			var ap := PanelContainer.new()
			var asb := StyleBoxFlat.new()
			var unlocked: bool = i < 3
			asb.bg_color = Color(0.95,0.80,0.30, 0.12 if unlocked else 0.02)
			asb.border_color = Color(0.78,0.65,0.34, 0.5 if unlocked else 0.1)
			asb.set_border_width_all(1)
			asb.set_corner_radius_all(6)
			ap.add_theme_stylebox_override("panel", asb)
			ap.custom_minimum_size = Vector2(200, 130)
			ap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_record_achievement_grid.add_child(ap)
			var avb := VBoxContainer.new()
			avb.alignment = BoxContainer.ALIGNMENT_CENTER
			ap.add_child(avb)
			var aicon := Label.new()
			aicon.text = "★" if unlocked else "？"
			aicon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UITheme.apply_project_font(aicon, UITheme.FONT_H1, true)
			aicon.modulate = Color(1,1,1) if unlocked else Color(0.3,0.3,0.3)
			avb.add_child(aicon)
			var aname := Label.new()
			aname.text = achs[i] if unlocked else "未解锁"
			aname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			aname.add_theme_color_override("font_color", Color(0.91,0.83,0.60) if unlocked else Color(0.35,0.38,0.4))
			UITheme.apply_project_font(aname, UITheme.FONT_BODY, false)
			avb.add_child(aname)
	# 历练时间线
	if _record_timeline:
		for c in _record_timeline.get_children():
			c.queue_free()
		var events = d.履历 if "履历" in d else []
		if events.is_empty():
			var empty := Label.new()
			empty.text = "尚无历练记录"
			empty.add_theme_color_override("font_color", Color(0.45,0.50,0.52))
			_record_timeline.add_child(empty)
		else:
			var count: int = min(events.size(), 20)
			for i in range(count - 1, -1, -1):
				var row := HBoxContainer.new()
				var dot := Label.new()
				dot.text = "●"
				dot.add_theme_color_override("font_color", Color(0.95,0.80,0.30))
				UITheme.apply_project_font(dot, UITheme.FONT_AUX, false)
				dot.custom_minimum_size = Vector2(30, 0)
				row.add_child(dot)
				var evl := Label.new()
				evl.text = _格式化履历(events[i])
				evl.add_theme_color_override("font_color", Color(0.75,0.80,0.82))
				UITheme.apply_project_font(evl, UITheme.FONT_BODY, false)
				evl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				evl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				row.add_child(evl)
				_record_timeline.add_child(row)

# 履历条目形态不统一（纯串 / {日,事件,详情} / {时间,事件,类型}），此处统一为可读文本；
# 旧写法 left(60) 会腰斩长文案，改由 AUTOWRAP 自然折行。
func _格式化履历(ev: Variant) -> String:
	if typeof(ev) != TYPE_DICTIONARY:
		return str(ev)
	var rec: Dictionary = ev
	var 日: int = int(rec.get("日", rec.get("时间", 0)))
	var 主: String = str(rec.get("事件", rec.get("desc", "")))
	var 详: String = str(rec.get("详情", rec.get("类型", "")))
	var 头: String = ("第%d日 · " % 日) if 日 > 0 else ""
	if 主 == "":
		主 = 详
		详 = ""
	if 详 != "" and 详 != 主:
		return "%s%s（%s）" % [头, 主, 详]
	return "%s%s" % [头, 主]

func _make_info_row(name: String, value: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.custom_minimum_size = Vector2(420, 0)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := Label.new()
	nl.text = name
	nl.add_theme_color_override("font_color", Color(0.54,0.61,0.66))
	UITheme.apply_project_font(nl, UITheme.FONT_BODY, false)
	nl.custom_minimum_size = Vector2(140, 0)
	hb.add_child(nl)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_color_override("font_color", Color(0.91,0.83,0.60))
	UITheme.apply_project_font(vl, UITheme.FONT_BODY, false)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vl)
	return hb

func _refresh_power_summary() -> void:
	if _current_disciple == null:
		return
	var 装备 = _safe_get(_current_disciple, "装备", {})
	if typeof(装备) != TYPE_DICTIONARY:
		装备 = {}
	var count = 装备.size()
	var total_bonus = 0
	for key in 装备:
		var it = 装备[key]
		if it != null and typeof(it) == TYPE_OBJECT:
			total_bonus += int(it.战力加成)
		elif it != null and typeof(it) == TYPE_DICTIONARY:
			total_bonus += int(it.get("战力加成", 0))
	if _power_count:
		_power_count.text = "%d/9" % count
	if _power_bonus:
		_power_bonus.text = "+%d" % total_bonus
	if _power_total:
		# 直接显示弟子的战力属性（已包含装备贡献）
		var 弟子战力 = _safe_get(_current_disciple, "战力", 100)
		_power_total.text = str(int(弟子战力))


# ───────── 刷新装备详情面板 ─────────
func _refresh_equip_detail() -> void:
	if _current_disciple == null or _selected_equip_slot == "":
		_equip_detail_name.text = "未选择装备"
		_equip_detail_power.text = "道行 —"
		_equip_detail_desc.text = "轻点器物格，可观其详"
		_btn_unequip.disabled = true
		# 清空词缀（先获取子节点列表的副本，避免遍历同时修改）
		var affixes_children = _equip_detail_affixes.get_children().duplicate()
		for child in affixes_children:
			_equip_detail_affixes.remove_child(child)
			child.queue_free()
		return

	var 装备 = _safe_get(_current_disciple, "装备", {})
	if typeof(装备) != TYPE_DICTIONARY:
		装备 = {}
	var item = 装备.get(_selected_equip_slot, null)

	if item == null:
		var slot_def = _find_slot_def(_selected_equip_slot)
		var slot_name = slot_def.get("name", "未知槽位") if slot_def != {} else "未知槽位"
		_equip_detail_name.text = slot_name + "（空）"
		_equip_detail_power.text = "道行 —"
		_equip_detail_desc.text = "此槽位尚未装备物品"
		_btn_unequip.disabled = true
	else:
		# 兼容Item对象和Dictionary
		var is_obj = typeof(item) == TYPE_OBJECT
		var 名称 = str(item.名称) if is_obj else str(item.get("名称", "未知装备"))
		var 品阶 = str(item.品阶) if is_obj else str(item.get("品阶", "凡阶"))
		var 战力加成 = int(item.战力加成) if is_obj else int(item.get("战力加成", 0))
		var quality_color = _get_quality_color(品阶)

		_equip_detail_name.text = 名称 + "  [" + 品阶 + "]"
		_equip_detail_name.add_theme_color_override("font_color", quality_color)
		_equip_detail_power.text = "道行加成 +%d" % 战力加成
		_equip_detail_desc.text = "装备部位：%s" % _find_slot_def(_selected_equip_slot).get("name", "")
		_btn_unequip.disabled = false

	# 清空词缀
	for child in _equip_detail_affixes.get_children():
		_equip_detail_affixes.remove_child(child)
		child.queue_free()

	# 更新套装进度
	for child in _equip_set_panel.get_children():
		_equip_set_panel.remove_child(child)
		child.queue_free()
	if _current_disciple != null:
		var 套装列表 = _current_disciple.获取套装进度()
		if 套装列表.size() > 0:
			var set_title := Label.new()
			set_title.text = "◆ 套装共鸣"
			set_title.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
			UITheme.apply_project_font(set_title, UITheme.FONT_BODY, true)
			_equip_set_panel.add_child(set_title)
			for 套装 in 套装列表:
				var set_lbl := Label.new()
				var 数量 = 套装["数量"]
				var 效果文本 = ""
				if 数量 >= 5:
					效果文本 = "五宝相契：" + str(套装["5件效果"])
				elif 数量 >= 3:
					效果文本 = "三宝相契：" + str(套装["3件效果"]) + " ｜ 五宝：" + str(套装["5件效果"])
				elif 数量 >= 2:
					效果文本 = "二宝相生：" + str(套装["2件效果"]) + " ｜ 三宝：" + str(套装["3件效果"])
				else:
					效果文本 = "二宝相生：" + str(套装["2件效果"])
				set_lbl.text = "%s (%d/5件) %s" % [str(套装["名称"]), 数量, 效果文本]
				set_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
				UITheme.apply_project_font(set_lbl, UITheme.FONT_BODY, false)
				set_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_equip_set_panel.add_child(set_lbl)

	# S43 装备词条（锻造产出具名特效：战力/修炼/突破）
	if item != null:
		var is_obj = typeof(item) == TYPE_OBJECT
		var 词列 = []
		if is_obj:
			词列 = item.装备词条
		elif typeof(item) == TYPE_DICTIONARY:
			词列 = item.get("装备词条", [])
		if 词列 is Array and 词列.size() > 0:
			var 词标 := Label.new()
			词标.text = "◆ 装备词条"
			词标.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
			UITheme.apply_project_font(词标, UITheme.FONT_BODY, true)
			_equip_detail_affixes.add_child(词标)
			for t in 词列:
				var 类型名 = {"战力":"道行", "修炼":"修炼", "突破":"突破"}.get(t.get("类型",""), str(t.get("类型","")))
				var 值文本 = ""
				if t.get("类型") == "战力":
					值文本 = "+%d道行" % int(t.get("数值", 0))
				elif t.get("类型") == "修炼":
					值文本 = "+%.0f%%修炼" % (float(t.get("数值", 0)) * 100)
				else:
					值文本 = "+%.0f%%突破" % (float(t.get("数值", 0)) * 100)
				var 行 := Label.new()
				行.text = "  %s·%s %s" % [类型名, t.get("中文名", ""), 值文本]
				行.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
				UITheme.apply_project_font(行, UITheme.FONT_BODY, false)
				行.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_equip_detail_affixes.add_child(行)

	# 刷新战力摘要
	_refresh_power_summary()


func _make_equip_slot(index: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	# vb 横满：5 个均分 panel 宽（间距由 _equip_box separation 控）
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	var slot := PanelContainer.new()
	# 装备/灵兽槽：40dp×40dp（×UI_SCALE=2.25→90×90 实际像素），正方形不许拉伸
	slot.custom_minimum_size = Vector2(int(round(40 * UITheme.UI_SCALE)), int(round(40 * UITheme.UI_SCALE)))
	# slot 在 vb 内只占自己 90×90 不被 vb 横向 FILL 拉成长方形，居中显示
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.4)
	sb.border_color = Color(0.83, 0.69, 0.21, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(round(8 * UITheme.UI_SCALE)))
	slot.add_theme_stylebox_override("panel", sb)
	var icon := Label.new()
	icon.text = "?"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66, 0.5))
	slot.add_child(icon)
	vb.add_child(slot)
	var name_lbl: Label = Label.new()
	var slot_names: Array = ["法兵", "道冠", "法袍", "灵饰", "灵兽"]
	name_lbl.text = slot_names[index] if index < slot_names.size() else "—"
	name_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	# 槽位名字号走 UITheme.FONT_AUX 单一来源（21px）。原写法 8*UI_SCALE=18px 低于项目最小字号档，
	# 实机 1080 宽下两个汉字只有 18px 高，视觉上就像被切掉/糊掉，是「文字看不全」的次因。
	UITheme.apply_project_font(name_lbl, UITheme.FONT_AUX, false)
	# ④ 修复 文字与框体不对齐：
	# 原先 name_lbl 未设 size_flags / horizontal_alignment，Label 默认 SIZE_FILL 撑满 vb 整列宽，
	# 而文本默认 HORIZONTAL_ALIGNMENT_LEFT → 文字贴列左边，上方槽框是 SIZE_SHRINK_CENTER 居中 → 两者错轴。
	# 修法：Label 显式占满整列宽 + 文本水平居中，与 90×90 槽框共用同一列中心线。
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 单行不裁切：列宽 ≈ (1080-24 面板内边距-4×6 间距)/5 ≈ 206px，两个汉字 42px 富余充足
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = false
	vb.add_child(name_lbl)
	return vb


func set_disciple(d: Disciple) -> void:
	_current_disciple = d
	_查抄待确认 = false   # §4.0 切换弟子即重置查抄确认态
	_驱逐待确认 = false   # 2026-09-14：驱逐的二次确认态同样随切人复位（防误点错人）
	if d == null:
		print("[弟子详情] set_disciple: d is null")
		return
	print("[弟子详情] set_disciple: 姓名=", d.姓名, " 立绘类型=", d.立绘类型, " 性别=", d.性别)
	# 名字
	_info_name.text = str(d.姓名)
	# 境界
	_info_realm.text = str(d.境界)
	# 身份
	_info_identity.text = str(d.身份)
	# 品质（资质存的是拼音，转中文显示）
	var 资质拼音 = str(d.资质)
	var 资质中文 = _资质显示.get(资质拼音, 资质拼音)
	_info_quality.text = 资质中文
	var 品质色 = _品质颜色(资质拼音)
	_info_quality.add_theme_color_override("font_color", 品质色)
	# 特殊体质标签
	if d.体质觉醒 and d.特殊体质 != "凡体":
		_info_constitution.text = str(d.特殊体质)
		_info_constitution.visible = true
		# 稀有度颜色
		var 体质稀有度: String = str(Disciple.特殊体质表.get(d.特殊体质, {}).get("稀有度", "普通"))
		match 体质稀有度:
			"极稀有":
				_info_constitution.add_theme_color_override("font_color", Color(0.95, 0.30, 0.30))
			"稀有":
				_info_constitution.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20))
			_:
				_info_constitution.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80))
	else:
		_info_constitution.visible = false
	# 高阶修士标签（神魂/法相/领域）
	var 高阶文本: String = ""
	if d.神魂等级 > 0:
		高阶文本 += "神魂%d " % d.神魂等级
	if d.法相等级 > 0:
		高阶文本 += "%s%d " % [str(d.法相名称), d.法相等级]
	if d.领域等级 > 0:
		高阶文本 += "%s%d " % [str(d.领域名称), d.领域等级]
	if 高阶文本 != "":
		_info_advanced.text = 高阶文本.strip_edges()
		_info_advanced.visible = true
	else:
		_info_advanced.visible = false
	# 名字+境界移到战力行
	if _power_name != null:
		_power_name.text = str(d.姓名)
	if _power_realm != null:
		_power_realm.text = str(d.境界) + " · " + str(d.身份) + " · " + 资质中文 + " · " + str(int(d.年龄)) + "岁"
	# 隐藏hero区域旧名字
	_info_name.visible = false
	_info_realm.visible = false
	_info_identity.visible = false
	_info_quality.visible = false
	_info_constitution.visible = false
	_info_advanced.visible = false
	# 战力
	_power_label.text = str(d.战力)
	if _power_summary != null:
		var 法器数: int = d.装备.size() if d.装备 is Dictionary else 0
		var 历练数: int = d.履历.size() if "履历" in d else 0
		# 2026-09-14：不再重复「身份」（已在上行 _power_realm 的「境界 · 身份 · 资质 · 年龄」里），
		#   缩短后确保整行不超出屏宽。
		_power_summary.text = "历练%d次 · 法器%d件" % [历练数, 法器数]
	# 四维属性（自绘视觉条：bar=ColorRect，按 val% 算 width）
	if d.属性 is Dictionary:
		for attr_name in ["攻", "防", "血", "速"]:
			var val = d.属性.get(attr_name, 0)
			var entry = _attr_bars.get(attr_name, null)
			if entry != null:
				entry["val"].text = str(val)
				# bar=ColorRect：宽度按 (val/100) * track 宽 计算，deferred 到 layout 后
				var ratio: float = clampf(float(val) / 100.0, 0.0, 1.0)
				_set_attr_fill_width(entry, ratio)
		# 六维属性+雷达图
		var radar_vals: Array = []
		if d.属性 is Dictionary:
			for dim in ["体魂","根骨","悟性","机缘","心性","气运"]:
				var dv: int = int(d.属性.get(dim, 500))
				if _six_labels.has(dim):
					_six_labels[dim].text = str(dv)
				radar_vals.append(clampf(float(dv) / 1000.0, 0.05, 1.0))
		if _radar != null and radar_vals.size() == 6:
			_radar.set_values(radar_vals)
		# 战力构成
		var base_power: int = 0
		var equip_power: int = 0
		if d.属性 is Dictionary:
			base_power = int(d.属性.get("攻",0)) + int(d.属性.get("防",0)) + int(d.属性.get("血",0)) + int(d.属性.get("速",0))
		if d.装备 is Dictionary:
			for slot in d.装备.keys():
				var it = d.装备[slot]
				if it == null:
					continue
				if typeof(it) == TYPE_OBJECT:
					equip_power += int(it.战力加成)
				elif typeof(it) == TYPE_DICTIONARY:
					equip_power += int(it.get("战力加成", 0))
		var beast_power: int = 0
		if d.主宠灵兽 != null and typeof(d.主宠灵兽) == TYPE_OBJECT:
			beast_power = int(d.主宠灵兽.战力加成) if "战力加成" in d.主宠灵兽 else 0
		var gongfa_power: int = int(d.战力 - base_power - equip_power - beast_power)
		var max_comp: float = float(max(base_power, equip_power, beast_power, max(gongfa_power, 1)))
		for comp_name in ["基础属性","装备加成","灵兽加成","功法加成"]:
			if not _power_bars.has(comp_name):
				continue
			var entry2: Dictionary = _power_bars[comp_name]
			var cv: int = 0
			match comp_name:
				"基础属性": cv = base_power
				"装备加成": cv = equip_power
				"灵兽加成": cv = beast_power
				"功法加成": cv = max(gongfa_power, 0)
			entry2["label"].text = str(cv)
			var ratio2: float = clampf(float(cv) / max_comp, 0.0, 1.0) if max_comp > 0 else 0.0
			var bar2: ColorRect = entry2["bar"]
			bar2.offset_right = int(200 * ratio2)
		# 突破进度
		if _breakthrough_label != null:
			_breakthrough_label.text = str(d.境界) + "·" + _层数中文(int(d.层数))
		if _breakthrough_bar != null:
			var prog: float = clampf(float(d.修炼进度), 0.0, 1.0)
			_breakthrough_bar.offset_right = int(400 * prog)
		if _breakthrough_pct != null:
			_breakthrough_pct.text = str(int(d.修炼进度 * 100)) + "%  →  " + str(d.境界) + "·" + _层数中文(min(int(d.层数) + 1, 10))
		# 当前状态（命牌：只表示生死二态；状态栏文字显示具体活动：历练/闭关/秘境/失踪/在宗）
		if _status_label != null and _status_icon != null:
			var 状态v: String = _取显示状态(d)
			var 已陨落: bool = (状态v == "陨落")
			_refresh_命牌(已陨落)
			if 已陨落:
				_status_label.text = "已陨落（命牌灭）"
			else:
				match 状态v:
					"历练中":
						_status_label.text = "历练中"
					"失踪":
						_status_label.text = "失踪 · 下落不明"
					"闭关":
						_status_label.text = "闭关修炼中"
					"秘境":
						_status_label.text = "秘境探索中"
					_:
						if d.突破冷却剩余 > 0:
							_status_label.text = "在宗 · 突破气机未复"
						elif d.稳固期剩余 > 0:
							_status_label.text = "在宗 · 境界稳固中"
						else:
							_status_label.text = "在宗"
	# 命格（先查 DestinyDataLoader 拿中文名称，回落 destiny_id 避免显示原始 key）
	var destiny_id = str(d.destiny_id)
	var lbl = _destiny_label.find_child("DescLabel", true, false)
	if lbl != null:
		if destiny_id != "":
			var dt: Dictionary = DestinyLoader.get_destiny(destiny_id)
			if dt is Dictionary and not dt.is_empty():
				lbl.text = str(dt.get("名称", destiny_id))
			else:
				lbl.text = destiny_id
		else:
			lbl.text = "—"
	# 性格 + 气质（F项：详情页显示气质，12修仙性格→6型气质）
	var lbl2 = _personality_label.find_child("DescLabel", true, false)
	if lbl2 != null:
		var 气质: String = d.获取气质() if d.has_method("获取气质") else "沉稳"
		lbl2.text = "%s\n气质：%s" % [str(d.性格), 气质]
		lbl2.autowrap_mode = TextServer.AUTOWRAP_WORD
	# 道途
	var 道途 = str(d.道途)
	var lbl3 = _daotu_label.find_child("DescLabel", true, false)
	if lbl3 != null:
		lbl3.text = 道途 if 道途 != "" else "未入门"
	# 心境
	var lbl_xj = _xinjing_label.find_child("DescLabel", true, false) if _xinjing_label != null else null
	if lbl_xj != null:
		lbl_xj.text = "%d" % int(d.心境)
	# 道心
	var lbl_dx = _daoxin_label.find_child("DescLabel", true, false) if _daoxin_label != null else null
	if lbl_dx != null:
		lbl_dx.text = "%d" % int(d.道心)
	# 心魔
	var lbl_xm = _xinmo_label.find_child("DescLabel", true, false) if _xinmo_label != null else null
	if lbl_xm != null:
		var 心魔值 = int(d.心魔值)
		if 心魔值 >= 90:
			lbl_xm.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		elif 心魔值 >= 60:
			lbl_xm.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
		elif 心魔值 >= 30:
			lbl_xm.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		lbl_xm.text = "%d" % 心魔值
	# 护道人信息（P0新增）
	if _护道人_label != null and is_instance_valid(Game):
		if Game.护道人列表.has(d.弟子ID):
			var 护道人: Dictionary = Game.护道人列表[d.弟子ID]
			var 剩余天数: int = max(0, int(护道人.get("到期日", 0)) - Game.累计游戏日)
			_护道人_label.text = "护道人：%s（%s，功德%d，剩余%d日）" % [
				str(护道人.get("护道人姓名", "")),
				str(护道人.get("护道人等级", "")),
				int(护道人.get("功德", 0)),
				剩余天数
			]
			_护道人_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		else:
			var 需求: String = Game.检查护道人需求(d)
			if 需求 != "":
				_护道人_label.text = "护道人：无（%s，建议配备）" % 需求
				_护道人_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
			else:
				_护道人_label.text = "护道人：无"
				_护道人_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	# 忠诚（S30）
	var lbl_zl = _忠诚_label.find_child("DescLabel", true, false) if _忠诚_label != null else null
	if lbl_zl != null:
		lbl_zl.text = "%d" % int(d.忠诚)
	# 欠俸（S30）
	var lbl_qf = _欠俸_label.find_child("DescLabel", true, false) if _欠俸_label != null else null
	if lbl_qf != null:
		var 欠: int = int(d.欠俸月数)
		lbl_qf.text = ("%d月" % 欠) if 欠 > 0 else "无"
		if 欠 > 0:
			lbl_qf.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		else:
			lbl_qf.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	# 更新互动按钮显示
	if Game != null:
		var 弟子ID = int(d.弟子ID)
		for 互动类型 in _hudong_buttons.keys():
			var btn = _hudong_buttons[互动类型]
			if btn != null:
				var 剩余次数 = Game.获取互动剩余次数(弟子ID, 互动类型)
				var 配置 = Game.互动配置.get(互动类型, {})
				var 消耗文本 = ""
				if 配置.has("消耗灵气"):
					消耗文本 = "（灵气%d）" % 配置["消耗灵气"]
				elif 配置.has("消耗悟道点"):
					消耗文本 = "（悟道点%d）" % 配置["消耗悟道点"]
				btn.text = "%s%s 剩余%d次" % [互动类型, 消耗文本, 剩余次数]
				btn.disabled = 剩余次数 <= 0
	# 已学功法
	if _gongfa_list_label != null:
		var 已学 = _safe_get(d, "已学功法", [])
		if 已学 == null or 已学.size() == 0:
			_gongfa_list_label.text = "尚无功法，静待机缘"
		else:
			var 功法名列表: Array = []
			for gid in 已学:
				var 功法 = GongFaSystem.功法库.get(gid, {})
				功法名列表.append(str(功法.get("名称", gid)))
			_gongfa_list_label.text = "已学%d部：%s" % [已学.size(), "、".join(功法名列表)]
			# S41 已学功法附词条
			var _词条本 = _safe_get(d, "功法词条", {})
			if typeof(_词条本) == TYPE_DICTIONARY:
				for _gid in 已学:
					if _词条本.has(_gid) and _词条本[_gid].size() > 0:
						var _功名: String = str(GongFaSystem.功法库.get(_gid, {}).get("名称", _gid))
						var _词串: String = ""
						for _条 in _词条本[_gid]:
							_词串 += "%s·" % str(_条["中文名"])
						_gongfa_list_label.text += "\n  %s：%s" % [_功名, _词串.trim_suffix("·")]
	# ★ 2026-09-14 删：原「学习功法」按钮已去（功法随师承与机缘自动习得）。
	#   旧版靠 `_gongfa_list_label.get_parent().get_children()[-1]` 反查那颗按钮来改文案，
	#   属「按子节点序位硬猜」的脆弱写法；按钮既去，这段一并删除。
	# 丹药显示（★2026-09-15 改口径：弟子**自身携带**的丹药＝背包（随身公开）+ 私库（背地私藏））
	#   旧版数的是 `Game.宗门库房`（全宗门公库）—— 既非此人的东西，且类别常量实为拼音码 `dan_yao`，
	#   旧写中文「丹药」永不命中 ⇒ 恒显示 0 颗（静默错数）。现按弟子自己的两本账统计：
	#   背包＝随身公开持有（列品名，玩家可见可管）；私库＝储物法宝内的私藏（只报件数，须「查抄」方知品名）。
	if _danyao_list_label != null and d is Disciple:
		var 随身: Array = []
		if d.背包 != null:
			for it in d.背包:
				if it == null or typeof(it) != TYPE_OBJECT:
					continue
				if str(it.类别) == "dan_yao":
					随身.append(str(it.简称))
		var 私藏数: int = 0
		if d.私库 != null:
			for it in d.私库:
				if it == null or typeof(it) != TYPE_OBJECT:
					continue
				if str(it.类别) == "dan_yao":
					私藏数 += 1
		if 随身.is_empty() and 私藏数 == 0:
			_danyao_list_label.text = "随身丹药：无"
		else:
			var 丹文本: String = "随身丹药：%d颗" % 随身.size()
			if not 随身.is_empty():
				丹文本 += "（%s）" % "、".join(随身)
			if 私藏数 > 0:
				丹文本 += "\n私藏：%d颗（未报，须查抄方知）" % 私藏数
			_danyao_list_label.text = 丹文本
	# 立绘（直接调用方法，不依赖 has_method 判断）
	var 路径 = d.取立绘路径("stand")
	print("[弟子详情] 立绘路径=", 路径)
	var tex = _load_texture_safe(路径)
	# 精英版加载失败时自动fallback到普通版
	if tex == null and (路径.contains("_elite") or 路径.contains("_top")):
		var 普通路径: String = 路径.replace("_elite.png", ".png").replace("_top.png", ".png")
		print("[弟子详情] 高阶立绘加载失败, fallback到普通版: ", 普通路径)
		tex = _load_texture_safe(普通路径)
	if tex != null:
		print("[弟子详情] 立绘加载成功, size=", tex.get_width(), "x", tex.get_height())
		_portrait.texture = tex
		call_deferred("_apply_portrait_cover")
	else:
		print("[弟子详情] 立绘加载失败, tex=null")

	# 刷新纸娃娃系统的弟子立绘
	if _paper_doll_portrait != null:
		_paper_doll_portrait.texture = tex

	# 刷新装备槽位和详情
	_selected_equip_slot = ""
	_refresh_equip_slots()
	_refresh_equip_detail()
	_refresh_护身符_section()
	_refresh_休闲设置_section()
	_refresh_oath_box(d)        # S36 心魔誓（2026-09-14 改：只读状态）
	_刷新互动区(d)               # 2026-09-14：互动培养按「当下情境」触发/隐藏
	_刷新灵泉状态()              # 2026-09-15：洗池·灵泉天时（十二载一开）
	_刷新驱逐门禁(d)             # 2026-09-15：驱逐按钮平时锁死，唯重罪解禁
	_close_portrait_fullview()  # 切弟子即收起「看全图」浮层，避免残留上一人的整图


# ───────── 命牌牌位刷新（生／殁二态）─────────
# 旧版用位图命魂灯（soul_lamp_*.png）：实测 128²、全图 alpha=255、四角近白，
# 灯身 ivory 亮度与近白底色同区间 ⇒ 区域生长抠底会把灯座一并啃空（源图缺陷，非工程可修）。
# 故改**矢量命牌**：金描边小牌 + 「生／殁」镌字，风格与全项目图标统一（老大 2026-09-15 定）。
func _refresh_命牌(已陨落: bool) -> void:
	if _status_glyph != null and is_instance_valid(_status_glyph):
		_status_glyph.text = 命牌_殁 if 已陨落 else 命牌_生
		_status_glyph.add_theme_color_override("font_color",
			UITheme.COLOR_TEXT_RED if 已陨落 else UITheme.获取暗金正文())
	if _status_icon != null and is_instance_valid(_status_icon):
		var 牌框: StyleBoxFlat = _status_icon.get_theme_stylebox("panel") as StyleBoxFlat
		if 牌框 != null:
			牌框.border_color = UITheme.COLOR_TEXT_RED if 已陨落 else UITheme.获取金色描边()


# ───────── 洗池 · 灵泉状态行（十二载一开、开则三十日）─────────
# 与月课 `Game._月课_洗池灵泉()` 共用同一真源 `XiChiSystem.灵泉开启信息()`，避免 UI 与结算口径分叉。
func _刷新灵泉状态() -> void:
	if _lingquan_label == null or not is_instance_valid(_lingquan_label):
		return
	if Game == null:
		_lingquan_label.text = "灵泉：—"
		return
	var 泉: Dictionary = XiChiSystem.灵泉开启信息(Game.累计游戏日)
	var 池级: int = 1
	if Game.司职列表.has("xichi"):
		var 池: Variant = Game.司职列表["xichi"]
		if 池 is Dictionary:
			池级 = int((池 as Dictionary).get("等级", 1))
	if bool(泉.get("开启", false)):
		_lingquan_label.text = "灵泉已开 · 余%d日（本轮）：弟子可自以功勋%d叩请入池洗髓（池级%d，本轮每人限一次）。" % [
			int(泉.get("剩余日", 0)), int(XiChiSystem.自费洗髓耗功勋), 池级]
		_lingquan_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	else:
		_lingquan_label.text = "灵泉未开 · 尚需%d日复涌（十二载一开、开则三十日）：宗门强开灵泉须宗主耗仙玉。" % int(泉.get("剩余日", 0))
		_lingquan_label.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)


# ───────── 驱逐门禁：平时锁死，唯身负「重罪」方解禁 ─────────
# 真源：`SectManager.获取待裁决违规()`（由 `game_state` 月度戒律事件 `SectManager.上报违规()` 写入；
#   违规类型表含 残害同门／监守自盗（严重度 5，处罚含「逐出宗门」）等高severity项）。
# 判定：「处罚含逐出宗门」或「严重度 >= 5」——只有犯下大错者，宗主方能依门规逐出。
func _弟子重罪信息(d: Object) -> Dictionary:
	if d == null or Game == null or not (d is Disciple):
		return {}
	if SectManager == null:
		return {}
	var 该弟子ID: int = int((d as Disciple).弟子ID)
	var 待裁: Array = SectManager.获取待裁决违规() if SectManager.has_method("获取待裁决违规") else []
	for 项 in 待裁:
		if not (项 is Dictionary):
			continue
		var 录: Dictionary = 项
		if int(录.get("弟子ID", -1)) != 该弟子ID:
			continue
		var 类型: String = str(录.get("违规类型", ""))
		var 定义: Dictionary = SectManager.违规类型.get(类型, {})
		var 处罚: Array = 定义.get("处罚", [])
		var 严重度: int = int(定义.get("严重度", 0))
		if 严重度 >= 5 or 处罚.has("逐出宗门"):
			return {"类型": 类型, "严重度": 严重度, "处罚": 处罚, "详情": str(录.get("详情", ""))}
	return {}


func _刷新驱逐门禁(d: Object) -> void:
	if _驱逐_btn == null or not is_instance_valid(_驱逐_btn):
		return
	var 罪: Dictionary = _弟子重罪信息(d)
	var 可逐: bool = not 罪.is_empty()
	_驱逐待确认 = false
	_驱逐_btn.disabled = not 可逐
	if 可逐:
		_驱逐_btn.text = "驱逐师门（%s）" % str(罪.get("类型", "重罪"))
		if _驱逐_hint != null and is_instance_valid(_驱逐_hint):
			_驱逐_hint.text = "门规所限：此人已犯「%s」（严重度%d），可依门规逐出师门。" % [
				str(罪.get("类型", "")), int(罪.get("严重度", 0))]
	else:
		_驱逐_btn.text = "驱逐师门\n（门规所限）"
		if _驱逐_hint != null and is_instance_valid(_驱逐_hint):
			_驱逐_hint.text = "门规所限：无重罪者不得逐出同门。弟子违法由执法堂按月申报，须待宗主裁决。"


# 把弟子对象里的 状态 字段 + ExpeditionSystem 历练中标志，统一为可读的活动状态文字。
# 优先级：陨落 > 历练中 > 失踪/闭关/秘境/原值 > 在宗。
func _取显示状态(d: Object) -> String:
	var 状态v: String = str(_safe_get(d, "状态", "在宗"))
	if 状态v == "":
		状态v = "在宗"
	var 弟子id: int = int(_safe_get(d, "弟子ID", -1))
	if 弟子id >= 0 and ExpeditionSystem != null and ExpeditionSystem.has_method("_弟子是否在历练中"):
		if bool(ExpeditionSystem._弟子是否在历练中(弟子id)):
			return "历练中"
	return 状态v

func _safe_get(d: Variant, key: String, default):
	if d == null:
		return default
	if typeof(d) == TYPE_DICTIONARY:
		return d.get(key, default)
	if typeof(d) == TYPE_OBJECT:
		var obj: Object = d
		if obj != null and obj.has_method("get"):
			var val = obj.get(key)
			return val if val != null else default
	return default


# 自绘进度条宽度：track PanelContainer 拿 layout 后的真实宽，fill_rect 算 ratio。
# 若 track size 还没好（layout 未完成）则 deferred 到下一帧。
func _set_attr_fill_width(entry: Dictionary, ratio: float) -> void:
	if not is_inside_tree():
		return
	var track: PanelContainer = entry.get("track", null)
	var fill_rect: ColorRect = entry.get("bar", null)
	if track == null or fill_rect == null:
		return
	var track_size: Vector2 = track.size
	if track_size.x <= 0.0:
		# layout 未完成，deferred 重试
		var call: Callable = func() -> void:
			if is_instance_valid(self) and self.is_inside_tree():
				_set_attr_fill_width(entry, ratio)
		call.call_deferred()
		return
	fill_rect.size = Vector2(track_size.x * ratio, max(track_size.y, 16))
	# 用 anchor 锁定到 track 左上角
	fill_rect.anchor_left = 0.0
	fill_rect.anchor_top = 0.0
	fill_rect.anchor_right = 0.0
	fill_rect.anchor_bottom = 1.0
	fill_rect.offset_left = 0.0
	fill_rect.offset_top = 0.0
	fill_rect.offset_right = track_size.x * ratio
	fill_rect.offset_bottom = 0.0


func _层数中文(n: int) -> String:
	var cn = ["一","二","三","四","五","六","七","八","九","十"]
	return cn[clampi(n - 1, 0, 9)] + "层"

var _info_popup: Control = null

func _make_card_clickable(card: Control, callback: Callable) -> void:
	# 递归设置所有子控件鼠标穿透，让card的gui_input能触发
	_set_mouse_ignore_recursive(card)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			callback.call(event))

func _set_mouse_ignore_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_mouse_ignore_recursive(child)

func _show_info_popup(title: String, body: String, anchor_pos: Vector2 = Vector2.ZERO) -> void:
	_close_info_popup()
	var shade := ColorRect.new()
	shade.name = "InfoPopupShade"
	shade.color = Color(0, 0, 0, 0.01)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "InfoPopupPanel"
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.122, 0.169, 0.192, 0.97)
	psb.border_color = Color(0.78, 0.65, 0.34, 0.8)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(8)
	psb.content_margin_left = 20; psb.content_margin_right = 20
	psb.content_margin_top = 14; psb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", psb)
	shade.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	UITheme.apply_project_font(tl, UITheme.FONT_H2, true)
	vb.add_child(tl)
	var bl := Label.new()
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(600, 0)
	bl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
	UITheme.apply_project_font(bl, UITheme.FONT_BODY, false)
	vb.add_child(bl)
	# 定位：跟随点击位置，使用 UITheme 安全区收口（顶栏/底部Tab 不遮挡、整屏不出界）
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_instance_valid(panel):
		return
	var vp: Vector2 = get_viewport_rect().size
	UITheme.place_tooltip_near(panel, anchor_pos, vp)
	_info_popup = shade
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_info_popup())

func _close_info_popup() -> void:
	if _info_popup != null and is_instance_valid(_info_popup):
		_info_popup.queue_free()
		_info_popup = null

func _on_destiny_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var did: String = str(_current_disciple.destiny_id)
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	if did == "":
		_show_info_popup("命格", "此弟子尚无命格。\n命格影响修炼方向与特殊加成。", pos)
		return
	var dt: Dictionary = DestinyLoader.get_destiny(did)
	var body: String = str(dt.get("描述", "尚无描述"))
	var effects = dt.get("效果", dt.get("加成", ""))
	if effects != "":
		body += "\n效果：" + str(effects)
	_show_info_popup(str(dt.get("名称", did)), body, pos)

func _on_personality_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	var p: String = str(_current_disciple.性格)
	var body: String = "性格决定弟子在历练、论道与宗务中的行事倾向与抉择。\n不同性格影响事件选项的成败与收益，也会影响同门相处与道途契合。\n可在「洗池·灵泉」处重铸性格，以契合你的修行布局。"
	_show_info_popup(p, body, pos)

func _on_daotu_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	var dt2: String = str(_current_disciple.道途)
	if dt2 == "":
		dt2 = "未入门"
	var desc: Dictionary = {
		"道修": "以法入道，偏重攻击与速度，擅长法术输出。",
		"体修": "以力证道，偏重防御与气血，擅长近身持久战。",
		"法修": "以术御道，偏重速度与攻击，擅长控场辅助。",
		"未入门": "筑基后将根据四维属性自动判定道途。"
	}
	_show_info_popup("道途·" + dt2, str(desc.get(dt2, "此道途尚未解锁。")), pos)

func _on_xinjing_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	var v = _current_disciple.心境
	_show_info_popup("心境", "当前心境：%d/100\n\n心境影响修炼效率、突破成功率、堂务管理效果。\n通过论道切磋、丹药、悟道事件提升。" % v, pos)

func _on_daoxin_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	var v = _current_disciple.道心
	_show_info_popup("道心", "当前道心：%d/100\n\n道心影响高阶突破成功率、心魔抗性、决策正确率。\n通过共参功法、悟道事件、功法学习提升。" % v, pos)

func _on_xinmo_card_clicked(event: InputEvent) -> void:
	if _current_disciple == null:
		return
	var pos: Vector2 = (event as InputEventMouseButton).global_position if event is InputEventMouseButton else Vector2(540, 800)
	var v = _current_disciple.心魔值
	var st = "正常"
	if v >= 90:
		st = "重度（修炼-50%，突破-30%）"
	elif v >= 60:
		st = "中度（修炼-30%，突破-15%）"
	elif v >= 30:
		st = "轻度（修炼-10%，突破-5%）"
	_show_info_popup("心魔", "当前心魔：%d/100\n状态：%s\n\n突破失败、负面事件会增加心魔。\n通过指点修行、罚面壁、丹药降低心魔。" % [v, st], pos)

# ★ 2026-09-14 删：`_on_learn_gongfa_pressed()`、`_on_take_danyao_pressed()`
#   原因（老大 2026-09-14 拍板）：已学功法/服用丹药两项**不该出现在玩家操作面**，
#   应融入弟子自身行为逻辑全自动：功法走「师徒授功 + 机缘」（game_state 约:10711），
#   丹药走「私库自动服用」（disciple.gd：私库自动服用丹药()）。
#   另：原实现都是「取第一个可用项就执行」的无参数一键（违反设计铁则 9）。
#   后端能力保留：`GongFaSystem.学习功法`（仍被 page_building / 功法管理系统调用）、
#   `Game.弟子服用丹药`（待「丹药房 · 择人赐丹」这类**有选择**的入口接入）。

func _on_hudong_pressed(互动类型: String) -> void:
	if _current_disciple == null or Game == null:
		return
	# P0联动：宗主护法单独处理（消耗宗主精力，提升突破成功率）
	if 互动类型 == "宗主护法":
		var 护法结果 = Game.宗主护法(_current_disciple)
		if 护法结果.get("成功", false):
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "护法圆满", "宗主为%s护法，突破成功率+%d%%" % [_current_disciple.姓名, int(护法结果.get("加成", 0) * 100)])
			set_disciple(_current_disciple)
		else:
			if UIHint != null and UIHint.has_method("show_hint"):
				UIHint.show_hint(null, "护法受阻", 护法结果.get("原因", "气机不顺"))
		return
	# ★ 2026-09-14：以毒攻毒＝**宗主亲自施治**（用宗主自身毒道修为），与「宗主护法」同类，
	#   故不走 `Game.执行互动`（那不是「互动次数」体系），直接转给 `_on以毒攻毒治疗`。
	if 互动类型 == "以毒攻毒":
		if _current_disciple is Disciple:
			_on以毒攻毒治疗(_current_disciple as Disciple)
		return
	var 弟子ID = int(_current_disciple.弟子ID)
	var 结果 = Game.执行互动(弟子ID, 互动类型)
	if 结果.get("成功", false):
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "互动圆满", "%s与弟子完成了%s互动！" % [str(Game.宗主名), 互动类型])
		set_disciple(_current_disciple)
	else:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "互动受阻", 结果.get("消息", "卦象错乱"))

func _on_chongzhu_mingge_pressed() -> void:
	if _current_disciple == null:
		return
	if Game == null:
		return
	var 重塑价: int = int(Game.命格重塑仙玉价格)
	if not Game.消耗仙玉(重塑价):
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "仙玉匮乏（需%d）" % 重塑价)
		return
	# 获取洗池等级
	var 洗池等级 = 1
	if Game.司职列表 != null and Game.司职列表.has("xichi"):
		洗池等级 = int(Game.司职列表["xichi"].get("等级", 1))
	# 重铸命格
	var 结果 = XiChiSystem.重铸命格(_current_disciple, 洗池等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "命格重铸", str(结果.get("原因","")))
	set_disciple(_current_disciple)

func _on_six_dim_clicked(event: InputEvent, dim: String, desc: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = (event as InputEventMouseButton).global_position
		var val: int = 0
		if _current_disciple != null and _current_disciple.属性 is Dictionary:
			val = int(_current_disciple.属性.get(dim, 0))
		_show_info_popup(dim + "  " + str(val), desc, pos)

func _on_comp_clicked(event: InputEvent, name: String, desc: String) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = (event as InputEventMouseButton).global_position
		_show_info_popup(name, desc, pos)

func _on_breakthrough_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = (event as InputEventMouseButton).global_position
		var body := "弟子修炼至当前境界大圆满后自动突破。\n\n"
		body += "· 道功进境圆满，自入下一层\n"
		body += "· 十层大圆满后打磨瓶颈，自动突破境界\n"
		body += "· 根骨与心性影响突破成功率\n"
		body += "· 突破失败进入冷却期，期间修炼效率降低"
		_show_info_popup("突破机制", body, pos)

func _on_status_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos: Vector2 = (event as InputEventMouseButton).global_position
		var body := "闭关修炼中：灵气吸收速率提升，期间不可参与历练。\n\n"
		body += "· 修炼中：正常闭关，效率+20%\n"
		body += "· 突破冷却：突破失败后恢复，效率-50%\n"
		body += "· 境界稳固：突破后巩固期，效率-50%"
		_show_info_popup("当前状态", body, pos)

func _on以毒攻毒治疗(弟子: Disciple) -> void:
	if Game == null or 弟子 == null:
		return
	var 结果: Dictionary = Game.以毒攻毒治疗(弟子)
	if bool(结果.get("成功", false)):
		UIHint.show_hint(self, "治疗成功", "毒医以毒攻毒，%s伤势恢复%d日" % [弟子.姓名, int(结果.get("治疗天数", 0))])
	else:
		UIHint.show_hint(self, "治疗失败", str(结果.get("原因", "治疗失败")))
	set_disciple(_current_disciple)

func _品质颜色(资质: String) -> Color:
	match 资质:
		"凡俗", "fan_su": return Color(0.5, 0.55, 0.55)
		"平庸", "pingyong": return Color(0.15, 0.68, 0.38)
		"优良", "youliang": return Color(0.2, 0.6, 0.86)
		"天才", "tiancai": return Color(0.61, 0.35, 0.71)
		"妖孽", "yaonie": return Color(0.9, 0.49, 0.13)
		"旷世", "kuangshi": return Color(0.91, 0.3, 0.24)
		_: return Color(0.5, 0.55, 0.55)

# 立绘安全加载：优先「绝对路径直读」绕开 Godot 资源系统（ResourceLoader / .import UID remap），
# 直接走 OS 文件系统读盘——可规避中文目录名（如「弟子立绘」）在 ResourceLoader 下的静默失败。
# 这也是项目内唯一已验证可工作的加载范式（见 sect_home_page._load_bg_texture）。
# fallback：Godot 资源系统（无中文目录或已正确 import 的场景）。
func _load_texture_safe(path: String) -> Texture2D:
	if path == "":
		return null
	# 1) 优先：OS 文件系统直读（不经 ResourceLoader，中文路径安全）
	var abs_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img: Image = Image.load_from_file(abs_path)
		if img != null:
			return ImageTexture.create_from_image(img)
	# 2) fallback：Godot 资源系统（load 走 .import UID；失败再试 img.load）
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			return tex
		var img2: Image = Image.new()
		if img2.load(path) == OK:
			return ImageTexture.create_from_image(img2)
	return null


func _on_tab_pressed(tab_name: String) -> void:
	for tname in _tab_pages.keys():
		var page: Control = _tab_pages[tname]
		page.visible = (tname == tab_name)
	# 详情Tab显示hero立绘，其他Tab隐藏hero成为独立页面
	var show_hero: bool = (tab_name == "详情")
	if _hero_area != null:
		_hero_area.visible = show_hero
	# 返回按钮：**所有 Tab 常显且置顶**（2026-09-15 修）。
	#   原实现 `_back_btn.visible = show_hero` ⇒ 切到装备/灵兽/履历后返回按钮消失，
	#   玩家只能先切回「详情」Tab 才能离开该页（实机反馈：装备页左上角看不到 ← 返回）。
	#   另：非详情 Tab 时 `_content_area.offset_top = 0`，内容自 y=0 起会把返回按钮盖住，
	#   故同时把 z_index 提到内容层之上（_content_area 后于 _back_btn 添加，默认同层压前者）。
	if _back_btn != null:
		_back_btn.visible = true
		_back_btn.z_index = 200
	# 立绘右上工具带（看全图 / 换装 / 「?」）：只在「详情」Tab 显示。
	# ★ 2026-09-15 修：此前只藏了「换装」，漏藏整条工具带 ⇒ 「看全图」在装备/灵兽/履历页
	#   也挂在右上角（老大截图确认：那是大立绘的工具，别的 Tab 用不到）。
	if _hero_tools != null:
		_hero_tools.visible = show_hero
	# 换装按钮仍只在详情 Tab（它作用于大立绘；装备 Tab 有自己的槽位交互）
	if _skin_btn != null:
		_skin_btn.visible = show_hero
	if _content_area != null:
		if show_hero:
			var page_size: Vector2 = get_size()
			_content_area.offset_top = page_size.y * _HERO_RATIO
		else:
			# ★ 2026-09-15 修：非详情 Tab 原写 offset_top=0 ⇒ 内容自 y=0 起，被常显的返回按钮
			#   （12~48 逻辑 = 27~108 物理）压住，灵兽/履历页顶部信息看不到（老大截图确认）。
			#   现改为「让开返回按钮一行」：顶inset = 返回钮底边 + 一个 GRID 间隙。
			var 顶空: float = float(int(round(48 * UITheme.UI_SCALE))) + float(UITheme.GRID)
			if _back_btn != null:
				顶空 = _back_btn.offset_bottom + float(UITheme.GRID)
			_content_area.offset_top = 顶空
	# 更新Tab按钮样式
	for tname in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tname]
		if tname == tab_name:
			var sb := StyleBoxFlat.new()
			sb.bg_color = UITheme.COLOR_BTN_PRIMARY
			sb.border_color = UITheme.color_border_gold()
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(8)
			sb.set_content_margin_all(UITheme.GRID / 2)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_color_override("font_color", Color(0.06, 0.11, 0.10))
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.122, 0.169, 0.192, 0.90)
			sb.border_color = UITheme.color_border_gold()
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(8)
			sb.set_content_margin_all(UITheme.GRID / 2)
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("pressed", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_color_override("font_color", UITheme.color_text_gold())

func _on_back_pressed() -> void:
	返回列表.emit()

func _on_skin_pressed() -> void:
	仙衣阁请求.emit()

# === S29 收徒拜师 UI：真实羁绊 + 收徒/逐师入口 ===
func _refresh_record_info() -> void:
	if _record_info_grid == null or _current_disciple == null:
		return
	for c in _record_info_grid.get_children():
		c.queue_free()
	var d = _current_disciple
	var 资质中文2: String = _资质显示.get(str(d.资质), str(d.资质))
	var 师名: String = "—"
	if int(d.师父ID) >= 0:
		var 师 = Game._取弟子(int(d.师父ID))
		if 师 != null and str(师.状态) == "在宗":
			师名 = str(师.姓名)
	var info_items = [
		["■ 资质", 资质中文2], ["⚠ 历练", str(d.履历.size()) + "次" if "履历" in d else "0次"],
		["▲ 所属", str(d.司职) if d.司职 != "" else "—"], ["◇ 师父", 师名],
		["◇ 入门", "太玄" + str(max(1, int(d.年龄))) + "年"], ["◎ 道途", str(d.道途) if str(d.道途) != "" else "未入门"],
	]
	for item in info_items:
		_record_info_grid.add_child(_make_info_row(item[0], item[1]))

func _refresh_bonds() -> void:
	if _record_bond_list == null or _current_disciple == null:
		return
	for c in _record_bond_list.get_children():
		c.queue_free()
	var d = _current_disciple
	var bonds = []
	if int(d.师父ID) >= 0:
		var 师 = Game._取弟子(int(d.师父ID))
		if 师 != null and str(师.状态) == "在宗":
			bonds.append(["◇ 师父·" + str(师.姓名), "传功 " + str(d.已学功法.size()) + " 式"])
	if d.主宠灵兽 != null and typeof(d.主宠灵兽) == TYPE_OBJECT:
		bonds.append(["● 灵兽·" + str(d.主宠灵兽.种类名), "随行"])
	if d.装备 is Dictionary:
		for it in d.装备.values():
			if it is Item and (str(it.类别) == "fabao" or str(it.穿戴位) == "本命法宝"):
				bonds.append(["◆ 法宝·" + str(it.名称), str(it.品阶)])
				break
	for b in bonds:
		var br: HBoxContainer = HBoxContainer.new()
		var bn: Label = Label.new()
		bn.text = b[0]
		UITheme.apply_body_text(bn)
		UITheme.apply_project_font(bn, UITheme.FONT_BODY, false)
		bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		br.add_child(bn)
		var bv: Label = Label.new()
		bv.text = b[1]
		UITheme.apply_aux_text(bv)
		UITheme.apply_project_font(bv, UITheme.FONT_AUX, false)
		br.add_child(bv)
		_record_bond_list.add_child(br)
	# S30 性格相冲提示
	var 相冲提示: String = ""
	if int(d.师父ID) >= 0:
		var 师 = Game._取弟子(int(d.师父ID))
		if 师 != null and Disciple.性格相冲度(str(师.性格), str(d.性格)) > 0:
			相冲提示 = "⚠ 与师父性格相冲，心魔渐生"
	elif int(d.道侣ID) >= 0:
		var 侣 = Game._取弟子(int(d.道侣ID))
		if 侣 != null and Disciple.性格相冲度(str(侣.性格), str(d.性格)) > 0:
			相冲提示 = "⚠ 与道侣性格相冲，心魔渐生"
	if 相冲提示 != "":
		var wr: HBoxContainer = HBoxContainer.new()
		var wl: Label = Label.new()
		wl.text = 相冲提示
		UITheme.apply_aux_text(wl)
		wl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
		UITheme.apply_project_font(wl, UITheme.FONT_BODY, false)
		wr.add_child(wl)
		_record_bond_list.add_child(wr)
	var bond_title = _record_bond_list.get_parent().get_parent().get_node_or_null("BondTitle")
	if bond_title:
		bond_title.text = "◆ 羁绊    " + str(bonds.size()) + "条"

func _on_shoutu_pressed() -> void:
	if _current_disciple == null or _shoutu_panel == null:
		return
	for c in _shoutu_panel.get_children():
		c.queue_free()
	var 徒 = _current_disciple
	var 徒阶: int = Disciple.境界序.find(str(徒.境界))
	var 有候选: bool = false
	for 候选 in Game.弟子列表:
		if 候选 == null or 候选 == 徒:
			continue
		if str(候选.状态) != "在宗":
			continue
		var 师阶: int = Disciple.境界序.find(str(候选.境界))
		if 师阶 < 0 or 徒阶 < 0 or (师阶 - 徒阶) < 2:
			continue
		var b: Button = Button.new()
		b.text = "%s（%s）" % [str(候选.姓名), str(候选.境界)]
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(b)
		var 候选ID: int = 候选.弟子ID
		b.pressed.connect(func(): _on_shoutu_pick(候选ID))
		_shoutu_panel.add_child(b)
		有候选 = true
	if not 有候选:
		var tip: Label = Label.new()
		tip.text = "无符合境界差（≥2阶）的在宗弟子可作师"
		UITheme.apply_aux_text(tip)
		_shoutu_panel.add_child(tip)
	_shoutu_panel.visible = true

func _on_shoutu_pick(师ID: int) -> void:
	if _current_disciple == null or _shoutu_panel == null:
		return
	var 徒ID: int = _current_disciple.弟子ID
	var 结果 = Game.收徒(徒ID, 师ID)
	_shoutu_panel.visible = false
	for c in _shoutu_panel.get_children():
		c.queue_free()
	if 结果.get("成功", false):
		_refresh_record_info()
		_refresh_bonds()
		_show_info_popup("收徒成功", "%s 拜入 %s 门下，承传功法 %d 式" % [str(结果.get("徒名", "")), str(结果.get("师名", "")), int(结果.get("授功数", 0))])
	else:
		_show_info_popup("无法收徒", str(结果.get("原因", "未知原因")))

func _on_zhushi_pressed() -> void:
	if _current_disciple == null:
		return
	var 徒ID: int = _current_disciple.弟子ID
	var 结果 = Game.逐师(徒ID)
	if 结果.get("成功", false):
		_refresh_record_info()
		_refresh_bonds()
		_show_info_popup("逐师成功", "%s 已脱离 %s 门下" % [str(_current_disciple.姓名), str(结果.get("师名", ""))])
	else:
		_show_info_popup("无法逐师", str(结果.get("原因", "未知原因")))

# ───────────────── S36 心魔誓（2026-09-14 改：只读）─────────────────
# 设计口径（老大 2026-09-14 拍板）：心魔誓是**弟子依自身行为与经历起誓**的严肃之事，
# 不是玩家在面板上挑一个「限期7日 · 修炼×1.25」的选项。故本页**只显示状态**
# （无誓 / 哪种誓在起效、剩余几日）；立誓走弟子主动请誓：
#   Game._生成请誓_S36() → Game.誓约待批 → 玩家在首页传讯栏「批准 / 驳回」。
func _refresh_oath_box(d: Object) -> void:
	if _oath_box == null:
		return
	for c in _oath_box.get_children():
		_oath_box.remove_child(c)
		c.queue_free()
	if d == null or Game == null:
		return
	var 誓: Dictionary = d.誓言 if (d.誓言 is Dictionary) else {}
	if 誓.is_empty():
		var 空: Label = Label.new()
		空.text = "无誓约在身。若弟子心有所感，会依自身经历自行请誓，届时于首页传讯栏批复即可。"
		空.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(空)
		_oath_box.add_child(空)
		return
	var 名: String = str(誓.get("名称", "无名之誓"))
	var 剩余: int = int(誓.get("剩余日", 0))
	var 期限: int = int(誓.get("期限", 0))
	var 增益: float = float(誓.get("buff_cult", 1.0))
	var 日增: float = float(誓.get("demon_per_day", 0.0))
	var 行: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(行)
	_oath_box.add_child(行)
	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	行.add_child(vb)
	var 头: Label = Label.new()
	头.text = "「%s」　剩余 %d / %d 日" % [名, 剩余, 期限]
	头.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(头)
	vb.add_child(头)
	var eff_txt: String = "在效：修炼速度 ×%.2f" % 增益
	if 日增 > 0.0:
		eff_txt += "　心魔 +%d/日" % int(round(日增))
	elif 日增 < 0.0:
		eff_txt += "　心魔 %d/日" % int(round(日增))
	var eff: Label = Label.new()
	eff.text = eff_txt
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(eff)
	vb.add_child(eff)
	if int(誓.get("forbid_expedition", 0)) == 1:
		var warn: Label = Label.new()
		warn.text = "闭关苦修：期间不可出战"
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_aux_text(warn)
		vb.add_child(warn)

# ───────────────── 互动培养：条件触发（2026-09-14）─────────────────
# 修真世界里的「互动」不是随时都能做，而是**因缘到了才有**：
#   · 论道切磋 / 指点修行：看当日是否还有次数（有人在侧、尚有可指点之处）
#   · 共参功法：还须悟道点足够
#   · 罚面壁思过：只在「心魔渐盛」或「心境失守」时才该出现（无过失不该罚）
#   · 宗主护法：只在弟子正卡突破关口、且宗主精力足够时才该出现
# 判据一律是「当下情境」，不是「玩家想不想」。无一项可用 ⇒ 整块（含标题与红点）隐藏。
func _取可用互动列表(d: Object) -> Array:
	var 出: Array = []
	if d == null or not (d is Disciple) or Game == null:
		return 出
	var 弟子: Disciple = d as Disciple
	if 弟子 == null:
		return 出
	var 弟子ID: int = int(弟子.弟子ID)
	if Game.获取互动剩余次数(弟子ID, "论道切磋") > 0:
		出.append({"类型": "论道切磋", "缘由": "道友在侧，正可论道"})
	if Game.获取互动剩余次数(弟子ID, "共参功法") > 0 and int(Game.悟道点) >= 20:
		出.append({"类型": "共参功法", "缘由": "悟道点充裕，可共参"})
	if Game.获取互动剩余次数(弟子ID, "指点修行") > 0:
		出.append({"类型": "指点修行", "缘由": "尚有可指点之处"})
	if Game.获取互动剩余次数(弟子ID, "罚面壁思过") > 0 and (int(弟子.心魔值) >= 20 or int(弟子.心境) < 50):
		出.append({"类型": "罚面壁思过", "缘由": "心魔渐盛／心境失守"})
	var 关口: bool = float(弟子.瓶颈打磨值) > 0.0 or int(弟子.层数) >= 9
	if 关口 and int(Game.宗主精力) >= 50:
		出.append({"类型": "宗主护法", "缘由": "正卡关口，宜为之护法"})
	# 以毒攻毒＝宗主亲自施治（用宗主自身毒道修为），只在「弟子有伤未愈」且宗主毒道有成时出现。
	if int(弟子.受伤剩余) > 0 and Game.获取毒道境界() != "":
		出.append({"类型": "以毒攻毒", "缘由": "伤而未愈，可以毒攻毒（宗主毒道亲施）"})
	return 出

## 是否有可拜之师（替当前弟子找一位境界高出 ≥2 阶的在宗师）
func _有可拜之师(d: Object) -> bool:
	if d == null or not (d is Disciple) or Game == null:
		return false
	var 弟子: Disciple = d as Disciple
	if 弟子 == null:
		return false
	if int(弟子.师父ID) > 0:
		return false   # 已有师，无需再拜
	var 徒阶: int = Disciple.境界序.find(str(弟子.境界))
	if 徒阶 < 0:
		return false
	for 候选 in Game.弟子列表:
		if 候选 == null or 候选 == 弟子 or not (候选 is Disciple):
			continue
		if str(候选.状态) != "在宗":
			continue
		var 师阶: int = Disciple.境界序.find(str(候选.境界))
		if 师阶 >= 0 and (师阶 - 徒阶) >= 2:
			return true
	return false

## 按情境刷新互动区：无可用项则整块隐藏（含标题与红点）
func _刷新互动区(d: Object) -> void:
	if _hudong_head == null or _hudong_panel == null:
		return
	var 是弟子: bool = (d is Disciple) and Game != null
	var 可用: Array = _取可用互动列表(d) if 是弟子 else []
	var 缘由: Dictionary = {}
	for 项 in 可用:
		var 项D: Dictionary = 项
		缘由[str(项D.get("类型", ""))] = str(项D.get("缘由", ""))
	var 弟子ID: int = int((d as Disciple).弟子ID) if 是弟子 else -1
	for 互动类型 in _hudong_buttons.keys():
		var btn: Button = _hudong_buttons[互动类型]
		if btn == null or not is_instance_valid(btn):
			continue
		var 可: bool = 缘由.has(str(互动类型))
		btn.visible = 可
		if 可:
			# 「以毒攻毒」属宗主亲自施治，不进每日互动次数体系 ⇒ 不显示「剩余N次」。
			if str(互动类型) == "以毒攻毒":
				btn.text = "以毒攻毒"
			else:
				btn.text = "%s 剩余%d次" % [str(互动类型), Game.获取互动剩余次数(弟子ID, str(互动类型))]
			btn.tooltip_text = str(缘由[str(互动类型)])
	# 师徒：拜师（有可拜之师）/ 逐师（已有师）
	var 可拜: bool = _有可拜之师(d)
	var 可逐: bool = 是弟子 and int((d as Disciple).师父ID) > 0
	if _shoutu_btn != null and is_instance_valid(_shoutu_btn):
		_shoutu_btn.visible = 可拜
	if _zhushi_btn != null and is_instance_valid(_zhushi_btn):
		_zhushi_btn.visible = 可逐
	var 总数: int = 缘由.size() + (1 if 可拜 else 0) + (1 if 可逐 else 0)
	var 显: bool = 总数 > 0
	_hudong_head.visible = 显
	_hudong_panel.visible = 显
	if _hudong_dot != null and is_instance_valid(_hudong_dot):
		_hudong_dot.visible = 显   # 有可办之事 ⇒ 亮红点（与首页红点体系同源；无则静态隐藏）
	if _hudong_tip != null and is_instance_valid(_hudong_tip):
		_hudong_tip.text = "" if not 显 else "因缘既至，方可为之；每日各有上限。"

# ───────────────── 立绘「看全图」浮层 ─────────────────
# 立绘在取景框里是 cover 裁切（顶对齐保脸），玩家看不到全身 ⇒ 给一个显式入口看整图。
func _on_portrait_view_pressed() -> void:
	if _fullview_layer != null and is_instance_valid(_fullview_layer):
		_close_portrait_fullview()
		return
	if _portrait == null or _portrait.texture == null:
		return
	var layer: Control = Control.new()
	layer.name = "PortraitFullView"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	_fullview_layer = layer
	var 暗: ColorRect = ColorRect.new()
	var 色: Color = UITheme.获取场景压暗色()
	色.a = 0.94
	暗.color = 色
	暗.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	暗.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(暗)
	# 整图：KEEP_ASPECT_CENTERED ⇒ 1024×2048 全身图完整入框（不裁切），上下自然留边
	var 图: TextureRect = TextureRect.new()
	图.name = "FullPortrait"
	图.texture = _portrait.texture
	图.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	图.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	图.anchor_left = 0.0
	图.anchor_top = 0.0
	图.anchor_right = 1.0
	图.anchor_bottom = 1.0
	图.offset_left = float(int(round(8 * UITheme.UI_SCALE)))
	图.offset_top = float(int(round(64 * UITheme.UI_SCALE)))
	图.offset_right = -float(int(round(8 * UITheme.UI_SCALE)))
	图.offset_bottom = -float(int(round(64 * UITheme.UI_SCALE)))
	图.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(图)
	var 关: Button = Button.new()
	关.name = "CloseBtn"
	关.text = "◇ 关闭"
	关.anchor_left = 1.0
	关.anchor_top = 0.0
	关.anchor_right = 1.0
	关.anchor_bottom = 0.0
	关.offset_left = -float(int(round(150 * UITheme.UI_SCALE)))
	关.offset_top = float(int(round(12 * UITheme.UI_SCALE)))
	关.offset_right = -float(int(round(16 * UITheme.UI_SCALE)))
	关.offset_bottom = float(int(round(12 * UITheme.UI_SCALE))) + float(UITheme.SIZE_SM)
	UITheme.apply_secondary_button_style(关)
	关.pressed.connect(_close_portrait_fullview)
	layer.add_child(关)
	# 点图层任意处也可关（按钮是 STOP，会优先吃掉自身范围内的点击）
	layer.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_portrait_fullview())

func _close_portrait_fullview() -> void:
	if _fullview_layer != null and is_instance_valid(_fullview_layer):
		_fullview_layer.queue_free()
	_fullview_layer = null

# ───────────────── 驱逐师门（二次点击确认）─────────────────
# 「驱逐」属宗主的重决策（不可代劳），但破坏性高 ⇒ 沿用项目既有「二次点击确认」惯例：
# 第一次点＝亮明后果，第二次点才真执行；切换弟子即复位，防误点。
func _on_驱逐师门_pressed() -> void:
	if _current_disciple == null or Game == null:
		return
	# ★ 2026-09-15 门禁：无重罪者此钮锁死（_刷新驱逐门禁() 按「执法堂待裁决重大违规」判定）
	if _驱逐_btn != null and is_instance_valid(_驱逐_btn) and _驱逐_btn.disabled:
		UIHint.show_hint(self, "驱逐师门", "门规所限：%s 未犯重罪，不得逐出同门。" % str(_current_disciple.姓名))
		return
	if not _驱逐待确认:
		_驱逐待确认 = true
		if _驱逐_btn != null and is_instance_valid(_驱逐_btn):
			_驱逐_btn.text = "确认驱逐\n不可撤销"
		UIHint.show_hint(self, "驱逐师门", "再点一次「确认驱逐」方生效：%s 将被逐出宗门，此举不可撤销。" % str(_current_disciple.姓名))
		return
	_驱逐待确认 = false
	var 名: String = str(_current_disciple.姓名)
	var 结果: bool = Game.驱逐弟子(int(_current_disciple.弟子ID))
	if 结果:
		UIHint.show_hint(self, "驱逐师门", "%s 已被逐出宗门。" % 名)
		返回列表.emit()
	else:
		UIHint.show_hint(self, "驱逐师门", "驱逐失败（弟子或已不在宗）。")
		_刷新驱逐门禁(_current_disciple)   # 失败则回落到门禁态（文案/禁用复位）

# 装备称号
func _装备称号(title_id: String) -> void:
	if _current_disciple == null:
		return
	_current_disciple.当前称号 = title_id
	_refresh_record_page()
