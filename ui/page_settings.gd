extends Control

# 设置（GameUI 二级页）：音频 / 画面 / 通知 / 推演 / 账号 / 关于 分组开关与值展示。
# 2026-08-21 收尾：开关/值全部持久化至 Game.设置项（存档），画质/推演速度可点循环；
# 音频开关为配置持久化（项目当前无 AudioServer 总线，暂不实际控制声音）。账号/退出为占位（账号功法 P1 未接）。

signal 返回主页
signal 登出请求

var _built: bool = false
var _开关: Dictionary = {}

func _ready() -> void:
	_build()
	refresh()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)
	_build_header(vbox)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(inner)
	_build_section(inner, "音频", [{"标签": "背景音乐", "开": _取("背景音乐", true)}, {"标签": "音效", "开": _取("音效", true)}])
	_build_section(inner, "画面", [
		{"标签": "画境", "键": "画质", "值": _取("画质", "精"), "选项": ["精", "中", "简"], "占位": true},
		# ★ 2026-09-16（#18）：UITheme.动效强度 此前只有定义、无任何入口。手机端省电 + 晕动症友好刚需。
		{"标签": "减少动效", "开": _取("减少动效", false)}
	])
	_build_section(inner, "通知", [{"标签": "通知推送", "开": _取("通知推送", true)}])
	_build_section(inner, "推演", [
		{"标签": "天机流转", "键": "推演速度", "值": _取("推演速度", "常"), "选项": ["常", "速", "亟"], "占位": true},
		{"标签": "斗法纪略", "键": "战斗模式", "值": _取("战斗模式", "逐式"), "选项": ["逐式", "概略"]}
	])
	_build_section(inner, "账号", [{"标签": "玉牒铭刻", "值": "已铭刻"}])
	_build_section(inner, "关于", [{"标签": "关于本作", "值": "v1.0.0"}])
	var 退出: Button = Button.new()
	退出.name = "Logout"
	退出.text = "辞山归隐"
	退出.custom_minimum_size = Vector2(0, 48)
	UITheme.apply_button_label(退出, true)
	退出.add_theme_color_override("font_color", Color(0.98, 0.95, 0.92))
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.549, 0.290, 0.247)
	sb.set_corner_radius_all(8)
	退出.add_theme_stylebox_override("normal", sb)
	退出.pressed.connect(_on_退出)
	inner.add_child(退出)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("设置", _on_back_pressed, [], "设置", "宗门规制：音律、画境、玉牒封存。\n宜常封存玉牒，以防讯息散佚。"))
func _build_section(parent: Control, 标题: String, 行列表: Array) -> void:
	var 标题标签 := Label.new()
	标题标签.text = 标题
	UITheme.apply_section_title(标题标签)
	parent.add_child(标题标签)
	var 序号 := 0
	for r in 行列表:
		var 行节点 := _建行(r)
		parent.add_child(行节点)
		行节点.modulate.a = 0.0
		var 入场 := 行节点.create_tween()
		入场.tween_property(行节点, "modulate:a", 1.0, 0.2).set_delay(float(序号) * 0.04)
		序号 += 1

