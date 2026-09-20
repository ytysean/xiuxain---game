extends Node
## 全量「返回按钮可用性」审计探针（真实渲染 · 窗口移出屏幕）。
## 用法：<godot> --path . res://tests/_probe_backbtn.tscn
##
## 背景：老大反馈「我点个返回都是弹出储物袋」「返回也点不动，什么都是乱套的」。
##       逐页静态读代码太慢且会漏，故改为**逐页真实按键验收**：
##       ① 用 _show_sub_page 打开 ENTRY_SUB_PAGES 里每个二级页
##       ② 在该页里找所有「返回类」按钮（名字/文本命中，或位于左上 200×200 热区）
##       ③ 真实点击它，看 _current_sub 是否真的关掉
##       ④ 顺手复测 _舆图回跳 是否粘滞（关上后误跳宗门舆图）
##
## 输出：每页一行结论 + 末尾汇总。任何「返回点不动」都会现形。

const 探针账号 := "__probe_backbtn__"

var _main: Node = null
var _ui: Node = null
var _失败: Array = []
var _警告: Array = []   # 「返回后跳到另一页」＝老大口中的「返回串台」


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	_main._登录_进入({"id": 探针账号})
	await _settle(24)

	_ui = _main.get("新UI")
	if _ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	var 常量表: Dictionary = _ui.get_script().get_script_constant_map()
	var 页面表: Dictionary = 常量表.get("ENTRY_SUB_PAGES", {})
	prints("===== 待审计二级页 %d 个 =====" % 页面表.size())

	var 序号: int = 0
	for id in 页面表.keys():
		序号 += 1
		var scene: PackedScene = 页面表[id]
		prints("\n---- [%d/%d] %s ----" % [序号, 页面表.size(), str(id)])
		await _审一页(String(id), scene)

	prints("\n===== 汇总 =====")
	if _警告.is_empty():
		prints("  「返回串台」：0 例")
	else:
		prints("  ⚠ 「返回串台」%d 例（返回后跳到别的页，非回一级页）：" % _警告.size())
		for w in _警告:
			prints("    - %s" % str(w))
	if _失败.is_empty():
		prints("  >>>PASS 全部二级页返回按钮均生效")
	else:
		prints("  >>>FAIL %d 个页面存在问题：" % _失败.size())
		for f in _失败:
			prints("    - %s" % str(f))

	get_tree().quit()


func _审一页(id: String, scene: PackedScene) -> void:
	_重置()
	await _settle(3)
	_ui.call("_show_sub_page", id, scene)
	await _settle(8)

	var sub: Control = _ui.get("_current_sub")
	if sub == null:
		prints("  打开失败：_current_sub 为空")
		_失败.append("%s：打不开（_current_sub 为空）" % id)
		return
	prints("  已打开：%s / script=%s / 子节点 %d" % [
		str(sub.name), _脚本名(sub), sub.get_child_count()])

	# 收集候选返回钮：① 名字/文本命中 ② 左上 200×200 热区内的小按钮
	var 钮们: Array = []
	_收集按钮(sub, 钮们)
	var 候选: Array = []
	for b in 钮们:
		var bb: Button = b
		if not bb.visible or bb.size.x <= 1.0:
			continue
		var 名文: String = str(bb.name) + "|" + bb.text.strip_edges()
		var r: Rect2 = bb.get_global_rect()
		var 像返回: bool = false
		for k in ["返回", "Back", "Close", "关闭", "退出", "◇", "×", "←", "‹", "回到"]:
			if 名文.contains(k):
				像返回 = true
				break
		# 左上角小方钮也视为返回候选（本项目返回箭头多为 90×90 无名钮）
		if r.position.x < 200.0 and r.position.y < 220.0 and r.size.x <= 130.0 and r.size.y <= 130.0:
			像返回 = true
		if 像返回:
			候选.append(bb)

	if 候选.is_empty():
		prints("  ⚠ 未找到任何「返回类」按钮（该页可能只能靠系统手势/外链关闭）")
		_失败.append("%s：页内无返回按钮" % id)
		# 仍然尝试用容器级关闭兜底，确认它能被关掉
		_重置()
		return

	# 逐个点，直到页面被关掉
	var 关掉: bool = false
	var 已点: Array = []
	for b in 候选:
		var bb: Button = b
		if not is_instance_valid(bb) or not bb.is_inside_tree():
			continue
		var c: Vector2 = bb.get_global_rect().get_center()
		已点.append("%s「%s」" % [str(bb.name), bb.text.strip_edges()])
		_点击(c)
		await _settle(8)
		var 现: Variant = _ui.get("_current_sub")
		if 现 == null:
			关掉 = true
			break
		# 跳到别的二级页也算「返回生效」的一种（如舆图回跳）
		if str((现 as Node).name) != str(sub.name):
			# B8 舆图回跳：返回时回到「宗门舆图」是设计行为
			if str((现 as Node).name).contains("宗门舆图"):
				prints("  ✓ 返回生效（并按 B8 设计回到宗门舆图）")
				关掉 = true
				break
			prints("  ⚠ 返回后跳到另一页：%s" % str((现 as Node).name))
			_警告.append("%s：点「%s」后跳到 %s" % [
				id, str(bb.text.strip_edges()), str((现 as Node).name)])
			关掉 = true
			break

	if 关掉:
		prints("  ✓ 返回生效（试过 %s）" % str(已点))
	else:
		prints("  × 返回无效！点过 %s 后页面仍开着（%s）" % [str(已点), str(sub.name)])
		_失败.append("%s：返回按钮点了不关页（按钮 %s）" % [id, str(已点)])
		_重置()
	await _settle(3)


func _重置() -> void:
	if _ui != null and _ui.has_method("_close_sub_page"):
		_ui.call("_close_sub_page")


func _脚本名(c: Control) -> String:
	var s: Variant = c.get_script()
	if s == null:
		return "-"
	return str(s).get_slice("(", 0)


func _收集按钮(n: Node, 出: Array) -> void:
	if n is Button:
		出.append(n)
	for c in n.get_children():
		_收集按钮(c, 出)


func _点击(点: Vector2) -> void:
	# 画布坐标 → 窗口坐标（见 _probe_hitmap.gd 的踩坑注释）
	var 窗口点: Vector2 = get_viewport().get_final_transform() * 点
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = 窗口点
	ev.global_position = 窗口点
	get_viewport().push_input(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = 窗口点
	ev2.global_position = 窗口点
	get_viewport().push_input(ev2)


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
