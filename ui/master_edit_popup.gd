extends Control

# 宗主改名弹窗（全屏暗底模态）。
# 复用 avatar_select_popup 的 CanvasLayer 模态范式：由 game_ui 以
# Control.new() + set_script(load(...)) 实例化并挂 CanvasLayer(layer=101) 容器。
# 仅改宗主名（玩家自定身份，非战斗/经济字段）；确认时直接写 Game.宗主名
# （与 main.gd 创建宗门时 `Game.宗主名 = 宗主名` 同源安全写），零玩法/战斗触碰。
# 消耗道具：易名玉牒（有牒耗牒，无牒则耗仙玉直接购牒使用）。

signal 宗主名已改(新名: String)

# ── 逻辑坐标（480×854）→ 物理（×UI_SCALE）；本弹窗根即满屏，子节点用 _place 物理定位 ──
const 屏宽: float = 480.0
const 屏高: float = 854.0
const 边距: float = 40.0

var _built: bool = false
var _name_edit: LineEdit = null
var _shade: ColorRect = null
var _card_hint: Label = null

func _ready() -> void:
	_build()

func _build() -> void:
	if _built:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 暗底遮罩（点遮罩关闭）
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(UITheme.C01_SCENE_BASE, 1.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_on_cancel())
	add_child(_shade)

	# 主面板：暗底 + 金描边 + 圆角（与头像弹窗同款浮层样式）
	var 面板 := Panel.new()
	面板.name = "MainPanel"
	_place(面板, 边距, 300.0, 屏宽 - 边距 * 2.0, 254.0)
	面板.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var 面板样式 := StyleBoxFlat.new()
	面板样式.bg_color = UITheme.C01_FLOAT_BG
	面板样式.border_color = UITheme.C01_TEXT_GOLD
	面板样式.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	面板样式.set_border_width_all(int(round(2.0 * UITheme.UI_SCALE)))
	面板样式.set_content_margin_all(0)
	面板.add_theme_stylebox_override("panel", 面板样式)
	add_child(面板)

	_build_title()
	_build_input()
	_build_bottom()

	_built = true

