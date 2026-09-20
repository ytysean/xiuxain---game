extends Node
# owner: engineering-lead
## ────────────────────────────────────────────────────────────────────────────
## P0 契约微探针（长期保留 · 契约回归护栏）· tests/_probe_p0_vbox_contract.gd
##
## 目的：以**最小确定复现**固定一条 UI 契约：
##   ui_theme.gd `_包边距_延迟`（:2067-2104）会把「带 margin_* override 的
##   VBox/HBox/Grid 宿主」**原地**包进一个 MarginContainer(name="MarginWrap")，
##   于是该宿主的**直系父不再直接持有它**（深度 +1、直系子由 宿主 → MarginWrap）。
##   ⇒ 按名/按路径的**直系**查找契约被破坏：
##        wrap 前  `card.get_node("VBox")`                              命中
##        wrap 后  `card.get_node("VBox")` / `get_node_or_null("VBox")` 断（null）
##        wrap 后  `card.find_child("VBox", true, false)`               命中（递归、深度无关）
##        正控制   `card.find_child("VBox", true, true)`                仍 null（owned=true 只匹配
##          「有 owner」的节点；本卡片 VBox 由代码 new + add_child 生成，owner=null）
##
## 为何需要它：PH7-VIS-FIX 丙-b-P0 把 page_sect_manager.gd 34 处
##   `card.get_node("VBox")` → `card.find_child("VBox", true, false)`。
##   本探针把「为何必须 find_child」与「为何第 3 参 false 是承重的（非装饰）」两条
##   契约定死为可回归断言，防未来 Godot 版本语义漂移 / 有人误改回 get_node。
##
## ── 时序模型（team-lead 硬要求 · 全程**不入树**）────────────────────────────
##   本探针**不把 card 加入场景树**（断言 `card.is_inside_tree()==false`），
##   所模拟的是两种查询时序：① 入树前按名查询（pre-wrap）；② 钩子包裹后按名查询
##   （post-wrap，由 `_test_模拟包裹` **只复刻与「按名契约」相关的结构操作** = :2073-2102 中的
##    新建 MarginWrap / 抄 margin / 原位替换 / 收编 c）。**未复刻三段**（只影响布局尺寸，
##    不改「直系子 / 深度」⇒ 对按名契约无涉）：
##     ① size_flags 平移（:2078-2079）；
##     ② 非 Container 父的 anchor/offset 继承（:2080-2089）；
##     ③ 收编后 c 的 size_flags 覆写（:2103-2104）。
##   ⇒ 「包裹生效」必须被**独立观测**（children_before/after + vb 深度 + CTRL），
##      不能靠后续置空断言间接推断，否则第 3 条 null 可能「本来就没有」而假绿。
##
## 纪律：不改任何产品代码；仅新增本文件 + 同名 .tscn。
## 运行：godot --headless --path <项目> --scene res://tests/_probe_p0_vbox_contract.tscn
##
## gate_all / 门3 死函数水位豁免口径：本文件全部自定义函数均带 `_test_` 前缀
##   （DFUNC_KEEP_PREFIX 含 "_test_"）⇒ 不计入死函数水位（探针 = 主动探针，非遗留死码）。
##   文件名 `_probe_*.gd` + 函数 `_test_*` 前缀 = 双标记。
##
## 输出：机器可读行（**载荷全 ASCII**，防日志 mojibake）`P0PROBE <n> OK|FAIL <detail>`（n=1..5）
##   ＋ 配套自证 `P0PROBE PRE|CTRL|TREE|ORDER ...`，末行 `P0PROBE_DONE n_ok=<n> n_fail=<n>`。
##   计数口径：n_ok/n_fail 只计 5 条编号断言；PRE/CTRL/TREE/ORDER 为**配套自证**，
##   通过时不加 n_ok，失败时加 n_fail（诚实反映「测试自身失效」）。
## 退出码（承 verifier VRF2d-B 建议1）：`_fail>0 ⇒ quit(1)`，否则 `quit(0)` ⇒ 失败可被 gate_all 看见。
##   运行后自清临时节点（card.free()），不留 orphan。
## ────────────────────────────────────────────────────────────────────────────

