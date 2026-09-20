extends Node

## 真实进入游戏链路集成自检（端到端层 —— 全项目覆盖面最宽的 harness）
##
## ── headless harness 家族分工（互补，勿合并）──────────────────────────
##   headless_smoke            直连 Game autoload：主循环 100 月 + 各系统动作 + 存读档 + 死亡路径
##   headless_ui_compile_all   只 load() 全部 ui/*.gd 查 Parse Error（不实例化、不建树）
##   headless_ui_decouple      game_ui 三容器过滤 / 紧凑重排 / 无空洞断言
##   本脚本（main_enter）      唯一覆盖「main.tscn 实例化 → _登录_进入 → game_ui.tscn 真实装配
##                            → 全部二级页 + 三级页详情可达」的端到端链路
##
## ── 为什么必须有它 ────────────────────────────────────────────────
## 上面三者都**不实例化 main.tscn**。main.gd(6000+ 行) 的启动分支、登录流程、UI 装配顺序、
## 心跳/信号连接里的任何一处回归（节点缺失 / 信号断连 / 装配期空引用），它们全都逃得过去。
## 本 harness 是这条链路的唯一防线 —— 覆盖「玩家双击图标到首页可点」的完整一致性。
##
## 起源：项目根历史脚本 _test_main_enter.gd（SceneTree + --script 版），2026-09-12 自归档中
##   捞出转正：改为 --scene 模式（Node + .tscn）与既有 harness 同构，并去掉对特定账号存档的依赖。
##
## 运行：MSYS_NO_PATHCONV=1 <godot> --headless --path <proj> --scene res://tests/headless_main_enter.tscn
## 判据：末行出现 >>>MAIN_ENTER_ALL_DONE，且全程无 SCRIPT ERROR / FATAL。


func _ready() -> void:
	prints("=== 真实进入游戏链路自检启动 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return

	# ---------- 阶段1：真实实例化 main.tscn（走 main.gd _ready 全部分支）----------
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)  # add_child 同步触发 _ready
	prints(">>>阶段1 main.tscn 已实例化（_ready 已完成）")

	# ---------- 阶段2：真实「点进入游戏」→ _登录_进入(acc) ----------
	# 不预建宗：load_game 对全新账号自带「初始建宗 + 传承事件 + 账号摘要 + save + 重建司职
	# + 复检里程碑/成就」兜底，这条首启分支本身就是我们要覆盖的真实路径。
	main._登录_进入({"id": "acc_headless"})
	prints(">>>阶段2 _登录_进入 调用完成")

	var ui: Node = main.get("新UI")
	if ui == null:
		printerr(">>>FAIL 新UI 为空（启用新UI 分支未构建 game_ui.tscn）")
		get_tree().quit()
		return
	prints(">>>阶段2 主界面 game_ui 已构建，弟子数=", Game.弟子列表.size())

	# ---------- 阶段3：遍历全部二级页（ENTRY_SUB_PAGES 是唯一活路由表）----------
	var subs: Dictionary = ui.ENTRY_SUB_PAGES
	for id in subs.keys():
		ui._show_sub_page(id, subs[id])
	prints(">>>阶段3 全部二级页 OK，数量=", subs.size())

	# ---------- 阶段4：三级页（详情 / 商店类）----------
	var n: int = 0
	for d in Game.弟子列表:
		ui._open_disciple_detail(d)
		n += 1
		if n >= 3:
			break
	prints(">>>阶段4 弟子详情 x", n, " OK")
	ui._open_master_detail()
	prints(">>>阶段4 宗主详情 OK")
	ui._open_skin_shop()
	ui._open_master_skin_shop()
	prints(">>>阶段4 仙衣阁 / 宗主仙衣阁 OK")

	# ---------- 阶段5：在线心跳链路（推演 + 全页刷新）----------
	Game.推演一月(1)
	ui.refresh_all()
	prints(">>>阶段5 推演一月(1) + refresh_all OK")

	prints(">>>MAIN_ENTER_ALL_DONE（如上方无 SCRIPT ERROR 则全部通过）")
	get_tree().quit()
