extends Node

## PH7-VIS-09 装备图纸（器谱阁）· 真实渲染单页探针（before/after 判读帧）。
## 复刻 tests/_probe_pill_shot.gd 的口径，只渲染「装备图纸」一页。
## 输出名可用环境变量 PH7_SHOT_NAME 覆盖（默认 S42_装备图纸.png），便于 before/after 两跑共用一份探针。
## 用法： <managed python> .workbuddy/_run_shot.py res://tests/_probe_bp_shot.tscn _bp_shot.txt

const OUT_DIR := "res://accept_shots_full/"
const SHOT_DEFAULT := "S42_装备图纸.png"
const PAGE_KEY := "装备图纸"

var _labels: Array = []


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	prints("=== 装备图纸单页探针启动 ===")
	_ensure_dir()
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
	var _ui: Node = main.get("新UI")
	if _ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	prints(">>> 进入游戏 · 弟子=", Game.弟子列表.size(), " 灵石=", Game.灵石)
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var scene: PackedScene = subs.get(PAGE_KEY, null) as PackedScene
	if scene == null:
		printerr(">>>FAIL 装备图纸 scene 缺失")
		get_tree().quit()
		return
	_ui._show_sub_page(PAGE_KEY, scene)
	await _settle(12)
	var cur: Node = _ui.get("_current_sub")
	if cur == null:
		printerr(">>>FAIL _current_sub=null")
		get_tree().quit()
		return
	prints(">>>PAGE 装备图纸 cur=", cur.name, " class=", cur.get_class(),
		" size=", cur.size, " global_rect=", cur.get_global_rect())
	_scan(cur)
	prints(">>>LABELS_BEGIN n=", _labels.size())
	for e in _labels:
		prints(">>>  LBL", e)
	prints(">>>LABELS_END")
	var name_out: String = OS.get_environment("PH7_SHOT_NAME")
	if name_out.strip_edges() == "":
		name_out = SHOT_DEFAULT
	await _shot(name_out)
	prints(">>>BP_SHOT_DONE name=", name_out)
	get_tree().quit()


func _scan(root: Node) -> void:
	_walk(root, 0)
	# ★ 机器可检几何：打印关键容器节点的 global_rect，确认顶栏/详情面板落在视口(1080×1920)内。
	var 关键: Array = ["TopBar"]
	for c in root.get_children():
		if c is Panel or c is PanelContainer or c.name in 关键:
			var r: Rect2 = c.get_global_rect()
			_labels.append("RECT %s cls=%s '%s' g=%s" % [c.name, c.get_class(), str(r.position), str(r.size)])
	var 详情 := root.get_node_or_null("Panel")  # 详情面板（_build 中直接 add_child 的 Panel）
	if 详情 != null:
		var rd: Rect2 = 详情.get_global_rect()
		_labels.append("RECT 详情面板 cls=Panel g=%s size=%s" % [str(rd.position), str(rd.size)])
	# ★ 机器可检：顶栏/标签栏子节点矩形（用于判定标题与返回钮是否重叠、页签是否均分）
	var 顶栏 := root.get_node_or_null("TopBar")
	if 顶栏 != null:
		_dump_children(顶栏, "TopBar")
	var 标签栏 := root.get_node_or_null("HBoxContainer")
	if 标签栏 == null:
		for c in root.get_children():
			if c is HBoxContainer and _has_tab_button(c):
				标签栏 = c
				break
	if 标签栏 != null:
		_dump_children(标签栏, "TabBar")

func _has_tab_button(n: Node) -> bool:
	for c in n.get_children():
		if c is Button:
			return true
	return false


func _dump_children(n: Node, tag: String) -> void:
	for c in n.get_children():
		var r: Rect2 = (c as Control).get_global_rect()
		_labels.append("CH %s/%s cls=%s g=%s size=%s" % [tag, c.name, c.get_class(),
			str(r.position), str(r.size)])
		for g in c.get_children():
			var rg: Rect2 = (g as Control).get_global_rect()
			_labels.append("CH %s/%s>%s cls=%s g=%s size=%s" % [tag, c.name, g.name, g.get_class(),
				str(rg.position), str(rg.size)])


func _walk(n: Node, d: int) -> void:
	if d > 16:
		return
	if n is Label:
		var lb := n as Label
		if lb.is_visible_in_tree():
			_labels.append("%s cls=%s fs=%s fc=%s '%s'" % [
				lb.name, lb.get_class(), str(lb.get_theme_font_size("font_size")),
				str(lb.get_theme_color("font_color")), lb.text.strip_edges().substr(0, 24)])
	for c in n.get_children():
		_walk(c, d + 1)


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
	var err: int = img.save_png(OUT_DIR + name)
	prints(">>>SHOT", name, "err=", err, "size=", str(img.get_size()))