var _ok: int = 0
var _fail: int = 0

func _ready() -> void:
	_test_看门狗()
	_test_跑()

func _test_看门狗() -> void:
	var t: SceneTreeTimer = get_tree().create_timer(6.0)
	t.timeout.connect(_test_超时退出)

func _test_超时退出() -> void:
	printerr("P0PROBE WATCHDOG timeout, force quit")
	get_tree().quit()

func _test_跑() -> void:
	prints(">>> P0PROBE_BEGIN")

	# ── 0. 构造卡片：与 page_sect_manager.gd:_make_card(:959-969) 同构 ──
	#    PanelContainer(card) 的直系子 = VBoxContainer(name="VBox")，VBox 带 margin override
	#    （正是 `_入树_包边距` 白名单命中的宿主形状）。**不加入场景树**（见上方时序模型）。
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	var vb: VBoxContainer = VBoxContainer.new()
	vb.name = "VBox"
	vb.add_theme_constant_override("margin_left", 12)
	vb.add_theme_constant_override("margin_right", 12)
	vb.add_theme_constant_override("margin_top", 12)
	vb.add_theme_constant_override("margin_bottom", 12)
	card.add_child(vb)

	var 子_before: String = _test_子名(card)
	var 深_before: int = _test_深(card, vb)

	# ── 断言 1（pre-wrap）：card.get_node("VBox") 命中，且就是 vb；打印 vb 名 + 深度 ──
	var vb_before: Node = card.get_node("VBox")
	_test_断言(1,
		vb_before != null and vb_before == vb and 深_before == 1,
		"get_node pre-wrap -> %s depth=%d" % [_test_名(vb_before), 深_before])

	# ── PRE（覆盖实际调用情形 · 承 verifier VRF2d-B 建议2）：pre-wrap 时 find_child 亦命中同一 object ──
	#    （P0 补丁 34 处的实际情形正是「未包裹时用 find_child」）
	var vb_pre: Node = card.find_child("VBox", true, false)
	_test_配套("PRE", vb_pre != null and is_same(vb_pre, vb_before),
		"pre-wrap find_child(true,false) id=" + str(_test_id(vb_pre)) + " == get_node id=" + str(_test_id(vb_before)))

	# ── 断言 2：模拟钩子包裹；独立观测「包裹确实发生」= 子节点名列表变化 + 深度 +1 ──
	_test_模拟包裹(card, vb)
	var 子_after: String = _test_子名(card)
	var 深_after: int = _test_深(card, vb)
	_test_断言(2,
		子_before == "[VBox]" and 子_after == "[MarginWrap]"
		and String(vb.get_parent().name) == "MarginWrap" and 深_after == 2,
		"children_before=%s children_after=%s  VBox depth %d->%d (wrap confirmed)"
			% [子_before, 子_after, 深_before, 深_after])

	# ── 断言 3（post-wrap · 反证必要性）：旧直系查找已断（null）──
	var 取回: Node = card.get_node_or_null("VBox")
	_test_断言(3, 取回 == null,
		"get_node_or_null post-wrap -> %s" % _test_名(取回))

	# ── 断言 4（post-wrap · 证有效）：递归按名查找命中**同一 object 引用** ──
	#    禁只比 name：用 `==` 与 `is_same` 双判，并打印双方 instance_id 相等。
	var vb_after: Node = card.find_child("VBox", true, false)
	_test_断言(4,
		vb_after != null and vb_after == vb_before and is_same(vb_after, vb_before),
		"find_child(true,false) -> %s id=%d == vb_before id=%d"
			% [_test_名(vb_after), _test_id(vb_after), _test_id(vb_before)])

	# ── 断言 5（★正控制 · 不可省）：owned=true 只匹配有 owner 者 ⇒ 仍 null ──
	#    证明第 3 参 `false` 是**承重的**（若误传 true，断言 4 会静默变红）。
	var vb_owned: Node = card.find_child("VBox", true, true)
	_test_断言(5, vb_owned == null,
		"find_child(true,true) -> %s   (owned-false is load-bearing)" % _test_名(vb_owned))

	# ── CTRL（反向自证 · 第 3 条的必要配套）：证明「null 不是本来就没有」，
	#    而是路径从 `VBox` 变成了 `MarginWrap`。──
	_test_配套("CTRL", card.get_node("MarginWrap") != null,
		"card.get_node(\"MarginWrap\") post-wrap -> MarginWrap   (path changed, so assertion 3 holds)")

	# ── TREE（时序自证）：确认全程不入树（否则断言 3 的时序前提不成立）。──
	_test_配套("TREE", card.is_inside_tree() == false,
		"card.is_inside_tree()=%s (expect false, never in tree)" % str(card.is_inside_tree()))

	# ── ORDER（tree-order 语义 · 承 verifier VRF2d-B 附注）：补一个同名直系子 "VBox"（无 margin ⇒ 不触发钩子）
	#    后，find_child 仍按 tree order 命中 vb（MarginWrap@0 先于 影@1）⇒ 钉住「首个 tree-order 匹配」语义。──
	var 影: VBoxContainer = VBoxContainer.new()
	影.name = "VBox"
	card.add_child(影)
	var fb: Node = card.find_child("VBox", true, false)
	_test_配套("ORDER", fb != null and is_same(fb, vb_before),
		"tree-order first-match id=" + str(_test_id(fb)) + " == vb id=" + str(_test_id(vb_before)))

	prints("P0PROBE_DONE n_ok=" + str(_ok) + " n_fail=" + str(_fail))

	# ── 自清：释放临时卡片（连带 MarginWrap/VBox/影），不留 orphan ──
	card.free()
	prints(">>> P0PROBE_END")
	# ── 退出码（承 verifier VRF2d-B 建议1）：断言失败必须**进退出码**，否则 gate_all/run_headless_chain
	#    只读 exit code ⇒ 看不见回归 ⇒「长期契约回归护栏」名实不符。──
	if _fail > 0:
		get_tree().quit(1)
	get_tree().quit()