func _build_title() -> void:
	var title := Label.new()
	title.name = "Title"
	_place(title, 边距, 316.0, 屏宽 - 边距 * 2.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.text = "宗主易名"
	UITheme.apply_title_font_sized(title, int(round(20.0 * UITheme.UI_SCALE)))
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	add_child(title)

	# 副标题提示
	var hint := Label.new()
	hint.name = "SubTitle"
	_place(hint, 边距, 356.0, 屏宽 - 边距 * 2.0, 22.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.text = "修改宗主名（仅显示用，不影响数值）"
	UITheme.apply_body_font_sized(hint, int(round(12.0 * UITheme.UI_SCALE)))
	hint.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	add_child(hint)
	# 易名玉牒数量提示
	var card_hint := Label.new()
	card_hint.name = "CardHint"
	_place(card_hint, 边距, 378.0, 屏宽 - 边距 * 2.0, 20.0)
	card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_hint.text = "易名玉牒: 0 张（无牒则消耗 %d 仙玉直接购牒并使用）" % Game.改名卡仙玉价格
	UITheme.apply_body_font_sized(card_hint, int(round(11.0 * UITheme.UI_SCALE)))
	card_hint.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	add_child(card_hint)
	_card_hint = card_hint

func _build_input() -> void:
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_place(_name_edit, 边距 + 24.0, 404.0, 屏宽 - 边距 * 2.0 - 48.0, 44.0)
	_name_edit.placeholder_text = "请输入宗主名"
	_name_edit.max_length = 12
	_name_edit.right_icon = null
	UITheme.apply_body_font_sized(_name_edit, int(round(15.0 * UITheme.UI_SCALE)))
	_name_edit.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	_name_edit.add_theme_color_override("caret_color", UITheme.C01_TEXT_GOLD)
	_name_edit.add_theme_color_override("placeholder_color", UITheme.C01_TEXT_TERTIARY)
	var le_sb: StyleBoxFlat = UITheme.make_panel_stylebox_flat(UITheme.C01_SCENE_BASE, UITheme.C01_TEXT_GOLD, 8, 1)
	_name_edit.add_theme_stylebox_override("normal", le_sb)
	_name_edit.add_theme_stylebox_override("focus", le_sb)
	_name_edit.add_theme_stylebox_override("pressed", le_sb)
	_name_edit.add_theme_stylebox_override("hover", le_sb)
	add_child(_name_edit)

func _build_bottom() -> void:
	var by: float = 492.0
	var bw: float = (屏宽 - 边距 * 2.0 - 48.0) * 0.5
	var bh: float = 44.0

	var confirm := Button.new()
	confirm.name = "ConfirmBtn"
	confirm.text = "确认易名"
	_place(confirm, 边距 + 24.0, by, bw, bh)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	var c正常: StyleBoxFlat = UITheme.make_panel_stylebox_flat(UITheme.COLOR_BTN_PRIMARY, UITheme.COLOR_BTN_PRIMARY, 8, 2)
	var c按下: StyleBoxFlat = UITheme.make_panel_stylebox_flat(
		Color(UITheme.COLOR_BTN_PRIMARY.r * 0.8, UITheme.COLOR_BTN_PRIMARY.g * 0.8, UITheme.COLOR_BTN_PRIMARY.b * 0.8),
		UITheme.COLOR_BTN_PRIMARY, 8, 2)
	confirm.add_theme_stylebox_override("normal", c正常)
	confirm.add_theme_stylebox_override("pressed", c按下)
	confirm.add_theme_stylebox_override("hover", c正常)
	confirm.add_theme_stylebox_override("focus", c正常)
	UITheme.apply_title_font_sized(confirm, int(round(14.0 * UITheme.UI_SCALE)))
	confirm.add_theme_color_override("font_color", UITheme.COLOR_TEXT_TITLE2)
	confirm.pressed.connect(_on_confirm)
	add_child(confirm)

	var cancel := Button.new()
	cancel.name = "CancelBtn"
	cancel.text = "作罢"
	_place(cancel, 边距 + 24.0 + bw + 16.0, by, bw, bh)
	cancel.mouse_filter = Control.MOUSE_FILTER_STOP
	var x正常: StyleBoxFlat = UITheme.make_panel_stylebox_flat(Color(UITheme.C01_SCENE_BASE, 1.0), UITheme.C01_TEXT_GOLD, 8, 2)
	var x按下: StyleBoxFlat = UITheme.make_panel_stylebox_flat(
		Color(UITheme.C01_SCENE_BASE.r * 0.8, UITheme.C01_SCENE_BASE.g * 0.8, UITheme.C01_SCENE_BASE.b * 0.8, 1.0),
		UITheme.C01_TEXT_GOLD, 8, 2)
	cancel.add_theme_stylebox_override("normal", x正常)
	cancel.add_theme_stylebox_override("pressed", x按下)
	cancel.add_theme_stylebox_override("hover", x正常)
	cancel.add_theme_stylebox_override("focus", x正常)
	UITheme.apply_title_font_sized(cancel, int(round(14.0 * UITheme.UI_SCALE)))
	cancel.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	cancel.pressed.connect(_on_cancel)
	add_child(cancel)

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	var s: float = UITheme.UI_SCALE
	c.layout_mode = 0
	c.offset_left = x * s
	c.offset_top = y * s
	c.offset_right = (x + w) * s
	c.offset_bottom = (y + h) * s
	c.size = Vector2(w * s, h * s)

# 唤起 / 关闭：复用常驻实例，仅切换可见性，零重建。
func 唤起() -> void:
	if not _built:
		_build()
	if _name_edit != null:
		if is_instance_valid(Game):
			_name_edit.text = Game.宗主名
			_name_edit.set_caret_column(_name_edit.text.length())
			_name_edit.grab_focus()
	# 更新易名玉牒数量显示
	if _card_hint != null and is_instance_valid(Game):
		_card_hint.text = "易名玉牒: %d 张（无牒则消耗 %d 仙玉直接购牒并使用）" % [Game.改名卡数量, Game.改名卡仙玉价格]
	visible = true

func 关闭() -> void:
	visible = false

func _on_confirm() -> void:
	var 新名: String = _name_edit.text.strip_edges()
	if 新名 == "":
		关闭()
		return
	if not is_instance_valid(Game):
		return
	# 易名玉牒逻辑：有牒则消耗1张，无牒则用仙玉直接购牒并使用
	if Game.改名卡数量 > 0:
		Game.改名卡数量 -= 1
		print("[易名弹窗] 使用易名玉牒1张，剩余: %d" % Game.改名卡数量)
	else:
		var 价格: int = Game.改名卡仙玉价格
		var 总仙玉: int = Game.仙玉_绑定 + Game.仙玉_非绑定
		if 总仙玉 < 价格:
			print("[易名弹窗] 仙玉不足，需要 %d，当前 %d" % [价格, 总仙玉])
			return
		# 优先扣绑定仙玉
		if Game.仙玉_绑定 >= 价格:
			Game.仙玉_绑定 -= 价格
		else:
			var 剩余: int = 价格 - Game.仙玉_绑定
			Game.仙玉_绑定 = 0
			Game.仙玉_非绑定 -= 剩余
		print("[易名弹窗] 无易名玉牒，消耗 %d 仙玉购牒并易名" % 价格)
	Game.宗主名 = 新名
	宗主名已改.emit(新名)
	关闭()

func _on_cancel() -> void:
	关闭()

