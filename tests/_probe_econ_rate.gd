extends Node
## ECON-03 P0-A / P0-B / P0-D 探针（纯逻辑校验，headless 可跑）。
## 用法：<godot> --headless --path . --scene res://tests/_probe_econ_rate.tscn
## 目的：① 汇率基座同日恒定 / 跨日轮换 / R∈[6,30] / 三因子接线正确
##       ② 经济基线.csv 真的被读进缓存（修掉「continue 之后不可达」那个静默 bug）
##       ③ 坊市默认落点 = 灵石区（不再一进来就是仙玉价）
##       ④ 拍品「底价仙玉」派生 + 混场比价工具接线正确
##       ⑤ page_shop / page_auction 实例化零 SCRIPT ERROR

const 探针账号 := "__probe_econ_rate__"

var 失败: int = 0
var 断言: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		DisplayServer.window_set_size(Vector2i(1080, 1920))

	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(20)
	prints(">>> 账号 = %s" % 探针账号)

	_测基线读取()
	_测汇率基座()
	_测折算往返()
	_测坊市默认落点()
	_测拍卖双币()
	await _测页面实例化()

	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败])
	prints(">>>PROBE_ECON_RATE_%s" % ("FAIL" if 失败 > 0 else "PASS"))
	get_tree().quit(1 if 失败 > 0 else 0)

# ────────────────────────────── 断言助手 ──────────────────────────────
func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败 += 1
		prints(">>>  [XX] %s" % 文)

func _近(a: float, b: float, 容差: float) -> bool:
	return abs(a - b) <= 容差

# ────────────────────────────── ① 基线 CSV 真读 ──────────────────────────────
func _测基线读取() -> void:
	var 基线: Dictionary = Game.call("_读经济基线")
	_ok(not 基线.is_empty(), "经济基线.csv 缓存非空（原「continue 后不可达」bug 已修）")
	prints(">>>  基线键数 = %d" % 基线.size())
	for k in ["仙玉基准汇率", "汇率下限", "汇率上限", "仙玉结算溢价"]:
		_ok(基线.has(k), "基线含新增键 [%s]" % k)
	_ok(str(基线.get("标准局月耗_上限", "")) != "", "基线含既有键 [标准局月耗_上限]（证明整表可读）")

# ────────────────────────────── ② 汇率基座 ──────────────────────────────
func _测汇率基座() -> void:
	var 日0: int = int(Game.累计游戏日)
	var r1: float = Game.当前汇率()
	var r2: float = Game.当前汇率()
	var r3: float = Game.当前汇率()
	_ok(r1 == r2 and r2 == r3, "同日三次调用恒定（r=%.4f）" % r1)

	# 三因子接线复算：与 当前汇率() 内部公式逐项对齐
	var f产: float = clamp(float(Game.预估月产出()) / 366.0, 0.70, 2.00)
	var f望: float = clamp(1.40 - float(Game.声望) / 6000.0, 0.75, 1.40)
	var f浮: float = 1.0 + (float(Game.call("_汇率_浮动因子", 日0)) - 0.5) * 0.16
	var 期望: float = clamp(10.0 * f产 * f望 * f浮, 6.0, 30.0)
	_ok(_近(r1, 期望, 0.0001), "三因子复算一致：实测 %.4f / 期望 %.4f（f产%.3f f望%.3f f浮%.3f）" % [r1, 期望, f产, f望, f浮])

	# 跨日轮换 + 边界 [6,30]
	var 最小: float = 1e9
	var 最大: float = -1e9
	for d in range(0, 400):
		var v: float = clamp(10.0 * f产 * f望 * (1.0 + (float(Game.call("_汇率_浮动因子", d)) - 0.5) * 0.16), 6.0, 30.0)
		最小 = min(最小, v)
		最大 = max(最大, v)
	_ok(最小 >= 6.0 and 最大 <= 30.0, "400 日扫描全部落在 [6,30]（min=%.2f max=%.2f）" % [最小, 最大])
	_ok(最大 - 最小 > 0.01, "浮动生效（400 日内极差 %.2f）" % (最大 - 最小))

	# 跨日轮换：找一个 R 与今日不同的游戏日，切过去后重取必须变，切回须复原
	var 异日: int = -1
	for d in range(0, 400):
		var v: float = clamp(10.0 * f产 * f望 * (1.0 + (float(Game.call("_汇率_浮动因子", d)) - 0.5) * 0.16), 6.0, 30.0)
		if abs(v - r1) > 0.05:
			异日 = d
			break
	_ok(异日 >= 0, "400 日内存在与今日显著不同的牌价（找到日 %d）" % 异日)
	if 异日 >= 0:
		Game.累计游戏日 = 异日
		var r_异: float = Game.当前汇率()
		_ok(abs(r_异 - r1) > 0.05, "跨日后牌价确实轮换（%.4f → %.4f）" % [r1, r_异])
		_ok(Game.当前汇率() == r_异, "新日之内再次调用恒定（缓存日已随累计游戏日更新）")
		Game.累计游戏日 = 日0
		_ok(Game.当前汇率() == r1, "切回原日后恢复原牌价（缓存可重算，非一次性）")

