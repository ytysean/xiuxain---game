extends Node
## PH7-QA-PREP-1 · 探针③：纪事红点两态只读断言（headless）
## 背景（设计线 §10.3-a P0 待验项）：纪事红点须「有新未读纪事 ⇒ 亮；读后 ⇒ 灭」，须实证、禁凭源码推断。
## 断言：
##   ① 0 条纪事 ⇒ 红点不亮（有未读纪事()=false 且 红点 纪事_未读 是否显示=false）；
##   ② 首日 2 条纪事 ⇒ 红点亮；
##   ③ Game.标记纪事已读() 被调用后 ⇒ 红点消失；
##   ③' 真页 page_chronicle 进树（_enter_tree → 标记纪事已读）后也消失。
## 相关实现：red_dot_init.gd:229-232（读 有未读纪事()）／ game_state.gd:640/647 ／ ui/page_chronicle.gd:126-129。
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_chronicle_reddot.tscn
## 判据：末行 >>>PROBE_RESULT=PASS
## 注：本探针「已写待跑」，不得与工程线 gate_all/探针并发跑 Godot。

const RedDotInitScript := preload("res://red_dot_init.gd")
const 纪事页脚本: String = "res://ui/page_chronicle.gd"

var 失败: Array = []
var 断言: int = 0

func _ready() -> void:
	prints("=== 探针③ 纪事红点两态 启动 ===")
	# ★ 前置（QA-PREP-1b-6 · 主理人硬要求）：脚本自把存档摆到正常态，避免序章模态压暗
	var 探针账号: String = "acc_ph7qa1b6_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(探针账号)
	await get_tree().process_frame
	Game.引导阶段 = 6
	Game.save_game()
	prints(">>> 前置就绪 账号=%s 引导阶段=%d" % [探针账号, int(Game.引导阶段)])
	var 原纪事: Array = (Game.宗门纪事 as Array).duplicate(true)
	var 原时间: float = float(Game.最后查看纪事时间)

	var 红点 = RedDotInitScript.new()
	add_child(红点)
	await get_tree().process_frame
	var 管理器 = 红点.获取管理器()
	_ok(管理器 != null, "0a 红点管理器已建（red_dot_init 初始化成功）")

	# ── ① 0 条纪事 ⇒ 不亮 ──
	Game.宗门纪事.clear()
	Game.最后查看纪事时间 = _现在() + 100.0   # 已读时刻在未来 ⇒ 无未读
	红点.刷新所有红点()
	await get_tree().process_frame
	_ok(Game.有未读纪事() == false, "1a 0 条纪事 ⇒ 有未读纪事()=false（实得 %s）" % str(Game.有未读纪事()))
	_ok(管理器.是否显示("纪事_未读") == false, "1b 0 条纪事 ⇒ 红点 纪事_未读 不亮（是否显示=%s，期望 false）" % str(管理器.是否显示("纪事_未读")))

	# ── ② 2 条纪事 ⇒ 亮 ──
	Game.宗门纪事.clear()
	Game.最后查看纪事时间 = _现在() - 100.0   # 已读时刻在过去 ⇒ 新纪事为未读
	Game.添加纪事("庶务", "探针·纪事甲", "第一条", 1)
	Game.添加纪事("庶务", "探针·纪事乙", "第二条", 1)
	红点.刷新所有红点()
	await get_tree().process_frame
	_ok(Game.宗门纪事.size() == 2, "2a 已注入 2 条纪事（实得 %d）" % Game.宗门纪事.size())
	_ok(Game.有未读纪事() == true, "2b 2 条纪事 ⇒ 有未读纪事()=true（实得 %s）" % str(Game.有未读纪事()))
	_ok(管理器.是否显示("纪事_未读") == true, "2c 2 条纪事 ⇒ 红点 纪事_未读 亮（是否显示=%s，期望 true）" % str(管理器.是否显示("纪事_未读")))

	# ── ③ 标记已读 ⇒ 消失 ──
	Game.标记纪事已读()
	红点.刷新所有红点()
	await get_tree().process_frame
	_ok(Game.有未读纪事() == false, "3a 标记纪事已读() 后 ⇒ 有未读纪事()=false（实得 %s）" % str(Game.有未读纪事()))
	_ok(管理器.是否显示("纪事_未读") == false, "3b 标记已读后 ⇒ 红点 纪事_未读 消失（是否显示=%s，期望 false）" % str(管理器.是否显示("纪事_未读")))

	# ── ③' 真页进树（page_chronicle._enter_tree 自动标记已读）⇒ 消失 ──
	Game.宗门纪事.clear()
	Game.最后查看纪事时间 = _现在() - 100.0
	Game.添加纪事("庶务", "探针·纪事丙", "第三条", 1)
	_ok(Game.有未读纪事() == true, "3c 进页前 有未读纪事()=true（实得 %s）" % str(Game.有未读纪事()))
	var 页 = (load(纪事页脚本) as GDScript).new()
	add_child(页)   # _enter_tree() → Game.标记纪事已读()
	await get_tree().process_frame
	_ok(Game.有未读纪事() == false, "3d 进页(进树)后 ⇒ 有未读纪事()=false（_enter_tree 自动标记；实得 %s）" % str(Game.有未读纪事()))
	页.queue_free()

	# 还原
	Game.宗门纪事.assign(原纪事)
	Game.最后查看纪事时间 = 原时间
	红点.queue_free()
	_报告()

func _现在() -> float:
	return Time.get_unix_time_from_system()

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