func _建行(r: Dictionary) -> Control:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Row_" + str(r.get("标签", ""))
	card.custom_minimum_size = Vector2(0, 44)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
	sb.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", sb)
	var 行 := HBoxContainer.new()
	行.add_theme_constant_override("margin_left", 16)
	行.add_theme_constant_override("margin_right", 16)
	行.add_theme_constant_override("margin_top", 10)
	行.add_theme_constant_override("margin_bottom", 10)
	行.add_theme_constant_override("separation", UITheme.GRID)
	行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(行)
	var 标签 := Label.new()
	标签.text = str(r.get("标签", ""))
	标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_text(标签)
	行.add_child(标签)
	if r.has("开"):
		var 开: bool = bool(r.get("开", false))
		var 键: String = str(r.get("键", r.get("标签", "")))
		var btn: Button = _make_switch(开)
		btn.pressed.connect(_on_开关.bind(键, btn))
		_开关[键] = btn
		行.add_child(btn)
	elif r.has("选项"):
		var 选项 = r["选项"]
		var 当前值: String = str(r.get("值", 选项[0]))
		var val_btn = Button.new()
		val_btn.flat = true
		val_btn.text = 当前值
		val_btn.custom_minimum_size = Vector2(120, 32)
		val_btn.pressed.connect(_on_值切换.bind(str(r.get("键", r.get("标签", ""))), 选项, val_btn))
		_style_val_btn(val_btn)
		# 占位字段：游戏内未实装（UI 持久化已落地），灰显防误导玩家以为有效果
		if bool(r.get("占位", false)):
			val_btn.disabled = true
			val_btn.tooltip_text = "此法尚未传下，暂寄于玉牒备用"
		行.add_child(val_btn)
	elif r.has("值"):
		var 值 := Label.new()
		值.text = str(r.get("值", ""))
		值.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UITheme.apply_value_text(值)
		行.add_child(值)
	return card

func _make_switch(开: bool) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(88, 20)
	b.text = "开" if 开 else "关"
	_style_switch(b, 开)
	return b

func _style_switch(b: Button, 开: bool) -> void:
	b.text = "开" if 开 else "关"
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.784, 0.659, 0.416) if 开 else UITheme.获取面板底色()
	sb.set_corner_radius_all(10)
	b.add_theme_stylebox_override("normal", sb)
	UITheme.apply_button_label(b, true)
	b.add_theme_color_override("font_color", Color(0.043, 0.078, 0.094) if 开 else UITheme.获取主文字色())

func _on_开关(键: String, b: Button) -> void:
	var 开: bool = (b.text != "开")
	_style_switch(b, 开)
	_开关[键] = b
	_存(键, 开)
	# ★ 2026-09-16（#18）：动效开关**立即生效**（红点呼吸 / 页面入场 / 列表错峰全部受 动效强度 门控）。
	if 键 == "减少动效" and is_instance_valid(UITheme):
		UITheme.应用动效偏好(开)

# ───────── 设置持久化（Game.设置项）─────────
func _默认() -> Dictionary:
	return {"背景音乐": true, "音效": true, "通知推送": true, "画质": "精", "推演速度": "常", "战斗模式": "逐式", "减少动效": false}

func _取(键: String, 缺省 = null):
	var d = _默认()
	var def = 缺省 if 缺省 != null else d.get(键, null)
	if is_instance_valid(Game) and Game.has_method("get"):
		var s = Game.get("设置项")
		if s is Dictionary and s.has(键):
			return s[键]
	return def

func _存(键: String, 值) -> void:
	if is_instance_valid(Game):
		if not (Game.get("设置项") is Dictionary):
			Game.设置项 = {}
		Game.设置项[键] = 值
		if Game.has_method("save_game"):
			Game.save_game()

func _style_val_btn(b: Button) -> void:
	b.add_theme_color_override("font_color", UITheme.获取金文字色())
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.获取面板底色()
	sb.border_color = UITheme.获取金文字色()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	UITheme.apply_body_font_sized(b, UITheme.FONT_BODY)

func _on_值切换(键: String, 选项: Array, btn: Button) -> void:
	var 当前: String = btn.text
	var i: int = 选项.find(当前)
	i = (i + 1) % 选项.size()
	var 新: String = str(选项[i])
	btn.text = 新
	_存(键, 新)
	# 战斗模式切换：更新Game.战斗模式（完整结算→full，加速结算→quick）
	if 键 == "战斗模式" and is_instance_valid(Game):
		Game.战斗模式 = "full" if 新 == "逐式" else "quick"

func refresh() -> void:
	if not _built:
		_build()

func _on_退出() -> void:
	# 退出登录：通知上层（game_ui → main）执行账号功法登出流程，回到登录/选择面板。
	登出请求.emit()

func _on_back_pressed() -> void:
	返回主页.emit()

