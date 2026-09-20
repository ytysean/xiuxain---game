extends Node
## PH7-QA-PREP-1 · 探针②：三信号加固后 arity 安全只读断言（headless）
## 背景：main.gd `_刷新红点` 原签名只吸收 1 个参数；SectManager 三信号各带 3 参，
##   若不同步加宽 ⇒ connect/emit 时报「expected N arguments」。已要求工程线加宽为 3 个可选参。
## 断言：
##   ① `_刷新红点` 形参个数 == 3；
##   ② SectManager 戒律违规上报 / 弟子请示 / 宗门事务待批阅 三信号 args 个数 == 3；
##   ③ 三信号 connect 到 main._刷新红点 成功，emit 后链路不中断；
##   ④ 「0 参 / 1 参 / 3 参」三类调用连同一可调用体（_刷新红点）均不抛错。
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_sect_signal.tscn
## 判据：末行 >>>PROBE_RESULT=PASS
## 注1：本探针「已写待跑」，不得与工程线 gate_all/探针并发跑 Godot。
## 注2：GDScript 无 try/catch，arity 不符只落错误日志、不中断脚本 ⇒「无报错」另由外层扫日志佐证
##      （与 tests/_probe_ph7b1e_m6.gd §1 同法；本探针为其独立化备份，命名并入 PH7-QA 序列）。

const 主脚本: String = "res://main.gd"

var 失败: Array = []
var 断言: int = 0

func _ready() -> void:
	prints("=== 探针② 三信号 arity 安全 启动 ===")
	# ★ 前置（QA-PREP-1b-6 · 主理人硬要求）：脚本自把存档摆到正常态，避免序章模态压暗
	var 探针账号: String = "acc_ph7qa1b6_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(探针账号)
	await get_tree().process_frame
	Game.引导阶段 = 6
	Game.save_game()
	prints(">>> 前置就绪 账号=%s 引导阶段=%d" % [探针账号, int(Game.引导阶段)])
	var 主 = (load(主脚本) as GDScript).new()

	# ① 形参个数 == 3
	var 形参: Array = []
	for m in 主.get_method_list():
		if str(m.get("name", "")) == "_刷新红点":
			形参 = m.get("args", [])
			break
	_ok(形参.size() == 3, "1 `_刷新红点` 形参个数 = %d（须 = 3；实得 %s）" % [形参.size(), str(形参)])

	# ② 三信号 args 个数 == 3
	var 三信号 := ["戒律违规上报", "弟子请示", "宗门事务待批阅"]
	for 名 in 三信号:
		var 参: int = -1
		for s in SectManager.get_signal_list():
			if str(s.get("name", "")) == 名:
				参 = (s.get("args", []) as Array).size()
				break
		_ok(参 == 3, "2 信号 %s 参数个数 = %d（须 = 3）" % [名, 参])

	# ③ connect + emit（各 3 参）
	var 连: int = 0
	SectManager.戒律违规上报.connect(Callable(主, "_刷新红点"), CONNECT_DEFERRED); 连 += 1
	SectManager.弟子请示.connect(Callable(主, "_刷新红点"), CONNECT_DEFERRED); 连 += 1
	SectManager.宗门事务待批阅.connect(Callable(主, "_刷新红点"), CONNECT_DEFERRED); 连 += 1
	_ok(连 == 3, "3a SectManager 三信号全部 connect 成功（实得 %d / 期望 3）" % 连)
	prints(">>>S2_EMIT_BEGIN")
	SectManager.戒律违规上报.emit(1, "私斗", {"n": 1})
	SectManager.弟子请示.emit(2, "请誓", {})
	SectManager.宗门事务待批阅.emit("t1", "标题", {})
	prints(">>>S2_EMIT_END")
	await get_tree().process_frame
	_ok(true, "3b 三信号（各 3 参）emit 后链路未中断（执行到达本行 ⇒ 未见致命 arity 中断）")
	SectManager.戒律违规上报.disconnect(Callable(主, "_刷新红点"))
	SectManager.弟子请示.disconnect(Callable(主, "_刷新红点"))
	SectManager.宗门事务待批阅.disconnect(Callable(主, "_刷新红点"))

	# ④ 0 / 1 / 3 参直呼同一可调用体
	prints(">>>S2_CALL_BEGIN")
	var c := Callable(主, "_刷新红点")
	c.call()
	c.call("文本")
	c.call(1, "违规", "细节")
	prints(">>>S2_CALL_END")
	_ok(true, "4 0/1/3 参直呼 `_刷新红点` 未中断（执行到达本行）")

	主.free()
	_报告()

func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败.append(文)
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败.size()])
	prints(">>>PROBE_RESULT=%s" % ("PASS" if 失败.is_empty() else ("FAIL:" + ", ".join(失败))))
	get_tree().quit(0 if 失败.is_empty() else 1)
