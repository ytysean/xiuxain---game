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

	# 顶部返回栏（★ PH7-14：统一为 UITheme.建顶栏，消除手搓 66-high + 文字方钮 fs=15 同型缺陷）
	var 顶栏: PanelContainer = UITheme.建顶栏("法宝阁", _on返回)
	main.add_child(顶栏)

	# 标签栏
	var 标签栏: HBoxContainer = HBoxContainer.new()
	标签栏.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(标签栏)

	# ★ 2026-09-16（#009 逐页精修）：建钮循环收口到 UITheme.建标签栏（原先 19 页各自手搓，
	#   且 custom_minimum_size 宽度在 80/90/100/110 之间漂移）。统一为最小宽 100 + EXPAND_FILL
	#   ⇒ 少量页签自动均分不空、多量页签不溢出、宽度全局一致。
	_tab_btns = UITheme.建标签栏(标签栏, TABS, Callable(self, "_切换标签"), _cur)

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
	# ★ PH7-14：内容区套左右边距（MARGIN），消除正文贴屏幕左边缘（x=0）同型缺陷
	_content.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_content.add_theme_constant_override("margin_right", UITheme.MARGIN)
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
	_添加信息项(统计网格, "总道行", str(int(统计.get("总战力", 0))))
	_添加信息项(统计网格, "平均道行", str(int(统计.get("平均战力", 0))))

	# 图鉴进度
	_添加面板标题("图鉴进度")
	var 进度文本: Label = Label.new()
	进度文本.text = "普通法宝：已收录 %d / %d 件  |  本命法宝：已收录 %d / %d 件" % [
		_普通法宝缓存.size(), _普通法宝缓存.size(),
		_本命法宝缓存.size(), _本命法宝缓存.size()
	]
	进度文本.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	UITheme.apply_project_font(进度文本, UITheme.FONT_BODY)
	_content.add_child(进度文本)

	# 已装备法宝列表（★ 2026-09-15：本命法宝为弟子自身祭炼所得，非外购/发放）
	_添加面板标题("宗门已立本命法宝（共 %d 件）" % int(统计.get("已装备数", 0)))

	if 法宝列表.is_empty():
		_添加空状态("暂无本命法宝", "本命法宝非外物，须由弟子自身以精血神识温养而成：\n境界至「金丹」且机缘加身，方能在洞府闭门祭炼。\n（弟子详情 · 装备页 · 本命法宝槽 可察其境界与机缘）")
		return

	# 表头
	var 表头: HBoxContainer = HBoxContainer.new()
	表头.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(表头)

	var 列宽: Array = [200, 120, 150, 150, 280, -1]  # -1 = 末列 EXPAND_FILL 填满内容宽
	var 列名: Array = ["法宝名", "品阶", "类别", "道行", "所属弟子", "状态"]
	for i in range(列名.size()):
		var 列标签: Label = Label.new()
		列标签.text = 列名[i]
		if 列宽[i] >= 0:
			列标签.custom_minimum_size = Vector2(列宽[i], 24)
		else:
			列标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		列标签.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
		UITheme.apply_project_font(列标签, UITheme.FONT_AUX)
		表头.add_child(列标签)
		列标签.modulate.a = 0.0
		列标签.create_tween().tween_property(列标签, "modulate:a", 1.0, 0.25)
	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)
	# 法宝列表
	for 法宝 in 法宝列表:
		var 行: HBoxContainer = HBoxContainer.new()
		行.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
		var 名标签: Label = Label.new()
		名标签.text = str(法宝.get("名称", "未知"))
		if 列宽[0] >= 0:
			名标签.custom_minimum_size = Vector2(列宽[0], 24)
		UITheme.apply_project_font(名标签, UITheme.FONT_BODY)
		行.add_child(名标签)
		名标签.modulate.a = 0.0
		名标签.create_tween().tween_property(名标签, "modulate:a", 1.0, 0.25)
		var 品阶标签: Label = Label.new()
		品阶标签.text = str(法宝.get("品阶", "未知"))
		if 列宽[1] >= 0:
			品阶标签.custom_minimum_size = Vector2(列宽[1], 24)
		品阶标签.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
		UITheme.apply_project_font(品阶标签, UITheme.FONT_AUX)
		行.add_child(品阶标签)
		品阶标签.modulate.a = 0.0
		品阶标签.create_tween().tween_property(品阶标签, "modulate:a", 1.0, 0.25)
		var 类别标签: Label = Label.new()
		类别标签.text = str(法宝.get("类别", "未知"))
		if 列宽[2] >= 0:
			类别标签.custom_minimum_size = Vector2(列宽[2], 24)
		UITheme.apply_project_font(类别标签, UITheme.FONT_BODY)
		行.add_child(类别标签)
		类别标签.modulate.a = 0.0
		类别标签.create_tween().tween_property(类别标签, "modulate:a", 1.0, 0.25)
		var 战力标签: Label = Label.new()
		战力标签.text = str(int(法宝.get("战力", 0)))
		if 列宽[3] >= 0:
			战力标签.custom_minimum_size = Vector2(列宽[3], 24)
		战力标签.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		UITheme.apply_project_font(战力标签, UITheme.FONT_BODY)
		行.add_child(战力标签)
		战力标签.modulate.a = 0.0
		战力标签.create_tween().tween_property(战力标签, "modulate:a", 1.0, 0.25)
		var 弟子标签: Label = Label.new()
		弟子标签.text = str(法宝.get("所属弟子", "未知"))
		if 列宽[4] >= 0:
			弟子标签.custom_minimum_size = Vector2(列宽[4], 24)
		UITheme.apply_project_font(弟子标签, UITheme.FONT_BODY)
		行.add_child(弟子标签)
		弟子标签.modulate.a = 0.0
		弟子标签.create_tween().tween_property(弟子标签, "modulate:a", 1.0, 0.25)
		var 状态标签: Label = Label.new()
		var 已装备: bool = bool(法宝.get("已装备", false))
		状态标签.text = "已装备" if 已装备 else "背包中"
		if 列宽[5] >= 0:
			状态标签.custom_minimum_size = Vector2(列宽[5], 24)
		else:
			状态标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if 已装备:
			状态标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		else:
			状态标签.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
		UITheme.apply_project_font(状态标签, UITheme.FONT_BODY)
		行.add_child(状态标签)
		状态标签.modulate.a = 0.0
		状态标签.create_tween().tween_property(状态标签, "modulate:a", 1.0, 0.25)


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
			卡片.modulate.a = 0.0
			卡片.create_tween().tween_property(卡片, "modulate:a", 1.0, 0.25)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)
			名栏.modulate.a = 0.0
			名栏.create_tween().tween_property(名栏, "modulate:a", 1.0, 0.25)

			var 名: Label = Label.new()
			名.text = "◆ %s" % str(法宝.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
			UITheme.apply_project_font(名, UITheme.FONT_H2, true)
			名栏.add_child(名)
			名.modulate.a = 0.0
			名.create_tween().tween_property(名, "modulate:a", 1.0, 0.25)

			var 品阶: Label = Label.new()
			品阶.text = "  [%s·%s]" % [str(法宝.get("品阶", "")), str(法宝.get("子品阶", ""))]
			品阶.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
			UITheme.apply_project_font(品阶, UITheme.FONT_AUX)
			名栏.add_child(品阶)
			品阶.modulate.a = 0.0
			品阶.create_tween().tween_property(品阶, "modulate:a", 1.0, 0.25)

			var 属性栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(属性栏)
			属性栏.modulate.a = 0.0
			属性栏.create_tween().tween_property(属性栏, "modulate:a", 1.0, 0.25)

			var 攻击: Label = Label.new()
			攻击.text = "攻+%d" % int(法宝.get("攻击", 0))
			攻击.custom_minimum_size = Vector2(60, 20)
			攻击.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
			UITheme.apply_project_font(攻击, UITheme.FONT_BODY)
			属性栏.add_child(攻击)
			攻击.modulate.a = 0.0
			攻击.create_tween().tween_property(攻击, "modulate:a", 1.0, 0.25)

			var 防御: Label = Label.new()
			防御.text = "防+%d" % int(法宝.get("防御", 0))
			防御.custom_minimum_size = Vector2(60, 20)
			防御.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			UITheme.apply_project_font(防御, UITheme.FONT_BODY)
			属性栏.add_child(防御)
			防御.modulate.a = 0.0
			防御.create_tween().tween_property(防御, "modulate:a", 1.0, 0.25)

			var 气血: Label = Label.new()
			气血.text = "血+%d" % int(法宝.get("气血", 0))
			气血.custom_minimum_size = Vector2(60, 20)
			气血.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
			UITheme.apply_project_font(气血, UITheme.FONT_BODY)
			属性栏.add_child(气血)
			气血.modulate.a = 0.0
			气血.create_tween().tween_property(气血, "modulate:a", 1.0, 0.25)

			var 售价: Label = Label.new()
			售价.text = "售价：%d灵石" % int(法宝.get("售价", 0))
			售价.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			UITheme.apply_project_font(售价, UITheme.FONT_BODY)
			属性栏.add_child(售价)
			售价.modulate.a = 0.0
			售价.create_tween().tween_property(售价, "modulate:a", 1.0, 0.25)

			var 效果: Label = Label.new()
			效果.text = "被动：%s（%s）" % [str(法宝.get("被动效果", "")), str(法宝.get("效果值", ""))]
			效果.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			UITheme.apply_project_font(效果, UITheme.FONT_AUX)
			卡片.add_child(效果)
			效果.modulate.a = 0.0
			效果.create_tween().tween_property(效果, "modulate:a", 1.0, 0.25)

			# 持有标录：普通法宝是外物，归弟子储物袋随身携带；收入/取出在 弟子·装备页 的储物袋面板操作
			# （此处为图鉴，不再直接改装备态，避免「宗主独占法宝」的旧口径）
			var 按钮栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(按钮栏)
			按钮栏.modulate.a = 0.0
			按钮栏.create_tween().tween_property(按钮栏, "modulate:a", 1.0, 0.25)

			var 持有者: String = _查找持有该法宝的弟子(str(法宝.get("id", "")))
			var 持有标签: Label = Label.new()
			if 持有者 != "":
				持有标签.text = "储物袋持有：%s" % 持有者
				持有标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
			else:
				持有标签.text = "尚无弟子携带（可在弟子·装备页收入储物袋）"
				持有标签.add_theme_color_override("font_color", Color(0.58, 0.62, 0.64))
			持有标签.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			持有标签.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_project_font(持有标签, UITheme.FONT_AUX)
			按钮栏.add_child(持有标签)
			持有标签.modulate.a = 0.0
			持有标签.create_tween().tween_property(持有标签, "modulate:a", 1.0, 0.25)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)
			分隔.modulate.a = 0.0
			分隔.create_tween().tween_property(分隔, "modulate:a", 1.0, 0.25)


