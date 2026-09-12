extends Control
# 宗门科技UI：总览 / 科技树
# 后端：game_state.gd 宗门科技系统（3函数+14科技配置）
# 入口：main.gd 宗门页快捷网格「科技」→ 二级页
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "科技树"]

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _提示: String = ""


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
	标题.text = "  宗门科技院"
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

	_刷新标签按钮()
	_刷新内容()


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
		"科技树":
			_填科技树()


# ==================== 总览页 ====================
func _填总览() -> void:
	var 科技列表: Array = Game.获取所有宗门科技列表()
	var 总效果: Dictionary = Game.计算宗门科技总效果()

	# 统计
	var 已研究数: int = 0
	var 可研究数: int = 0
	var 总消耗灵石: int = 0
	var 总消耗悟道点: int = 0
	for 科技 in 科技列表:
		if bool(科技.get("已研究", false)):
			已研究数 += 1
			总消耗灵石 += int(科技.get("消耗灵石", 0))
			总消耗悟道点 += int(科技.get("消耗悟道点", 0))
		elif bool(科技.get("可研究", false)):
			可研究数 += 1

	# 统计面板
	_添加面板标题("科技研究统计")

	var 统计网格: GridContainer = GridContainer.new()
	统计网格.columns = 2
	统计网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(统计网格)

	_添加信息项(统计网格, "科技总数", str(科技列表.size()))
	_添加信息项(统计网格, "已研究", str(已研究数))
	_添加信息项(统计网格, "可研究", str(可研究数))
	_添加信息项(统计网格, "未解锁", str(科技列表.size() - 已研究数 - 可研究数))
	_添加信息项(统计网格, "累计消耗灵石", str(总消耗灵石))
	_添加信息项(统计网格, "累计消耗悟道点", str(总消耗悟道点))

	# 当前资源
	_添加面板标题("当前资源")

	var 资源网格: GridContainer = GridContainer.new()
	资源网格.columns = 2
	资源网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(资源网格)

	_添加信息项(资源网格, "灵石", str(int(Game.灵石)))
	_添加信息项(资源网格, "悟道点", str(int(Game.悟道点)))

	# 总效果
	_添加面板标题("科技总效果")

	var 效果列表: Array = [
		["修炼速度加成", "修炼速度加成", Color(0.7, 1.0, 0.7)],
		["战力加成", "战力加成", Color(1.0, 0.7, 0.7)],
		["产出加成", "产出加成", Color(0.7, 0.9, 1.0)],
		["阵法加成", "阵法加成", Color(0.9, 0.7, 1.0)],
		["丹药加成", "丹药加成", Color(1.0, 0.85, 0.5)]
	]

	for 效果项 in 效果列表:
		var 效果名: String = 效果项[0]
		var 效果键: String = 效果项[1]
		var 效果颜色: Color = 效果项[2]
		var 效果值: float = float(总效果.get(效果键, 0.0))

		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)

		var 名标签: Label = Label.new()
		名标签.text = 效果名 + "："
		名标签.custom_minimum_size = Vector2(120, 24)
		名标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		行.add_child(名标签)

		var 值标签: Label = Label.new()
		if 效果值 > 0:
			值标签.text = "+%.1f%%" % [效果值 * 100]
			值标签.add_theme_color_override("font_color", 效果颜色)
		else:
			值标签.text = "未激活"
			值标签.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		行.add_child(值标签)

	# 提示
	if 可研究数 > 0:
		var 提示: Label = Label.new()
		提示.text = "💡 当前有 %d 项科技可研究，前往「科技树」查看详情" % 可研究数
		提示.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(提示)


