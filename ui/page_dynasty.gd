extends Control
# S34 凡人王朝：天下 / 差事 / 朝堂 / 册封 四合一面板
# 批次 2 一并补齐批次 1 欠账 —— 王朝在批次 1 落地时无任何 UI，玩家完全摸不到，
# 「要好玩」的前提是玩家能摸到，故差事榜（批次 1 内容）与朝堂/册封（批次 2）同批交付。
# 入口：main.gd 宗门页快捷网格「凡人王朝」→ 二级页。
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect。

signal 返回主页

const TABS: Array = ["总览", "郡县", "朝堂", "事件", "信仰", "奇观"]
# P0优化：10标签页合并为5个，渐进式解锁
# 总览：王朝状态+今日朝报+今日要事（默认解锁）
# 郡县：12郡列表+凡间差事（默认解锁）
# 朝堂：派系+爵位+荐举+皇储（护国宗爵位解锁）
# 事件：诏令+朝廷委托+反制应对（触发第一个反制事件解锁）
# 信仰：香火庙+愿力+功德/业力（建立第一座香火庙解锁）
# 旧标签页映射（保留内部函数引用）：
#   天下→总览(王朝状态)+郡县(郡县列表)
#   邸报→总览(今日朝报)
#   差事→郡县(差事榜)
#   朝堂→朝堂
#   册封→朝堂
#   皇嗣→朝堂
#   诏令→事件
#   委托→事件
#   国教→信仰
#   开国→特殊状态（王朝灭亡时弹窗）
# 反制 → 可选应对（与 game_state.gd 的 _执行反制后果_S34 分支一一对应）
const 反制选项表: Dictionary = {
	"dc_qiangzheng": [["pay", "缴纳供奉"], ["refuse", "抗命拒缴"]],
	"dc_kouya": [["ransom", "赎回弟子"], ["rescue", "遣人营救"], ["wait", "隐忍不发"]],
	"dc_duanguan": [["repair", "遣使安抚"]],
	"dc_jinchuan": [["mediate", "疏通关节"]],
	"dc_minbian": [["mediate", "调停民变"]],
	"dc_miefazhao": [["mediate", "上书自辩"]],
	"dc_miefaling": [["defend", "迎战禁军"], ["migrate", "迁宗避祸"], ["rebel", "扶持叛军"]],
}

var _built: bool = false
var _cur: String = "总览"
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _tab_btns: Dictionary = {}
var _提示: String = ""
var _展开差事: String = ""
var _展开委托: String = ""          # 当前展开「选弟子」面板的委托实例ID（""=未展开）          # 当前展开「选弟子」面板的差事ID（""=未展开）
var _开国选: Dictionary = {}        # S35-1 开国六问表单状态（路线/国号/主国策/副国策/都城/官制/律法/国教）

# P0优化：渐进式解锁状态缓存
var _已解锁标签: Dictionary = {}


# P0优化：检查标签页是否解锁
func _标签已解锁(标签名: String) -> bool:
	if 标签名 == "总览" or 标签名 == "郡县":
		return true
	if 标签名 == "朝堂":
		# 护国宗及以上爵位解锁
		var 爵位: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
		return 爵位 != "未册封"
	if 标签名 == "事件":
		# 触发过反制事件或有朝廷委托时解锁
		var 待决反制: Array = Game.王朝系统.王朝.get("待决反制", [])
		if 待决反制.size() > 0:
			return true
		var 待决委托: Array = Game.王朝系统.王朝.get("待决委托", [])
		if 待决委托.size() > 0:
			return true
		return false
	if 标签名 == "信仰":
		# 建立过香火庙解锁
		if Game.香火庙 != null and Game.香火庙.size() > 0:
			return true
		return false
	if 标签名 == "奇观":
		# 国师及以上爵位解锁
		var 爵位: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
		var 爵位序: Array = ["未册封", "国师", "帝师", "监国", "摄政王"]
		var 当前序: int = 爵位序.find(爵位)
		return 当前序 >= 1
	return false


# P0优化：获取未解锁标签的提示
func _未解锁提示(标签名: String) -> String:
	match 标签名:
		"朝堂":
			return "受封护国宗爵位后解锁朝堂"
		"事件":
			return "触发王朝事件后解锁"
		"信仰":
			return "建立第一座香火庙后解锁"
		"奇观":
			return "受封国师及以上爵位后解锁奇观建造"
	return "未解锁"


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
	_build_tabs()
	_build_content_area()


func _build_header() -> void:
	_body.add_child(UITheme.建顶栏("凡人王朝", _on_back_pressed))


func _build_tabs() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.GRID / 2)
	_body.add_child(row)
	for t in TABS:
		var btn: Button = Button.new()
		btn.text = str(t)
		btn.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# P0优化：渐进式解锁，未解锁的标签显示锁定状态但不可点击
		if not _标签已解锁(str(t)):
			btn.text = "◇ " + str(t)
			btn.disabled = true
			btn.add_theme_color_override("font_color", UITheme.color_text_aux())
			btn.tooltip_text = _未解锁提示(str(t))
		else:
			btn.pressed.connect(_on_tab_pressed.bind(str(t)))
		row.add_child(btn)
		_tab_btns[str(t)] = btn


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
	for t in _tab_btns.keys():
		var b: Button = _tab_btns[t]
		# P0优化：重新检查解锁状态（可能在游戏过程中解锁）
		if not _标签已解锁(str(t)):
			b.text = "◇ " + str(t)
			b.disabled = true
			b.add_theme_color_override("font_color", UITheme.color_text_aux())
			b.tooltip_text = _未解锁提示(str(t))
		else:
			b.disabled = false
			UITheme.apply_tab_style(b, t == _cur)
			# S35-0 未读红点：总览 Tab 直接挂未读数，玩家一眼看到「今天有新鲜事」
			if t == "总览" and Game.朝报未读 > 0:
				b.text = "总览(%d)" % Game.朝报未读
			else:
				b.text = str(t)

	for c in _content.get_children():
		c.queue_free()
	if _提示 != "":
		var 提示: Label = Label.new()
		提示.text = _提示
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		提示.add_theme_color_override("font_color", UITheme.color_value(false))
		_content.add_child(提示)
	# P0优化：如果当前标签未解锁，自动跳转到总览
	if not _标签已解锁(_cur):
		_cur = "总览"
	match _cur:
		"总览": _populate_总览()
		"郡县": _populate_郡县()
		"朝堂": _populate_朝堂()
		"事件": _populate_事件()
		"信仰": _populate_信仰()
		"奇观": _populate_奇观()


# ——— 通用小组件 ———
func _card() -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(p, true)
	_content.add_child(p)
	p.modulate.a = 0.0
	var dyn_卡入场 := p.create_tween()
	dyn_卡入场.tween_property(p, "modulate:a", 1.0, 0.2)
	# PanelContainer 自身无子节点，必须先挂 VBox 再返回（原 p.get_child(0) 恒为 null）
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
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


# P0-3：数值可视化 - 进度条组件
func _进度条(值: int, 最大值: int, 标签: String = "") -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.GRID / 2)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if 标签 != "":
		var 标签l: Label = Label.new()
		标签l.text = 标签
		标签l.custom_minimum_size = Vector2(60, 0)
		UITheme.apply_aux_text(标签l)
		row.add_child(标签l)

	var bar: ProgressBar = ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 最大值
	bar.value = clamp(值, 0, 最大值)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, 16)
	# 根据值设置颜色
	var 比例: float = float(值) / float(最大值) if 最大值 > 0 else 0.0
	if 比例 >= 0.6:
		bar.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))  # 绿色
	elif 比例 >= 0.3:
		bar.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))  # 黄色
	else:
		bar.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))  # 红色
	row.add_child(bar)

	var 数值l: Label = Label.new()
	数值l.text = "%d/%d" % [值, 最大值]
	数值l.custom_minimum_size = Vector2(70, 0)
	UITheme.apply_body_text(数值l)
	row.add_child(数值l)

	return row


# P0-3：状态颜色文本
func _状态文本(值: float, 标签: String) -> Label:
	var l: Label = Label.new()
	l.text = "%s：%.0f" % [标签, 值]
	if 值 >= 70:
		l.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))  # 绿色-亲近/健康
	elif 值 >= 30:
		l.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))  # 黄色-中立/警告
	else:
		l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))  # 红色-疏远/危险
	UITheme.apply_body_text(l)
	return l


