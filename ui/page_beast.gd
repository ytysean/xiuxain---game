extends Control
# 灵兽/坐骑/血脉管理UI：总览 / 灵兽库 / 出战绑定 / 引育计划 / 坐骑
# 后端：beast_management_system.gd（灵兽）+ mount_system.gd（坐骑）
# 入口：main.gd 宗门页快捷网格「灵兽」→ 二级页
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "灵兽库", "出战绑定", "引育计划", "繁殖", "坐骑"]

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
	# ★ 2026-09-17 G1（06 灵兽 · 逐页视觉精修）：背景晕影画框（承 05 F1 逐字同款）。
	#   顶 0–11% / 底 88–100% 压暗，中部 11–88% 全透明（＝视觉安全区收缩，非全屏不透明蒙版）。
	#   铁律三条：① 只引 UITheme.建背景晕影渐变() **原样**，禁改停点；
	#             ② 禁碰 获取场景压暗色()（ui_theme.gd:1566）本体；
	#             ③ 零新色值（色字面量须留在 ui_theme.gd）。
	#   置于 main 之前 ⇒ 层级在内容之下；mouse_filter=IGNORE 不拦触控。
	var 背景: TextureRect = TextureRect.new()
	背景.name = "BGVeil"
	背景.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var 背景渐变: GradientTexture2D = GradientTexture2D.new()
	背景渐变.gradient = UITheme.建背景晕影渐变()
	背景渐变.fill_from = Vector2(0.5, 0.0)
	背景渐变.fill_to = Vector2(0.5, 1.0)
	背景.texture = 背景渐变
	背景.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	背景.stretch_mode = TextureRect.STRETCH_SCALE
	背景.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(背景)

	# ★ D1（#009 逐页精修 · 灵兽苑）：底部上浮灵气微粒，暖金柔点，零美术依赖、mouse_filter=IGNORE 不拦触控。
	_build_灵气()

	var main: VBoxContainer = VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 8)
	main.add_theme_constant_override("margin_left", UITheme.MARGIN)
	main.add_theme_constant_override("margin_right", UITheme.MARGIN)
	add_child(main)

	# ★ 2026-09-17 G2（06 灵兽 · 逐页视觉精修）：顶栏接统一房模板（18 页同款，含坊市
	#   page_shop.gd:104 / 05 灵钓 page_fishing.gd:65）。返回钮走 make_back_button ⇒ 得返回环；
	#   标题走 apply_page_title(FONT_TITLE=45)；bar 最小高 SIZE_SM=72 物理。
	#   原手搓 HBox＋裸 Button(min 120×36)＋裸 Label 一并移除。
	#   M1 随本条自然消解：原「  灵兽苑」前导空格对齐 hack 去掉。
	main.add_child(UITheme.建顶栏("灵兽苑", _on返回))

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

	# 显示提示
	if _提示 != "":
		var 提示标签: Label = Label.new()
		提示标签.text = _提示
		提示标签.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		_content.add_child(提示标签)
		_提示 = ""

	match _cur:
		"总览":
			_填总览()
		"灵兽库":
			_填灵兽库()
		"出战绑定":
			_填出战绑定()
		"引育计划":
			_填引育计划()
		"繁殖":
			_填繁殖()
		"坐骑":
			_填坐骑()


