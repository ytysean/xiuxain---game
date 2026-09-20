extends Node

## PH7-VERIFY-3 §3 · 存档往返断言（headless，只读断言）
## 目的：证明 Batch 1D 的 4 处 guard 修复（main_done/randcd/rtypecd/qcd 由 wjson 改 root）真的有效。
## 手法：赋「非空且可辨识」的值 ⇒ save ⇒ 重新 load ⇒ 断言 4 值完全保持（改前应全丢成 []/{}）。
## 另：独立复核「主线已完成」恢复后的副作用（是否发奖/凭空改资源）+ 可利用路径闭合（重领必被拒）。
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_verify3.tscn
## 判据：末行 >>>VERIFY3_RESULT=PASS

func _ready() -> void:
	prints("=== PH7-VERIFY-3 §3 存档往返断言 启动 ===")
	var fails: Array = []

	var acc: String = "acc_ph7v3_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(acc)
	await get_tree().process_frame

	# 取真实主线 quest_id 样本（1~2 个）
	var ids: Array = []
	if Game.has_method("取主线任务列表"):
		for m in Game.取主线任务列表():
			ids.append(str(m.get("id", "")))
			if ids.size() >= 2:
				break
	prints(">>>V3.0 账号=", acc, " 主线id样本=", ids)

	# 赋非空且可辨识的值
	Game.主线已完成 = ids.duplicate()
	Game.随机事件冷却 = {"__probe_evt": 123456}
	Game.随机事件类型冷却 = {"__probe_type": 654321}
	Game.quest_cooldown = {"__probe_q": 111222}
	Game.save_game()
	await get_tree().process_frame
	prints(">>>V3.1 已赋值并存盘: main_done=", Game.主线已完成, " randcd=", Game.随机事件冷却, " rtypecd=", Game.随机事件类型冷却, " qcd=", Game.quest_cooldown)

	# 记录「load 前」资源基线（load 同步、立即读，避开 deferred 离线结算）
	var 灵石_b: int = int(Game.灵石)
	var 灵气_b: int = int(Game.灵气)
	var 声望_b: int = int(Game.声望)

	# ★ 重新载入 —— 立即断言（不 await，隔离 deferred 离线结算）
	Game.load_game(acc)
	var md: Array = Game.主线已完成
	var rc: Dictionary = Game.随机事件冷却
	var rt: Dictionary = Game.随机事件类型冷却
	var qc: Dictionary = Game.quest_cooldown
	var 灵石_a: int = int(Game.灵石)
	var 灵气_a: int = int(Game.灵气)
	var 声望_a: int = int(Game.声望)
	prints(">>>V3.2 回读: main_done=", md, " randcd=", rc, " rtypecd=", rt, " qcd=", qc)

	var p1: bool = _arr_eq(md, ids)
	var p2: bool = int(rc.get("__probe_evt", 0)) == 123456 and rc.size() == 1
	var p3: bool = int(rt.get("__probe_type", 0)) == 654321 and rt.size() == 1
	var p4: bool = int(qc.get("__probe_q", 0)) == 111222 and qc.size() == 1
	prints(">>>V3.3 往返断言 main_done=", p1, " randcd=", p2, " rtypecd=", p3, " qcd=", p4)
	if not p1: fails.append("main_done")
	if not p2: fails.append("randcd")
	if not p3: fails.append("rtypecd")
	if not p4: fails.append("qcd")

	# 副作用独立复核：load 本身未凭空发奖/改资源（load 恢复存档值 ⇒ 应与 load 前相等）
	var p5: bool = (灵石_a == 灵石_b) and (灵气_a == 灵气_b) and (声望_a == 声望_b)
	prints(">>>V3.4 副作用检查 灵石 ", 灵石_b, "→", 灵石_a, " 灵气 ", 灵气_b, "→", 灵气_a, " 声望 ", 声望_b, "→", 声望_a, " → ", p5)
	if not p5: fails.append("side_effect_grant")

	# 可利用路径闭合证明：已完成的 quest_id 再领 ⇒ 必被拒「已完成」
	var p6: bool = true
	if not ids.is_empty():
		var r: Dictionary = Game.领取主线(str(ids[0]))
		p6 = (r.get("ok", true) == false) and str(r.get("msg", "")) == "已完成"
		prints(">>>V3.5 重领拦截 领取主线(", ids[0], ")=", r, " → ", p6)
	else:
		prints(">>>V3.5 无主线 id 样本，跳过（不影响主断言）")
	if not p6: fails.append("reclaim_guard")

	# 重领失败不得改动 主线已完成 / 资源
	var p7: bool = _arr_eq(Game.主线已完成, ids) and int(Game.灵石) == 灵石_a
	prints(">>>V3.6 重领后 main_done=", Game.主线已完成, " 资源未变=", int(Game.灵石) == 灵石_a, " → ", p7)
	if not p7: fails.append("claim_mutation")

	prints(">>>VERIFY3_RESULT=", "PASS" if fails.is_empty() else ("FAIL:" + ", ".join(fails)))
	prints(">>>VERIFY3_ALL_DONE")
	get_tree().quit(0 if fails.is_empty() else 1)

func _arr_eq(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if str(a[i]) != str(b[i]):
			return false
	return true
