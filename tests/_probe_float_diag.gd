extends Node

# `Invalid call. Nonexistent 'float' constructor.` 事故回归探针（2026-09-16）
#
# 事故链：game_state.gd 的 `"资源产能": 预估月产出` 漏了括号 ⇒ 传进快照的是 **Callable 而非数值**
#        ⇒ period_settlement.gd:100 的 `float(Callable)` 抛错 ⇒ 结算中断 ⇒ 「推演一月」整段中断
#        ⇒ 对外表现「游戏无法启动」（无 F5 窗口、只有错误面板）。
#
# 本探针钉死两件事：
#   ① 引擎行为：Godot 4.7 的 float()/int() 在实参为 null / 数组 / 字典 / Callable 时**抛错**
#      （不是早期版本的静默转 0）—— 这是全项目级的雷区，不只本模块。
#   ② 修复行为：坏值快照不得再掀翻年结结算。

var 通过: int = 0
var 失败: int = 0

func _ok(条: bool, 名: String) -> void:
	if 条:
		通过 += 1
		print("[OK] " + 名)
	else:
		失败 += 1
		print("[XX] " + 名)

# 把 float()/int() 关进独立函数：引擎抛错会中断本函数并返回 null ⇒ 外层据 null 判「抛错」
func _调float(v: Variant) -> Variant:
	return float(v)

func _调int(v: Variant) -> Variant:
	return int(v)

func _无参() -> int:
	return 0

func _ready() -> void:
	# ── A 段：钉死转换函数的实参雷区 ──
	_ok(_调float(null) == null, "A1 float(null) 抛错（4.7 起不再静默转 0）")
	_ok(_调float([]) == null, "A2 float(数组) 抛错")
	_ok(_调float({}) == null, "A3 float(字典) 抛错")
	_ok(_调float(Callable(self, "_无参")) == null, "A4 float(Callable) 抛错")
	_ok(_调float(1) == 1.0, "A5 float(int) 正常")
	_ok(_调float(2.5) == 2.5, "A6 float(float) 正常")
	_ok(_调float("3.5") == 3.5, "A7 float(数字字符串) 正常")
	_ok(_调float(true) == 1.0, "A8 float(bool) 正常")
	_ok(_调int(null) == null, "A9 int(null) 抛错（同一雷区，int() 亦不可裸用）")
	_ok(_调int([]) == null, "A10 int(数组) 抛错")
	_ok(_调int({}) == null, "A11 int(字典) 抛错")

	# ── B 段：复现事故成因「方法名漏括号 ⇒ Callable」 ──
	var 裸引用: Variant = Game.预估月产出
	_ok(typeof(裸引用) == TYPE_CALLABLE,
		"B1 裸写方法名求值为 Callable（typeof=%d）—— 这正是事故成因" % typeof(裸引用))
	_ok(typeof(Game.预估月产出()) == TYPE_INT,
		"B2 补上括号后返回 int（typeof=%d）" % typeof(Game.预估月产出()))
	_ok(_调float(裸引用) == null, "B3 把裸引用塞进 float() 即抛错（与线上栈帧完全一致）")
	_ok(_调float(Game.预估月产出()) != null, "B4 用正确调用形态则安全")

	# ── C 段：周期结算的坏值免疫 ──
	var 脚本 = load("res://period_settlement.gd")
	_ok(脚本 != null, "C1 period_settlement.gd 可加载")
	var 实例 = 脚本.new()
	var 坏快照: Dictionary = {
		"资源产能": null, "灵石增量": [], "总战力增量": {}, "宗主战力增量": Callable(self, "_无参"),
		"宗主境界提升": "12.5", "技艺殿阁等级": true,
	}
	var 卡: Dictionary = 实例.结算(10, 坏快照)
	_ok(not 卡.is_empty() and 卡.has("评级"),
		"C2 坏值快照不再中断年结（评级=%s 总分=%s）" % [str(卡.get("评级", "?")), str(卡.get("总分", "?"))])
	_ok(int(卡["明细"]["资源产能"]) == 0, "C3 null 被收敛为 0")
	_ok(int(卡["明细"]["宗主境界提升"]) == 12, "C4 字符串数值仍被正确解析（12.5→12）")
	_ok(int(卡["明细"]["技艺殿阁等级"]) != 0, "C5 bool 参与计分（true→1，不再是雷）")

	# ── D 段：修复后的真实调用形态 ──
	var 快照: Dictionary = {
		"资源产能": Game.预估月产出(), "灵石增量": 200, "总战力增量": 300,
		"宗主战力增量": 40, "宗主境界提升": 0, "技艺殿阁等级": 3,
		"高阶产出": 0, "洞府数量": 0, "灵田等级": 0,
	}
	var 卡2: Dictionary = 实例.结算(10, 快照)
	_ok(not 卡2.is_empty() and int(卡2["明细"]["资源产能"]) == Game.预估月产出(),
		"D1 修复后调用形态出卡正常（资源产能=%d）" % int(卡2["明细"]["资源产能"]))
	_ok(快照["资源产能"] is float, "D2 快照数值已被净化为 float（下游 int()/float() 均安全）")

	print("PROBE_FLOAT_DIAG 通过=%d 失败=%d" % [通过, 失败])
	print("PROBE_FLOAT_DIAG_%s" % ("PASS" if 失败 == 0 else "FAIL"))
	get_tree().quit()
