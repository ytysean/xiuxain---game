extends Node

## 死键扫描探针（**真实渲染，勿加 --headless**）
##
## 解决的问题（#003 子任务 3.2 的自动化版）：
##   既有 `_t_btnsweep.gd` 判「点了没反应」只靠三路 —— 页面栈 / tab / 窗口数，
##   而**页内 Tab、筛选 chip、开关、勾选、列表重绘**一律落空 ⇒ 实测 NOOP 高达 588 条，
##   噪声把真死键彻底淹没，人工复核 588 条根本不现实。
##
## 本探针只回答一个问题：**这个按钮按下去，游戏有没有任何可观察反应**。
## 六路判据，任一路变化即判「有效」：
##   ① 页面栈 `_current_sub` 变化          → SUB（进二级页）
##   ② tab `_last_tab_page` 变化           → TAB
##   ③ 顶层 Window 数增加                   → POPUP（弹窗）
##   ④ **本次点击期间新建节点数** > 空转基线 → NEW（toast / 飘字 / 列表重建 / 任何 add_child）
##   ⑤ **页内指纹**变化                     → PAGE_INT（页内切换 / 数值刷新 / 可见性变化）
##   ⑥ 以上全无                             → DEAD（真死键候选，唯一需要人看的）
##
## ★ ④ 必须扣除「空转基线」：页面自带的定时重绘/轮播会让 `node_added` 每帧增长，
##   不扣基线 ⇒ 所有按钮都会被误判成「有效」。故每击前先静默等 6 帧测自然增长量，
##   这既是基线，也是一次「测量方法自检」（阳性对照思维的落地）。
##
## 跳过：破坏性按钮（删除/重置/出征/挑战…），沿用 btnsweep 的 SKIP_KEYS。
##
## 用法：python .workbuddy/_run_probe.py "res://tests/_t_deadkey.tscn" "_deadkey.txt"
## 产物：.workbuddy/_deadkey.log（Godot 直写 UTF-8，权威）

const LOG_PATH := "E:/Xiuxian/taixuanzongmenlu/.workbuddy/_deadkey.log"
const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]
const MAX_CLICKS := 1400
const IDLE_FRAMES := 6
const FP_MAX_NODES := 4000        # 指纹遍历节点上限（防超重页卡死）

const SKIP_KEYS: Array = [
	"删除", "删档", "删号", "重置", "清空", "清除", "销毁", "解散", "灭门", "踢出", "逐出", "注销",
	"退出游戏", "退出登录", "卸载", "恢复初始", "弃档", "退宗",
	"出征", "讨伐", "攻打", "围攻", "进入战斗", "开战", "追杀", "斗法", "挑战",
	"开始战斗", "迎战", "应战", "宣战",
]

var _ui: Node = null
var _buf: Array = []
var _born := 0
var _clicks := 0
var _opt_seen := 0
var _disabled_seen := 0
var _fp_unstable := 0
var _dead: Array = []
var _stat := {"SUB": 0, "TAB": 0, "POPUP": 0, "NEW": 0, "PAGE_INT": 0, "LAYER": 0, "DEAD": 0}
var _layers: Array = []          # 缓存 CanvasLayer 列表（启动时收集一次，避免每击遍历全场景）
var _done: Dictionary = {}
var _fin := false


