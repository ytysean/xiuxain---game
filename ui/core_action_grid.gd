extends Control

# 核心操作宫格（§7.2：上排3大按钮 建筑/坊市/修炼 + 下排3小按钮 洞府/任务/账册）。
# 每个按钮发信号 action_requested(action_id)；仅发信号，不连玩法。

signal action_requested(action_id: String)

const ActionButtonScene: PackedScene = preload("res://ui/action_button.tscn")

const BIG_ACTIONS: Array = ["建筑", "坊市", "修炼"]
const SMALL_ACTIONS: Array = ["洞府", "任务", "账册"]

func _ready() -> void:
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(0, UITheme.CORE_GRID_H)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top := HBoxContainer.new()
	top.name = "TopRow"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", UITheme.GRID + 4)
	top.add_theme_constant_override("alignment", BoxContainer.ALIGNMENT_CENTER)
	vbox.add_child(top)

	var bottom := HBoxContainer.new()
	bottom.name = "BottomRow"
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_theme_constant_override("separation", UITheme.GRID + 4)
	bottom.add_theme_constant_override("alignment", BoxContainer.ALIGNMENT_CENTER)
	vbox.add_child(bottom)

	for id in BIG_ACTIONS:
		top.add_child(_make_action(id, true))
	for id in SMALL_ACTIONS:
		bottom.add_child(_make_action(id, false))

func _make_action(id: String, big: bool) -> Control:
	var b := ActionButtonScene.instantiate() as Control
	b.action_id = id
	b.label_text = id
	b.big = big
	b.pressed.connect(_on_action_pressed)
	return b

func _on_action_pressed(action_id: String) -> void:
	action_requested.emit(action_id)