# ==================== 总览页 ====================
func _填总览() -> void:
	var 灵兽统计: Dictionary = Game.灵兽管理系统.获取灵兽统计()
	var 坐骑统计: Dictionary = Game.坐骑系统.获取坐骑统计()

	# 灵兽统计
	_添加面板标题("灵兽统计")

	var 灵兽网格: GridContainer = GridContainer.new()
	灵兽网格.columns = 2
	灵兽网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(灵兽网格)

	_添加信息项(灵兽网格, "灵兽总数", str(int(灵兽统计.get("总数", 0))))
	_添加信息项(灵兽网格, "苑中", str(int(灵兽统计.get("库存数", 0))))
	_添加信息项(灵兽网格, "孵化中", str(int(灵兽统计.get("孵化中数", 0))))
	_添加信息项(灵兽网格, "出战中", str(int(灵兽统计.get("出战数", 0))))
	_添加信息项(灵兽网格, "总道行", str(int(灵兽统计.get("总战力", 0))))
	_添加信息项(灵兽网格, "平均等级", str(int(灵兽统计.get("平均等级", 0))))
	_添加信息项(灵兽网格, "最高等级", str(int(灵兽统计.get("最高等级", 0))))
	_添加信息项(灵兽网格, "最高道行", str(int(灵兽统计.get("最高战力", 0))))
	_添加信息项(灵兽网格, "神兽血脉", str(int(灵兽统计.get("神兽血脉数", 0))))

	# 孵化中队列（含倒计时）
	if Game.灵兽蛋列表.size() > 0:
		_添加子标题("孵化中（%d只）" % Game.灵兽蛋列表.size())
		for 蛋 in Game.灵兽蛋列表:
			var 蛋行: HBoxContainer = HBoxContainer.new()
			_content.add_child(蛋行)
			var 蛋名: Label = Label.new()
			蛋名.text = "◌ %s" % str(蛋.种类名)
			蛋名.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
			蛋行.add_child(蛋名)
			var 倒计时: Label = Label.new()
			倒计时.text = "  剩余 %d 日" % int(蛋.剩余天数)
			倒计时.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			蛋行.add_child(倒计时)

	# 品阶分布
	# ★ 2026-09-16 修（#009 逐页精修 · 灵兽苑）：原实现**无条件** add 空的 `品阶行`，
	#   而循环内 `if 数 > 0` 又跳过全部 0 值 ⇒ 无灵兽时留下「品阶分布」标题 + 一个空行，
	#   实机上就是标题下的一片空白（被当成"这页没加载完"）。对照「类型分布」并不过滤、
	#   显示全 0 的行为，两者本就不一致。改为：有货才出行，无货给一行弱文字说明。
	_添加子标题("品阶分布")
	var 品阶显示: Dictionary = {"fan_jie": "凡阶", "ling_jie": "灵阶", "bao_jie": "宝阶", "wang_jie": "王阶", "sheng_jie": "圣阶", "xian_jie": "仙阶", "dao_jie": "道阶", "hun_jie": "混沌阶"}
	var 品阶分布: Dictionary = 灵兽统计.get("品阶分布", {})
	var 品阶行: HBoxContainer = HBoxContainer.new()
	for 品阶键 in 品阶显示.keys():
		var 数: int = int(品阶分布.get(品阶键, 0))
		if 数 > 0:
			var 标签: Label = Label.new()
			标签.text = "%s:%d " % [品阶显示.get(品阶键, 品阶键), 数]
			标签.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			品阶行.add_child(标签)
	if 品阶行.get_child_count() > 0:
		_content.add_child(品阶行)
	else:
		# 用统一空态组件（自带最小宽度下限，避免 autowrap Label 在滚动容器里塌缩成竖排长条）
		_content.add_child(UITheme.建空态("尚无灵兽入册", "可于山野间驯服，或于灵兽库中孵化", "", true))

	# 类型分布
	_添加子标题("类型分布")
	var 类型显示: Dictionary = {"attack": "攻击", "defense": "防御", "support": "辅助"}
	var 类型分布: Dictionary = 灵兽统计.get("类型分布", {})
	var 类型行: HBoxContainer = HBoxContainer.new()
	for 类型键 in 类型显示.keys():
		var 数: int = int(类型分布.get(类型键, 0))
		var 标签: Label = Label.new()
		标签.text = "%s:%d " % [类型显示.get(类型键, 类型键), 数]
		标签.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		类型行.add_child(标签)
	_content.add_child(类型行)

	# 坐骑统计
	_添加面板标题("坐骑统计")

	var 坐骑网格: GridContainer = GridContainer.new()
	坐骑网格.columns = 2
	坐骑网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(坐骑网格)

	_添加信息项(坐骑网格, "坐骑总数", str(int(坐骑统计.get("总数", 0))))
	_添加信息项(坐骑网格, "已激活", str(int(坐骑统计.get("已激活数", 0))))
	_添加信息项(坐骑网格, "总速度加成", "+%.0f%%" % [float(坐骑统计.get("总速度加成", 0)) * 100])
	_添加信息项(坐骑网格, "总道行加成", "+%d" % int(坐骑统计.get("总战力加成", 0)))

	# 当前资源
	_添加面板标题("当前资源")
	var 资源网格: GridContainer = GridContainer.new()
	资源网格.columns = 2
	资源网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(资源网格)
	_添加信息项(资源网格, "灵石", str(int(Game.灵石)))
	_添加信息项(资源网格, "灵草", str(int(Game.灵草)))

	# 快捷操作
	_添加面板标题("快捷操作")
	var 操作栏: HBoxContainer = HBoxContainer.new()
	_content.add_child(操作栏)

	# §4.12 宗主理政法：一键 → 方针（宗主定方针，门下按月自动培养，不逐只点）
	var 方针按钮: Button = Button.new()
	方针按钮.text = "培养方针：%s" % _当前培养方针()
	方针按钮.custom_minimum_size = Vector2(140, 32)
	UITheme.apply_secondary_button_style(方针按钮)
	方针按钮.modulate = Color(0.8, 1.0, 0.8)
	方针按钮.pressed.connect(_切换培养方针)
	操作栏.add_child(方针按钮)

	var 催办按钮: Button = Button.new()
	催办按钮.text = "催办一次"
	催办按钮.custom_minimum_size = Vector2(90, 32)
	UITheme.apply_secondary_button_style(催办按钮)
	催办按钮.pressed.connect(_按方针催办)
	操作栏.add_child(催办按钮)


