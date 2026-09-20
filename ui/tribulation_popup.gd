extends Control

## 天劫渡劫弹窗（全屏暗底模态）
##
## 实例化方式（复用 avatar_select_popup 的 CanvasLayer 模态范式）：
##   CanvasLayer(layer=100) → 容器 Control(FULL_RECT) → 本脚本 Control
## 自包含，无 .tscn 依赖。零玩法逻辑：预览走 Tribulation，结算走 Game.执行弟子渡劫。
##
## 设计要点：
##   - 预览为「确定性」：劫云固定 1.0、心魔关按已渡过计（避免勾选道具时评分乱跳）。
##   - 实际结算走随机（劫云 0.85~1.20 + 心魔关现场抽取），故预览分档仅供决策参考。
##   - 道具为灵石直购（CSV consume_type=灵石），不涉仓库；护阵/护法为免费外力。

signal 渡劫结束(通过: bool)

var _弟子 = null
var _弟子ID: int = -1
var _目标境: String = ""
var _cfg: Dictionary = {}
var _道具勾选: Dictionary = {}
var _用护阵: bool = false
var _用护法: bool = false
var _已结算: bool = false
var _观礼名单列表: VBoxContainer = null   # S46 手动邀请名单动态容器（仅宗主渡劫面板）

var _内容: VBoxContainer = null
var _评分值: Label = null
var _分档值: Label = null
var _消耗值: Label = null


# ============ 外部接口 ============

## 由调用方在 add_child 之前调用
func 配置(d) -> void:
	_弟子 = d
	if d == null:
		return
	_弟子ID = int(d.弟子ID)
	_目标境 = Tribulation.下一境(d.境界)
	_cfg = Tribulation.取天劫配置(_目标境)
	for it in Tribulation.全部道具():
		_道具勾选[str(it.get("item_id", ""))] = false


# ============ 生命周期 ============

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _s(v: float) -> float:
	return v * UITheme.UI_SCALE


