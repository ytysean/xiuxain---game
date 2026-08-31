extends Control

# 弟子详情页（二级页）v1 · 立绘主导型（2026-08-23）
# 设计规格：立绘占满上半屏55%作为绝对视觉主体，底部半透明叠加信息条，
#           下半屏依次为战力大字、四维属性条(攻防血速)、命格/性格/道途三栏、装备栏+灵兽位。
# 立绘cover：手动计算 scale=max(hero宽/tex宽, hero高/tex高) + 居中绝对定位 + clip_contents裁剪。

signal 返回列表
signal 装备查看请求(弟子ID: int)
signal 仙衣阁请求

const _HERO_RATIO: float = 0.55

# 资质拼音→中文映射（对齐 disciple.gd 资质显示）
const _资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}
# 命格查表（destiny_id → 中文名称）
const DestinyLoader := preload("res://DestinyDataLoader.gd")

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
var _status_icon: ColorRect = null   # 命魂灯：以颜色表示弟子生死（P3 重构：命牌殿入口移除，状态集成至此）
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
var _record_social_grid: GridContainer = null
var _record_bond_list: VBoxContainer = null
var _record_title_text: Label = null
var _record_achievement_grid: GridContainer = null
var _record_timeline: VBoxContainer = null
var _info_name: Label = null
var _info_realm: Label = null
var _info_identity: Label = null
var _info_quality: Label = null
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
var _gongfa_list_label: Label = null
var _danyao_list_label: Label = null
var _equip_box: HBoxContainer = null
# 魔兽世界风格纸娃娃系统（9槽位）
var _paper_doll_area: Control = null
var _paper_doll_portrait: TextureRect = null
var _equip_slots: Dictionary = {}  # 槽位key -> Button
var _equip_detail_panel: PanelContainer = null
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
	if _portrait == null or _hero_area == null:
		return
	var tex: Texture2D = _portrait.texture
	if tex == null:
		return
	var hero_size: Vector2 = _hero_area.get_size()
	if hero_size.x <= 0 or hero_size.y <= 0:
		# hero_area 还没 layout 完成，deferred 到下一帧重试
		var retry_call: Callable = func() -> void: _apply_portrait_cover()
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
	var pos_y: float = (hero_size.y - draw_h) / 2.0
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
	bg.color = Color(0.05, 0.07, 0.1, 1.0)
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
	_info_name.add_theme_font_size_override("font_size", int(round(28 * UITheme.UI_SCALE)))
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
	_back_btn.pressed.connect(_on_back_pressed)
	add_child(_back_btn)

	# 换装按钮（仙衣阁入口）
	_skin_btn = Button.new()
	_skin_btn.name = "SkinBtn"
	_skin_btn.text = "换装"
	_skin_btn.anchor_left = 1.0
	_skin_btn.anchor_top = 0.0
	_skin_btn.anchor_right = 1.0
	_skin_btn.anchor_bottom = 0.0
	_skin_btn.offset_left = -float(int(round(72 * UITheme.UI_SCALE)))
	_skin_btn.offset_top = float(int(round(12 * UITheme.UI_SCALE)))
	_skin_btn.offset_right = -float(int(round(12 * UITheme.UI_SCALE)))
	_skin_btn.offset_bottom = float(int(round(48 * UITheme.UI_SCALE)))
	_skin_btn.pressed.connect(_on_skin_pressed)
	add_child(_skin_btn)

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
	detail_vb.add_theme_constant_override("separation", 8)
	page_scroll.add_child(detail_vb)
	_tab_pages["详情"] = detail_vb

	# 名字+战力一排
	var power_box := HBoxContainer.new()
	power_box.alignment = BoxContainer.ALIGNMENT_CENTER
	power_box.add_theme_constant_override("separation", 24)
	# 左：名字+境界
	var name_vb := VBoxContainer.new()
	name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_vb.add_child(name_row)
	var name_ico := Label.new()
	name_ico.text = "◆"
	name_ico.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	name_ico.add_theme_font_size_override("font_size", 28)
	name_row.add_child(name_ico)
	_power_name = Label.new()
	_power_name.text = "—"
	_power_name.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	_power_name.add_theme_font_size_override("font_size", 36)
	name_row.add_child(_power_name)
	_power_realm = Label.new()
	_power_realm.text = ""
	_power_realm.add_theme_color_override("font_color", Color(0.35, 0.68, 0.62))
	_power_realm.add_theme_font_size_override("font_size", 22)
	name_vb.add_child(_power_realm)
	power_box.add_child(name_vb)
	# 右：战力+摘要
	var power_right := VBoxContainer.new()
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_END
	prow.add_theme_constant_override("separation", 6)
	power_right.add_child(prow)
	var sword := Label.new()
	sword.text = "⚔"
	sword.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	sword.add_theme_font_size_override("font_size", 32)
	prow.add_child(sword)
	_power_label = Label.new()
	_power_label.text = "—"
	_power_label.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	_power_label.add_theme_font_size_override("font_size", 40)
	prow.add_child(_power_label)
	_power_summary = Label.new()
	_power_summary.text = ""
	_power_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_power_summary.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	_power_summary.add_theme_font_size_override("font_size", 18)
	power_right.add_child(_power_summary)
	power_box.add_child(power_right)
	detail_vb.add_child(power_box)

	# 命格/性格/道途 三栏
	detail_vb.add_child(_make_section_title("命格·性格·道途"))
	var three_col := HBoxContainer.new()
	three_col.add_theme_constant_override("separation", 8)
	detail_vb.add_child(three_col)
	_destiny_label = _make_mini_card("命格", "—")
	_make_card_clickable(_destiny_label, _on_destiny_card_clicked)
	three_col.add_child(_destiny_label)
	_personality_label = _make_mini_card("性格", "—")
	_make_card_clickable(_personality_label, _on_personality_card_clicked)
	three_col.add_child(_personality_label)
	_daotu_label = _make_mini_card("道途", "—")
	_make_card_clickable(_daotu_label, _on_daotu_card_clicked)
	three_col.add_child(_daotu_label)

	# 心境·道心·心魔 三栏
	detail_vb.add_child(_make_section_title("心境·道心·心魔"))
	var xinjing_col := HBoxContainer.new()
	xinjing_col.add_theme_constant_override("separation", 8)
	detail_vb.add_child(xinjing_col)
	_xinjing_label = _make_mini_card("心境", "—")
	_make_card_clickable(_xinjing_label, _on_xinjing_card_clicked)
	xinjing_col.add_child(_xinjing_label)
	_daoxin_label = _make_mini_card("道心", "—")
	_make_card_clickable(_daoxin_label, _on_daoxin_card_clicked)
	xinjing_col.add_child(_daoxin_label)
	_xinmo_label = _make_mini_card("心魔", "—")
	_make_card_clickable(_xinmo_label, _on_xinmo_card_clicked)
	xinjing_col.add_child(_xinmo_label)

	# 互动培养区域
	detail_vb.add_child(_make_section_title("互动培养"))
	var hudong_panel: PanelContainer = _make_panel()
	detail_vb.add_child(hudong_panel)
	var hudong_vb := VBoxContainer.new()
	hudong_vb.add_theme_constant_override("separation", 6)
	hudong_panel.add_child(hudong_vb)

	# 互动按钮网格（2列）
	var hudong_grid := GridContainer.new()
	hudong_grid.columns = 2
	hudong_grid.add_theme_constant_override("h_separation", 8)
	hudong_grid.add_theme_constant_override("v_separation", 8)
	hudong_vb.add_child(hudong_grid)

	_hudong_buttons = {}
	for 互动类型 in ["论道切磋", "共参功法", "指点修行", "罚面壁思过"]:
		var btn := Button.new()
		btn.name = "Hudong_" + 互动类型
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(btn)
		var 类型 = 互动类型
		btn.pressed.connect(func(): _on_hudong_pressed(类型))
		hudong_grid.add_child(btn)
		_hudong_buttons[互动类型] = btn

	# 互动说明
	var hudong_tip := Label.new()
	hudong_tip.text = "互动可提升弟子属性，每日有次数限制。"
	hudong_tip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	hudong_tip.add_theme_font_size_override("font_size", 16)
	hudong_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hudong_vb.add_child(hudong_tip)

	# 已学功法
	detail_vb.add_child(_make_section_title("已学功法"))
	var gongfa_panel: PanelContainer = _make_panel()
	detail_vb.add_child(gongfa_panel)
	var gongfa_vb := VBoxContainer.new()
	gongfa_vb.add_theme_constant_override("separation", 6)
	gongfa_panel.add_child(gongfa_vb)
	_gongfa_list_label = Label.new()
	_gongfa_list_label.text = "尚无功法，静待机缘"
	_gongfa_list_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_gongfa_list_label.add_theme_font_size_override("font_size", 20)
	gongfa_vb.add_child(_gongfa_list_label)
	var learn_gongfa_btn := Button.new()
	learn_gongfa_btn.text = "学习功法（悟道点：0）"
	learn_gongfa_btn.custom_minimum_size = Vector2(0, 44)
	learn_gongfa_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(learn_gongfa_btn)
	learn_gongfa_btn.pressed.connect(_on_learn_gongfa_pressed)
	gongfa_vb.add_child(learn_gongfa_btn)

	# 丹药服用
	detail_vb.add_child(_make_section_title("丹药"))
	var danyao_panel: PanelContainer = _make_panel()
	detail_vb.add_child(danyao_panel)
	var danyao_vb := VBoxContainer.new()
	danyao_vb.add_theme_constant_override("separation", 6)
	danyao_panel.add_child(danyao_vb)
	_danyao_list_label = Label.new()
	_danyao_list_label.text = "尚无丹药效果"
	_danyao_list_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	_danyao_list_label.add_theme_font_size_override("font_size", 20)
	danyao_vb.add_child(_danyao_list_label)
	var take_danyao_btn := Button.new()
	take_danyao_btn.text = "服用丹药（宗门丹药库）"
	take_danyao_btn.custom_minimum_size = Vector2(0, 44)
	take_danyao_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(take_danyao_btn)
	take_danyao_btn.pressed.connect(_on_take_danyao_pressed)
	danyao_vb.add_child(take_danyao_btn)

	# 命格重铸
	detail_vb.add_child(_make_section_title("命格重铸"))
	var chongzhu_panel: PanelContainer = _make_panel()
	detail_vb.add_child(chongzhu_panel)
	var chongzhu_vb := VBoxContainer.new()
	chongzhu_vb.add_theme_constant_override("separation", 6)
	chongzhu_panel.add_child(chongzhu_vb)
	var chongzhu_desc := Label.new()
	chongzhu_desc.text = "前往洗池·灵泉重铸命格/性格，改变弟子天赋与修行方向。"
	chongzhu_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	chongzhu_desc.add_theme_font_size_override("font_size", 18)
	chongzhu_vb.add_child(chongzhu_desc)
	var chongzhu_btn := Button.new()
	chongzhu_btn.text = "前往洗池重铸（消耗200灵石）"
	chongzhu_btn.custom_minimum_size = Vector2(0, 44)
	chongzhu_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(chongzhu_btn)
	chongzhu_btn.pressed.connect(_on_chongzhu_mingge_pressed)
	chongzhu_vb.add_child(chongzhu_btn)

	# ── 六维属性+雷达图 ──
	detail_vb.add_child(_make_section_title("六维属性"))
	var six_panel: PanelContainer = _make_panel()
	detail_vb.add_child(six_panel)
	var six_hb := HBoxContainer.new()
	six_hb.add_theme_constant_override("separation", 12)
	six_panel.add_child(six_hb)
	# 左：六维数值列表
	var six_list := VBoxContainer.new()
	six_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	six_list.add_theme_constant_override("separation", 4)
	six_hb.add_child(six_list)
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
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_six_dim_clicked.bind(dim, six_desc[dim]))
		var name_lbl := Label.new()
		name_lbl.text = dim
		name_lbl.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.custom_minimum_size = Vector2(70, 0)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(val_lbl)
		var hint := Label.new()
		hint.text = "ⓘ"
		hint.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		hint.add_theme_font_size_override("font_size", 18)
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hint)
		_six_labels[dim] = val_lbl
		six_list.add_child(row)
	# 右：雷达图
	_radar = preload("res://ui/radar_chart.gd").new()
	_radar.custom_minimum_size = Vector2(200, 200)
	_radar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	six_hb.add_child(_radar)

	# ── 战力构成 ──
	detail_vb.add_child(_make_section_title("战力构成"))
	var power_panel: PanelContainer = _make_panel()
	detail_vb.add_child(power_panel)
	var power_vb := VBoxContainer.new()
	power_vb.add_theme_constant_override("separation", 6)
	power_panel.add_child(power_vb)
	_power_bars = {}
	var comp_desc = {
		"基础属性": "由攻/防/血/速四维构成，随境界提升。",
		"装备加成": "已穿戴法器提供的战力加成总和。",
		"灵兽加成": "主宠灵兽提供的战力加成。",
		"功法加成": "已修功法与命格提供的加成。"
	}
	for comp in [["基础属性", Color(0.35,0.68,0.90)], ["装备加成", Color(0.70,0.45,0.85)], ["灵兽加成", Color(0.35,0.80,0.50)], ["功法加成", Color(0.95,0.80,0.30)]]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_comp_clicked.bind(comp[0], comp_desc[comp[0]]))
		var cn := Label.new()
		cn.text = comp[0]
		cn.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
		cn.add_theme_font_size_override("font_size", 20)
		cn.custom_minimum_size = Vector2(100, 0)
		cn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cn)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(1,1,1,0.06)
		bar_bg.custom_minimum_size = Vector2(0, 12)
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
		vn.add_theme_font_size_override("font_size", 20)
		vn.custom_minimum_size = Vector2(80, 0)
		vn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(vn)
		_power_bars[comp[0]] = {"bar": bar, "label": vn, "color": comp[1]}
		power_vb.add_child(row)

	# ── 突破进度 ──
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
	_breakthrough_label.add_theme_font_size_override("font_size", 24)
	_breakthrough_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_row.add_child(_breakthrough_label)
	var next_label := Label.new()
	next_label.text = "自动突破中"
	next_label.add_theme_color_override("font_color", Color(0.35, 0.80, 0.50))
	next_label.add_theme_font_size_override("font_size", 20)
	break_row.add_child(next_label)
	break_vb.add_child(break_row)
	var prog_bg := ColorRect.new()
	prog_bg.color = Color(1,1,1,0.08)
	prog_bg.custom_minimum_size = Vector2(0, 16)
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
	_breakthrough_pct.add_theme_font_size_override("font_size", 18)
	break_vb.add_child(_breakthrough_pct)

	# ── 当前状态 ──
	detail_vb.add_child(_make_section_title("当前状态"))
	var status_panel: PanelContainer = _make_panel()
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	status_panel.gui_input.connect(_on_status_clicked)
	detail_vb.add_child(status_panel)
	var status_hb := HBoxContainer.new()
	status_hb.add_theme_constant_override("separation", 12)
	status_panel.add_child(status_hb)
	_status_icon = ColorRect.new()
	_status_icon.color = Color(0.35, 0.68, 0.90, 0.3)
	_status_icon.custom_minimum_size = Vector2(48, 48)
	status_hb.add_child(_status_icon)
	var status_info := VBoxContainer.new()
	status_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hb.add_child(status_info)
	_status_label = Label.new()
	_status_label.text = "闭关修炼中"
	_status_label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	_status_label.add_theme_font_size_override("font_size", 24)
	status_info.add_child(_status_label)
	var status_desc := Label.new()
	status_desc.text = "灵气吸收速率 +20%，期间不可参与历练"
	status_desc.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	status_desc.add_theme_font_size_override("font_size", 18)
	status_info.add_child(status_desc)
	_status_timer = Label.new()
	_status_timer.text = ""
	_status_timer.add_theme_color_override("font_color", Color(0.35, 0.68, 0.90))
	_status_timer.add_theme_font_size_override("font_size", 22)
	status_hb.add_child(_status_timer)

	# ── 底部操作按钮 ──
	var action_hb := HBoxContainer.new()
	action_hb.add_theme_constant_override("separation", 10)
	action_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vb.add_child(action_hb)
	var btn_dispatch := Button.new()
	btn_dispatch.text = "调遣\n任命司职"
	btn_dispatch.custom_minimum_size = Vector2(0, 80)
	btn_dispatch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(btn_dispatch)
	action_hb.add_child(btn_dispatch)
	var btn_cultivate := Button.new()
	btn_cultivate.text = "修炼\n闭关提升"
	btn_cultivate.custom_minimum_size = Vector2(0, 80)
	btn_cultivate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(btn_cultivate)
	action_hb.add_child(btn_cultivate)
	var btn_expel := Button.new()
	btn_expel.text = "驱逐师门\n触犯规矩"
	btn_expel.custom_minimum_size = Vector2(0, 80)
	btn_expel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(btn_expel)
	btn_expel.modulate = Color(1, 0.6, 0.5)
	action_hb.add_child(btn_expel)

	# ── 装备Tab（v17：左右分列大厂布局）──
	var equip_vb := VBoxContainer.new()
	equip_vb.name = "EquipPage"
	equip_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip_vb.custom_minimum_size = Vector2(0, 1750)
	equip_vb.add_theme_constant_override("separation", 6)
	equip_vb.visible = false
	page_scroll.add_child(equip_vb)
	_tab_pages["装备"] = equip_vb
	_build_paper_doll(equip_vb)
	_build_power_summary(equip_vb)
	_build_set_bonus(equip_vb)
	_build_equip_detail(equip_vb)

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
		tb.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		tb.pressed.connect(_on_tab_pressed.bind(tname))
		tab_bar.add_child(tb)
		_tab_buttons[tname] = tb

	# 默认选中详情Tab
	_on_tab_pressed("详情")