## 当前培养方针（读 Game；缺省「均衡」）
func _当前培养方针() -> String:
	if not is_instance_valid(Game) or "灵兽培养方针" not in Game:
		return "均衡"
	return String(Game.灵兽培养方针)

## 循环切换 节俭 → 均衡 → 精进
func _切换培养方针() -> void:
	var 表: Array = ["节俭", "均衡", "精进"]
	var 当前: String = _当前培养方针()
	var idx: int = 表.find(当前)
	var 下一个: String = String(表[(idx + 1) % 表.size()] if idx >= 0 else 表[0])
	var 结果: Dictionary = Game.灵兽管理系统.设置培养方针(下一个)
	_反馈(str(结果.get("消息", "培养方针已更新")))

## 一键执行「已定方针」（§2.0 唯一合法的一键形态）
func _按方针催办() -> void:
	var 结果: Dictionary = Game.灵兽管理系统.按方针培养灵兽()
	_反馈(str(结果.get("消息", "培养未执行")))


# ==================== 灵兽库页 ====================
func _填灵兽库() -> void:
	var 灵兽列表: Array = Game.灵兽管理系统.获取所有灵兽列表()

	if 灵兽列表.is_empty():
		_content.add_child(UITheme.建空态("暂无灵兽", "灵兽苑尚空，可通过引育计划或历练获取灵兽。", "", true))
		return

	_添加子标题("灵兽列表（%d只）" % 灵兽列表.size())

	var 品阶显示: Dictionary = {"fan_jie": "凡阶", "ling_jie": "灵阶", "bao_jie": "宝阶", "wang_jie": "王阶", "sheng_jie": "圣阶", "xian_jie": "仙阶", "dao_jie": "道阶", "hun_jie": "混沌阶"}
	var 类型显示: Dictionary = {"attack": "攻击", "defense": "防御", "support": "辅助"}

	for i in range(灵兽列表.size()):
		var 灵兽: Dictionary = 灵兽列表[i]
		var 卡片: VBoxContainer = VBoxContainer.new()
		卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(卡片)
		_卡片淡入(卡片)

		var 名栏: HBoxContainer = HBoxContainer.new()
		卡片.add_child(名栏)

		var 名: Label = Label.new()
		var 品阶名: String = 品阶显示.get(str(灵兽.get("品阶", "")), str(灵兽.get("品阶", "")))
		var 类型名: String = 类型显示.get(str(灵兽.get("类型", "")), str(灵兽.get("类型", "")))
		名.text = "【%s】%s（%s）" % [品阶名, str(灵兽.get("种类名", "")), 类型名]
		名.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
		UITheme.apply_project_font(名, UITheme.FONT_H2, true)
		名栏.add_child(名)

		var 状态: Label = Label.new()
		状态.text = "  [%s]" % str(灵兽.get("状态", ""))
		状态.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if "主宠" in str(灵兽.get("状态", "")) else Color(0.7, 0.7, 0.7))
		名栏.add_child(状态)

		var 属性栏: HBoxContainer = HBoxContainer.new()
		卡片.add_child(属性栏)

		var 等级标签: Label = Label.new()
		等级标签.text = "品级：%d/%d" % [int(灵兽.get("等级", 0)), int(灵兽.get("等级上限", 0))]
		等级标签.custom_minimum_size = Vector2(120, 20)
		等级标签.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		属性栏.add_child(等级标签)

		var 忠诚标签: Label = Label.new()
		忠诚标签.text = "忠诚：%d" % int(灵兽.get("忠诚", 0))
		忠诚标签.custom_minimum_size = Vector2(100, 20)
		忠诚标签.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
		属性栏.add_child(忠诚标签)

		var 战力标签: Label = Label.new()
		战力标签.text = "道行：%d" % int(灵兽.get("战力", 0))
		战力标签.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		属性栏.add_child(战力标签)

		# 操作按钮（仅库存中的灵兽可操作）
		if str(灵兽.get("状态", "")) == "库存":
			var 按钮栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(按钮栏)

			var 进化按钮: Button = Button.new()
			var 进化消耗: Dictionary = Game.灵兽管理系统.获取灵兽进化消耗(i)
			if bool(进化消耗.get("是否可进化", false)):
				进化按钮.text = "进化（%d灵石+%d灵草）" % [int(进化消耗.get("进化消耗灵石", 0)), int(进化消耗.get("进化消耗灵草", 0))]
				进化按钮.modulate = Color(1.0, 0.9, 0.5)
			else:
				进化按钮.text = "进化（未达条件）"
				进化按钮.disabled = true
				进化按钮.modulate = Color(0.6, 0.6, 0.6)
			进化按钮.custom_minimum_size = Vector2(200, 28)
			UITheme.apply_secondary_button_style(进化按钮)
			进化按钮.pressed.connect(Callable(self, "_进化灵兽").bind(i))
			按钮栏.add_child(进化按钮)

		var 分隔: HSeparator = HSeparator.new()
		卡片.add_child(分隔)


