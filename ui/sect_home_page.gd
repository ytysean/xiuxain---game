extends Control

# 宗门页骨架（导航骨架 C）。组合：经营概览占位(§2.2 120dp) + CoreActionGrid(240dp)
# + 可滚动次功能区（3 个 CollapsibleCategory + 御兽通用占位槽）。
# 本骨架仅搭建结构并发信号，不连玩法。

const CoreActionGridScene: PackedScene = preload("res://ui/core_action_grid.tscn")
const CollapsibleScene: PackedScene = preload("res://ui/collapsible_category.tscn")

const CATEGORIES: Array = ["凡世香火", "宗门规制", "道统传承"]

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

	# 经营概览面板占位（§2.2, 120dp）— 内容由 design-strategist 填充，本骨架仅占位，不连玩法
	var overview := PanelContainer.new()
	overview.name = "OverviewPlaceholder"
	overview.custom_minimum_size = Vector2(0, UITheme.OVERVIEW_H)
	UITheme.apply_panel_style(overview)
	var ov_label := Label.new()
	ov_label.text = "经营概览（占位 · §2.2）"
	ov_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_font(ov_label)
	overview.add_child(ov_label)
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
