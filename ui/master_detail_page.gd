extends Control

# 宗主详情页（二级页）v5 · 立绘主导型（2026-08-23 自包含绝对布局版）
# 核心改动：不依赖 game_ui.gd 修改 offset_top，不依赖 anchor 比例自动计算。
#           在 _ready() 里直接修改父容器位置，延迟一帧用绝对像素设置 Hero/Content 布局。
# 设计规格：立绘占满上半屏58%作为绝对视觉主体，底部半透明叠加信息条，
#           下半屏依次为宗主特权(3数值)、宗主权责(6图标宫格)、最近纪事(2条+查看更多)。

signal 返回主页
signal 权责请求(分类: String)
signal 编辑请求
signal 宗主皮肤请求

const 权责列表: Array = [
	"宗门规制", "职司任免", "功勋赏罚",
	"闭关设置", "阵堂布置", "宗门纪事",
]

const 权责图标路径: Array = [
	"res://art/ui/master_detail/icon_1_guizhi.png",
	"res://art/ui/master_detail/icon_2_renmian.png",
	"res://art/ui/master_detail/icon_3_gongxun.png",
	"res://art/ui/master_detail/icon_4_biguan.png",
	"res://art/ui/master_detail/icon_5_zhentang.png",
	"res://art/ui/master_detail/icon_6_jishi.png",
]

const 宗主特权: Array = [
	{"值": "+2%", "标签": "宗门产出"},
	{"值": "+5%", "标签": "招募成功率"},
	{"值": "-1%", "标签": "坊市交易税"},
]

const _履历上限: int = 2
const _HERO_RATIO: float = 0.58

var _built: bool = false
var _hero_area: Control = null
var _content_area: ScrollContainer = null
var _portrait: TextureRect = null
var _info_name: Label = null
var _info_realm: Label = null
var _info_realm_desc: Label = null
var _info_days: Label = null
var _privilege_values: Array = []
var _auth_buttons: Array = []
var _history_box: VBoxContainer = null


func _ready() -> void:
	print("[宗主详情 v5] _ready() 被调用")
	# 关键1：直接修改父容器（_sub_page_container）的 offset_top = 0，不依赖 game_ui.gd
	var parent: Node = get_parent()
	if parent != null and parent is Control:
		var p: Control = parent as Control
		p.offset_top = 0.0
		print("[宗主详情 v5] 已设置父容器 offset_top=0, 父节点名=", p.name)
	# 页面自己设为全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	# 关键2：延迟一帧，等布局稳定后用绝对像素设置 Hero/Content
	call_deferred("_apply_final_layout")
	refresh()


func _apply_final_layout() -> void:
	# 再次确保父容器 offset_top = 0（防止被其他代码覆盖）
	var parent: Node = get_parent()
	if parent != null and parent is Control:
		(parent as Control).offset_top = 0.0
	# 页面自己重新设为全屏
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 获取页面实际大小
	var page_size: Vector2 = get_size()
	var hero_h: float = page_size.y * _HERO_RATIO
	print("[宗主详情 v5] 最终布局: 页面=%dx%d Hero高=%.0f" % [page_size.x, page_size.y, hero_h])
	# Hero 撑满全宽 + 固定高度 hero_h；cover 由 _portrait 的 STRETCH_KEEP_ASPECT_COVERED 自动处理
	if _hero_area != null:
		_hero_area.anchor_left = 0.0
		_hero_area.anchor_top = 0.0
		_hero_area.anchor_right = 1.0
		_hero_area.anchor_bottom = 0.0
		_hero_area.offset_left = 0.0
		_hero_area.offset_top = 0.0
		_hero_area.offset_right = 0.0
		_hero_area.offset_bottom = hero_h
		print("[宗主详情 v5] Hero设置: offset_right=%.0f offset_bottom=%.0f" % [_hero_area.offset_right, _hero_area.offset_bottom])
	# Content 撑满全宽 + 从 hero_h 到页底
	if _content_area != null:
		_content_area.anchor_left = 0.0
		_content_area.anchor_top = 0.0
		_content_area.anchor_right = 1.0
		_content_area.anchor_bottom = 1.0
		_content_area.offset_left = 0.0
		_content_area.offset_top = hero_h
		_content_area.offset_right = 0.0
		_content_area.offset_bottom = 0.0
		print("[宗主详情 v5] Content设置: offset_top=%.0f offset_bottom=%.0f" % [_content_area.offset_top, _content_area.offset_bottom])
	# 立绘 cover：手动算 max scale + 居中，TextureRect 用 STRETCH_SCALE 在 self size 内渲染
	_apply_portrait_cover()