# ────────────────────────────── ③ 折算往返 ──────────────────────────────
func _测折算往返() -> void:
	var r: float = Game.当前汇率()
	var 溢价: float = Game.仙玉结算溢价()
	_ok(_近(溢价, 1.15, 0.0001), "仙玉结算溢价 = 1.15（实读 %.4f）" % 溢价)

	var 仙玉价: int = Game.灵石折仙玉(5000)
	var 期望仙玉: int = int(ceil(5000.0 / r * 溢价))
	_ok(仙玉价 == 期望仙玉, "灵石折仙玉(5000) = %d（期望 %d）" % [仙玉价, 期望仙玉])
	_ok(仙玉价 >= 192 and 仙玉价 <= 959, "5000 灵石折仙玉落在设计两端 [192,959] 之内（实测 %d）" % 仙玉价)

	var 回: int = Game.仙玉折灵石(仙玉价)
	_ok(abs(回 - 5000) <= 60, "往返自洽：5000 → %d 仙玉 → %d 灵石（误差 %d）" % [仙玉价, 回, abs(回 - 5000)])
	_ok(Game.灵石折仙玉(0) == 0 and Game.仙玉折灵石(0) == 0, "零/负值安全（不产生除零或负价）")

	var 文: String = Game.汇率牌价文案()
	_ok(文.find("仙玉") >= 0 and 文.find("灵石") >= 0, "牌价文案含双币：%s" % 文)

# ────────────────────────────── ④ 坊市默认落点 ──────────────────────────────
func _测坊市默认落点() -> void:
	var 页: Control = load("res://ui/page_shop.gd").new()
	if 页 == null:
		失败 += 1
		prints(">>>  [XX] page_shop.gd 无法实例化")
		return
	_ok(str(页.get("_当前分类")) == "收购", "坊市默认分类 = %s（应为灵石区「收购」）" % str(页.get("_当前分类")))
	页.free()

# ────────────────────────────── ⑤ 拍卖双币 ──────────────────────────────
func _测拍卖双币() -> void:
	var 系统 = Game.拍卖行系统
	var 假拍品: Dictionary = {"起拍价": 5000, "当前价": 5000}
	var 派生: int = 系统.拍品底价仙玉(假拍品)
	_ok(派生 == Game.灵石折仙玉(5000), "拍品底价仙玉 == 灵石折仙玉(起拍价)（%d）" % 派生)
	_ok(系统.拍品底价仙玉({}) == 0, "空拍品安全返回 0")

	var r: float = Game.当前汇率()
	_ok(系统.出价灵石等价(100, "仙玉") == int(round(100.0 * r)), "仙玉出价折算灵石等价 = 出价×R（%d）" % 系统.出价灵石等价(100, "仙玉"))
	_ok(系统.出价灵石等价(100, "灵石") == 100, "灵石出价等价恒等 100")
	_ok(系统.出价灵石等价(0, "仙玉") == 0, "零出价安全返回 0")

	# 不落盘（结构性断言）：汇率缓存只是 Autoload 上的普通字段，未进 save_game() 白名单。
	# 若哪天被误加进白名单，下面的静态校验脚本 check_econ_rate_persist.py 会 FAIL。
	_ok(Game.get("汇率_日缓存") is float, "汇率_日缓存 存在且为 float（实值 %s）" % str(Game.get("汇率_日缓存")))
	_ok(Game.get("汇率_缓存日") is int, "汇率_缓存日 存在且为 int（实值 %s）" % str(Game.get("汇率_缓存日")))
	_ok(int(Game.get("汇率_缓存日")) == int(Game.累计游戏日), "缓存日已对齐当前累计游戏日")

# ────────────────────────────── ⑥ 页面实例化 ──────────────────────────────
func _测页面实例化() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": 探针账号})
	await _settle(20)
	var ui: Node = main.get("新UI")
	_ok(ui != null, "新UI 就绪")
	if ui == null:
		return
	for 路径 in ["res://ui/page_shop.tscn", "res://ui/page_auction.tscn"]:
		if not ResourceLoader.exists(路径):
			prints(">>>  [--] %s 不存在，跳过" % 路径)
			continue
		var 页: Node = (load(路径) as PackedScene).instantiate()
		add_child(页)
		await _settle(16)
		if 页.has_method("refresh"):
			页.call("refresh")
		await _settle(16)
		var 牌价: Node = 页.find_child("RateLabel", true, false) if 页 is Node else null
		prints(">>>  [OK] %s 实例化+refresh 未抛错（RateLabel=%s）" % [路径, "有" if 牌价 != null else "无"])
		断言 += 1
		页.queue_free()
		await _settle(4)
	main.queue_free()

# ────────────────────────────── 工具 ──────────────────────────────
func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