# 查找储物袋中携带该法宝的弟子（多人则顿号相连）
func _查找持有该法宝的弟子(法宝ID: String) -> String:
	var 名册: Array = []
	for d in Game.弟子列表:
		if d != null and "储物袋法宝" in d and d.储物袋法宝.has(法宝ID):
			名册.append(str(d.姓名))
	return "、".join(名册)


# ==================== 本命法宝页 ====================
func _填本命法宝() -> void:
	if _本命法宝缓存.is_empty():
		_添加空状态("本命法宝配置为空", "treasure_innate.csv 未加载或为空。")
		return

	_添加面板标题("本命法宝图鉴（共 %d 件）" % _本命法宝缓存.size())

	# ★ 2026-09-15（老大定）：本命法宝 = 弟子自身祭炼所得，法宝阁**只作图鉴**，
	#   不提供任何"发放/购买"入口；成器条件为「境界 ≥ 金丹 + 机缘检定」。
	#   此处三行说明即"世界观口径"，与弟子装备页的本命法宝槽一一对应。
	_添加子标题("祭炼须知")
	_添加说明("本命法宝与神魂相连、同生共死，故不可外购、不可转赠、不可夺取；\n须由弟子自身以精血神识温养而成，损毁则伤及道基。\n成器门槛：境界 ≥ 金丹 ｜ 机缘检定通过（弟子详情 · 装备页可查）")

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
			卡片.modulate.a = 0.0
			卡片.create_tween().tween_property(卡片, "modulate:a", 1.0, 0.25)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)
			名栏.modulate.a = 0.0
			名栏.create_tween().tween_property(名栏, "modulate:a", 1.0, 0.25)

			var 名: Label = Label.new()
			名.text = "★ %s" % str(法宝.get("名", "未知"))
			名.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			UITheme.apply_project_font(名, UITheme.FONT_H2, true)
			名栏.add_child(名)
			名.modulate.a = 0.0
			名.create_tween().tween_property(名, "modulate:a", 1.0, 0.25)

			var 品阶: Label = Label.new()
			品阶.text = "  [%s·%s]" % [str(法宝.get("品阶", "")), str(法宝.get("子品阶", ""))]
			品阶.add_theme_color_override("font_color", _品阶颜色(str(法宝.get("品阶", ""))))
			UITheme.apply_project_font(品阶, UITheme.FONT_AUX)
			名栏.add_child(品阶)
			品阶.modulate.a = 0.0
			品阶.create_tween().tween_property(品阶, "modulate:a", 1.0, 0.25)

			var 主动技栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(主动技栏)
			主动技栏.modulate.a = 0.0
			主动技栏.create_tween().tween_property(主动技栏, "modulate:a", 1.0, 0.25)

			var 主动技标签: Label = Label.new()
			主动技标签.text = "主动技："
			主动技标签.add_theme_color_override("font_color", Color(0.8, 0.6, 0.8))
			UITheme.apply_project_font(主动技标签, UITheme.FONT_AUX)
			主动技栏.add_child(主动技标签)
			主动技标签.modulate.a = 0.0
			主动技标签.create_tween().tween_property(主动技标签, "modulate:a", 1.0, 0.25)

			var 主动技: Label = Label.new()
			主动技.text = str(法宝.get("主动技", "未知"))
			主动技.add_theme_color_override("font_color", Color(0.9, 0.7, 0.9))
			UITheme.apply_project_font(主动技, UITheme.FONT_BODY)
			主动技栏.add_child(主动技)
			主动技.modulate.a = 0.0
			主动技.create_tween().tween_property(主动技, "modulate:a", 1.0, 0.25)

			var 属性栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(属性栏)
			属性栏.modulate.a = 0.0
			属性栏.create_tween().tween_property(属性栏, "modulate:a", 1.0, 0.25)

			var 成长: Label = Label.new()
			成长.text = "成长：%s" % str(法宝.get("成长值", "未知"))
			成长.custom_minimum_size = Vector2(100, 20)
			成长.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
			UITheme.apply_project_font(成长, UITheme.FONT_BODY)
			属性栏.add_child(成长)
			成长.modulate.a = 0.0
			成长.create_tween().tween_property(成长, "modulate:a", 1.0, 0.25)

			var 最大等级: Label = Label.new()
			最大等级.text = "最高品级：第%d重" % int(法宝.get("最大等级", 0))
			最大等级.custom_minimum_size = Vector2(100, 20)
			最大等级.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
			UITheme.apply_project_font(最大等级, UITheme.FONT_BODY)
			属性栏.add_child(最大等级)
			最大等级.modulate.a = 0.0
			最大等级.create_tween().tween_property(最大等级, "modulate:a", 1.0, 0.25)

			var 献祭: Label = Label.new()
			献祭.text = "献祭材料：%s" % str(法宝.get("献祭材料", "未知"))
			献祭.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			UITheme.apply_project_font(献祭, UITheme.FONT_BODY)
			属性栏.add_child(献祭)
			献祭.modulate.a = 0.0
			献祭.create_tween().tween_property(献祭, "modulate:a", 1.0, 0.25)

			var 被动: Label = Label.new()
			被动.text = "被动：%s" % str(法宝.get("被动效果", ""))
			被动.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
			UITheme.apply_project_font(被动, UITheme.FONT_AUX)
			卡片.add_child(被动)
			被动.modulate.a = 0.0
			被动.create_tween().tween_property(被动, "modulate:a", 1.0, 0.25)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)
			分隔.modulate.a = 0.0
			分隔.create_tween().tween_property(分隔, "modulate:a", 1.0, 0.25)


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
	UITheme.apply_project_font(空标题, UITheme.FONT_TITLE, true)
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
	UITheme.apply_section_title(标题标签)
	_content.add_child(标题标签)

	var 分隔: HSeparator = HSeparator.new()
	_content.add_child(分隔)


func _添加子标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, 6)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "● %s" % 标题
	UITheme.apply_section_title(标题标签)
	_content.add_child(标题标签)


## 说明段落（长文案 → 必须 AUTOWRAP_WORD_SMART，否则撑破屏宽）
func _添加说明(文本: String) -> void:
	var 说明: Label = Label.new()
	说明.text = 文本
	说明.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	说明.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_project_font(说明, UITheme.FONT_AUX, false)
	说明.add_theme_color_override("font_color", Color(0.72, 0.76, 0.70))
	_content.add_child(说明)


func _添加信息项(网格: GridContainer, 标签: String, 值: String) -> void:
	var 标签控件: Label = Label.new()
	标签控件.text = 标签 + "："
	标签控件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	标签控件.custom_minimum_size = Vector2(100, 24)
	UITheme.apply_project_font(标签控件, UITheme.FONT_AUX)
	网格.add_child(标签控件)
	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	UITheme.apply_project_font(值控件, UITheme.FONT_BODY)
	网格.add_child(值控件)


func _on返回() -> void:
	返回主页.emit()