func _进化灵兽(索引: int) -> void:
	var 结果: Dictionary = Game.灵兽管理系统.灵兽进化(索引)
	if bool(结果.get("成功", false)):
		_提示 = "%s进化为%s成功！" % [str(结果.get("灵兽", {}).get("种类名", "")), str(结果.get("新品阶显示", ""))]
	else:
		_提示 = "进化失败：%s" % str(结果.get("原因", "未知错误"))
	_反馈(_提示)


# ==================== 出战绑定页 ====================
func _填出战绑定() -> void:
	_添加子标题("弟子灵兽出战状态")

	var 有出战弟子: bool = false
	for d in Game.弟子列表:
		if d == null:
			continue
		if d.主宠灵兽 != null or d.副宠灵兽 != null:
			有出战弟子 = true
			var 卡片: VBoxContainer = VBoxContainer.new()
			卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(卡片)
			_卡片淡入(卡片)

			var 名栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(名栏)

			var 弟子名: Label = Label.new()
			弟子名.text = "弟子：%s（%s）" % [d.姓名, d.境界]
			弟子名.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
			UITheme.apply_project_font(弟子名, UITheme.FONT_H2, true)
			名栏.add_child(弟子名)

			if d.主宠灵兽 != null:
				var 主宠栏: HBoxContainer = HBoxContainer.new()
				卡片.add_child(主宠栏)
				var 主宠标签: Label = Label.new()
				主宠标签.text = "  主宠：%s（%d 阶，道行%d）" % [d.主宠灵兽.种类名, d.主宠灵兽.等级, d.主宠灵兽.本体战力()]
				主宠标签.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
				主宠栏.add_child(主宠标签)

				var 解绑主宠按钮: Button = Button.new()
				解绑主宠按钮.text = "解绑"
				解绑主宠按钮.custom_minimum_size = Vector2(60, 24)
				UITheme.apply_secondary_button_style(解绑主宠按钮)
				解绑主宠按钮.modulate = Color(1.0, 0.7, 0.7)
				解绑主宠按钮.pressed.connect(Callable(self, "_解绑灵兽").bind(d, "主宠"))
				主宠栏.add_child(解绑主宠按钮)

			if d.副宠灵兽 != null:
				var 副宠栏: HBoxContainer = HBoxContainer.new()
				卡片.add_child(副宠栏)
				var 副宠标签: Label = Label.new()
				副宠标签.text = "  副宠：%s（%d 阶，道行%d）" % [d.副宠灵兽.种类名, d.副宠灵兽.等级, d.副宠灵兽.本体战力()]
				副宠标签.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
				副宠栏.add_child(副宠标签)

				var 解绑副宠按钮: Button = Button.new()
				解绑副宠按钮.text = "解绑"
				解绑副宠按钮.custom_minimum_size = Vector2(60, 24)
				UITheme.apply_secondary_button_style(解绑副宠按钮)
				解绑副宠按钮.modulate = Color(1.0, 0.7, 0.7)
				解绑副宠按钮.pressed.connect(Callable(self, "_解绑灵兽").bind(d, "副宠"))
				副宠栏.add_child(解绑副宠按钮)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)

	if not 有出战弟子:
		_content.add_child(UITheme.建空态("暂无出战灵兽", "目前没有弟子绑定灵兽，可在「灵兽库」中查看苑中灵兽。", "", true))

	# 库存灵兽快速绑定
	_添加面板标题("苑中灵兽（可绑定）")
	var 库存数: int = 0
	for 兽 in Game.灵兽管理系统.灵兽库存:
		if 兽 != null and not 兽.孵化中:
			库存数 += 1
			var 栏: HBoxContainer = HBoxContainer.new()
			_content.add_child(栏)

			var 名: Label = Label.new()
			名.text = "%s（%d 阶，道行%d）" % [兽.种类名, 兽.等级, 兽.本体战力()]
			名.custom_minimum_size = Vector2(200, 24)
			名.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
			栏.add_child(名)

			var 绑定按钮: Button = Button.new()
			绑定按钮.text = "绑定给首只合体"
			绑定按钮.custom_minimum_size = Vector2(140, 24)
			UITheme.apply_secondary_button_style(绑定按钮)
			绑定按钮.modulate = Color(0.8, 1.0, 0.8)
			绑定按钮.pressed.connect(Callable(self, "_快速绑定").bind(兽))
			栏.add_child(绑定按钮)

	if 库存数 == 0:
		var 空: Label = Label.new()
		空.text = "苑中暂无可用灵兽"
		空.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_content.add_child(空)