func _ready() -> void:
	prints("=== 死键扫描探针启动 ===")
	get_tree().node_added.connect(_on_born)

	var t := Timer.new()
	# 自毁闸：必须在外部运行器 timeout(900s) 之前落盘，否则日志为空、白跑一轮。
	t.wait_time = 480.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		prints(">>>DEADKEY_TIMEOUT")
		_finish("TIMEOUT"))
	add_child(t)
	t.start()

	if Game == null:
		_finish("NO_GAME")
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		_finish("NO_MAIN")
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": "acc_full"})
	await _settle(16)
	_ui = main.get("新UI")
	if _ui == null:
		_finish("NO_UI")
		return
	prints(">>> 进入游戏 弟子=", Game.弟子列表.size())

	# ① 首页
	await _sweep("HOME", _首页根())

	# ② 底部 5 Tab
	for tab in TABS:
		if _clicks >= MAX_CLICKS:
			break
		_ui._show_page(str(tab))
		await _settle(12)
		await _sweep("TAB_" + str(tab), _ui.get("_current"))

	# ③ 全部二级页
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var ids: Array = subs.keys()
	ids.sort()
	for id in ids:
		if _clicks >= MAX_CLICKS:
			break
		_ui._show_sub_page(str(id), subs[id])
		await _settle(11)
		await _sweep("SUB_" + str(id), _有效子页())
		_回退()

	# ④ 特殊页（非 ENTRY_SUB_PAGES 键）
	var sps: Array = [
		["X01_天下", "_open_world_map_page"],
		["X02_心弦", "_open_chat_page"],
		["X03_传讯中心", "_open_message_center"],
		["X04_宗主详情", "_open_master_detail"],
		["X05_玩家交易", "_open_player_trade_page"],
		["X06_离线管理", "_open_offline_manager_page"],
	]
	for sp in sps:
		if _clicks >= MAX_CLICKS:
			break
		if _ui.has_method(str(sp[1])):
			_ui.call(str(sp[1]))
			await _settle(14)
			await _sweep("SP_" + str(sp[0]), _有效子页())
			_回退()

	_finish("DONE")


# ══════════════ 遍历 ══════════════

func _sweep(label: String, root: Node) -> void:
	if root == null or not is_instance_valid(root):
		_buf.append(">>>PAGE_NULL " + label)
		return
	_收集浮层()        # 每页刷新一次浮层清单（可能有动态新建的 CanvasLayer）
	var btns: Array = _按钮(root)
	_buf.append(">>>PAGE %s btns=%d" % [label, btns.size()])
	var base_tab: String = str(_ui.get("_last_tab_page"))
	for b in btns:
		if _clicks >= MAX_CLICKS:
			break
		# ★ 必须先判有效再转换：点击可能让当前页 queue_free（被点的按钮也随之释放），
		#   直接 `b as Button` 对已释放对象会抛 "Trying to cast a freed object" 并**中断整轮遍历**
		#   （v1 实测就在此断掉，clicks 只到 422 / 应有 ~600）。
		if not is_instance_valid(b):
			continue
		var btn: Button = b
		if btn == null or not btn.visible:
			continue
		var txt: String = btn.text.strip_edges()
		var nm: String = str(btn.name)
		# ★ disabled 按钮必须跳过：`pressed.emit()` 是**直接发信号**，绕过 disabled 检查
		#   ⇒ 前置条件不满足而置灰的按钮（「解锁丹方」「入阁」「习得图谱」…）会被测出
		#   「点了没反应」，而用户实际**根本点不到它** ⇒ 纯属假死键（v4 实测成批）。
		#   注意：txt/nm 必须在上面先取好 —— 提到声明之前用会让整脚本**编译失败**，
		#   而 gdtoolkit 只做语法解析、不做名字解析 ⇒ 闸门看不见（本批次实测挂死 7 分钟）。
		if btn.disabled:
			_disabled_seen += 1
			_buf.append(">>>SKIP_DISABLED %s | %s | %s" % [label, txt, nm])
			continue
		# ★ 返回类按钮必须排除：点它会**关闭当前页** ⇒ 同一页后续按钮全在「已关闭的页」上被测
		#   ⇒ 整页按钮集体假 DEAD（v3 实测 BackBtn / 「← 返回宗门」成批出现即此）。
		#   返回钮的功能是确定的（关当前页），且 64 页验收已覆盖「每页能开能关」，无需重复测。
		if nm.begins_with("BackBtn") or txt.find("返回") >= 0 or txt.find("折返") >= 0:
			_buf.append(">>>SKIP_BACK %s | %s | %s" % [label, txt, nm])
			continue
		var key: String = label + "|" + txt + "|" + nm
		if _done.has(key):
			continue
		_done[key] = true
		var skip := false
		for k in SKIP_KEYS:
			if txt.find(str(k)) >= 0:
				skip = true
				break
		if skip:
			_buf.append(">>>SKIP %s | %s | %s" % [label, txt, nm])
			continue
		await _press(btn, label, txt, nm, base_tab, root)


