extends Node
## UI 手感探针（headless 可跑）：验证「全局按压反馈钩子」是否真的挂到了按钮上、并按预期缩放。
## 用法：<godot> --headless --path . --scene res://tests/_probe_ui_feel.tscn
## 目的：按压反馈是**全局隐式副作用**（node_added 钩子），没有静态调用点可查，
##       只能靠运行时实测：① 有多少按钮被挂钩 ② 按下/松开后 scale 是否按预期往返。

const 探针账号 := "__probe_uifeel__"

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(20)

	var ui: Node = main.get("新UI")
	if ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	# ★ GDScript 的 lambda 对局部变量是**按值捕获**（写入不外传），故计数必须放进容器。
	var st: Dictionary = {"n": 0, "hooked": 0, "first": null}
	_扫(ui, func(b: BaseButton) -> void:
		st["n"] = int(st["n"]) + 1
		if b.has_meta("_ui_press_hooked"):
			st["hooked"] = int(st["hooked"]) + 1
		if st["first"] == null:
			st["first"] = b)
	var 总数: int = int(st["n"])
	var 已挂: int = int(st["hooked"])
	var 首个: BaseButton = st["first"]
	prints(">>> 首页按钮 %d 个，已挂钩 %d 个" % [总数, 已挂])
	if 首个 != null:
		prints(">>> 首钮 meta=%s  button_down 连接数=%d" % [
			str(首个.get_meta_list()), 首个.button_down.get_connections().size()])
		# 抽查一个「非首钮」：若它也已被挂钩，说明钩子覆盖率而非单点偶然。
		var st2: Dictionary = {"second": null}
		_扫(ui, func(b: BaseButton) -> void:
			if b != 首个 and st2["second"] == null:
				st2["second"] = b)
		var 次: BaseButton = st2["second"]
		if 次 != null:
			prints(">>> 次钮 name=%s 连接数=%d meta=%s" % [
				str(次.name), 次.button_down.get_connections().size(), str(次.get_meta_list())])
			# 重复入树（切 Tab 会 remove_child + add_child）后连接数是否翻倍 —— 防重复挂钩回归
			var p: Node = 次.get_parent()
			if p != null:
				p.remove_child(次)
				p.add_child(次)
				prints(">>> 移出再入树后 连接数=%d（应保持，不得翻倍）" % 次.button_down.get_connections().size())

	if 首个 == null:
		prints(">>>FAIL 首页未找到任何 Button")
		get_tree().quit()
		return
	prints(">>> 取样按钮 name=%s size=%s scale=%s" % [
		str(首个.name), str(首个.size), str(首个.scale)])
	首个.emit_signal("button_down")
	await _settle(10)
	prints(">>> 按下后 scale=%s (期望 ≈0.94)" % str(首个.scale))
	首个.emit_signal("button_up")
	await _settle(14)
	prints(">>> 松开后 scale=%s (期望 =1.0)" % str(首个.scale))

	# 二级页入场：打开任一二级页后立刻取样，应处于「在途」状态，稍后归位。
	var subs: Dictionary = ui.get("ENTRY_SUB_PAGES")
	if subs.size() > 0:
		var k: String = str(subs.keys()[0])
		ui.call("_show_sub_page", k, subs[k])
		await _settle(1)
		var cur: Control = ui.get("_current_sub")
		if cur != null:
			prints(">>> 二级页 %s 入场第 1 帧 pos=%s alpha=%.2f（位移/淡入应在途）" % [
				k, str(cur.position), cur.modulate.a])
			await _settle(30)
			prints(">>> 收敛后 pos=%s alpha=%.2f（期望 (0,0) / 1.00）" % [
				str(cur.position), cur.modulate.a])

	prints(">>>PROBE_UI_FEEL_DONE")
	get_tree().quit()

func _扫(n: Node, f: Callable) -> void:
	if n is BaseButton:
		f.call(n)
	for c in n.get_children():
		_扫(c, f)

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