func _build() -> void:
	if _built:
		return
	_built = true
	print("[宗主详情 v5] _build() 开始")
	# 背景层
	var bg := ColorRect.new()
	bg.name = "BaseBG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = UITheme.SECONDARY_CONTENT_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Hero 立绘区（先占全屏，_apply_final_layout 里再精确设置）
	_hero_area = Control.new()
	_hero_area.name = "HeroArea"
	_hero_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_area.clip_contents = true  # 关键：裁剪超出区域的立绘部分
	add_child(_hero_area)
	_build_hero(_hero_area)
	# 内容区（先占全屏，_apply_final_layout 里再精确设置）
	_content_area = ScrollContainer.new()
	_content_area.name = "ContentArea"
	_content_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_area.mouse_filter = Control.MOUSE_FILTER_STOP  # 必须 STOP 才能接收滚轮滚动事件
	add_child(_content_area)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UITheme.GRID)
	inner.add_theme_constant_override("margin_left", UITheme.MARGIN)
	inner.add_theme_constant_override("margin_right", UITheme.MARGIN)
	inner.add_theme_constant_override("margin_top", UITheme.GRID)
	inner.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_content_area.add_child(inner)
	_build_privilege(inner)
	_build_authority(inner)
	_build_history(inner)
	print("[宗主详情 v5] _build() 完成")


