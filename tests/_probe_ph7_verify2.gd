extends Node

## PH7-VERIFY-2 · Part1 用户可见抽验（headless，只读断言）
## 背景：Batch 1A 做了 362 处文案替换，需证明「改对了且没改坏功能」。
## 用法：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_verify2.tscn
## 判据：末行 >>>PART1_RESULT=PASS。仅断言节点/属性/状态，不截图。

func _ready() -> void:
	prints("=== PH7-VERIFY-2 Part1 启动 ===")
	var fails: Array = []

	# 先落一个新档，确保 Game 就绪（系统解锁引擎 / 声望等真实状态）
	Game.load_game("acc_ph7v2_" + str(int(Time.get_unix_time_from_system())))

	# ── P1.1 纪事首日可点 ──
	var 纪事: bool = SystemUnlock.入口可显示("纪事")
	prints(">>>P1.1 SystemUnlock.入口可显示(纪事)=", 纪事, "（期望 true）")
	if not 纪事:
		fails.append("P1.1")

	# ── P1.2 弟子名录「道行降」真降序（抓「显示串改了、比较键没改」类静默缺陷）──
	var page = load("res://ui/page_disciple.gd").new()
	page._sort_mode = "道行降"
	var 列表: Array = [{"战力": 10}, {"战力": 30}, {"战力": 20}]
	page._apply_sort(列表)
	var 序: Array = []
	for d in 列表:
		序.append(int(d["战力"]))
	var 真降序: bool = (序.size() == 3 and 序[0] == 30 and 序[1] == 20 and 序[2] == 10)
	prints(">>>P1.2 道行降 排序后=", 序, " 真降序=", 真降序, "（期望 [30, 20, 10]）")
	if not 真降序:
		fails.append("P1.2")
	page.free()

	# ── P1.3 宗门战报文案：含「道行」不含「战力」 ──
	var 日志: Array = []
	# 注意：_resolve_timeout 要求调用方预先初始化 battle_state["战斗日志"]（zongmen_battle.gd:395/400）
	var st1: Dictionary = {
		"攻方队伍": [{"队员": [{"当前生命": 100, "最大生命": 100, "战斗属性": {"战力": 100}}]}],
		"守方队伍": [{"队员": [{"当前生命": 100, "最大生命": 100, "战斗属性": {"战力": 10}}]}],
		"战斗日志": [],
	}
	ZongmenBattle._resolve_timeout(st1)
	日志.append_array(st1.get("战斗日志", []))
	var st2: Dictionary = {"攻方队伍": [], "守方队伍": [], "战斗日志": []}
	ZongmenBattle._resolve_timeout(st2)
	日志.append_array(st2.get("战斗日志", []))
	var 全串: String = " ｜ ".join(日志)
	var 含道行: bool = 全串.contains("道行")
	var 含战力: bool = 全串.contains("战力")
	prints(">>>P1.3 战报=", 全串)
	prints(">>>P1.3 含道行=", 含道行, " 含战力=", 含战力, "（期望 true / false）")
	if not (含道行 and not 含战力):
		fails.append("P1.3")

	# ── P1.4 让利数值 = (1 − 价格乘数) × 100；声望2 → 折扣0.9 → 让利10 ──
	Game.声望 = 2
	var dr: float = Game.坊市折扣率()
	var 让利: int = int(round((1.0 - dr) * 100))
	prints(">>>P1.4 声望=2 折扣率=", dr, " 让利=", 让利, "（期望 0.9 / 10）")
	if not (absf(dr - 0.9) < 0.0001 and 让利 == 10):
		fails.append("P1.4")

	# ── P1.5 每日重置小时 === 8 ──
	var 时: int = int(Game.每日重置小时)
	prints(">>>P1.5 每日重置小时=", 时, "（期望 8）")
	if 时 != 8:
		fails.append("P1.5")

	prints(">>>PART1_RESULT=", "PASS" if fails.is_empty() else ("FAIL:" + ", ".join(fails)))
	prints(">>>PART1_ALL_DONE")
	get_tree().quit(0 if fails.is_empty() else 1)
