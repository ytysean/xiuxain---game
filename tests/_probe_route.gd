extends Node
## 路由全链路真实点击探针（真实渲染 · 窗口移出屏幕，不弹窗干扰）。
## 用法：<godot> --path . res://tests/_probe_route.tscn
##
## 目的：老大反馈「点个返回都是弹出储物袋」「我点天下，返回的时候变成储物袋」
##       「宗门名字点不动」「返回也点不动」——一句话：路由乱套。
##       静态读 `game_ui.gd` 的 _show_sub_page/_close_sub_page 看着是自洽的，
##       故必须用**真实渲染 + 真实鼠标事件**把每一步的层级打出来，拿铁证定位。
##
## 探针输出四大块：
##   ① 首页可见按钮清单（文本 + 全局矩形）—— 查「看到的」与「点到的」是否错位
##   ② 点「天下」→ 二级页容器里的实际内容
##   ③ 点大地图的关闭钮 → 回到哪一层
##   ④ 点顶栏「宗门名字」→ 是否触发宗主详情

const 探针账号 := "__probe_route__"

var _main: Node = null
var _ui: Node = null


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	_main._登录_进入({"id": 探针账号})
	await _settle(24)

	_ui = _main.get("新UI")
	if _ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	await _dump_首页按钮()

	# ── ② 点「天下」 ──────────────────────────────
	prints("\n========== ② 真实点击「天下」入口 ==========")
	var 天下钮: Button = _找按钮(["Entry_天下"])
	if 天下钮 == null:
		prints(">>>FAIL 找不到「天下」入口按钮")
	else:
		var c: Vector2 = 天下钮.global_position + 天下钮.size * 0.5
		prints("「天下」钮 rect=%s 中心=%s 命中=%s" % [
			str(Rect2(天下钮.global_position, 天下钮.size)), str(c),
			_命中名(c)])
		_点击(c)
		await _settle(14)
		await _dump_二级页("点天下之后")
		await _shot("_probe_route_1_world.png")

	# ── ③ 点关闭/返回 ─────────────────────────────
	prints("\n========== ③ 真实点击大地图关闭钮 ==========")
	var 关钮: Button = _找按钮(["✕", "×", "返回", "←"])
	if 关钮 == null:
		prints("→ 二级页内找不到关闭/返回按钮，列出二级页全部 Button：")
		_列出按钮(_ui.get("_sub_page_container"))
	else:
		var c2: Vector2 = 关钮.global_position + 关钮.size * 0.5
		prints("关闭钮 text=%s rect=%s 中心=%s 命中=%s" % [
			关钮.text, str(Rect2(关钮.global_position, 关钮.size)), str(c2), _命中名(c2)])
		_点击(c2)
		await _settle(14)
		await _dump_二级页("点返回之后")
		await _shot("_probe_route_2_back.png")

	# ── ④ 点顶栏宗门名字 ───────────────────────────
	prints("\n========== ④ 真实点击顶栏「宗门名字」 ==========")
	var top: Node = _ui.get("_top_bar")
	prints("顶栏 visible=%s" % (str(top.visible) if top != null else "-"))
	if top != null:
		var 名热区: Node = top.find_child("NameHit", true, false)
		prints("NameHit 节点 = %s" % str(名热区))
		if 名热区 is Control:
			var nc: Control = 名热区
			var c3: Vector2 = nc.global_position + nc.size * 0.5
			prints("NameHit visible=%s rect=%s filter=%d 命中=%s" % [
				str(nc.visible), str(Rect2(nc.global_position, nc.size)),
				int(nc.mouse_filter), _命中名(c3)])
			_点击(c3)
			await _settle(14)
			await _dump_二级页("点宗门名字之后")
			await _shot("_probe_route_3_name.png")

	# ── ⑤ 底部 Tab 逐个点 ─────────────────────────
	prints("\n========== ⑤ 底部 Tab 逐个真实点击 ==========")
	var bot: Node = _ui.get("_bottom_bar")
	if bot != null:
		_列出按钮(bot)
		var 按钮们: Array = []
		_收集按钮(bot, 按钮们)
		for b in 按钮们:
			var bb: Button = b
			var c4: Vector2 = bb.global_position + bb.size * 0.5
			_点击(c4)
			await _settle(8)
			prints("  点底部 Tab name=%s text=「%s」 → _current=%s _current_sub=%s" % [
				str(bb.name), bb.text, _名(_ui.get("_current")), _名(_ui.get("_current_sub"))])

	get_tree().quit()


# ─────────────── 输出工具 ───────────────

func _dump_首页按钮() -> void:
	prints("\n========== ① 首页可见按钮清单 ==========")
	var 容器: Node = _ui.get("_page_container")
	_列出按钮(容器)


func _dump_二级页(标题: String) -> void:
	prints("---- %s · 层状态 ----" % 标题)
	prints("  _current        = %s" % _名(_ui.get("_current")))
	prints("  _current_sub    = %s" % _名(_ui.get("_current_sub")))
	prints("  _master_sub_open= %s" % str(_ui.get("_master_sub_open")))
	prints("  _舆图回跳        = %s" % str(_ui.get("_舆图回跳")))
	var top: Node = _ui.get("_top_bar")
	var bot: Node = _ui.get("_bottom_bar")
	prints("  顶栏 visible=%s / 底栏 visible=%s" % [
		str(top.visible) if top != null else "-", str(bot.visible) if bot != null else "-"])
	var c: Control = _ui.get("_current_sub")
	if c != null and is_instance_valid(c):
		prints("  二级页 script=%s child_count=%d" % [str(c.get_script()), c.get_child_count()])
		_列出按钮(c, "    ")
	else:
		prints("  （当前无二级页）")
	# 二级页缓存里的僵尸实例（诊断「串台」用）
	var cache: Dictionary = _ui.get("_sub_pages")
	prints("  _sub_pages 缓存 %d 项: %s" % [cache.size(), str(cache.keys())])


func _列出按钮(根: Node, 缩进: String = "  ") -> void:
	if 根 == null:
		prints("%s（空）" % 缩进)
		return
	var 结果: Array = []
	_收集按钮(根, 结果)
	prints("%s共 %d 个 Button：" % [缩进, 结果.size()])
	for b in 结果:
		var bb: Button = b
		var txt: String = bb.text.strip_edges()
		if txt.length() > 14:
			txt = txt.substr(0, 14) + "…"
		var r: Rect2 = Rect2(bb.global_position, bb.size)
		# 屏幕外/零尺寸是「点不动」的头号嫌疑
		var 标记: String = ""
		if not bb.visible:
			标记 = " [不可见]"
		if bb.size.x <= 1.0 or bb.size.y <= 1.0:
			标记 += " [零尺寸]"
		if r.position.y < -1.0 or r.position.x < -1.0:
			标记 += " [出屏]"
		if bb.disabled:
			标记 += " [禁用]"
		prints("%s  name=%s text=「%s」 %s%s" % [缩进, str(bb.name), txt, str(r), 标记])


func _收集按钮(n: Node, 出: Array) -> void:
	if n is Button:
		出.append(n)
	for c in n.get_children():
		_收集按钮(c, 出)


## 按「节点名 或 文本」匹配（本项目的入口钮是图标态、text 为空，只能靠 name）
func _找按钮(关键字组: Array) -> Button:
	var 结果: Array = []
	var sub: Control = _ui.get("_current_sub")
	var 当前层: Node = (_ui.get("_sub_page_container") if sub != null else _ui.get("_current"))
	_收集按钮(当前层, 结果)
	var 候选: Button = null
	for b in 结果:
		var bb: Button = b
		if not bb.visible or bb.size.x <= 1.0:
			continue
		var 名文: String = str(bb.name) + "|" + bb.text.strip_edges()
		for k in 关键字组:
			if 名文.contains(String(k)):
				if 候选 == null or bb.global_position.y < 候选.global_position.y:
					候选 = bb
	return 候选


func _名(n: Variant) -> String:
	if n == null:
		return "null"
	if n is Node:
		return "%s" % str((n as Node).name)
	return str(n)


func _命中名(点: Vector2) -> String:
	var r: Control = _鼠标命中(_ui, 点)
	if r == null:
		return "null"
	return "%s(%s)" % [str(r.name), r.get_class()]


func _鼠标命中(根: Node, 点: Vector2) -> Control:
	var 结果: Control = null
	for c in 根.get_children():
		var r: Control = _递归命中(c, 点)
		if r != null:
			结果 = r
	return 结果


func _递归命中(n: Node, 点: Vector2) -> Control:
	if n is Control:
		var c: Control = n
		if not c.visible or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return null
		var r: Rect2 = Rect2(c.global_position, c.size)
		if not r.has_point(点):
			return null
		for ch in c.get_children():
			var inner: Control = _递归命中(ch, 点)
			if inner != null:
				return inner
		return c
	return null


func _点击(点: Vector2) -> void:
	# ★ 踩坑记录（2026-09-15）：push_input(ev,false) 用 get_final_transform().affine_inverse()
	#   把事件当**窗口坐标**换算回画布。本工程 画布 1080×1920 / 窗口 720×1280 ⇒ 缩放 0.6667，
	#   直接传画布点会被再乘 1.5（曾据此误报「点天下打开坊市」）。故先映射成窗口点。
	var 窗口点: Vector2 = get_viewport().get_final_transform() * 点
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = 窗口点
	ev.global_position = 窗口点
	get_viewport().push_input(ev)
	var ev2 := InputEventMouseButton.new()
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.pressed = false
	ev2.position = 窗口点
	ev2.global_position = 窗口点
	get_viewport().push_input(ev2)


func _shot(名: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		prints(">>>FAIL 截图为空 %s" % 名)
		return
	var err: int = img.save_png("res://accept_shots_full/" + 名)
	prints(">>>SAVED %s err=%d" % [名, err])


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
