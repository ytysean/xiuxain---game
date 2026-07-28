extends Control

# 宗门页骨架（导航骨架 C）。组合：经营概览占位(§2.2 120dp) + CoreActionGrid(240dp)
# + 可滚动次功能区（3 个 CollapsibleCategory + 御兽通用占位槽）。
# 本骨架仅搭建结构并发信号，不连玩法。

const CoreActionGridScene: PackedScene = preload("res://ui/core_action_grid.tscn")
const CollapsibleScene: PackedScene = preload("res://ui/collapsible_category.tscn")

const CATEGORIES: Array = ["凡世香火", "宗门规制", "道统传承"]

# 经营概览状态标签阈值（UI 层临时占位；待玩法侧确认后改读 Game.在岗预警阈值）
const UI_在岗预警阈值: int = 3

var _status_label: Label
var _metric_values: Dictionary = {}
var _metric_trends: Dictionary = {}

func _ready() -> void:
	_build()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 经营概览面板（§2.2, 120dp）：4 字段 + 右上角状态标签；数据只读 Game，不连玩法。
	var overview := PanelContainer.new()
	overview.name = "OverviewPlaceholder"
	overview.custom_minimum_size = Vector2(0, UITheme.OVERVIEW_H)
	UITheme.apply_panel_style(overview)
	_build_overview_content(overview)
	vbox.add_child(overview)

	# 核心操作宫格
	var grid := CoreActionGridScene.instantiate() as Control
	grid.name = "CoreActionGrid"
	grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(grid)

	# 次功能滚动区
	var scroll := ScrollContainer.new()
	scroll.name = "SecondaryArea"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", UITheme.GRID * 2)
	scroll.add_child(inner)

	for cat in CATEGORIES:
		var c := CollapsibleScene.instantiate() as Control
		c.title_text = cat
		c.collapsed_by_default = true
		inner.add_child(c)

	# 非宫格模块通用占位槽（如御兽）
	var beast_slot := PanelContainer.new()
	beast_slot.name = "BeastSlot"
	beast_slot.custom_minimum_size = Vector2(0, UITheme.SIZE_LG)
	UITheme.apply_panel_style(beast_slot)
	var bs_label := Label.new()
	bs_label.text = "御兽（通用占位槽 · 非宫格模块）"
	bs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_font(bs_label)
	beast_slot.add_child(bs_label)
	inner.add_child(beast_slot)

# ───────── 经营概览面板（§2.2）─────────
# 字段契约（只读 Game autoload；缺失即占位「—」，并预留信号待玩法侧补齐）：
#   月产出   <- Game.预估月产出()        （已落地）
#   繁荣度   <- Game.繁荣                （已落地）
#   在岗弟子 <- Game.弟子列表.size()       （已落地；在岗 = 在册弟子数）
#   月消耗   <- Game.月消耗 / 预估月消耗()（玩法侧暂未暴露公开访问器 → 占位，预留信号）
#   环比趋势 <- Game.上月产出             （玩法侧暂未暴露上月快照 → 中性「—」，预留信号）
# 异常着色：数值为负 / 入不敷出 / 人手不足 → 暗红（UITheme.color_value(abnormal)）。
func _build_overview_content(p: PanelContainer) -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", UITheme.GRID)
	p.add_child(content)

	# 头部：标题（左）+ 状态标签（右上）
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", UITheme.GRID)
	content.add_child(header)

	var title := Label.new()
	title.name = "Title"
	title.text = "经营概览"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	UITheme.apply_title_font(title)
	header.add_child(title)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "宗门安定"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_aux_font(_status_label)
	header.add_child(_status_label)

	# 指标行：4 列（月产出 / 月消耗 / 在岗弟子 / 繁荣度）
	var metrics := HBoxContainer.new()
	metrics.name = "Metrics"
	metrics.size_flags_vertical = Control.SIZE_EXPAND_FILL
	metrics.add_theme_constant_override("separation", UITheme.GRID)
	content.add_child(metrics)

	var specs: Array = [{"key": "月产出"}, {"key": "月消耗"}, {"key": "在岗弟子"}, {"key": "繁荣度"}]
	for s in specs:
		var key: String = s["key"]
		var cell := VBoxContainer.new()
		cell.name = "Cell_" + key
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		metrics.add_child(cell)

		var cap := Label.new()
		cap.name = "Caption"
		cap.text = key
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_font(cap)
		cell.add_child(cap)

		var row := HBoxContainer.new()
		row.name = "ValueRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 2)
		cell.add_child(row)

		var val := Label.new()
		val.name = "Value"
		val.text = "—"
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_value_font(val, false)
		row.add_child(val)

		var trend := Label.new()
		trend.name = "Trend"
		trend.text = ""
		trend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_aux_font(trend)
		row.add_child(trend)

		_metric_values[key] = val
		_metric_trends[key] = trend

	# 首屏拉取一次（只读 Game）；推演后由 main / 周期结算调用 refresh_overview() 刷新（信号预留）。
	refresh_overview()