# P0-2：今日要事系统 - 获取当前最紧急的事项
func _获取今日要事() -> Array:
	var 要事: Array = []

	# 1. 待批朝奏（最高优先级）
	if not Game.朝奏.is_empty():
		要事.append({
			"级": "紧急",
			"题": "待批奏疏",
			"文": "有一道奏疏等待批复",
			"跳转": "总览",
			"颜色": Color(0.9, 0.3, 0.3)
		})

	# 2. 王朝反制事件
	var 待决反制: Array = Game.王朝系统.王朝.get("待决反制", [])
	if 待决反制.size() > 0:
		要事.append({
			"级": "紧急",
			"题": "王朝反制",
			"文": "有%d项王朝反制待应对" % 待决反制.size(),
			"跳转": "事件",
			"颜色": Color(0.9, 0.3, 0.3)
		})

	# 3. 差事即将到期
	if Game.王朝系统.凡间差事进行中 != null and Game.王朝系统.凡间差事进行中.size() > 0:
		var 临期数: int = 0
		for k in Game.王朝系统.凡间差事进行中.keys():
			var 差: Dictionary = Game.王朝系统.凡间差事进行中[k]
			if int(差.get("剩余日", 999)) <= 3:
				临期数 += 1
		if 临期数 > 0:
			要事.append({
				"级": "警告",
				"题": "差事临期",
				"文": "%d项差事即将到期" % 临期数,
				"跳转": "郡县",
				"颜色": Color(0.9, 0.7, 0.2)
			})

	# 4. 爵位义务（荐举）
	var 爵位: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
	if 爵位 == "国师" or 爵位 == "帝师":
		if not Game.王朝系统.王朝.get("本月已荐举", false):
			要事.append({
				"级": "提醒",
				"题": "荐举义务",
				"文": "本月尚未荐举官员，逾期将扣关系",
				"跳转": "朝堂",
				"颜色": Color(0.3, 0.6, 0.9)
			})

	# 5. 灾情预警
	var 灾郡数: int = 0
	for k in Game.王朝系统.郡县状态.keys():
		var 郡: Dictionary = Game.王朝系统.郡县状态[k]
		if int(郡.get("灾情", 0)) > 50:
			灾郡数 += 1
	if 灾郡数 > 0:
		要事.append({
			"级": "警告",
			"题": "郡县灾情",
			"文": "%d个郡县灾情严重" % 灾郡数,
			"跳转": "郡县",
			"颜色": Color(0.9, 0.7, 0.2)
		})

	# 6. 国祚危机
	var 国祚: int = int(Game.王朝系统.王朝.get("国祚", 100))
	if 国祚 <= 30:
		要事.append({
			"级": "紧急",
			"题": "国祚垂危",
			"文": "王朝国祚仅剩%d，即将改朝换代" % 国祚,
			"跳转": "总览",
			"颜色": Color(0.9, 0.3, 0.3)
		})

	# 7. 民心危机
	var 民心: int = int(Game.王朝系统.王朝.get("民心", 60))
	if 民心 <= 20:
		要事.append({
			"级": "警告",
			"题": "民心离散",
			"文": "民心仅剩%d，民变风险极高" % 民心,
			"跳转": "总览",
			"颜色": Color(0.9, 0.7, 0.2)
		})

	return 要事


# ——— P0新聚合页面：总览（王朝状态+今日要事+今日朝报）———
func _populate_总览() -> void:
	# ① 今日要事（P0-2）
	var 要事: Array = _获取今日要事()
	if 要事.size() > 0:
		var 要事卡: VBoxContainer = _card()
		var 要事题: Label = Label.new()
		要事题.text = "◇ 今日要事（%d项）" % 要事.size()
		UITheme.apply_section_title(要事题)
		要事卡.add_child(要事题)
		# 只显示最紧急的3项
		var 显示数: int = mini(要事.size(), 3)
		for i in range(显示数):
			var 项: Dictionary = 要事[i]
			var 项行: HBoxContainer = HBoxContainer.new()
			项行.add_theme_constant_override("separation", UITheme.GRID / 2)

			var 级l: Label = Label.new()
			级l.text = "[%s]" % str(项.get("级", ""))
			级l.add_theme_color_override("font_color", 项.get("颜色", Color.WHITE))
			级l.custom_minimum_size = Vector2(50, 0)
			UITheme.apply_body_text(级l)
			项行.add_child(级l)

			var 文l: Label = Label.new()
			文l.text = "%s：%s" % [str(项.get("题", "")), str(项.get("文", ""))]
			文l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UITheme.apply_body_text(文l)
			项行.add_child(文l)

			# 快捷跳转按钮
			var 跳转标签: String = str(项.get("跳转", ""))
			if 跳转标签 != "" and 跳转标签 != _cur and _标签已解锁(跳转标签):
				var 钮: Button = Button.new()
				钮.text = "前往"
				钮.custom_minimum_size = Vector2(50, 0)
				UITheme.apply_secondary_button_style(钮)
				钮.pressed.connect(_on_tab_pressed.bind(跳转标签))
				项行.add_child(钮)

			要事卡.add_child(项行)

	# P1-1 待决策办差奇遇
	if Game.王朝系统.待决策办差奇遇.size() > 0:
		for i in range(Game.王朝系统.待决策办差奇遇.size()):
			var 待决: Dictionary = Game.王朝系统.待决策办差奇遇[i]
			var 奇遇: Dictionary = 待决.get("奇遇", {})
			var 奇遇卡: VBoxContainer = _card()
			var 奇遇题: Label = Label.new()
			奇遇题.text = "◆ 办差奇遇待决策：%s" % str(奇遇.get("名", ""))
			UITheme.apply_section_title(奇遇题)
			奇遇卡.add_child(奇遇题)
			奇遇卡.add_child(_label(str(奇遇.get("描述", "")), true))
			奇遇卡.add_child(_label("弟子：%s　差事：%s　郡县：%s" % [
				str(待决.get("差", {}).get("接取弟子名", "?")),
				str(待决.get("差", {}).get("名", "?")),
				str(待决.get("差", {}).get("郡名", "?"))], false))
			var 选项: Array = 奇遇.get("选项", [])
			for j in range(选项.size()):
				var 选: Dictionary = 选项[j]
				var 钮: Button = Button.new()
				钮.text = str(选.get("文", ""))
				UITheme.apply_secondary_button_style(钮)
				钮.pressed.connect(_on_奇遇决策.bind(i, j))
				奇遇卡.add_child(钮)
				奇遇卡.add_child(_label("　　" + str(选.get("描述", "")), false))

	# ② 王朝状态卡片（P0-3数值可视化）
	if Game.王朝系统.王朝.is_empty():
		_card().add_child(_label("（王朝未立）", false))
		return

	var 卡: VBoxContainer = _card()
	var 国号: String = str(Game.王朝系统.王朝.get("国号", "?"))
	var 帝: Dictionary = Game.王朝系统.王朝.get("皇帝", {})
	var 头: Label = Label.new()
	头.text = "%s · %s（第%d代）" % [国号, str(帝.get("名", "?")), int(Game.王朝系统.王朝.get("朝代序", 1))]
	UITheme.apply_section_title(头)
	卡.add_child(头)

	卡.add_child(_label("阶段：%s　国策：%s" % [str(Game.王朝系统.王朝.get("阶段", "?")), str(Game.王朝系统.王朝.get("国策", "?"))], true))

	# P0-3：国祚/民心进度条
	var 国祚: int = int(Game.王朝系统.王朝.get("国祚", 0))
	var 民心: int = int(Game.王朝系统.王朝.get("民心", 0))
	卡.add_child(_进度条(国祚, 100, "国祚"))
	卡.add_child(_进度条(民心, 100, "民心"))

	# P0-3：关系值颜色显示
	var 关系: float = float(Game.王朝系统.王朝.get("对宗门关系", 0.0))
	卡.add_child(_状态文本(关系, "对宗门关系"))

	卡.add_child(_label("在位 %d 月（预期 %d 月）" % [int(Game.王朝系统.王朝.get("在位月", 0)), int(Game.王朝系统.王朝.get("预期在位月", 30))], false))
	卡.add_child(_label("日香火供奉 %d　日灵石供奉 %d" % [
			Game._郡县供奉香火_S34(), Game._郡县供奉灵石_S34()], true))

	# P1-3 终局路线进度
	var 路线: String = Game.正邪路线
	if 路线 != "":
		var 路线卡: VBoxContainer = _card()
		var 路线题: Label = Label.new()
		路线题.text = "◇ 修行路线：%s" % 路线
		UITheme.apply_section_title(路线题)
		路线卡.add_child(路线题)

		# 计算终局进度
		var 爵位: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
		var 功德: int = Game.功德 if "功德" in Game else 0
		var 业力: int = Game.业力 if "业力" in Game else 0
		var 进度: int = 0
		var 终局: String = ""
		var 描述: String = ""

		if 路线 == "玄门正道":
			终局 = "帝师 → 监国"
			进度 = min(100, int(功德 / 3) + (10 if 爵位 != "未册封" else 0) + (20 if 爵位 == "国师" else 0) + (30 if 爵位 == "帝师" else 0))
			描述 = "正道终局：辅佐皇室，监国摄政，王朝兴则宗门兴"
		elif 路线 == "九幽邪道":
			终局 = "操控 → 傀儡皇帝"
			进度 = min(100, int(业力 / 3) + (10 if 爵位 != "未册封" else 0) + (20 if 爵位 == "国师" else 0) + (30 if 爵位 == "帝师" else 0))
			描述 = "邪道终局：操控朝局，挟天子以令诸侯，供奉翻倍"
		else:
			终局 = "割据 → 自立为王"
			var 高感恩郡: int = 0
			for k in Game.王朝系统.郡县状态.keys():
				var 郡: Dictionary = Game.王朝系统.郡县状态[k]
				if int(郡.get("感恩", 0)) >= 80:
					高感恩郡 += 1
			进度 = min(100, 高感恩郡 * 20 + (10 if 爵位 != "未册封" else 0))
			描述 = "中立终局：挖王朝墙角，割据自立，脱离朝廷管控"

		路线卡.add_child(_label("终局目标：%s" % 终局, true))
		路线卡.add_child(_进度条(进度, 100, "进度"))
		路线卡.add_child(_label(描述, false))

	# P1-3 阶段目标引导
	var 阶段: String = str(Game.王朝系统.王朝.get("阶段", "开国"))
	var 目标卡: VBoxContainer = _card()
	var 目标题: Label = Label.new()
	目标题.text = "◆ 当前阶段目标（%s）" % 阶段
	UITheme.apply_section_title(目标题)
	目标卡.add_child(目标题)

	match 阶段:
		"开国":
			目标卡.add_child(_label("1. 确立正统性，避免被朝廷视为邪教剿灭", true))
			目标卡.add_child(_label("2. 提升对宗门关系，争取受封护国宗爵位", false))
			目标卡.add_child(_label("3. 积累基础资源，度过王朝初期的动荡期", false))
		"盛世":
			目标卡.add_child(_label("1. 经营郡县，推高感恩度，扩大供奉收入", true))
			目标卡.add_child(_label("2. 平衡朝堂派系，扶持对宗门有利的派系掌权", false))
			目标卡.add_child(_label("3. 积累功德/业力，为终局路线做准备", false))
		"中衰":
			目标卡.add_child(_label("1. 站队押注继承人，为新朝铺路", true))
			目标卡.add_child(_label("2. 调停民变，提升朝廷对宗门的依赖度", false))
			目标卡.add_child(_label("3. 乱世出英杰，注意搜寻高资质苗子", false))
		"乱世":
			目标卡.add_child(_label("1. 平叛或割据，根据路线选择立场", true))
			目标卡.add_child(_label("2. 流民中出天才，重点寻访灵根苗子", false))
			目标卡.add_child(_label("3. 准备迎接改朝换代，新朝新气象", false))
		_:
			目标卡.add_child(_label("积累实力，静观其变", true))

	# ③ 今日朝报摘要
	if not Game.朝报.is_empty():
		var 摘卡: VBoxContainer = _card()
		var 摘题: Label = Label.new()
		摘题.text = "◇ 今日朝报"
		UITheme.apply_section_title(摘题)
		摘卡.add_child(摘题)
		var 最新: Dictionary = Game.朝报[0] as Dictionary
		摘卡.add_child(_label("【%s】%s" % [str(最新.get("类型", "寻常")), str(最新.get("标题", ""))], true))
		摘卡.add_child(_label(str(最新.get("正文", "")), false))
		if Game.朝报未读 > 0:
			var 钮: Button = Button.new()
			钮.text = "查看全部朝报（%d 条未读）" % Game.朝报未读
			UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(_on_goto_gazette)
			摘卡.add_child(钮)

	# ④ 待批朝奏（如果有）
	if not Game.朝奏.is_empty():
		var 奏卡: VBoxContainer = _card()
		var 奏题: Label = Label.new()
		奏题.text = "◇ 待批奏疏 · " + str(Game.朝奏.get("类", "庶务"))
		UITheme.apply_section_title(奏题)
		奏卡.add_child(奏题)
		奏卡.add_child(_label(str(Game.朝奏.get("名", "奏疏")), true))
		奏卡.add_child(_label(str(Game.朝奏.get("正文", "")), false))
		var 选项: Array = Game.朝奏.get("选项", [])
		for i in range(选项.size()):
			var 项: Dictionary = 选项[i]
			var 钮: Button = Button.new()
			钮.text = str(项.get("文", ""))
			UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(_on_memorial_pressed.bind(i))
			奏卡.add_child(钮)


