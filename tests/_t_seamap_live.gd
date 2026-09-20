extends Node

## ===== 无缝大地图 · 实机验收探针（真实渲染，走真机主流程）· 2026-09-14 =====
## 走玩家真实路径：main.tscn → _登录_进入 → 新UI → _open_world_map_page()（= 点首页「天下」）。
## 每次运行前用 Game.删除账号() 清掉探针账号 ⇒ 必定走「全新账号」分支（覆盖新档初始化）。
## 只读原则：不清迷雾、不改资源点/宗门数据；只驱动 UI 输入与缩放。
##
## 覆盖老大关心的 4 点：①首屏迷雾揭示比例 ②拖拽顺滑度+松手惯性 ③边界云雾淡出+缩放保护 ④秘境点位可点
## 附带：标记分类清点、坐标双轨可逆、节点总数、固定屏幕元素定位（游离元素排查）。
##
## 用法（默认无头 —— 不弹游戏窗口，不占老大的屏幕/焦点）：
##   <godot_console> --headless --path <proj> --scene res://tests/_t_seamap_live.tscn
##   ↑ 逻辑结论全跑（迷雾比例/缩放约束/域分布/秘境可点/坐标双轨）；截图自动跳过。
## 仅当需要「看图」时才带窗口（会弹窗，尽量少用）：
##   <godot_console> --path <proj> --scene res://tests/_t_seamap_live.tscn
## 产物：res://.workbuddy/_seamap_live.log（+ 带窗口跑时 res://.workbuddy/shots_seamap_live/*.png）

const LOG_PATH := "res://.workbuddy/_seamap_live.log"
const SHOT_DIR := "res://.workbuddy/shots_seamap_live/"
const 探针账号 := "seamap_live"

var _lines: Array = []
var _page = null
var _ui: Node = null

func _log(s: String) -> void:
	_lines.append(s)

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
		_log(">>> TIMEOUT 自毁触发")
		_flush()
		get_tree().quit(1))
	add_child(t)
	t.start()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	await get_tree().process_frame
	await _run()
	_flush()
	get_tree().quit(0)

func _const_of(node, name: String, fallback: float) -> float:
	var sc: Script = node.get_script()
	if sc == null:
		return fallback
	var m: Dictionary = sc.get_script_constant_map()
	if m.has(name):
		return float(m[name])
	return fallback

# 迷雾格数（新实现＝单张 20×20 遮罩位图，按 alpha 统计未探索格）
func _数迷雾(p) -> int:
	var 图 = p._迷雾图
	if 图 == null:
		return -1
	var c: int = 0
	for j in range(图.get_height()):
		for i in range(图.get_width()):
			if 图.get_pixel(i, j).a > 0.01:
				c += 1
	return c