func _make_tag(text: String, border_color: Color, bg_color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", border_color)
	lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	return lbl


func _make_section_title(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = "◆ " + text
	lbl.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	lbl.add_theme_font_size_override("font_size", int(round(16 * UITheme.UI_SCALE)))
	return lbl


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.14, 0.2, 0.6)
	sb.border_color = Color(0.83, 0.69, 0.21, 0.2)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_attr_row(attr_name: String) -> HBoxContainer:
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	var name_lbl: Label = Label.new()
	name_lbl.text = attr_name
	name_lbl.custom_minimum_size = Vector2(24, 0)
	name_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	name_lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
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
	track_style.bg_color = Color(0.1, 0.14, 0.2, 0.85)
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
	val_lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	hb.add_child(val_lbl)
	# entry: bar=ColorRect（直接 set width）, val=value label, track=PanelContainer（拿总宽）
	_attr_bars[attr_name] = {"bar": fill_rect, "val": val_lbl, "track": track, "fill_root": fill_root}
	return hb


func _make_mini_card(title: String, desc: String) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	var panel: PanelContainer = _make_panel()
	vb.add_child(panel)
	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	title_lbl.add_theme_font_size_override("font_size", int(round(14 * UITheme.UI_SCALE)))
	inner.add_child(title_lbl)
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.text = desc
	desc_lbl.add_theme_color_override("font_color", Color(0.91, 0.86, 0.78))
	desc_lbl.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(desc_lbl)
	return vb


# ───────── v15竖屏纸娃娃系统（9槽位精确对位）─────────
func _build_paper_doll(parent: VBoxContainer) -> void:
	var root_vb := VBoxContainer.new()
	root_vb.name = "PaperDollRoot"
	root_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_theme_constant_override("separation", 10)
	parent.add_child(root_vb)
	_paper_doll_area = root_vb

	var slot_size: int = 100

	# ── 立绘：全宽铺满上部 ──
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(0, 750)
	portrait_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vb.add_child(portrait_box)
	# 立绘区域背景（和页面统一色调）
	var pbg := ColorRect.new()
	pbg.color = Color(0.08, 0.06, 0.09, 1.0)
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

	# ── 8件装备：2排×4列 ──
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vb.add_child(grid_center)
	grid_center.add_child(grid)

	var equip_keys = ["toukui", "wuqi", "yipao", "peishi", "huzhi", "yaodai", "changku", "xuezi"]
	for key in equip_keys:
		_build_equip_slot(grid, key, slot_size)

	# ── 一键穿戴 | 本命法宝 | 一键卸下 ──
	var fabao_hb := HBoxContainer.new()
	fabao_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	fabao_hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fabao_hb.add_theme_constant_override("separation", 16)
	root_vb.add_child(fabao_hb)

	var btn_wear := Button.new()
	btn_wear.text = "一键穿戴"
	btn_wear.custom_minimum_size = Vector2(200, 80)
	var wear_sb := StyleBoxFlat.new()
	wear_sb.bg_color = Color(0.18, 0.80, 0.44, 0.15)
	wear_sb.border_color = Color(0.18, 0.80, 0.44, 0.8)
	wear_sb.set_border_width_all(1)
	wear_sb.set_corner_radius_all(10)
	btn_wear.add_theme_stylebox_override("normal", wear_sb)
	btn_wear.add_theme_color_override("font_color", Color(0.18, 0.80, 0.44))
	btn_wear.add_theme_font_size_override("font_size", 24)
	btn_wear.pressed.connect(_on_auto_equip_pressed)
	fabao_hb.add_child(btn_wear)

	_build_equip_slot(fabao_hb, "本命法宝", slot_size)

	var btn_off := Button.new()
	btn_off.text = "一键卸下"
	btn_off.custom_minimum_size = Vector2(200, 80)
	var off_sb := StyleBoxFlat.new()
	off_sb.bg_color = Color(1, 1, 1, 0.04)
	off_sb.border_color = Color(0.78, 0.65, 0.34, 0.4)
	off_sb.set_border_width_all(1)
	off_sb.set_corner_radius_all(10)
	btn_off.add_theme_stylebox_override("normal", off_sb)
	btn_off.add_theme_color_override("font_color", Color(0.78, 0.72, 0.59))
	btn_off.add_theme_font_size_override("font_size", 24)
	btn_off.pressed.connect(_on_unequip_all_pressed)
	fabao_hb.add_child(btn_off)


# 构建单个装备槽（圆角方形，大厂标准样式）
func _build_equip_slot(parent: Node, key: String, slot_size: int) -> void:
	var slot_def = _find_slot_def(key)
	var slot_name: String = slot_def.get("name", key)
	var icon_text: String = slot_def.get("icon", "")

	var holder := PanelContainer.new()
	holder.name = "EquipSlot_" + key
	holder.custom_minimum_size = Vector2(slot_size, slot_size)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.10, 0.14, 0.85)
	sb.border_color = Color(0.78, 0.65, 0.34, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
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
	name_lbl.add_theme_color_override("font_color", Color(0.83, 0.72, 0.42, 0.9))
	name_lbl.add_theme_font_size_override("font_size", 19)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_vb.add_child(name_lbl)

	var hint_lbl := Label.new()
	hint_lbl.name = "SlotHint"
	hint_lbl.text = "＋"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66, 0.7))
	hint_lbl.add_theme_font_size_override("font_size", 22)
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
	sb.bg_color = Color(0.06, 0.09, 0.12, 0.8)
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
	power_val.add_theme_font_size_override("font_size", 32)
	power_vb.add_child(power_val)
	_power_total = power_val
	var power_lbl := Label.new()
	power_lbl.text = "总战力"
	power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	power_lbl.add_theme_font_size_override("font_size", 18)
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
	bonus_val.add_theme_font_size_override("font_size", 28)
	bonus_vb.add_child(bonus_val)
	_power_bonus = bonus_val
	var bonus_lbl := Label.new()
	bonus_lbl.text = "装备加成"
	bonus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	bonus_lbl.add_theme_font_size_override("font_size", 18)
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
	count_val.add_theme_font_size_override("font_size", 28)
	count_vb.add_child(count_val)
	_power_count = count_val
	var count_lbl := Label.new()
	count_lbl.text = "已装备"
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	count_lbl.add_theme_font_size_override("font_size", 18)
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
	title_lbl.text = "✨ 套装效果"
	title_lbl.add_theme_color_override("font_color", Color(0.80, 0.55, 0.90))
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_hb.add_child(title_lbl)
	var count_lbl := Label.new()
	count_lbl.name = "SetCount"
	count_lbl.text = "0/5"
	count_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	count_lbl.add_theme_font_size_override("font_size", 20)
	title_hb.add_child(count_lbl)

	# 2/3/5件效果横排
	var effects_hb := HBoxContainer.new()
	effects_hb.add_theme_constant_override("separation", 8)
	vb.add_child(effects_hb)

	var set2 := Label.new()
	set2.name = "SetBonus2"
	set2.text = "2件:未激活"
	set2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set2.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	set2.add_theme_font_size_override("font_size", 16)
	effects_hb.add_child(set2)

	var set3 := Label.new()
	set3.name = "SetBonus3"
	set3.text = "3件:未激活"
	set3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set3.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	set3.add_theme_font_size_override("font_size", 16)
	effects_hb.add_child(set3)

	var set5 := Label.new()
	set5.name = "SetBonus5"
	set5.text = "5件:未激活"
	set5.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set5.add_theme_color_override("font_color", Color(0.40, 0.45, 0.48))
	set5.add_theme_font_size_override("font_size", 16)
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
	_equip_detail_power.text = "战力: —"
	_equip_detail_power.size_flags_horizontal = Control.SIZE_SHRINK_END
	UITheme.apply_value_text(_equip_detail_power)
	header_hb.add_child(_equip_detail_power)

	# 装备描述
	_equip_detail_desc = Label.new()
	_equip_detail_desc.text = "点击装备槽位查看详情"
	_equip_detail_desc.add_theme_color_override("font_color", Color(0.78, 0.72, 0.59))
	_equip_detail_desc.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
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
	avatar_bg.add_theme_stylebox_override("panel", avatar_sb)
	avatar_bg.custom_minimum_size = Vector2(96, 96)
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
	_beast_name.add_theme_font_size_override("font_size", 30)
	name_row.add_child(_beast_name)
	_beast_info = Label.new()
	_beast_info.text = ""
	_beast_info.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	_beast_info.add_theme_font_size_override("font_size", 20)
	name_vb.add_child(_beast_info)
	_beast_power = Label.new()
	_beast_power.text = ""
	_beast_power.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	_beast_power.add_theme_font_size_override("font_size", 22)
	name_vb.add_child(_beast_power)
	# 亲密度
	main_vb.add_child(_make_progress_row("亲密度", "_beast_loyalty", Color(0.95, 0.75, 0.20)))
	# 成长值
	main_vb.add_child(_make_progress_row("成长值", "_beast_level", Color(0.35, 0.80, 0.50)))
	# 技能标题
	var skill_title := Label.new()
	skill_title.text = "灵兽技能"
	skill_title.add_theme_color_override("font_color", Color(0.83, 0.69, 0.21))
	skill_title.add_theme_font_size_override("font_size", 22)
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
	dep_icon.add_theme_font_size_override("font_size", 36)
	dep_hb.add_child(dep_icon)
	var dep_vb := VBoxContainer.new()
	dep_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dep_hb.add_child(dep_vb)
	var dep_name := Label.new()
	dep_name.text = "灵兽·副（空槽）"
	dep_name.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	dep_name.add_theme_font_size_override("font_size", 24)
	dep_vb.add_child(dep_name)
	var dep_hint := Label.new()
	dep_hint.text = "坊市招募，需要灵兽契约×1"
	dep_hint.add_theme_color_override("font_color", Color(0.45, 0.50, 0.52))
	dep_hint.add_theme_font_size_override("font_size", 18)
	dep_vb.add_child(dep_hint)

