extends Node

## P0-1 洋葱式解锁 × UI 布局解耦 自检（headless 实机）
##
## 覆盖 headless_smoke 覆盖不到的 UI 层：
##   [A] 引擎静态入口 入口可显示 —— 验证静态函数能否访问 autoload Game
##   [B] 两个 UI 脚本强制编译 —— game_ui.gd 非 autoload，冒烟不会加载它
##   [C] 三容器共用过滤来源 _过滤已解锁 / _可见序号
##   [D] 真实例化首页 —— 断言隐藏中间入口后坐标按可见序号连续（无空洞）

var _fail: int = 0


func _ready() -> void:
	prints("=== P0-1 解锁 × UI 解耦 自检 ===")
	# 看门狗：任何异常都不至于挂死（正常路径在结尾 quit）
	get_tree().create_timer(40.0).timeout.connect(_看门狗)
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return
	var U: SystemUnlock = Game.系统解锁
	if U == null:
		printerr("FATAL: Game.系统解锁 未挂载")
		get_tree().quit()
		return

	# ── A. 引擎静态入口（关键未知：静态函数能否访问 autoload Game）──
	prints("\n[A] SystemUnlock 静态入口")
	_check("A1 入口可显示(天下) == true", SystemUnlock.入口可显示("天下") == true)
	_check("A2 陌生入口 fail-open == true", SystemUnlock.入口可显示("__不存在__") == true)
	_check("A3 静态与实例结果一致(库藏)", SystemUnlock.入口可显示("库藏") == U.入口已解锁("库藏"))

	# ── B. UI 脚本编译（headless_smoke 不加载这两文件，此处强制编译）──
	prints("\n[B] UI 脚本编译")
	var sp: GDScript = load("res://ui/sect_home_page.gd")
	var gu: GDScript = load("res://ui/game_ui.gd")
	_check("B1 sect_home_page.gd 可编译", sp != null)
	_check("B2 game_ui.gd 可编译", gu != null)
	if sp == null:
		prints("\n=== 自检结束  FAIL=%d ===" % _fail)
		get_tree().quit()
		return

	# ── C. 三容器过滤来源（helper 级）──
	# 关键：不用「强制全解锁」开关，而是让四类条件在真实判定下全部成立，
	#       这样锁定单个入口时才能看到「真实收缩 + 紧凑上移」。
	prints("\n[C] _过滤已解锁 / _可见序号")
	var 旧等级: int = Game.门派等级
	var 旧突破: int = Game.累计弟子突破次数
	var 旧辈分: int = Game.当前辈分序
	Game.门派等级 = 999
	Game.累计弟子突破次数 = 1
	Game.当前辈分序 = 99
	U.强制全解锁 = false

	var page: Control = sp.new()
	_check("C2 全条件成立 快捷栏 = 7（含「更多」折叠钮）", page._过滤已解锁(page.QUICK_ENTRIES).size() == 7)
	_check("C3 全条件成立 更多面板 = 42", page._过滤已解锁(page.MORE_ENTRIES).size() == 42)
	# C4（S3 重写）：新旧 6 入口全部「已在册」（只断成员性 >=0；槽号非契约本意）
	var 六项: Array = ["天下", "宗务", "坊市", "玄榜", "宗门典藏", "碎片宝箱"]
	for 入口id in 六项:
		_check("C4 更多面板含「%s」" % 入口id, page._可见序号(page.MORE_ENTRIES, 入口id) >= 0)
	# R9：MORE_ENTRIES <-> MORE_GROUPS 双向同步（集合相等，禁静默兜底 —— 项目红线）
	var a_ids: Dictionary = {}
	for cfg in page.MORE_ENTRIES:
		a_ids[String(cfg["id"])] = true
	var b_ids: Dictionary = {}
	for grp in page.MORE_GROUPS:
		for eid in grp["入口"]:
			b_ids[String(eid)] = true
	var 差集: Array = []
	for k in a_ids.keys():
		if not b_ids.has(k):
			差集.append("仅MORE_ENTRIES:" + k)
	for k in b_ids.keys():
		if not a_ids.has(k):
			差集.append("仅MORE_GROUPS:" + k)
	_check("R9 MORE_ENTRIES <-> MORE_GROUPS 集合相等（差集空）", 差集.is_empty())
	if not 差集.is_empty():
		printerr("     R9 差集=", 差集)
	# R8：组容量（组数 <=6 ∧ 组内 <=8 ∧ Σ组内 == 42）
	_check("R8 组数 <= 6", page.MORE_GROUPS.size() <= 6)
	var 组内总数: int = 0
	for grp in page.MORE_GROUPS:
		组内总数 += (grp["入口"] as Array).size()
		_check("R8 组「%s」<= 8" % String(grp["组名"]), (grp["入口"] as Array).size() <= 8)
	_check("R8 Σ组内 == 42", 组内总数 == 42)
	page.free()

	# 锁掉「宗务」→ 更多面板收缩 1（S3 后宿主由侧边入口列改为「更多」面板）
	_锁入口(U, "宗务")
	_check("C5 锁定后 入口可显示(宗务) = false", SystemUnlock.入口可显示("宗务") == false)
	var page2: Control = sp.new()
	_check("C6 锁定后 更多面板 = 41", page2._过滤已解锁(page2.MORE_ENTRIES).size() == 41)
	_check("C8 锁定后 宗务序号 = -1", page2._可见序号(page2.MORE_ENTRIES, "宗务") == -1)
	page2.free()
	U.加载表()

	# ── D. 构建级：真实例化首页，验证坐标按可见序号排布、无空洞 ──
	prints("\n[D] 实例化首页验证坐标（无空洞）")
	await _实例化并测(sp, "全条件成立")
	_锁入口(U, "宗务")
	await _实例化并测(sp, "锁宗务")
	_锁入口(U, "日供")
	await _实例化并测(sp, "锁宗务+日供")
	U.加载表()

	# ★ S3 第 4 场景：折叠态 —— 强制走 `if not c.visible: continue` 与 suffix 期望（防死分支）
	await _实例化并测(sp, "折叠态", true)

	# 还原游戏状态
	Game.门派等级 = 旧等级
	Game.累计弟子突破次数 = 旧突破
	Game.当前辈分序 = 旧辈分

	prints("\n=== 自检结束  FAIL=%d ===" % _fail)
	get_tree().quit()


