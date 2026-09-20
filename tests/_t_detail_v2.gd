extends Node

## ===== 弟子详情页「七连修」无头验收 · 2026-09-15 =====
## 走玩家真实路径：main.tscn → _登录_进入 → _on_tab_selected("弟子") → _open_disciple_detail → 四 Tab。
## 覆盖老大本轮 7 条反馈：
##   ① 当前状态文案不再重复「（生还）」（命牌已镌「生」）
##   ② 状态说明弹窗字号（标题 33 / 正文 27）
##   ③ 六维属性右侧改等宽胶囊双列（填平留白；雷达 ≥200 为既有测试红线）
##   ④ 装备页：立绘居中 + 八槽左右环绕，首屏同框
##   ⑤ 闲情雅趣由「装备」Tab 移入「详情」Tab（紧随互动培养）
##   ⑥ 灵兽头像框恢复正方（不再被行高拉成竖长条）
##   ⑦ 履历页字号降档（45/48/60 当正文 → ≤33）
##
## 用法（默认无头，不弹窗）：
##   <godot_console> --headless --path <proj> res://tests/_t_detail_v2.tscn
## 产物：res://.workbuddy/_detail_v2.log

const LOG_PATH := "res://.workbuddy/_detail_v2.log"
const 探针账号 := "detail_v2"

var _lines: Array = []
var _fail: int = 0
var _ui: Node = null
var _视口: Vector2 = Vector2.ZERO
var _详情: Node = null

func _log(s: String) -> void:
	_lines.append(s)

func _ck(条件: bool, 描述: String) -> void:
	if 条件:
		_log("  [OK]   " + 描述)
	else:
		_fail += 1
		_log("  [FAIL] " + 描述)

