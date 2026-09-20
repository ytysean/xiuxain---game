extends Control

# 身外化身系统（GameUI 二级页）：展示化身列表、创建化身、派遣游历、查看奇遇。
# 数据只读 Game.化身列表；写操作调 Game.创建化身() / Game.派遣化身游历()。

signal 返回主页

var _built: bool = false
var _列表: VBoxContainer
var _状态标签: Label
var _创建性别: String = ""  # 创建化身时选择的性别，""=随机
var _创建性别按钮: Button = null

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
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	_列表 = VBoxContainer.new()
	_列表.name = "List"
	_列表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_列表.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_列表)

	var 说明 := Label.new()
	说明.name = "Note"
	说明.text = "身外化身：元婴期可修炼，以一缕元神分化化身，代宗主游历天下，寻机缘求大道。化身所得资源可反哺宗门。"
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(说明)
	说明.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(说明)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	var 右侧 := []
	_状态标签 = Label.new()
	_状态标签.name = "Status"
	_状态标签.text = "化身 0 具"
	UITheme.apply_value_text(_状态标签)
	右侧.append(_状态标签)
	_创建性别按钮 = Button.new()
	_创建性别按钮.text = "性别：随机"
	_创建性别按钮.custom_minimum_size = Vector2(100, UITheme.SIZE_SM)
	UITheme.apply_button_style(_创建性别按钮)
	_创建性别按钮.pressed.connect(_on_切换创建性别)
	右侧.append(_创建性别按钮)
	var 创建按钮 := Button.new()
	创建按钮.text = "修炼化身"
	创建按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	UITheme.apply_button_style(创建按钮)
	创建按钮.pressed.connect(_on_创建化身)
	右侧.append(创建按钮)
	parent.add_child(UITheme.建顶栏("身外化身", _on_back_pressed, 右侧, "身外化身", "元婴期可修炼身外化身，分化元神游历天下。\n化身实力不超过宗主50%，月度所得反哺宗门。"))
func refresh() -> void:
	if not _built:
		return
	for c in _列表.get_children():
		c.queue_free()
	if Game == null or not is_instance_valid(Game):
		return
	var 化身列表: Array = Game.化身列表
	_状态标签.text = "化身 %d 具" % 化身列表.size()
	if 化身列表.is_empty():
		var empty := Label.new()
		empty.text = "尚无化身。宗主达元婴期后，可消耗灵石10000、灵草500修炼身外化身。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UITheme.apply_body_text(empty)
		empty.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		_列表.add_child(empty)
		return
	for 化身 in 化身列表:
		_render化身卡片(化身)

