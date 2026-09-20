extends Node

## ===== 弟子录 / 弟子详情页 · 无头验收探针 · 2026-09-14 =====
## 走玩家真实路径：main.tscn → _登录_进入 → 新UI → _on_tab_selected("弟子") → 点卡片 → 弟子详情页。
## 验证本轮 6 项改动：
##   A. 弟子录首屏不再被「山门气象 / 万仙大誓」挡住（首张弟子卡落在首屏上半）
##   B. 命魂灯不再每行一盏（在宗弟子 0 盏）
##   C. 立绘取景顶部对齐（脸可见）
##   D. 三卡等高（命格 · 性格 · 道途）；注：勿在本文件写「点号 + 命格」以免触发废弃字段护栏
##   E. 名字行（境界行 + 历练/法器摘要）不出屏
##   F. 版面压缩：hero 占比、3 列互动、section 字号
##   G. 宗门气象抽屉已承接 山门气象 + 万仙大誓
##
## 用法（默认无头，不弹窗）：
##   <godot_console> --headless --path <proj> --scene res://tests/_t_disciple_ui.tscn
## 产物：res://.workbuddy/_disciple_ui.log

const LOG_PATH := "res://.workbuddy/_disciple_ui.log"
const 探针账号 := "disciple_ui"

var _lines: Array = []
var _fail: int = 0
var _ui: Node = null
var _视口: Vector2 = Vector2.ZERO

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

## 递归收集某节点下所有 Label 文本
func _收文本(根: Node, 出: Array) -> void:
	for c in 根.get_children():
		if c is Label:
			出.append(str(c.text))
		elif c is Button:
			出.append(str(c.text))
		_收文本(c, 出)

## 递归按名字找节点
func _找(根: Node, 名: String) -> Node:
	if 根.name == 名:
		return 根
	for c in 根.get_children():
		var r: Node = _找(c, 名)
		if r != null:
			return r
	return null

## 递归收集「◆ 」节标题（按先序＝版面上下顺序）
## 注意：互动培养的标题在 HBoxContainer 里（标题+红点同行），只扫直接子节点会漏 ⇒ 必须递归。
func _收节标题(根: Node, 出: Array) -> void:
	for c in 根.get_children():
		if c is Label and str(c.text).begins_with("◆ "):
			出.append(str(c.text))
		_收节标题(c, 出)

func _数节点(根: Node) -> int:
	var n: int = 1
	for c in 根.get_children():
		n += _数节点(c)
	return n

