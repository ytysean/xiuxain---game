extends Node
## ─────────────────────────────────────────────────────────────
## 只读探针：定案 UITheme._入树_包边距（把 VBox/HBox/Grid 上的无效 margin 宿主
## 原地包进 MarginContainer = "MarginWrap"）在实机到底触不触发。
## 目的：裁决「margin 失效族=幻影族」普查（钩子生效）与美术侧帧实证的冲突。
## 纪律：不改任何产品代码；仅新增本文件 + 同名 .tscn。
## 运行：godot --headless --path <项目> --scene res://tests/_probe_margin_hook.tscn
## ─────────────────────────────────────────────────────────────

const PAGE_EXPLORE := "res://ui/page_explore.gd"
const PAGE_SECT_MGR := "res://ui/page_sect_manager.gd"

func _ready() -> void:
	_看门狗()
	await _跑()

func _看门狗() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(8.0)
	t.timeout.connect(_超时退出)

func _超时退出() -> void:
	printerr("WATCHDOG 超时，强制退出")
	get_tree().quit()

func _跑() -> void:
	prints(">>> PROBE_BEGIN")
	var ut: Node = get_node_or_null("/root/UITheme")
	prints(">>> UITheme autoload 存在=", ut != null)
	if ut != null:
		prints(">>> node_added->_on_节点入树 已连接=", get_tree().node_added.is_connected(Callable(ut, "_on_节点入树")))

	print("----- (A) 合成最小复现 -----")
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "SYNTH"
	v.add_theme_constant_override("margin_left", 24)
	v.add_theme_constant_override("margin_right", 24)
	add_child(v)
	await get_tree().process_frame
	await get_tree().process_frame
	var ap: Node = v.get_parent()
	prints("A parent=", ap.name, " class=", ap.get_class())
	prints("A vbox_rect=", v.get_global_rect())
	if ap is Control:
		prints("A wrap_rect=", (ap as Control).get_global_rect())
	prints("A 钩子生效=", ap.name == "MarginWrap")

	print("----- (B) page_explore 直接 add_child -----")
	var page: Control = load(PAGE_EXPLORE).new()
	add_child(page)
	await get_tree().process_frame
	await get_tree().process_frame
	prints("B page.size=", page.size, " page_rect=", page.get_global_rect())
	_报(page, "B")

	print("----- (B2) page_explore 宿主 480x854 x UI_SCALE -----")
	var host: Control = Control.new()
	host.name = "LOGICAL_HOST"
	host.size = Vector2(480.0, 854.0)
	host.scale = Vector2(UITheme.UI_SCALE, UITheme.UI_SCALE)
	add_child(host)
	var page2: Control = load(PAGE_EXPLORE).new()
	host.add_child(page2)
	await get_tree().process_frame
	await get_tree().process_frame
	prints("B2 page.size=", page2.size, " page_rect=", page2.get_global_rect())
	_报(page2, "B2")

	print("----- (C) page_sect_manager 裸键 margin -----")
	var p2: Control = load(PAGE_SECT_MGR).new()
	add_child(p2)
	await get_tree().process_frame
	await get_tree().process_frame
	prints("C page.size=", p2.size)
	_报(p2, "C")
	var 命名VBox: Array = []
	_找名(p2, "VBox", 命名VBox)
	prints("C 命名 VBox 数=", 命名VBox.size())
	for vv in 命名VBox:
		var 父: Node = (vv as Node).get_parent()
		prints("   VBox(", (vv as Node).name, ") parent=", 父.name, " class=", 父.get_class(),
			" 有裸margin键=", (vv as Control).has_theme_constant_override("margin"))

	prints(">>> PROBE_END")
	get_tree().quit()

func _报(root: Node, 标签: String) -> void:
	var 包s: Array = []
	_找名(root, "MarginWrap", 包s)
	prints(标签, " MarginWrap 数=", 包s.size())
	for w in 包s:
		var wc: Control = w
		prints("   MarginWrap rect=", wc.get_global_rect(), " 子数=", wc.get_child_count())
		for ch in wc.get_children():
			if ch is Control:
				prints("      child=", ch.name, " rect=", (ch as Control).get_global_rect(), " x=", (ch as Control).get_global_rect().position.x)
	var 宿: Control = _找宿(root)
	if 宿 != null:
		prints(标签, " 边距宿主 name=", 宿.name, " x=", 宿.get_global_rect().position.x, " parent=", 宿.get_parent().name)
	else:
		prints(标签, " 边距宿主=NOT FOUND")

func _找名(n: Node, 名: String, 出: Array) -> void:
	if String(n.name) == 名:
		出.append(n)
	for c in n.get_children():
		_找名(c, 名, 出)

func _找宿(n: Node) -> Control:
	if n is Control:
		var c: Control = n
		if c is VBoxContainer or c is HBoxContainer or c is GridContainer:
			if (c.has_theme_constant_override("margin_left") or c.has_theme_constant_override("margin_right")
					or c.has_theme_constant_override("margin_top") or c.has_theme_constant_override("margin_bottom")):
				return c
	for ch in n.get_children():
		var r: Control = _找宿(ch)
		if r != null:
			return r
	return null