func _render化身卡片(化身: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "化身卡片_" + str(化身.get("化身ID", ""))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID_SM)
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	panel.add_child(vbox)

	var 行1 := HBoxContainer.new()
	行1.add_theme_constant_override("separation", UITheme.GRID)
	var 名 := Label.new()
	var 性别: String = str(化身.get("性别", "男"))
	名.text = "%s（%s）" % [str(化身.get("姓名", "未知")), 性别]
	UITheme.apply_title_text(名)
	行1.add_child(名)
	var 境 := Label.new()
	境.text = str(化身.get("境界", ""))
	UITheme.apply_value_text(境)
	行1.add_child(境)
	var 战力 := Label.new()
	战力.text = "道行 %d" % int(化身.get("战力", 0))
	UITheme.apply_aux_text(战力)
	行1.add_child(战力)
	行1.add_spacer(true)
	vbox.add_child(行1)

	var 行2 := HBoxContainer.new()
	行2.add_theme_constant_override("separation", UITheme.GRID)
	var 性格 := Label.new()
	性格.text = "性格：" + str(化身.get("性格", ""))
	UITheme.apply_aux_text(性格)
	性格.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行2.add_child(性格)
	var 道心 := Label.new()
	道心.text = "道心：%d" % int(化身.get("道心", 0))
	UITheme.apply_aux_text(道心)
	道心.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行2.add_child(道心)
	var 人脉 := Label.new()
	人脉.text = "人脉：%d" % int(化身.get("人脉", 0))
	UITheme.apply_aux_text(人脉)
	人脉.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	行2.add_child(人脉)
	行2.add_spacer(true)
	vbox.add_child(行2)

	var 状态行 := HBoxContainer.new()
	状态行.add_theme_constant_override("separation", UITheme.GRID)
	var 状态 := Label.new()
	var 游历状态: String = str(化身.get("游历状态", "闲置"))
	if 游历状态 == "游历中":
		var 剩余日: int = max(0, int(化身.get("游历结束日", 0)) - Game.累计游戏日)
		状态.text = "正在%s游历，剩余%d日" % [化身.get("游历区域", ""), 剩余日]
	elif 游历状态 == "红尘历练中":
		var 剩余年: int = max(0, int(化身.get("红尘结束日", 0)) - Game.累计游戏日)
		var 职业: String = str(化身.get("红尘职业", ""))
		var 年龄: int = int(化身.get("红尘年龄", 0))
		var 配偶: String = str(化身.get("红尘配偶", ""))
		var 子女: int = int(化身.get("红尘子女", 0))
		var 世: int = int(化身.get("轮回世", 0))
		var 伤残: String = str(化身.get("红尘伤残", ""))
		var 家庭: String = ""
		if 配偶 != "":
			家庭 = "，妻%s" % 配偶
			if 子女 > 0:
				家庭 += "，子女%d人" % 子女
		var 伤残显示: String = ""
		if 伤残 != "":
			伤残显示 = "，%s" % 伤残
		状态.text = "红尘第%d世·%s，%d岁，剩余%d年%s%s" % [世 + 1, 职业, 年龄, 剩余年, 家庭, 伤残显示]
	elif 游历状态 == "轮回等待":
		var 世: int = int(化身.get("轮回世", 0))
		状态.text = "轮回之中·已历%d世，可继续轮回或回归宗门" % 世
	elif 游历状态 == "客卿中":
		var 剩余日: int = max(0, int(化身.get("客卿结束日", 0)) - Game.累计游戏日)
		状态.text = "做客卿于%s，剩余%d日" % [化身.get("客卿宗门", ""), 剩余日]
	else:
		状态.text = "闲置中，可派遣游历或入凡历练"
	UITheme.apply_body_text(状态)
	状态行.add_child(状态)
	状态行.add_spacer(true)
	vbox.add_child(状态行)

	# 背包显示（灵石/功法残卷）
	var 背包行 := HBoxContainer.new()
	背包行.add_theme_constant_override("separation", UITheme.GRID)
	var 灵石数: int = int(化身.get("背包", {}).get("灵石", 0))
	var 残卷数: int = int(化身.get("背包", {}).get("功法残卷", 0))
	var 背包标签 := Label.new()
	背包标签.text = "背包：灵石%d，功法残卷%d" % [灵石数, 残卷数]
	UITheme.apply_aux_text(背包标签)
	背包标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	背包行.add_child(背包标签)
	背包行.add_spacer(true)
	vbox.add_child(背包行)

	# 游历区域选择（仅闲置时显示）
	if 游历状态 == "闲置":
		var 区域行 := HBoxContainer.new()
		区域行.add_theme_constant_override("separation", UITheme.GRID_SM)
		var 区域列表: Array = ["蛮荒之地", "仙城闹市", "深山老林", "东海之滨", "北境雪原", "南疆密林"]
		for 区域 in 区域列表:
			var btn := Button.new()
			btn.text = 区域
			btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
			UITheme.apply_tab_style(btn, false)
			btn.pressed.connect(func(): _on_派遣游历(int(化身.get("化身ID", 0)), 区域))
			区域行.add_child(btn)
			btn.modulate.a = 0.0
			btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
		vbox.add_child(区域行)
		# 红尘历练入口
		var 红尘行 := HBoxContainer.new()
		红尘行.add_theme_constant_override("separation", UITheme.GRID_SM)
		var 红尘标签 := Label.new()
		红尘标签.text = "红尘历练："
		UITheme.apply_aux_text(红尘标签)
		红尘标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		红尘行.add_child(红尘标签)
		var 职业列表: Array = ["厨师", "医者", "士兵", "将军", "书生", "商人", "工匠", "农夫", "猎户", "戏子"]
		for 职业 in 职业列表:
			var btn := Button.new()
			btn.text = 职业
			btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
			UITheme.apply_tab_style(btn, false)
			btn.pressed.connect(func(): _on_派遣入凡(int(化身.get("化身ID", 0)), 职业))
			红尘行.add_child(btn)
			btn.modulate.a = 0.0
			btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
		vbox.add_child(红尘行)
		# P2：客卿入口
		var 客卿行 := HBoxContainer.new()
		客卿行.add_theme_constant_override("separation", UITheme.GRID_SM)
		var 客卿标签 := Label.new()
		客卿标签.text = "加入客卿："
		UITheme.apply_aux_text(客卿标签)
		客卿标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		客卿行.add_child(客卿标签)
		var 客卿列表: Array = ["青云宗", "合欢宗", "万剑门", "百药谷", "机关城"]
		for 宗门 in 客卿列表:
			var btn := Button.new()
			btn.text = 宗门
			btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
			UITheme.apply_tab_style(btn, false)
			btn.pressed.connect(func(): _on_加入客卿(int(化身.get("化身ID", 0)), 宗门))
			客卿行.add_child(btn)
			btn.modulate.a = 0.0
			btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
		vbox.add_child(客卿行)

	# P1：坊市交易（仅在仙城闹市游历中显示）
	if 游历状态 == "游历中" and str(化身.get("游历区域", "")) == "仙城闹市":
		var 坊市行 := HBoxContainer.new()
		坊市行.add_theme_constant_override("separation", UITheme.GRID_SM)
		var 坊市标签 := Label.new()
		坊市标签.text = "坊市交易："
		UITheme.apply_aux_text(坊市标签)
		坊市标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
		坊市行.add_child(坊市标签)
		var 商品列表: Array = ["灵草", "妖兽内丹一阶", "精铁", "灵品灵草", "玉石"]
		for 商品 in 商品列表:
			var btn := Button.new()
			btn.text = "买入" + 商品
			btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
			UITheme.apply_tab_style(btn, false)
			btn.pressed.connect(func(): _on_坊市买入(int(化身.get("化身ID", 0)), 商品))
			坊市行.add_child(btn)
			btn.modulate.a = 0.0
			btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
		vbox.add_child(坊市行)

	# 轮回等待状态：继续轮回或回归宗门
	if 游历状态 == "轮回等待":
		var 轮回操作行 := HBoxContainer.new()
		轮回操作行.add_theme_constant_override("separation", UITheme.GRID)
		var 继续轮回btn := Button.new()
		继续轮回btn.text = "继续轮回（选职业）"
		继续轮回btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_button_style(继续轮回btn)
		继续轮回btn.pressed.connect(func(): _on_显示轮回职业(int(化身.get("化身ID", 0))))
		轮回操作行.add_child(继续轮回btn)
		var 回归btn := Button.new()
		回归btn.text = "圆满回归"
		回归btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_button_style(回归btn)
		回归btn.pressed.connect(func(): _on_红尘回归(int(化身.get("化身ID", 0))))
		轮回操作行.add_child(回归btn)
		轮回操作行.add_spacer(true)
		vbox.add_child(轮回操作行)
		# 轮回职业选择（默认隐藏，点击继续轮回后显示）
		if 化身.get("显示轮回职业", false):
			var 轮回职业行 := HBoxContainer.new()
			轮回职业行.add_theme_constant_override("separation", UITheme.GRID_SM)
			var 职业列表: Array = ["厨师", "医者", "士兵", "将军", "书生", "商人", "工匠", "农夫", "猎户", "戏子"]
			for 职业 in 职业列表:
				var btn := Button.new()
				btn.text = 职业
				btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
				UITheme.apply_tab_style(btn, false)
				btn.pressed.connect(func(): _on_继续轮回(int(化身.get("化身ID", 0)), 职业))
				轮回职业行.add_child(btn)
				btn.modulate.a = 0.0
				btn.create_tween().tween_property(btn, "modulate:a", 1.0, 0.25)
			vbox.add_child(轮回职业行)
		# 轮回记录显示
		var 轮回记录: Array = 化身.get("轮回记录", [])
		if 轮回记录.size() > 0:
			var 记录标签 := Label.new()
			记录标签.text = "轮回记录："
			UITheme.apply_aux_text(记录标签)
			记录标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
			vbox.add_child(记录标签)
			for 记录 in 轮回记录:
				var 记录行 := Label.new()
				记录行.text = "  第%d世：%s，%s，道心+%d" % [int(记录.get("世", 0)), 记录.get("职业", ""), 记录.get("原因", ""), int(记录.get("道心", 0))]
				UITheme.apply_aux_text(记录行)
				记录行.add_theme_color_override("font_color", UITheme.color_text_body_dim())
				vbox.add_child(记录行)
				记录行.modulate.a = 0.0
				记录行.create_tween().tween_property(记录行, "modulate:a", 1.0, 0.25)

	# P1P2：操作按钮（传承功法/转化人脉）
	if 游历状态 == "闲置":
		var 操作行 := HBoxContainer.new()
		操作行.add_theme_constant_override("separation", UITheme.GRID)
		var 传承btn := Button.new()
		传承btn.text = "传承功法"
		传承btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_button_style(传承btn)
		传承btn.pressed.connect(func(): _on_传承功法(int(化身.get("化身ID", 0))))
		操作行.add_child(传承btn)
		var 人脉btn := Button.new()
		人脉btn.text = "转化人脉"
		人脉btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		UITheme.apply_button_style(人脉btn)
		人脉btn.pressed.connect(func(): _on_转化人脉(int(化身.get("化身ID", 0))))
		操作行.add_child(人脉btn)
		操作行.add_spacer(true)
		vbox.add_child(操作行)

	_列表.add_child(panel)