func _build_hero(parent: Control) -> void:
	# 立绘：anchor 全 0 + STRETCH_SCALE，cover 由 _apply_portrait_cover() 算绝对像素 offset（max scale + 居中）
	_portrait = TextureRect.new()
	_portrait.name = "PortraitTex"
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
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_portrait)
	# HeroFade 已移除：GradientTexture2D 默认 fill_to=(1,0) 是水平渐变，拉伸到 hero 后从左到右透明→黑
	# 在明暗交界处产生 5px 左右灰绿色竖条（截图里那条）。改为 vertical fill；不必要则删除——info_bar
	# 标签自带 shadow_offset_x/y=2 + C01_SHADOW，视觉层级足够，无需 fade 过渡。直接删除最稳。
	# 顶部导航栏
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = float(UITheme.MARGIN)
	top_bar.offset_top = float(UITheme.GRID)
	top_bar.offset_right = -float(UITheme.MARGIN)
	top_bar.offset_bottom = float(UITheme.GRID) + float(UITheme.SIZE_SM)
	top_bar.add_theme_constant_override("separation", UITheme.GRID)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(top_bar)
	var back: Button = UITheme.make_back_button(_on_back_pressed)
	top_bar.add_child(back)
	var title := Label.new()
	title.name = "Title"
	title.text = "宗主玉牒"
	title.visible = false  # 用户要求不显示顶部标题
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font_sized(title, int(round(18.0 * UITheme.UI_SCALE)))
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	title.add_theme_color_override("font_shadow_color", UITheme.C01_SHADOW)
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	top_bar.add_child(title)
	# 弹性spacer，把改名/换装按钮推到右上角
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)
	var edit := Button.new()
	edit.name = "EditBtn"
	edit.text = "改名"
	edit.custom_minimum_size = Vector2(int(round(56.0 * UITheme.UI_SCALE)), 0)
	UITheme.apply_body_font_sized(edit, int(round(13.0 * UITheme.UI_SCALE)))
	edit.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	edit.pressed.connect(_on_edit_pressed)
	top_bar.add_child(edit)
	# 换装按钮（宗主皮肤商店入口）
	var skin := Button.new()
	skin.name = "SkinBtn"
	skin.text = "换装"
	skin.custom_minimum_size = Vector2(int(round(56.0 * UITheme.UI_SCALE)), 0)
	UITheme.apply_body_font_sized(skin, int(round(13.0 * UITheme.UI_SCALE)))
	skin.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	skin.pressed.connect(_on_skin_pressed)
	top_bar.add_child(skin)
	# 底部信息条
	var info_bar := VBoxContainer.new()
	info_bar.name = "HeroInfoBar"
	info_bar.anchor_left = 0.0
	info_bar.anchor_top = 1.0
	info_bar.anchor_right = 1.0
	info_bar.anchor_bottom = 1.0
	info_bar.offset_left = float(UITheme.MARGIN)
	info_bar.offset_top = -float(UITheme.SIZE_LG)
	info_bar.offset_right = -float(UITheme.MARGIN)
	info_bar.offset_bottom = -float(UITheme.GRID)
	info_bar.add_theme_constant_override("separation", 4)
	info_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(info_bar)
	_info_name = Label.new()
	_info_name.text = "—"
	UITheme.apply_title_font_sized(_info_name, int(round(20.0 * UITheme.UI_SCALE)))
	_info_name.add_theme_color_override("font_color", UITheme.获取主文字色())
	_info_name.add_theme_color_override("font_shadow_color", UITheme.C01_SHADOW)
	_info_name.add_theme_constant_override("shadow_offset_x", 2)
	_info_name.add_theme_constant_override("shadow_offset_y", 2)
	info_bar.add_child(_info_name)
	var info_sub := HBoxContainer.new()
	info_sub.add_theme_constant_override("separation", 8)
	info_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_bar.add_child(info_sub)
	# 境界金色圆角标签（深色半透明底 + 金色边框 + 金色文字）
	var realm_panel := PanelContainer.new()
	realm_panel.name = "RealmPanel"
	var realm_sb := StyleBoxFlat.new()
	realm_sb.bg_color = Color(0.06, 0.05, 0.03, 0.88)
	realm_sb.border_color = UITheme.获取暗金边色()
	realm_sb.set_corner_radius_all(6)
	realm_sb.set_border_width_all(1)
	realm_sb.content_margin_left = 8.0
	realm_sb.content_margin_right = 8.0
	realm_sb.content_margin_top = 2.0
	realm_sb.content_margin_bottom = 2.0
	realm_panel.add_theme_stylebox_override("panel", realm_sb)
	var realm_tag := Label.new()
	realm_tag.name = "RealmTag"
	realm_tag.text = "—"
	UITheme.apply_body_font_sized(realm_tag, int(round(12.0 * UITheme.UI_SCALE)))
	realm_tag.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	realm_tag.add_theme_color_override("font_shadow_color", UITheme.C01_SHADOW)
	realm_tag.add_theme_constant_override("shadow_offset_x", 1)
	realm_tag.add_theme_constant_override("shadow_offset_y", 1)
	realm_panel.add_child(realm_tag)
	info_sub.add_child(realm_panel)
	_info_realm = realm_tag
	# 境界说明文字
	var realm_desc := Label.new()
	realm_desc.name = "RealmDesc"
	realm_desc.text = "（宗门当前最高境界）"
	UITheme.apply_body_font_sized(realm_desc, int(round(11.0 * UITheme.UI_SCALE)))
	realm_desc.add_theme_color_override("font_color", UITheme.获取次文字色())
	realm_desc.add_theme_color_override("font_shadow_color", UITheme.C01_SHADOW)
	realm_desc.add_theme_constant_override("shadow_offset_x", 1)
	realm_desc.add_theme_constant_override("shadow_offset_y", 1)
	info_sub.add_child(realm_desc)
	_info_realm_desc = realm_desc
	var days_label := Label.new()
	days_label.name = "DaysLabel"
	days_label.text = "执掌 0 日"
	days_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	days_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_body_font_sized(days_label, int(round(12.0 * UITheme.UI_SCALE)))
	days_label.add_theme_color_override("font_color", UITheme.获取主文字色())
	days_label.add_theme_color_override("font_shadow_color", UITheme.C01_SHADOW)
	days_label.add_theme_constant_override("shadow_offset_x", 2)
	days_label.add_theme_constant_override("shadow_offset_y", 2)
	info_sub.add_child(days_label)
	_info_days = days_label


func _build_privilege(parent: Control) -> void:
	var panel: VBoxContainer = _make_module_panel(parent, "宗主特权")
	var grid := HBoxContainer.new()
	grid.name = "PrivilegeGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grid)
	_privilege_values.clear()
	for item in 宗主特权:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(col)
		var val := Label.new()
		val.text = str(item["值"])
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_body_font_sized(val, int(round(18.0 * UITheme.UI_SCALE)))
		val.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		col.add_child(val)
		_privilege_values.append(val)
		var cap := Label.new()
		cap.text = str(item["标签"])
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(cap)
		cap.add_theme_color_override("font_color", UITheme.获取弱文字色())
		col.add_child(cap)


func _build_authority(parent: Control) -> void:
	var panel: VBoxContainer = _make_module_panel(parent, "宗主权责")
	var grid := GridContainer.new()
	grid.name = "AuthGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(grid)
	_auth_buttons.clear()
	for i in range(权责列表.size()):
		var 分类: String = 权责列表[i]
		var 图标路径: String = 权责图标路径[i]
		var btn: Control = _make_auth_icon_button(分类, 图标路径)
		grid.add_child(btn)
		_auth_buttons.append(btn)