func _run() -> void:
	_log("=== 弟子录 / 弟子详情页 无头验收（2026-09-14）===")
	# ★ 无头模式虚拟屏是方的（实测 1920×1920）⇒ 几何类断言（首卡落首屏 / 右缘不出屏）会失真，
	#   故在实例化 UI 之前强制回手机竖屏 1080×1920（与 tests/_t_seamap_live.gd 同款处理）。
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
	_log(">>> 显示后端=%s 视口=%.0fx%.0f 弟子=%d 灵石=%d" % [
		DisplayServer.get_name(), _视口.x, _视口.y, Game.弟子列表.size(), Game.灵石])

	# ══════ 走真路由：点底部「弟子」Tab ══════
	_ui._on_tab_selected("弟子")
	await _settle(20)
	var 弟子页 = _ui.get("_current")
	if 弟子页 == null:
		_log(">>> FAIL 弟子页 _current 未创建")
		_fail += 1
		return
	_log(">>> 路由 OK：_current.name=%s" % str(弟子页.name))

	# ── A. 首屏不再被宗门级面板挡住 ──
	_log("")
	_log("── A. 弟子录首屏可直见弟子 ──")
	_ck(_找(弟子页, "KarmaSectPanel") == null, "「山门气象」固定面板已从弟子录移除")
	var 文本: Array = []
	_收文本(弟子页, 文本)
	var 含大誓: int = 0
	for t in 文本:
		if str(t).contains("万仙大誓"):
			含大誓 += 1
	_ck(含大誓 == 0, "弟子录内已无「万仙大誓」字样（实际 %d 处）" % 含大誓)
	_ck(_找(弟子页, "RumorBand") != null, "门中异闻带存在（有异闻才占一行）")
	var 异闻条 = _找(弟子页, "RumorBand")
	if 异闻条 != null:
		_log("     异闻带 visible=%s（%d 条异闻）" % [str(异闻条.visible),
			(弟子页._异闻容器.get_child_count() if 弟子页._异闻容器 != null else -1)])

	var 首卡: Control = null
	var 卡片数: int = 0
	var 灯数: int = 0
	if 弟子页._list_vbox != null:
		for c in 弟子页._list_vbox.get_children():
			if str(c.name).begins_with("Card_"):
				卡片数 += 1
				if 首卡 == null:
					首卡 = c
				灯数 += _递归数名(c, "命魂灯")
	_ck(卡片数 > 0, "弟子列表渲染出 %d 张卡片" % 卡片数)
	if 首卡 != null:
		var r: Rect2 = 首卡.get_global_rect()
		_log("     首张弟子卡 global=(%.0f,%.0f) 高=%.0f" % [r.position.x, r.position.y, r.size.y])
		_ck(r.position.y < _视口.y * 0.50,
			"首张弟子卡落在首屏上半（y=%.0f < 视口 50%%=%.0f）" % [r.position.y, _视口.y * 0.5])
	_ck(灯数 == 0, "在宗弟子不再挂命魂灯（实际 %d 盏；旧版每行一盏米白灯座 ⇒ 一片白）" % 灯数)

	# ── A2. 顶栏「批量操作」已删（一键晋升 + 白送全体忠诚，违铁律 11「职责归属」）──
	_ck(_找(弟子页, "BatchBtn") == null, "顶栏「批量操作」按钮已移除（该职能回归执事殿月课自动流转）")
	var 列表文本: Array = []
	_收文本(弟子页, 列表文本)
	var 有批: bool = false
	var 疑似id: Array = []
	for t in 列表文本:
		var s2: String = str(t)
		if s2.contains("批量操作"):
			有批 = true
		if s2.length() >= 3 and _是纯ASCII标识(s2):
			疑似id.append(s2)
	_ck(not 有批, "弟子录内已无「批量操作」字样")
	_ck(疑似id.is_empty(), "弟子录无「原始 id 裸奔」标签（如 qitang）：%s" % str(疑似id))

	# ══════ 打开弟子详情页（真实路由）══════
	_log("")
	_log("── C~F. 弟子详情页 ──")
	if Game.弟子列表.size() == 0:
		_log(">>> SKIP 详情页：本档无弟子")
	else:
		var 目标 = Game.弟子列表[0]
		_log("     目标弟子=%s 性格=%s 气质=%s 立绘类型=%s 立绘变体=%d 性别=%s 头像=%s" % [
			str(目标.姓名), str(目标.性格), str(目标.获取气质()), str(目标.立绘类型),
			int(目标.立绘变体), str(目标.性别), 目标.取头像路径()])
		_ui._open_disciple_detail(目标)
		await _settle(24)
		var 详情 = _ui.get("_current_sub")
		if 详情 == null:
			_log(">>> FAIL 弟子详情页未创建")
			_fail += 1
		else:
			# C. 立绘取景：顶部对齐 ⇒ 脸可见
			var 立 = 详情.get("_portrait")
			var 取景 = 详情.get("_hero_area")
			_ck(立 != null and 立.texture != null, "立绘画布已加载贴图")
			if 立 != null and 取景 != null:
				var 图高: float = float(立.texture.get_height())
				var 图宽: float = float(立.texture.get_width())
				var 框: Vector2 = 取景.get_size()
				var 缩放: float = max(框.x / 图宽, 框.y / 图高)
				var 绘制高: float = 图高 * 缩放
				_log("     原图 %.0fx%.0f  取景框 %.0fx%.0f  绘制高=%.0f  offset_top=%.1f" % [
					图宽, 图高, 框.x, 框.y, 绘制高, 立.offset_top])
				_ck(绘制高 > 框.y, "立绘高于取景框（需裁切）")
				_ck(absf(立.offset_top) <= 1.0,
					"立绘顶部对齐（offset_top=%.1f ≈ 0）⇒ 发顶与脸在画面内，不再被居中裁掉" % 立.offset_top)
			var ratio: float = float(详情.get_script().get_script_constant_map().get("_HERO_RATIO", -1.0))
			_ck(absf(ratio - 0.45) < 0.001, "hero 占比 _HERO_RATIO=%.2f（0.55→0.45，给下半屏让位）" % ratio)

			# D. 三卡等高
			var 卡高: Array = []
			for k in ["_destiny_label", "_personality_label", "_daotu_label"]:
				var vb = 详情.get(k)
				if vb != null and vb.get_child_count() > 0:
					卡高.append(vb.get_child(0).get_size().y)
			_log("     命格/性格/道途 卡高 = %s" % str(卡高))
			if 卡高.size() == 3:
				_ck(absf(float(卡高[0]) - float(卡高[1])) <= 1.0 and absf(float(卡高[1]) - float(卡高[2])) <= 1.0,
					"三卡等高（不再出现「性格」比别人高半格）")
				_ck(float(卡高[0]) > 0.0, "三卡已完成布局（高>0）")

			# E. 名字行不出屏
			for k in ["_power_realm", "_power_summary", "_power_name", "_power_label"]:
				var lb = 详情.get(k)
				if lb != null:
					var gr: Rect2 = lb.get_global_rect()
					var 右缘: float = gr.position.x + gr.size.x
					_ck(右缘 <= _视口.x + 1.0,
						"%s 右缘=%.0f ≤ 屏宽 %.0f（未出屏）" % [k, 右缘, _视口.x])

			# E2. 横向溢出回归护栏（比单看「战力右缘」更强：任何子节点撑宽都会命中）
			#   背景：根因是 detail_vb 里某个未换行的长 Label（如「命格重铸」说明 27 字 @45px）
			#   把整页 minimum 宽顶到 1207，ScrollContainer 被撑到 1215 > 屏宽 1080，
			#   于是「◆战力」被一路推到 x=1207（旧反馈「信息跑到屏幕外面去了」的第一真凶）。
			var 详vb: Control = 详情.get("_tab_pages").get("详情", null)
			if 详vb != null:
				var 详最小宽: float = 详vb.get_combined_minimum_size().x
				var 果: Array = _最宽子孙(详vb, "")
				_log("     detail_vb min.x=%.0f（屏宽 %.0f）  最宽子孙=%s" % [详最小宽, _视口.x, str(果[1])])
				_ck(详最小宽 <= _视口.x + 1.0,
					"详情页内容最小宽 %.0f ≤ 屏宽 %.0f（无横向溢出 ⇒ 战力/摘要不会被推出屏）" % [详最小宽, _视口.x])

			# F. 版面压缩
			var 互动 = _找(详情, "Hudong_论道切磋")
			if 互动 != null and 互动.get_parent() != null:
				_ck(int(互动.get_parent().columns) == 3,
					"互动培养改为 3 列（5 钮 3 列=2 行，原 2 列=3 行）")
			var 节标题: Label = null
			var 详情页vb = 详情.get("_tab_pages").get("详情", null)
			if 详情页vb != null:
				for c in 详情页vb.get_children():
					if c is Label and str(c.text).begins_with("◆ "):
						节标题 = c
						break
			if 节标题 != null:
				var fs: int = 节标题.get_theme_font_size("font_size")
				_log("     section 标题字号=%dpx（设计值 14×UI_SCALE）" % fs)
				_ck(fs <= int(round(14 * 2.25)) + 1, "section 字号已降到 14 档（16→14）")
			_log("     详情页节点总数=%d" % _数节点(详情))

			# ══════ H. 2026-09-14 第二轮改版（职责归属 / 字号 / 条件触发）══════
			_log("")
			_log("── H. 详情页第二轮改版 ──")
			var 详vbH = 详情.get("_tab_pages").get("详情", null)

			# H1. 立绘「看全图」
			var 全图钮: Button = 详情.get("_portrait_view_btn")
			_ck(全图钮 != null and str(全图钮.name) == "PortraitViewBtn",
				"立绘上已挂「看全图」按钮（%s）" % (str(全图钮.text) if 全图钮 != null else "null"))
			if 全图钮 != null:
				详情._on_portrait_view_pressed()
				await _settle(4)
				var 层 = _找(详情, "PortraitFullView")
				_ck(层 != null, "点击后弹出全图浮层 PortraitFullView")
				var 整图 = _找(详情, "FullPortrait")
				if 整图 != null:
					_ck(int(整图.stretch_mode) == int(TextureRect.STRETCH_KEEP_ASPECT_CENTERED),
						"浮层整图用 KEEP_ASPECT_CENTERED（完整入框、不裁切）")
					_ck(整图.texture == 立.texture, "浮层用的是同一张立绘贴图")
				详情._on_portrait_view_pressed()
				await _settle(4)
				_ck(_找(详情, "PortraitFullView") == null, "再点一次可关闭全图浮层")

			# H2. 无冗余三卡组标题（拆掉「命格·性格·道途」「心境·道心·心魔」）
			var 组标题: Array = []
			if 详vbH != null:
				_收节标题(详vbH, 组标题)
			_log("     详情页 section 标题序列=%s" % str(组标题))
			_ck(not 组标题.has("◆ 命格·性格·道途"), "已删冗余组标题「命格·性格·道途」（三卡自带卡名）")
			_ck(not 组标题.has("◆ 心境·道心·心魔"), "已删冗余组标题「心境·道心·心魔」（三卡自带卡名）")

			# H3. 六维属性：图大文字小
			var 雷达 = 详情.get("_radar")
			if 雷达 != null:
				var 图min宽: float = float(雷达.custom_minimum_size.x)
				_log("     雷达图 min 宽=%.0f" % 图min宽)
				_ck(图min宽 >= 200.0, "雷达图已放大（min 宽 %.0f ≥ 200，原 170）" % 图min宽)
			var 六系 = 详情.get("_six_labels")
			if 六系 != null and 六系.has("体魂"):
				var 六字: int = 六系["体魂"].get_theme_font_size("font_size")
				_log("     六维数值字号=%dpx" % 六字)
				_ck(六字 <= 36, "六维数值降为小字（%dpx ≤ 36，原 FONT_TITLE 45）" % 六字)

			# H4. 互动培养：条件触发（无触发 ⇒ 整块隐藏）
			详情._刷新互动区(目标)
			await _settle(4)
			var 互头 = 详情.get("_hudong_head")
			var 互板 = 详情.get("_hudong_panel")
			var 可用: Array = 详情._取可用互动列表(目标)
			var 可拜师: bool = 详情._有可拜之师(目标)
			var 应显: bool = 可用.size() > 0 or 可拜师 or int(目标.师父ID) > 0
			_log("     可用互动=%d 项  可拜师=%s  须显=%s  实显 标题/面板=%s/%s" % [
				可用.size(), str(可拜师), str(应显),
				str(互头.visible) if 互头 != null else "null",
				str(互板.visible) if 互板 != null else "null"])
			_ck(互头 != null and 互板 != null, "互动培养 标题行 / 面板已就位")
			if 互头 != null and 互板 != null:
				_ck(互头.visible == 应显 and 互板.visible == 应显,
					"互动培养「有触发才出现、无触发整块隐藏」成立")
				if 应显:
					var 红点 = 详情.get("_hudong_dot")
					_ck(红点 != null and 红点.visible, "有可办之事时红点已亮（红点体系同源）")
			var 互按钮 = 详情.get("_hudong_buttons")
			if 互按钮 != null:
				var 显数: int = 0
				for k in 互按钮.keys():
					if 互按钮[k] != null and 互按钮[k].visible:
						显数 += 1
				_ck(显数 == 可用.size(),
					"未触发的互动按钮已隐藏（可见 %d / 共 %d / 可用 %d）" % [显数, 互按钮.size(), 可用.size()])

			# H5. 心魔誓：只读（无玩家立誓/解誓入口）
			var 誓文本: Array = []
			var 誓盒 = 详情.get("_oath_box")
			if 誓盒 != null:
				_收文本(誓盒, 誓文本)
			var 誓串: String = "|".join(誓文本)
			_log("     心魔誓区文本=%s" % 誓串)
			_ck(not 誓串.contains("以此立誓"), "心魔誓区已无「以此立誓」手动立誓钮")
			_ck(not 誓串.contains("立心魔誓"), "心魔誓区已无「立心魔誓」折叠钮")
			_ck(not 誓串.contains("解誓"), "心魔誓区已无「解誓」钮（誓由弟子起，不可玩家随手解除）")
			_ck(目标.誓言.is_empty() == 誓串.contains("无誓约在身"),
				"心魔誓区按「有/无誓约」如实显示状态")

			# H6/H7. 玩家操作面清理（只留「宗主不可代劳」的决策）
			var 详文本: Array = []
			if 详vbH != null:
				_收文本(详vbH, 详文本)
			var 详串: String = "|".join(详文本)
			_ck(not 详串.contains("学习功法（"), "已学功法已无「学习功法」手动钮（改自动习得）")
			_ck(not 详串.contains("服用丹药（宗门丹药库）"), "丹药已无「服用丹药」手动钮（改自动服用）")
			_ck(详串.contains("洗池") or 详串.contains("洗髓"), "洗池·洗髓（原命格重铸）保留手动付费入口")
			_ck(not 详串.contains("命格重铸"), "旧标题「命格重铸」已正名为「洗池 · 洗髓」")
			_ck(not 详串.contains("任命司职"), "底部死按钮「调遣/任命司职」已移除（未接任何回调）")
			_ck(not 详串.contains("闭关提升"), "底部死按钮「修炼/闭关提升」已移除（未接任何回调）")
			_ck(详情.get("_驱逐_btn") != null, "底部保留「驱逐师门」（唯一保留的玩家重决策）")

			# H8. 字号统一（战力构成 / 突破 / 状态 / 功法不再比别人大一号）
			for k2 in ["_breakthrough_label", "_status_label"]:
				var lb2 = 详情.get(k2)
				if lb2 != null:
					var f2: int = lb2.get_theme_font_size("font_size")
					_ck(f2 <= 33, "%s 字号=%dpx ≤ 33（原 FONT_H1 48 当正文）" % [k2, f2])
			for k3 in ["_gongfa_list_label", "_danyao_list_label"]:
				var lb3 = 详情.get(k3)
				if lb3 != null:
					var f3: int = lb3.get_theme_font_size("font_size")
					_ck(f3 <= 27, "%s 字号=%dpx ≤ 27（原 FONT_TITLE 45 当正文）" % [k3, f3])

			# H9. 信息优先度：高频在前
			if 详vbH != null:
				var 标题序: Array = []
				_收节标题(详vbH, 标题序)
				var 序: Dictionary = {}
				for i in range(标题序.size()):
					序[str(标题序[i])] = i
				_log("     标题索引=%s" % str(序))
				if 序.has("◆ 突破进度") and 序.has("◆ 六维属性"):
					_ck(int(序["◆ 突破进度"]) < int(序["◆ 六维属性"]),
						"「突破进度」排在「六维属性」之前")
				if 序.has("◆ 互动培养") and 序.has("◆ 已学功法"):
					_ck(int(序["◆ 互动培养"]) < int(序["◆ 已学功法"]),
						"「互动培养」排在「已学功法」之前")
				if 序.has("◆ 护道人 · 牵绊") and 序.has("◆ 已学功法"):
					_ck(int(序["◆ 护道人 · 牵绊"]) < int(序["◆ 已学功法"]),
						"「护道人·牵绊」排在低频的「已学功法」之前")

			# H10. 「以毒攻毒」＝宗主亲自施治（与「宗主护法」同类，不进每日互动次数体系）
			#   存在意义：① 条件触发而非常驻；② 它同时是 `Game.以毒攻毒治疗` 与
			#   `_on以毒攻毒治疗` 的唯一消费方（否则二者会掉进「死函数水位」闸门）。
			var 毒钮: Button = null
			var 互钮表 = 详情.get("_hudong_buttons")
			if 互钮表 != null and 互钮表.has("以毒攻毒"):
				毒钮 = 互钮表["以毒攻毒"]
			_ck(毒钮 != null, "互动区含「以毒攻毒」钮（宗主毒道亲施）")
			if 毒钮 != null:
				var 应显毒: bool = int(目标.受伤剩余) > 0 and str(Game.获取毒道境界()) != ""
				_log("     以毒攻毒：受伤剩余=%d 宗主毒道=%s 应显=%s 实显=%s" % [
					int(目标.受伤剩余), str(Game.获取毒道境界()), str(应显毒), str(毒钮.visible)])
				_ck(毒钮.visible == 应显毒, "以毒攻毒按「弟子有伤 + 宗主毒道有成」触发")
				if 毒钮.visible:
					_ck(str(毒钮.text) == "以毒攻毒", "以毒攻毒按钮不显示「剩余N次」（非次数体系）")

	# ══════ G. 宗门气象抽屉 ══════
	_log("")
	_log("── G. 宗门气象抽屉承接宗门级内容 ──")
	_ui._on_气象带请求()
	await _settle(14)
	var 抽屉 = _ui.get("_气象抽屉")
	_ck(抽屉 != null, "气象抽屉已打开")
	if 抽屉 != null:
		var 抽屉文本: Array = []
		_收文本(抽屉, 抽屉文本)
		var 有气象: bool = false
		var 有大誓段: bool = false
		var 有望气钮: bool = false
		var 有方针钮: bool = false
		for t in 抽屉文本:
			var s: String = str(t)
			if s == "山门气象":
				有气象 = true
			if s.contains("万仙大誓（全宗共誓）"):
				有大誓段 = true
			if s.begins_with("望宗门气运（"):
				有望气钮 = true
			if s.begins_with("突破方针："):
				有方针钮 = true
		_ck(有气象, "抽屉含「山门气象」段")
		_ck(有望气钮, "抽屉含「望宗门气运」按钮")
		_ck(有方针钮, "抽屉含「突破方针」按钮（C3 宗主干预接口③）")
		_ck(有大誓段, "抽屉含「万仙大誓（全宗共誓）」段")
		_ui._关闭气象抽屉()
		await _settle(6)
		_ck(_ui.get("_气象抽屉") == null, "抽屉可关闭")
	_log("")
	_log(">>> 弟子页节点总数=%d" % _数节点(弟子页))