# ——— P0新聚合页面：郡县（12郡列表+凡间差事）———
func _populate_郡县() -> void:
	# ① 郡县一览
	var 郡卡: VBoxContainer = _card()
	var 郡头: Label = Label.new()
	郡头.text = "◇ 郡县一览"
	UITheme.apply_section_title(郡头)
	郡卡.add_child(郡头)
	var 有凡俗郡: bool = false
	for k in Game.王朝系统.郡县状态.keys():
		var 郡: Dictionary = Game.王朝系统.郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		有凡俗郡 = true
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID / 2)

		var 名l: Label = Label.new()
		名l.text = "%s（Lv%d）" % [str(郡.get("名", "?")), int(郡.get("等级", 1))]
		名l.custom_minimum_size = Vector2(100, 0)
		UITheme.apply_body_text(名l)
		行.add_child(名l)

		# P0-3：忠顺度/感恩度颜色显示
		var 忠顺: int = int(郡.get("忠顺", 0))
		var 感恩: int = int(郡.get("感恩", 0))
		var 忠顺l: Label = Label.new()
		忠顺l.text = "忠顺%d" % 忠顺
		if 忠顺 >= 60:
			忠顺l.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		elif 忠顺 >= 30:
			忠顺l.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		else:
			忠顺l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		UITheme.apply_aux_text(忠顺l)
		行.add_child(忠顺l)

		var 感恩l: Label = Label.new()
		感恩l.text = "感恩%d" % 感恩
		if 感恩 >= 60:
			感恩l.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		elif 感恩 >= 30:
			感恩l.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		else:
			感恩l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		UITheme.apply_aux_text(感恩l)
		行.add_child(感恩l)

		if int(郡.get("灾情", 0)) > 0:
			var 灾l: Label = Label.new()
			灾l.text = "【灾】"
			灾l.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			UITheme.apply_aux_text(灾l)
			行.add_child(灾l)

		郡卡.add_child(行)
	if not 有凡俗郡:
		郡卡.add_child(_label("（暂无非凡俗郡县）", false))

	# ② 入赘名录
	if not Game.王朝系统.入赘名录.is_empty():
		var 赘卡: VBoxContainer = _card()
		var 赘头: Label = Label.new()
		赘头.text = "◇ 入赘名录"
		UITheme.apply_section_title(赘头)
		赘卡.add_child(赘头)
		for it in Game.王朝系统.入赘名录:
			var d: Dictionary = it as Dictionary
			赘卡.add_child(_label("%s（%s·%s）第%d日入%s" % [
					str(d.get("名", "?")), str(d.get("境界", "")), str(d.get("资质", "")), int(d.get("日", 0)), str(d.get("去向", "外戚府"))], false))

	# ③ 凡间差事榜（调用原有函数）
	_populate_decree()


# ——— P0新聚合页面：朝堂（派系+爵位+荐举+皇储）———
func _populate_朝堂() -> void:
	# ① 派系（调用原有函数）
	_populate_court()
	# ② 爵位（调用原有函数）
	_populate_title()
	# ③ 皇储（调用原有函数）
	_populate_heir()


# ——— P0新聚合页面：事件（诏令+朝廷委托+反制应对）———
func _populate_事件() -> void:
	# ① 诏令（调用原有函数）
	_populate_edict()
	# ② 朝廷委托（调用原有函数）
	_populate_commission()
	# ③ 反制应对（如果有反制列表，显示在顶部）
	var 待决反制: Array = Game.王朝系统.王朝.get("待决反制", [])
	if 待决反制.size() > 0:
		var 反制卡: VBoxContainer = _card()
		var 反制题: Label = Label.new()
		反制题.text = "⚠ 王朝反制（%d项待应对）" % 待决反制.size()
		UITheme.apply_section_title(反制题)
		反制卡.add_child(反制题)
		for i in range(待决反制.size()):
			var 项: Dictionary = 待决反制[i]
			反制卡.add_child(_label(str(项.get("名", "反制")), true))
			反制卡.add_child(_label(str(项.get("描述", "")), false))
			var 选项: Array = 反制选项表.get(str(项.get("类型", "")), [])
			for j in range(选项.size()):
				var 选: Array = 选项[j]
				var 钮: Button = Button.new()
				钮.text = str(选[1])
				UITheme.apply_secondary_button_style(钮)
				钮.pressed.connect(_on_counter_pressed.bind(i, str(选[0])))
				反制卡.add_child(钮)


# ——— P0新聚合页面：信仰（香火庙+愿力+功德/业力）———
func _populate_信仰() -> void:
	_populate_faith()


# P1-1 办差奇遇决策回调
func _on_奇遇决策(奇遇索引: int, 选项索引: int) -> void:
	var 果: Dictionary = Game.决策办差奇遇(奇遇索引, 选项索引)
	if not bool(果.get("成功", false)):
		_提示 = str(果.get("因", "决策失败"))
	else:
		var 成功_str: String = "差事成功" if bool(果.get("差事成功", false)) else "差事失败"
		_提示 = str(果.get("摘要", "已决策")) + "（" + 成功_str + "）"
	refresh()

# P0：反制应对按钮回调
func _on_counter_pressed(索引: int, 选择: String) -> void:
	var 待决反制: Array = Game.王朝系统.王朝.get("待决反制", [])
	if 索引 >= 待决反制.size():
		return
	var 项: Dictionary = 待决反制[索引]
	var 果: Dictionary = Game.应对王朝反制_S34(str(项.get("id", "")), 选择)
	if not bool(果.get("成功", false)):
		_提示 = str(果.get("因", "应对失败"))
	else:
		_提示 = "已应对：" + str(果.get("摘要", "完成"))
	refresh()


# ——— 天下：王朝总览 + 郡县 ———
# ——— 邸报：每日新鲜感主入口（S35-0） ———
func _populate_gazette() -> void:
	# ① 待批朝奏：每日一道，三选一（离线不自动结算，登录后玩家手动批）
	if not Game.朝奏.is_empty():
		var 卡: VBoxContainer = _card()
		var 题: Label = Label.new()
		题.text = "待批奏疏 · " + str(Game.朝奏.get("类", "庶务"))
		UITheme.apply_section_title(题)
		卡.add_child(题)
		卡.add_child(_label(str(Game.朝奏.get("名", "奏疏")), true))
		卡.add_child(_label(str(Game.朝奏.get("正文", "")), false))
		var 选项: Array = Game.朝奏.get("选项", [])
		for i in range(选项.size()):
			var 项: Dictionary = 选项[i]
			var 钮: Button = Button.new()
			钮.text = str(项.get("文", ""))
			UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(_on_memorial_pressed.bind(i))
			卡.add_child(钮)
	else:
		var 卡2: VBoxContainer = _card()
		卡2.add_child(_label("（今日奏疏已批，明日早朝再议。）", false))
	# ② 邸报条目
	var 头: Label = Label.new()
	if Game.朝报未读 > 0:
		头.text = "朝报（%d 条未读）" % Game.朝报未读
	else:
		头.text = "朝报"
	UITheme.apply_section_title(头)
	_content.add_child(头)
	if Game.朝报.is_empty():
		_card().add_child(_label("（尚无邸报。天命维新，静待佳音。）", false))
		return
	var 上限: int = mini(Game.朝报.size(), 60)
	for i in range(上限):
		var 记: Dictionary = Game.朝报[i] as Dictionary
		var 类: String = str(记.get("类型", "寻常"))
		var 前缀: String = "【常】"
		if 类 == "喜讯":
			前缀 = "【喜】"
		elif 类 == "警讯":
			前缀 = "【警】"
		elif 类 == "待办":
			前缀 = "【办】"
		elif 类 == "异闻":
			前缀 = "【异】"
		var 题文: String = 前缀 + str(记.get("标题", ""))
		if not bool(记.get("已读", false)):
			题文 += " ·新"
		var 卡3: VBoxContainer = _card()
		卡3.add_child(_label(题文, 类 != "寻常"))
		卡3.add_child(_label(str(记.get("正文", "")), false))
		卡3.add_child(_label("第%d月 · 第%d日" % [int(记.get("王朝月", 0)), int(记.get("游戏日", 0))], false))
	# 进入即视为已读（红点清零发生在下一次 refresh）
	Game.标记朝报已读()


