extends Node
# owner: engineering-lead
## ────────────────────────────────────────────────────────────────────────────
## P0 契约 · **真钩子入树版**探针（长期保留 · 端到端护栏）· tests/_probe_p0_wrap_in_tree.gd
##
## 与同目录 `_probe_p0_vbox_contract.gd`（**模拟**包裹）互补：
##   模拟版证明「包裹本身会破直系按名契约」；
##   本版走**真入树路径** —— 把带 margin_* override 的 VBoxContainer 宿主挂进场景树，
##   令 ui_theme.gd 自动加载的 `_入树_包边距`（:2053）/ `_包边距_延迟`（:2067-2104）
##   **真的**把它原地包进 MarginContainer ⇒ 端到端证明「生产钩子确实会破该契约」。
##
## 四条必断 + 正控制：
##   1（拓扑）  包裹后 card 的直系子 = MarginWrap（**独立观测「钩子真跑了」**）
##   2（断）    post `card.get_node_or_null("VBox")` == null
##   3（通）    post `card.find_child("VBox", true, false)` == vb（**同一 object 引用**）
##   4（层数）  vb -> MarginWrap -> card（**包裹层数恰为 1**；护 has_meta 终止守卫被删致多重包裹）
##   CTRL（正控制） post `card.find_child("VBox", true, true)` == null（owned-false 承重）
##
## 纪律：不改任何产品代码；仅新增本文件 + 同名 .tscn。
##   输出载荷一律 ASCII（中文只留源码注释）—— 防日志 mojibake 致下游脚本不可读。
## 运行：godot --headless --path <项目> --scene res://tests/_probe_p0_wrap_in_tree.tscn
## 输出：`P0WRAP <n> OK|FAIL <ascii>` / `P0WRAP CTRL ...` / `P0WRAP_DONE n_ok=<n> n_fail=<n> gate=<bool>`
## 退出码：gate = (n_ok >= 3 and n_fail == 0)；gate 假 ⇒ exit 1（防断言失败静默吞＝假绿）
## 自清：跑完 remove_child + free 卡片 + quit，不留 orphan。
##
## gate_all / 门3 死函数水位豁免：自定义函数一律 `_test_` 前缀（DFUNC_KEEP_PREFIX 含 "_test_"）。
## ────────────────────────────────────────────────────────────────────────────

const 看门狗秒: float = 6.0
var _ok: int = 0
var _fail: int = 0

func _ready() -> void:
	_test_看门狗()
	await _test_跑()

func _test_看门狗() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(看门狗秒)
	t.timeout.connect(_test_超时退出)

func _test_超时退出() -> void:
	printerr("P0WRAP WATCHDOG timeout, force quit")
	get_tree().quit(1)

func _test_跑() -> void:
	prints(">>> P0WRAP_BEGIN")
	var ut: Node = get_node_or_null("/root/UITheme")
	prints("P0WRAP autoload_UITheme=" + str(ut != null))

	# 宿主卡片：与 page_sect_manager.gd:_make_card 同构（PanelContainer > VBox(name="VBox")，VBox 带 margin override）
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	var vb: VBoxContainer = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("margin_left", 12)
	vb.add_theme_constant_override("margin_right", 12)
	vb.add_theme_constant_override("margin_top", 12)
	vb.add_theme_constant_override("margin_bottom", 12)
	card.add_child(vb)

	# 入树：触发 node_added -> _入树_包边距 -> _包边距_延迟（call_deferred）
	add_child(card)
	await get_tree().process_frame
	await get_tree().process_frame

	# 断 1（拓扑）：card 直系子已由 VBox 变 MarginWrap
	var wrap: Node = card.get_node_or_null("MarginWrap")
	_test_断言(1, wrap != null and vb.get_parent() != null and String(vb.get_parent().name) == "MarginWrap",
		"wrap topology: card children = " + _test_子名(card))

	# 断 2（断）：直系按名查找已失配
	var got: Node = card.get_node_or_null("VBox")
	_test_断言(2, got == null,
		"post get_node_or_null(VBox) -> " + _test_名(got))

	# 断 3（通）：递归按名命中**同一 object**
	var f: Node = card.find_child("VBox", true, false)
	_test_断言(3, f != null and f == vb and is_same(f, vb),
		"post find_child(true,false) id=" + str(_test_id(f)) + " == vb id=" + str(_test_id(vb)))

	# 断 4（层数恰为 1）：vb -> MarginWrap -> card（护 has_meta 终止守卫被删致多重包裹）
	var gp: Node = vb.get_parent()
	_test_断言(4, gp != null and gp.get_parent() == card and String(gp.name) == "MarginWrap",
		"wrap depth: vb.parent=" + _test_名(gp) + " parent.parent=" + _test_名(gp.get_parent() if gp != null else null) + " == card")

	# CTRL 正控制：owned=true 仍 null
	var fo: Node = card.find_child("VBox", true, true)
	_test_配套("CTRL", fo == null,
		"post find_child(true,true) -> " + _test_名(fo))

	var gate: bool = _ok >= 3 and _fail == 0
	prints("P0WRAP_DONE n_ok=" + str(_ok) + " n_fail=" + str(_fail) + " gate=" + str(gate))

	# 自清
	remove_child(card)
	card.free()
	prints(">>> P0WRAP_END")
	# 单一 quit()（Godot 4 的 quit(exit_code) 会覆盖 exit_code；双调用会把失败退 0 ⇒ 必须二选一）
	if gate:
		get_tree().quit()
	else:
		get_tree().quit(1)

func _test_断言(n: int, cond: bool, detail: String) -> void:
	if cond:
		_ok += 1
		prints("P0WRAP", n, "OK", detail)
	else:
		_fail += 1
		prints("P0WRAP", n, "FAIL", detail)

func _test_配套(tag: String, cond: bool, detail: String) -> void:
	if cond:
		prints("P0WRAP", tag, "OK", detail)
	else:
		_fail += 1
		prints("P0WRAP", tag, "FAIL", detail)

func _test_名(n: Node) -> String:
	if n == null:
		return "<null>"
	return String(n.name)

func _test_id(n: Node) -> int:
	if n == null:
		return -1
	return int(n.get_instance_id())

func _test_子名(n: Node) -> String:
	var a: Array = []
	for c in n.get_children():
		a.append(String(c.name))
	return "[" + ", ".join(a) + "]"
