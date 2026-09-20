extends CanvasLayer

# ToastManager — 全局轻提示（Autoload: ToastManager，CanvasLayer 常驻顶层）。
# show_tip(text, dur) 实例化 toast_item.tscn，居中偏上，淡入 0.2s → 停留 dur → 淡出 0.3s → queue_free。
# 红线：不触碰玩法/数值；纯展示。

const TOAST_SCENE: String = "res://components/toast_item.tscn"

func show_tip(text: String, dur: float = 1.5) -> void:
	var scene: PackedScene = load(TOAST_SCENE) as PackedScene
	if scene == null:
		push_warning("ToastManager: 找不到 toast_item.tscn")
		return
	var toast: Control = scene.instantiate() as Control
	if toast == null:
		return
	add_child(toast)
	var lbl = toast.get_node_or_null("label")
	if lbl is Label:
		(lbl as Label).text = text
	var vp: Viewport = get_viewport()
	var sz: Vector2 = toast.get_combined_minimum_size()
	var 终点: Vector2 = Vector2((vp.size.x - sz.x) / 2.0, vp.size.y * 0.28)
	toast.position = 终点
	toast.modulate.a = 0.0
	# 上浮入场：自下方 14px 升起 + 淡入。纯位移不碰布局基准（toast 走绝对定位）。
	# 位移刻意做小：轻提示是"眼角余光级"反馈，位移大了会抢主线剧情的注意力。
	if UITheme.动效强度 > 0.0:
		toast.position = 终点 + Vector2(0, 14)
	var t: Tween = create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.2)
	t.parallel().tween_property(toast, "position", 终点, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(dur)
	t.tween_property(toast, "modulate:a", 0.0, 0.3)
	t.tween_callback(toast.queue_free)