func _on_memorial_pressed(索引: int) -> void:
	var 果: Dictionary = Game.应对朝奏_S34(索引)
	if not bool(果.get("成功", false)):
		_提示 = str(果.get("因", "无法批复"))
	else:
		var 摘: String = ""
		for s in (果.get("摘要", []) as Array):
			if 摘 != "":
				摘 += "；"
			摘 += str(s)
		_提示 = "已批复。" + (摘 if 摘 != "" else "（无显性损益）")
	refresh()


func _on_goto_gazette() -> void:
	# P0优化：邸报已合并到总览页
	_on_tab_pressed("总览")
func _populate_world() -> void:
	# S35-0 今日朝报摘要：王朝面板首屏即见动态，不必切 Tab 才知道发生了什么
	if not Game.朝报.is_empty():
		var 摘卡: VBoxContainer = _card()
		var 摘题: Label = Label.new()
		摘题.text = "今日朝报"
		UITheme.apply_section_title(摘题)
		摘卡.add_child(摘题)
		var 最新: Dictionary = Game.朝报[0] as Dictionary
		摘卡.add_child(_label("【%s】%s" % [str(最新.get("类型", "寻常")), str(最新.get("标题", ""))], true))
		摘卡.add_child(_label(str(最新.get("正文", "")), false))
		if Game.朝报未读 > 0:
			var 钮: Button = Button.new()
			钮.text = "查看全部（%d 条未读）" % Game.朝报未读
			UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(_on_goto_gazette)
			摘卡.add_child(钮)
	if Game.王朝系统.王朝.is_empty():
		_card().add_child(_label("（王朝未立）", false))
		return
	var 卡: VBoxContainer = _card()
	var 国号: String = str(Game.王朝系统.王朝.get("国号", "?"))
	var 帝: Dictionary = Game.王朝系统.王朝.get("皇帝", {})
	var 头: Label = Label.new()
	头.text = "%s · %s（第%d代）" % [国号, str(帝.get("名", "?")), int(Game.王朝系统.王朝.get("朝代序", 1))]
	UITheme.apply_section_title(头)
	卡.add_child(头)
	卡.add_child(_label("阶段：%s　国策：%s" % [str(Game.王朝系统.王朝.get("阶段", "?")), str(Game.王朝系统.王朝.get("国策", "?"))], true))
	卡.add_child(_label("国祚 %d　民心 %d　对宗门关系 %.0f" % [
			int(Game.王朝系统.王朝.get("国祚", 0)), int(Game.王朝系统.王朝.get("民心", 0)), float(Game.王朝系统.王朝.get("对宗门关系", 0.0))], true))
	卡.add_child(_label("在位 %d 月（预期 %d 月）" % [int(Game.王朝系统.王朝.get("在位月", 0)), int(Game.王朝系统.王朝.get("预期在位月", 30))], false))
	卡.add_child(_label("日香火供奉 %d　日灵石供奉 %d" % [
			Game._郡县供奉香火_S34(), Game._郡县供奉灵石_S34()], true))
	# 郡县一览
	var 郡卡: VBoxContainer = _card()
	var 郡头: Label = Label.new()
	郡头.text = "—— 郡县 ——"
	UITheme.apply_section_title(郡头)
	郡卡.add_child(郡头)
	for k in Game.王朝系统.郡县状态.keys():
		var 郡: Dictionary = Game.王朝系统.郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		var 行: Label = Label.new()
		行.text = "%s（Lv%d）　忠顺 %d　感恩 %d%s" % [
			str(郡.get("名", "?")), int(郡.get("等级", 1)),
			int(郡.get("忠顺", 0)), int(郡.get("感恩", 0)),
			"　【灾】" if int(郡.get("灾情", 0)) > 0 else ""]
		UITheme.apply_body_text(行)
		郡卡.add_child(行)
	if not Game.王朝系统.入赘名录.is_empty():
		var 赘卡: VBoxContainer = _card()
		var 赘头: Label = Label.new()
		赘头.text = "—— 入赘名录 ——"
		UITheme.apply_section_title(赘头)
		赘卡.add_child(赘头)
		for it in Game.王朝系统.入赘名录:
			var d: Dictionary = it as Dictionary
			赘卡.add_child(_label("%s（%s·%s）第%d日入%s" % [
					str(d.get("名", "?")), str(d.get("境界", "")), str(d.get("资质", "")), int(d.get("日", 0)), str(d.get("去向", "外戚府"))], false))


# ——— 差事：凡间差事榜（批次 1 欠账，本期补 UI）———
func _populate_decree() -> void:
	var 榜: Dictionary = Game.王朝系统.凡间差事榜
	var 进行: Dictionary = Game.王朝系统.凡间差事进行中
	if 榜.is_empty() and 进行.is_empty():
		_card().add_child(_label("（差事榜空，每月初刷新）", false))
		return
	if not 进行.is_empty():
		var 卡: VBoxContainer = _card()
		var 头: Label = Label.new()
		头.text = "—— 执行中 ——"
		UITheme.apply_section_title(头)
		卡.add_child(头)
		for k in 进行.keys():
			var 差: Dictionary = 进行[k]
			卡.add_child(_label("「%s」%s·%s　第%d日到期" % [
					str(差.get("名", "?")), str(差.get("郡名", "")), str(差.get("接取弟子名", "?")), int(差.get("到期日", 0))], true))
	for k in 榜.keys():
		var 差: Dictionary = 榜[k]
		var 卡: VBoxContainer = _card()
		var 名: Label = Label.new()
		名.text = "「%s」%s" % [str(差.get("名", "?")), str(差.get("郡名", ""))]
		UITheme.apply_body_text(名)
		卡.add_child(名)
		卡.add_child(_label("难度 %d　需%s　需道行 %d　耗时 %d 日" % [
				int(差.get("难度", 1)), str(差.get("要求境界", "练气")), int(差.get("要求战力", 0)), int(差.get("耗时天", 3))], false))
		卡.add_child(_label("成：感恩+%d 灵石+%d 战功+%d　败：感恩%d 忠诚%d" % [
				int(差.get("奖励感恩", 0)), int(差.get("奖励灵石", 0)), int(差.get("奖励战功", 0)),
			int(差.get("惩罚感恩", 0)), int(差.get("惩罚忠诚", 0))], false))
		var tid: String = str(k)
		if _展开差事 == tid:
			_build_pick_disciple(卡, 差, tid)
		else:
			var 接: Button = Button.new()
			接.text = "差遣弟子"
			接.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(接)
			接.pressed.connect(func():
				_展开差事 = tid
				_提示 = ""
				refresh()
			)
			卡.add_child(接)


func _build_pick_disciple(卡: VBoxContainer, 差: Dictionary, tid: String) -> void:
	var 需境: String = str(差.get("要求境界", "练气"))
	var 需战力: int = int(差.get("要求战力", 0))
	var 可选: Array = []
	for d in Game.弟子列表:
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		if Disciple.境界序.find(d.境界) < Disciple.境界序.find(需境):
			continue
		if int(d.总战力()) < 需战力:
			continue
		var 占: bool = false
		for kk in Game.王朝系统.凡间差事进行中.keys():
			if str((Game.王朝系统.凡间差事进行中[kk] as Dictionary).get("接取弟子ID", "")) == str(d.弟子ID):
				占 = true
				break
		if 占:
			continue
		可选.append(d)
	if 可选.is_empty():
		卡.add_child(_label("（无符合要求的空闲弟子）", false))
	else:
		for d in 可选:
			var 钮: Button = Button.new()
			钮.text = "派 %s（%s·道行%d）" % [str(d.姓名), str(d.境界), int(d.总战力())]
			钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(钮)
			var 弟子ID: String = str(d.弟子ID)
			钮.pressed.connect(func():
				var 果: Dictionary = Game.接取凡间差事_S34(tid, 弟子ID)
				_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
				_展开差事 = ""
				refresh()
			)
			卡.add_child(钮)
	var 收: Button = Button.new()
	收.text = "收起"
	收.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(收)
	收.pressed.connect(func():
		_展开差事 = ""
		refresh()
	)
	卡.add_child(收)