func _解绑灵兽(弟子: Object, 槽位: String) -> void:
	var 消息: String = Game.灵兽管理系统.解绑灵兽(弟子, 槽位)
	_反馈(消息)


func _快速绑定(灵兽: Object) -> void:
	var 消息: String = Game.灵兽管理系统.绑定灵兽给首只合体(灵兽)
	_反馈(消息)


# ==================== 引育计划页 ====================
func _填引育计划() -> void:
	var 队列: Array = Game.灵兽管理系统.灵兽兑换队列

	_添加子标题("引育计划队列（%d项）" % 队列.size())

	if 队列.is_empty():
		_content.add_child(UITheme.建空态("暂无引育计划", "可添加引育计划，自动拨付灵石引育灵兽。", "", true))
	else:
		for i in range(队列.size()):
			var 条目: Dictionary = 队列[i]
			var 卡片: VBoxContainer = VBoxContainer.new()
			卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_content.add_child(卡片)
			_卡片淡入(卡片)

			var 栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(栏)

			var 状态图标: String = "●" if bool(条目.get("启用", false)) else "○"
			var 状态颜色: Color = Color(0.6, 1.0, 0.6) if bool(条目.get("启用", false)) else Color(0.6, 0.6, 0.6)
			var 名: Label = Label.new()
			名.text = "%s 引育计划 #%d" % [状态图标, i + 1]
			名.add_theme_color_override("font_color", 状态颜色)
			UITheme.apply_project_font(名, UITheme.FONT_H2, true)
			栏.add_child(名)

			var 经费: Label = Label.new()
			经费.text = "  经费：%d灵石" % int(条目.get("cost", 0))
			经费.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
			栏.add_child(经费)

			var 按钮栏: HBoxContainer = HBoxContainer.new()
			卡片.add_child(按钮栏)

			var 启停按钮: Button = Button.new()
			启停按钮.text = "停用" if bool(条目.get("启用", false)) else "启用"
			启停按钮.custom_minimum_size = Vector2(80, 24)
			UITheme.apply_secondary_button_style(启停按钮)
			启停按钮.pressed.connect(Callable(self, "_启停引育").bind(i))
			按钮栏.add_child(启停按钮)

			var 删除按钮: Button = Button.new()
			删除按钮.text = "删除"
			删除按钮.custom_minimum_size = Vector2(80, 24)
			UITheme.apply_secondary_button_style(删除按钮)
			删除按钮.modulate = Color(1.0, 0.7, 0.7)
			删除按钮.pressed.connect(Callable(self, "_删除引育").bind(i))
			按钮栏.add_child(删除按钮)

			var 分隔: HSeparator = HSeparator.new()
			卡片.add_child(分隔)

	# 添加新计划
	_添加面板标题("添加引育计划")
	var 输入栏: HBoxContainer = HBoxContainer.new()
	_content.add_child(输入栏)

	var 经费标签: Label = Label.new()
	UITheme.apply_body_text(经费标签)
	经费标签.text = "经费（灵石）："
	输入栏.add_child(经费标签)

	var 经费输入: LineEdit = LineEdit.new()
	经费输入.text = "1000"
	经费输入.custom_minimum_size = Vector2(100, 28)
	输入栏.add_child(经费输入)

	var 添加按钮: Button = Button.new()
	添加按钮.text = "添加计划"
	添加按钮.custom_minimum_size = Vector2(100, 28)
	UITheme.apply_secondary_button_style(添加按钮)
	添加按钮.modulate = Color(0.8, 1.0, 0.8)
	添加按钮.pressed.connect(Callable(self, "_添加引育").bind(经费输入))
	输入栏.add_child(添加按钮)


func _启停引育(序号: int) -> void:
	var 消息: String = Game.灵兽管理系统.灵兽兑换_启停(序号)
	_反馈(消息)


func _删除引育(序号: int) -> void:
	var 消息: String = Game.灵兽管理系统.灵兽兑换_删除(序号)
	_反馈(消息)


func _添加引育(输入框: LineEdit) -> void:
	var 经费: int = int(输入框.text)
	if 经费 <= 0:
		_反馈("经费必须为正数")
		return
	if 经费 > int(Game.灵石):
		_反馈("灵石不足，当前灵石 %d" % int(Game.灵石))
		return
	var 偏好: Dictionary = {"类型": "随机"}
	var 消息: String = Game.灵兽管理系统.灵兽兑换_新增(偏好, 经费)
	_反馈(消息)


