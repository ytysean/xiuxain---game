extends Control

# ===== S58 世界大地图UI =====
# 山门入口打开，显示宗门位置、周边城镇、其他宗门
# 符合修真世界观：俯瞰天下，指点江山


var _content: VBoxContainer = null
var _提示: String = ""

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# 背景
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.1, 0.95)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 主容器
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# 标题栏
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)

	var title: Label = Label.new()
	title.text = "🗺️ 天下舆图"
	title.add_theme_font_size_override("font_size", UITheme.FONT_H1)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(title)

	header.add_spacer(false)

	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 36)
	UITheme.apply_secondary_button_style(close_btn)
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 宗门位置信息
	var 位置信息: HBoxContainer = HBoxContainer.new()
	位置信息.add_theme_constant_override("separation", 16)
	main.add_child(位置信息)

	var 位置: Dictionary = Game.世界地图系统.获取宗门位置()
	var 区域标签: Label = Label.new()
	区域标签.text = "📍 所在：%s" % str(位置["区域"])
	区域标签.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	区域标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	位置信息.add_child(区域标签)

	var 坐标标签: Label = Label.new()
	坐标标签.text = "坐标：(%.0f, %.0f)" % [float(位置["x"]), float(位置["y"])]
	坐标标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	坐标标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	位置信息.add_child(坐标标签)

	var 特性: Dictionary = Game.世界地图系统.获取当前区域特性()
	var 特性标签: Label = Label.new()
	特性标签.text = str(特性.get("描述", ""))
	特性标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	特性标签.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	特性标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	位置信息.add_child(特性标签)

	# 页签栏
	var tab_bar: HBoxContainer = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	main.add_child(tab_bar)

	var 页签列表: Array = ["周边城镇", "附近宗门", "区域总览"]
	for 页签 in 页签列表:
		var btn: Button = Button.new()
		btn.text = 页签
		btn.custom_minimum_size = Vector2(0, 32)
		UITheme.apply_secondary_button_style(btn)
		btn.pressed.connect(func(t=页签):
			_显示页签(t)
		)
		tab_bar.add_child(btn)

	# 滚动区域
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)

	# 默认显示周边城镇
	_显示周边城镇()

func _显示页签(页签: String) -> void:
	match 页签:
		"周边城镇":
			_显示周边城镇()
		"附近宗门":
			_显示附近宗门()
		"区域总览":
			_显示区域总览()

func _显示周边城镇() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "🏘️ 周边城镇（按距离排序）"
	标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	var 城镇列表: Array = Game.世界地图系统.获取周边城镇(12)
	for 城镇 in 城镇列表:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 60)
		_content.add_child(card)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var 名称标签: Label = Label.new()
		名称标签.text = str(城镇["名称"])
		名称标签.custom_minimum_size = Vector2(120, 0)
		名称标签.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		名称标签.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		hbox.add_child(名称标签)

		var 区域标签: Label = Label.new()
		区域标签.text = "[%s]" % str(城镇["区域"])
		区域标签.custom_minimum_size = Vector2(80, 0)
		区域标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		区域标签.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		hbox.add_child(区域标签)

		var 距离标签: Label = Label.new()
		距离标签.text = "距离：%.0f" % float(城镇["距离"])
		距离标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		距离标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(距离标签)

		hbox.add_spacer(false)

		var 前往钮: Button = Button.new()
		前往钮.text = "前往"
		前往钮.custom_minimum_size = Vector2(80, 28)
		UITheme.apply_secondary_button_style(前往钮)
		前往钮.pressed.connect(func():
			_提示 = "前往%s...（商队贸易功能开发中）" % str(城镇["名称"])
			_显示周边城镇()
		)
		hbox.add_child(前往钮)

	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_content.add_child(tip)
		_提示 = ""

func _显示附近宗门() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "🏯 附近宗门"
	标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	# 确保有模拟宗门
	if Game.世界地图系统.其他宗门列表.is_empty():
		Game.世界地图系统.生成模拟宗门(20)

	var 宗门列表: Array = Game.世界地图系统.其他宗门列表.slice(0, 15)
	for 宗门 in 宗门列表:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 60)
		_content.add_child(card)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var 名称标签: Label = Label.new()
		名称标签.text = str(宗门["名称"])
		名称标签.custom_minimum_size = Vector2(120, 0)
		名称标签.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		名称标签.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5))
		hbox.add_child(名称标签)

		var 区域标签: Label = Label.new()
		区域标签.text = "[%s]" % str(宗门["区域"])
		区域标签.custom_minimum_size = Vector2(80, 0)
		区域标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		区域标签.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		hbox.add_child(区域标签)

		var 战力标签: Label = Label.new()
		战力标签.text = "战力：%s" % _format战力(int(宗门["战力"]))
		战力标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		战力标签.add_theme_color_override("font_color", Color(0.7, 0.5, 0.5))
		hbox.add_child(战力标签)

		var 距离标签: Label = Label.new()
		距离标签.text = "距离：%.0f" % float(宗门["距离"])
		距离标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		距离标签.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		hbox.add_child(距离标签)

		# S58-P2：行军时间
		var 行军时间: int = Game.世界地图系统.计算行军时间(str(宗门["区域"]), float(宗门["x"]), float(宗门["y"]))
		var 行军标签: Label = Label.new()
		行军标签.text = "行军：%d日" % 行军时间
		行军标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		行军标签.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
		hbox.add_child(行军标签)

		hbox.add_spacer(false)

		var 交互钮: Button = Button.new()
		交互钮.text = "交互"
		交互钮.custom_minimum_size = Vector2(80, 28)
		UITheme.apply_secondary_button_style(交互钮)
		交互钮.pressed.connect(func():
			_提示 = "与%s交互...（宗门外交功能开发中）" % str(宗门["名称"])
			_显示附近宗门()
		)
		hbox.add_child(交互钮)

	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_content.add_child(tip)
		_提示 = ""

