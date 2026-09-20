# ui/section_helper.gd
# 共享「分区（section）」构建工具：殿阁 page_building / 弟子 page_disciple 等详情页复用，
# 避免每页各写 ~80 行重复的「面板 + 标题 + KV 行 + 进度条」逻辑。
# 纯 static 工具类（UITheme 为 Autoload 单例，全局可达，static 上下文可直接调用）。
# 各页既有视觉差异（墨纹面板 / 标题字体 / 左标签宽度 / 是否内嵌内容层）通过参数保留，不强行统一。

class_name SectionHelper
extends RefCounted

# 创建带标题的分区面板，返回「内容容器」（调用方往里塞 KV 行 / 自定义控件）。
# 参数用于保留各页既有视觉差异（非统一硬改）：
#   parent            内容挂载的父节点（详情页滚动 vbox，如 _detail_vbox）
#   use_ink           面板是否带墨纹（弟子=true / 殿阁=false；等价原 make_panel_stylebox(use_ink)）
#   title_style      "section"=apply_section_title（弟子，米白大标题）/ "title"=apply_title_font（殿阁，金标题）
#   dot_type         "" 无点；非 "" 在标题右侧加红点（弟子 "danger"/"gold" 共用同一红点，与历史行为一致）
#   nested           是否在标题下再嵌一层 content vbox（殿阁=true / 弟子=false）
static func add_section(parent: Control, 标题: String, use_ink: bool = true, title_style: String = "section", dot_type: String = "", nested: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.name = "Section_%s" % 标题
	UITheme.apply_panel_style(panel, use_ink)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	panel.add_child(vbox)
	vbox.add_child(make_section_title(标题, dot_type))
	var content := vbox
	if nested:
		content = VBoxContainer.new()
		content.add_theme_constant_override("separation", UITheme.GRID)
		vbox.add_child(content)
	parent.add_child(panel)
	return content

# 标题行（含可选红点）；返回 HBoxContainer，可直接 add_child 到任意容器。
static func make_section_title(标题: String, dot_type: String = "") -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var t := Label.new()
	t.text = 标题
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_section_title(t)
	hb.add_child(t)
	if dot_type != "":
		hb.add_child(_make_red_dot())
	return hb

static func _make_red_dot() -> Panel:
	# 统一红点样式（大厂标准：红色圆形+白色描边）；danger/gold 历史均共用此红点（与历史行为一致）
	var dot: Panel = UITheme.make_red_dot(12.0)
	dot.name = "RedDot"
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return dot

# KV 行：左标题 / 右值；支持异常高亮 + 颜色覆盖 + 自动换行 + 左对齐。
#   caption_min_width  左标签最小宽度（弟子=96 / 殿阁=GRID*12=144）
static func add_kv(parent: Control, caption: String, value: String, abnormal: bool = false, color_override: Color = Color.WHITE, caption_min_width: int = 96) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.custom_minimum_size = Vector2(caption_min_width, 0)
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if abnormal:
		UITheme.apply_value_font(v, true)
	elif color_override != Color.WHITE:
		UITheme.apply_body_font(v)
		v.add_theme_color_override("font_color", color_override)
	else:
		UITheme.apply_body_font(v)
	hb.add_child(v)
	parent.add_child(hb)

# 自绘进度条（标题 + 百分比 + track/fill），禁用内置百分比，自绘 % 标签。
# 等价原 page_disciple._make_progress（track=COLOR_BG_CONTENT，fill 传入配色）。
static func make_progress(caption: String, ratio: float, fill_color: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UITheme.GRID / 2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var c := Label.new()
	c.text = caption
	c.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	UITheme.apply_aux_font(c)
	hb.add_child(c)
	var pct := Label.new()
	pct.text = "%d%%" % int(clamp(ratio, 0.0, 1.0) * 100.0)
	UITheme.apply_value_font(pct, false)
	hb.add_child(pct)
	box.add_child(hb)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.01
	bar.value = clamp(ratio, 0.0, 1.0)
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, UITheme.GRID * 2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UITheme.COLOR_BG_CONTENT
	bg.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	bg.set_content_margin_all(0)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(UITheme.RADIUS_BUTTON)
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("disabled", bg)
	box.add_child(bar)
	return box