# ==================== 坐骑页 ====================
func _填坐骑() -> void:
	var 坐骑列表: Array = Game.坐骑系统.获取所有坐骑列表()
	var 坐骑统计: Dictionary = Game.坐骑系统.获取坐骑统计()

	# 当前坐骑
	_添加面板标题("当前坐骑")
	var 当前加成: Dictionary = Game.坐骑系统.获取当前坐骑加成()
	var 当前栏: HBoxContainer = HBoxContainer.new()
	_content.add_child(当前栏)

	var 当前名: Label = Label.new()
	当前名.text = "坐骑：%s" % str(当前加成.get("名称", "无"))
	当前名.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
	UITheme.apply_project_font(当前名, UITheme.FONT_H2, true)
	当前栏.add_child(当前名)

	var 加成标签: Label = Label.new()
	加成标签.text = "  速度+%.0f%%，道行+%d" % [float(当前加成.get("速度加成", 0)) * 100, int(当前加成.get("战力加成", 0))]
	加成标签.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	当前栏.add_child(加成标签)

	# 坐骑列表
	_添加面板标题("坐骑列表（%d只）" % 坐骑列表.size())

	for 坐骑 in 坐骑列表:
		var 卡片: VBoxContainer = VBoxContainer.new()
		卡片.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content.add_child(卡片)
		_卡片淡入(卡片)

		var 名栏: HBoxContainer = HBoxContainer.new()
		卡片.add_child(名栏)

		var 状态图标: String = "★" if bool(坐骑.get("当前使用", false)) else ("✓" if bool(坐骑.get("已激活", false)) else "○")
		var 状态颜色: Color = Color(1.0, 0.9, 0.5) if bool(坐骑.get("当前使用", false)) else (Color(0.6, 1.0, 0.6) if bool(坐骑.get("已激活", false)) else Color(0.5, 0.5, 0.5))
		var 名: Label = Label.new()
		名.text = "%s %s（%s）" % [状态图标, str(坐骑.get("名称", "")), str(坐骑.get("品阶", ""))]
		名.add_theme_color_override("font_color", 状态颜色)
		UITheme.apply_project_font(名, UITheme.FONT_H2, true)
		名栏.add_child(名)

		var 类型: Label = Label.new()
		类型.text = "  [%s]" % str(坐骑.get("类型", ""))
		类型.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		名栏.add_child(类型)

		var 属性栏: HBoxContainer = HBoxContainer.new()
		卡片.add_child(属性栏)

		var 速度标签: Label = Label.new()
		速度标签.text = "速度+%.0f%%" % [float(坐骑.get("速度加成", 0)) * 100]
		速度标签.custom_minimum_size = Vector2(100, 20)
		速度标签.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		属性栏.add_child(速度标签)

		var 战力标签: Label = Label.new()
		战力标签.text = "道行+%d" % int(坐骑.get("战力加成", 0))
		战力标签.custom_minimum_size = Vector2(100, 20)
		战力标签.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
		属性栏.add_child(战力标签)

		# 操作按钮
		var 按钮栏: HBoxContainer = HBoxContainer.new()
		卡片.add_child(按钮栏)

		var 坐骑ID: String = str(坐骑.get("id", ""))

		if not bool(坐骑.get("已激活", false)):
			var 激活按钮: Button = Button.new()
			激活按钮.text = "激活"
			激活按钮.custom_minimum_size = Vector2(80, 24)
			UITheme.apply_secondary_button_style(激活按钮)
			激活按钮.modulate = Color(0.8, 1.0, 0.8)
			激活按钮.pressed.connect(Callable(self, "_激活坐骑").bind(坐骑ID))
			按钮栏.add_child(激活按钮)
		else:
			if not bool(坐骑.get("当前使用", false)):
				var 切换按钮: Button = Button.new()
				切换按钮.text = "切换"
				切换按钮.custom_minimum_size = Vector2(80, 24)
				UITheme.apply_secondary_button_style(切换按钮)
				切换按钮.modulate = Color(0.8, 0.9, 1.0)
				切换按钮.pressed.connect(Callable(self, "_切换坐骑").bind(坐骑ID))
				按钮栏.add_child(切换按钮)

			var 升级消耗: Dictionary = Game.坐骑系统.获取坐骑升级消耗(坐骑ID)
			var 升级按钮: Button = Button.new()
			var 当前等级: int = int(升级消耗.get("当前等级", 1))
			var 最大等级: int = int(升级消耗.get("最大等级", 10))
			if 当前等级 >= 最大等级:
				升级按钮.text = "已满级"
				升级按钮.disabled = true
				升级按钮.modulate = Color(0.6, 0.6, 0.6)
			else:
				升级按钮.text = "升级（%d灵石）" % int(升级消耗.get("升级消耗灵石", 0))
				升级按钮.modulate = Color(1.0, 0.9, 0.5)
			升级按钮.custom_minimum_size = Vector2(140, 24)
			UITheme.apply_secondary_button_style(升级按钮)
			升级按钮.pressed.connect(Callable(self, "_升级坐骑").bind(坐骑ID))
			按钮栏.add_child(升级按钮)

			var 培养按钮: Button = Button.new()
			培养按钮.text = "培养（100灵石）"
			培养按钮.custom_minimum_size = Vector2(140, 24)
			UITheme.apply_secondary_button_style(培养按钮)
			培养按钮.pressed.connect(Callable(self, "_培养坐骑").bind(坐骑ID))
			按钮栏.add_child(培养按钮)

		var 分隔: HSeparator = HSeparator.new()
		卡片.add_child(分隔)