func _on_切换创建性别() -> void:
	# 循环切换：随机→男→女→随机
	if _创建性别 == "":
		_创建性别 = "男"
	elif _创建性别 == "男":
		_创建性别 = "女"
	else:
		_创建性别 = ""
	var 显示文本: String = "随机" if _创建性别 == "" else _创建性别
	_创建性别按钮.text = "性别：%s" % 显示文本

func _on_创建化身() -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 检查: Dictionary = Game.可创建化身()
	if not 检查.get("成功", false):
		UIHint.show_hint(self, "修炼化身", str(检查.get("原因", "无法创建")))
		Game.添加提示("修炼化身")
		return
	# 性别处理：随机则50%男50%女
	var 实际性别: String = _创建性别
	if 实际性别 == "":
		实际性别 = "男" if randf() < 0.5 else "女"
	var 结果: Dictionary = Game.创建化身("", 实际性别)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "修炼化身", "成功修炼%s化身「%s」！" % [实际性别, 结果.get("姓名", "")])
		Game.添加提示("修炼化身")
	else:
		UIHint.show_hint(self, "修炼化身", str(结果.get("原因", "创建失败")))
		Game.添加提示("修炼化身")
	refresh()

func _on_派遣游历(化身ID: int, 区域: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.派遣化身游历(化身ID, 区域)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "派遣游历", str(结果.get("消息", "派遣成功")))
		Game.添加提示("派遣游历")
	else:
		UIHint.show_hint(self, "派遣游历", str(结果.get("原因", "派遣失败")))
		Game.添加提示("派遣游历")
	refresh()

