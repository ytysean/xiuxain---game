# ui_tween.gd — 《太玄宗门录》S1 UI 重架构 · 通用补间动画（Autoload: UITween）
# 职责：按钮按压回弹、淡入淡出、数字滚动等通用动效。
# 铁律：每次都用 create_tween() 新建独立 Tween，避免全局 Tween 互相打断/冲突。
#
# ★ 2026-09-16 职责边界（避免后人重复造轮子）：
#   - **真实指针按压**的反馈由 `ui_theme.gd` 的全局 `node_added` 钩子统一负责
#     （任何 BaseButton 入树即自动获得 0.94 按下 / TRANS_BACK 回弹），**无需在此调用**。
#   - `button_press()` 保留给**程序化触发**的确认回弹（如点完卡片让自身弹一下），
#     它由 `pressed` 信号之后手动调用，与上面的全局钩子叠加时后者接管 scale，
#     观感仍是一条连续的回弹曲线，不会打架。
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

# 数字滚动：从**当前显示文本**解析出的整数滚到 target。
# 格式：可选的 int→String 格式化回调。**带千分位 / 万·亿后缀时必传**，
#   否则滚动中段会出现 "1,448" → "1449" 这种格式突变（跳字）。
# 起始值从 label.text 反解（而非从 1 开始）：连续刷新时能接着上一段滚动继续，
#   不会每次都从 0 重来。文本非数字（如占位「—」）时视为 0 ⇒ 首次显示自带「滚上来」的入场感。
# 值相等则直接返回，不发 tween —— 本函数会被高频只读刷新调用。
func tween_number(label: Label, target: int, dur: float = 0.5, 格式: Callable = Callable()) -> void:
	if label == null or not is_instance_valid(label):
		return
	var 从: int = _文本转整数(label.text)
	if 从 == target:
		return
	var t: Tween = create_tween()
	t.tween_method(func(v: float) -> void:
			var 值: int = int(roundf(v))
			label.text = str(格式.call(值) if 格式.is_valid() else str(值)),
		float(从), float(target), dur)

# 把「1,448」/「1.2万」/「3亿」/「—」反解回整数。仅用于滚动的起始值，精度不敏感。
func _文本转整数(s: String) -> int:
	var t: String = s.strip_edges().replace(",", "")
	if t == "":
		return 0
	var 倍率: int = 1
	if t.ends_with("亿"):
		倍率 = 100000000
		t = t.substr(0, t.length() - 1)
	elif t.ends_with("万"):
		倍率 = 10000
		t = t.substr(0, t.length() - 1)
	if not t.is_valid_float():
		return 0
	return int(roundf(t.to_float() * float(倍率)))
