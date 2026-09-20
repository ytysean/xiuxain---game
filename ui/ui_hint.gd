extends CanvasLayer

## 全局详情弹窗 Autoload：UIHint.show_hint(anchor, "标题", "说明")
## 点击任意处关闭。

var _shade: ColorRect
var _panel: PanelContainer
var _anchor: Control
var _locate_pending: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_hint(anchor: Control, title: String, body: String) -> void:
	_close()
	_anchor = anchor
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.01)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	_panel = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.122, 0.169, 0.192, 0.97)
	psb.border_color = Color(0.78, 0.65, 0.34, 0.8)
	psb.set_border_width_all(1)
	psb.set_corner_radius_all(8)
	psb.content_margin_left = 20; psb.content_margin_right = 20
	psb.content_margin_top = 14; psb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", psb)
	_shade.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_panel.add_child(vb)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_color_override("font_color", Color(0.91, 0.83, 0.60))
	UITheme.apply_project_font(tl, UITheme.FONT_H1, true)
	vb.add_child(tl)
	var bl := Label.new()
	bl.text = body
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.custom_minimum_size = Vector2(600, 0)
	bl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.90))
	# ★ 2026-09-15 修复：正文原用 FONT_TITLE(45)+Bold，与标题 FONT_H1(48) 几乎同大 → 弹窗失衡。
	#   正文回落 FONT_BODY(27) 常规字重，与全局正文口径一致。
	UITheme.apply_project_font(bl, UITheme.FONT_BODY, false)
	vb.add_child(bl)
	# 气泡入场：只做 scale/alpha。定位要等下一帧 _process 拿到面板真实尺寸后才算，
	# 这里若补间 position 会与随后的定位互相打架（两处写同一属性）。
	UITheme.弹窗入场(_panel, null, 0.16, true)
	_locate_pending = true

func _process(_dt: float) -> void:
	if not _locate_pending or _panel == null:
		return
	if _panel.size.x < 10:
		return
	_locate_pending = false
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ap: Vector2 = Vector2(vp.x * 0.5, vp.y * 0.4)
	if _anchor != null and is_instance_valid(_anchor):
		ap = _anchor.global_position + Vector2(_anchor.size.x * 0.5, _anchor.size.y)
	var pw: float = _panel.size.x
	var ph: float = _panel.size.y
	var px: float = ap.x - pw * 0.5
	var py: float = ap.y + 12
	if py + ph > vp.y - 120:
		py = ap.y - ph - 12
	px = clampf(px, 8, vp.x - pw - 8)
	py = clampf(py, 100, vp.y - ph - 120)
	_panel.position = Vector2(px, py)

func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()

func _close() -> void:
	if _shade != null and is_instance_valid(_shade):
		_shade.queue_free()
	_shade = null
	_panel = null
	_locate_pending = false
