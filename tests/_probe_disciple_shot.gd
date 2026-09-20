extends Node

## 弟子页（列表 + 详情）真实渲染 before 截图探针。
## 用法： <managed python> .workbuddy/_run_shot.py res://tests/_probe_disciple_shot.tscn _probe_disciple_shot.txt
## 输出：accept_shots_full/01_disciple_before.png ＋ 01_disciple_detail_before.png

const OUT_DIR := "res://accept_shots_full/"


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": "acc_full"})
	await _settle(14)
	var ui: Node = main.get("新UI")
	if ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	ui._show_page("弟子")
	await _settle(25)
	var dp: Node = _find_page(get_tree().root, "page_disciple.gd")
	if dp == null:
		printerr(">>>FAIL 弟子页未找到")
		get_tree().quit()
		return
	prints(">>>DISC_PAGE", dp.name, "子节点数=", dp.get_child_count())
	_scan(dp)
	# ① 列表视图（中性文件名：防 before/after 相互覆盖事故，PH7-0919 实证）
	await _shot("01_disciple_list_shot.png")
	prints(">>>DISC_LIST_DONE")
	# ② 详情子视图（首位弟子）
	if dp.has_method("_show_detail"):
		dp._show_detail(0)
		await _settle(25)
		_scan(dp)
		await _shot("01_disciple_detail_shot.png")
		prints(">>>DISC_DETAIL_DONE")
	prints(">>>SHOT_DONE")
	get_tree().quit()


func _find_page(n: Node, tail: String) -> Node:
	if n.get_script() != null:
		var rp: String = n.get_script().resource_path
		if rp != "" and rp.ends_with(tail):
			return n
	for ch in n.get_children():
		var r: Node = _find_page(ch, tail)
		if r != null:
			return r
	return null


## 打印弟子页可见 Label 文本（机器可检 + 辅助视觉审查），空文本跳过。
func _scan(n: Node) -> void:
	if n is Control and n.is_visible_in_tree():
		if n is Label:
			var t: String = (n as Label).text
			if t.strip_edges() != "":
				prints(">>>DTXT", String(n.name), "'%s'" % t)
	for ch in n.get_children():
		_scan(ch)


func _settle(n: int) -> void:
	var t0: int = Time.get_ticks_msec()
	for i in n:
		await get_tree().process_frame
	var 余: int = 260 - (Time.get_ticks_msec() - t0)
	if 余 > 0:
		await get_tree().create_timer(float(余) / 1000.0).timeout
	await RenderingServer.frame_post_draw


func _ensure_dir() -> void:
	var abs := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null or vp.get_texture() == null:
		printerr(">>>SHOT FAIL 无 viewport/texture")
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		printerr(">>>SHOT FAIL 无 image")
		return
	_ensure_dir()
	var err: int = img.save_png(OUT_DIR + name)
	prints(">>>SHOT", name, "err=", err, "size=", str(img.get_size()))