func _数节点(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _数节点(ch)
	return c

func _按下(p: Vector2) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	return e

func _松开(p: Vector2) -> InputEventMouseButton:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = p
	return e

func _移动(p: Vector2) -> InputEventMouseMotion:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = p
	e.relative = Vector2.ZERO
	return e

func _shoot(名: String) -> void:
	# --headless 下没有渲染后端：frame_post_draw 不推进、viewport 纹理取到空图 ⇒ 直接跳过。
	# 所有结论性断言（迷雾比例/缩放约束/域分布/秘境可点/坐标双轨）都是节点与数值层的事实，
	# 不依赖像素，故无头模式能跑出全部结论；只有「看图」这一步需要带窗口跑。
	if DisplayServer.get_name() == "headless":
		_log(">>> SHOT %s 跳过（无头模式，无渲染后端）" % 名)
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(SHOT_DIR + 名)
	_log(">>> SHOT %s err=%d 尺寸=%dx%d" % [名, err, img.get_width(), img.get_height()])

# 硬删目录（递归）—— 探针自保：游戏侧 删除账号 依赖回收站，实测会残留
func _删目录(root: String) -> void:
	var da: DirAccess = DirAccess.open(root)
	if da == null:
		return
	da.list_dir_begin()
	var n: String = da.get_next()
	while n != "":
		if n != "." and n != "..":
			if da.dir_exists(n):
				_删目录(root.path_join(n))
			else:
				DirAccess.remove_absolute(root.path_join(n))
		n = da.get_next()
	da.list_dir_end()
	DirAccess.remove_absolute(root)

# 列出某节点的直接子级（Control 带屏幕矩形），用于定位固定位置的游离元素
func _列子(p: Node, 标题: String) -> void:
	var 区: Vector2 = get_viewport().get_visible_rect().size
	_log(">>> [子级] %s 共 %d 个" % [标题, p.get_child_count()])
	for n in p.get_children():
		if n is Control:
			var r: Rect2 = (n as Control).get_global_rect()
			_log("      %s(%s) pos=(%.0f,%.0f) size=(%.0f,%.0f) 可见=%s" % [
				str(n.name), n.get_class(), r.position.x, r.position.y, r.size.x, r.size.y, str((n as Control).visible)])
		else:
			_log("      %s(%s)" % [str(n.name), n.get_class()])

# 地图层子节点普查（按 类型+尺寸 归类计数）——用于确认域板/迷雾/装饰的实际节点形态
func _普查地图层(p) -> void:
	var 计: Dictionary = {}
	for n in p._地图层.get_children():
		var k: String = ""
		if n is TextureRect:
			var r: Vector2 = (n as TextureRect).size
			k = "TextureRect %d×%d" % [int(r.x), int(r.y)]
		elif n is PanelContainer:
			var s: Vector2 = (n as PanelContainer).size
			k = "PanelContainer %d×%d" % [int(s.x), int(s.y)]
		elif n is Button:
			k = "Button"
		elif n is Label:
			k = "Label"
		else:
			k = str(n.get_class())
		计[k] = int(计.get(k, 0)) + 1
	var ks: Array = 计.keys()
	ks.sort()
	_log(">>> [普查] 地图层直接子级 共 %d 个：" % p._地图层.get_child_count())
	for k in ks:
		_log("      %s × %d" % [str(k), int(计[k])])

# 全树扫描：找出屏幕矩形与「目标区」相交的所有可见 Control（定位固定位置游离元素）
func _扫游离(目标: Rect2) -> void:
	_log(">>> [游离] 目标屏幕矩形=%s" % str(目标))
	var 命中: int = 0
	var 栈: Array = [get_tree().root]
	while not 栈.is_empty():
		var n: Node = 栈.pop_back()
		for c in n.get_children():
			栈.append(c)
		if n is Control:
			var ctl: Control = n as Control
			if not ctl.is_visible_in_tree():
				continue
			var r: Rect2 = ctl.get_global_rect()
			if r.intersects(目标):
				命中 += 1
				var 附: String = ""
				if ctl is Label:
					附 = " text=[%s]" % str((ctl as Label).text)
				elif ctl is Button:
					附 = " btn=[%s]" % str((ctl as Button).text)
				elif ctl is TextureRect:
					附 = " tex=%s" % str((ctl as TextureRect).texture)
				_log("      命中 %s(%s) layerZ=%d rect=%s%s" % [
					str(ctl.name), ctl.get_class(), ctl.z_index, str(r), 附])
	_log(">>> [游离] 命中可见 Control 数=%d" % 命中)

# 全树扫描：列出可见 Label 中含「符号/emoji 码点」者（游离 emoji 字形来源）
func _扫emoji() -> void:
	var 数: int = 0
	var 栈: Array = [get_tree().root]
	_log(">>> [emoji] 全树可见 Label 含符号码点者：")
	while not 栈.is_empty():
		var n: Node = 栈.pop_back()
		for c in n.get_children():
			栈.append(c)
		if n is Label:
			var l: Label = n as Label
			if not l.is_visible_in_tree():
				continue
			var t: String = l.text
			var 有: bool = false
			for i in range(t.length()):
				var cp: int = t.unicode_at(i)
				if (cp >= 0x2190 and cp <= 0x2BFF) or cp >= 0x1F000:
					有 = true
					break
			if 有 and 数 < 40:
				数 += 1
				_log("      %s rect=%s text=[%s]" % [str(l.get_path()), str(l.get_global_rect()), t])
	_log(">>> [emoji] 共列出 %d 条" % 数)

func _run() -> void:
	_log("=== 无缝大地图 实机验收（真机主流程 · 全新账号）===")
	_log(">>> 显示后端=%s（headless 时截图跳过；逻辑断言不受影响）" % DisplayServer.get_name())
	# 无头模式下没有真实窗口，Godot 的虚拟屏幕是方的（实测 1920×1920）⇒ 视口/动态最小缩放等
	#   几何类结论会失真。强制回手机竖屏 1080×1920 再测。
	if DisplayServer.get_name() == "headless":
		get_window().size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame
	var 视口尺寸: Vector2 = get_viewport().get_visible_rect().size
	_log(">>> 视口=%s" % str(视口尺寸))
	if Game == null:
		_log(">>> FAIL Game 单例缺失")
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		_log(">>> FAIL main.tscn 加载失败")
		return
	# 清掉探针账号 ⇒ 必定走 load_game 的「全新账号」分支
	# 注意：OS.move_to_trash 会报 SHFileOperation error 124 且档案残留（实测），游戏侧兜底没兜住 ⇒
	#   探针自己再硬删一次并复验，避免「清档伪成功」把新档用例悄悄变成读档用例。
	var 档根: String = "user://profiles/%s" % 探针账号
	_log(">>> [清档] 硬删前存在? %s" % str(DirAccess.dir_exists_absolute(档根)))
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	if DirAccess.dir_exists_absolute(档根):
		_删目录(档根)
	_log(">>> [清档] 硬删后存在? %s（false 才会走全新账号分支）" % str(DirAccess.dir_exists_absolute(档根)))
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": 探针账号})
	await _settle(18)
	_ui = main.get("新UI")
	if _ui == null:
		_log(">>> FAIL 新UI 为空")
		return
	var 世界 = Game.世界地图系统
	_log(">>> 新档初始化 · 宗门区域=%s 宗门坐标=(%.0f,%.0f) 资源点=%d 模拟宗门=%d" % [
		str(世界.宗门区域), float(世界.宗门坐标X), float(世界.宗门坐标Y),
		世界.资源点列表.size(), 世界.其他宗门列表.size()])
	_log(">>> 弟子=%d 灵石=%d" % [Game.弟子列表.size(), Game.灵石])

	# ── 走真路由：等价玩家在首页点「天下」入口 ──
	_ui._open_world_map_page()
	await _settle(22)
	_page = _ui.get("_current_sub")
	if _page == null:
		_log(">>> FAIL 地图页 _current_sub 未创建")
		return
	_log(">>> 路由 OK：_open_world_map_page → _current_sub.name=%s" % str(_page.name))
	_列子(_ui, "新UI 直接子级")
	_列子(_page, "地图页 直接子级")
	_列子(_page._地图容器, "地图容器 直接子级")
	_普查地图层(_page)

	# ══════ ① 首屏迷雾揭示比例 ══════
	var 画布: float = _const_of(_page, "地图宽度", 4000.0)
	var 格尺寸: float = _const_of(_page, "迷雾网格大小", 200.0)
	var 边长: int = int(画布 / 格尺寸)
	var 总格: int = 边长 * 边长
	var 迷雾: int = _数迷雾(_page)
	var 已探存: int = 世界.已探索网格.size()
	var 揭示比: float = float(总格 - 迷雾) / float(总格) * 100.0
	var 迷雾节点: int = _page._迷雾层.get_child_count()
	_log(">>> [①首屏] 画布=%.0f 网格=%d×%d=%d格 剩余迷雾=%d 存档已探=%d → 揭示比=%.1f%%" % [
		画布, 边长, 边长, 总格, 迷雾, 已探存, 揭示比])
	_log(">>> [①首屏] 迷雾渲染节点数=%d（旧实现为 400 个 ColorRect，现为 1 张遮罩）" % 迷雾节点)
	_log(">>> [①首屏] 初始缩放=%.3f 偏移=(%.0f,%.0f) 地图视口=%s" % [
		_page._缩放, _page._偏移.x, _page._偏移.y, str(_page._地图容器.size)])
	await _shoot("01_首屏.png")

	# ══════ ①-b 游离金色元素定位（截图上 720×(659,944) 的固定图标）══════
	# 截图 720×1280 为视口 1080×1920 的 2/3 缩略 ⇒ ×1.5 还原；留 20px 余量
	var 目标: Rect2 = Rect2(Vector2(942.0, 1371.0), Vector2(93.0, 90.0))
	_扫游离(目标)
	_扫emoji()

	# ══════ 标记分类清点 ══════
	var 计数: Dictionary = {}
	var 秘境列表: Array = []
	for m in _page._地点标记:
		var t: String = str(m["类型"])
		计数[t] = int(计数.get(t, 0)) + 1
		if t == "秘境":
			秘境列表.append(m)
	var 明细: Array = []
	for k in 计数.keys():
		明细.append("%s=%d" % [str(k), int(计数[k])])
	_log(">>> [标记] 上图点位总数=%d → %s" % [_page._地点标记.size(), ", ".join(明细)])
	_log(">>> [标记] 资源点数据=%d 秘境数据=%d（均为真源表规模）" % [
		世界.资源点列表.size(), 秘境列表.size()])

	# ══════ 标记的「域分布」：验证域内口径抬升后不再全挤在中州板 ══════
	var 域计: Dictionary = {}
	for m in _page._地点标记:
		var lg: Vector2 = _page._视觉转逻辑(float(m["x"]), float(m["y"]))
		var 归域: String = "框外"
		for 域名 in 世界.区域逻辑范围.keys():
			var f: Dictionary = 世界.区域逻辑范围[域名]
			if lg.x >= float(f["x1"]) and lg.x <= float(f["x2"]) and lg.y >= float(f["y1"]) and lg.y <= float(f["y2"]):
				归域 = str(域名)
				break
		域计[归域] = int(域计.get(归域, 0)) + 1
	var 域明: Array = []
	for k in 域计.keys():
		域明.append("%s=%d" % [str(k), int(域计[k])])
	_log(">>> [分布] 标记按域画布框归类：%s" % ", ".join(域明))

	# ══════ ② 拖拽顺滑度 + 松手惯性 ══════
	var 视口: Vector2 = _page._地图容器.size
	var 中心: Vector2 = 视口 * 0.5
	# _build_ui 完整性哨兵：若中途报错，详情面板/事件面板会是 null、gui_input 也没连上
	_log(">>> [②哨兵] gui_input 连接数=%d（应≥1） 详情面板=%s 事件面板=%s" % [
		_page._地图容器.gui_input.get_connections().size(),
		str(_page._详情面板 != null), str(_page._事件面板 != null)])
	# 先把地图挪到可平移区间的正中：初始 偏移 由 _定位到宗门 定在宗门处，若宗门贴近图边，
	#   拖动会立刻被 _约束偏移 截断 ⇒ 会被误读成「拖不动」。居中后位移才反映真实跟手度。
	_page._偏移 = -Vector2(
		maxf(0.0, 画布 * _page._缩放 - 视口.x),
		maxf(0.0, 画布 * _page._缩放 - 视口.y)) * 0.5
	_page._更新地图变换()
	var 偏0: Vector2 = _page._偏移
	_page._地图容器.gui_input.emit(_按下(中心))
	for i in range(5):
		_page._地图容器.gui_input.emit(_移动(中心 + Vector2(30.0, 18.0) * float(i + 1)))
	var 偏拖: Vector2 = _page._偏移
	var 拖动位移: Vector2 = 偏拖 - 偏0
	_page._地图容器.gui_input.emit(_松开(中心 + Vector2(150.0, 90.0)))
	_log(">>> [②拖拽] 5 段拖动(每段+30,+18) 位移=(%.0f,%.0f) 模长=%.0f 拖动中标记=%s" % [
		拖动位移.x, 拖动位移.y, 拖动位移.length(), str(_page._拖动中)])
	var 速度样本: Array = []
	for i in range(10):
		await get_tree().process_frame
		速度样本.append(snappedf(_page._拖动速度.length(), 0.01))
	var 单调: bool = true
	for i in range(1, 速度样本.size()):
		if 速度样本[i] > 速度样本[i - 1] + 0.02:
			单调 = false
	_log(">>> [②惯性] 松手后逐帧末速度=%s" % str(速度样本))
	_log(">>> [②惯性] 单调衰减=%s 收尾速度=%.2f（<1.0 即归零停住）" % [str(单调), 速度样本[-1]])
	await _shoot("02_拖拽后.png")

	# ══════ ③ 缩放保护 + 边界云雾淡出 ══════
	var 下限: float = _page._动态最小缩放()
	var 上0: float = _page._缩放
	for i in range(40):
		_page._调整缩放(-0.1)
	var 缩放下限值: float = _page._缩放
	var 地图视: Vector2 = Vector2(画布, 画布) * 缩放下限值
	var 盖满: bool = 地图视.x >= 视口.x - 0.5 and 地图视.y >= 视口.y - 0.5
	_log(">>> [③缩放] 初始=%.3f → 连缩 40 次 → %.3f（动态下限=%.3f 绝对下限=%.1f）" % [
		上0, 缩放下限值, 下限, _const_of(_page, "最小缩放", 0.3)])
	_log(">>> [③缩放] 最小缩放下 地图视=(%.0f,%.0f) 视口=(%.0f,%.0f) 盖满视口=%s（⇒不露黑区）" % [
		地图视.x, 地图视.y, 视口.x, 视口.y, str(盖满)])
	for 角 in [Vector2(999999.0, 999999.0), Vector2(-999999.0, -999999.0)]:
		_page._偏移 = 角
		_page._更新地图变换()
		var 越界: bool = (_page._偏移.x > 0.001) or (_page._偏移.y > 0.001) \
			or ((_page._偏移.x + 地图视.x) < 视口.x - 0.5) or ((_page._偏移.y + 地图视.y) < 视口.y - 0.5)
		_log(">>> [③约束] 置偏移=%s → 实际=(%.0f,%.0f) 出界=%s" % [
			str(角), _page._偏移.x, _page._偏移.y, str(越界)])
	await _shoot("03_最小缩放_边界.png")
	var 渐隐: int = 0
	var 渐隐基色: Color = Color.BLACK
	for n in _page._地图容器.get_children():
		if n is TextureRect and (n as TextureRect).texture is GradientTexture2D:
			渐隐 += 1
			var gt: GradientTexture2D = (n as TextureRect).texture
			渐隐基色 = gt.gradient.get_color(0)
	var 压暗色: Color = UITheme.获取场景压暗色()
	var 基色一致: bool = absf(渐隐基色.r - 压暗色.r) < 0.01 and absf(渐隐基色.g - 压暗色.g) < 0.01 and absf(渐隐基色.b - 压暗色.b) < 0.01
	_log(">>> [③边界] 视口内渐隐条=%d（应=4）带宽=%dpx 基色=(%.3f,%.3f,%.3f) =场景压暗色? %s" % [
		渐隐, UITheme.边界渐隐带宽, 渐隐基色.r, 渐隐基色.g, 渐隐基色.b, str(基色一致)])
	for i in range(14):
		_page._调整缩放(0.1)
	_log(">>> [③缩放] 连放 14 次 → %.3f（上限=%.1f）" % [_page._缩放, _const_of(_page, "最大缩放", 2.0)])
	await _shoot("05_放大细节.png")

	# ══════ ④ 秘境点位可点 ══════
	if 秘境列表.is_empty():
		_log(">>> [④秘境] FAIL 无秘境标记上图")
	else:
		var 秘: Dictionary = 秘境列表[0]
		var 秘点: Vector2 = Vector2(float(秘["x"]), float(秘["y"]))
		_page._缩放 = clampf(1.2, _page._动态最小缩放(), 2.0)
		_page._偏移 = 视口 * 0.5 - 秘点 * _page._缩放
		_page._更新地图变换()
		await _settle(3)
		var 屏上: Vector2 = _page._偏移 + 秘点 * _page._缩放
		var 钮: Button = 秘["节点"]
		_log(">>> [④秘境] 共 %d 处 · 取「%s」@视觉(%.0f,%.0f) 屏上=(%.0f,%.0f) 在视口内=%s" % [
			秘境列表.size(), str(秘["名称"]), 秘点.x, 秘点.y, 屏上.x, 屏上.y,
			str(屏上.x >= 0.0 and 屏上.x <= 视口.x and 屏上.y >= 0.0 and 屏上.y <= 视口.y)])
		_log(">>> [④秘境] 标记按钮 mouse_filter=STOP? %s 可见=%s（可点前提）" % [
			str(钮.mouse_filter == Control.MOUSE_FILTER_STOP), str(钮.visible)])
		钮.pressed.emit()
		await _settle(4)
		var 面板细节: String = ""
		if _page._详情面板 != null and _page._详情面板.get_child_count() > 0:
			var vbox = _page._详情面板.get_child(0)
			for c in vbox.get_children():
				if c is Label:
					面板细节 += str((c as Label).text) + " | "
		_log(">>> [④秘境] 点击后 详情面板.visible=%s 内容=%s" % [
			str(_page._详情面板 != null and _page._详情面板.visible), 面板细节])
		await _shoot("04_秘境详情.png")

	# ══════ 附：坐标双轨可逆 + 口径抬升一致性 + 节点总数 ══════
	var 系数: float = _const_of(_page, "世界映射系数", -1.0)
	var 视: Vector2 = _page._逻辑转视觉(120.0, -60.0)
	var 反: Vector2 = _page._视觉转逻辑(视.x, 视.y)
	_log(">>> [附·双轨] 系数=%.2f 全局逻辑=(120.0,-60.0) → 视觉=(%.1f,%.1f) → 反算=(%.3f,%.3f) 可逆=%s" % [
		系数, 视.x, 视.y, 反.x, 反.y,
		str(absf(反.x - 120.0) < 0.001 and absf(反.y + 60.0) < 0.001)])
	# 域内口径抬升：宗门（域内 ±200）→ 全局，应落回本域画布框内（否则就是又挤到中州板）
	var 宗门位置: Dictionary = 世界.获取宗门位置()
	var 宗门全局: Vector2 = 世界.域内坐标转全局(str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]))
	var 宗门框: Dictionary = 世界.区域逻辑范围.get(str(宗门位置["区域"]), {})
	var 在框: bool = 宗门全局.x >= float(宗门框.get("x1", -99999.0)) and 宗门全局.x <= float(宗门框.get("x2", 99999.0)) \
		and 宗门全局.y >= float(宗门框.get("y1", -99999.0)) and 宗门全局.y <= float(宗门框.get("y2", 99999.0))
	_log(">>> [附·抬升] 宗门域=%s 域内=(%.0f,%.0f) → 全局=(%.0f,%.0f) 落在本域框内=%s" % [
		str(宗门位置["区域"]), float(宗门位置["x"]), float(宗门位置["y"]), 宗门全局.x, 宗门全局.y, str(在框)])
	_log(">>> [附] 地图页节点总数=%d" % _数节点(_page))
	_log(">>>SEAMAP_LIVE_DONE")
