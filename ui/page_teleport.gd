extends Control
# S34c §11.17 传送阵：独立「传送调度」设施（物流方式，与陆路商队形成 慢/险/廉/大量 vs 快/零险/贵/小量 取舍）
# 入口：main.gd 宗门页快捷网格「传送阵」→ 二级页。
# 货币复用宗门灵石（不新建货币）；价值/重量复用 _拍卖品阶基准 / 品阶序（零新增字段）。
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 .bind 避免闭包捕获循环变量；UITheme 0 臆造。

signal 返回主页

var _built: bool = false
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _提示: String = ""
var _选中城市: String = ""          # city_id
var _选中货物: Array = []           # 宗门库房索引数组

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _on_back_pressed() -> void:
	返回主页.emit()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	_body = VBoxContainer.new()
	_body.name = "Root"
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.GRID)
	_body.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_body.add_theme_constant_override("separation", UITheme.GRID)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)
	_build_header()
	_build_content_area()

func _build_header() -> void:
	var 灵石标: Label = Label.new()
	灵石标.text = "宗门灵石：%d" % Game.灵石
	UITheme.apply_aux_text(灵石标)
	_body.add_child(UITheme.建顶栏("太玄传送阵", _on_back_pressed, [灵石标]))

func _build_content_area() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_content)

func refresh() -> void:
	if not _built:
		_build()
	for c in _content.get_children():
		c.queue_free()
	if _提示 != "":
		var 提示: Label = Label.new()
		提示.text = _提示
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		提示.add_theme_color_override("font_color", UITheme.color_value(false))
		_content.add_child(提示)
		_提示 = ""
	_populate()

func _card() -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(p, true)
	_content.add_child(p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	# PanelContainer 自身无子节点，必须先挂 VBox 再返回（原 p.get_child(0) 恒为 null）
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.25)
	return v

func _label(文: String, 主: bool) -> Label:
	var l: Label = Label.new()
	l.text = 文
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if 主:
		UITheme.apply_body_text(l)
	else:
		UITheme.apply_aux_text(l)
	return l

func _段标题(文: String) -> void:
	var l: Label = Label.new()
	l.text = 文
	UITheme.apply_body_text(l)
	_content.add_child(l)

func _populate() -> void:
	if not Game.enable_teleport_system:
		_content.add_child(_label("传送阵系统已关闭（总控开关 enable_teleport_system = false）", true))
		return
	_建造区()
	_调度区()

func _建造区() -> void:
	_段标题("◆ 传送阵·建造与升级")
	var 信息: Dictionary = Game.传送阵建造信息()
	if 信息.get("建造中", false):
		var 卡: VBoxContainer = _card()
		var _fb1 := _label("传送阵建造中（目标%d品），预计第%d日完工" % [int(信息.get("目标档", 0)), int(信息.get("完成日", 0))], true)
		卡.add_child(_fb1)
		_fb1.modulate.a = 0.0
		_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
		return
	if not 信息.get("可建", false):
		var 卡2: VBoxContainer = _card()
		if 信息.get("已满", false):
			var _fb2 := _label("已达当前可建最高品级——跨界传送阵（ta05-06）需灵界通道开启后方可兴建", true)
			卡2.add_child(_fb2)
			_fb2.modulate.a = 0.0
			_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
		else:
			var _fb3 := _label("（暂无可达的传送阵档位配置）", false)
			卡2.add_child(_fb3)
			_fb3.modulate.a = 0.0
			_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
		return
	var 卡: VBoxContainer = _card()
	var _fb4 := _label("可兴建：%s（%d品）" % [str(信息.get("名称", "")), int(信息.get("等级", 0))], true)
	卡.add_child(_fb4)
	_fb4.modulate.a = 0.0
	_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)
	var _fb5 := _label("覆盖距离 %d ｜ 最大载重 %d ｜ 每日可传送 %d 次 ｜ 单次基费 %d ＋ 每重 %s" % [int(信息.get("max_range", 0)), int(信息.get("max_carry", 0)), int(信息.get("daily_use_count", 0)), int(信息.get("per_use_base_cost", 0)), str(信息.get("per_weight_cost", 0.0))], false)
	卡.add_child(_fb5)
	_fb5.modulate.a = 0.0
	_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	var _fb6 := _label("需宗门品级 %d ｜ 祭炼工费 %d 灵石 ｜ 工期 %d 日 ｜ 每日待机 %d 灵石" % [int(信息.get("需门派等级", 99)), int(信息.get("工费", 0)), int(信息.get("时日", 0)), int(信息.get("daily_standby_cost", 0))], false)
	卡.add_child(_fb6)
	_fb6.modulate.a = 0.0
	_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	for m in 信息.get("材料", []):
		var 足: bool = int(m.get("有", 0)) >= int(m.get("需", 0))
		var 标: String = "✓" if 足 else "×"
		var _fb7 := _label("　灵材 %s：需 %d ／ 现存 %d  %s" % [str(m.get("名", "")), int(m.get("需", 0)), int(m.get("有", 0)), 标], false)
		卡.add_child(_fb7)
		_fb7.modulate.a = 0.0
		_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	var 钮: Button = Button.new()
	钮.text = "动工兴建 %s" % str(信息.get("名称", ""))
	钮.custom_minimum_size = Vector2(0, int(round(38.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(钮)
	钮.pressed.connect(_建传送阵)
	卡.add_child(钮)
	钮.modulate.a = 0.0
	钮.create_tween().tween_property(钮, "modulate:a", 1.0, 0.25)

func _建传送阵() -> void:
	var 果: Dictionary = Game.建造传送阵()
	_提示 = str(果.get("消息", ""))
	refresh()

func _调度区() -> void:
	_段标题("◆ 传送调度（瞬时货运·就地售卖）")
	if not Game.已建传送阵():
		_content.add_child(_label("建成传送阵后方可瞬时传送货物（见上方建造区）", false))
		return
	if not Game.传送阵建造中.is_empty():
		_content.add_child(_label("传送阵建造/升级中，暂不可调度", false))
		return
	if Game.传送阵待机欠费:
		var 警: Label = _label("⚠ 传送阵待机灵石不足，已暂停运转——补足每日待机灵石后自动恢复", false)
		警.add_theme_color_override("font_color", UITheme.color_value(false))
		_content.add_child(警)
	var 档: Dictionary = Game.传送阵当前档()
	if 档.is_empty():
		return
	var 范围: int = int(档.get("max_range", 0))
	var 载重: int = int(档.get("max_carry", 0))
	var 日限: int = int(档.get("daily_use_count", 0))
	_content.add_child(_label("当前档位：覆盖距离 %d ｜ 最大载重 %d ｜ 每日已用 %d/%d 次" % [范围, 载重, Game.传送阵今日已用, 日限], false))
	_城邦选择()
	_货物选择()
	_预览与传送(档)

func _城邦选择() -> void:
	_段标题("　① 选择目标城邦")
	var 城列: Array = Game.传送阵可达城邦()
	if 城列.is_empty():
		_content.add_child(_label("（当前档位无可达城邦，需升级传送阵以扩大覆盖范围）", false))
		return
	for 城 in 城列:
		var cid: String = str(城.get("city_id", ""))
		var 选中: bool = (cid == _选中城市)
		var 率文: String = "%.2f" % float(城.get("base_price_rate", 1.0))
		var 钮: Button = Button.new()
		钮.text = ("▶ " if 选中 else "　") + "%s（%d级·距离%d·售卖率%s）" % [str(城.get("city_name", cid)), int(城.get("city_level", 1)), Game._传送距离(城), 率文]
		钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(钮)
		钮.pressed.connect(_选城邦.bind(cid))
		_content.add_child(钮)
		钮.modulate.a = 0.0
		钮.create_tween().tween_property(钮, "modulate:a", 1.0, 0.25)

func _选城邦(cid_arg: String) -> void:
	_选中城市 = cid_arg
	refresh()

func _货物选择() -> void:
	_段标题("　② 勾选要传送的货物（宗门库房）")
	var 库: Array = Game.宗门库房
	if 库.is_empty():
		_content.add_child(_label("（宗门库房暂无货物）", false))
		return
	for i in 库.size():
		var it: Item = 库[i]
		if it == null:
			continue
		var 选中: bool = _选中货物.has(i)
		var 重: int = Game._物品传送重量(it)
		var 值: int = Game._物品传送价值(it)
		var 钮: Button = Button.new()
		钮.text = ("✓ " if 选中 else "□ ") + "%s（%s·重%d·值%d）" % [str(it.名称), str(it.品阶), 重, 值]
		钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(钮)
		钮.pressed.connect(_切换货物.bind(i))
		_content.add_child(钮)
		钮.modulate.a = 0.0
		钮.create_tween().tween_property(钮, "modulate:a", 1.0, 0.25)

func _切换货物(i: int) -> void:
	if _选中货物.has(i):
		_选中货物.erase(i)
	else:
		_选中货物.append(i)
	refresh()

func _预览与传送(档: Dictionary) -> void:
	var 总重: int = 0
	var 货值: int = 0
	for i in _选中货物:
		var it: Item = Game.宗门库房[i]
		if it == null:
			continue
		总重 += Game._物品传送重量(it)
		货值 += Game._物品传送价值(it)
	var 载重: int = int(档.get("max_carry", 0))
	var 基费: int = int(档.get("per_use_base_cost", 0))
	var 重费: float = float(档.get("per_weight_cost", 0.0))
	var 成本: int = 基费 + int(float(总重) * 重费)
	var 超重: bool = (载重 > 0 and 总重 > 载重)
	_段标题("　③ 传送预览")
	var 重文: String = "已选 %d 件 ｜ 总重 %d / 最大载重 %d%s" % [_选中货物.size(), 总重, 载重, "（超重！）" if 超重 else ""]
	var 重标: Label = _label(重文, false)
	if 超重:
		重标.add_theme_color_override("font_color", UITheme.color_value(false))
	_content.add_child(重标)
	if _选中城市 != "":
		var 城: Dictionary = Game.商队系统.商队城市表.get(_选中城市, null)
		if 城 != null:
			var 城率: float = float(城.get("base_price_rate", 1.0))
			var 预估收益: int = int(float(货值) * 城率)
			_content.add_child(_label("目标城邦：%s（售卖率 %.2f）" % [str(城.get("city_name", "")), 城率], false))
			_content.add_child(_label("预估货值 %d ｜ 预估售价 %d 灵石 ｜ 传送费 %d 灵石" % [货值, 预估收益, 成本], false))
	else:
		_content.add_child(_label("预估货值 %d ｜ 传送费 %d 灵石（请选择目标城邦查看预估售价）" % [货值, 成本], false))
	var 传送钮: Button = Button.new()
	传送钮.text = "发动传送阵·瞬时货运并就地售卖"
	传送钮.custom_minimum_size = Vector2(0, int(round(40.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(传送钮)
	传送钮.disabled = (_选中城市 == "" or _选中货物.is_empty() or 超重 or Game.传送阵待机欠费)
	传送钮.pressed.connect(_发动传送)
	_content.add_child(传送钮)

func _发动传送() -> void:
	if _选中城市 == "" or _选中货物.is_empty():
		_提示 = "请先选择目标城邦并勾选货物"
		refresh()
		return
	var 果: Dictionary = Game.传送调度(_选中城市, _选中货物.duplicate())
	if bool(果.get("成功", false)):
		_提示 = "传送成功！%s 售得 %d 灵石（传送费 %d），商路声望+%d" % [str(果.get("城市", "")), int(果.get("收益", 0)), int(果.get("成本", 0)), int(果.get("声望", 0))]
		_选中货物 = []
	else:
		_提示 = str(果.get("消息", "传送失败"))
	refresh()