func _press(btn: Button, label: String, txt: String, nm: String,
		base_tab: String, root: Node) -> void:
	_clicks += 1
	var dsc: String = "%s | %s | %s" % [label, txt, nm]

	# ── 采样前先「等稳定」：页面入场是**时间制** tween（约 0.25s），headless 帧率极高
	#    ⇒ 固定等 6 帧只有 ~20ms，动画远未结束 ⇒ 指纹每次采样都不同 ⇒ 指纹判据 172 次失效。
	#    正确做法：一直等到连续两次采样相同（有上限，防永久轮播页卡死）。
	var r0: Dictionary = await _等稳定(root)
	var before_fp: String = str(r0["fp"])
	var fp_stable: bool = bool(r0["stable"])
	if not fp_stable:
		_fp_unstable += 1

	# ── 空转基线：页面已稳定后再量 IDLE_FRAMES 帧的自然新增节点数 ──
	var b0: int = _born
	await _settle(IDLE_FRAMES)
	var idle: int = _born - b0
	var before_born: int = _born

	var before_sub = _有效子页()
	var before_tab: String = str(_ui.get("_last_tab_page"))
	var before_win: int = _窗口数()
	var before_layer: int = _浮层签名()
	prints(">>>CLICK|%s|%d|%s|%s" % [label, _clicks, txt, nm])

	# ★ toggle_mode 按钮（筛选 chip / 队签 / 选中卡）：真实点击会翻转 button_pressed，
	#   而 `pressed.emit()` 只发信号**不改状态** ⇒ 依赖 button_pressed 的页面看起来「没反应」，
	#   会把大批有效按钮误判成死键。故先翻转状态（触发 toggled 与内部逻辑）再发 pressed。
	if btn.toggle_mode:
		btn.button_pressed = not btn.button_pressed
	btn.pressed.emit()
	await _settle(10)

	var after_sub = _有效子页()
	var after_tab: String = str(_ui.get("_last_tab_page"))
	var after_win: int = _窗口数()
	var new_nodes: int = _born - before_born - idle
	var r1: Dictionary = await _等稳定(root)
	var after_fp: String = str(r1["fp"])
	var after_layer: int = _浮层签名()
	var root_gone: bool = not is_instance_valid(root)

	var kind := ""
	if root_gone:
		# 当前页被销毁（返回 / 关闭 / 跳转）＝ 明确反应
		kind = "SUB"
	elif after_sub != null and after_sub != before_sub:
		kind = "SUB"
	elif after_tab != before_tab:
		kind = "TAB"
	elif after_win > before_win or after_win > 0:
		kind = "POPUP"
	elif new_nodes > 0:
		kind = "NEW"
	elif after_layer != before_layer:
		kind = "LAYER"
	elif fp_stable and after_fp != before_fp:
		kind = "PAGE_INT"
	else:
		kind = "DEAD"
		_dead.append("%s | idle=%d new=%d fp稳定=%s" % [
			dsc, idle, new_nodes, "是" if fp_stable else "否"])

	_stat[kind] = int(_stat[kind]) + 1
	_buf.append(">>>%s %s | idle=%d new=%d" % [kind, dsc, idle, new_nodes])
	if kind != "DEAD":
		prints(">>>%s %s" % [kind, dsc])
	else:
		prints(">>>DEAD %s" % dsc)

	# ★ 恢复现场必须**条件化**（v1–v6 无条件关页 ⇒ 同页第 2 个按钮起全在「已关闭的页」上被测
	#   ⇒ 大面积假 DEAD：v6 清单里 TeamTab_1/2、Type_秘境/妖兽/阵营、Opt_逍遥/九幽、
	#   阵营声望 2/3、藏书阁「收录此类」… 全是这么来的）。只有真的「栈变了/窗口开了/tab 换了」
	#   才需要回退，否则当前页保持原样、后续按钮才能在真实页面上被测。
	var 需恢复: bool = root_gone or (after_sub != before_sub) or after_tab != before_tab or after_win > 0
	if 需恢复:
		_回退()
		if str(_ui.get("_last_tab_page")) != base_tab:
			_ui._show_page(base_tab)
			await _settle(8)


func _回退() -> void:
	var cs = _ui.get("_current_sub")
	if is_instance_valid(cs):
		_ui._close_sub_page()
	if _窗口数() > 0:
		_隐藏窗口()


