extends Node

## 阶段一 · 运行时性能与泄漏实测（真实渲染 · 窗口移出屏幕 · 2026-09-16）
## A1（2026-09-16）：① 页清单改为运行时从 ENTRY_SUB_PAGES ∪ PAGE_IDS 派生（全 52 二级页 + 5 Tab）；
##                   ② 每页新增打点（dc/tex/robj 在场绝对量 + objd 常驻节点增量）→ 定位 DrawCall/显存大头。
## 流程：进入游戏 → 全页循环切 3 轮 → 每页打印 >>>PAGE 打点 + 每轮打印 >>>METRICS。
## 判据：第 2/3 轮 OBJECT_COUNT 增幅 < 2% ⇒ 页缓存正常、无失控泄漏；
##       若逐轮线性上涨 ⇒ 存在切页泄漏（配合 ORPHAN_NODE_COUNT 定位）。
## 用法：<godot> --path <proj> --scene res://tests/_probe_perf.tscn   ← 不要 --headless
##       （FPS / DrawCall / 显存指标只有真实渲染器才有意义）

const ROUNDS := 3
var _ui: Node = null
var _main: Node = null
var _pages: Array = []      # [["SUB", id] | ["TAB", id], ...]（运行时派生，A1）


func _ready() -> void:
	var w: Window = get_window()
	if w != null and DisplayServer.get_name() != "headless":
		w.position = Vector2i(-6000, -6000)
	var t := Timer.new()
	t.wait_time = 900.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		printerr(">>>PERF TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var t0 := Time.get_ticks_msec()
	_main = ps.instantiate()
	add_child(_main)
	await _settle(6)
	_main._登录_进入({"id": "acc_perf"})
	await _settle(14)
	_ui = _main.get("新UI")
	if _ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	print(">>>ENTER ms=", Time.get_ticks_msec() - t0, " 弟子=", Game.弟子列表.size())
	# A1：从真实路由表派生全页清单（SUB=二级页 / TAB=底部一级页），路由增删自动同步
	for _k in _ui.ENTRY_SUB_PAGES.keys():
		_pages.append(["SUB", str(_k)])
	for _pid in _ui.PAGE_IDS:
		_pages.append(["TAB", str(_pid)])
	print(">>>PAGES total=%d（SUB=%d TAB=%d）" % [
		_pages.size(), _ui.ENTRY_SUB_PAGES.size(), _ui.PAGE_IDS.size()])
	for r in range(1, ROUNDS + 1):
		for pg in _pages:
			var kind: String = str(pg[0])
			var id: String = str(pg[1])
			var obj0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var m0 := Time.get_ticks_msec()
			if kind == "TAB":
				_ui._show_page(id)
			else:
				var scene: PackedScene = _ui.ENTRY_SUB_PAGES.get(id, null)
				if scene == null:
					print(">>>PERF_PAGE_MISSING ", id)
					continue
				_ui._show_sub_page(id, scene)
			await _settle(10)
			# A1：每页打点 —— dc/tex/robj 为在场绝对量（找 DrawCall/显存大头）；objd 为该页常驻节点增量
			var obj := int(Performance.get_monitor(Performance.OBJECT_COUNT))
			var robj := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
			var dc := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
			var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
			print(">>>PAGE ms=%d round=%d kind=%s page=%s objd=%d obj=%d robj=%d dc=%d tex=%.2fMB" % [
				Time.get_ticks_msec() - m0, r, kind, id, obj - obj0, obj, robj, dc, tex / 1048576.0])
		await _settle(20)
		_dump(r)
	print(">>>PERF_ALL_DONE")
	get_tree().quit()


func _dump(round_idx: int) -> void:
	# DrawCall/显存为渲染线程上一帧的快照，足够反映量级。
	var fps := Engine.get_frames_per_second()
	var obj := Performance.get_monitor(Performance.OBJECT_COUNT)
	var orphan := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	# Godot 4：DrawCall/对象数走 RenderingServer 渲染统计（Performance 枚举名已变）
	var robj := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var tex := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	print(">>>METRICS round=%d fps=%d obj=%d orphan=%d robj=%d drawcalls=%d texmem=%.1fMB mem=%.1fMB" % [
		round_idx, fps, int(obj), int(orphan), int(robj), int(dc), tex / 1048576.0, mem / 1048576.0])


func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame
