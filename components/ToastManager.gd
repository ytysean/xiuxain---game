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
	toast.position = Vector2((vp.size.x - sz.x) / 2.0, vp.size.y * 0.28)
	toast.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(dur)
	t.tween_property(toast, "modulate:a", 0.0, 0.3)
	t.tween_callback(toast.queue_free)
