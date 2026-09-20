extends Node

# 探针：成就 toast 落点的真实坐标系标定（#009 弟子页 before 审计 2026-09-16）
#
# 背景：`AchievementPopupManager._播放动画()` 用 `popup.position.y = 落点` 定位，但实机截图
# 里弹窗的视觉位置与「落点 ÷ UI_SCALE = 逻辑值」的推算对不上（差 ~36 逻辑）。可能原因有二：
#   ① CanvasLayer 下 Control 的 position 不在预期的 1080×1920 坐标系；
#   ② 截图抓拍在 tween 进行中途（TRANS_BACK 前段超调），拍到的不是终态。
# 本探针等 tween 完全结束（1.4s > 0.5s 滑入）后再读 position，把 ① 钉死；
# 用 `vp.size` 与 `content_scale_size` 对照，确认单位到底是设计空间还是别的。

func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ProbeLayer"
	add_child(layer)

	var mgr: CanvasLayer = load("res://components/AchievementPopupManager.gd").new()
	mgr.name = "PopupMgr"
	layer.add_child(mgr)
	await get_tree().process_frame

	var vp: Viewport = layer.get_viewport()
	print("[探针] vp.size=", vp.size,
		" content_scale_size=", vp.content_scale_size,
		" content_scale_mode=", vp.content_scale_mode,
		" content_scale_factor=", vp.content_scale_factor)
	print("[探针] UI_SCALE=", UITheme.UI_SCALE,
		"  视口高/UI_SCALE=", vp.size.y / UITheme.UI_SCALE)

	mgr.show_achievement("功绩堂", "弟子盈门", "", Color(0.9, 0.7, 0.2))
	# 1.4s ≫ 滑入 0.5s（TRANS_BACK 超调 + 回弹），确保读到终态
	await get_tree().create_timer(1.4).timeout

	var found: int = 0
	for c in mgr.get_children():
		if c is Control:
			var cc: Control = c as Control
			var 逻辑y: float = cc.position.y / UITheme.UI_SCALE
			print("[探针] popup pos=", cc.position, " size=", cc.size,
				" min=", cc.get_combined_minimum_size())
			print("[探针]   换算 逻辑y=", "%.1f" % 逻辑y,
				"  (顶栏=0~84 逻辑，弟子页筛选条=103~125 逻辑)")
			print("[探针]   顶栏占比 = ", "%.2f%%" % (逻辑y * 2.25 / vp.size.y * 100.0))
			found += 1
	if found == 0:
		print("[探针] !! 未找到 Control 子节点 —— 弹窗创建路径可能异常")

	print("[探针] PROBE_POPUP_POS_DONE")
	get_tree().quit()
