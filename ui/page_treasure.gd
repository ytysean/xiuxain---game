extends Control
# 法宝系统UI：总览 / 普通法宝 / 本命法宝
# 后端：game_state.gd 法宝系统（3函数）+ config/treasure_normal.csv(36件) + config/treasure_innate.csv(25件)
# 入口：main.gd 宗门页快捷网格「法宝」→ 二级页
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "普通法宝", "本命法宝"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _普通法宝缓存: Array = []
var _本命法宝缓存: Array = []


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	# 修复（实机验收抓出 · 2026-09-12）：本页根节点是 Control（非容器），子节点 anchors 全 0，
	# ScrollContainer 最小尺寸为 0 → 塌成 0×0 且 clip_contents=true 把正文整块裁掉。
	# 与 page_chat 同构：先挂一个全屏 VBoxContainer 作为唯一布局宿主。
	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	add_child(main)

	# 顶部返回栏
	var 顶栏: HBoxContainer = HBoxContainer.new()
	顶栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(顶栏)

	var 返回按钮: Button = Button.new()
	返回按钮.text = "← 返回宗门"
	返回按钮.custom_minimum_size = Vector2(120, 36)
	返回按钮.pressed.connect(_on返回)
	顶栏.add_child(返回按钮)

	var 标题: Label = Label.new()
	标题.text = "  法宝阁"
	标题.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	标题.add_theme_font_size_override("font_size", 20)
	顶栏.add_child(标题)

	# 标签栏
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)

	for 标签名 in TABS:
		var 按钮: Button = Button.new()
		按钮.text = 标签名
		按钮.custom_minimum_size = Vector2(100, 32)
		按钮.pressed.connect(Callable(self, "_切换标签").bind(标签名))
		标签栏.add_child(按钮)
		_tab_btns[标签名] = 按钮

	# 内容滚动区
	var 滚: ScrollContainer = ScrollContainer.new()
	滚.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.size_flags_vertical = Control.SIZE_EXPAND_FILL
	滚.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(滚)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	滚.add_child(_body)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_content)

	_加载配置表()
	_刷新标签按钮()
	_刷新内容()


func _加载配置表() -> void:
	# 加载普通法宝配置
	var 普通文件: FileAccess = FileAccess.open("res://config/treasure_normal.csv", FileAccess.READ)
	if 普通文件 != null:
		var 行号: int = 0
		while not 普通文件.eof_reached():
			var 行: String = 普通文件.get_line()
			行号 += 1
			if 行号 == 1 or 行.strip_edges() == "":
				continue
			var 字段: Array = 行.split(",", false)
			if 字段.size() >= 11:
				_普通法宝缓存.append({
					"id": str(字段[0]),
					"名": str(字段[1]),
					"品阶": str(字段[2]),
					"子品阶": str(字段[3]),
					"类型": str(字段[4]),
					"攻击": int(字段[5]),
					"防御": int(字段[6]),
					"气血": int(字段[7]),
					"被动效果": str(字段[8]),
					"效果值": str(字段[9]),
					"售价": int(字段[10])
				})
		普通文件.close()

	# 加载本命法宝配置
	var 本命文件: FileAccess = FileAccess.open("res://config/treasure_innate.csv", FileAccess.READ)
	if 本命文件 != null:
		var 行号2: int = 0
		while not 本命文件.eof_reached():
			var 行2: String = 本命文件.get_line()
			行号2 += 1
			if 行号2 == 1 or 行2.strip_edges() == "":
				continue
			var 字段2: Array = 行2.split(",", false)
			if 字段2.size() >= 11:
				_本命法宝缓存.append({
					"id": str(字段2[0]),
					"名": str(字段2[1]),
					"品阶": str(字段2[2]),
					"子品阶": str(字段2[3]),
					"适用": str(字段2[4]),
					"主动技": str(字段2[5]),
					"被动效果": str(字段2[6]),
					"成长值": str(字段2[7]),
					"最大等级": int(字段2[8]),
					"献祭材料": str(字段2[9])
				})
		本命文件.close()


func _切换标签(标签名: String) -> void:
	_cur = 标签名
	_刷新标签按钮()
	_刷新内容()


func _刷新标签按钮() -> void:
	for 标签名 in _tab_btns.keys():
		var 按钮: Button = _tab_btns[标签名]
		if 标签名 == _cur:
			按钮.modulate = Color(1.0, 0.9, 0.6)
		else:
			按钮.modulate = Color(0.7, 0.7, 0.7)


