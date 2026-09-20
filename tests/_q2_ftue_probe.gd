extends Node

## PH6-Q2 独立验收探针：证明 S0 FTUE 在新 UI 下**真实建节点**（M1/M2）
## 背景：本事故根因是"代码写好、所有闸门全绿、实机零发生"，故本探针不采信任何报告、
##       不跑静态闸门，而是**在 headless 下走真实进入主界面路径并检查实际节点树**。
## 运行：MSYS_NO_PATHCONV=1 <godot_console> --headless --path <proj> --scene res://tests/_q2_ftue_probe.tscn
## 只读：不修改 main.gd / game_state.gd。判据：末行 >>>Q2_RESULT=PASS。

func _ready() -> void:
	prints("=== PH6-Q2 FTUE 接线独立验收探针启动 ===")
	prints(">>>STEP0 环境 Game=", Game != null, " UITheme=", UITheme != null)

	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FATAL main.tscn 加载失败")
		get_tree().quit(1)
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await get_tree().process_frame
	prints(">>>STEP1 main.tscn 已实例化（main.gd _ready 已完成）")

	# 新档状态：每次用全新账号 id → 真实新档（无离线时间戳），再显式强制 FTUE 起始态，保证可复现
	var 探针账号: String = "acc_q2_probe_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(探针账号)
	if main.has_method("_标题_关闭"):
		main._标题_关闭()
	Game.引导阶段 = 0
	Game.新手目标链激活 = false
	Game.累计游戏日 = 0
	prints(">>>STEP2 新档态就绪: 账号=", 探针账号, " 引导阶段=", Game.引导阶段, " 新手目标链激活=", Game.新手目标链激活, " 累计游戏日=", Game.累计游戏日)

	# ★★ 走真实进入主界面代码路径（M1/M2 就在 _进入主界面 内）★★
	await main._进入主界面()
	prints(">>>STEP3 _进入主界面() 已返回（新UI 分支 + M1 补调 _入门指引_初始化）")

	# [M4] 首日保底推进 1 游戏日：断言 累计游戏日 == 1
	prints(">>>STEP3b [M4] 累计游戏日=", Game.累计游戏日, "（期望==1）")
	# [M4+] 宗务红点：显式刷新红点系统后读「真实状态源」UITheme.红点源
	if main.has_method("_刷新红点"):
		main._刷新红点()
	await get_tree().process_frame
	var 宗务红: bool = false
	if UITheme.红点源 != null:
		宗务红 = bool(UITheme.红点可见("宗门_宗务"))
	prints(">>>STEP3c [M4+] 红点源存在=", UITheme.红点源 != null, " 宗门_宗务红点=", 宗务红, "（期望 true）")

	var 层: Variant = main.get("入门指引_层")
	prints(">>>STEP4 入门指引_层 存在=", 层 != null)
	if 层 == null:
		printerr(">>>FAIL 入门指引_层 为 null ⇒ M1 未生效（_入门指引_初始化 未建层）")
		prints(">>>Q2_RESULT=FAIL")
		prints(">>>Q2_ALL_DONE")
		get_tree().quit(1)
		return

	prints(">>>STEP5 入门指引_层.visible=", 层.visible)
	prints(">>>STEP6 子节点清单 count=", 层.get_child_count())
	for c in 层.get_children():
		prints("      child: name=", c.name, " class=", c.get_class(), " visible=", c.visible)

	var panel_before: int = 0
	for c in 层.get_children():
		if c.get_class() == "PanelContainer":
			panel_before += 1
	prints(">>>STEP7 序章面板(PanelContainer)数=", panel_before)

	# 模拟逐屏推进序章（「继续」×N → 末屏「开始治宗」）
	var pressed_log: String = ""
	for i in range(8):
		var b: Button = _find_button(层)
		if b == null:
			break
		var t: String = b.text
		pressed_log += ("[%d]%s " % [i, t])
		b.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		if t == "开始治宗":
			break
	prints(">>>STEP8 序章按钮按下序列: ", pressed_log)

	prints(">>>STEP9 序章结束后 引导阶段=", Game.引导阶段, "（期望==1）")
	var panel_after: int = 0
	var colorrect_after: int = 0
	for c in 层.get_children():
		if c.get_class() == "PanelContainer":
			panel_after += 1
		elif c.get_class() == "ColorRect":
			colorrect_after += 1
	prints(">>>STEP10 刷新后 步骤气泡(PanelContainer)数=", panel_after, " 遮罩(ColorRect)数=", colorrect_after, "（气泡期望>=1）")
	prints(">>>STEP11 层.visible=", 层.visible)

	prints(">>>STEP12 Game.新手_有红点()=", Game.新手_有红点(), "（期望 true；M2 已激活目标链）")
	prints(">>>STEP13 Game.新手目标链激活=", Game.新手目标链激活)

	var 项1_M4: bool = int(Game.累计游戏日) == 1
	var 项2_M2: bool = bool(Game.新手目标链激活)
	var 项3_FTUE: bool = (panel_before >= 1) and bool(层.visible) and (panel_after >= 1)
	var 项4_红点: bool = 宗务红
	prints(">>>断言1 M4 累计游戏日==1: ", 项1_M4)
	prints(">>>断言2 M2 新手目标链激活==true: ", 项2_M2)
	prints(">>>断言3 FTUE 序章/气泡节点存在: ", 项3_FTUE)
	prints(">>>断言4 宗门_宗务红点亮: ", 项4_红点)
	var pass_ok: bool = 项1_M4 and 项2_M2 and 项3_FTUE and 项4_红点
	prints(">>>Q2_RESULT=", "PASS" if pass_ok else "FAIL")
	prints(">>>Q2_ALL_DONE")
	get_tree().quit(0 if pass_ok else 1)

func _find_button(root: Node) -> Button:
	for c in root.get_children():
		if c is Button:
			return c
		var r: Button = _find_button(c)
		if r != null:
			return r
	return null