# ==================== 科技树页 ====================
func _填科技树() -> void:
	var 科技列表: Array = Game.获取所有宗门科技列表()

	if 科技列表.is_empty():
		_添加空状态("暂无科技", "宗门科技树配置为空。")
		return

	# 按系列分组
	var 系列分组: Dictionary = {}
	for 科技 in 科技列表:
		var 科技名: String = str(科技.get("科技名称", ""))
		var 系列名: String = _提取系列名(科技名)
		if not 系列分组.has(系列名):
			系列分组[系列名] = []
		系列分组[系列名].append(科技)

	# 提示信息
	var 提示标签: Label = Label.new()
	提示标签.text = "研究科技需消耗灵石和悟道点，部分科技需要先研究前置科技。"
	提示标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	提示标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(提示标签)

	# 各系列科技
	for 系列名 in 系列分组.keys():
		var 系列列表: Array = 系列分组[系列名]
		# 按等级排序
		系列列表.sort_custom(func(a, b): return int(a.get("等级", 1)) < int(b.get("等级", 1)))

		_添加子标题("%s（%d项）" % [系列名, 系列列表.size()])

		for 科技 in 系列列表:
			var 卡片: VBoxContainer = VBoxContainer.new()
			卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(卡片)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)

			var 科技名: String = str(科技.get("科技名称", ""))
			var 已研究: bool = bool(科技.get("已研究", false))
			var 可研究: bool = bool(科技.get("可研究", false))

			var 状态图标: String = "✓" if 已研究 else ("○" if 可研究 else "🔒")
			var 状态颜色: Color = Color(0.6, 1.0, 0.6) if 已研究 else (Color(1.0, 0.9, 0.5) if 可研究 else Color(0.5, 0.5, 0.5))

			var 名: Label = Label.new()
			名.text = "%s %s" % [状态图标, 科技名]
			名.add_theme_color_override("font_color", 状态颜色)
			名.add_theme_font_size_override("font_size", 15)
			名栏.add_child(名)

			var 等级: Label = Label.new()
			等级.text = "  [Lv.%d]" % int(科技.get("等级", 1))
			等级.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			名栏.add_child(等级)

			var 描述: Label = Label.new()
			描述.text = str(科技.get("描述", ""))
			描述.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			卡片.add_child(描述)

			var 消耗栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(消耗栏)

			var 灵石消耗: Label = Label.new()
			灵石消耗.text = "消耗：%d灵石" % int(科技.get("消耗灵石", 0))
			灵石消耗.custom_minimum_size = Vector2(120, 20)
			灵石消耗.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			消耗栏.add_child(灵石消耗)

			var 悟道消耗: Label = Label.new()
			悟道消耗.text = "+ %d悟道点" % int(科技.get("消耗悟道点", 0))
			悟道消耗.custom_minimum_size = Vector2(120, 20)
			悟道消耗.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			消耗栏.add_child(悟道消耗)

			# 前置科技
			var 前置列表: Array = 科技.get("前置科技", [])
			if 前置列表.size() > 0:
				var 前置: Label = Label.new()
				前置.text = "前置：%s" % ", ".join(前置列表)
				前置.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				卡片.add_child(前置)

			# 研究按钮
			if not 已研究:
				var 按钮栏: HBoxContainer = HBoxContainer.new()
				卡片.add_child(按钮栏)

				var 研究按钮: Button = Button.new()
				if 可研究:
					研究按钮.text = "研究"
					研究按钮.modulate = Color(0.8, 1.0, 0.8)
				else:
					研究按钮.text = "未解锁"
					研究按钮.disabled = true
					研究按钮.modulate = Color(0.6, 0.6, 0.6)
				研究按钮.custom_minimum_size = Vector2(100, 28)
				研究按钮.pressed.connect(Callable(self, "_研究科技").bind(科技名))
				按钮栏.add_child(研究按钮)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)


func _研究科技(科技名: String) -> void:
	var 结果: Dictionary = Game.研究宗门科技(科技名)
	if bool(结果.get("成功", false)):
		_提示 = "研究「%s」成功！" % 科技名
	else:
		_提示 = "研究失败：%s" % str(结果.get("原因", "未知错误"))
	_刷新内容()

	# 显示提示
	if _提示 != "":
		var 提示标签: Label = Label.new()
		提示标签.text = _提示
		提示标签.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		_content.add_child(提示标签)


# ==================== 工具函数 ====================
func _提取系列名(科技名: String) -> String:
	if 科技名.begins_with("修炼加速"):
		return "修炼加速"
	elif 科技名.begins_with("战力强化"):
		return "战力强化"
	elif 科技名.begins_with("资源增产"):
		return "资源增产"
	elif 科技名.begins_with("阵法强化"):
		return "阵法强化"
	elif 科技名.begins_with("丹药强化"):
		return "丹药强化"
	else:
		return "其他"


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
	标签控件.custom_minimum_size = Vector2(120, 24)
	网格.add_child(标签控件)

	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	网格.add_child(值控件)


func _on返回() -> void:
	返回主页.emit()