func _刷新内容() -> void:
	for c in _content.get_children():
		c.queue_free()

	match _cur:
		"总览":
			_填总览()
		"普通法宝":
			_填普通法宝()
		"本命法宝":
			_填本命法宝()


# ==================== 总览页 ====================
func _填总览() -> void:
	var 统计: Dictionary = Game.获取本命法宝统计()
	var 法宝列表: Array = Game.获取所有本命法宝列表()

	# 统计面板
	_添加面板标题("法宝统计")

	var 统计网格: GridContainer = GridContainer.new()
	统计网格.columns = 2
	统计网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(统计网格)

	_添加信息项(统计网格, "法宝总数", str(int(统计.get("总数", 0))))
	_添加信息项(统计网格, "已装备数", str(int(统计.get("已装备数", 0))))
	_添加信息项(统计网格, "总战力", str(int(统计.get("总战力", 0))))
	_添加信息项(统计网格, "平均战力", str(int(统计.get("平均战力", 0))))

	# 图鉴进度
	_添加面板标题("图鉴进度")
	var 进度文本: Label = Label.new()
	进度文本.text = "普通法宝：已收录 %d / %d 件  |  本命法宝：已收录 %d / %d 件" % [
		_普通法宝缓存.size(), _普通法宝缓存.size(),
		_本命法宝缓存.size(), _本命法宝缓存.size()
	]
	进度文本.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_content.add_child(进度文本)

	# 已装备法宝列表
	_添加面板标题("已装备本命法宝（共 %d 件）" % int(统计.get("已装备数", 0)))

	if 法宝列表.is_empty():
		_添加空状态("暂无本命法宝", "弟子可通过器殿锻造或特殊事件获得本命法宝。本命法宝绑定弟子，可成长升级。")
		return

	# 表头
	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	var 列宽: Array = [120, 60, 60, 60, 80, 60]
	var 列名: Array = ["法宝名", "品阶", "类别", "战力", "所属弟子", "状态"]
	for i in range(列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 列名[i]
		列标签.custom_minimum_size = Vector2(列宽[i], 24)
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		表头.add_child(列标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)

	# 法宝列表
	for 法宝 in 法宝列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 名标签: Label = Label.new()
		名标签.text = str(法宝.get("名称", "未知"))
		名标签.custom_minimum_size = Vector2(列宽[0], 24)
		行.add_child(名标签)

		var 品阶标签: Label = Label.new()
		品阶标签.text = str(法宝.get("品阶", "未知"))
		品阶标签.custom_minimum_size = Vector2(列宽[1], 24)
		品阶标签.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
		行.add_child(品阶标签)

		var 类别标签: Label = Label.new()
		类别标签.text = str(法宝.get("类别", "未知"))
		类别标签.custom_minimum_size = Vector2(列宽[2], 24)
		行.add_child(类别标签)

		var 战力标签: Label = Label.new()
		战力标签.text = str(int(法宝.get("战力", 0)))
		战力标签.custom_minimum_size = Vector2(列宽[3], 24)
		战力标签.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		行.add_child(战力标签)

		var 弟子标签: Label = Label.new()
		弟子标签.text = str(法宝.get("所属弟子", "未知"))
		弟子标签.custom_minimum_size = Vector2(列宽[4], 24)
		行.add_child(弟子标签)

		var 状态标签: Label = Label.new()
		var 已装备: bool = bool(法宝.get("已装备", false))
		状态标签.text = "已装备" if 已装备 else "背包中"
		状态标签.custom_minimum_size = Vector2(列宽[5], 24)
		if 已装备:
			状态标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			状态标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		行.add_child(状态标签)


# ==================== 普通法宝页 ====================
func _填普通法宝() -> void:
	if _普通法宝缓存.is_empty():
		_添加空状态("普通法宝配置为空", "treasure_normal.csv 未加载或为空。")
		return

	_添加面板标题("普通法宝图鉴（共 %d 件）" % _普通法宝缓存.size())

	# 按类型分组
	var 类型分组: Dictionary = {}
	for 法宝 in _普通法宝缓存:
		var 类型: String = str(法宝.get("类型", "未知"))
		if not 类型分组.has(类型):
			类型分组[类型] = []
		类型分组[类型].append(法宝)

	for 类型 in 类型分组.keys():
		var 类型列表: Array = 类型分组[类型]
		_添加子标题("%s（%d件）" % [类型, 类型列表.size()])

		for 法宝 in 类型列表:
			var 卡片: VBoxContainer = VBoxContainer.new()
			卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(卡片)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)

			var 名: Label = Label.new()
			名.text = "◆ %s" % str(法宝.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
			名.add_theme_font_size_override("font_size", 15)
			名栏.add_child(名)

			var 品阶: Label = Label.new()
			品阶.text = "  [%s·%s]" % [str(法宝.get("品阶", "")), str(法宝.get("子品阶", ""))]
			品阶.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
			名栏.add_child(品阶)

			var 属性栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(属性栏)

			var 攻击: Label = Label.new()
			攻击.text = "攻+%d" % int(法宝.get("攻击", 0))
			攻击.custom_minimum_size = Vector2(60, 20)
			攻击.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
			属性栏.add_child(攻击)

			var 防御: Label = Label.new()
			防御.text = "防+%d" % int(法宝.get("防御", 0))
			防御.custom_minimum_size = Vector2(60, 20)
			防御.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			属性栏.add_child(防御)

			var 气血: Label = Label.new()
			气血.text = "血+%d" % int(法宝.get("气血", 0))
			气血.custom_minimum_size = Vector2(60, 20)
			气血.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
			属性栏.add_child(气血)

			var 售价: Label = Label.new()
			售价.text = "售价：%d灵石" % int(法宝.get("售价", 0))
			售价.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			属性栏.add_child(售价)

			var 效果: Label = Label.new()
			效果.text = "被动：%s（%s）" % [str(法宝.get("被动效果", "")), str(法宝.get("效果值", ""))]
			效果.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			卡片.add_child(效果)

			# 装备/卸下按钮
			var 按钮栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(按钮栏)

			var 法宝ID: String = str(法宝.get("id", ""))
			var 已装备弟子: String = _查找装备该法宝的弟子(法宝ID)

			if 已装备弟子 != "":
				var 已装备标签: Label = Label.new()
				已装备标签.text = "已装备：%s" % 已装备弟子
				已装备标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
				已装备标签.custom_minimum_size = Vector2(150, 24)
				按钮栏.add_child(已装备标签)

				var 卸下按钮: Button = Button.new()
				卸下按钮.text = "卸下"
				卸下按钮.custom_minimum_size = Vector2(80, 24)
				卸下按钮.modulate = Color(1.0, 0.7, 0.7)
				卸下按钮.pressed.connect(Callable(self, "_卸下普通法宝").bind(法宝ID))
				按钮栏.add_child(卸下按钮)
			else:
				var 装备按钮: Button = Button.new()
				装备按钮.text = "装备给宗主"
				装备按钮.custom_minimum_size = Vector2(120, 24)
				装备按钮.modulate = Color(0.8, 1.0, 0.8)
				装备按钮.pressed.connect(Callable(self, "_装备普通法宝").bind(法宝ID))
				按钮栏.add_child(装备按钮)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)


