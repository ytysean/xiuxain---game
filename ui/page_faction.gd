extends Control

# 阵营声望页（GameUI 二级页）：展示五大阵营声望等级、进度、权益
# 全部字体走 UITheme 角色 helper，讯息从 Game.阵营声望 读取
signal 返回主页

# P2接入：战斗场景需要BattleManager
const BattleManager = preload("res://BattleManager.gd")

var _built: bool = false
var _scroll_vbox: VBoxContainer
var _faction_cards: Dictionary = {}
var _campaign_vbox: VBoxContainer = null  # P2接入：阵营战役列表容器
# 延迟构建：整页单 ScrollContainer，5 个二级面板一次建完 1372 节点（打开 545ms）→ 滚动近底再建
var _滚动: ScrollContainer
var _延迟面板: Array = []

const FACTION_LIST: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
const FACTION_SHORT: Dictionary = {
	"正道宗门": "正道", "魔道邪宗": "魔道", "中立散修": "散修",
	"上古妖兽": "妖兽", "远古遗泽": "遗泽"
}
const FACTION_COLOR: Dictionary = {
	"正道宗门": Color(0.29, 0.62, 1.0),
	"魔道邪宗": Color(1.0, 0.29, 0.29),
	"中立散修": Color(0.6, 0.6, 0.6),
	"上古妖兽": Color(0.29, 1.0, 0.48),
	"远古遗泽": Color(1.0, 0.84, 0.0),
}
const REPUTATION_LEVELS: Array = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
const REPUTATION_THRESHOLDS: Array = [0, 100, 500, 2000, 5000]

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var content: Control = UITheme.make_scene_background(self)

	var margin := MarginContainer.new()
	margin.name = "MarginRoot"
	margin.add_theme_constant_override("margin_left", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_right", UITheme.MARGIN)
	margin.add_theme_constant_override("margin_top", UITheme.GRID)
	margin.add_theme_constant_override("margin_bottom", UITheme.GRID)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "RootVBox"
	root.add_theme_constant_override("separation", UITheme.GRID)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_build_header(root)
	_build_scroll(root)
	# 修复（实机验收抓出 · 2026-09-12）：这 5 个面板原以 root(VBox) 为父平铺，其最小高度
	# 之和（≈10403）已超过整页；VBox 无剩余空间可分，带 EXPAND 的 FactionScroll 只能拿 0 高
	# （实测 size=(1032.0, 0.0)），MarginContainer 亦被自身 min 撑到 10565 溢出父容器。
	# 改挂进 FactionScroll 内的 _scroll_vbox：整页收成一个滚动容器，内容顺序不变。
	# 整页是单个 ScrollContainer，5 个二级面板一次建完达 1372 节点（实测打开 545ms）；
	# 改为滚动近底时逐个构建，首屏只建前两个（综合权益为常看信息）。
	_登记延迟面板("ComprehensivePanel", func(): _build_comprehensive(_scroll_vbox), _update_comprehensive)
	_登记延迟面板("CampaignPanel", func(): _build_campaign(_scroll_vbox), _update_campaign)
	_登记延迟面板("HostileNPCPanel", func(): _build_hostile_npc(_scroll_vbox), _update_hostile_npc)
	_登记延迟面板("NPCPanel", func(): _build_npc_list(_scroll_vbox), _update_npc_list)
	_登记延迟面板("InteractiveNPCPanel", func(): _build_interactive_npc(_scroll_vbox), _update_interactive_npc)
	_建下一批面板(true)

## 登记一个延迟构建的面板（构建与刷新成对，建完立即刷新一次拿当前数据）
func _登记延迟面板(名: String, 构建: Callable, 更新: Callable) -> void:
	_延迟面板.append({"名": 名, "构建": 构建, "更新": 更新, "已建": false})

## 构建一个未建面板；返回是否真的建了
func _建下一面板() -> bool:
	for 项 in _延迟面板:
		if bool(项.get("已建", false)):
			continue
		var 构建: Callable = 项.get("构建", Callable())
		if 构建.is_valid():
			构建.call()
		项["已建"] = true
		var 更新: Callable = 项.get("更新", Callable())
		if 更新.is_valid():
			更新.call()
		return true
	return false

## 首屏固定建前 N 个；之后滚动触发时建到够一屏为止，避免「还有面板却滚不动」的假底
const 首屏面板数: int = 2

func _建下一批面板(首屏: bool = false) -> void:
	if _滚动 == null:
		return
	var 建了: int = 0
	while _建下一面板():
		建了 += 1
		if 首屏:
			if 建了 >= 首屏面板数:
				break
		elif _scroll_vbox.size.y >= _滚动.size.y:
			break

func _on_scroll_changed(_v: float) -> void:
	if _滚动 == null:
		return
	var bar: ScrollBar = _滚动.get_v_scroll_bar()
	if bar == null or bar.max_value <= 0.0:
		return
	if bar.value >= bar.max_value - bar.page * 0.8:
		_建下一批面板()

func _连接滚动信号() -> void:
	if _滚动 == null or not is_instance_valid(_滚动):
		return
	var bar: ScrollBar = _滚动.get_v_scroll_bar()
	if bar == null:
		return
	if not bar.value_changed.is_connected(_on_scroll_changed):
		bar.value_changed.connect(_on_scroll_changed)

func _build_header(parent: Control) -> void:
	# P0-3.5 统一顶栏：建顶栏（暗金描边底 + 金环返回键 + 亮金标题 + 可选信息提示 + 右侧操作簇）
	parent.add_child(UITheme.建顶栏("阵营声望", _on_back_pressed, []))
func _build_scroll(parent: Control) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "FactionScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "FactionVBox"
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID)
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_vbox)
	_滚动 = scroll
	_连接滚动信号()

	for faction in FACTION_LIST:
		var card = _build_faction_card(faction)
		_scroll_vbox.add_child(card)
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.25)
		_faction_cards[faction] = card

	# 弟子阵营管理
	var 弟子阵营面板 := PanelContainer.new()
	弟子阵营面板.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	_scroll_vbox.add_child(弟子阵营面板)

	var 弟子阵营vbox := VBoxContainer.new()
	弟子阵营vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	弟子阵营vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	弟子阵营vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	弟子阵营vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	弟子阵营vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	弟子阵营面板.add_child(弟子阵营vbox)

	var 弟子阵营标题 := Label.new()
	弟子阵营标题.text = "弟子阵营管理"
	弟子阵营标题.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	UITheme.apply_project_font(弟子阵营标题, UITheme.FONT_TITLE, true)
	弟子阵营vbox.add_child(弟子阵营标题)

	# 统计弟子阵营分布
	var 正道数: int = 0
	var 魔道数: int = 0
	var 无阵营数: int = 0
	for d in Game.弟子列表:
		if d == null:
			continue
		match str(d.正魔阵营):
			"正道": 正道数 += 1
			"魔道": 魔道数 += 1
			_: 无阵营数 += 1

	var 分布文本 := Label.new()
	分布文本.text = "正道弟子：%d  |  魔道弟子：%d  |  无阵营弟子：%d" % [正道数, 魔道数, 无阵营数]
	分布文本.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	弟子阵营vbox.add_child(分布文本)

	# 批量加入按钮
	var 按钮栏 := HBoxContainer.new()
	按钮栏.add_theme_constant_override("separation", UITheme.GRID)
	弟子阵营vbox.add_child(按钮栏)

	var 加入正道按钮 := Button.new()
	加入正道按钮.text = "无阵营弟子加入正道"
	加入正道按钮.custom_minimum_size = Vector2(0, 32)
	加入正道按钮.pressed.connect(_on批量加入阵营.bind("正道"))
	按钮栏.add_child(加入正道按钮)

	var 加入魔道按钮 := Button.new()
	加入魔道按钮.text = "无阵营弟子加入魔道"
	加入魔道按钮.custom_minimum_size = Vector2(0, 32)
	加入魔道按钮.pressed.connect(_on批量加入阵营.bind("魔道"))
	按钮栏.add_child(加入魔道按钮)

	var 退出阵营按钮 := Button.new()
	退出阵营按钮.text = "全部退出阵营"
	退出阵营按钮.custom_minimum_size = Vector2(0, 32)
	退出阵营按钮.pressed.connect(_on批量退出阵营)
	按钮栏.add_child(退出阵营按钮)

