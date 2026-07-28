# ui_tween.gd — 《太玄宗门录》S1 UI 重架构 · 通用补间动画（Autoload: UITween）
# 职责：按钮按压回弹、淡入淡出、数字滚动等通用动效。
# 铁律：每次都用 create_tween() 新建独立 Tween，避免全局 Tween 互相打断/冲突。
extends Node

# 按钮按压回弹：scale 0.95 → 1（约 0.05 + 0.08s），以自身中心为锚点缩放。
func button_press(btn: Control) -> void:
	if btn == null:
		return
	btn.pivot_offset = btn.size * 0.5
	var t: Tween = create_tween()
	t.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.05)
	t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

# 淡入：modulate.a 0 → 1。
func fade_in(node: CanvasItem, dur: float = 0.2) -> void:
	if node == null:
		return
	if node is Control:
		(node as Control).visible = true
	node.modulate.a = 0.0
	var t: Tween = create_tween()
	t.tween_property(node, "modulate:a", 1.0, dur)

# 淡出：modulate.a 1 → 0（不自动隐藏，调用方按需 visible=false）。
func fade_out(node: CanvasItem, dur: float = 0.2) -> void:
	if node == null:
		return
	var t: Tween = create_tween()
	t.tween_property(node, "modulate:a", 0.0, dur)

# 数字滚动：从当前文字整数滚动到 target。
func tween_number(label: Label, target: int, dur: float = 0.5) -> void:
	if label == null:
		return
	var from: int = label.text.to_int()
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void: label.text = str(int(v)), float(from), float(target), dur)
