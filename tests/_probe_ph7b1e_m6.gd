extends Node
## PH7-BATCH1E 收尾探针（headless，只读断言）
## 目的：
##   §1 信号异参吸收 —— main.gd `_刷新红点(_a,_b,_c=null)` 必须同时吞下
##      Game 的 0/1 参信号 + SectManager 的 3 参信号（connect + emit 均不得报错；
##      旧 0 参签名在 3 参 emit 时必炸「expected 0 arguments, but called with 3」）。
##      ★ GDScript 无 try/catch：arity 不符只打日志、不中断脚本 ⇒ 「无报错」由外层脚本扫日志佐证。
##   §2 M6 只读汇总条 —— ui/page_disciple.gd「请示汇总」文本 N = 待抉择 + 誓约待批；N==0 ⇒ 隐藏（铁律⑭）。
## 运行：<godot> --headless --path <proj> --scene res://tests/_probe_ph7b1e_m6.tscn
## 判据：末行 >>>PROBE_PH7B1E_M6_PASS

var 失败: int = 0
var 断言: int = 0

const 主脚本: String = "res://main.gd"
const 弟子页脚本: String = "res://ui/page_disciple.gd"
const 弟子页场景: String = "res://ui/page_disciple.tscn"

func _ready() -> void:
	prints("=== PH7-BATCH1E M6 + 信号异参 探针 启动 ===")
	_测信号异参吸收()
	await _测M6汇总条()
	_报告()

# ───────── §1 信号异参吸收 ─────────
func _测信号异参吸收() -> void:
	var 主 = (load(主脚本) as GDScript).new()
	# 1a 形参个数（旧签名 0 参 ⇒ 3 参信号 emit 必报「expected 0 arguments」）
	var 形参: Array = []
	for m in 主.get_method_list():
		if str(m.get("name", "")) == "_刷新红点":
			形参 = m.get("args", [])
			break
	_ok(形参.size() == 3, "1a `_刷新红点` 形参=%d（须=3，方可吸收 3 参信号；实得 %s）" % [形参.size(), str(形参)])

	# 1b 直接以 0/1/3 参调用（错误只落日志 ⇒ 证据见外层扫日志）
	prints(">>>S1B_BEGIN 直呼 _刷新红点 0/1/3 参")
	var c := Callable(主, "_刷新红点")
	c.call()
	c.call("文本")
	c.call(1, "违规", "细节")
	prints(">>>S1B_END")

	# 1c 真实 7 信号 connect + emit（Game 0/1 参 × 4；SectManager 3 参 × 3）
	prints(">>>S1C_BEGIN 连接并 emit 7 条真实信号")
	var 主2 = (load(主脚本) as GDScript).new()
	var 连: int = 0
	var 悬: Array = []
	if Game != null:
		for 名 in ["弟子变动", "新手目标更新", "战报更新", "邮件变动"]:
			悬.append(名)
			(Game.get(名) as Signal).connect(Callable(主2, "_刷新红点"), CONNECT_DEFERRED)
			连 += 1
	if SectManager != null:
		for 名 in ["戒律违规上报", "弟子请示", "宗门事务待批阅"]:
			悬.append(名)
			(SectManager.get(名) as Signal).connect(Callable(主2, "_刷新红点"), CONNECT_DEFERRED)
			连 += 1
	_ok(连 == 7, "1c 已连接 7 条信号（Game 4 + SectManager 3；实得 %d）" % 连)

	Game.弟子变动.emit()
	Game.新手目标更新.emit()
	Game.战报更新.emit("探针战报")
	Game.邮件变动.emit()
	SectManager.戒律违规上报.emit(1, "私斗", "细节")
	SectManager.弟子请示.emit(2, "请誓", {})
	SectManager.宗门事务待批阅.emit("t1", "标题", {})
	prints(">>>S1C_END 7 条信号已 emit")

	# 断开，避免污染 / free 报错
	if Game != null:
		for 名 in ["弟子变动", "新手目标更新", "战报更新", "邮件变动"]:
			(Game.get(名) as Signal).disconnect(Callable(主2, "_刷新红点"))
	if SectManager != null:
		for 名 in ["戒律违规上报", "弟子请示", "宗门事务待批阅"]:
			(SectManager.get(名) as Signal).disconnect(Callable(主2, "_刷新红点"))
	主2.free()
	主.free()

# ───────── §2 M6 只读汇总条 ─────────
func _测M6汇总条() -> void:
	var 原待: Array = (Game.待抉择 as Array).duplicate()
	var 原誓: Array = (Game.誓约待批 as Array).duplicate()

	# 2a/2b 隔离测：直接喂 label，验 N 值语义（不触发 populate，避免假数据干扰列表构建）
	var 页 = (load(弟子页脚本) as GDScript).new()
	var lbl := Label.new()
	lbl.name = "请示汇总"
	页.set("_请示汇总_label", lbl)
	_喂(2, 1)
	页.call("_刷新请示汇总")
	_ok(lbl.text == "弟子请示（3）" and lbl.visible, "2a N=待抉择2+誓约待批1=3 → 文本「%s」visible=%s" % [lbl.text, str(lbl.visible)])
	_喂(0, 0)
	页.call("_刷新请示汇总")
	_ok(lbl.text == "弟子请示（0）" and not lbl.visible, "2b N=0 → 隐藏（铁律⑭ 无待办不亮）；文本「%s」visible=%s" % [lbl.text, str(lbl.visible)])
	页.free()

	# 2c..f 集成测：真场景真构建（label 由 _build_list_header 建出，样式=UITheme 金文字）
	var 页2: Control = (load(弟子页场景) as PackedScene).instantiate()
	add_child(页2)
	await _帧(3)
	var L: Label = 页2.find_child("请示汇总", true, false) as Label
	_ok(L != null, "2c 弟子录顶栏存在「请示汇总」Label（find_child 命中）")
	if L != null:
		_ok(L.get_theme_color("font_color").is_equal_approx(UITheme.COLOR_TEXT_GOLD),
			"2d 金文字色 == UITheme.COLOR_TEXT_GOLD（禁自写 Color）")
		_喂(0, 0)
		页2.call("_刷新请示汇总")
		_ok(L.text == "弟子请示（0）" and not L.visible, "2e 构建后默认空队列 → 隐藏（文本「%s」）" % L.text)
		_喂(2, 1)
		页2.call("_刷新请示汇总")
		_ok(L.text == "弟子请示（3）" and L.visible, "2f 置 2+1 → 显示「%s」（真构建 label 上重算，与 Tab 红点同源）" % L.text)
		页2.queue_free()
		await _帧(2)

	# 还原 Game
	Game.待抉择.assign(原待)
	Game.誓约待批.assign(原誓)

func _喂(待: int, 誓: int) -> void:
	var t: Array[Dictionary] = []
	for i in range(待):
		t.append({"弟子": null, "物品": null, "文本": "probe"})
	Game.待抉择 = t
	var s: Array = []
	for i in range(誓):
		s.append({"弟子ID": i, "弟子名": "probe", "oath_id": "x", "名称": "p", "desc": "", "日": 0})
	Game.誓约待批 = s

# ───────── 工具 ─────────
func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败 += 1
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败])
	prints(">>>PROBE_PH7B1E_M6_%s" % ("FAIL" if 失败 > 0 else "PASS"))
	get_tree().quit(1 if 失败 > 0 else 0)

func _帧(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
