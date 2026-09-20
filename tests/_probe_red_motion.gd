extends Node
## 红点 / 弹窗动效探针 —— headless 可跑（不实例化 main.tscn，只测 UITheme 动效层）。
## 用法：<godot> --headless --path . --scene res://tests/_probe_red_motion.tscn
## 断言语义：
##   A 工厂红点自驱：隐藏不起、出场弹入、呼吸、父级显隐不重播、显式显示必重播；
##   B 数字红点：文本 / 胶囊宽度 / 99+ 截断 / 数量变动脉冲；
##   C RedDotManager 驱动数字红点（旧实现探测不存在的方法 ⇒ 角标数字永不更新）；
##   D RedDotBadge（第二套红点控件）单实例只建一个 Dot + 共用同一动效；
##   E 弹窗入场：面板弹入 + 遮罩淡入；准全屏面板（缩放=false）不加缩放；
##   F 抽屉入场：位移起跳并精确回到终点（无累积误差）；
##   G 关动效（动效强度=0）不留残余状态。
## ★ 计时一律用**墙钟**（create_timer / Time.get_ticks_msec）而非「等 N 帧」：
##   headless 下无 vsync，帧率可达数千 ⇒ N 帧可能只有几毫秒，tween 几乎没推进，必误判。

var 失败: int = 0
var 断言: int = 0
var 宿主: Control = null

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(1080, 1920))
	宿主 = Control.new()
	宿主.name = "MotionHost"
	宿主.size = Vector2(1080, 1920)
	add_child(宿主)
	await _帧(2)

	await _测红点工厂()
	await _测数字红点()
	await _测管理器驱动()
	await _测红点徽标()
	await _测弹窗入场()
	await _测抽屉入场()
	await _测关动效()
	_报告()

# ───────── A 工厂红点自驱 ─────────
func _测红点工厂() -> void:
	var 点: Panel = UITheme.make_red_dot(12.0)
	点.name = "ProbeDot"
	点.size = Vector2(27, 27)
	点.visible = false
	宿主.add_child(点)
	await _帧(2)
	_ok(点.scale == Vector2.ONE, "A1 隐藏态不起动画 scale=(%.2f, %.2f)" % [点.scale.x, 点.scale.y])

	点.visible = true
	_ok(点.scale.x < 0.5, "A2 出场瞬间 scale=%.3f < 0.5（弹入起点同帧写入）" % 点.scale.x)
	await get_tree().create_timer(0.45).timeout
	_ok(absf(点.scale.x - 1.0) < 0.12, "A3 0.45s 后 scale=%.3f 收敛到 1 附近" % 点.scale.x)

	var 峰: float = 0.0
	var 始: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - 始 < 500:
		await get_tree().process_frame
		峰 = maxf(峰, 点.scale.x)
	_ok(峰 > 1.005, "A4 呼吸生效（500ms 内缩放峰值 %.4f > 1.005）" % 峰)

	# 父级显隐往返不重播 —— 这正是判据用 visible 而非 is_visible_in_tree 的意义：
	# 父隐藏会向子树传播 visibility_changed，若看 in_tree 就会整屏重播。
	宿主.visible = false
	await _帧(2)
	宿主.visible = true
	await _帧(2)
	_ok(点.scale.x > 0.5, "A5 父级显隐往返不重播 scale=%.3f > 0.5" % 点.scale.x)

	点.visible = false
	await _帧(2)
	_ok(点.scale == Vector2.ONE, "A6 隐藏后复位 scale=%.3f（不留放大残余）" % 点.scale.x)
	点.visible = true
	_ok(点.scale.x < 0.5, "A7 显式重新显示必重播 scale=%.3f < 0.5" % 点.scale.x)
	await get_tree().create_timer(0.45).timeout
	点.queue_free()