# ══════════════ 工具 ══════════════

func _on_born(_n: Node) -> void:
	_born += 1


func _首页根() -> Node:
	var h = _ui.get("_页_宗门")
	if is_instance_valid(h):
		return h
	return _ui


func _有效子页() -> Node:
	var s = _ui.get("_current_sub")
	if is_instance_valid(s):
		return s
	return null


func _按钮(root: Node) -> Array:
	var out: Array = []
	_走(root, out, 0)
	return out


func _走(n: Node, out: Array, d: int) -> void:
	if n == null or d > 14:
		return
	if n is OptionButton:
		# OptionButton 靠 `item_selected` 工作，`pressed.emit()` 对它无意义 ⇒ 本轮不计入，
		# 单独计数（避免把「机制不同」误报成「死键」）。
		_opt_seen += 1
	elif n is Button and not (n is Window):
		out.append(n)
	if n is Window:
		return          # 不钻进弹窗内部
	for c in n.get_children():
		_走(c, out, d + 1)


# 页内指纹：把「可见结构 + 全部文本 + 纹理路径」压成一个串。
# 判据意义：点击后这些东西一个都没变 ⇒ 连列表重绘都没发生 ⇒ 极可能真死键。
func _指纹(root: Node) -> String:
	if root == null or not is_instance_valid(root):
		return "null"
	var acc: Array = []
	_采(root, acc, 0)
	return str(hash(str(acc)))


func _采(n: Node, acc: Array, d: int) -> void:
	if n == null or d > 12 or acc.size() > FP_MAX_NODES:
		return
	if n is Control:
		var c: Control = n
		# ★ 必须用 is_visible_in_tree()：`c.visible` 是**自身**属性，父节点被 hide 时子节点
		#   的 visible 仍是 true ⇒ 页面隐藏/关闭在指纹里完全看不出来（v3 实测）。
		acc.append(1 if c.is_visible_in_tree() else 0)
		acc.append(c.get_class())
		acc.append(str(c.size))
		# ★ modulate 必须采：页内 Tab / 筛选 chip / 队签 / 选中卡**只改颜色不改结构**，
		#   不采 modulate ⇒ 这批「有效的页内切换」全被判成死键（v1 实测即此）。
		acc.append(str(c.modulate))
		acc.append(str(c.self_modulate))
		if c is Label or c is RichTextLabel or c is Button:
			acc.append(c.text)
		# ★ 主题色 override 也必须采：项目大量用 add_theme_color_override("font_color", …)
		#   表达「选中/高亮/禁用」，这类变化不进 modulate ⇒ 不采则又是一批假死键（v2 实测）。
		if c is Label or c is Button:
			acc.append(str(c.get_theme_color("font_color")))
			acc.append(str(c.get_theme_font_size("font_size")))
		if c is PanelContainer or c is Panel:
			var sb: StyleBox = c.get_theme_stylebox("panel")
			if sb is StyleBoxFlat:
				var sbf: StyleBoxFlat = sb
				acc.append(str(sbf.bg_color))
				acc.append(str(sbf.border_color))
		if c is BaseButton:
			acc.append(1 if (c as BaseButton).button_pressed else 0)
			# 采 normal stylebox：项目大量用 add_theme_stylebox_override("normal", …) 表达
			# 选中态（它不进 modulate、也不一定改 font_color）⇒ 不采则又是一批假死键。
			var bs: StyleBox = (c as BaseButton).get_theme_stylebox("normal")
			if bs is StyleBoxFlat:
				var bsf: StyleBoxFlat = bs
				acc.append(str(bsf.bg_color))
				acc.append(str(bsf.border_color))
		if c is TextureRect:
			var tr: TextureRect = c
			if tr.texture != null:
				acc.append(tr.texture.resource_path)
		if c is ProgressBar:
			acc.append(str((c as ProgressBar).value))
	for ch in n.get_children():
		_采(ch, acc, d + 1)


