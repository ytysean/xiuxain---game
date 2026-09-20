extends Node
## UI 动效层探针（列表错峰入场）—— headless 可跑。
## 用法：<godot> --headless --path . --scene res://tests/_probe_ui_stagger.tscn
## 断言语义：
##   ① `_找首个列表容器()` 能在真实页面里定位到列表容器；
##   ② 入场瞬间：前 N 条 alpha≈0、第 N 条之后 alpha=1（长列表不被整体拖慢）；
##   ③ 收敛：等足墙钟后全部条目 alpha=1（无一条卡在半透明）；
##   ④ 快速重入：连续两次错峰入场，仍全部收敛到 1（旧 tween 被杀、不争夺 modulate）。

const 探针账号 := "__probe_ui_stagger__"
const 上限: int = 10

var 失败: int = 0
var 断言: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(1080, 1920))

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _帧(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _帧(20)

	var ui: Node = main.get("新UI")
	if ui == null:
		_ok(false, "新UI 就绪")
		_报告()
		return
	_ok(true, "新UI 就绪")

	# ① 直连页面：验证容器定位 + 错峰三段式
	var 宿主: Control = Control.new()
	宿主.name = "StaggerHost"
	宿主.size = Vector2(1080, 1920)
	ui.add_child(宿主)
	var 页: Control = (load("res://ui/page_shop.tscn") as PackedScene).instantiate()
	宿主.add_child(页)
	await _帧(16)
	if 页.has_method("refresh"):
		页.call("refresh")
	await _帧(16)

	var 容器: Node = _找列表(页)
	_ok(容器 != null, "page_shop 能定位到列表容器（%s）" % (容器.name if 容器 != null else "null"))
	if 容器 == null:
		_报告()
		return
	var 条目: Array = 容器.get_children()
	_ok(条目.size() >= 3, "列表条目数 %d ≥ 3（错峰有意义）" % 条目.size())
	prints(">>> 列表容器 = %s / 条目 %d" % [容器.name, 条目.size()])

	UITheme.列表错峰入场(页)
	# ★ 同步采样：函数体内已把 alpha 直接写入节点，**不要等帧** ——
	#   实测重页面前 2 帧耗时可达 ~175ms（布局开销），等帧会把首条读到 0.97 而误判失败。
	var 首条: Control = 条目[0] as Control
	var 末条: Control = 条目[条目.size() - 1] as Control
	var 第五: Control = (条目[5] as Control) if 条目.size() > 5 else null
	_ok(首条 != null and 首条.modulate.a < 0.01, "入场瞬间第 1 条 alpha=%.2f < 0.01" % (首条.modulate.a if 首条 != null else -1.0))
	if 第五 != null:
		_ok(第五.modulate.a < 0.01, "入场瞬间第 6 条 alpha=%.2f < 0.01（在错峰带内，尚未起跑）" % 第五.modulate.a)
	if 条目.size() > 上限:
		_ok(末条.modulate.a > 0.95, "第 %d 条（超上限）alpha=%.2f ≈ 1（长列表不整体延迟）" % [条目.size(), 末条.modulate.a])

	# ② 错峰有序：等 0.16s（约首条跑完、第 6 条刚起跑）后，前者的进度必须领先后者
	await get_tree().create_timer(0.16).timeout
	if 第五 != null:
		_ok(首条.modulate.a > 第五.modulate.a, "错峰有序：第 1 条 alpha=%.2f > 第 6 条 alpha=%.2f" % [首条.modulate.a, 第五.modulate.a])

	# ③ 收敛
	await get_tree().create_timer(1.4).timeout
	_ok(全部可见(条目), "等足墙钟后全部条目 alpha=1（无一条卡半透明）")

	# ④ 快速重入：连开两次，仍须收敛
	UITheme.列表错峰入场(页)
	await _帧(3)
	UITheme.列表错峰入场(页)
	await _帧(3)
	await get_tree().create_timer(1.4).timeout
	_ok(全部可见(条目), "连续两次错峰入场后全部条目 alpha=1（旧 tween 已被杀）")

	# ⑤ 真实一级页路径（走 game_ui._show_page）
	ui.call("_show_page", "弟子")
	await _帧(4)
	var 弟子页: Control = ui.get("_current") as Control
	if 弟子页 != null:
		var 弟子容器: Node = _找列表(弟子页)
		if 弟子容器 != null:
			await get_tree().create_timer(1.4).timeout
			_ok(全部可见(弟子容器.get_children()), "game_ui 路径：弟子页列表条目全部收敛 alpha=1")
		else:
			prints(">>>  [--] 弟子页无滚动列表容器，跳过收敛断言")
	else:
		_ok(false, "game_ui 路径：_current 为 null")

	宿主.queue_free()
	_报告()

func 全部可见(条目: Array) -> bool:
	for c in 条目:
		var ctl: Control = c as Control
		if ctl != null and ctl.modulate.a < 0.99:
			return false
	return true

## 探针自带遍历：定位首个 ScrollContainer 的子 VBoxContainer（＝货架/名录）。
## 自带而不复用 UITheme 私有函数，避免探针引用私有 API 被「臆造调用」闸误报。
func _找列表(根: Node) -> Node:
	var 队列: Array = [根]
	while not 队列.is_empty():
		var cur: Node = 队列.pop_front()
		if cur is ScrollContainer:
			for ch in cur.get_children():
				if ch is VBoxContainer:
					return ch
		for ch in cur.get_children():
			队列.append(ch)
	return null

func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败 += 1
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败])
	prints(">>>PROBE_UI_STAGGER_%s" % ("FAIL" if 失败 > 0 else "PASS"))
	get_tree().quit(1 if 失败 > 0 else 0)

func _帧(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