# ───────── B 数字红点 ─────────
func _测数字红点() -> void:
	var 点: Panel = UITheme.make_red_dot_number(5, 20.0)
	点.name = "ProbeNumDot"
	宿主.add_child(点)
	await _帧(2)
	var 标: Label = 点.get_node_or_null("Num") as Label
	_ok(标 != null, "B1 数字红点含 Num 子标签")
	if 标 == null:
		return
	_ok(标.text == "5", "B2 初值文本 = %s" % 标.text)
	var 宽0: float = 点.custom_minimum_size.x
	UITheme.设置红点数量(点, 128)
	_ok(标.text == "99+", "B3 超 99 截断 = %s" % 标.text)
	var 宽1: float = 点.custom_minimum_size.x
	_ok(宽1 > 宽0, "B4 胶囊宽度随内容变化 %.1f → %.1f" % [宽0, 宽1])

	await get_tree().create_timer(0.5).timeout
	UITheme.设置红点数量(点, 20)
	var 峰: float = 0.0
	var 始: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - 始 < 260:
		await get_tree().process_frame
		峰 = maxf(峰, 点.scale.x)
	# 脉冲峰值 1.18 明确高于呼吸峰值 1.07 ⇒ 可区分「脉冲发生了」而非只是呼吸相位
	_ok(峰 > 1.10, "B5 数量变动触发脉冲（峰值 %.4f > 1.10，高于呼吸上限 1.07）" % 峰)
	点.queue_free()

# ───────── C RedDotManager 驱动 ─────────
func _测管理器驱动() -> void:
	var 管: Node = (load("res://red_dot_manager.gd") as GDScript).new()
	管.name = "ProbeRedDotMgr"
	add_child(管)
	var 点: Panel = UITheme.make_red_dot_number(0, 20.0)
	点.name = "MgrNumDot"
	宿主.add_child(点)
	await _帧(2)
	管.call("注册红点", "探针_数字", 点)
	管.call("设置红点数量", "探针_数字", 7)
	await _帧(2)
	var 标: Label = 点.get_node_or_null("Num") as Label
	_ok(标 != null and 标.text == "7", "C1 管理器驱动数字红点文本 = %s（旧实现恒为 0）" % (标.text if 标 != null else "null"))
	_ok(点.visible, "C2 数量 > 0 时红点可见")

	点.queue_free()
	await _帧(3)
	管.call("刷新所有")
	var 表: Dictionary = 管.get("_红点节点")
	var 空: bool = true
	if 表.has("探针_数字"):
		空 = (表["探针_数字"] as Array).is_empty()
	_ok(空, "C3 失效节点已被剔除（数组不再随切页无限增长）")
	管.queue_free()

# ───────── D RedDotBadge（第二套红点控件）─────────
func _测红点徽标() -> void:
	var 徽 = (load("res://ui/red_dot_badge.gd") as GDScript).new()
	徽.name = "ProbeBadge"
	徽.call("设置类型", "dot")   # 入树前调用 ⇒ 曾导致 _ready 再建一份，叠出两个圆点
	宿主.add_child(徽)
	await _帧(3)
	var 圆点数: int = 0
	for ch in 徽.get_children():
		if ch.name == "Dot":
			圆点数 += 1
	_ok(圆点数 == 1, "D1 单实例只建一个 Dot（实得 %d；旧实现叠两个致红点错位重叠）" % 圆点数)
	徽.visible = false
	await _帧(2)
	徽.visible = true
	_ok(徽.scale.x < 0.5, "D2 RedDotBadge 出场弹入 scale=%.3f < 0.5" % 徽.scale.x)
	await get_tree().create_timer(0.45).timeout
	_ok(absf(徽.scale.x - 1.0) < 0.12, "D3 RedDotBadge 收敛 scale=%.3f" % 徽.scale.x)
	徽.queue_free()