func _激活坐骑(坐骑ID: String) -> void:
	var 结果: Dictionary = Game.坐骑系统.激活坐骑(坐骑ID)
	_反馈(str(结果.get("消息", 结果.get("原因", "操作完成"))))


func _切换坐骑(坐骑ID: String) -> void:
	var 结果: Dictionary = Game.坐骑系统.切换坐骑(坐骑ID)
	_反馈(str(结果.get("消息", 结果.get("原因", "操作完成"))))


func _升级坐骑(坐骑ID: String) -> void:
	var 结果: Dictionary = Game.坐骑系统.升级坐骑(坐骑ID)
	_反馈(str(结果.get("消息", 结果.get("原因", "操作完成"))))


func _培养坐骑(坐骑ID: String) -> void:
	var 结果: Dictionary = Game.坐骑系统.培养坐骑(坐骑ID, 1)
	_反馈(str(结果.get("消息", 结果.get("原因", "操作完成"))))


# ==================== 繁殖页 ====================
func _填繁殖() -> void:
	_添加面板标题("灵兽繁殖")

	# 繁殖中列表
	var 繁殖中: Array = Game.繁殖中灵兽 if "繁殖中灵兽" in Game else []
	if 繁殖中.size() > 0:
		_添加面板标题("繁殖中")
		for 繁殖 in 繁殖中:
			var 面板: PanelContainer = PanelContainer.new()
			面板.custom_minimum_size = Vector2(0, 60)
			_content.add_child(面板)
			var vb: VBoxContainer = VBoxContainer.new()
			面板.add_child(vb)
			var 名称标签: Label = Label.new()
			名称标签.text = "%s × %s" % [str(繁殖.get("父名称", "")), str(繁殖.get("母名称", ""))]
			名称标签.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5))
			vb.add_child(名称标签)
			var 进度标签: Label = Label.new()
			var 剩余日: int = int(繁殖.get("完成日", 0)) - int(Game.累计游戏日)
			进度标签.text = "预计品质：%s，剩余%d日产崽" % [str(繁殖.get("预计品质", "普通")), max(0, 剩余日)]
			进度标签.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			vb.add_child(进度标签)

	# 可繁殖灵兽列表
	var 可繁殖: Array = Game.获取可繁殖灵兽列表() if Game.has_method("获取可繁殖灵兽列表") else []
	if 可繁殖.size() < 2:
		_content.add_child(UITheme.建空态("无可繁殖灵兽", "需要至少2只亲密度>=20的契约灵兽才能繁殖", "", true))
		return

	_添加面板标题("选择灵兽配对（亲密度>=20）")
	var 选中列表: Array = []
	for i in range(min(4, 可繁殖.size())):
		var 灵兽: Dictionary = 可繁殖[i]
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", 10)
		_content.add_child(行)
		var 名称标签: Label = Label.new()
		名称标签.text = "%s（%s，道行%d，亲密度%d）" % [str(灵兽.get("名称", "")), str(灵兽.get("境界", "")), int(灵兽.get("战力", 0)), int(灵兽.get("亲密度", 0))]
		名称标签.custom_minimum_size = Vector2(300, 0)
		行.add_child(名称标签)
		var 选择按钮: Button = Button.new()
		选择按钮.text = "选择"
		选择按钮.custom_minimum_size = Vector2(60, 28)
		UITheme.apply_secondary_button_style(选择按钮)
		选择按钮.pressed.connect(Callable(self, "_选择繁殖灵兽").bind(str(灵兽.get("灵兽ID", ""))))
		行.add_child(选择按钮)

	# 开始繁殖按钮
	var 开始按钮: Button = Button.new()
	开始按钮.text = "开始繁殖（需选择2只灵兽，消耗%d灵石）" % (500 * max(1, int(Game.门派等级)))
	开始按钮.custom_minimum_size = Vector2(0, 36)
	UITheme.apply_secondary_button_style(开始按钮)
	开始按钮.pressed.connect(_on开始繁殖)
	_content.add_child(开始按钮)

var _选中繁殖灵兽: Array = []

func _选择繁殖灵兽(灵兽ID: String) -> void:
	if 灵兽ID in _选中繁殖灵兽:
		_选中繁殖灵兽.erase(灵兽ID)
	else:
		if _选中繁殖灵兽.size() >= 2:
			_选中繁殖灵兽.pop_front()
		_选中繁殖灵兽.append(灵兽ID)
	_反馈("已选择%d只灵兽" % _选中繁殖灵兽.size())

