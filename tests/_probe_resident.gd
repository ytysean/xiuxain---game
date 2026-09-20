extends Node

## 阶段一 · 常驻资源/内存峰值探针（headless · 只读 · 2026-09-16）
##
## 为什么 headless：真机显存（RENDER_TEXTURE_MEM_USED）只有真实渲染器才有意义，
##   故本探针不测显存，而测**与渲染无关的常驻量**：OBJECT_RESOURCE_COUNT / OBJECT_COUNT /
##   MEMORY_STATIC / OBJECT_ORPHAN_NODE_COUNT。它在 CI（--headless）即可跑，作为 _probe_perf
##   （真实渲染）的互补基线，专抓「切页后资源未释放」的常驻泄漏（真机表现为显存只涨不落）。
##
## 流程：进入游戏 → 采样基线 → 全二级页 + 全 Tab 各开一次 → 回首页 → 采样终值；
##   全程记录 OBJECT_RESOURCE_COUNT / MEMORY_STATIC 峰值。
## 用法：<godot> --headless --path <proj> --scene res://tests/_probe_resident.tscn
## 判据：末行出现 >>>RESIDENT_DONE；peak/after 若远高于 baseline 且不回落 ⇒ 常驻泄漏。

var _ui: Node = null
var _peak_res: int = 0
var _peak_mem: float = 0.0


func _ready() -> void:
	var w: Window = get_window()
	if w != null:
		w.position = Vector2i(-6000, -6000)
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit(1)
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit(1)
		return
	var t0 := Time.get_ticks_msec()
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": "acc_resident"})
	await _settle(14)
	_ui = main.get("新UI")
	if _ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit(1)
		return
	_sample("baseline")
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	for id in subs.keys():
		_ui._show_sub_page(id, subs[id])
		await _settle(2)
		_sample("open:" + str(id))
	for pid in _ui.PAGE_IDS:
		_ui._show_page(str(pid))
		await _settle(2)
		_sample("tab:" + str(pid))
	_ui._show_page("宗门")
	await _settle(20)
	_sample("after_home")
	print(">>>RESIDENT_DONE ms=%d sub_pages=%d peak_res=%d peak_mem=%.1fMB" % [
		Time.get_ticks_msec() - t0, subs.size(), _peak_res, _peak_mem / 1048576.0])
	get_tree().quit(0)


func _sample(tag: String) -> void:
	# 只读采样 + 峰值跟踪（不改任何业务状态）
	var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var obj := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphan := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC)
	if res > _peak_res:
		_peak_res = res
	if mem > _peak_mem:
		_peak_mem = mem
	print(">>>RESIDENT tag=%s res=%d obj=%d orphan=%d mem=%.1fMB" % [
		tag, res, obj, orphan, mem / 1048576.0])


func _settle(frames: int) -> void:
	for _i in range(frames):
		await get_tree().process_frame