func _显示区域总览() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var 标题: Label = Label.new()
	标题.text = "🌍 五大区域总览"
	标题.add_theme_font_size_override("font_size", UITheme.FONT_H2)
	标题.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	_content.add_child(标题)

	# S58-P1：宗门迁移信息
	var 迁移信息: PanelContainer = PanelContainer.new()
	迁移信息.custom_minimum_size = Vector2(0, 50)
	_content.add_child(迁移信息)

	var 迁移盒: HBoxContainer = HBoxContainer.new()
	迁移盒.add_theme_constant_override("separation", 12)
	迁移信息.add_child(迁移盒)

	var 迁移标签: Label = Label.new()
	var 冷却剩余: int = Game.世界地图系统.获取迁移冷却剩余()
	if 冷却剩余 > 0:
		迁移标签.text = "🚫 宗门大阵冷却中（还需%d日）" % 冷却剩余
	else:
		迁移标签.text = "✅ 宗门大阵就绪，可举宗迁移"
	迁移标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	迁移标签.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4))
	迁移盒.add_child(迁移标签)

	迁移盒.add_spacer(false)

	var 消耗标签: Label = Label.new()
	消耗标签.text = "迁移消耗：1万灵石 + 5灵晶"
	消耗标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
	消耗标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	迁移盒.add_child(消耗标签)

	for 区域 in Game.世界地图系统.所有区域:
		var 特性: Dictionary = Game.世界地图系统.获取区域特性(区域)
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 100)
		_content.add_child(card)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		var 名称行: HBoxContainer = HBoxContainer.new()
		名称行.add_theme_constant_override("separation", 8)
		vbox.add_child(名称行)

		var 名称标签: Label = Label.new()
		var 当前标记: String = "（当前所在）" if 区域 == Game.世界地图系统.宗门区域 else ""
		名称标签.text = "%s%s" % [区域, 当前标记]
		名称标签.add_theme_font_size_override("font_size", UITheme.FONT_H2)
		if 区域 == Game.世界地图系统.宗门区域:
			名称标签.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			名称标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		名称行.add_child(名称标签)

		名称行.add_spacer(false)

		# S58-P1：迁移按钮
		if 区域 != Game.世界地图系统.宗门区域 and 冷却剩余 == 0:
			var 迁移钮: Button = Button.new()
			迁移钮.text = "迁移至此"
			迁移钮.custom_minimum_size = Vector2(80, 28)
			UITheme.apply_secondary_button_style(迁移钮)
			迁移钮.pressed.connect(func(r=区域):
				_确认迁移(r)
			)
			名称行.add_child(迁移钮)

		var 描述标签: Label = Label.new()
		描述标签.text = str(特性.get("描述", ""))
		描述标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		描述标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		描述标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(描述标签)

		var 加成行: HBoxContainer = HBoxContainer.new()
		加成行.add_theme_constant_override("separation", 16)
		vbox.add_child(加成行)

		var 修炼标签: Label = Label.new()
		修炼标签.text = "修炼加成：+%.0f%%" % (float(特性.get("修炼加成", 0)) * 100)
		修炼标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		修炼标签.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		加成行.add_child(修炼标签)

		var 商路标签: Label = Label.new()
		商路标签.text = "商路加成：+%.0f%%" % (float(特性.get("商路加成", 0)) * 100)
		商路标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		商路标签.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		加成行.add_child(商路标签)

		var 危险标签: Label = Label.new()
		危险标签.text = "危险度：%.0f%%" % (float(特性.get("危险度", 0)) * 100)
		危险标签.add_theme_font_size_override("font_size", UITheme.FONT_BODY)
		危险标签.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
		加成行.add_child(危险标签)

	if _提示 != "":
		var tip: Label = Label.new()
		tip.text = _提示
		tip.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		_content.add_child(tip)
		_提示 = ""

# S58-P1：确认迁移
func _确认迁移(目标区域: String) -> void:
	# 在目标区域内随机选择坐标
	var x: float = randf_range(-200.0, 200.0)
	var y: float = randf_range(-200.0, 200.0)
	var 结果: Dictionary = Game.世界地图系统.迁移宗门(目标区域, x, y)
	if bool(结果.get("成功", false)):
		_提示 = str(结果.get("原因", "迁移成功"))
	else:
		_提示 = "❌ %s" % str(结果.get("原因", "迁移失败"))
	_显示区域总览()

func _format战力(v: int) -> String:
	if v >= 10000:
		return "%0.1f万" % (float(v) / 10000.0)
	return str(v)

func _on_close() -> void:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("_close_sub_page"):
			n._close_sub_page()
			return
		n = n.get_parent()
	queue_free()
