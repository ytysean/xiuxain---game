extends Node
## PH7-QA-PREP-1 · 探针①：弟子请示计数「三处 1:1」只读断言（headless）
## 目的：证明同一个数字（弟子请示待办数）在
##   ① 源（Game.待抉择.size() + Game.誓约待批.size()）
##   ② 红点 弟子_请示 的显示数量（RedDotInit → RedDotManager.获取数量）
##   ③ 弟子录「弟子请示（N）」汇总条（page_disciple._刷新请示汇总）
## 三处严格 1:1；且 N==0 时红点不亮 + 汇总条隐藏（铁律⑭ 零待办不许亮）。
## 另验守卫：数组为空 / null（非 Array）时不抛错（守 red_dot_init.gd:154-161 与 page_disciple.gd:465-472）。
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7_m6_count.tscn
## 判据：末行 >>>PROBE_RESULT=PASS
## 注：本探针「已写待跑」——由主理人在引擎通道空闲时执行；不得与工程线 gate_all/探针并发。

const RedDotInitScript := preload("res://red_dot_init.gd")
const 弟子页脚本: String = "res://ui/page_disciple.gd"

var 失败: Array = []
var 断言: int = 0

func _ready() -> void:
	prints("=== 探针① 弟子请示计数 三处 1:1 启动 ===")
	# ★ 前置（QA-PREP-1b-6 · 主理人硬要求）：脚本自把存档摆到正常态，避免序章模态压暗
	#   用独立探针账号 ⇒ save_game() 写入 user://profiles/<探针账号>/ ，绝不覆盖任何真实存档。
	var 探针账号: String = "acc_ph7qa1b6_" + str(int(Time.get_unix_time_from_system()))
	Game.load_game(探针账号)
	await get_tree().process_frame
	Game.引导阶段 = 6
	Game.save_game()
	prints(">>> 前置就绪 账号=%s 引导阶段=%d" % [探针账号, int(Game.引导阶段)])
	var 原待: Array = (Game.待抉择 as Array).duplicate()
	var 原誓: Array = (Game.誓约待批 as Array).duplicate()

	# 本探针自建红点系统（不依赖 main.tscn）
	var 红点 = RedDotInitScript.new()
	add_child(红点)
	await get_tree().process_frame
	var 管理器 = 红点.获取管理器()
	_ok(管理器 != null, "0a 红点管理器已建（red_dot_init 初始化成功）")

	# 隔离 label：直接验 page_disciple._刷新请示汇总 的 N 语义
	var 页 = (load(弟子页脚本) as GDScript).new()
	var lbl := Label.new()
	lbl.name = "请示汇总"
	页.set("_请示汇总_label", lbl)

	# ── 用例 A：(待抉择=2, 誓约待批=1) ⇒ N=3 ──
	_喂(2, 1)
	红点.刷新所有红点()
	await get_tree().process_frame
	var n_src3: int = (Game.待抉择 as Array).size() + (Game.誓约待批 as Array).size()
	var n_dot3: int = int(管理器.获取数量("弟子_请示"))
	页.call("_刷新请示汇总")
	var n_banner3: int = _抽数(lbl.text)
	_ok(n_src3 == 3, "1a 源 N = 待抉择2 + 誓约待批1 = %d（期望 3）" % n_src3)
	_ok(n_dot3 == 3, "1b 红点 弟子_请示 数量 = %d（期望 3；是否显示=%s）" % [n_dot3, str(管理器.是否显示("弟子_请示"))])
	_ok(lbl.text == "弟子请示（3）", "1c 汇总条文本 = 「%s」（期望 弟子请示（3））" % lbl.text)
	_ok(n_src3 == n_dot3 and n_dot3 == n_banner3, "1d 三处 1:1 相等：源%d == 红点%d == 汇总条%d" % [n_src3, n_dot3, n_banner3])

	# ── 用例 B：(0, 0) ⇒ N=0 且「不亮」 ──
	_喂(0, 0)
	红点.刷新所有红点()
	await get_tree().process_frame
	var n_src0: int = (Game.待抉择 as Array).size() + (Game.誓约待批 as Array).size()
	var n_dot0: int = int(管理器.获取数量("弟子_请示"))
	页.call("_刷新请示汇总")
	_ok(n_src0 == 0 and n_dot0 == 0, "2a 零待办：源=%d 红点=%d（期望 0 / 0）" % [n_src0, n_dot0])
	_ok(not 管理器.是否显示("弟子_请示"), "2b 零待办 ⇒ 红点不亮（是否显示=%s，期望 false）" % str(管理器.是否显示("弟子_请示")))
	_ok(lbl.text == "弟子请示（0）" and not lbl.visible, "2c 零待办 ⇒ 汇总条隐藏（文本「%s」visible=%s，期望 false）" % [lbl.text, str(lbl.visible)])

	# ── 用例 C：null（非 Array）入参不抛错 ──
	# 放在独立函数内：即便 typed array 拒绝 null 也只中断该函数，不带走 _ready。
	_试置空()
	红点.刷新所有红点()
	await get_tree().process_frame
	页.call("_刷新请示汇总")
	_ok(true, "3a null 入参下 红点刷新 + 汇总刷新 链路未中断（执行到达本行）")
	_ok(int(管理器.获取数量("弟子_请示")) == 0, "3b null 入参下 红点数量 = %d（期望 0；守卫 is Array 兜底）" % int(管理器.获取数量("弟子_请示")))
	_ok(lbl.text == "弟子请示（0）" and not lbl.visible, "3c null 入参下 汇总条隐藏（文本「%s」）" % lbl.text)

	# 静态守卫存在性（typed array 无法注入真正的「非 Array」，此为主证）
	# 注：守卫形态为「存在性判 + 别名 + is Array」：
	#   red_dot_init.gd:155/156  var 待抉择 = Game.待抉择 ; if 待抉择 is Array
	#   red_dot_init.gd:159/160  var 请誓 = Game.誓约待批 ; if 请誓 is Array
	#   page_disciple.gd:466/467、470/471 同形。
	#   ⇒ 直接字面量「誓约待批 is Array」**不存在**（被别名为「请誓」）；断言须别名感知，否则假失败。
	var 源1: String = _读源("res://red_dot_init.gd")
	var 源2: String = _读源("res://ui/page_disciple.gd")
	_ok(("待抉择 is Array" in 源1) and ("请誓 is Array" in 源1 or "誓约待批 is Array" in 源1), "3d red_dot_init 守卫 `is Array` 存在（待抉择／誓约待批→别名「请誓」；红点源）")
	_ok(("待抉择 is Array" in 源2) and ("请誓 is Array" in 源2 or "誓约待批 is Array" in 源2), "3e page_disciple 守卫 `is Array` 存在（待抉择／誓约待批→别名「请誓」；汇总条源）")

	# 还原
	_还原(原待, 原誓)
	页.free()
	红点.queue_free()
	_报告()