func _make_progress_row(label_text: String, bar_name: String, bar_color: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_color_override("font_color", Color(0.66, 0.74, 0.72))
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.name = "ValLabel"
	val_lbl.text = "—"
	val_lbl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	val_lbl.add_theme_font_size_override("font_size", 20)
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
	# 社交关系
	parent.add_child(_make_section_title("社交关系"))
	var social_panel: PanelContainer = _make_panel()
	parent.add_child(social_panel)
	_record_social_grid = GridContainer.new()
	_record_social_grid.columns = 2
	_record_social_grid.add_theme_constant_override("h_separation", 10)
	_record_social_grid.add_theme_constant_override("v_separation", 10)
	social_panel.add_child(_record_social_grid)
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
	trophy.text = "🏆"
	trophy.add_theme_font_size_override("font_size", 32)
	title_hb.add_child(trophy)
	var title_vb := VBoxContainer.new()
	title_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hb.add_child(title_vb)
	_record_title_text = Label.new()
	_record_title_text.text = "尚无称号"
	_record_title_text.add_theme_color_override("font_color", Color(0.97, 0.93, 0.85))
	_record_title_text.add_theme_font_size_override("font_size", 26)
	title_vb.add_child(_record_title_text)
	var title_desc := Label.new()
	title_desc.text = "完成成就可获得称号与属性加成"
	title_desc.add_theme_color_override("font_color", Color(0.54, 0.61, 0.66))
	title_desc.add_theme_font_size_override("font_size", 18)
	title_vb.add_child(title_desc)
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


# ───────── 装备槽位点击事件 ─────────
func _on_equip_slot_pressed(slot_key: String) -> void:
	_selected_equip_slot = slot_key
	_refresh_equip_detail()


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
			eq_sb.bg_color = Color(0.08, 0.12, 0.15, 0.92)
			eq_sb.border_color = quality_color
			eq_sb.set_border_width_all(3)
			eq_sb.set_corner_radius_all(10)
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
				var 类别后缀: Dictionary = {"法器":"faqi","神兵":"shenbing","法宝":"fabao","丹药":"danyao","灵材":"lingcai"}
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
			empty_sb.bg_color = Color(0.06, 0.10, 0.13, 0.85)
			empty_sb.border_color = Color(0.78, 0.65, 0.34, 0.5)
			empty_sb.set_border_width_all(2)
			empty_sb.set_corner_radius_all(10)
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
				name_lbl.text = default_name
				name_lbl.add_theme_color_override("font_color", Color(0.83, 0.72, 0.42, 0.9))
				name_lbl.add_theme_font_size_override("font_size", 19)
			if hint_lbl != null:
				hint_lbl.visible = true
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
		title_lbl.text = "✨ " + set_name
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
			tn.add_theme_font_size_override("font_size", 18)
			eb.add_child(tn)
			var td := Label.new()
			td.text = t[1]
			td.add_theme_color_override("font_color", Color(0.85,0.88,0.90) if t[2] else Color(0.35,0.4,0.45))
			td.add_theme_font_size_override("font_size", 16)
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
		_beast_power.text = "战力 " + str(bp)
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
		_beast_level_text.text = str(beast.品阶) + " Lv." + str(lv) + "/" + str(lv_max)
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
			sk_name.add_theme_font_size_override("font_size", 22)
			sk_vb.add_child(sk_name)
			if sk[1]:
				var sk_hint := Label.new()
				sk_hint.text = "已激活"
				sk_hint.add_theme_color_override("font_color", Color(0.35,0.80,0.50))
				sk_hint.add_theme_font_size_override("font_size", 16)
				sk_vb.add_child(sk_hint)

func _refresh_record_page() -> void:
	if _current_disciple == null:
		return
	var d = _current_disciple
	# 基本信息
	if _record_info_grid:
		for c in _record_info_grid.get_children():
			c.queue_free()
		var 资质中文2: String = _资质显示.get(str(d.资质), str(d.资质))
		var info_items = [
			["📊 资质", 资质中文2], ["⚔ 历练", str(d.履历.size()) + "次" if "履历" in d else "0次"],
			["▲ 所属", str(d.司职) if d.司职 != "" else "—"], ["👤 师父", "—"],
			["📅 入门", "太玄" + str(max(1, int(d.年龄))) + "年"], ["◎ 道途", str(d.道途) if str(d.道途) != "" else "未入门"],
		]
		for item in info_items:
			_record_info_grid.add_child(_make_info_row(item[0], item[1]))
	# 社交关系
	if _record_social_grid:
		for c in _record_social_grid.get_children():
			c.queue_free()
		var socials = [
			["💗 道侣", (str(d.道侣) if d.道侣 != "" else "尚无道侣"), "双修加成+15%"],
			["🤝 道友", "0人", "组队历练加成+10%"],
			["🏛 家族", str(d.来源) if d.来源 != "" else "散修", "家族声望+5%"],
			["👶 子嗣", "0人", ""],
		]
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
			sn.add_theme_font_size_override("font_size", 22)
			svb.add_child(sn)
			var sv := Label.new()
			sv.text = s[1]
			sv.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			sv.add_theme_font_size_override("font_size", 20)
			svb.add_child(sv)
	# 羁绊
	if _record_bond_list:
		for c in _record_bond_list.get_children():
			c.queue_free()
		var bonds = [["🔥 赤焰狐", "+5%"], ["👤 师父", "+8%"], ["⚔ 霜寒剑", "+8%"]]
		var bond_title = _record_bond_list.get_parent().get_parent().get_node_or_null("BondTitle")
		if bond_title:
			bond_title.text = "◆ 羁绊    " + str(bonds.size()) + "条"
		for b in bonds:
			var br := HBoxContainer.new()
			var bn := Label.new()
			bn.text = b[0]
			bn.add_theme_color_override("font_color", Color(0.85,0.88,0.90))
			bn.add_theme_font_size_override("font_size", 22)
			bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			br.add_child(bn)
			var bv := Label.new()
			bv.text = b[1]
			bv.add_theme_color_override("font_color", Color(0.35,0.80,0.50))
			bv.add_theme_font_size_override("font_size", 22)
			br.add_child(bv)
			_record_bond_list.add_child(br)
	# 称号
	if _record_title_text:
		_record_title_text.text = "宗门新秀"
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
			aicon.text = "🏆" if unlocked else "？"
			aicon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			aicon.add_theme_font_size_override("font_size", 32)
			aicon.modulate = Color(1,1,1) if unlocked else Color(0.3,0.3,0.3)
			avb.add_child(aicon)
			var aname := Label.new()
			aname.text = achs[i] if unlocked else "未解锁"
			aname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			aname.add_theme_color_override("font_color", Color(0.91,0.83,0.60) if unlocked else Color(0.35,0.38,0.4))
			aname.add_theme_font_size_override("font_size", 16)
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
				var ev = events[i]
				var ev_text: String = str(ev) if typeof(ev) != TYPE_DICTIONARY else str(ev.get("事件", ev.get("desc", "")))
				var row := HBoxContainer.new()
				var dot := Label.new()
				dot.text = "●"
				dot.add_theme_color_override("font_color", Color(0.95,0.80,0.30))
				dot.add_theme_font_size_override("font_size", 16)
				dot.custom_minimum_size = Vector2(30, 0)
				row.add_child(dot)
				var evl := Label.new()
				evl.text = ev_text.left(60)
				evl.add_theme_color_override("font_color", Color(0.75,0.80,0.82))
				evl.add_theme_font_size_override("font_size", 20)
				evl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				evl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				row.add_child(evl)
				_record_timeline.add_child(row)

func _make_info_row(name: String, value: String) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.custom_minimum_size = Vector2(420, 0)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := Label.new()
	nl.text = name
	nl.add_theme_color_override("font_color", Color(0.54,0.61,0.66))
	nl.add_theme_font_size_override("font_size", 22)
	nl.custom_minimum_size = Vector2(140, 0)
	hb.add_child(nl)
	var vl := Label.new()
	vl.text = value
	vl.add_theme_color_override("font_color", Color(0.91,0.83,0.60))
	vl.add_theme_font_size_override("font_size", 22)
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
		_equip_detail_power.text = "战力: —"
		_equip_detail_desc.text = "点击装备槽位查看详情"
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
		_equip_detail_power.text = "战力: —"
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
		_equip_detail_power.text = "战力加成: +%d" % 战力加成
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
			set_title.add_theme_font_size_override("font_size", 20)
			_equip_set_panel.add_child(set_title)
			for 套装 in 套装列表:
				var set_lbl := Label.new()
				var 数量 = 套装["数量"]
				var 效果文本 = ""
				if 数量 >= 5:
					效果文本 = "已激活5件: " + str(套装["5件效果"])
				elif 数量 >= 3:
					效果文本 = "已激活3件: " + str(套装["3件效果"]) + " | 5件: " + str(套装["5件效果"])
				elif 数量 >= 2:
					效果文本 = "已激活2件: " + str(套装["2件效果"]) + " | 3件: " + str(套装["3件效果"])
				else:
					效果文本 = "2件激活: " + str(套装["2件效果"])
				set_lbl.text = "%s (%d/5件) %s" % [str(套装["名称"]), 数量, 效果文本]
				set_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
				set_lbl.add_theme_font_size_override("font_size", 16)
				set_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_equip_set_panel.add_child(set_lbl)

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
	name_lbl.add_theme_font_size_override("font_size", UITheme.FONT_AUX)
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
	# 战力
	_power_label.text = str(d.战力)
	if _power_summary != null:
		var 法器数: int = d.装备.size() if d.装备 is Dictionary else 0
		var 历练数: int = d.履历.size() if "履历" in d else 0
		var 身份文: String = str(d.身份)
		_power_summary.text = 身份文 + " · 历练" + str(历练数) + "次 · 法器" + str(法器数) + "件"
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
		# 当前状态（命魂灯：在宗亮/失踪亮/陨落灭；P3 重构：命牌殿入口移除，状态集成至此）
		if _status_label != null and _status_icon != null:
			var 状态v = str(d.状态) if "状态" in d else "在宗"
			var 命牌色 = Color(0.35, 0.68, 0.90, 0.3)
			var 生死态 = ""
			if 状态v == "失踪":
				命牌色 = Color(0.93, 0.78, 0.30)
				生死态 = "失踪（生还·下落不明）"
			elif 状态v == "陨落":
				命牌色 = Color(0.12, 0.12, 0.14)
				生死态 = "已陨落（命牌灭）"
			else:
				命牌色 = Color(0.49, 0.83, 0.60)
				生死态 = "在宗（生还）"
			_status_icon.color = 命牌色
			if 状态v == "陨落" or 状态v == "失踪":
				_status_label.text = 生死态
			elif d.突破冷却剩余 > 0:
				_status_label.text = 生死态 + " · 突破气机未复"
			elif d.稳固期剩余 > 0:
				_status_label.text = 生死态 + " · 境界稳固中"
			else:
				_status_label.text = 生死态 + " · 闭关修炼中"
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
	# 性格
	var lbl2 = _personality_label.find_child("DescLabel", true, false)
	if lbl2 != null:
		lbl2.text = str(d.性格)
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
	# 更新学习按钮的悟道点显示
	var learn_btn = _gongfa_list_label.get_parent().get_children()[-1] if _gongfa_list_label != null and _gongfa_list_label.get_parent() != null else null
	if learn_btn != null and learn_btn is Button:
		learn_btn.text = "学习功法（悟道点：%d）" % int(Game.悟道点) if Game != null else "学习功法"
	# 丹药显示
	if _danyao_list_label != null:
		var 仓库 = Game.仓库 if Game != null else []
		var 丹药数 = 0
		for item in 仓库:
			if item != null and str(item.get("类别", "")) == "丹药":
				丹药数 += 1
		_danyao_list_label.text = "宗门丹药库：%d颗" % 丹药数
	# 立绘（直接调用方法，不依赖 has_method 判断）
	var 路径 = d.取立绘路径("stand")
	print("[弟子详情] 立绘路径=", 路径)
	var tex = _load_texture_safe(路径)
	# 精英版加载失败时自动fallback到普通版
	if tex == null and 路径.contains("_elite"):
		var 普通路径: String = 路径.replace("_elite.png", ".png")
		print("[弟子详情] 精英版加载失败, fallback到普通版: ", 普通路径)
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
	var track: PanelContainer = entry.get("track", null)
	var fill_rect: ColorRect = entry.get("bar", null)
	if track == null or fill_rect == null:
		return
	var track_size: Vector2 = track.size
	if track_size.x <= 0.0:
		# layout 未完成，deferred 重试
		var call: Callable = func() -> void: _set_attr_fill_width(entry, ratio)
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
	psb.bg_color = Color(0.12, 0.18, 0.17, 0.97)
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
	tl.add_theme_font_size_override("font_size", 22)
	vb.add_child(tl)
	var bl := Label.new()
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(600, 0)
	bl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
	bl.add_theme_font_size_override("font_size", 20)
	vb.add_child(bl)
	# 定位：跟随点击位置，确保不出屏
	await get_tree().process_frame
	await get_tree().process_frame
	var pw2: float = panel.size.x
	var ph2: float = panel.size.y
	if pw2 < 10:
		pw2 = 640
	if ph2 < 10:
		ph2 = 120
	var vp: Vector2 = get_viewport_rect().size
	var px2: float = anchor_pos.x - pw2 * 0.5
	var py2: float = anchor_pos.y - ph2 - 16
	# 默认在点击位置上方；上方空间不够则放下方
	if py2 < 100:
		py2 = anchor_pos.y + 16
	# 水平不出屏
	px2 = clampf(px2, 8, vp.x - pw2 - 8)
	# 垂直不出屏
	py2 = clampf(py2, 100, vp.y - ph2 - 120)
	panel.position = Vector2(px2, py2)
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
	_show_info_popup(p, "性格影响弟子的行为倾向与事件选择。", pos)

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

func _on_learn_gongfa_pressed() -> void:
	if _current_disciple == null:
		return
	# 查找第一个可学习的功法
	var 目标功法: String = ""
	for gid in GongFaSystem.功法库.keys():
		var 检查 = GongFaSystem.可学习(_current_disciple, gid)
		if 检查.get("可学", false):
			目标功法 = gid
			break
	if 目标功法 == "":
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "尚无修习之功（境界不足或已尽习）")
		return
	# 学习功法
	var 结果 = GongFaSystem.学习功法(_current_disciple, 目标功法, int(Game.悟道点))
	if 结果.get("成功", false):
		Game.悟道点 -= int(结果.get("消耗", 0))
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "学习功法", str(结果.get("原因","")))
	set_disciple(_current_disciple)

