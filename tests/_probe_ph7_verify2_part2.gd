extends Node

## PH7-VERIFY-2 · Part2 FTUE 复验（headless，只读断言）
## 依赖：Batch 1C 已落盘（main.gd:3975 `if Game.引导阶段 >= 6:`；原「过引导期即熄灯」elif 已整段删除）。
## 断言：① 高亮框锚点落在 TopBar/EntryBtn_灵石  ② 收尾后 新手目标链激活==true
##       ③ 随后（读档回读 + 再进主界面）激活仍 true（Batch 1B 净回归的回归位）  ④ 宗门_宗务红点亮
##       ⑤ 累计游戏日==1；附：legacy 档（缺 newbie_active）熄灯迁移
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_verify2_part2.tscn
## 判据：末行 >>>PART2_RESULT=PASS

func _ready() -> void:
	prints("=== PH7-VERIFY-2 Part2 启动 ===")
	var fails: Array = []

	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FATAL main.tscn 加载失败")
		get_tree().quit(1)
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await get_tree().process_frame
	prints(">>>P2.0 main.tscn 已实例化")

	# ── 新档：全新账号 → 强制 FTUE 起始态 ──
	var acc: String = "acc_ph7v2p2_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(acc)
	if main.has_method("_标题_关闭"):
		main._标题_关闭()
	Game.引导阶段 = 0
	Game.新手目标链激活 = false
	Game.新手完成列表 = []
	Game.累计游戏日 = 0
	prints(">>>P2.0b 新档态 账号=", acc, " 引导阶段=", Game.引导阶段, " 激活=", Game.新手目标链激活, " 累计游戏日=", Game.累计游戏日)

	# 走真实进入主界面路径（新UI 分支；引导阶段=0 → M2 块 no-op）
	await main._进入主界面()
	prints(">>>P2.1 _进入主界面() 返回")

	# ── ⑤ 累计游戏日 == 1（首日保底推演 1 日）──
	var a5: bool = int(Game.累计游戏日) == 1
	prints(">>>P2.5 累计游戏日=", Game.累计游戏日, "（期望==1）→ ", a5)
	if not a5:
		fails.append("P2.5")

	# ── 序章推进：不断按按钮直到「开始治宗」（引导阶段 0→1）──
	var 层: Variant = main.get("入门指引_层")
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
	prints(">>>P2.2 序章按钮序列=", pressed_log, " 引导阶段=", Game.引导阶段)

	# ── ① 高亮框锚点：应解析到 TopBar/EntryBtn_灵石（top_bar.gd:312 建）──
	var 锚: Control = main._入门指引_锚点()
	var 锚名: String = "" if 锚 == null else String(锚.name)
	var frame_cnt: int = 0
	if 层 != null and is_instance_valid(层):
		for c in 层.get_children():
			if c is Panel:   # 高亮框（Panel，非 PanelContainer）
				frame_cnt += 1
	# 复核真实节点存在（顶栏 EntryBtn_灵石）
	var node_ok: bool = false
	var 新UIv: Variant = main.get("新UI")
	if 新UIv != null and is_instance_valid(新UIv):
		var tb: Node = 新UIv.find_child("TopBar", true, false)
		if tb != null and tb.find_child("EntryBtn_灵石", true, false) != null:
			node_ok = true
	var a1: bool = (锚名 == "EntryBtn_灵石")
	prints(">>>P2.1* 锚点名=", 锚名, " 期望=EntryBtn_灵石 → ", a1, " ｜ 高亮框(Panel)数=", frame_cnt, " ｜ 顶栏节点存在=", node_ok)
	if not a1:
		fails.append("P2.1*")

	# ── ② 收尾后 新手目标链激活 == true ──
	main._入门指引_收尾()
	await get_tree().process_frame
	var a2: bool = bool(Game.新手目标链激活) and int(Game.引导阶段) == 6
	prints(">>>P2.2* 收尾后 引导阶段=", Game.引导阶段, " 激活=", Game.新手目标链激活, "（期望==true）→ ", a2)
	if not a2:
		fails.append("P2.2*")

	# ── ④ 宗门_宗务红点亮 ──
	if main.has_method("_刷新红点"):
		main._刷新红点()
	await get_tree().process_frame
	var 宗务红: bool = false
	if UITheme.红点源 != null:
		宗务红 = bool(UITheme.红点可见("宗门_宗务"))
	var a4: bool = 宗务红
	prints(">>>P2.4 红点源存在=", UITheme.红点源 != null, " 宗门_宗务=", 宗务红, "（期望 true）→ ", a4)
	if not a4:
		fails.append("P2.4")

	# ── ③ 随后（读档回读 + 再进主界面）激活仍 true ──（Batch 1B 净回归位）
	Game.load_game(acc)   # 持久化回读：引导阶段=6 / newbie_active=true
	await get_tree().process_frame
	var 激活_读档: bool = bool(Game.新手目标链激活)
	# 释放旧 新UI，模拟「再次进入」而不产生重复 UI
	var old: Variant = main.get("新UI")
	if old != null and is_instance_valid(old):
		main.set("新UI", null)
		old.queue_free()
		await get_tree().process_frame
	await main._进入主界面()
	var 激活_再进: bool = bool(Game.新手目标链激活)
	var a3: bool = 激活_读档 and 激活_再进
	prints(">>>P2.3 读档后激活=", 激活_读档, " 再进主界面后激活=", 激活_再进, "（期望均 true）→ ", a3)
	if not a3:
		fails.append("P2.3")

	# ── 附：legacy 档（缺 newbie_active）熄灯迁移 ──
	var aL: bool = await _legacy_迁移断言()
	if not aL:
		fails.append("P2.legacy")

	prints(">>>PART2_RESULT=", "PASS" if fails.is_empty() else ("FAIL:" + ", ".join(fails)))
	prints(">>>PART2_ALL_DONE")
	get_tree().quit(0 if fails.is_empty() else 1)

# 构造 legacy 档：存盘 → 手工删 newbie_active/newbie_done 键 → 回读 → 断言「熄灯迁移」
func _legacy_迁移断言() -> bool:
	var accL: String = "acc_ph7v2legacy_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(accL)          # 全新账号 → 初始建宗（新手目标链激活=false）
	await get_tree().process_frame
	Game.引导阶段 = 6
	Game.save_game()              # 写盘（含 newbie_active=false）
	await get_tree().process_frame

	var path: String = Game.账号存档路径(accL)
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		prints(">>>P2.legacy 存档打开失败 path=", path, " → 未能构造 legacy 档")
		return false
	var dd: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if dd == null or not (dd is Dictionary):
		prints(">>>P2.legacy JSON 解析失败 → 未能构造 legacy 档")
		return false
	dd.erase("newbie_active")
	dd.erase("newbie_done")
	var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	w.store_string(JSON.stringify(dd))
	w.close()

	Game.load_game(accL)          # 回读：缺 newbie_active → 熄灯迁移分支
	await get_tree().process_frame
	var 激活L: bool = bool(Game.新手目标链激活)
	var 红L: bool = Game.新手_有红点()
	var ok: bool = 激活L == true and 红L == false
	prints(">>>P2.legacy 迁移后 激活=", 激活L, " 新手_有红点=", 红L, "（期望 true / false）→ ", ok)
	return ok

func _find_button(root: Node) -> Button:
	for c in root.get_children():
		if c is Button:
			return c
		var r: Button = _find_button(c)
		if r != null:
			return r
	return null