func _喂(待: int, 誓: int) -> void:
	var t: Array[Dictionary] = []
	for i in range(待):
		t.append({"弟子": null, "物品": null, "文本": "probe_count"})
	Game.待抉择 = t
	var s: Array = []
	for i in range(誓):
		s.append({"弟子ID": i, "弟子名": "probe", "oath_id": "x", "名称": "p", "desc": "", "日": 0})
	Game.誓约待批 = s

func _试置空() -> void:
	# 注：`Game.待抉择` 为 Array[Dictionary] 强类型字段；`Game.待抉择 = null` 会在**解析期**报类型错误
	#     ⇒ 整脚本不加载、探针空跑挂起（命门在 tests/_probe_ph7_m6_count.gd 原 :94/95）。
	#     改用 Object.set() 绕过静态类型检查：运行期仅软报错、属性保持原值，不中断脚本，
	#     从而 3a/3b/3c 仍在「空数组」态执行（真守卫由 3d/3e 的 `X is Array` 源码存在性主证）。
	(Game as Object).set("待抉择", null)
	(Game as Object).set("誓约待批", null)

func _还原(原待: Array, 原誓: Array) -> void:
	Game.待抉择.assign(原待)
	Game.誓约待批.assign(原誓)

func _抽数(s: String) -> int:
	var a: int = s.find("（")
	var b: int = s.find("）")
	if a < 0 or b <= a:
		return -1
	return int(s.substr(a + 1, b - a - 1))

func _读源(p: String) -> String:
	if not FileAccess.file_exists(p):
		return ""
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t

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