func _on_派遣入凡(化身ID: int, 职业: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.派遣化身入凡(化身ID, 职业)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "红尘历练", str(结果.get("消息", "入凡成功")))
		Game.添加提示("红尘历练")
	else:
		UIHint.show_hint(self, "红尘历练", str(结果.get("原因", "入凡失败")))
		Game.添加提示("红尘历练")
	refresh()

func _on_加入客卿(化身ID: int, 宗门名: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身加入客卿(化身ID, 宗门名)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "加入客卿", str(结果.get("消息", "加入成功")))
		Game.添加提示("加入客卿")
	else:
		UIHint.show_hint(self, "加入客卿", str(结果.get("原因", "加入失败")))
		Game.添加提示("加入客卿")
	refresh()

func _on_坊市买入(化身ID: int, 商品: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身坊市交易(化身ID, 商品, 1, true)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "坊市交易", str(结果.get("消息", "买入成功")))
		Game.添加提示("坊市交易")
	else:
		UIHint.show_hint(self, "坊市交易", str(结果.get("原因", "买入失败")))
		Game.添加提示("坊市交易")
	refresh()

func _on_传承功法(化身ID: int) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身传承功法(化身ID)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "传承功法", str(结果.get("消息", "传承成功")))
		Game.添加提示("传承功法")
	else:
		UIHint.show_hint(self, "传承功法", str(结果.get("原因", "传承失败")))
		Game.添加提示("传承功法")
	refresh()

func _on_转化人脉(化身ID: int) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身人脉转化(化身ID)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "转化人脉", str(结果.get("消息", "转化成功")))
		Game.添加提示("转化人脉")
	else:
		UIHint.show_hint(self, "转化人脉", str(结果.get("原因", "转化失败")))
		Game.添加提示("转化人脉")
	refresh()

func _on_显示轮回职业(化身ID: int) -> void:
	# 切换显示轮回职业选择
	for 化身 in Game.化身列表:
		if int(化身.get("化身ID", 0)) == 化身ID:
			化身["显示轮回职业"] = not 化身.get("显示轮回职业", false)
			break
	refresh()

func _on_继续轮回(化身ID: int, 职业: String) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身继续轮回(化身ID, 职业)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "继续轮回", str(结果.get("消息", "轮回成功")))
		Game.添加提示("继续轮回")
	else:
		UIHint.show_hint(self, "继续轮回", str(结果.get("原因", "轮回失败")))
		Game.添加提示("继续轮回")
	refresh()

func _on_红尘回归(化身ID: int) -> void:
	if Game == null or not is_instance_valid(Game):
		return
	var 结果: Dictionary = Game.化身红尘回归(化身ID)
	if 结果.get("成功", false):
		UIHint.show_hint(self, "圆满回归", str(结果.get("消息", "回归成功")))
		Game.添加提示("圆满回归")
	else:
		UIHint.show_hint(self, "圆满回归", str(结果.get("原因", "回归失败")))
		Game.添加提示("圆满回归")
	refresh()

func _on_back_pressed() -> void:
	返回主页.emit()