# 查找装备该法宝的弟子名
func _查找装备该法宝的弟子(法宝ID: String) -> String:
	for d in Game.弟子列表:
		if d != null and "_普通法宝ID" in d and d.get("_普通法宝ID") == 法宝ID:
			return str(d.姓名)
	return ""


# 装备普通法宝给宗主
func _装备普通法宝(法宝ID: String) -> void:
	if Game.弟子列表.is_empty():
		print("[法宝] 没有弟子可装备")
		_刷新内容()
		return
	var 宗主: Object = Game.弟子列表[0]
	if 宗主 == null:
		print("[法宝] 宗主不存在")
		_刷新内容()
		return
	var 结果: Dictionary = Game.装备普通法宝(宗主.弟子ID, 法宝ID)
	print("[法宝] %s" % str(结果.get("原因", "操作完成")))
	_刷新内容()


# 卸下普通法宝
func _卸下普通法宝(法宝ID: String) -> void:
	for d in Game.弟子列表:
		if d != null and "_普通法宝ID" in d and d.get("_普通法宝ID") == 法宝ID:
			var 结果: Dictionary = Game.卸下普通法宝(d.弟子ID)
			print("[法宝] %s" % str(结果.get("原因", "操作完成")))
			break
	_刷新内容()


# ==================== 本命法宝页 ====================
func _填本命法宝() -> void:
	if _本命法宝缓存.is_empty():
		_添加空状态("本命法宝配置为空", "treasure_innate.csv 未加载或为空。")
		return

	_添加面板标题("本命法宝图鉴（共 %d 件）" % _本命法宝缓存.size())

	# 按适用职业分组
	var 适用分组: Dictionary = {}
	for 法宝 in _本命法宝缓存:
		var 适用: String = str(法宝.get("适用", "未知"))
		if not 适用分组.has(适用):
			适用分组[适用] = []
		适用分组[适用].append(法宝)

	for 适用 in 适用分组.keys():
		var 适用列表: Array = 适用分组[适用]
		_添加子标题("%s适用（%d件）" % [适用, 适用列表.size()])

		for 法宝 in 适用列表:
			var 卡片: VBoxContainer = VBoxContainer.new()
			卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(卡片)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)

			var 名: Label = Label.new()
			名.text = "★ %s" % str(法宝.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			名.add_theme_font_size_override("font_size", 15)
			名栏.add_child(名)

			var 品阶: Label = Label.new()
			品阶.text = "  [%s·%s]" % [str(法宝.get("品阶", "")), str(法宝.get("子品阶", ""))]
			品阶.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
			名栏.add_child(品阶)

			var 主动技栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(主动技栏)

			var 主动技标签: Label = Label.new()
			主动技标签.text = "主动技："
			主动技标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.8))
			主动技栏.add_child(主动技标签)

			var 主动技: Label = Label.new()
			主动技.text = str(法宝.get("主动技", "未知"))
			主动技.add_theme_color_override("font_color", Color(0.9, 0.7, 0.9))
			主动技栏.add_child(主动技)

			var 属性栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(属性栏)

			var 成长: Label = Label.new()
			成长.text = "成长：%s" % str(法宝.get("成长值", "未知"))
			成长.custom_minimum_size = Vector2(100, 20)
			成长.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
			属性栏.add_child(成长)

			var 最大等级: Label = Label.new()
			最大等级.text = "最大等级：Lv.%d" % int(法宝.get("最大等级", 0))
			最大等级.custom_minimum_size = Vector2(100, 20)
			最大等级.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
			属性栏.add_child(最大等级)

			var 献祭: Label = Label.new()
			献祭.text = "献祭材料：%s" % str(法宝.get("献祭材料", "未知"))
			献祭.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			属性栏.add_child(献祭)

			var 被动: Label = Label.new()
			被动.text = "被动：%s" % str(法宝.get("被动效果", ""))
			被动.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			卡片.add_child(被动)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)