func _test_模拟包裹(父: Node, c: Control) -> void:
	# 只复刻 ui_theme.gd:_包边距_延迟 中与「按名契约」相关的结构操作：
	# 新建 MarginWrap → 抄 margin → 原位替换 → 收编 c。
	# 未复刻三段（只影响布局尺寸，不改「直系子 / 深度」⇒ 对按名契约无涉）：
	#   ① size_flags 平移（:2078-2079）；
	#   ② 非 Container 父的 anchor/offset 继承（:2080-2089）；
	#   ③ 收编后 c 的 size_flags 覆写（:2103-2104）。
	var 位: int = c.get_index()
	var 包: MarginContainer = MarginContainer.new()
	包.name = "MarginWrap"
	for 键 in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		if c.has_theme_constant_override(键):
			包.add_theme_constant_override(键, c.get_theme_constant(键))
	父.remove_child(c)
	父.add_child(包)
	父.move_child(包, 位)
	包.add_child(c)

func _test_断言(n: int, cond: bool, detail: String) -> void:
	if cond:
		_ok += 1
		prints("P0PROBE", n, "OK", detail)
	else:
		_fail += 1
		prints("P0PROBE", n, "FAIL", detail)

func _test_配套(tag: String, cond: bool, detail: String) -> void:
	# 配套自证：通过不加 n_ok（n_ok 仅计 5 条编号断言），失败加 n_fail（反映测试自身失效）。
	if cond:
		prints("P0PROBE", tag, "OK", detail)
	else:
		_fail += 1
		prints("P0PROBE", tag, "FAIL", detail)

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

func _test_深(根: Node, 目标: Node) -> int:
	# 从「目标」向父链走到「根」的跳数（根=0）；不在根子树内返回 -1。
	var d: int = 0
	var cur: Node = 目标
	while cur != null and cur != 根:
		cur = cur.get_parent()
		d += 1
	if cur == null:
		return -1
	return d