func _看门狗() -> void:
	printerr("WATCHDOG 超时，强制退出（疑似挂死）")
	get_tree().quit()


func _check(标签: String, 条件: bool) -> void:
	if 条件:
		prints("  PASS  ", 标签)
	else:
		_fail += 1
		printerr("  FAIL  ", 标签)


## 让「入口id」被唯一一个永不达成的测试系统 gating（先摘掉其它真实引用，保证判定唯一）
func _锁入口(U: SystemUnlock, 入口id: String) -> void:
	for k in U._系统表.keys():
		if String(U._系统表[k].get("入口", "")) == 入口id:
			U._系统表.erase(k)
	U._系统表["__t_lock_" + 入口id] = {
		"名称": "测试锁", "条件类型": "门派等级", "条件参数": "99999",
		"页面": "", "入口": 入口id, "阶段": "P1",
	}
	U._被锁定入口[入口id] = true
	U.强制全解锁 = false


## 实例化首页 → 读各容器实际坐标 → 断言「按可见序号连续」= 无空洞
## 折叠: true 时置 `_quick_folded` 并调 `_apply_quick_fold()`，验证折叠态只校 dock 末槽
func _实例化并测(sp: GDScript, 标签: String, 折叠: bool = false) -> void:
	var page: Control = sp.new()
	add_child(page)
	await get_tree().process_frame
	if 折叠:
		page._quick_folded = true
		page._apply_quick_fold()
	var qxs: Array = []
	var chrome = page._chrome
	_check("%s _chrome 已构建" % 标签, chrome != null)
	if chrome != null:
		for c in chrome.get_children():
			var nm: String = String(c.name)
			if nm.begins_with("Quick_"):
				if not c.visible:      # ★ S3：折叠感知（折叠态仅「更多」可见）
					continue
				qxs.append(c.offset_left / UITheme.UI_SCALE + page.QUICK_BTN_W * 0.5)
	qxs.sort()
	prints("  ", 标签, " → 快捷X=", qxs)
	# ★ S3：左右列(Entry_*)已退场，其“Y 槽无空洞”断言随列退场（原 :147/:148 删除，勿留假 PASS）。
	#   列消失后本断言改断 dock：期望 = _算dock中心列(N 布局数) 的**末 qxs.size() 项**
	#   （展开态 N 项全等；折叠态仅「更多」1 项 = 末槽）。契约：可见项按可见序号紧凑排布、无空洞。
	var n_layout: int = page._过滤已解锁(page.QUICK_ENTRIES).size()
	var 全列: Array = page._算dock中心列(n_layout)
	_check("%s 快捷栏 X 槽连续无空洞" % 标签,
		_近似(qxs, 全列.slice(n_layout - qxs.size(), n_layout)))
	page.free()


func _近似(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if abs(float(a[i]) - float(b[i])) > 0.05:
			return false
	return true