func _递归数名(根: Node, 名: String) -> int:
	var n: int = 1 if str(根.name) == 名 else 0
	for c in 根.get_children():
		n += _递归数名(c, 名)
	return n

## 递归找 minimum 宽度最大的子孙；返回 [最宽, 路径]
func _最宽子孙(根: Node, 前缀: String) -> Array:
	var 最宽: float = 0.0
	var 最宽路径: String = ""
	var 本路径: String = 前缀 + "/" + str(根.name)
	if 根 is Control:
		最宽 = (根 as Control).get_combined_minimum_size().x
		最宽路径 = 本路径 + "(" + 根.get_class() + ")"
	for c in 根.get_children():
		var r: Array = _最宽子孙(c, 本路径)
		if r.size() == 2 and float(r[0]) > 最宽:
			最宽 = float(r[0])
			最宽路径 = str(r[1])
	return [最宽, 最宽路径]

## 纯 ASCII 标识（≥3 位字母/数字/下划线，且**至少含 1 个字母**）＝疑似「原始 id 裸奔」（如 qitang）
## ★ 必须要求「含字母」：纯数字也是合法显示值（如「900」灵石/声望），
##   否则会把正常数字标签误判为 id（2026-09-14 首跑实测：`["900"]` 假阳性）。
## 用途：A2 断言——列表 pill 不该直接把司职 key 印出来。
func _是纯ASCII标识(s: String) -> bool:
	var t: String = s.strip_edges()
	if t.length() < 3:
		return false
	var 有字母: bool = false
	for i in range(t.length()):
		var c: String = t[i]
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			有字母 = true
			continue
		if (c >= "0" and c <= "9") or c == "_":
			continue
		return false
	return 有字母