# 经营概览数据刷新：只读 Game，绝不写玩法逻辑。
func refresh_overview() -> void:
	if not is_instance_valid(Game):
		return
	# 月产出（真实）
	var 产出: int = 0
	if Game.has_method("预估月产出"):
		产出 = Game.预估月产出()
	_set_metric("月产出", str(产出), 产出 < 0)
	# 环比趋势（中性占位，待 Game.上月产出）
	var 上月 = Game.get("上月产出")
	if 上月 != null and (typeof(上月) == TYPE_INT or typeof(上月) == TYPE_FLOAT):
		if 上月 < 产出:
			_set_trend("月产出", "↑")
		elif 上月 > 产出:
			_set_trend("月产出", "↓")
		else:
			_set_trend("月产出", "—")
	else:
		_set_trend("月产出", "—")
	# 月消耗（预留，占位）
	var 消耗 = Game.get("月消耗")
	if 消耗 == null:
		消耗 = Game.get("预估月消耗")
	var 消耗值: int = -1
	var 消耗异常: bool = false
	if 消耗 != null and (typeof(消耗) == TYPE_INT or typeof(消耗) == TYPE_FLOAT):
		消耗值 = int(消耗)
		消耗异常 = 消耗值 < 0
		if 消耗值 < 0:
			消耗值 = -1
	_set_metric("月消耗", "—" if 消耗值 < 0 else str(消耗值), 消耗异常)
	# 在岗弟子（真实，在册弟子数）
	var 在岗: int = Game.弟子列表.size()
	_set_metric("在岗弟子", str(在岗), false)
	# 繁荣度（真实）
	var 繁荣: int = Game.繁荣
	_set_metric("繁荣度", str(繁荣), 繁荣 < 0)
	# 状态标签
	_update_status(产出, 消耗值, 在岗)

func _set_metric(key: String, text: String, abnormal: bool) -> void:
	var lbl: Label = _metric_values.get(key, null)
	if lbl == null:
		return
	lbl.text = text
	UITheme.apply_value_font(lbl, abnormal)

func _set_trend(key: String, arrow: String) -> void:
	var lbl: Label = _metric_trends.get(key, null)
	if lbl == null:
		return
	lbl.text = arrow
	UITheme.apply_aux_font(lbl)

# 状态标签优先级：入不敷出 > 人手不足 > 安定
func _update_status(产出: int, 消耗值: int, 在岗: int) -> void:
	if _status_label == null:
		return
	UITheme.apply_aux_font(_status_label)
	var col: Color = UITheme.COLOR_TEXT_GOLD
	var txt: String = "宗门安定"
	if 消耗值 >= 0 and 产出 < 消耗值:
		col = UITheme.COLOR_TEXT_RED
		txt = "财政吃紧"
	else:
		var 阈值 = Game.get("在岗预警阈值")
		if 阈值 == null:
			阈值 = UI_在岗预警阈值
		if 在岗 < int(阈值):
			col = UITheme.COLOR_TEXT_RED
			txt = "人手短缺"
	_status_label.text = txt
	_status_label.add_theme_color_override("font_color", col)