func _on_take_danyao_pressed() -> void:
	if _current_disciple == null:
		return
	# 检查宗门丹药库
	var 仓库 = Game.仓库 if Game != null else []
	if 仓库 == null or 仓库.size() == 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "宗门丹药库为空，去丹堂炼丹吧")
		return
	# 查找第一个丹药
	var 丹药索引 = -1
	for i in range(仓库.size()):
		var item = 仓库[i]
		if item != null and str(item.get("类别", "")) == "丹药":
			丹药索引 = i
			break
	if 丹药索引 < 0:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "丹库空空，尚无丹药")
		return
	# 服用丹药
	var 丹药 = 仓库[丹药索引]
	var 丹药名 = str(丹药.get("名称", "丹药"))
	# 简化：直接移除丹药并提示效果
	仓库.remove_at(丹药索引)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "服用丹药", "%s服用了%s，效果已生效！" % [str(_current_disciple.姓名), 丹药名])
	set_disciple(_current_disciple)

func _on_hudong_pressed(互动类型: String) -> void:
	if _current_disciple == null or Game == null:
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
	if Game == null or Game.灵石 < 200:
		if UIHint != null and UIHint.has_method("show_hint"):
			UIHint.show_hint(null, "指点", "灵石匮乏（需200）")
		return
	Game.灵石 -= 200
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
		body += "· 修炼进度满后自动进入下一层\n"
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
	# 返回/换装按钮只在详情Tab显示
	if _back_btn != null:
		_back_btn.visible = show_hero
	if _skin_btn != null:
		_skin_btn.visible = show_hero
	if _content_area != null:
		if show_hero:
			var page_size: Vector2 = get_size()
			_content_area.offset_top = page_size.y * _HERO_RATIO
		else:
			_content_area.offset_top = 0.0
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
			sb.bg_color = Color(0.12, 0.18, 0.17, 0.9)
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
