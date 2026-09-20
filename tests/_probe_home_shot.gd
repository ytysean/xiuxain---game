extends Node

## 首页（宗门全貌）真实渲染探针：登录后直接截默认基页（无需路由键）。
## 仿 _probe_page_shot.gd，但跳过二级页导航 —— 首页即 game_ui 默认呈现的基页。
## 用法： <managed python> .workbuddy/_run_shot.py res://tests/_probe_home_shot.tscn <日志名>
## 输出：accept_shots_full/00_home_after.png ＋ 首页快照栏节点文本 → 日志（机器可检）。

const OUT_DIR := "res://accept_shots_full/"

var _labels: Array = []


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
	# 制造一个司职空缺，让快照栏小字「空缺 N · 去殿阁 ▶」在截图中可见（精修问题①验收）
	var 司职 = Game.get("司职列表")
	if 司职 is Dictionary and 司职.size() > 0:
		var ks = 司职.keys()
		var e = 司职[ks[0]]
		if e is Dictionary:
			e["负责"] = null
	# 注入后让首页重绘快照栏（小字「空缺 N」依赖司职空缺，须 refresh 才进界面）
	var hp: Node = _find_home(get_tree().root)
	if hp != null and hp.has_method("refresh"):
		hp.refresh()
	prints(">>> 进入游戏 · 弟子=", Game.弟子列表.size(), " 灵石=", Game.灵石)
	await _settle(12)
	_scan_home(get_tree().root)
	# 验收问题⑤：灵气光点粒子节点是否真正建出（小字/转场/滚动的机器判据已含于扫描）
	if hp != null:
		var qi: Node = hp.find_child("AmbientQi", true, false)
		if qi != null:
			prints(">>>QI", "AmbientQi exist amount=", (qi as GPUParticles2D).amount)
		else:
			prints(">>>QI", "AmbientQi MISSING")
	await _shot("00_home_after.png")
	prints(">>>SHOT_DONE")
	get_tree().quit()


## 仅打印首页快照栏相关节点（Snap_/Title_/Value_/Sub_），机器可检、禁肉眼读截图。
func _scan_home(n: Node) -> void:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree():
			var nm: String = String(n.name)
			if nm.begins_with("Snap_") or nm.begins_with("Title_") or nm.begins_with("Value_") or nm.begins_with("Sub_"):
				var txt: String = ""
				if n is Label:
					txt = (n as Label).text
				prints(">>>HOME", nm, "'%s'" % txt)
	for ch in n.get_children():
		_scan_home(ch)


func _find_home(n: Node) -> Node:
	if n.get_script() != null:
		var rp: String = n.get_script().resource_path
		if rp != "" and rp.ends_with("sect_home_page.gd"):
			return n
	for ch in n.get_children():
		var r: Node = _find_home(ch)
		if r != null:
			return r
	return null


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
