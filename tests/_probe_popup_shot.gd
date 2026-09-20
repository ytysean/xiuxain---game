extends Node

# 真实渲染下给「成就 toast」拍一张定位快照（#009 弟子页 D1 验收用）
#
# 为什么不用 headless：`--headless` 走 dummy 渲染器，`RenderingServer.frame_post_draw`
# 永不触发 ⇒ 截图为空。故必须真实渲染；窗口由 `--position -6000,-6000` + 本脚本
# 二次兜底移到屏幕外，不打扰用户（与 `tests/ui_full_accept.gd` 同策略）。
#
# 判据：弹窗（高 100 设计）应完整落在顶栏区（y = 0~189 设计）之内。

func _enter_tree() -> void:
	# 尽早移出屏幕，避免任何一帧可见
	get_window().position = Vector2i(-6000, -6000)

func _ready() -> void:
	var w: Window = get_window()
	w.position = Vector2i(-6000, -6000)
	await get_tree().process_frame
	var vp: Viewport = get_viewport()
	print("[弹窗探针] window.size=", w.size, " vp.size=", vp.size,
		" content_scale_size=", vp.content_scale_size)

	# 参照层：顶栏高 189 是 1920 设计空间常量，窗口空间须按比例换算
	var 顶栏底: float = vp.size.y * (189.0 / 1920.0)
	print("[弹窗探针] 顶栏底（窗口空间）= %.1f px  （设计 189 / 1920 × 窗高）. " % 顶栏底)

	var 参照: ColorRect = ColorRect.new()
	参照.name = "TopbarRef"
	参照.color = Color(0.10, 0.18, 0.15)
	参照.position = Vector2.ZERO
	参照.size = Vector2(vp.size.x, 顶栏底)
	add_child(参照)

	var 标线: ColorRect = ColorRect.new()
	标线.name = "TopbarBottomLine"
	标线.color = Color(0.95, 0.80, 0.30)
	标线.position = Vector2(0, 顶栏底 - 2.0)
	标线.size = Vector2(vp.size.x, 2)
	add_child(标线)

	var 标尺: Label = Label.new()
	标尺.name = "RulerLabel"
	标尺.text = "▲ 顶栏底边 = %.0f px（窗口空间）" % 顶栏底
	标尺.position = Vector2(16, 顶栏底 + 4.0)
	标尺.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	UITheme.apply_project_font(标尺, 20, false)
	add_child(标尺)

	# 弹窗：与线上同一条路径
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ProbeLayer"
	add_child(layer)
	var mgr: CanvasLayer = load("res://components/AchievementPopupManager.gd").new()
	mgr.name = "PopupMgr"
	layer.add_child(mgr)
	await get_tree().process_frame
	mgr.show_achievement("功绩堂", "弟子盈门", "宗门弟子已满十人", Color(0.9, 0.7, 0.2))

	# 滑入 tween 0.5s（TRANS_BACK）+ 回弹 → 等 1.6s 确保完全静止，避开「拍到动画中途」
	await get_tree().create_timer(1.6).timeout

	for c in mgr.get_children():
		if c is Control:
			var cc: Control = c as Control
			print("[弹窗探针] popup pos=", cc.position, " size=", cc.size,
				"  → 覆盖窗口 y %.0f~%.0f" % [cc.position.y, cc.position.y + cc.size.y],
				"  顶栏底=%.0f ⇒ " % 顶栏底,
				"在顶栏内 OK" if cc.position.y + cc.size.y <= 顶栏底 + 0.5 else "越界 NG —— 会压到下方可点控件")

	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img == null:
		print("[弹窗探针] !! 取图为空（是否误加了 --headless？）")
	else:
		var p: String = "res://.workbuddy/_popup_probe.png"
		img.save_png(p)
		print("[弹窗探针] 已保存 ", p, "  尺寸=", img.get_size())
	print("[弹窗探针] PROBE_POPUP_SHOT_DONE")
	get_tree().quit()
