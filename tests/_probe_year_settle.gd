extends Node

# 「游戏无法启动」回归探针（2026-09-16）
# 线上崩溃栈：结算(period_settlement.gd:100) ← _年结评分(game_state.gd:14426) ← 推演一月(14372)
# 本探针直接复跑 `_年结评分` 全路径，证明该链路不再中断。

func _ready() -> void:
	print("A1_周期评分实例=%s" % str(Game.周期评分 != null))
	print("A2_类型=%d（期望 OBJECT）" % typeof(Game.周期评分))
	var 评分对象 = Game.周期评分
	print("A3_结算方法可调用=%s" % str(评分对象.has_method("结算")))

	# B 段：直打线上崩溃点 —— 年结评分全路径（含 预估月产出() 调用点）
	var 卡 = Game.call("_年结评分")
	if 卡 is Dictionary:
		print("B1_年结评分返回评级=%s 总分=%s" % [str(卡.get("评级", "?")), str(卡.get("总分", "?"))])
		print("B2_明细键数=%d" % int((卡.get("明细", {}) as Dictionary).size()))
	else:
		print("B1_年结评分返回异常=%s" % str(卡))

	# C 段：连续两年结算（验证计数器清零后仍稳）
	var 卡2 = Game.call("_年结评分")
	print("C1_次年结算=%s" % ("ok" if 卡2 is Dictionary else str(卡2)))

	print("PROBE_YEAR_SETTLE_DONE")
	get_tree().quit()