# ==================== 工具函数 ====================
func _品阶颜色(品阶: String) -> Color:
	match 品阶:
		"凡品", "凡阶":
			return Color(0.7, 0.7, 0.7)
		"灵品", "灵阶":
			return Color(0.5, 0.9, 0.6)
		"宝品", "宝阶":
			return Color(0.5, 0.7, 1.0)
		"王品", "王阶":
			return Color(0.9, 0.7, 1.0)
		"圣品", "圣阶":
			return Color(1.0, 0.85, 0.4)
		"仙品", "仙阶":
			return Color(1.0, 0.6, 0.6)
		"道品", "道阶":
			return Color(0.8, 0.6, 1.0)
		_:
			return Color(0.7, 0.7, 0.7)


func _添加空状态(标题: String, 描述: String) -> void:
	var 空状态: VBoxContainer = VBoxContainer.new()
	空状态.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	空状态.add_theme_constant_override("separation", 10)
	_content.add_child(空状态)

	var 空标题: Label = Label.new()
	空标题.text = 标题
	空标题.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	空标题.add_theme_font_size_override("font_size", 18)
	空标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空标题)

	var 空描述: Label = Label.new()
	空描述.text = 描述
	空描述.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	空描述.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	空描述.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	空状态.add_child(空描述)


func _添加面板标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, 8)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "▎ %s" % 标题
	标题标签.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	标题标签.add_theme_font_size_override("font_size", 16)
	_content.add_child(标题标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)


func _添加子标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, 6)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "● %s" % 标题
	标题标签.add_theme_color_override("font_color", Color(0.75, 0.65, 0.45))
	标题标签.add_theme_font_size_override("font_size", 14)
	_content.add_child(标题标签)


func _添加信息项(网格: GridContainer, 标签: String, 值: String) -> void:
	var 标签控件: Label = Label.new()
	标签控件.text = 标签 + "："
	标签控件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	标签控件.custom_minimum_size = Vector2(100, 24)
	网格.add_child(标签控件)

	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	网格.add_child(值控件)


func _on返回() -> void:
	返回主页.emit()