func _make_auth_icon_button(分类: String, 图标路径: String) -> Control:
	var wrapper := VBoxContainer.new()
	wrapper.name = "AuthBtn_%s" % 分类
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_theme_constant_override("separation", 4)
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn := TextureButton.new()
	btn.name = "IconBtn"
	btn.custom_minimum_size = Vector2(int(round(52.0 * UITheme.UI_SCALE)), int(round(52.0 * UITheme.UI_SCALE)))
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.stretch_mode = TextureButton.STRETCH_SCALE
	btn.ignore_texture_size = true
	if ResourceLoader.exists(图标路径):
		var tex: Texture2D = load(图标路径) as Texture2D
		btn.texture_normal = tex
		print("[宗主详情 v5] 图标加载成功: %s" % 分类)
	else:
		print("[宗主详情 v5] 图标加载失败: %s" % 分类)
	btn.pressed.connect(_on_auth_pressed.bind(分类))
	wrapper.add_child(btn)
	var label := Label.new()
	label.name = "Label"
	label.text = 分类
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_body_font_sized(label, int(round(11.0 * UITheme.UI_SCALE)))
	label.add_theme_color_override("font_color", UITheme.获取次文字色())
	wrapper.add_child(label)
	return wrapper


func _build_history(parent: Control) -> void:
	var panel: VBoxContainer = _make_module_panel(parent, "最近纪事")
	_history_box = VBoxContainer.new()
	_history_box.name = "HistoryList"
	_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_box.add_theme_constant_override("separation", 6)
	_history_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_history_box)
	var more_btn := Button.new()
	more_btn.name = "MoreBtn"
	more_btn.text = "查看更多纪事 →"
	more_btn.flat = true
	more_btn.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	UITheme.apply_body_font_sized(more_btn, int(round(11.0 * UITheme.UI_SCALE)))
	more_btn.add_theme_color_override("font_color", UITheme.获取弱文字色())
	more_btn.add_theme_color_override("font_hover_color", UITheme.COLOR_TEXT_GOLD)
	var sb_more := StyleBoxFlat.new()
	sb_more.bg_color = Color(0, 0, 0, 0)
	sb_more.set_content_margin_all(0)
	more_btn.add_theme_stylebox_override("normal", sb_more)
	more_btn.add_theme_stylebox_override("hover", sb_more)
	more_btn.add_theme_stylebox_override("pressed", sb_more)
	more_btn.pressed.connect(_on_history_more_pressed)
	panel.add_child(more_btn)


func _make_module_panel(parent: Control, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Panel_%s" % title
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.获取面板底色(), 0.5)
	sb.border_color = Color(UITheme.获取暗金边色(), 0.3)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.name = "InnerCol"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	var title_lbl := Label.new()
	title_lbl.text = "◆  %s" % title
	UITheme.apply_title_font_sized(title_lbl, int(round(13.0 * UITheme.UI_SCALE)))
	title_lbl.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	col.add_child(title_lbl)
	return col


func _make_history_row(名称: String, 日: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, int(round(28.0 * UITheme.UI_SCALE)))
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(6, 6)
	marker.color = UITheme.COLOR_TEXT_GOLD
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(marker)
	var name_lbl := Label.new()
	name_lbl.text = 名称
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_font_sized(name_lbl, int(round(12.0 * UITheme.UI_SCALE)))
	name_lbl.add_theme_color_override("font_color", UITheme.获取主文字色())
	row.add_child(name_lbl)
	var day_lbl := Label.new()
	day_lbl.text = "第 %d 日" % 日
	UITheme.apply_aux_text(day_lbl)
	day_lbl.add_theme_color_override("font_color", UITheme.获取弱文字色())
	row.add_child(day_lbl)
	return row


func refresh() -> void:
	if not _built:
		_build()
	if not is_instance_valid(Game):
		return
	_refresh_hero()
	_refresh_privilege()
	_refresh_history()


func _refresh_hero() -> void:
	if _portrait != null and Game.has_method("取宗主立绘纹理"):
		var tex: Texture2D = Game.取宗主立绘纹理()
		if tex != null:
			_portrait.texture = tex
			print("[宗主详情 v5] 立绘加载成功，尺寸: %dx%d" % [tex.get_width(), tex.get_height()])
			# texture 是延迟加载的，必须在 _ready->_apply_final_layout 之后再走一次 cover
			_apply_portrait_cover()
		else:
			print("[宗主详情 v5] 立绘纹理为 null")
	var 主名: String = _str_or_dash("宗主名", "太虚道君")
	var 门名: String = _str_or_dash("宗门名", "太玄宗")
	_info_name.text = "%s · %s宗主" % [主名, 门名]
	var 境界: String = _取_宗主境界()
	if 境界 == "":
		_info_realm.text = "—"
		if _info_realm_desc != null:
			_info_realm_desc.visible = false
	else:
		_info_realm.text = 境界
		if _info_realm_desc != null:
			_info_realm_desc.visible = true
	var 天: int = _int_or_zero("累计游戏日")
	_info_days.text = "执掌 %d 日" % 天