# ——— 朝堂：四派系权重 + 扶持 + 外戚索要待决 ———
func _populate_court() -> void:
	# 外戚索要待决：优先置顶，玩家必须先看这个
	if not Game.王朝系统.外戚索要待决.is_empty():
		var 警卡: VBoxContainer = _card()
		var 警: Label = Label.new()
		警.text = "外戚点名索要 %s（%s·%s）入赘" % [
				str(Game.王朝系统.外戚索要待决.get("弟子名", "?")), str(Game.王朝系统.外戚索要待决.get("境界", "")), str(Game.王朝系统.外戚索要待决.get("资质", ""))]
		警.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		警.add_theme_color_override("font_color", UITheme.color_status_danger())
		警卡.add_child(警)
		警卡.add_child(_label("应允：弟子离宗，其师父/道侣/同门忠诚下滑，王朝关系+10、外戚权重+10", false))
		警卡.add_child(_label("回绝：王朝关系-15、外戚记恨权重+8", false))
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID / 2)
		警卡.add_child(行)
		var 允: Button = Button.new()
		允.text = "应允"
		允.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(允)
		允.pressed.connect(func():
			var 果: Dictionary = Game.应对外戚索要_S34(true)
			_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		行.add_child(允)
		var 拒: Button = Button.new()
		拒.text = "回绝"
		拒.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(拒)
		拒.pressed.connect(func():
			var 果: Dictionary = Game.应对外戚索要_S34(false)
			_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		行.add_child(拒)
	_build_recommend()
	var 派系: Array = Game.王朝系统.王朝.get("派系", [])
	if 派系.is_empty():
		_card().add_child(_label("（朝堂派系未初始化）", false))
		return
	var 卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "—— 朝堂派系 ——"
	UITheme.apply_section_title(头)
	卡.add_child(头)
	卡.add_child(_label("掌权者每月流失势能、在野者每月积蓄，故掌权必被推翻；扶持会同时得罪其余三派。", false))
	for it in 派系:
		var 项: Dictionary = it as Dictionary
		var 名: String = str(项.get("名", "?"))
		var 掌权: bool = bool(项.get("掌权", false))
		var 行: Label = Label.new()
		行.text = "%s%s　权重 %d　恩遇 %d　宿怨 %d" % [
			名, "【掌权】" if 掌权 else "", int(项.get("权重", 0)), int(项.get("恩遇", 0)), int(项.get("宿怨", 0))]
		if 掌权:
			行.add_theme_color_override("font_color", UITheme.color_value(false))
		else:
			UITheme.apply_body_text(行)
		卡.add_child(行)
		var 条: ProgressBar = ProgressBar.new()
		条.min_value = 0
		条.max_value = 100
		条.value = int(项.get("权重", 0))
		条.show_percentage = false
		条.custom_minimum_size = Vector2(0, int(round(10.0 * UITheme.UI_SCALE)))
		卡.add_child(条)
		var 诉: Label = Label.new()
		诉.text = "诉求：%s　代价：%s" % [_扶持代价(名), _派系诉求(名)]
		UITheme.apply_aux_text(诉)
		卡.add_child(诉)
		var 扶: Button = Button.new()
		扶.text = "扶持%s" % 名
		扶.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(扶)
		var 派系名: String = 名
		扶.pressed.connect(func():
			var 果: Dictionary = Game.扶持派系_S34(派系名)
			_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		卡.add_child(扶)


# ——— 荐举朝臣（国师之权 / 月度义务）———
# 义务的 UI 入口是义务本身的一部分：没有这个入口，玩家每月只能眼睁睁掉关系。
func _build_recommend() -> void:
	var 位阶: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
	if 位阶 == "未册封":
		return
	var 配: Dictionary = Game._爵位配置(位阶)
	if str(配.get("duty_type", "none")) != "recommend":
		return
	var 费: int = int(配.get("duty_cost", 0))
	var 卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "—— 荐举朝臣（%s之权）——" % 位阶
	UITheme.apply_section_title(头)
	卡.add_child(头)
	卡.add_child(_label("荐举对象即你押注的派系：权重+4、恩遇+1。荐举非掌权派系会被掌权者记恨（宿怨+1）。", false))
	var 已荐: bool = int(Game.王朝系统.王朝.get("上次荐举月", -99)) == int(Game.王朝系统.王朝.get("在位月", 0))
	var 态: Label = Label.new()
	if 已荐:
		态.text = "本月已荐举，下月再议"
		UITheme.apply_body_text(态)
	else:
		态.text = "本月尚未荐举（耗灵石%d，逾期则朝廷不满）" % 费
		态.add_theme_color_override("font_color", UITheme.color_status_danger())
	卡.add_child(态)
	var 容: Array = Game.王朝系统.王朝.get("派系", [])
	if 容.is_empty():
		return
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID / 2)
	卡.add_child(行)
	var 行2: HBoxContainer = HBoxContainer.new()
	行2.add_theme_constant_override("separation", UITheme.GRID / 2)
	卡.add_child(行2)
	for i in range(容.size()):
		var 项: Dictionary = 容[i] as Dictionary
		var 名: String = str(项.get("名", "?"))
		var 荐: Button = Button.new()
		荐.text = "荐举%s" % 名
		荐.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		荐.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.apply_secondary_button_style(荐)
		荐.disabled = 已荐
		var 派系名: String = 名
		荐.pressed.connect(func():
			var 果: Dictionary = Game.荐举派系_S34(派系名)
			_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		if i < 2:
			行.add_child(荐)
		else:
			行2.add_child(荐)
func _派系诉求(名: String) -> String:
	var 配: Dictionary = Game._派系配置(名)
	if 配.is_empty():
		return "未知"
	var 类型: String = str(配.get("desire_type", ""))
	var 量: int = int(配.get("desire_cost", 0))
	if 类型 == "contribution":
		return "贡献点 %d" % 量
	if 类型 == "pill":
		return "库房丹药 %d" % 量
	if 类型 == "lingshi":
		return "灵石 %d" % 量
	if 类型 == "disciple":
		return "送弟子入赘（点名后由你决断）"
	return "未知"


func _扶持代价(名: String) -> String:
	var 配: Dictionary = Game._派系配置(名)
	if 配.is_empty():
		return "—"
	return "供奉×%s　苗子×%s　危机×%s　战功×%s" % [
		str(配.get("tribute_rate", "1.0")), str(配.get("talent_rate", "1.0")),
		str(配.get("crisis_rate", "1.0")), str(配.get("merit_rate", "1.0"))]


# ——— 册封：位阶门槛 + 权利义务 + 受封/辞位 ———
func _populate_title() -> void:
	var 当前: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
	var 卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "当前爵位：%s" % 当前
	UITheme.apply_section_title(头)
	卡.add_child(头)
	var 配: Dictionary = Game._爵位配置(当前)
	if not 配.is_empty():
		卡.add_child(_label("权利：%s" % str(配.get("right_desc", "—")), true))
		卡.add_child(_label("义务：%s" % str(配.get("duty_desc", "—")), true))
		卡.add_child(_label("月度开销：%s" % (("%d 灵石" % int(配.get("duty_cost", 0))) if int(配.get("duty_cost", 0)) > 0 else "无"), false))
	if 当前 != "未册封":
		var 辞: Button = Button.new()
		辞.text = "辞去%s（王朝关系-12）" % 当前
		辞.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(辞)
		辞.pressed.connect(func():
			var 果: Dictionary = Game.辞去爵位_S34()
			_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		卡.add_child(辞)
	if 当前 == "监国" or 当前 == "摄政":
		var 权卡: VBoxContainer = _card()
		var 权头: Label = Label.new()
		权头.text = "—— 终局权柄 ——"
		UITheme.apply_section_title(权头)
		权卡.add_child(权头)
		if 当前 == "监国":
			权卡.add_child(_label("监国可行伊霍之事：废立皇帝（不可逆，民心-8、国祚-10、业力+10）", false))
			var 废: Button = Button.new()
			废.text = "废立皇帝（不可逆）"
			废.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(废)
			废.pressed.connect(_废立皇帝)
			权卡.add_child(废)
		else:
			权卡.add_child(_label("摄政可更易国策（国策真实影响供奉与反制，每次民心-2）", false))
			var 现行: String = str(Game.王朝系统.王朝.get("国策", ""))
			for 行 in Game._读王朝配置():
				var 策: String = str((行 as Dictionary).get("policy_name", ""))
				if 策 == "":
					continue
				var 在行: bool = (策 == 现行)
				var 策钮: Button = Button.new()
				策钮.text = ("%s（现行）" % 策) if 在行 else 策
				策钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
				UITheme.apply_secondary_button_style(策钮)
				策钮.disabled = 在行
				策钮.pressed.connect(_改国策.bind(策))
				权卡.add_child(策钮)
	# 门槛进度
	var 门卡: VBoxContainer = _card()
	var 门头: Label = Label.new()
	门头.text = "—— 册封门槛 ——"
	UITheme.apply_section_title(门头)
	门卡.add_child(门头)
	门卡.add_child(_label("对宗门关系 %.0f　感恩≥50 郡数 %d　门派等级 %d　功德 %d　业力 %d" % [
			float(Game.王朝系统.王朝.get("对宗门关系", 0.0)), Game._感恩达标郡数_S34(50), Game.门派等级, Game.功德, Game.业力], true))
	var 可受: Array = Game.可受封爵位_S34()
	if 可受.is_empty():
		门卡.add_child(_label("（暂无可晋升的爵位）", false))
	else:
		for 位阶 in 可受:
			var 阶: String = str(位阶)
			var 阶配: Dictionary = Game._爵位配置(阶)
			var 阶卡: VBoxContainer = _card()
			var 阶头: Label = Label.new()
			阶头.text = "可受封：%s" % 阶
			UITheme.apply_section_title(阶头)
			阶卡.add_child(阶头)
			阶卡.add_child(_label("权利：%s" % str(阶配.get("right_desc", "—")), true))
			var 义: Label = Label.new()
			义.text = "义务：%s" % str(阶配.get("duty_desc", "—"))
			义.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			义.add_theme_color_override("font_color", UITheme.color_status_danger())
			阶卡.add_child(义)
			var 受: Button = Button.new()
			受.text = ("掀桌·自立为王" if 阶 == "自立为王" else ("受封为%s" % 阶))
			受.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(受)
			受.pressed.connect(func():
				var 果: Dictionary = Game.受封爵位_S34(阶)
				_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
				refresh()
			)
			阶卡.add_child(受)

func _废立皇帝() -> void:
	var 果: Dictionary = Game.废立皇帝_S34()
	_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
	refresh()

func _改国策(策: String) -> void:
	var 果: Dictionary = Game.操控国策_S34(策)
	_提示 = str(果.get("消息", "")) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
	refresh()

# ——— 诏令：待决反制与应对（王朝有牙齿的主界面） ———
func _populate_edict() -> void:
	var 头卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "朝廷诏令　国祚 %d　民心 %d　对宗门关系 %.0f" % [
			int(Game.王朝系统.王朝.get("国祚", 0)), int(Game.王朝系统.王朝.get("民心", 0)), float(Game.王朝系统.王朝.get("对宗门关系", 0.0))]
	UITheme.apply_section_title(头)
	头卡.add_child(头)
	头卡.add_child(_label("诏令逾期不决，将自动按最坏结果执行（决策窗口 %d 个王朝月）" % Game.反制决策窗口, false))
	var 待决: Array = Game.王朝系统.王朝.get("待决反制", []) if Game.王朝系统.王朝.get("待决反制", null) != null else []
	if 待决.is_empty():
		var 空卡: VBoxContainer = _card()
		空卡.add_child(_label("眼下并无诏令临门。", true))
		空卡.add_child(_label("国祚低迷会招强征、感恩崩坏会致断供、民心离散则生民变 —— 皆有其兆，宜早为之计。", false))
		return
	for it in 待决:
		var 项: Dictionary = it as Dictionary
		var 实例: String = str(项.get("实例ID", ""))
		var 反制ID: String = str(项.get("反制ID", ""))
		if 实例 == "" or 反制ID == "":
			continue
		var 配: Dictionary = Game._反制配置(反制ID)
		var 卡: VBoxContainer = _card()
		var 题: Label = Label.new()
		题.text = "%s%s" % [str(项.get("名", "?")), ("·" + str(项.get("郡名", ""))) if str(项.get("郡名", "")) != "" else ""]
		UITheme.apply_section_title(题)
		卡.add_child(题)
		var 险: Label = Label.new()
		险.text = "后果：%s" % str(配.get("penalty_desc", "—"))
		险.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		险.add_theme_color_override("font_color", UITheme.color_status_danger())
		卡.add_child(险)
		var 机: Label = Label.new()
		机.text = "转机：%s" % str(配.get("convert_desc", "—"))
		UITheme.apply_aux_text(机)
		机.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		卡.add_child(机)
		var 成本: int = int(项.get("成本", 0))
		if 成本 > 0:
			var 免: bool = 反制ID == "dc_minbian" and Game._可调停民变_S34()
			卡.add_child(_label("所需灵石：%d%s" % [成本, "（国师调停免单）" if 免 else ""], false))
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID / 2)
		卡.add_child(行)
		var 选项表: Array = 反制选项表.get(反制ID, []) if 反制选项表.has(反制ID) else []
		for 组 in 选项表:
			var 码: String = str((组 as Array)[0])
			var 文案: String = str((组 as Array)[1])
			var 钮: Button = Button.new()
			钮.text = 文案
			钮.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			if 码 in ["pay", "ransom", "repair", "mediate"]:
				UITheme.apply_primary_button_style(钮)
			else:
				UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(func():
				var 果: Dictionary = Game.应对王朝反制_S34(实例, 码)
				_提示 = ("已应对：%s" % str(果.get("反制", ""))) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
				refresh()
			)
			行.add_child(钮)


# ——— 委托：朝廷征调（护国宗不可拒，仅有应征/拖延） ———
func _populate_commission() -> void:
	if Game.王朝系统.王朝.is_empty():
		_card().add_child(_label("（王朝未立）", false))
		return
	var 头卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "朝廷征调　国祚 %d　民心 %d　对宗门关系 %.0f" % [
			int(Game.王朝系统.王朝.get("国祚", 0)), int(Game.王朝系统.王朝.get("民心", 0)), float(Game.王朝系统.王朝.get("对宗门关系", 0.0))]
	UITheme.apply_section_title(头)
	头卡.add_child(头)
	# 与 game_state.gd 的 _须应征调_S34 同义：仅护国宗须应征调，自立为王豁免
	var 爵位: String = str(Game.王朝系统.王朝.get("宗门爵位", "未册封"))
	if 爵位 != "护国宗":
		头卡.add_child(_label("仅「护国宗」须应朝廷征调（自立为王者不受此制）。", false))
		头卡.add_child(_label("受封护国宗后，朝廷会不定时下诏征调弟子办差，不可拒绝 —— 拖延亦将按最严档结算。", false))
		return
	头卡.add_child(_label("护国宗须应征调：应征可遣弟子领命，拖延将逾期按最严档结算（关系暴跌）。", false))
	var 待决: Array = Game.王朝系统.王朝.get("待决委托", []) if Game.王朝系统.王朝.get("待决委托", null) != null else []
	if 待决.is_empty():
		var 空卡: VBoxContainer = _card()
		空卡.add_child(_label("眼下并无朝廷征调临门。", true))
		空卡.add_child(_label("每月至多一道征调，办成则感恩/灵石/战功皆有赏。", false))
		return
	var 今月: int = int(Game.王朝系统.王朝.get("在位月", 0))
	for it in 待决:
		var 项: Dictionary = it as Dictionary
		var 实例: String = str(项.get("实例ID", ""))
		if 实例 == "":
			continue
		var 卡: VBoxContainer = _card()
		var 题: Label = Label.new()
		题.text = "%s%s" % [str(项.get("名", "?")), ("·" + str(项.get("郡名", ""))) if str(项.get("郡名", "")) != "" else ""]
		UITheme.apply_section_title(题)
		卡.add_child(题)
		卡.add_child(_label("类型 %s　难度 %d　需%s　需道行 %d　耗时 %d 日%s" % [
			str(项.get("类型", "?")), int(项.get("难度", 1)), str(项.get("要求境界", "练气")),
			int(项.get("要求战力", 0)), int(项.get("耗时天", 5)),
			("　成本灵石 %d" % int(项.get("成本灵石", 0))) if int(项.get("成本灵石", 0)) > 0 else ""], false))
		卡.add_child(_label("赏：感恩+%d 灵石+%d 战功+%d　罚：感恩%d 忠诚%d" % [
			int(项.get("奖励感恩", 0)), int(项.get("奖励灵石", 0)), int(项.get("奖励战功", 0)),
			int(项.get("惩罚感恩", 0)), int(项.get("惩罚忠诚", 0))], false))
		if str(项.get("状态", "")) == "执行中":
			卡.add_child(_label("执行中：%s 领命，第 %d 日到期" % [str(项.get("接取弟子名", "?")), int(项.get("到期日", 0))], true))
			continue
		var 余: int = Game.委托决策窗口 - (今月 - int(项.get("生成月", 0)))
		var 期: Label = Label.new()
		if 余 > 0:
			期.text = "决策窗口剩余 %d 个王朝月，逾期按拖延最严档结算" % 余
			UITheme.apply_aux_text(期)
		else:
			期.text = "已逾决策窗口，下次结算将按拖延最严档执行"
			期.add_theme_color_override("font_color", UITheme.color_status_danger())
		期.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		卡.add_child(期)
		if _展开委托 == 实例:
			_build_pick_commission_disciple(卡, 项, 实例)
		else:
			var 行: HBoxContainer = HBoxContainer.new()
			行.add_theme_constant_override("separation", UITheme.GRID / 2)
			卡.add_child(行)
			var 征: Button = Button.new()
			征.text = "应征"
			征.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(征)
			var 实例ID: String = 实例
			征.pressed.connect(func():
				_展开委托 = 实例ID
				_提示 = ""
				refresh()
			)
			行.add_child(征)
			var 拖: Button = Button.new()
			拖.text = "拖延"
			拖.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(拖)
			拖.pressed.connect(func():
				var 果: Dictionary = Game.应对王朝委托_S34(实例ID, "delay")
				_提示 = ("已暂缓应对：%s" % str(果.get("说明", ""))) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
				refresh()
			)
			行.add_child(拖)

func _build_pick_commission_disciple(卡: VBoxContainer, 项: Dictionary, 实例ID: String) -> void:
	var 需境: String = str(项.get("要求境界", "练气"))
	var 需战力: int = int(项.get("要求战力", 0))
	var 可选: Array = []
	for d in Game.弟子列表:
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		if Disciple.境界序.find(d.境界) < Disciple.境界序.find(需境):
			continue
		if int(d.总战力()) < 需战力:
			continue
		var 占: bool = false
		for kk in Game.王朝系统.凡间差事进行中.keys():
			if str((Game.王朝系统.凡间差事进行中[kk] as Dictionary).get("接取弟子ID", "")) == str(d.弟子ID):
				占 = true
				break
		if 占:
			continue
		可选.append(d)
	if 可选.is_empty():
		卡.add_child(_label("（无符合要求的空闲弟子）", false))
	else:
		for d in 可选:
			var 钮: Button = Button.new()
			钮.text = "派 %s（%s·道行%d）" % [str(d.姓名), str(d.境界), int(d.总战力())]
			钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(钮)
			var 弟子ID: String = str(d.弟子ID)
			钮.pressed.connect(func():
				var 果: Dictionary = Game.应对王朝委托_S34(实例ID, "accept", 弟子ID)
				_提示 = ("已领命：%s" % str(果.get("弟子", "?"))) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
				_展开委托 = ""
				refresh()
			)
			卡.add_child(钮)
	var 收: Button = Button.new()
	收.text = "收起"
	收.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(收)
	收.pressed.connect(func():
		_展开委托 = ""
		refresh()
	)
	卡.add_child(收)

# ——— 皇嗣：皇子候选与继承人押注 ———

func _populate_heir() -> void:
	var 头卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "皇嗣　朝代序 %d　在位 %d 月" % [int(Game.王朝系统.王朝.get("朝代序", 1)), int(Game.王朝系统.王朝.get("在位月", 0))]
	UITheme.apply_section_title(头)
	头卡.add_child(头)
	var 押: String = str(Game.王朝系统.王朝.get("押注皇子ID", ""))
	头卡.add_child(_label("国祚跌破 %d（中衰）后朝中方有皇子候选；帝师及以上可押注储君，押中则新帝感念宗门。" % Game.皇子生成国祚线, false))
	var 表: Array = Game.王朝系统.王朝.get("皇子", []) if Game.王朝系统.王朝.get("皇子", null) != null else []
	if 表.is_empty():
		var 空卡: VBoxContainer = _card()
		空卡.add_child(_label("朝中尚无皇子候选。", true))
		空卡.add_child(_label("国祚 %d —— 跌破 %d 后方有储位之争。" % [int(Game.王朝系统.王朝.get("国祚", 100)), Game.皇子生成国祚线], false))
		return
	for it in 表:
		var 子: Dictionary = it as Dictionary
		var 卡: VBoxContainer = _card()
		var 名: Label = Label.new()
		名.text = "%s（%d岁）%s" % [str(子.get("名", "?")), int(子.get("年龄", 0)), "　【已押注】" if str(子.get("ID", "")) == 押 else ""]
		UITheme.apply_section_title(名)
		卡.add_child(名)
		卡.add_child(_label("资质 %d　对宗门 %+d　倾向 %s" % [
				int(子.get("资质", 0)), int(子.get("对宗门", 0)), str(子.get("派系倾向", "—"))], true))
		卡.add_child(_label("竞争力 %d（择储按此权重抽签，非必中）" % int(子.get("竞争力", 0)), false))
		if str(子.get("ID", "")) == 押:
			continue
		var 钮: Button = Button.new()
		钮.text = "押注此人" if 押 == "" else "改押此人（关系-%d）" % Game.改押关系罚
		钮.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(钮)
		var 子ID: String = str(子.get("ID", ""))
		钮.pressed.connect(func():
			var 果: Dictionary = Game.押注继承人_S34(子ID)
			_提示 = ("已押注 %s" % str(果.get("皇子", ""))) if bool(果.get("成功", false)) else str(果.get("原因", "失败"))
			refresh()
		)
		卡.add_child(钮)

# ——— 开国：三条掀桌路线 + 建制六问（S35-1） ———
func _populate_found() -> void:
	var 选项: Dictionary = Game.开国选项_S34()
	var 已自立: bool = bool(Game.王朝系统.王朝.get("自立", false))

	var 卡: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "掀桌开国" if not 已自立 else "新朝已立"
	UITheme.apply_section_title(头)
	卡.add_child(头)
	if 已自立:
		卡.add_child(_label("当前国号「%s」，开国方式：%s，定都%s。"
			% [str(Game.王朝系统.王朝.get("国号", "?")), str(Game.王朝系统.王朝.get("开国方式", "?")),
			str((Game.王朝系统.郡县状态.get(str(Game.王朝系统.王朝.get("都城", "")), {}) as Dictionary).get("名", "?"))], true))
		卡.add_child(_label("再举一次，便是另起新朝——旧朝一切建制都将作废。", false))

	# ① 三条路线
	var 路线卡: VBoxContainer = _card()
	var 头2: Label = Label.new()
	头2.text = "一、取天下之路"
	UITheme.apply_section_title(头2)
	路线卡.add_child(头2)
	for r in (选项.get("路线", []) as Array):
		var 路: Dictionary = r
		var 达成: bool = bool(路.get("达成", false))
		var 缺: Array = 路.get("缺", [])
		var b: Button = Button.new()
		b.text = str(路.get("名", "?"))
		if not 达成:
			b.text = "%s（未达：%s）" % [str(路.get("名", "?")), "、".join(缺)]
		b.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		if str(_开国选.get("路线", "")) == str(路.get("id", "")):
			UITheme.apply_primary_button_style(b)
		else:
			UITheme.apply_secondary_button_style(b)
		b.disabled = not 达成
		b.pressed.connect(_开国_设.bind("路线", str(路.get("id", ""))))
		路线卡.add_child(b)
		路线卡.add_child(_label(str(路.get("说明", "")), false))
		if str(_开国选.get("路线", "")) == str(路.get("id", "")):
			路线卡.add_child(_label("　※ 已择此路", true))

	var 路线id: String = str(_开国选.get("路线", ""))
	if 路线id == "":
		return

	# ② 国号（玩家自打）
	var 号卡: VBoxContainer = _card()
	var 头3: Label = Label.new()
	头3.text = "二、定国号"
	UITheme.apply_section_title(头3)
	号卡.add_child(头3)
	var 输入: LineEdit = LineEdit.new()
	输入.placeholder_text = "自定国号（≤%d 字，留空则由天命拟定）" % Game.王朝系统.开国国号最长
	输入.text = str(_开国选.get("国号", ""))
	输入.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	输入.text_changed.connect(func(新文: String):
		_开国选["国号"] = 新文
	)
	号卡.add_child(输入)

	# ③ 国策（主 + 副）
	var 策卡: VBoxContainer = _card()
	var 头4: Label = Label.new()
	头4.text = "三、定国策（主策全效，副策补益）"
	UITheme.apply_section_title(头4)
	策卡.add_child(头4)
	var 策池: Array = 选项.get("国策", [])
	_开国_选项行(策卡, "主国策", 策池)
	_开国_选项行(策卡, "副国策", 策池)

	# ④ 都城
	var 都卡: VBoxContainer = _card()
	var 头5: Label = Label.new()
	头5.text = "四、定都（都城供奉 ×%.1f）" % Game.王朝系统.开国都城供奉加成
	UITheme.apply_section_title(头5)
	都卡.add_child(头5)
	for c in (选项.get("都城", []) as Array):
		var 城: Dictionary = c
		var 城名: String = "%s（%d级）" % [str(城.get("名", "?")), int(城.get("等级", 1))]
		var bc: Button = Button.new()
		bc.text = 城名
		bc.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		if str(_开国选.get("都城", "")) == str(城.get("id", "")):
			UITheme.apply_primary_button_style(bc)
		else:
			UITheme.apply_secondary_button_style(bc)
		bc.pressed.connect(_开国_设.bind("都城", str(城.get("id", ""))))
		都卡.add_child(bc)

	# ⑤ 官制 / ⑥ 律法 / ⑦ 国教：统一「id|名」选项行
	var 制卡: VBoxContainer = _card()
	var 头6: Label = Label.new()
	头6.text = "五、定官制（苗子与战功之取向）"
	UITheme.apply_section_title(头6)
	制卡.add_child(头6)
	_开国_配置行(制卡, "官制", 选项.get("官制", []))
	var 法卡: VBoxContainer = _card()
	var 头7: Label = Label.new()
	头7.text = "六、定律法（供奉与民心之权衡）"
	UITheme.apply_section_title(头7)
	法卡.add_child(头7)
	_开国_配置行(法卡, "律法", 选项.get("律法", []))
	var 教卡: VBoxContainer = _card()
	var 头8: Label = Label.new()
	头8.text = "七、定国教（S35-2 信仰网络之始）"
	UITheme.apply_section_title(头8)
	教卡.add_child(头8)
	_开国_配置行(教卡, "国教", 选项.get("国教", []))

	# ⑧ 祭天称帝
	var 末卡: VBoxContainer = _card()
	var 缺项: Array = []
	if str(_开国选.get("都城", "")) == "":
		缺项.append("都城")
	for k in ["官制", "律法", "国教"]:
		if str(_开国选.get(k, "")) == "":
			缺项.append(k)
	if 缺项.size() > 0:
		末卡.add_child(_label("尚缺：%s" % "、".join(缺项), false))
	var 祭: Button = Button.new()
	祭.text = "祭天称帝"
	祭.custom_minimum_size = Vector2(0, int(round(40.0 * UITheme.UI_SCALE)))
	if 缺项.size() > 0:
		UITheme.apply_secondary_button_style(祭)
		祭.disabled = true
	else:
		UITheme.apply_primary_button_style(祭)
	祭.pressed.connect(_开国_祭天)
	末卡.add_child(祭)

# 国策（纯字符串池）选项行
func _开国_选项行(父: VBoxContainer, 键: String, 池: Array) -> void:
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID / 2)
	父.add_child(行)
	var 题: Label = Label.new()
	题.text = "主策" if 键 == "主国策" else "副策"
	UITheme.apply_aux_text(题)
	行.add_child(题)
	for p in 池:
		var 策: String = str(p)
		var b: Button = Button.new()
		b.text = 策
		b.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
		if str(_开国选.get(键, "")) == 策:
			UITheme.apply_primary_button_style(b)
		else:
			UITheme.apply_secondary_button_style(b)
		b.pressed.connect(_开国_设.bind(键, 策))
		行.add_child(b)

# 官制/律法/国教（配置字典池）选项行
func _开国_配置行(父: VBoxContainer, 键: String, 池: Array) -> void:
	for r in 池:
		var 项: Dictionary = r
		var b: Button = Button.new()
		b.text = str(项.get("name", "?"))
		b.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
		if str(_开国选.get(键, "")) == str(项.get("id", "")):
			UITheme.apply_primary_button_style(b)
		else:
			UITheme.apply_secondary_button_style(b)
		b.pressed.connect(_开国_设.bind(键, str(项.get("id", ""))))
		父.add_child(b)
		父.add_child(_label("　" + str(项.get("desc", "")), false))

# 统一设值入口：按钮一律 .bind(键, 值)，规避闭包捕获循环变量
func _开国_设(键: String, 值: String) -> void:
	_开国选[键] = 值
	_提示 = ""
	refresh()

func _开国_祭天() -> void:
	var 果: Dictionary = Game.建立新朝_S34(_开国选)
	if bool(果.get("成功", false)):
		_提示 = "新朝「%s」开国，定都%s（%s）。" % [str(果.get("国号", "?")), str(果.get("都城", "?")), str(果.get("方式", "?"))]
		_开国选 = {}
		_cur = "天下"
	else:
		_提示 = str(果.get("原因", "开国失败"))
	refresh()
# ——— 国教：信仰网络（S35-2）———
func _populate_faith() -> void:
	var 览: Dictionary = Game.信仰总览_S34()
	var 概: VBoxContainer = _card()
	var 头: Label = Label.new()
	头.text = "国教信仰网络"
	UITheme.apply_section_title(头)
	概.add_child(头)
	var 教名: String = str(览.get("国教名", ""))
	if 教名 == "":
		教名 = "未立（开国时择定）"
	概.add_child(_label("国教：%s" % 教名, true))
	var 人: int = int(览.get("总人口", 0))
	var 众: int = int(览.get("总信众", 0))
	var 覆: int = int(览.get("总覆盖", 0))
	var 异: int = int(览.get("异端人口", 0))
	var 百: float = 0.0
	if 人 > 0:
		百 = float(众) * 100.0 / float(人)
	概.add_child(_label("信众 %d / 版图 %d 人（%.1f%%）" % [众, 人, 百], true))
	概.add_child(_label("香火庙覆盖 %d 人 ｜ 异端裹挟 %d 人" % [覆, 异], false))
	概.add_child(_label("信仰香火 +%d/日 ｜ 愿力 +%d/月 ｜ 庙宇维护 -%d/日"
				% [int(览.get("香火日产", 0)), int(览.get("愿力月产", 0)), int(览.get("维护香火", 0))], false))
	var 民修: int = int(览.get("民心月修正", 0))
	if 民修 < 0:
		var 红: Label = _label("异端炽盛，月度民心 %d" % 民修, false)
		红.add_theme_color_override("font_color", UITheme.color_value(false))
		概.add_child(红)
	概.add_child(_label("香火庙按郡建造，覆盖人口决定信仰上限——小郡建大庙是浪费，大城不建庙则异端乘虚而入。", false))
	var 郡表: Array = 览.get("郡表", []) as Array
	for 项 in 郡表:
		var d: Dictionary = 项 as Dictionary
		var 卡: VBoxContainer = _card()
		var 头2: Label = Label.new()
		头2.text = "%s（人口 %d）" % [str(d.get("名", "?")), int(d.get("人口", 0))]
		UITheme.apply_section_title(头2)
		卡.add_child(头2)
		卡.add_child(_label("香火庙：%s" % str(d.get("庙名", "无")), true))
		卡.add_child(_label(_信仰条(int(d.get("本宗", 0))), false))
		var 异端: int = int(d.get("异端", 0))
		if 异端 > 0:
			var 主名: String = str(d.get("异端主名", ""))
			if 主名 == "":
				主名 = "未明"
			var 红2: Label = _label("异端 %d%%（%s）" % [异端, 主名], false)
			红2.add_theme_color_override("font_color", UITheme.color_value(false))
			卡.add_child(红2)
		卡.add_child(_label("覆盖 %d / %d 人" % [int(d.get("覆盖", 0)), int(d.get("人口", 0))], false))
		if bool(d.get("建造中", false)):
			卡.add_child(_label("正在建造中……", false))
		elif bool(d.get("欠费", false)):
			var 红3: Label = _label("香火不足，庙宇停摆（不庇佑、不抗异端）", false)
			红3.add_theme_color_override("font_color", UITheme.color_value(false))
			卡.add_child(红3)
		else:
			var 信息: Dictionary = Game.香火庙建造信息(str(d.get("郡ID", "")))
			if bool(信息.get("可建", false)):
				var b: Button = Button.new()
				var 等级: int = int(d.get("庙等级", 0))
				if 等级 <= 0:
					b.text = "动工兴建（%s）" % str(信息.get("名称", ""))
				else:
					b.text = "升级为%s" % str(信息.get("名称", ""))
				b.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
				UITheme.apply_secondary_button_style(b)
				b.pressed.connect(_国教_建庙.bind(str(d.get("郡ID", ""))))
				卡.add_child(b)
				卡.add_child(_label("工费 %d 灵石 ｜ 覆民 %d ｜ 日耗香火 %d ｜ 工期 %d 日"
									% [int(信息.get("工费", 0)), int(信息.get("覆盖人口", 0)),
									int(信息.get("日耗香火", 0)), int(信息.get("时日", 0))], false))
			else:
				卡.add_child(_label(str(信息.get("原因", "无可再建")), false))

# 信仰进度条：字符条，零自定义控件（避免引入未审计的 UI 组件）
func _信仰条(值: int) -> String:
	var 格: int = int(clamp(float(值) / 10.0, 0.0, 10.0))
	var s: String = "本宗 "
	for i in range(格):
		s += "▓"
	for i in range(10 - 格):
		s += "░"
	return s + " %d%%" % 值

func _国教_建庙(郡id: String) -> void:
	var 果: Dictionary = Game.建造香火庙(郡id)
	var 文: String = str(果.get("消息", ""))
	if 文 == "":
		文 = "营建失败"
	_提示 = 文
	refresh()

func _on_tab_pressed(t: String) -> void:
	_cur = t
	_提示 = ""
	_展开差事 = ""
	_展开委托 = ""
	refresh()


# ============ P1-2 奇观建造 ============

func _populate_奇观() -> void:
	var 奇观列表: Array = Game.获取所有奇观列表()
	# 总览统计
	var 已建数: int = 0
	var 建造中数: int = 0
	for w in 奇观列表:
		if bool(w.get("已建造", false)):
			已建数 += 1
		elif bool(w.get("建造中", false)):
			建造中数 += 1
	var 统计卡: VBoxContainer = _card()
	统计卡.add_child(_label("◆ 王朝奇观建造", true))
	统计卡.add_child(_label("推动王朝耗费巨资营建奇观，建成后获得永久加成。当前爵位：%s" % str(Game.王朝系统.王朝.get("宗门爵位", "未册封")), false))
	统计卡.add_child(_label("已建成：%d / %d ｜ 建造中：%d ｜ 宗门灵石：%d" % [已建数, 奇观列表.size(), 建造中数, int(Game.灵石)], false))
	# 奇观总效果
	var 总效果: Dictionary = Game.获取奇观总效果()
	var 效果文: String = "已生效加成："
	var 有效果: bool = false
	if float(总效果.get("修炼加成", 0.0)) > 0:
		效果文 += "修炼+%.0f%% " % (float(总效果["修炼加成"]) * 100)
		有效果 = true
	if float(总效果.get("供奉加成", 0.0)) > 0:
		效果文 += "供奉+%.0f%% " % (float(总效果["供奉加成"]) * 100)
		有效果 = true
	if int(总效果.get("国祚加成", 0)) > 0:
		效果文 += "国祚+%d " % int(总效果["国祚加成"])
		有效果 = true
	if int(总效果.get("气运加成", 0)) > 0:
		效果文 += "气运+%d " % int(总效果["气运加成"])
		有效果 = true
	if float(总效果.get("功德加成", 0.0)) > 0:
		效果文 += "功德+%.0f%% " % (float(总效果["功德加成"]) * 100)
		有效果 = true
	if float(总效果.get("苗子资质加成", 0.0)) > 0:
		效果文 += "苗子资质+%.0f%% " % (float(总效果["苗子资质加成"]) * 100)
		有效果 = true
	if 有效果:
		统计卡.add_child(_label(效果文, false))
	else:
		统计卡.add_child(_label("（暂无已建成奇观，加成未生效）", false))
	# 奇观列表
	for w in 奇观列表:
		var 卡: VBoxContainer = _card()
		var 奇观ID: String = str(w.get("id", ""))
		var 名称: String = str(w.get("名", ""))
		var 描述: String = str(w.get("描述", ""))
		var 成本灵石: int = int(w.get("成本灵石", 0))
		var 建造月数: int = int(w.get("建造月数", 0))
		var 效果: String = str(w.get("效果", ""))
		var 门槛爵位: String = str(w.get("门槛爵位", ""))
		var 已建造: bool = bool(w.get("已建造", false))
		var 建造中: bool = bool(w.get("建造中", false))
		var 已建月: int = int(w.get("已建月", 0))
		var 可建造: bool = bool(w.get("可建造", false))
		# 状态标签
		var 状态文: String = ""
		var 状态颜色: Color = Color(0.7, 0.7, 0.7)
		if 已建造:
			状态文 = "✓ 已建成"
			状态颜色 = Color(0.5, 1.0, 0.5)
		elif 建造中:
			状态文 = "◆ 建造中（%d/%d月）" % [已建月, 建造月数]
			状态颜色 = Color(1.0, 0.85, 0.4)
		elif not 可建造:
			状态文 = "◇ 需%s爵位" % 门槛爵位
			状态颜色 = Color(0.6, 0.6, 0.6)
		else:
			状态文 = "○ 可建造"
			状态颜色 = Color(0.7, 0.9, 1.0)
		var 标题: Label = Label.new()
		标题.text = "%s 【%s】" % [名称, 状态文]
		标题.add_theme_color_override("font_color", 状态颜色)
		UITheme.apply_body_text(标题)
		卡.add_child(标题)
		卡.add_child(_label(描述, false))
		卡.add_child(_label("效果：%s ｜ 成本：%d灵石 ｜ 工期：%d个月 ｜ 门槛：%s" % [效果, 成本灵石, 建造月数, 门槛爵位], false))
		# 建造进度条
		if 建造中:
			var 进度: float = float(w.get("进度", 0.0))
			var 进度条: HBoxContainer = _进度条(int(进度 * 100), 100, "建造进度 %.0f%%（%d/%d月）" % [进度 * 100, 已建月, 建造月数])
			卡.add_child(进度条)
		# 建造按钮
		if 可建造 and not 已建造 and not 建造中:
			var 建造钮: Button = Button.new()
			建造钮.text = "开工建造（消耗%d灵石）" % 成本灵石
			建造钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			UITheme.apply_primary_button_style(建造钮)
			建造钮.pressed.connect(func(): _开始建造奇观(奇观ID))
			卡.add_child(建造钮)
		elif 已建造:
			var 完成标: Label = Label.new()
			完成标.text = "◆ 奇观效果已永久生效"
			完成标.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0))
			卡.add_child(完成标)


func _开始建造奇观(奇观ID: String) -> void:
	var 果: Dictionary = Game.开始建造奇观(奇观ID)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "建造已开工"))
	else:
		_提示 = str(果.get("原因", "建造失败"))
	refresh()


func _on_back_pressed() -> void:
	返回主页.emit()