func _build_faction_card(faction: String) -> Control:
	var card := PanelContainer.new()
	card.name = "Card_" + faction
	card.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	card.add_child(vbox)

	# 阵营名称 + 等级
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", UITheme.GRID)
	vbox.add_child(header)

	var name_label := Label.new()
	name_label.name = "FactionName"
	name_label.text = faction
	name_label.add_theme_color_override("font_color", FACTION_COLOR[faction])
	UITheme.apply_body_text(name_label)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)

	var level_label := Label.new()
	level_label.name = "LevelLabel"
	level_label.text = "冷淡"
	UITheme.apply_aux_text(level_label)
	header.add_child(level_label)

	# 声望进度条
	var progress_panel := PanelContainer.new()
	progress_panel.custom_minimum_size = Vector2(0, 16)
	progress_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
	vbox.add_child(progress_panel)

	var progress_bar := ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0
	progress_bar.show_percentage = false
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_panel.add_child(progress_bar)

	# 声望数值
	var value_label := Label.new()
	value_label.name = "ValueLabel"
	value_label.text = "0 / 100"
	UITheme.apply_aux_text(value_label)
	vbox.add_child(value_label)

	# 权益标签
	var benefits_label := Label.new()
	benefits_label.name = "BenefitsLabel"
	benefits_label.text = "权益：基础商品"
	UITheme.apply_aux_text(benefits_label)
	benefits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(benefits_label)

	return card