# ───────── E 弹窗入场 ─────────
func _测弹窗入场() -> void:
	var 遮: ColorRect = ColorRect.new()
	遮.name = "ProbeShade"
	遮.color = Color(0, 0, 0, 0.6)
	遮.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	宿主.add_child(遮)
	var 面: PanelContainer = PanelContainer.new()
	面.name = "ProbePanel"
	面.custom_minimum_size = Vector2(400, 300)
	遮.add_child(面)
	await _帧(2)

	UITheme.弹窗入场(面, 遮, 0.22, true)
	_ok(面.scale.x < 0.95, "E1 入场瞬间面板 scale=%.3f < 0.95" % 面.scale.x)
	_ok(遮.modulate.a < 0.05, "E2 入场瞬间遮罩 alpha=%.3f ≈ 0（先暗后亮）" % 遮.modulate.a)
	await get_tree().create_timer(0.5).timeout
	_ok(absf(面.scale.x - 1.0) < 0.02, "E3 面板收敛 scale=%.4f ≈ 1" % 面.scale.x)
	_ok(遮.modulate.a > 0.95, "E4 遮罩收敛 alpha=%.3f ≈ 1" % 遮.modulate.a)

	var 面2: PanelContainer = PanelContainer.new()
	面2.name = "ProbeFullPanel"
	面2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	面2.offset_left = 16.0
	面2.offset_right = -16.0
	遮.add_child(面2)
	await _帧(2)
	UITheme.弹窗入场(面2, null, 0.2, false)
	_ok(面2.scale == Vector2.ONE, "E5 缩放=false（准全屏面板）scale 保持 1，不做弹入")
	await get_tree().create_timer(0.4).timeout
	_ok(面2.modulate.a > 0.95, "E6 缩放=false 仍完成淡入 alpha=%.3f" % 面2.modulate.a)
	遮.queue_free()

# ───────── F 抽屉入场 ─────────
func _测抽屉入场() -> void:
	var 屉: Panel = Panel.new()
	屉.name = "ProbeDrawer"
	屉.size = Vector2(300, 200)
	屉.position = Vector2(100, 500)
	宿主.add_child(屉)
	var 终点: Vector2 = 屉.position
	UITheme.抽屉入场(屉, null, Vector2(0, 1), 140.0, 0.26)
	_ok(屉.position.y >= 终点.y + 139.0, "F1 抽屉起跳 y=%.1f（终点 %.1f + 140）" % [屉.position.y, 终点.y])
	_ok(屉.modulate.a < 0.05, "F2 抽屉起跳 alpha=%.3f ≈ 0" % 屉.modulate.a)
	await get_tree().create_timer(0.5).timeout
	_ok(absf(屉.position.y - 终点.y) < 1.0, "F3 抽屉精确回到终点 y=%.3f（误差 < 1，无累积）" % 屉.position.y)
	_ok(屉.modulate.a > 0.95, "F4 抽屉完成淡入 alpha=%.3f" % 屉.modulate.a)
	屉.queue_free()

# ───────── G 关动效 ─────────
func _测关动效() -> void:
	var 旧: float = UITheme.动效强度
	UITheme.动效强度 = 0.0

	var 点: Panel = UITheme.make_red_dot(12.0)
	点.size = Vector2(27, 27)
	点.visible = false
	宿主.add_child(点)
	await _帧(2)
	点.visible = true
	await _帧(2)
	_ok(点.scale == Vector2.ONE, "G1 关动效：红点出场不留缩放残余 %.3f" % 点.scale.x)

	var 面: PanelContainer = PanelContainer.new()
	面.custom_minimum_size = Vector2(400, 300)
	宿主.add_child(面)
	await _帧(2)
	UITheme.弹窗入场(面, null, 0.22, true)
	_ok(面.scale == Vector2.ONE and 面.modulate.a >= 0.99, "G2 关动效：弹窗即时可见 scale=%.3f alpha=%.3f" % [面.scale.x, 面.modulate.a])

	var 屉: Panel = Panel.new()
	屉.size = Vector2(300, 200)
	屉.position = Vector2(50, 300)
	宿主.add_child(屉)
	var 终: Vector2 = 屉.position
	UITheme.抽屉入场(屉, null, Vector2(0, 1), 140.0, 0.26)
	_ok(屉.position == 终 and 屉.modulate.a >= 0.99, "G3 关动效：抽屉不位移且即时可见")

	UITheme.动效强度 = 旧
	点.queue_free()
	面.queue_free()
	屉.queue_free()

func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败 += 1
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败])
	prints(">>>PROBE_RED_MOTION_%s" % ("FAIL" if 失败 > 0 else "PASS"))
	get_tree().quit(1 if 失败 > 0 else 0)

func _帧(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
