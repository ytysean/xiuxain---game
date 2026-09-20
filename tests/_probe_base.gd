extends Node
## 图标底座「环带遮罩」效果探针（真实渲染 · 窗口移出屏幕，不弹窗干扰）。
## 用法：<godot> --path . res://tests/_probe_base.tscn
## 目的：老大要求底座「不要底色只要边框」（原为实心彩色圆盘，与金色器物抢视觉，
##       冰蓝/粉紫帧底色亮度 181~213 甚至比金器还亮 ⇒ 糊成一片）。改完后须在真实首页
##       逐一核对 6 套皮肤观感，并确认观景模式推近已彻底移除（背景恢复完整显示）。

const 探针账号 := "__probe_base__"
const 皮肤们: Array = [
	["taixu_yunhai", "太虚云海"],
	["chun_qinglan", "春·青岚叠翠"],
	["xia_bihe",     "夏·碧荷听雨"],
	["qiu_jinfeng",  "秋·金枫染岳"],
	["dong_xueji",   "冬·雪霁寒山"],
	["xian_jiuqiao", "仙·九霄琼阙"],
]

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(24)

	var ui: Node = main.get("新UI")
	if ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	var home: Node = ui.get("_current")
	if home == null:
		prints(">>>FAIL _current 为空")
		get_tree().quit()
		return
	prints(">>> 首页 = %s" % home.name)

	var vp: Viewport = get_viewport()

	# ── A. 首页（dock 有底座：库藏 / 幻形…）逐皮肤出图 ──
	for pair in 皮肤们:
		var sid: String = pair[0]
		Game.当前皮肤 = sid
		home.call("refresh")
		await _settle(10)
		await _save(vp, "res://_probe_base_home_%s.png" % sid)
		prints(">>> A 首页 %-14s → _probe_base_home_%s.png" % [sid, sid])

	# ── B. 更多面板（图1 那处：图标最大，底座问题最明显）逐皮肤出图 ──
	home.call("_on_quick_fold_toggle")
	await _settle(14)
	var mp = home.get("_more_panel")
	prints(">>> 更多面板 = %s visible=%s" % [str(mp != null), str(mp.visible) if mp != null else "?"])
	for pair in 皮肤们:
		var sid2: String = pair[0]
		Game.当前皮肤 = sid2
		home.call("refresh")
		await _settle(10)
		await _save(vp, "res://_probe_base_more_%s.png" % sid2)
		prints(">>> B 更多 %-14s → _probe_base_more_%s.png" % [sid2, sid2])

	# ── C. 观景模式：推近已移除 ⇒ 背景 rect 应恒为整屏，不随隐藏 UI 变化 ──
	for pair in 皮肤们:
		var tid: String = pair[0]
		Game.当前皮肤 = tid
		home.call("refresh")
		await _settle(8)
		var bg: TextureRect = home.get("_bg")
		prints(">>> C 换肤后 _bg rect=%s" % str(Rect2(bg.position, bg.size)))

	home.call("_on_quick_fold_toggle")   # 关掉更多面板
	await _settle(8)
	if home.has_method("_on_hide_ui_requested"):
		home.call("_on_hide_ui_requested")
	elif home.has_method("_toggle_hidden_ui"):
		home.call("_toggle_hidden_ui")
	elif home.has_method("_on_eye_pressed"):
		home.call("_on_eye_pressed")
	await _settle(16)
	var bg2: TextureRect = home.get("_bg")
	var chrome = home.get("_chrome")
	prints(">>> C 隐藏UI后 chrome.visible=%s  _bg rect=%s (应仍为整屏 ⇒ 未推近)"
		% [str(chrome.visible) if chrome != null else "?", str(Rect2(bg2.position, bg2.size))])
	await _save(vp, "res://_probe_base_hideui.png")
	prints(">>> C 隐藏UI图 → _probe_base_hideui.png")

	prints(">>>PROBE_BASE_DONE")
	get_tree().quit()

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(vp: Viewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img == null:
		prints(">>>WARN 截图失败 %s" % path)
		return
	img.save_png(path)