# ── 浮层签名 ──
# 为什么单独采这一路：常驻预热的浮层（宗主改名弹窗等）挂在**独立 CanvasLayer** 上，
# 不在当前页子树内；且它的 `_build()` 只跑一次 ⇒ 唤起时「节点数不变 + 页内指纹不变」
# ⇒ 会被误判成死键（v4/v5 实测 EditBtn 即此）。故把「所有 CanvasLayer 的可见性 +
# 其下 Control 的可见性/文本」单独压一个签名参与判据。
func _收集浮层() -> void:
	_layers.clear()
	var st: Array = [get_tree().root]
	while not st.is_empty():
		var x: Node = st.pop_back()
		if x is CanvasLayer:
			_layers.append(x)
			continue        # CanvasLayer 内部不再当普通树遍历
		for c in x.get_children():
			st.append(c)


func _浮层签名() -> int:
	var h: int = 0
	for L in _layers:
		if not is_instance_valid(L):
			continue
		h = h * 31 + (1 if (L as CanvasLayer).visible else 0)
		for g in (L as CanvasLayer).get_children():
			h = h * 31 + _浮层走(g, 0)
	return h


func _浮层走(n: Node, d: int) -> int:
	if n == null or d > 6:
		return 0
	var h: int = 0
	if n is Control:
		var c: Control = n
		h = h * 31 + (1 if c.is_visible_in_tree() else 0)
		if c is Label or c is Button or c is LineEdit:
			h = h * 31 + c.text.hash()
	for ch in n.get_children():
		h = h * 31 + _浮层走(ch, d + 1)
	return h


func _窗口数() -> int:
	var n := 0
	var st: Array = [get_tree().root]
	while not st.is_empty():
		var x: Node = st.pop_back()
		if x is Window and (x as Window).visible and x != get_tree().root:
			n += 1
		for c in x.get_children():
			st.append(c)
	return n


func _隐藏窗口() -> void:
	var st: Array = [get_tree().root]
	while not st.is_empty():
		var x: Node = st.pop_back()
		if x is Window and (x as Window).visible and x != get_tree().root:
			(x as Window).hide()
		for c in x.get_children():
			st.append(c)


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


# 一直等到「连续两次采样完全相同」，返回 {fp, stable}。
# 为什么必须这样：页面入场/交错动画是**时间制** tween，headless 帧率极高 ⇒ 定帧等待远远不够；
# 固定帧数会让绝大多数页被误判成「指纹不稳定」而放弃该路判据（v2 实测 172 次）。
func _等稳定(root: Node, 帧上限: int = 90) -> Dictionary:
	var prev: String = _指纹(root)
	for i in range(帧上限):
		await get_tree().process_frame
		var cur: String = _指纹(root)
		if cur == prev:
			return {"fp": cur, "stable": true}
		prev = cur
	return {"fp": prev, "stable": false}


func _finish(tag: String) -> void:
	if _fin:
		return
	_fin = true
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		prints(">>>DEADKEY_LOG_FAIL")
		get_tree().quit()
		return
	f.store_line("# 死键扫描报告 tag=%s clicks=%d" % [tag, _clicks])
	f.store_line("# SUB=%d TAB=%d POPUP=%d NEW=%d PAGE_INT=%d LAYER=%d  ★DEAD=%d" % [
		int(_stat["SUB"]), int(_stat["TAB"]), int(_stat["POPUP"]),
		int(_stat["NEW"]), int(_stat["PAGE_INT"]), int(_stat["LAYER"]), int(_stat["DEAD"])])
	f.store_line("# 未测：OptionButton %d 个（走 item_selected，机制不同）；disabled 按钮 %d 个（用户点不到）；"
		% [_opt_seen, _disabled_seen]
		+ "指纹不稳定页 %d 次（该页已放弃指纹判据）" % _fp_unstable)
	f.store_line("")
	f.store_line("### 明细")
	for l in _buf:
		f.store_line(str(l))
	f.store_line("")
	f.store_line("### ★ 真死键候选（六路判据全无变化，需人工判定「瞬时动作」还是「空转」）")
	f.store_line("### 判定口径：①页面栈 ②tab ③窗口数 ④新建节点数(已扣空转基线) ⑤页内指纹 ⑥全无=DEAD")
	for d in _dead:
		f.store_line(str(d))
	f.flush()
	f.close()
	prints(">>>DEADKEY_ALL_DONE", tag, " clicks=", _clicks, " DEAD=", _dead.size())
	get_tree().quit()