func _on开始繁殖() -> void:
	if _选中繁殖灵兽.size() < 2:
		_反馈("请先选择2只灵兽")
		return
	var 结果: Dictionary = Game.开始灵兽繁殖(_选中繁殖灵兽[0], _选中繁殖灵兽[1])
	_提示 = str(结果.get("原因", "繁殖开始！预计%d日产崽，品质%s" % [int(结果.get("繁殖日", 30)), str(结果.get("预计品质", "普通"))]))
	_选中繁殖灵兽.clear()
	_反馈(_提示)


# ==================== 工具函数 ====================
# ★ 2026-09-17 G4（06 灵兽）：删除页内自造空态 `_添加空状态`，统一走 UITheme.建空态
#   （同页禁两套空态）。原 4 处调用点（灵兽库 / 出战绑定 / 引育计划 / 繁殖）均已改为
#   _content.add_child(UITheme.建空态(...))；总览原有 1 处本就走建空态 ⇒ 全页空态单源。
#   注：规格 §1.6 V5 只列了 3 处（漏「引育计划」）—— 本批按「同页禁两套空态」硬规则补齐为 4 处。


func _添加面板标题(标题: String) -> void:
	var 间距: Control = Control.new()
	间距.custom_minimum_size = Vector2(0, 8)
	_content.add_child(间距)

	var 标题标签: Label = Label.new()
	标题标签.text = "▎ %s" % 标题
	# ★ 2026-09-17 G4（06 灵兽）：分节标题接统一分节组件 UITheme.apply_section_title
	#   （FONT_H2=33 ＋ COLOR_TEXT_TITLE2 token 文字色，替代原硬编码标题金）。
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
	# ★ 2026-09-17 G3（06 灵兽）：子标题原 FONT_H2(33) 与面板标题同号 ⇒ 降为 FONT_BODY(27)，
	#   建立 页标题(45) ＞ 面板标题(33) ＞ 子标题/正文(27) ＞ 辅助(21)。
	#   承 G4「分节组件族」：走 apply_body_text（token 字号＋token 文字色，替代原硬编码子标题金）。
	UITheme.apply_body_text(标题标签)
	_content.add_child(标题标签)


func _添加信息项(网格: GridContainer, 标签: String, 值: String) -> void:
	var 标签控件: Label = Label.new()
	标签控件.text = 标签 + "："
	标签控件.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	标签控件.custom_minimum_size = Vector2(120, 24)
	# ★ 2026-09-17 G3（06 灵兽）：信息项原未接字号 token（走 Godot 默认字号）⇒ 补 apply_project_font(FONT_BODY)。
	UITheme.apply_project_font(标签控件, UITheme.FONT_BODY)
	网格.add_child(标签控件)

	var 值控件: Label = Label.new()
	值控件.text = 值
	值控件.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	UITheme.apply_project_font(值控件, UITheme.FONT_BODY)
	网格.add_child(值控件)


# ==================== 反馈与动效辅助 ====================
## 操作反馈一致化（B1）：页面内文字提示 + 浮层 toast 双轨，与炼丹/炼器页一致。
func _反馈(文本: String) -> void:
	_提示 = 文本
	if 文本 != "":
		Game.添加提示(文本)
	_刷新内容()

## 列表/tab 切换入场淡入（B4）：每次重建内容时逐卡片淡入。
func _卡片淡入(节点: Control) -> void:
	节点.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(节点, "modulate:a", 1.0, 0.25)

# ★ D1（#009 逐页精修 · 灵兽苑）：底部上浮灵气微粒，暖金柔点，零美术依赖。
func _build_灵气() -> void:
	var 粒子: GPUParticles2D = GPUParticles2D.new()
	粒子.name = "灵气粒子"
	粒子.amount = 24
	粒子.lifetime = 4.0
	粒子.emitting = true
	粒子.z_index = -1
	粒子.position = Vector2(240, 854)
	var 材: ParticleProcessMaterial = ParticleProcessMaterial.new()
	材.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	材.emission_box_extents = Vector3(240, 30, 0)
	材.direction = Vector3(0, -1, 0)
	材.gravity = Vector3(0, -6, 0)
	材.initial_velocity_min = 5.0
	材.initial_velocity_max = 14.0
	材.scale_min = 0.25
	材.scale_max = 0.65
	材.color = Color(0.85, 0.75, 0.45, 0.45)
	var 图: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	图.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(16):
		for x in range(16):
			var d: float = Vector2(float(x) - 7.5, float(y) - 7.5).length()
			图.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(1.0 - d / 7.5, 0.0, 1.0)))
	var 纹理: ImageTexture = ImageTexture.create_from_image(图)
	粒子.texture = 纹理   # ★ ParticleProcessMaterial 无 particle_texture；纹理属 GPUParticles2D
	粒子.process_material = 材
	add_child(粒子)


func _on返回() -> void:
	返回主页.emit()