func _flush() -> void:
	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _ready() -> void:
	var t: Timer = Timer.new()
	t.wait_time = 300.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		_log(">>> TIMEOUT 自毁")
		_flush()
		get_tree().quit(1))
	add_child(t)
	t.start()
	await _settle(2)
	await _run()
	_log("")
	_log("RESULT: %s（失败 %d）" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_flush()
	get_tree().quit(1 if _fail > 0 else 0)

# ───────── 小工具 ─────────
func _找(根: Node, 名: String) -> Node:
	if 根 == null:
		return null
	if str(根.name) == 名:
		return 根
	for c in 根.get_children():
		var r: Node = _找(c, 名)
		if r != null:
			return r
	return null

func _数名(根: Node, 前缀: String) -> int:
	var n: int = 0
	for c in 根.get_children():
		if str(c.name).begins_with(前缀):
			n += 1
	return n

func _收Label(根: Node, 出: Array) -> void:
	for c in 根.get_children():
		if c is Label:
			出.append(c)
		_收Label(c, 出)

func _字号(c: Node) -> int:
	if c == null:
		return -1
	return int(c.get_theme_font_size("font_size"))

func _run() -> void:
	_log("=== 弟子详情页 七连修 无头验收（2026-09-15）===")
	# 无头虚拟屏是方的（1920×1920）⇒ 强制回手机竖屏，否则几何类断言全部失真。
	if DisplayServer.get_name() == "headless":
		get_window().size = Vector2i(1080, 1920)
	var main_scene: PackedScene = load("res://main.tscn")
	if main_scene == null:
		_log(">>> FAIL main.tscn 加载失败")
		_fail += 1
		return
	var main: Node = main_scene.instantiate()
	add_child(main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	main._登录_进入({"id": 探针账号})
	await _settle(20)
	_ui = main.get("新UI")
	if _ui == null:
		_log(">>> FAIL 新UI 为空")
		_fail += 1
		return
	_视口 = get_viewport().get_visible_rect().size
	if Game.弟子列表.size() == 0:
		_log(">>> FAIL 本档无弟子，无法进详情页")
		_fail += 1
		return
	var 目标 = Game.弟子列表[0]
	_ui._open_disciple_detail(目标)
	await _settle(24)
	_详情 = _ui.get("_current_sub")
	if _详情 == null:
		_log(">>> FAIL 弟子详情页未创建")
		_fail += 1
		return
	_log(">>> 后端=%s 视口=%.0fx%.0f 弟子=%s" % [
		DisplayServer.get_name(), _视口.x, _视口.y, str(目标.姓名)])

	# ══════ ① 当前状态文案：不再重复「（生还）」 ══════
	_log("")
	_log("── ① 当前状态文案 ──")
	var 状态行: Label = _详情.get("_status_label")
	_ck(状态行 != null, "状态行存在")
	if 状态行 != null:
		_log("     状态文案 = 「%s」" % str(状态行.text))
		_ck(not str(状态行.text).contains("生还"),
			"状态行不再写「（生还）」（命牌已镌「生」，属同一信息第二次表达）")

	# ══════ ⑤ 闲情雅趣：已在详情 Tab，且下沉至末段 ══════
	_log("")
	_log("── ⑤ 闲情雅趣归属与位置 ──")
	var 装备页: Node = (_详情.get("_tab_pages") as Dictionary).get("装备", null)
	var 休闲: Node = _找(_详情, "休闲设置Panel")
	var 六维格: Node = _找(_详情, "SixDimGrid")
	_ck(休闲 != null, "「闲情雅趣」section 存在于页面中")
	_ck(装备页 != null and _找(装备页, "休闲设置Panel") == null,
		"「装备」Tab 内已无闲情雅趣（分类错位已消除）")
	if 休闲 != null and 六维格 != null:
		_log("     休闲 panel 父节点 = %s" % str(休闲.get_parent().name))
		_ck(休闲.global_position.y > 六维格.global_position.y,
			"闲情雅趣已下沉到「六维属性」之后（收尾型个性化设置，不打断战力主信息链）")

	# ══════ ③ 六维属性：等宽胶囊双列 ══════
	_log("")
	_log("── ③ 六维属性版面 ──")
	var 雷达 = _详情.get("_radar")
	var 六系: Dictionary = _详情.get("_six_labels")
	_ck(雷达 != null and float(雷达.custom_minimum_size.x) >= 200.0,
		"雷达图 min 宽 %.0f ≥ 200（既有红线）" % (float(雷达.custom_minimum_size.x) if 雷达 != null else -1.0))
	var 胶囊序: Array = []
	for dim in ["体魂", "根骨", "悟性", "机缘", "心性", "气运"]:
		var c: Node = _找(_详情, "SixCell_" + dim)
		胶囊序.append(c)
		if c == null:
			_fail += 1
			_log("  [FAIL] 缺胶囊 SixCell_%s" % dim)
	if 胶囊序.size() == 6 and 胶囊序[0] != null:
		var w0: float = 胶囊序[0].size.x
		var 全等宽: bool = true
		for c in 胶囊序:
			if absf(c.size.x - w0) > 1.0:
				全等宽 = false
		_log("     胶囊尺寸 = %.0f×%.0f（6 项等宽=%s）" % [w0, 胶囊序[0].size.y, str(全等宽)])
		_ck(w0 > 0.0, "胶囊已完成布局（宽 > 0）")
		_ck(全等宽, "六个胶囊等宽（两列铺满，不再是「原子+右对齐+留白」）")
		var 格宽: float = float(六维格.size.x)
		var 面板宽: float = float(六维格.get_parent().size.x)
		_log("     six_grid 宽=%.0f / six_hb 宽=%.0f（护栏：%.0f%%）" % [
			格宽, 面板宽, (格宽 / maxf(面板宽, 1.0)) * 100.0])
		_ck(格宽 / maxf(面板宽, 1.0) > 0.5, "六维格占父容器过半宽（右侧被填实）")
	# 且值字号仍满足 ≤36 红线
	if 六系 != null and 六系.has("体魂"):
		var 字号: int = _字号(六系["体魂"])
		_log("     六维数值字号 = %d" % 字号)
		_ck(字号 <= 36, "六维数值 ≤ 36（既有红线）")

	# ══════ ② 状态说明弹窗字号 ══════
	_log("")
	_log("── ② 状态说明弹窗 ──")
	_详情.call("_show_info_popup", "当前状态", "闭关修炼中：灵气吸收速率提升，期间不可参与历练。\n\n· 修炼中：正常闭关，效率+20%", Vector2(540.0, 900.0))
	await _settle(6)
	var 弹: Node = _找(_详情, "InfoPopupPanel")
	_ck(弹 != null, "弹窗已弹出")
	if 弹 != null:
		var ls: Array = []
		_收Label(弹, ls)
		var 最大: int = 0
		for l in ls:
			最大 = maxi(最大, _字号(l))
		_log("     弹窗内 %d 个 Label，最大字号 = %d" % [ls.size(), 最大])
		_ck(最大 <= 33, "弹窗最大字号 ≤ 33（原标题 48 / 正文 45，两个字档几乎同大）")
	_详情.call("_close_info_popup")
	await _settle(2)

	# ══════ ⑦ 履历页字号 ══════
	_log("")
	_log("── ⑦ 履历页字号 ──")
	_详情._on_tab_pressed("履历")
	await _settle(10)
	var 履历页: Node = (_详情.get("_tab_pages") as Dictionary).get("履历", null)
	var ls2: Array = []
	_收Label(履历页, ls2)
	var 超: Array = []
	for l in ls2:
		var t: String = str(l.text)
		# 排除 emoji 图标（★ / ◆ 之类单字符符号）：只查「成句的文字」
		if t.length() > 4 and _字号(l) > 33:
			超.append("%s(%d)" % [t.left(10), _字号(l)])
	_log("     履历页 Label %d 个；>33 号的成句文字 %d 处" % [ls2.size(), 超.size()])
	if 超.size() > 0:
		_log("       超限样例：%s" % str(超.slice(0, 6)))
	_ck(超.size() == 0, "履历页正文无一处 >33（原大量 45/48/60 当正文）")
	var 资质行: Label = null
	for l in ls2:
		if str(l.text).contains("资质"):
			资质行 = l
			break
	if 资质行 != null:
		_log("     「%s」字号 = %d" % [str(资质行.text), _字号(资质行)])
		_ck(_字号(资质行) <= 27, "基本信息行字号 ≤ 27（原 FONT_H1 48）")

	# ══════ ⑥ 灵兽头像框 ══════
	_log("")
	_log("── ⑥ 灵兽头像框 ──")
	_详情._on_tab_pressed("灵兽")
	await _settle(10)
	var 头像: Node = _详情.get("_beast_avatar")
	_ck(头像 != null, "灵兽头像节点存在")
	if 头像 != null:
		var 框: Node = 头像.get_parent()
		var 竖拉伸: bool = (int(框.size_flags_vertical) & Control.SIZE_SHRINK_CENTER) != 0
		_log("     框 = %s 尺寸 %.0f×%.0f size_flags_vertical=%d" % [
			str(框.name), 框.size.x, 框.size.y, int(框.size_flags_vertical)])
		_ck(竖拉伸, "头像框交叉轴已设 SHRINK_CENTER（不再被 HBoxContainer 拉到整行高）")
		_ck(absf(框.size.x - 框.size.y) <= 2.0,
			"头像框为正方（%.0f×%.0f，修复前被 name_vb 三行撑成竖长条）" % [框.size.x, 框.size.y])

	# ══════ ④ 装备页：立绘居中 + 八槽环绕 ══════
	_log("")
	_log("── ④ 装备页版面 ──")
	_详情._on_tab_pressed("装备")
	await _settle(12)
	var 舞台: Node = _找(_详情, "EquipStage")
	var 左列: Node = _找(_详情, "SlotColLeft")
	var 右列: Node = _找(_详情, "SlotColRight")
	var 立绘: Node = _详情.get("_paper_doll_portrait")
	_ck(舞台 != null and 左列 != null and 右列 != null, "装备舞台 / 左右槽列已创建")
	if 舞台 != null and 左列 != null and 右列 != null and 立绘 != null:
		var 立框: Node = 立绘.get_parent()
		var 槽左: int = _数名(左列, "EquipSlot_")
		var 槽右: int = _数名(右列, "EquipSlot_")
		var 槽表: Dictionary = _详情.get("_equip_slots")
		_log("     左列 %d 槽 / 右列 %d 槽 / _equip_slots 共 %d 项" % [槽左, 槽右, 槽表.size()])
		_log("     舞台 %.0f×%.0f ｜ 立绘 %.0f×%.0f ｜ 左列 x=%.0f 右列 x=%.0f" % [
			舞台.size.x, 舞台.size.y, 立框.size.x, 立框.size.y,
			左列.global_position.x, 右列.global_position.x])
		_ck(槽左 == 4 and 槽右 == 4, "八槽按 4+4 分列左右（原为居中 2×4 方块）")
		_ck(槽表.size() >= 8, "八个装备槽键位齐全（%d）" % 槽表.size())
		_ck(左列.global_position.x + 左列.size.x <= 立框.global_position.x + 1.0,
			"左槽列完全在立绘左侧（环绕成立）")
		_ck(立框.global_position.x + 立框.size.x <= 右列.global_position.x + 1.0,
			"右槽列完全在立绘右侧（环绕成立）")
		_ck(absf(立框.size.x - 420.0) <= 2.0, "立绘定尺 420 宽（%.0f）" % 立框.size.x)
		_ck(absf(舞台.size.y - 640.0) <= 2.0, "舞台高 640（%.0f）" % 舞台.size.y)
		var 舞台底: float = 舞台.global_position.y + 舞台.size.y
		_log("     舞台底 y=%.0f / 视口 %.0f（%.0f%%）" % [
			舞台底, _视口.y, (舞台底 / _视口.y) * 100.0])
		_ck(舞台底 <= _视口.y * 0.6, "舞台落在首屏（≤60% 视口高）⇒ 人与八槽同框")
		_ck(立绘.texture != null, "装备页立绘已加载贴图")
		# 装备页不该再有闲情雅趣
		_ck(_找(装备页, "休闲设置Panel") == null, "「装备」Tab 末尾不再挂闲情雅趣")

	# ══════ 汇总 ══════
	_log("")
	_log("── 附：页面节点总数 %d ──" % _数节点(_详情))
	_log("RESULT-PENDING")

func _数节点(根: Node) -> int:
	if 根 == null:
		return 0
	var n: int = 1
	for c in 根.get_children():
		n += _数节点(c)
	return n
