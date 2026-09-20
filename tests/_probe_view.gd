extends Node
## 背景完整性验证探针（2026-09-15 v2 · 重写）
##
## 验证 taixu_yunhai 皮肤背景 home_bg_sect_a.png：
##   ① 背景恒为整屏原比例铺满（KEEP_ASPECT_COVERED），无任何推近 / 裁切 / 放大；
##   ② 新素材下部留白是否已补满（看图，不看数值）。
##
## ★ 历史：旧版本探针记录的是「观景模式推近 1.22 倍把留白推出屏」方案。
##   该方案已被老大明确否决（「太虚云海我不要你的缩进效果，要跟其他一样显示完整图」），
##   相关常量 VIEW_ZOOM_K / VIEW_ZOOM_WHITE、变量 _bg_zoom_k / _skin_need_zoom、
##   函数 _is_bottom_blank() / _apply_bg_view_zoom() 已从 sect_home_page.gd 整体移除，
##   故本脚本同步重写，不再引用任何已删除成员。
##   下部留白属**素材问题**，已在素材侧重出（图生图补全云海），不靠运行时裁图掩盖。
##
## 出图：res://_probe_bg_normal.png（常态，含 UI） / res://_probe_bg_hidden.png（隐藏 UI 全图）

const 探针账号 := "__probe_bgfill__"

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)   # 铁律：探针绝不弹窗打扰老大

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(24)

	var ui: Node = main.get("新UI")
	var 页: Node = ui.get("_页_宗门")
	if 页 == null:
		prints(">>>FAIL 宗门首页为空")
		get_tree().quit()
		return

	var s: float = UITheme.UI_SCALE
	var bg: Control = 页.get("_bg") as Control
	if bg == null:
		prints(">>>FAIL _bg 为空")
		get_tree().quit()
		return

	var tex: Texture2D = null
	if bg is TextureRect:
		tex = (bg as TextureRect).texture
	prints(">>> 皮肤 = %s" % str(Game.get("当前皮肤")))
	prints(">>> 背景纹理尺寸 = %s   （应为 1080x1920）" % (str(tex.get_size()) if tex != null else "null"))
	prints(">>> 背景纹理路径 = %s" % (tex.resource_path if tex != null else "null"))
	if bg is TextureRect:
		prints(">>> stretch_mode = %d   （KEEP_ASPECT_COVERED = %d，应为前者）" % [
			(bg as TextureRect).stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED])
	prints(">>> _bg 逻辑 rect = [%s ~ %s]" % [
		str(bg.offset_left / s) + "," + str(bg.offset_top / s),
		str(bg.offset_right / s) + "," + str(bg.offset_bottom / s)])

	# ① 常态（含 UI）
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_probe_bg_normal.png")

	# ② 隐藏 UI —— 露出完整背景，这是老大真正要看的「完整图」
	页.call("_on_hide_ui_pressed")
	await _settle(40)          # tween 0.45s ≈ 27 帧，留足
	prints(">>> 隐藏后 _hidden_ui = %s" % str(页.get("_hidden_ui")))
	prints(">>> 隐藏后 _bg 逻辑 rect = [%s ~ %s]   （必须与常态完全一致）" % [
		str(bg.offset_left / s) + "," + str(bg.offset_top / s),
		str(bg.offset_right / s) + "," + str(bg.offset_bottom / s)])
	prints(">>> 隐藏后 _bg 逻辑尺寸 = %s x %s" % [str(bg.size.x / s), str(bg.size.y / s)])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_probe_bg_hidden.png")

	prints(">>>SAVED res://_probe_bg_normal.png / _probe_bg_hidden.png")
	get_tree().quit()

func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame
