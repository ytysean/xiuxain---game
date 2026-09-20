extends Node

## PH7 逐页视觉精修 · 通用单页真实渲染探针（一次编写 · 多页复用）。
## 与 _probe_bp_shot.gd / _probe_pill_shot.gd 同口径，唯一区别：页面路由键与输出名走环境变量。
## 用法：
##   PH7_PAGE_KEY=<ENTRY_SUB_PAGES 键> PH7_SHOT_NAME=<输出png名> \
##     <managed python> .workbuddy/_run_shot.py res://tests/_probe_page_shot.tscn <日志名>
## 输出：accept_shots_full/<SHOT_NAME> ＋ 全 Control 节点几何/字号/字色 → 日志（机器可检，禁肉眼读截图）。

const OUT_DIR := "res://accept_shots_full/"

var _key: String = ""
var _labels: Array = []


func _ready() -> void:
	_key = OS.get_environment("PH7_PAGE_KEY").strip_edges()
	if _key == "":
		printerr(">>>FAIL PH7_PAGE_KEY 未设置")
		get_tree().quit()
		return
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	prints("=== PH7 通用单页探针 key=", _key, " ===")
	_ensure_dir()
	if Game == null:
		printerr(">>>FAIL Game 单例缺失")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr(">>>FAIL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": "acc_full"})
	await _settle(14)
# ★ PH7-13：可选播种——默认存档无家族，家族页只会出空态，表格/排行/成员全不可验收。
	if OS.get_environment("PH7_SEED_FAMILY") == "1":
		_播种家族()
	if OS.get_environment("PH7_SEED_TREASURE") == "1":
		_播种本命法宝()
	var _ui: Node = main.get("新UI")
	if _ui == null:
		printerr(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	prints(">>> 进入游戏 · 弟子=", Game.弟子列表.size(), " 灵石=", Game.灵石)
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var scene: PackedScene = subs.get(_key, null) as PackedScene
	if scene == null:
		printerr(">>>FAIL 路由键不存在：", _key)
		get_tree().quit()
		return
	_ui._show_sub_page(_key, scene)
	await _settle(12)
	var cur: Node = _ui.get("_current_sub")
	if cur == null:
		printerr(">>>FAIL _current_sub=null")
		get_tree().quit()
		return
	# ★ PH7-13：可选切标签（多标签页逐页取证）。页面须有 _切换标签(名)。
	var _tab: String = OS.get_environment("PH7_SEED_TAB").strip_edges()
	if _tab != "" and cur.has_method("_切换标签"):
		cur.call("_切换标签", _tab)
		await _settle(8)
	prints(">>>PAGE ", _key, " cur=", cur.name, " class=", cur.get_class(),
		" size=", cur.size, " global_rect=", cur.get_global_rect())
	_scan(cur)
	prints(">>>NODES_BEGIN n=", _labels.size())
	for e in _labels:
		prints(">>>  N ", e)
	prints(">>>NODES_END")
	var name_out: String = OS.get_environment("PH7_SHOT_NAME").strip_edges()
	if name_out == "":
		name_out = _key + ".png"
	await _shot(name_out)
	prints(">>>SHOT_DONE name=", name_out)
	get_tree().quit()


func _播种家族() -> void:
	# ★ PH7-13：验收前提——把存档摆到「正常态」。不走 创建家族（内含 randi 家族ID 与随机血脉功法名，
	#   不可复现），改为直接注入确定性样本；同时注入 3 个确定性 NPC 家族供排行榜使用。
	var ds: Array = Game.弟子列表
	if ds.size() < 4:
		printerr(">>>SEED FAIL 弟子不足 n=", ds.size())
		return
	var fid: String = "family_probe_1"
	var 成员: Array = []
	var 职位表: Array = ["老祖", "长老", "核心", "外门"]
	for i in range(4):
		var d: Object = ds[i]
		d.家族ID = fid
		d.家族名 = "太玄李氏"
		d.家族职位 = 职位表[i]
		成员.append(d.弟子ID)
	ds[0].血脉功法列表.append("family_xuemai_%s" % fid)
	var 列表: Dictionary = Game.家族系统.家族列表
	列表[fid] = {
		"id": fid, "ID": fid, "名": "太玄李氏", "老祖ID": ds[0].弟子ID, "老祖名": ds[0].姓名,
		"创立时间": 120, "等级": 3, "成员列表": 成员, "长老列表": [成员[1]],
		"家族功法": [
			{"名": "青元剑诀", "描述": "李氏旁支剑术，攻伐锐利"},
			{"名": "玄水养气篇", "描述": "以水养气，稳固根基"},
		],
		"血脉功法": {"名": "李氏太玄血脉诀", "ID": "family_xuemai_%s" % fid,
			"描述": "太玄李氏家传血脉功法，世代传承", "创立时间": 120},
		"家族阵法": "", "家族秘宝": ["zhenbao_001", "zhenbao_003"],
		"家族宝库": {"lingcao": 12, "kuangshi": 5},
		"家族贡献池": 860, "家族声望": 320, "家族气运": 0.02,
		"联盟家族": ["npc_family_1"], "敌对家族": [], "联姻家族": ["npc_family_2"],
		"描述": "太玄李氏，以剑术立族", "是NPC": false
	}
	var 外族名: Array = ["慕容世家", "上官家族", "欧阳世家"]
	for i in range(3):
		var nid: String = "npc_family_%d" % (i + 1)
		列表[nid] = {
			"id": nid, "ID": nid, "名": 外族名[i], "等级": 2 + i, "成员列表": [],
			"家族声望": 100 * (i + 1), "贡献池": 200 * (i + 1),
			"家族宝库": {}, "家族秘宝": [], "血脉功法": "", "家族阵法": "",
			"联盟家族": [], "联姻家族": [], "敌对家族": [],
			"事件记录": [], "是NPC": true, "创立时间": 60
		}
	prints(">>>SEED 家族注入完成 · 家族数=", 列表.size(), " 我方成员=", 成员.size())


func _播种本命法宝() -> void:
	# ★ PH7-14：验收前提——把存档摆到「正常态」。默认存档无弟子祭炼本命法宝，
	#   总览页「已立本命法宝」列表恒空态、列表行样式不可验收。
	#   直接给首名弟子注入确定性本命法宝样本（inn_001 = 宝品下品本命剑）。
	var ds: Array = Game.弟子列表
	if ds.is_empty():
		printerr(">>>SEED FAIL 弟子列表空")
		return
	var d: Object = ds[0]
	d.本命法宝ID = "inn_001"
	d.本命法宝祭炼等级 = 3
	prints(">>>SEED 本命法宝注入 · 弟子=", d.姓名, " 法宝=inn_001 等级=3")


func _scan(root: Node) -> void:
	# ★ 机器可检：全 Control 节点几何 + 字号 + 字色（禁肉眼读截图判几何/颜色）。
	_walk(root, 0)
	# 顶栏 / 标签栏子节点单列（判定标题与返回钮是否重叠、页签是否均分）。
	var 顶栏 := root.get_node_or_null("TopBar")
	if 顶栏 != null:
		_dump_children(顶栏, "TopBar")
	var 标签栏 := _find_tab_bar(root)
	if 标签栏 != null:
		_dump_children(标签栏, "TabBar")

func _find_tab_bar(root: Node) -> Node:
	var stack: Array = [root]
	while not stack.is_empty() and stack.size() < 200:
		var n: Node = stack.pop_back()
		if n is HBoxContainer and _has_button(n):
			return n
		for c in n.get_children():
			stack.append(c)
	return null

func _has_button(n: Node) -> bool:
	for c in n.get_children():
		if c is Button:
			return true
	return false


func _dump_children(n: Node, tag: String) -> void:
	for c in n.get_children():
		var r: Rect2 = (c as Control).get_global_rect()
		_labels.append("%s/%s cls=%s g=%s size=%s" % [tag, c.name, c.get_class(),
			str(r.position), str(r.size)])
		for g in c.get_children():
			var rg: Rect2 = (g as Control).get_global_rect()
			_labels.append("%s/%s>%s cls=%s g=%s size=%s" % [tag, c.name, g.name, g.get_class(),
				str(rg.position), str(rg.size)])


func _walk(n: Node, d: int) -> void:
	if d > 12 or _labels.size() > 500:
		return
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect()
			var extra := ""
			if c is Label:
				var lb := c as Label
				extra = " fs=%s fc=%s '%s'" % [str(lb.get_theme_font_size("font_size")),
					str(lb.get_theme_color("font_color")), lb.text.strip_edges().substr(0, 26)]
			elif c is Button:
				var bt := c as Button
				extra = " fs=%s '%s'" % [str(bt.get_theme_font_size("font_size")),
					bt.text.strip_edges().substr(0, 26)]
			_labels.append("d%d %s cls=%s g=%s size=%s%s" % [d, c.name, c.get_class(),
				str(r.position), str(r.size), extra])
	for ch in n.get_children():
		_walk(ch, d + 1)


func _settle(n: int) -> void:
	var t0: int = Time.get_ticks_msec()
	for i in n:
		await get_tree().process_frame
	var 余: int = 260 - (Time.get_ticks_msec() - t0)
	if 余 > 0:
		await get_tree().create_timer(float(余) / 1000.0).timeout
	await RenderingServer.frame_post_draw


func _ensure_dir() -> void:
	var abs := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null or vp.get_texture() == null:
		printerr(">>>SHOT FAIL 无 viewport/texture")
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		printerr(">>>SHOT FAIL 无 image")
		return
	var err: int = img.save_png(OUT_DIR + name)
	prints(">>>SHOT", name, "err=", err, "size=", str(img.get_size()))