func _build_comprehensive(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "ComprehensivePanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "综合阵营权益"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITheme.GRID)
	grid.add_theme_constant_override("v_separation", UITheme.GRID / 2)
	vbox.add_child(grid)

	var items: Array = [
		{"label": "最高让利", "key": "discount"},
		{"label": "最高任务加成", "key": "bonus"},
		{"label": "解锁特殊商品", "key": "special"},
		{"label": "解锁专属任务", "key": "exclusive"},
	]
	for item in items:
		var item_panel := PanelContainer.new()
		item_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
		grid.add_child(item_panel)
		item_panel.modulate.a = 0.0
		item_panel.create_tween().tween_property(item_panel, "modulate:a", 1.0, 0.25)

		var item_vbox := VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 4)
		item_vbox.add_theme_constant_override("margin_left", 12)
		item_vbox.add_theme_constant_override("margin_right", 12)
		item_vbox.add_theme_constant_override("margin_top", 8)
		item_vbox.add_theme_constant_override("margin_bottom", 8)
		item_panel.add_child(item_vbox)

		var label := Label.new()
		label.text = item["label"]
		UITheme.apply_aux_text(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(label)

		var value := Label.new()
		value.name = "Value_" + item["key"]
		value.text = "-"
		UITheme.apply_body_text(value)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_vbox.add_child(value)

# ============ P2接入：阵营战役入口 ============
func _build_campaign(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "CampaignPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "CampaignList"
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "◆ 阵营战役"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "代表阵营出征，获取战功与声望奖励"
	UITheme.apply_aux_text(desc)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	_campaign_vbox = VBoxContainer.new()
	_campaign_vbox.name = "CampaignItems"
	_campaign_vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(_campaign_vbox)

func _update_campaign() -> void:
	if _campaign_vbox == null:
		return
	# 清空旧内容
	for child in _campaign_vbox.get_children():
		child.queue_free()

	if not Game.has_method("获取阵营战役列表"):
		return

	var 战役列表: Array = Game.获取阵营战役列表()
	var 余量: int = 0
	if Game.has_method("获取阵营战役余量"):
		余量 = int(Game.获取阵营战役余量())

	# 显示配额
	var quota_label := Label.new()
	quota_label.text = "本周出征次数：%d" % 余量
	UITheme.apply_aux_text(quota_label)
	quota_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campaign_vbox.add_child(quota_label)

	for 战役 in 战役列表:
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID)
		_campaign_vbox.add_child(行)

		var 信息 := VBoxContainer.new()
		信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_child(信息)

		var 名称 := Label.new()
		名称.text = str(战役.get("名称", "未知战役"))
		UITheme.apply_body_text(名称)
		信息.add_child(名称)

		var 详情 := Label.new()
		var 阵营: String = str(战役.get("阵营", ""))
		var 需声望: int = int(战役.get("需声望", 0))
		var 当前声望: int = int(战役.get("当前声望", 0))
		var 已解锁: bool = bool(战役.get("已解锁", false))
		var 告捷次数: int = int(战役.get("告捷次数", 0))
		var 状态文本: String = "◇ 未解锁" if not 已解锁 else "✓ 已解锁"
		详情.text = "%s | 声望：%d/%d | 告捷：%d次 | %s" % [阵营, 当前声望, 需声望, 告捷次数, 状态文本]
		UITheme.apply_aux_text(详情)
		信息.add_child(详情)

		var 出征按钮 := Button.new()
		出征按钮.text = "出征"
		出征按钮.custom_minimum_size = Vector2(100, 50)
		出征按钮.disabled = not 已解锁 or 余量 <= 0
		if 已解锁 and 余量 > 0:
			出征按钮.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		var 战役id: String = str(战役.get("id", ""))
		出征按钮.pressed.connect(func(): _on_campaign_start(战役id))
		行.add_child(出征按钮)

func _on_campaign_start(战役id: String) -> void:
	if not Game.has_method("发起阵营战役"):
		Game.添加提示("阵营战役系统未就绪")
		return

	# 选择出战队伍（简化版：取战力最高的3名弟子）
	var 出战队伍: Array = []
	var 弟子列表: Array = []
	if Game.has_method("获取所有弟子"):
		弟子列表 = Game.获取所有弟子()
	elif Game.has_method("弟子列表"):
		弟子列表 = Game.弟子列表
	# 按战力排序，取前3名
	弟子列表.sort_custom(func(a, b): return int(a.get("战力", 0)) > int(b.get("战力", 0)))
	var 一队: Array = []
	for i in range(min(3, 弟子列表.size())):
		一队.append(弟子列表[i])
	if not 一队.is_empty():
		出战队伍.append(一队)

	if 出战队伍.is_empty():
		Game.添加提示("没有可出战的弟子")
		return

	# 发起阵营战役
	var 结果: Dictionary = Game.发起阵营战役(战役id, 出战队伍, {})
	if not bool(结果.get("ok", false)):
		Game.添加提示(str(结果.get("error", "出征失败")))
		return

	# P2接入：播放战斗场景动画
	if Game.主UI != null and Game.主UI.has_method("播放战报"):
		# 从出战队伍提取攻方快照
		var 攻方快照: Array = []
		for d in 一队:
			if d != null and d.has_method("get_final_combat_attr"):
				攻方快照.append(d.get_final_combat_attr())
		# 守方快照：用攻方快照的副本模拟（后续优化从敌方队伍提取）
		var 守方快照: Array = []
		for s in 攻方快照:
			var 副本: Dictionary = s.duplicate(true)
			if 副本.has("名称"):
				副本["名称"] = "阵营敌军" + str(副本["名称"])
			守方快照.append(副本)
		# 计算表演性战斗并播放
		if 攻方快照.size() > 0 and 守方快照.size() > 0:
			var 表演战报: Dictionary
			if 攻方快照.size() == 1 and 守方快照.size() == 1:
				表演战报 = BattleManager.发起1v1(攻方快照[0], 守方快照[0], "full", false)
			else:
				表演战报 = BattleManager.发起3v3(攻方快照, 守方快照, "full", false)
			Game.主UI.播放战报(表演战报, 攻方快照, 守方快照, str(结果.get("战役名", "阵营战役")))
			# 等待战斗结束（通过信号或定时）
			await get_tree().create_timer(3.0).timeout

	# 刷新页面
	refresh()
	# 显示奖励提示
	var 战功: int = int(结果.get("战功", 0))
	var 声望: int = int(结果.get("声望奖励", 0))
	var 首胜: bool = bool(结果.get("首胜", false))
	var 提示: String = "%s告捷！战功+%d，声望+%d" % [str(结果.get("战役名", "战役")), 战功, 声望]
	if 首胜:
		提示 += "（首捷双赏）"
	Game.添加提示(提示)


# ============ P2接入：敌对NPC列表 ============
var _hostile_npc_vbox: VBoxContainer = null

func _build_hostile_npc(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "HostileNPCPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "HostileNPCList"
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "◆ 敌对势力"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "挑战敌对NPC，获取灵石与声望奖励"
	UITheme.apply_aux_text(desc)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	_hostile_npc_vbox = VBoxContainer.new()
	_hostile_npc_vbox.name = "HostileNPCItems"
	_hostile_npc_vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(_hostile_npc_vbox)

func _update_hostile_npc() -> void:
	if _hostile_npc_vbox == null:
		return
	for child in _hostile_npc_vbox.get_children():
		child.queue_free()
	if not Game.has_method("获取所有敌对NPC"):
		return
	var NPC列表: Array = Game.获取所有敌对NPC()
	for NPC in NPC列表:
		var npc_id: String = str(NPC.get("id", ""))
		var 状态: String = str(NPC.get("当前状态", "游荡"))
		var 行 := HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID)
		_hostile_npc_vbox.add_child(行)
		var 信息 := VBoxContainer.new()
		信息.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		行.add_child(信息)
		var 名称 := Label.new()
		var 状态标记: String = ""
		if 状态 == "已击杀":
			状态标记 = " [已击杀]"
		elif 状态 == "已和解":
			状态标记 = " [已和解]"
		名称.text = "%s%s" % [str(NPC.get("名称", "未知")), 状态标记]
		UITheme.apply_body_text(名称)
		信息.add_child(名称)
		var 详情 := Label.new()
		var 境界: String = str(NPC.get("境界", ""))
		var 战力: int = int(NPC.get("战力", 0))
		var 势力: String = str(NPC.get("势力", ""))
		var 仇恨: int = int(NPC.get("当前仇恨", 0))
		详情.text = "%s | 道行：%d | %s | 仇恨：%d" % [境界, 战力, 势力, 仇恨]
		UITheme.apply_aux_text(详情)
		信息.add_child(详情)
		var 挑战按钮 := Button.new()
		挑战按钮.text = "挑战"
		挑战按钮.custom_minimum_size = Vector2(100, 50)
		挑战按钮.disabled = 状态 == "已击杀" or 状态 == "已和解"
		if 状态 == "游荡":
			挑战按钮.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		挑战按钮.pressed.connect(func(): _on_hostile_npc_challenge(npc_id))
		行.add_child(挑战按钮)

func _on_hostile_npc_challenge(npc_id: String) -> void:
	if not Game.has_method("挑战敌对NPC"):
		Game.添加提示("敌对NPC挑战系统未就绪")
		return
	var 出战弟子: Array = []
	var 弟子列表: Array = []
	if Game.has_method("获取所有弟子"):
		弟子列表 = Game.获取所有弟子()
	elif Game.has_method("弟子列表"):
		弟子列表 = Game.弟子列表
	弟子列表.sort_custom(func(a, b): return int(a.get("战力", 0)) > int(b.get("战力", 0)))
	if 弟子列表.size() > 0:
		出战弟子.append(弟子列表[0])
	if 出战弟子.is_empty():
		Game.添加提示("没有可出战的弟子")
		return
	var 结果: Dictionary = Game.挑战敌对NPC(npc_id, 出战弟子)
	if not bool(结果.get("成功", false)):
		Game.添加提示(str(结果.get("原因", "挑战失败")))
		return
	if Game.主UI != null and Game.主UI.has_method("播放战报"):
		var 战报: Dictionary = 结果.get("战报", {})
		var 攻方快照: Array = 结果.get("攻方快照", [])
		var 守方快照: Array = 结果.get("守方快照", [])
		var NPC名称: String = str(结果.get("NPC详情", {}).get("名称", "敌对NPC"))
		if 攻方快照.size() > 0 and 守方快照.size() > 0:
			Game.主UI.播放战报(战报, 攻方快照, 守方快照, "挑战%s" % NPC名称)
			await get_tree().create_timer(3.0).timeout
	refresh()
	var 胜利: bool = bool(结果.get("胜利", false))
	var 奖励: Dictionary = 结果.get("奖励", {})
	if 胜利:
		Game.添加提示("击杀成功！灵石+%d，声望+%d" % [int(奖励.get("灵石", 0)), int(奖励.get("声望", 0))])
	else:
		Game.添加提示("挑战失败，弟子受伤休养")
## P2 阵营NPC列表展示
func _build_npc_list(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "NPCPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "NPCList"
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "◆ 阵营人物志"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "各阵营核心人物，提升声望可解锁对应功能"
	UITheme.apply_aux_text(desc)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# NPC内容容器（refresh时填充）
	var npc_content := VBoxContainer.new()
	npc_content.name = "NPCContent"
	npc_content.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(npc_content)

func refresh() -> void:
	if not _built:
		return
	# 更新每个阵营卡片
	for faction in FACTION_LIST:
		var card = _faction_cards.get(faction, null)
		if card == null:
			continue
		var rep_value: int = int(Game.阵营声望系统.阵营声望.get(faction, 0))
		var level_idx: int = _get_level_index(rep_value)
		var level_name: String = REPUTATION_LEVELS[level_idx]
		var next_threshold: int = REPUTATION_THRESHOLDS[min(level_idx + 1, REPUTATION_THRESHOLDS.size() - 1)]
		var current_threshold: int = REPUTATION_THRESHOLDS[level_idx]
		var progress: float = 0.0
		if next_threshold > current_threshold:
			progress = float(rep_value - current_threshold) / float(next_threshold - current_threshold) * 100.0
		# 更新UI
		var level_label = card.find_child("LevelLabel", true, false)
		if level_label != null:
			level_label.text = level_name
		var progress_bar = card.find_child("ProgressBar", true, false)
		if progress_bar != null:
			progress_bar.value = progress
		var value_label = card.find_child("ValueLabel", true, false)
		if value_label != null:
			if level_idx >= REPUTATION_LEVELS.size() - 1:
				value_label.text = "%d (已满级)" % rep_value
			else:
				value_label.text = "%d / %d（距%s：%d）" % [rep_value, next_threshold, REPUTATION_LEVELS[level_idx + 1], next_threshold - rep_value]
		var benefits_label = card.find_child("BenefitsLabel", true, false)
		if benefits_label != null:
			benefits_label.text = _get_benefits_text(faction, level_idx)
	# 延迟面板：未建的不刷新（构建时会自带一次刷新），已建的才更新
	for 项 in _延迟面板:
		if bool(项.get("已建", false)):
			var 更新: Callable = 项.get("更新", Callable())
			if 更新.is_valid():
				更新.call()

func _get_level_index(rep_value: int) -> int:
	for i in range(REPUTATION_THRESHOLDS.size()):
		if rep_value < REPUTATION_THRESHOLDS[i]:
			return max(0, i - 1)
	return REPUTATION_LEVELS.size() - 1

func _get_benefits_text(faction: String, level_idx: int) -> String:
	var benefits: Array = []
	match faction:
		"正道宗门":
			if level_idx >= 2: benefits.append("商店让利5%")
			if level_idx >= 3: benefits.append("正道高阶功法")
			if level_idx >= 4: benefits.append("正道专属皮肤")
		"魔道邪宗":
			if level_idx >= 2: benefits.append("魔道任务")
			if level_idx >= 3: benefits.append("黑市交易")
			if level_idx >= 4: benefits.append("魔道专属皮肤")
		"中立散修":
			if level_idx >= 2: benefits.append("散修任务")
			if level_idx >= 3: benefits.append("竞猜玩法")
			if level_idx >= 4: benefits.append("散修专属皮肤")
		"上古妖兽":
			if level_idx >= 2: benefits.append("高阶灵兽契约")
			if level_idx >= 3: benefits.append("灵兽繁育")
			if level_idx >= 4: benefits.append("上古灵兽契约")
		"远古遗泽":
			if level_idx >= 2: benefits.append("圣品突破素材")
			if level_idx >= 3: benefits.append("道品锻造素材")
			if level_idx >= 4: benefits.append("远古传承")
	if benefits.is_empty():
		return "权益：基础商品"
	return "权益：" + "、".join(benefits)

func _update_comprehensive() -> void:
	var best_discount: float = 1.0
	var best_bonus: float = 1.0
	var has_special: bool = false
	var has_exclusive: bool = false
	for faction in FACTION_LIST:
		var rep_value: int = int(Game.阵营声望系统.阵营声望.get(faction, 0))
		var level_idx: int = _get_level_index(rep_value)
		if level_idx >= 2: best_discount = min(best_discount, 0.95)
		if level_idx >= 3: best_discount = min(best_discount, 0.90)
		if level_idx >= 4: best_discount = min(best_discount, 0.85)
		if level_idx >= 2: best_bonus = max(best_bonus, 1.05)
		if level_idx >= 3: best_bonus = max(best_bonus, 1.10)
		if level_idx >= 4: best_bonus = max(best_bonus, 1.15)
		if level_idx >= 3: has_special = true
		if level_idx >= 4: has_exclusive = true
	# 更新UI
	var root = find_child("ComprehensivePanel", true, false)
	if root != null:
		var discount_val = root.find_child("Value_discount", true, false)
		if discount_val != null: discount_val.text = "让利%d%%" % int(round((1.0 - best_discount) * 100))
		var bonus_val = root.find_child("Value_bonus", true, false)
		if bonus_val != null: bonus_val.text = "+%d%%" % int((best_bonus - 1.0) * 100)
		var special_val = root.find_child("Value_special", true, false)
		if special_val != null: special_val.text = "✓" if has_special else "×"
		var exclusive_val = root.find_child("Value_exclusive", true, false)
		if exclusive_val != null: exclusive_val.text = "✓" if has_exclusive else "×"

## P2 更新阵营NPC列表
func _update_npc_list() -> void:
	var root = find_child("NPCPanel", true, false)
	if root == null:
		return
	var content = root.find_child("NPCContent", true, false)
	if content == null:
		return
	# 清空旧内容
	for child in content.get_children():
		child.queue_free()
	# 获取所有阵营NPC
	var 全部NPC: Dictionary = Game.获取所有阵营NPC列表()
	for 阵营名 in 全部NPC.keys():
		var NPC列表: Array = 全部NPC[阵营名]
		if NPC列表.is_empty():
			continue
		# 阵营标题
		var 阵营标题: Label = Label.new()
		阵营标题.text = "【%s】" % 阵营名
		阵营标题.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
		UITheme.apply_body_text(阵营标题)
		content.add_child(阵营标题)
		# NPC列表
		for NPC in NPC列表:
			var NPC卡: PanelContainer = PanelContainer.new()
			NPC卡.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
			content.add_child(NPC卡)
			NPC卡.modulate.a = 0.0
			NPC卡.create_tween().tween_property(NPC卡, "modulate:a", 1.0, 0.25)
			var NPCvbox: VBoxContainer = VBoxContainer.new()
			NPCvbox.add_theme_constant_override("separation", 4)
			NPCvbox.add_theme_constant_override("margin_left", 12)
			NPCvbox.add_theme_constant_override("margin_right", 12)
			NPCvbox.add_theme_constant_override("margin_top", 8)
			NPCvbox.add_theme_constant_override("margin_bottom", 8)
			NPC卡.add_child(NPCvbox)
			# NPC名称和身份
			var 名称行: HBoxContainer = HBoxContainer.new()
			名称行.add_theme_constant_override("separation", UITheme.GRID / 2)
			NPCvbox.add_child(名称行)
			var 名称: Label = Label.new()
			名称.text = str(NPC.get("名称", ""))
			名称.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
			UITheme.apply_body_text(名称)
			名称行.add_child(名称)
			var 身份: Label = Label.new()
			身份.text = "· %s" % str(NPC.get("身份", ""))
			身份.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
			UITheme.apply_aux_text(身份)
			名称行.add_child(身份)
			# 核心功能
			var 功能: Label = Label.new()
			功能.text = "功能：%s" % str(NPC.get("核心功能", ""))
			功能.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
			UITheme.apply_aux_text(功能)
			功能.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			NPCvbox.add_child(功能)
			# 解锁状态
			var 已解锁: bool = bool(NPC.get("已解锁", false))
			var 解锁提示: String = str(NPC.get("解锁提示", ""))
			var 状态: Label = Label.new()
			if 已解锁:
				状态.text = "✓ 已解锁"
				状态.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			else:
				状态.text = "◇ %s" % 解锁提示
				状态.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			UITheme.apply_aux_text(状态)
			NPCvbox.add_child(状态)
		content.add_child(HSeparator.new())

## P2 可交互NPC列表（当前在宗门内的NPC）
func _build_interactive_npc(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "InteractiveNPCPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(false))
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "InteractiveNPCList"
	vbox.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vbox.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "◆ 宗门人物（当前可交互）"
	title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "轻触人物可对话，了解宗门动态"
	UITheme.apply_aux_text(desc)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	vbox.add_child(HSeparator.new())

	# NPC内容容器（refresh时填充）
	var npc_content := VBoxContainer.new()
	npc_content.name = "InteractiveNPCContent"
	npc_content.add_theme_constant_override("separation", UITheme.GRID / 2)
	vbox.add_child(npc_content)

	# 对话显示区域
	var dialog_panel := PanelContainer.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
	dialog_panel.visible = false
	vbox.add_child(dialog_panel)

	var dialog_vbox := VBoxContainer.new()
	dialog_vbox.add_theme_constant_override("separation", 4)
	dialog_vbox.add_theme_constant_override("margin_left", 12)
	dialog_vbox.add_theme_constant_override("margin_right", 12)
	dialog_vbox.add_theme_constant_override("margin_top", 8)
	dialog_vbox.add_theme_constant_override("margin_bottom", 8)
	dialog_panel.add_child(dialog_vbox)

	var dialog_title := Label.new()
	dialog_title.name = "DialogTitle"
	dialog_title.text = ""
	dialog_title.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	UITheme.apply_body_text(dialog_title)
	dialog_vbox.add_child(dialog_title)

	var dialog_content := Label.new()
	dialog_content.name = "DialogContent"
	dialog_content.text = ""
	UITheme.apply_body_text(dialog_content)
	dialog_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_vbox.add_child(dialog_content)

	var close_btn := Button.new()
	close_btn.text = "关闭对话"
	close_btn.connect("pressed", func(): dialog_panel.visible = false)
	dialog_vbox.add_child(close_btn)

## P2 更新可交互NPC列表
func _update_interactive_npc() -> void:
	var root = find_child("InteractiveNPCPanel", true, false)
	if root == null:
		return
	var content = root.find_child("InteractiveNPCContent", true, false)
	if content == null:
		return
	# 清空旧内容
	for child in content.get_children():
		child.queue_free()
	# 获取可交互NPC列表
	var NPC列表: Array = Game.获取可交互NPC列表()
	if NPC列表.is_empty():
		var 空提示: Label = Label.new()
		空提示.text = "当前宗门内无可交互人物"
		UITheme.apply_aux_text(空提示)
		空提示.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(空提示)
		return
	# 显示NPC列表
	for NPC in NPC列表:
		var NPCID: String = str(NPC.get("id", ""))
		var NPC卡: PanelContainer = PanelContainer.new()
		NPC卡.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox(true))
		content.add_child(NPC卡)
		NPC卡.modulate.a = 0.0
		NPC卡.create_tween().tween_property(NPC卡, "modulate:a", 1.0, 0.25)
		var NPCvbox: VBoxContainer = VBoxContainer.new()
		NPCvbox.add_theme_constant_override("separation", 4)
		NPCvbox.add_theme_constant_override("margin_left", 12)
		NPCvbox.add_theme_constant_override("margin_right", 12)
		NPCvbox.add_theme_constant_override("margin_top", 8)
		NPCvbox.add_theme_constant_override("margin_bottom", 8)
		NPC卡.add_child(NPCvbox)
		# NPC名称和身份
		var 名称行: HBoxContainer = HBoxContainer.new()
		名称行.add_theme_constant_override("separation", UITheme.GRID / 2)
		NPCvbox.add_child(名称行)
		var 名称: Label = Label.new()
		名称.text = str(NPC.get("名称", ""))
		名称.add_theme_color_override("font_color", UITheme.COLOR_TEXT_BODY)
		UITheme.apply_body_text(名称)
		名称行.add_child(名称)
		var 身份: Label = Label.new()
		身份.text = "· %s" % str(NPC.get("身份", ""))
		身份.add_theme_color_override("font_color", UITheme.COLOR_TEXT_AUX)
		UITheme.apply_aux_text(身份)
		名称行.add_child(身份)
		# 位置和状态
		var 状态行: HBoxContainer = HBoxContainer.new()
		状态行.add_theme_constant_override("separation", UITheme.GRID)
		NPCvbox.add_child(状态行)
		var 位置: Label = Label.new()
		位置.text = "◇ %s" % str(NPC.get("位置", ""))
		UITheme.apply_aux_text(位置)
		状态行.add_child(位置)
		var 状态: Label = Label.new()
		状态.text = "状态：%s" % str(NPC.get("状态", ""))
		UITheme.apply_aux_text(状态)
		状态行.add_child(状态)
		var 心情: Label = Label.new()
		var 心情值: int = int(NPC.get("心情", 50))
		if 心情值 > 80:
			心情.text = "◇ 心情愉悦"
		elif 心情值 < 40:
			心情.text = "◇ 心情不佳"
		else:
			心情.text = "◇ 心情一般"
		UITheme.apply_aux_text(心情)
		状态行.add_child(心情)
		# P2 第二阶段：好感度显示
		var 好感度: int = Game.获取NPC好感度(NPCID)
		var 好感行: HBoxContainer = HBoxContainer.new()
		好感行.add_theme_constant_override("separation", UITheme.GRID / 2)
		NPCvbox.add_child(好感行)
		var 好感标签: Label = Label.new()
		好感标签.text = "◇ 好感度"
		UITheme.apply_aux_text(好感标签)
		好感行.add_child(好感标签)
		var 好感进度: ProgressBar = ProgressBar.new()
		好感进度.min_value = 0
		好感进度.max_value = 100
		好感进度.value = 0
		好感进度.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		好感进度.custom_minimum_size = Vector2(0, 16)
		好感行.add_child(好感进度)
		# ★ 2026-09-16（#18）：好感度自 0 生长
		UITheme.进度缓动(好感进度, float(好感度))
		var 好感数值: Label = Label.new()
		好感数值.text = "%d/100" % 好感度
		UITheme.apply_aux_text(好感数值)
		好感行.add_child(好感数值)
		# P2 第二阶段：任务状态
		var 任务状态: Dictionary = Game.获取NPC任务状态(NPCID)
		if not 任务状态.is_empty():
			var 任务行: HBoxContainer = HBoxContainer.new()
			任务行.add_theme_constant_override("separation", UITheme.GRID / 2)
			NPCvbox.add_child(任务行)
			var 任务信息: Label = Label.new()
			var 任务: Dictionary = 任务状态.get("任务", {})
			if bool(任务状态.get("已接取", false)):
				if bool(任务状态.get("可完成", false)):
					任务信息.text = "◇ 差事：%s（可完成）" % str(任务.get("名称", ""))
					任务信息.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
				else:
					任务信息.text = "◇ 差事：%s（%d/%d）" % [str(任务.get("名称", "")), int(任务状态.get("进度", 0)), int(任务状态.get("目标", 1))]
			else:
				任务信息.text = "◇ 可接差事：%s" % str(任务.get("名称", ""))
			UITheme.apply_aux_text(任务信息)
			任务行.add_child(任务信息)
			# 任务按钮
			var 任务按钮: Button = Button.new()
			if bool(任务状态.get("已接取", false)):
				if bool(任务状态.get("可完成", false)):
					任务按钮.text = "✓ 了却差事"
					任务按钮.connect("pressed", func():
						var 结果: Dictionary = Game.完成NPC任务(NPCID)
						_show_simple_dialog(root, "差事结果", str(结果.get("msg", "")))
						_update_interactive_npc()
					)
				else:
					任务按钮.text = "进行中..."
					任务按钮.disabled = true
			else:
				任务按钮.text = "◇ 接取差事"
				任务按钮.connect("pressed", func():
					var 结果: Dictionary = Game.接取NPC任务(NPCID)
					_show_simple_dialog(root, "差事接取", str(结果.get("msg", "")))
					_update_interactive_npc()
				)
			任务行.add_child(任务按钮)
		# 按钮行：对话+送礼+记忆+关系
		var 按钮行: HBoxContainer = HBoxContainer.new()
		按钮行.add_theme_constant_override("separation", UITheme.GRID / 2)
		NPCvbox.add_child(按钮行)
		# 对话按钮（增强版：记忆+随机事件）
		var 对话按钮: Button = Button.new()
		对话按钮.text = "◇ 对话"
		对话按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var NPC名称: String = str(NPC.get("名称", ""))
		对话按钮.connect("pressed", func():
			var 结果: Dictionary = Game.与NPC对话增强(NPCID)
			var 对话内容: String = str(结果.get("对话", ""))
			var 事件: Dictionary = 结果.get("事件", {})
			var 显示内容: String = 对话内容
			if not 事件.is_empty():
				显示内容 += "\n\n【随机事件】\n" + str(事件.get("描述", ""))
				if 事件.has("好感变化"):
					var 好感变化: int = int(事件.get("好感变化", 0))
					if 好感变化 > 0:
						显示内容 += "\n好感度 +%d" % 好感变化
					elif 好感变化 < 0:
						显示内容 += "\n好感度 %d" % 好感变化
				if 事件.has("奖励灵石"):
					显示内容 += "\n获得灵石 %d" % int(事件.get("奖励灵石", 0))
				if 事件.has("奖励声望"):
					显示内容 += "\n获得声望 %d" % int(事件.get("奖励声望", 0))
			_show_simple_dialog(root, "【%s】" % NPC名称, 显示内容)
			_update_interactive_npc()
		)
		按钮行.add_child(对话按钮)
		# P2 第二阶段：送礼按钮
		var 送礼按钮: Button = Button.new()
		送礼按钮.text = "◇ 送礼"
		送礼按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var 喜欢礼物: String = Game.获取NPC喜欢礼物(NPCID)
		送礼按钮.connect("pressed", func():
			_show_gift_dialog(root, NPCID, NPC名称, 喜欢礼物)
		)
		按钮行.add_child(送礼按钮)
		# P2 第三阶段：记忆按钮
		var 记忆按钮: Button = Button.new()
		记忆按钮.text = "◇ 记忆"
		记忆按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		记忆按钮.connect("pressed", func():
			var 记忆列表: Array = Game.获取NPC记忆(NPCID)
			var 记忆内容: String = ""
			if 记忆列表.is_empty():
				记忆内容 = "暂无交互记录"
			else:
				for i in range(记忆列表.size() - 1, -1, -1):
					var 记忆: Dictionary = 记忆列表[i]
					记忆内容 += "[第%d日] %s：%s\n" % [int(记忆.get("日期", 0)), str(记忆.get("类型", "")), str(记忆.get("内容", ""))]
			_show_simple_dialog(root, "【%s】的记忆" % NPC名称, 记忆内容)
		)
		按钮行.add_child(记忆按钮)
		# P2 第三阶段：关系按钮
		var 关系按钮: Button = Button.new()
		关系按钮.text = "◇ 关系"
		关系按钮.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		关系按钮.connect("pressed", func():
			var 关系列表: Array = Game.获取NPC关系(NPCID)
			var 关系内容: String = ""
			if 关系列表.is_empty():
				关系内容 = "暂无已知关系"
			else:
				for 关系 in 关系列表:
					var 关系NPCID: String = str(关系.get("目标", ""))
					var 关系NPC名称: String = 关系NPCID  # 简化，不调用后端获取名称
					关系内容 += "【%s】%s：%s\n" % [str(关系.get("关系", "")), 关系NPC名称, str(关系.get("描述", ""))]
			_show_simple_dialog(root, "【%s】的关系" % NPC名称, 关系内容)
		)
		按钮行.add_child(关系按钮)

## P2 第二阶段：显示简单对话框
func _show_simple_dialog(root: Control, 标题: String, 内容: String) -> void:
	var dialog_panel = root.find_child("DialogPanel", true, false)
	if dialog_panel == null:
		return
	var dialog_title = dialog_panel.find_child("DialogTitle", true, false)
	if dialog_title != null:
		dialog_title.text = 标题
	var dialog_content = dialog_panel.find_child("DialogContent", true, false)
	if dialog_content != null:
		dialog_content.text = 内容
	dialog_panel.visible = true
	# ★ 2026-09-16 修（死键扫描实测：阵营 3 个批量按钮全判 DEAD）：
	#   本函数把结果写进「可交互NPC」区块内的 DialogPanel。若玩家当前不在该页签，
	#   panel 自身 visible=true 但**父链仍是隐藏的** ⇒ is_visible_in_tree() 依旧 false
	#   ⇒ 操作结果落在看不见的地方，观感等同按钮坏了（点了毫无反应）。
	#   故仅在 panel 实际不可见时补一次全局轻提示，保证任何页签下都有明确回应。
	if not dialog_panel.is_visible_in_tree() and is_instance_valid(ToastManager):
		ToastManager.show_tip("%s：%s" % [标题, 内容])

## P2 第二阶段：显示送礼对话框
func _show_gift_dialog(root: Control, NPCID: String, NPC名称: String, 喜欢礼物: String) -> void:
	var dialog_panel = root.find_child("DialogPanel", true, false)
	if dialog_panel == null:
		return
	var dialog_title = dialog_panel.find_child("DialogTitle", true, false)
	if dialog_title != null:
		dialog_title.text = "◇ 给【%s】送礼" % NPC名称
	var dialog_content = dialog_panel.find_child("DialogContent", true, false)
	if dialog_content != null:
		dialog_content.text = "喜欢的礼物：%s（送喜欢的礼物好感度翻倍）\n\n选择礼物价值：" % 喜欢礼物
	# 检查是否已有送礼按钮容器，有则先清除
	var old_gift_btns = dialog_panel.find_child("GiftButtons", true, false)
	if old_gift_btns != null:
		old_gift_btns.queue_free()
	# 添加送礼按钮
	var gift_btns: VBoxContainer = VBoxContainer.new()
	gift_btns.name = "GiftButtons"
	gift_btns.add_theme_constant_override("separation", 4)
	dialog_panel.add_child(gift_btns)
	var 礼物选项: Array = [
		{"价值": 50, "类型": "普通", "描述": "普通礼物（50灵石）"},
		{"价值": 200, "类型": "精品", "描述": "精品礼物（200灵石）"},
		{"价值": 500, "类型": "珍品", "描述": "珍品礼物（500灵石）"}
	]
	for 选项 in 礼物选项:
		var btn: Button = Button.new()
		btn.text = str(选项.get("描述", ""))
		var 礼物价值: int = int(选项.get("价值", 50))
		btn.connect("pressed", func():
			var 结果: Dictionary = Game.给NPC送礼(NPCID, 喜欢礼物, 礼物价值)
			_show_simple_dialog(root, "送礼结果", str(结果.get("msg", "")))
			_update_interactive_npc()
		)
		gift_btns.add_child(btn)
	dialog_panel.visible = true

func _on_back_pressed() -> void:
	返回主页.emit()


func _on批量加入阵营(阵营: String) -> void:
	var 计数: int = 0
	for d in Game.弟子列表:
		if d == null:
			continue
		if str(d.阵营) == "" or str(d.阵营) == "无":
			Game.加入正魔阵营(d, 阵营)
			计数 += 1
	_show_simple_dialog(self, "阵营加入", "%d名无阵营弟子加入%s！" % [计数, 阵营])
	refresh()


func _on批量退出阵营() -> void:
	var 计数: int = 0
	for d in Game.弟子列表:
		if d == null:
			continue
		if str(d.阵营) in ["正道", "魔道"]:
			d.阵营 = ""
			计数 += 1
	_show_simple_dialog(self, "阵营退出", "%d名弟子退出阵营！" % 计数)
	refresh()