func _build() -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.086, 0.125, 0.141, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(panel)
	panel.custom_minimum_size = Vector2(_s(400.0), 0.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	var m: int = int(round(_s(float(UITheme.GRID))))
	margin.add_theme_constant_override("margin_left", m)
	margin.add_theme_constant_override("margin_right", m)
	margin.add_theme_constant_override("margin_top", m)
	margin.add_theme_constant_override("margin_bottom", m)
	panel.add_child(margin)

	# ScrollContainer 内必须挂有布局力的子节点（VBoxContainer），不可直挂普通 Control
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, _s(560.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", int(round(_s(8.0))))
	scroll.add_child(vbox)
	_内容 = vbox

	_build_content()


# ============ 内容构建 ============

func _build_content() -> void:
	if _弟子 == null or _cfg.is_empty():
		_add_center_text("该弟子当前无需渡劫")
		_add_close_row()
		return

	# 标题 / 副标题
	var title: Label = Label.new()
	title.text = "天劫 · %s" % str(_cfg.get("tribulation_name", "未知天劫"))
	UITheme.apply_page_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(title)

	var sub: Label = Label.new()
	sub.text = "%s · %s → %s" % [str(_弟子.姓名), str(_弟子.境界), _目标境]
	UITheme.apply_body_text(sub)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(sub)

	var tip: Label = Label.new()
	tip.text = "劫云强度随机 ±20%，心魔关临场显现，以下评分为期望值"
	UITheme.apply_aux_text(tip)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(tip)

	_内容.add_child(UITheme.make_divider_control())

	# 天劫属性（静态）
	_add_kv("天雷道数", "%d 道" % int(_cfg.get("thunder_count", "0")))
	_add_kv("成功阈值", "%.2f" % float(_cfg.get("success_threshold", "0.0")))
	_add_kv("完美阈值", "%.2f" % float(_cfg.get("perfect_threshold", "0.0")))
	_add_kv("陨落阈值", "%.2f" % float(_cfg.get("death_threshold", "0.0")), true)
	_add_kv("失败跌落", "%d 层" % int(_cfg.get("fail_realm_drop", "1")), true)
	_add_kv("失败重伤", "%d 日" % int(_cfg.get("injury_days", "0")), true)

	_内容.add_child(UITheme.make_divider_control())

	# 准备项
	var pt: Label = Label.new()
	pt.text = "渡劫准备"
	UITheme.apply_section_title(pt)
	_内容.add_child(pt)

	for it in Tribulation.全部道具():
		var iid: String = str(it.get("item_id", ""))
		var cb: CheckBox = CheckBox.new()
		cb.text = "%s · %s（%s）" % [
			str(it.get("item_name", "")), _道具效果文本(it), _道具代价文本(it)]
		UITheme.apply_body_text(cb)
		cb.toggled.connect(func(on: bool) -> void:
			_道具勾选[iid] = on
			_刷新预览()
		)
		_内容.add_child(cb)

	var cb阵: CheckBox = CheckBox.new()
	cb阵.text = "开启护山大阵 · 抗性 +%.0f%%（免费）" % (Game.获取护山大阵抗性() * 100.0)
	UITheme.apply_body_text(cb阵)
	cb阵.disabled = Game.获取护山大阵抗性() <= 0.0
	cb阵.toggled.connect(func(on: bool) -> void:
		_用护阵 = on
		_刷新预览()
	)
	_内容.add_child(cb阵)

	var cb法: CheckBox = CheckBox.new()
	cb法.text = "长老护法 · 抗性 +%.0f%%（免费）" % (Game.获取护法抗性() * 100.0)
	UITheme.apply_body_text(cb法)
	cb法.disabled = Game.获取护法抗性() <= 0.0
	cb法.toggled.connect(func(on: bool) -> void:
		_用护法 = on
		_刷新预览()
	)
	_内容.add_child(cb法)

	# 观礼邀请（仅宗主渡劫可配置；弟子渡劫由系统自动召集）
	if _弟子 == Game.宗主:
		_内容.add_child(UITheme.make_divider_control())
		_build_观礼邀请()

	_内容.add_child(UITheme.make_divider_control())

	# 动态预览
	var pv: Label = Label.new()
	pv.text = "渡劫推演"
	UITheme.apply_section_title(pv)
	_内容.add_child(pv)

	var 评分行: HBoxContainer = HBoxContainer.new()
	var 评分标题: Label = Label.new()
	评分标题.text = "推演评分"
	UITheme.apply_aux_text(评分标题)
	评分标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	评分行.add_child(评分标题)
	_评分值 = Label.new()
	UITheme.apply_value_text(_评分值)
	评分行.add_child(_评分值)
	_内容.add_child(评分行)

	var 分档行: HBoxContainer = HBoxContainer.new()
	var 分档标题: Label = Label.new()
	分档标题.text = "预计结果"
	UITheme.apply_aux_text(分档标题)
	分档标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	分档行.add_child(分档标题)
	_分档值 = Label.new()
	UITheme.apply_value_text(_分档值)
	分档行.add_child(_分档值)
	_内容.add_child(分档行)

	var 消耗行: HBoxContainer = HBoxContainer.new()
	var 消耗标题: Label = Label.new()
	消耗标题.text = "灵石消耗"
	UITheme.apply_aux_text(消耗标题)
	消耗标题.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	消耗行.add_child(消耗标题)
	_消耗值 = Label.new()
	UITheme.apply_value_text(_消耗值)
	消耗行.add_child(_消耗值)
	_内容.add_child(消耗行)

	_内容.add_child(UITheme.make_divider_control())

	# 操作行
	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(round(_s(8.0))))
	var 开始: Button = Button.new()
	开始.text = "开始渡劫"
	开始.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_primary_button_style(开始)
	开始.pressed.connect(_on_开始渡劫)
	hb.add_child(开始)
	var 关闭: Button = Button.new()
	关闭.text = "关闭"
	关闭.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(关闭)
	关闭.pressed.connect(_关闭)
	hb.add_child(关闭)
	_内容.add_child(hb)

	_刷新预览()


# ============ 预览 ============

## 当前勾选对应的准备项
func _当前准备() -> Dictionary:
	var 道具列表: Array = []
	for k in _道具勾选.keys():
		if bool(_道具勾选[k]):
			道具列表.append(k)
	var 汇总: Dictionary = Tribulation.汇总道具(道具列表)
	return {
		"护阵抗性": Game.获取护山大阵抗性() if _用护阵 else 0.0,
		"护法抗性": Game.获取护法抗性() if _用护法 else 0.0,
		"道具减伤": float(汇总["减伤"]),
		"承伤倍率": 1.0 + float(汇总["成功率加成"]),
	}


## 确定性预览：劫云固定 1.0、心魔关按已渡过计（避免勾选时评分乱跳）
func _预览() -> Dictionary:
	if _弟子 == null:
		return {}
	var 准备: Dictionary = _当前准备()
	准备["劫云"] = 1.0
	准备["心魔"] = {"成功": true}
	return Tribulation.计算渡劫结果(_弟子, 准备)


func _刷新预览() -> void:
	if _评分值 == null or _弟子 == null:
		return
	var 预: Dictionary = _预览()
	if 预.is_empty():
		return
	var 评: float = float(预.get("评分", 0.0))
	_评分值.text = "%.3f" % 评
	_分档值.text = str(预.get("结果", "—"))
	var 汇总: Dictionary = Tribulation.汇总道具(_已勾道具())
	var 石: int = int(汇总["灵石"])
	_消耗值.text = "%s / 持有 %s" % [UITheme.format_resource(石), UITheme.format_resource(int(Game.灵石))]
	var 不足: bool = 石 > int(Game.灵石)
	UITheme.apply_value_text(_消耗值, 不足)


func _已勾道具() -> Array:
	var out: Array = []
	for k in _道具勾选.keys():
		if bool(_道具勾选[k]):
			out.append(k)
	return out


# ============ 结算 ============

func _on_开始渡劫() -> void:
	if _已结算 or _弟子 == null:
		return
	var r: Dictionary = Game.执行弟子渡劫(_弟子ID, _已勾道具(), _用护阵, _用护法)
	if not r.has("结果"):
		# 前置校验未过（非渡劫结果），提示原因并保持面板
		Game.添加提示(str(r.get("原因", "无法渡劫")))
		return
	_已结算 = true
	_显示结果(r)


func _显示结果(r: Dictionary) -> void:
	for c in _内容.get_children():
		_内容.remove_child(c)
		c.queue_free()

	var 结: String = str(r.get("结果", "重伤"))
	var title: Label = Label.new()
	title.text = "渡劫%s" % ("成功" if 结 in ["完美", "成功"] else "失败")
	UITheme.apply_page_title(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(title)

	var 结行: Label = Label.new()
	结行.text = "%s · %s" % [str(r.get("天劫名", "")), 结]
	UITheme.apply_section_title(结行)
	结行.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(结行)

	_内容.add_child(UITheme.make_divider_control())

	_add_kv("渡劫评分", "%.3f" % float(r.get("评分", 0.0)))
	_add_kv("天劫强度", UITheme.format_resource(int(r.get("天劫强度", 0))))
	_add_kv("弟子承伤", UITheme.format_resource(int(r.get("承伤池", 0))))
	_add_kv("劫云强度", "%.2f" % float(r.get("劫云", 1.0)))
	var 抗: Dictionary = r.get("抗性", {})
	_add_kv("总抗性", "%.0f%%" % (float(抗.get("总", 0.0)) * 100.0))

	var 心魔: Dictionary = r.get("心魔", {})
	if not 心魔.is_empty():
		_内容.add_child(UITheme.make_divider_control())
		_add_kv("心魔关", str(心魔.get("心魔名", "心魔")))
		_add_kv("心境抉择", "%s（%s）" % [
			str(心魔.get("描述", "")), "渡过" if bool(心魔.get("成功", false)) else "失守"])
		var 奖惩: Dictionary = 心魔.get("奖惩", {})
		if not 奖惩.is_empty():
			_add_kv("心魔影响", str(心魔.get("奖惩原文", "")))

	_内容.add_child(UITheme.make_divider_control())
	match 结:
		"完美":
			_add_kv("结果", "完美渡劫，晋 %s" % _目标境)
			_add_kv("声望", "+%d" % int(round(float(r.get("声望", 0)) * 1.5)))
			_add_kv("道心", "+10")
			if str(r.get("完美奖励", "")) != "":
				_add_kv("完美奖励", "已记入待领")
		"成功":
			_add_kv("结果", "渡过天劫，晋 %s" % _目标境)
			_add_kv("声望", "+%d" % int(r.get("声望", 0)))
		"重伤":
			_add_kv("结果", "雷劫难承，跌落 %d 层" % int(r.get("跌落层数", 1)), true)
			_add_kv("重伤", "%d 日（养伤期间不可突破）" % int(r.get("受伤天数", 0)), true)
		_:
			_add_kv("结果", "形神俱灭，陨落于 %s 之下" % str(r.get("天劫名", "天劫")), true)

	_add_close_row()
	渡劫结束.emit(结 in ["完美", "成功"])


# ============ 组件 ============

func _add_kv(caption: String, value: String, abnormal: bool = false) -> void:
	var hb: HBoxContainer = HBoxContainer.new()
	var c: Label = Label.new()
	c.text = caption
	UITheme.apply_aux_text(c)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(c)
	var v: Label = Label.new()
	v.text = value
	UITheme.apply_value_text(v, abnormal)
	hb.add_child(v)
	_内容.add_child(hb)


func _add_center_text(文本: String) -> void:
	var l: Label = Label.new()
	l.text = 文本
	UITheme.apply_body_text(l)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_内容.add_child(l)


func _add_close_row() -> void:
	var 关闭: Button = Button.new()
	关闭.text = "关闭"
	关闭.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_secondary_button_style(关闭)
	关闭.pressed.connect(_关闭)
	_内容.add_child(关闭)


func _道具效果文本(it: Dictionary) -> String:
	var 率: float = float(it.get("success_rate_bonus", "0"))
	var 减: float = float(it.get("damage_reduce", "0"))
	var 段: Array = []
	if 率 > 0.0:
		段.append("承伤 +%.0f%%" % (率 * 100.0))
	if 减 > 0.0:
		段.append("减伤 %.0f%%" % (减 * 100.0))
	if 段.is_empty():
		return "无加成"
	return " / ".join(段)


func _道具代价文本(it: Dictionary) -> String:
	var 价: int = int(it.get("consume_cost", "0"))
	if 价 <= 0:
		return "免费"
	return "%s 灵石" % UITheme.format_resource(价)


# ============ S46 观礼邀请配置（仅宗主渡劫）============

func _build_观礼邀请() -> void:
	var cfg: Dictionary = Game.宗主观礼配置
	var st: Label = Label.new()
	st.text = "观礼邀请"
	UITheme.apply_section_title(st)
	_内容.add_child(st)

	var tip: Label = Label.new()
	tip.text = "宗主渡劫可邀观礼，观礼者得感悟；若渡劫受创/陨落，观礼者受雷劫余波"
	UITheme.apply_aux_text(tip)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_内容.add_child(tip)

	# 四档范围开关
	var 开关项: Array = [
		["本宗人员", "本宗在籍弟子"],
		["道友道侣", "宗主道友与道侣"],
		["友好阵营", "友好宗门代表（外部宾）"],
		["同盟阵营", "同盟宗门代表（外部宾）"],
	]
	for 项 in 开关项:
		var 键: String = String(项[0])
		var cb: CheckBox = CheckBox.new()
		cb.text = "%s · %s" % [键, String(项[1])]
		UITheme.apply_body_text(cb)
		cb.button_pressed = bool(cfg.get(键, true))
		cb.toggled.connect(func(on: bool, k: String = 键) -> void:
			Game.宗主观礼配置[k] = on
		)
		_内容.add_child(cb)

	# 手动邀请（本宗弟子ID → 观礼名单；他方/其他玩家名号 → 外部宾）
	var 名标题: Label = Label.new()
	名标题.text = "手动邀请（弟子ID 或 他方/其他玩家名号）"
	UITheme.apply_aux_text(名标题)
	_内容.add_child(名标题)

	var hb: HBoxContainer = HBoxContainer.new()
	hb.add_theme_constant_override("separation", int(round(_s(8.0))))
	var 输入: LineEdit = LineEdit.new()
	输入.placeholder_text = "输入弟子ID或名号后点添加"
	输入.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_body_text(输入)
	hb.add_child(输入)
	var 添加: Button = Button.new()
	添加.text = "添加"
	UITheme.apply_secondary_button_style(添加)
	添加.pressed.connect(func() -> void:
		_添加观礼条目(输入)
	)
	hb.add_child(添加)
	_内容.add_child(hb)

	_观礼名单列表 = VBoxContainer.new()
	_观礼名单列表.add_theme_constant_override("separation", int(round(_s(4.0))))
	_内容.add_child(_观礼名单列表)
	_刷新观礼名单()


func _刷新观礼名单() -> void:
	if _观礼名单列表 == null:
		return
	for c in _观礼名单列表.get_children():
		_观礼名单列表.remove_child(c)
		c.queue_free()
	var 名单: Array = Game.宗主观礼配置.get("手动名单", [])
	if 名单.is_empty():
		var 空: Label = Label.new()
		空.text = "（暂无手动邀请）"
		UITheme.apply_aux_text(空)
		_观礼名单列表.add_child(空)
		return
	for 条目 in 名单:
		var row: HBoxContainer = HBoxContainer.new()
		var 标记: String = "本宗弟子" if (条目 is int) else "他方/其他玩家"
		var 文: Label = Label.new()
		文.text = "%s · %s" % [str(条目), 标记]
		UITheme.apply_body_text(文)
		文.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(文)
		var 移除: Button = Button.new()
		移除.text = "移除"
		移除.custom_minimum_size = Vector2(_s(56.0), 0.0)
		UITheme.apply_secondary_button_style(移除)
		移除.pressed.connect(func(项 = 条目) -> void:
			_移除观礼条目(项)
		)
		row.add_child(移除)
		_观礼名单列表.add_child(row)


func _添加观礼条目(输入: LineEdit) -> void:
	var 文本: String = String(输入.text).strip_edges()
	if 文本 == "":
		return
	var 名单: Array = Game.宗主观礼配置.get("手动名单", [])
	if 文本.is_valid_int():
		var id: int = int(文本)
		if Game._取弟子(id) == null:
			Game.添加提示("无此弟子ID：%s" % 文本)
			return
		if 名单.has(id):
			Game.添加提示("已在名单：%s" % 文本)
			return
		名单.append(id)
	else:
		if 名单.has(文本):
			Game.添加提示("已在名单：%s" % 文本)
			return
		名单.append(文本)
	Game.宗主观礼配置["手动名单"] = 名单
	输入.text = ""
	_刷新观礼名单()


func _移除观礼条目(条目) -> void:
	var 名单: Array = Game.宗主观礼配置.get("手动名单", [])
	var idx: int = 名单.find(条目)
	if idx >= 0:
		名单.remove_at(idx)
	Game.宗主观礼配置["手动名单"] = 名单
	_刷新观礼名单()


func _关闭() -> void:
	var p: Node = get_parent()
	if p != null and p.get_parent() is CanvasLayer:
		p.get_parent().queue_free()
		return
	queue_free()