func _apply_portrait_cover() -> void:
	if _portrait == null or _hero_area == null:
		return
	if _portrait.texture == null:
		return
	var tex: Texture2D = _portrait.texture
	var tex_w: float = float(tex.get_width())
	var tex_h: float = float(tex.get_height())
	var hero_size: Vector2 = _hero_area.size
	if tex_w <= 0.0 or tex_h <= 0.0 or hero_size.x <= 0.0 or hero_size.y <= 0.0:
		return
	# max(scale_x, scale_y)：保证 cover 整个 hero_area，texture 多余 part 在 hero_area clip_contents 内裁剪
	var scale: float = max(hero_size.x / tex_w, hero_size.y / tex_h)
	var display_w: float = tex_w * scale
	var display_h: float = tex_h * scale
	var pos_x: float = (hero_size.x - display_w) / 2.0
	var pos_y: float = (hero_size.y - display_h) / 2.0
	_portrait.offset_left = pos_x
	_portrait.offset_top = pos_y
	_portrait.offset_right = pos_x + display_w
	_portrait.offset_bottom = pos_y + display_h
	print("[宗主详情 v5] cover: hero=%.0fx%.0f tex=%.0fx%.0f scale=%.3f display=%.0fx%.0f pos=(%.0f,%.0f)" % [hero_size.x, hero_size.y, tex_w, tex_h, scale, display_w, display_h, pos_x, pos_y])


func _refresh_privilege() -> void:
	pass


func _refresh_history() -> void:
	for c in _history_box.get_children():
		c.queue_free()
	var 履历: Array = _取_玉牒履历()
	if 履历.is_empty():
		var empty := Label.new()
		empty.text = "尚无纪事"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_text(empty)
		empty.add_theme_color_override("font_color", UITheme.获取弱文字色())
		_history_box.add_child(empty)
		return
	for entry in 履历:
		var 名称: String = str(entry.get("名称", "—"))
		var 日: int = int(entry.get("日", 0))
		_history_box.add_child(_make_history_row(名称, 日))


func _str_or_dash(key: String, fallback: String) -> String:
	if not is_instance_valid(Game):
		return fallback
	var v: Variant = Game.get(key)
	if v == null:
		return fallback
	var s: String = str(v)
	return s if s != "" else fallback


func _int_or_zero(key: String) -> int:
	if not is_instance_valid(Game):
		return 0
	var v: Variant = Game.get(key)
	return 0 if v == null else int(v)


func _取_宗主境界() -> String:
	if is_instance_valid(Game):
		var v: Variant = Game.get("宗主境界")
		if v != null:
			var s: String = str(v)
			if s != "":
				return s
	if is_instance_valid(Game):
		var v: Variant = Game.get("弟子列表")
		if v != null:
			var 弟子_arr: Array = v
			if not 弟子_arr.is_empty():
				var 最高: String = ""
				var 最高序: int = -1
				for d in 弟子_arr:
					if d == null:
						continue
					var 境: String = str(d.境界)
					if 境 == "":
						continue
					var 序: int = Quest._境界序.find(境)
					if 序 > 最高序:
						最高序 = 序
						最高 = 境
				if 最高 != "":
					return 最高
	return ""


func _取_玉牒履历() -> Array:
	if not is_instance_valid(Game):
		return []
	var v: Variant = Game.get("宗门纪事")
	if v == null:
		return []
	var 全部: Array = v
	var 过滤后: Array = []
	for e in 全部:
		if e == null:
			continue
		if str(e.get("category", "")) == "宗门大事件":
			过滤后.append(e)
	过滤后.sort_custom(func(a, b): return int(a.get("日", 0)) > int(b.get("日", 0)))
	var out: Array = []
	for i in range(min(过滤后.size(), _履历上限)):
		out.append(过滤后[i])
	return out


func _on_back_pressed() -> void:
	返回主页.emit()


func _on_edit_pressed() -> void:
	编辑请求.emit()


func _on_skin_pressed() -> void:
	宗主皮肤请求.emit()


func _on_auth_pressed(分类: String) -> void:
	权责请求.emit(分类)


func _on_history_more_pressed() -> void:
	权责请求.emit("宗门纪事")
