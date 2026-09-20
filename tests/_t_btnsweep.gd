extends Node

## 实机 UI 体检探针（**真实渲染**，勿加 --headless）
##
## 一次跑完三件事：
##  ① 按钮跳转：递归收集每页（首页 / 5 Tab / 全部二级页 / 特殊页，并下钻最多 2 层）所有 Button，
##     逐个 `pressed.emit()`；判定 NAV(跳转) / POPUP(弹窗) / NOOP(点了没反应) / SKIP(危险黑名单)。
##     每次点击前 print `>>>BTNCLICK|<页>|<序号>|<文本>|<名>`，供外部把 SCRIPT ERROR 归因到按钮。
##  ② 图标白底：对 TextureRect / Button.icon / TextureButton.texture_normal 取 Image，
##     统计外圈近白不透明像素比例 → 白底残留；并记录「小图拉大 / 大图缩极」异常。
##  ③ 符号图标：扫 Label / RichTextLabel / Button.text，找纯符号（★◆●▲→✔ 等，含 emoji 区间）当图标处。
##
## 用法：<godot> --path <proj> --scene res://tests/_t_btnsweep.tscn
## 产物：.workbuddy/_btnsweep.log（**权威，Godot 直写 UTF-8**）+ .workbuddy/accept_shots_btn/*.png
## 注意：**别用 PowerShell `*>` 抓 stdout 当结论** —— PS 5.1 按 GBK 解码原生进程输出，
##       中文/emoji 会变成「瀹炴満」式乱码且部分字符永久丢失。stdout 只用来判 EXIT，结论一律读 _btnsweep.log。

const OUT_DIR := "res://.workbuddy/accept_shots_btn/"
const LOG_PATH := "E:/Xiuxian/taixuanzongmenlu/.workbuddy/_btnsweep.log"
const SHOT_SCALE := 0.5
const TABS: Array = ["宗门", "弟子", "殿阁", "历练", "纪事"]
const MAX_CLICKS := 1600
const MAX_DEPTH := 2
const ICON_MAX := 512          # 超过此边长的纹理不逐像素分析（避免图集）
const WHITE_LINE := 0.35       # 外圈近白占比阈值（仅作嫌疑标记，非定罪）

# 不点的按钮：破坏数据 / 进战斗长流程
const SKIP_KEYS: Array = [
	"删除", "删档", "删号", "重置", "清空", "清除", "销毁", "解散", "灭门", "踢出", "逐出", "注销",
	"退出游戏", "退出登录", "卸载", "恢复初始", "弃档", "退宗",
	"出征", "讨伐", "攻打", "围攻", "进入战斗", "开战", "追杀", "斗法", "挑战",
]

var _ui: Node = null
var _buf: Array = []
var _clicks := 0
var _nav_rows: Array = []
var _noop_rows: Array = []
var _popup_rows: Array = []
var _skip_rows: Array = []
var _icon_rows: Array = []
var _sym_rows: Array = []
var _done_keys: Dictionary = {}
var _shot_n := 0


func _ready() -> void:
	prints("=== 实机 UI 体检探针启动 ===")
	_mkdir()
	var t := Timer.new()
	t.wait_time = 900.0
	t.one_shot = true
	t.timeout.connect(func() -> void:
		prints(">>>BTNSWEEP_TIMEOUT")
		_flush("TIMEOUT")
		get_tree().quit())
	add_child(t)
	t.start()

	if Game == null:
		_flush("NO_GAME")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		_flush("NO_MAIN")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	await _settle(6)
	main._登录_进入({"id": "acc_full"})
	await _settle(16)
	_ui = main.get("新UI")
	if _ui == null:
		_flush("NO_UI")
		get_tree().quit()
		return
	prints(">>> 进入游戏 弟子=", Game.弟子列表.size())

	# ① 首页
	await _sweep("HOME", _ui.get("_页_宗门"), 0)

	# ② 底部 5 Tab
	for tab in TABS:
		if _clicks >= MAX_CLICKS:
			break
		_ui._show_page(str(tab))
		await _settle(12)
		await _sweep("TAB_" + str(tab), _ui.get("_current"), 0)

	# ③ 全部二级页
	var subs: Dictionary = _ui.ENTRY_SUB_PAGES
	var ids: Array = subs.keys()
	ids.sort()
	for id in ids:
		if _clicks >= MAX_CLICKS:
			break
		_ui._show_sub_page(str(id), subs[id])
		await _settle(11)
		var cur_sub = _ui.get("_current_sub")
		if not is_instance_valid(cur_sub):
			cur_sub = null
		await _sweep("SUB_" + str(id), cur_sub, 0)
		if is_instance_valid(_ui.get("_current_sub")):
			_ui._close_sub_page()
		await _settle(4)

	# ④ 特殊页（非 ENTRY_SUB_PAGES 键）
	var sps: Array = [
		["X01_天下", "_open_world_map_page"],
		["X02_心弦", "_open_chat_page"],
		["X03_传讯中心", "_open_message_center"],
		["X04_宗主详情", "_open_master_detail"],
		["X05_玩家交易", "_open_player_trade_page"],
		["X06_离线管理", "_open_offline_manager_page"],
	]
	for sp in sps:
		if _clicks >= MAX_CLICKS:
			break
		if _ui.has_method(str(sp[1])):
			_ui.call(str(sp[1]))
			await _settle(14)
			var sp_sub = _ui.get("_current_sub")
			if not is_instance_valid(sp_sub):
				sp_sub = null
			await _sweep("SP_" + str(sp[0]), sp_sub, 0)
			if is_instance_valid(_ui.get("_current_sub")):
				_ui._close_sub_page()
			await _settle(4)

	_flush("DONE")
	prints(">>>BTNSWEEP_ALL_DONE clicks=", _clicks)
	get_tree().quit()


# ══════════════ 页面遍历 ══════════════

func _sweep(label: String, root: Node, depth: int) -> void:
	if root == null or not is_instance_valid(root):
		_buf.append(">>>PAGE_NULL " + label)
		return
	_buf.append(">>>PAGE %s depth=%d" % [label, depth])
	_scan_icons(root, label)
	_scan_symbols(root, label)
	await _shoot(label)
	_scan_page_stats(root, label)
	var btns: Array = _collect_buttons(root)
	_buf.append(">>>PAGE_BTNS %s n=%d" % [label, btns.size()])
	var base_tab: String = str(_ui.get("_last_tab_page"))
	for b in btns:
		if _clicks >= MAX_CLICKS:
			break
		if not is_instance_valid(b):
			continue
		var btn := b as Button
		if btn == null or not is_instance_valid(btn):
			continue
		var txt: String = btn.text.strip_edges()
		var nm: String = str(btn.name)
		var key: String = label + "|" + txt + "|" + nm
		if _done_keys.has(key):
			continue
		_done_keys[key] = true
		var skip := false
		for k in SKIP_KEYS:
			if txt.find(str(k)) >= 0:
				skip = true
				break
		if skip:
			_skip_rows.append("%s | %s | %s" % [label, txt, nm])
			_buf.append(">>>BTN_SKIP %s | %s | %s" % [label, txt, nm])
			continue
		await _click(btn, label, txt, nm, base_tab, depth)


func _click(btn: Button, label: String, txt: String, nm: String, base_tab: String, depth: int) -> void:
	_clicks += 1
	var dsc: String = _desc(txt, nm, btn)
	prints(">>>BTNCLICK|%s|%d|%s|%s" % [label, _clicks, txt, nm])
	var before_sub = _ui.get("_current_sub")
	if not is_instance_valid(before_sub):
		before_sub = null
	var before_tab: String = str(_ui.get("_last_tab_page"))
	btn.pressed.emit()
	await _settle(8)
	var after_sub = _ui.get("_current_sub")
	if not is_instance_valid(after_sub):
		after_sub = null
	var after_tab: String = str(_ui.get("_last_tab_page"))
	var win_n: int = _count_windows()

	if after_sub != before_sub and after_sub != null:
		var nm2: String = str((after_sub as Node).name)
		_nav_rows.append("%s | %s | →SUB:%s" % [label, dsc, nm2])
		prints(">>>BTN_NAV %s | %s | →SUB:%s" % [label, dsc, nm2])
		if depth < MAX_DEPTH:
			await _sweep(label + ">" + nm2, after_sub, depth + 1)
	elif after_tab != before_tab:
		_nav_rows.append("%s | %s | →TAB:%s" % [label, dsc, after_tab])
		prints(">>>BTN_NAV %s | %s | →TAB:%s" % [label, dsc, after_tab])
	elif win_n > 0:
		_popup_rows.append("%s | %s | windows=%d" % [label, dsc, win_n])
		_buf.append(">>>BTN_POPUP %s | %s | windows=%d" % [label, dsc, win_n])
	else:
		# 可能是「瞬时动作按钮」（改了数据但无视觉反馈），也可能是空转；先记为 NOOP 待人工复核
		_noop_rows.append("%s | %s" % [label, dsc])
		_buf.append(">>>BTN_NOOP %s | %s" % [label, dsc])

	# 统一恢复现场
	var cs = _ui.get("_current_sub")
	if is_instance_valid(cs):
		_ui._close_sub_page()
		await _settle(4)
	_hide_windows()
	if str(_ui.get("_last_tab_page")) != base_tab:
		_ui._show_page(base_tab)
		await _settle(8)


# ══════════════ 图标体检 ══════════════

func _scan_icons(root: Node, label: String) -> void:
	_walk_icon(root, label, 0)


func _walk_icon(n: Node, label: String, d: int) -> void:
	if d > 18:
		return
	var tex: Texture2D = null
	var ctx: String = ""
	if n is TextureRect and (n as TextureRect).is_visible_in_tree():
		tex = (n as TextureRect).texture
		ctx = "TextureRect"
	elif n is TextureButton and (n as TextureButton).is_visible_in_tree():
		tex = (n as TextureButton).texture_normal
		ctx = "TextureButton"
	elif n is Button and (n as Button).is_visible_in_tree():
		tex = (n as Button).icon
		ctx = "Button.icon"
	if tex != null:
		_analyze(tex, label, ctx, n)
	for c in n.get_children():
		_walk_icon(c, label, d + 1)


var _tex_seen: Dictionary = {}

func _analyze(tex: Texture2D, label: String, ctx: String, node: Node) -> void:
	# 同一纹理只分析一次（图标在多页复用；也避免巨量重复日志）
	var key: String = str(tex.resource_path)
	if key == "":
		key = "id:%d" % tex.get_instance_id()
	if tex is AtlasTexture:
		key += "#r" + str((tex as AtlasTexture).region)
	if _tex_seen.has(key):
		return
	_tex_seen[key] = true
	var img: Image = null
	var iw := 0
	var ih := 0
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		var base: Texture2D = at.atlas
		if base == null:
			return
		var r: Rect2 = at.region
		if r.size.x > float(ICON_MAX) or r.size.y > float(ICON_MAX):
			return
		var bi: Image = base.get_image()
		if bi == null:
			return
		img = bi.get_region(Rect2i(int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)))
	else:
		var sz: Vector2 = tex.get_size()
		if sz.x > float(ICON_MAX) or sz.y > float(ICON_MAX):
			_check_scale_mismatch(sz, node, label, ctx)
			return
		img = tex.get_image()
	if img == null:
		_icon_rows.append("%s | %s | %s | 取不到 Image" % [label, ctx, str(node.name)])
		return
	if img.is_empty():
		return
	img = img.duplicate()
	if img.is_compressed():
		# 项目图标多为 VRAM 压缩 .ctex，get_pixel 前必须先解压
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	iw = img.get_width()
	ih = img.get_height()
	if iw < 4 or ih < 4:
		return
	# 外圈 2px
	var white := 0
	var opaque := 0
	var near_black := 0
	var steps_x: Array = [0, 1, iw - 2, iw - 1]
	var steps_y: Array = [0, 1, ih - 2, ih - 1]
	for x in range(iw):
		for yy in steps_y:
			var c: Color = img.get_pixel(x, yy)
			if c.a > 0.5:
				opaque += 1
				if c.r > 0.9 and c.g > 0.9 and c.b > 0.9:
					white += 1
				if c.r < 0.08 and c.g < 0.08 and c.b < 0.08:
					near_black += 1
	for y in range(ih):
		for xx in steps_x:
			var c2: Color = img.get_pixel(xx, y)
			if c2.a > 0.5:
				opaque += 1
				if c2.r > 0.9 and c2.g > 0.9 and c2.b > 0.9:
					white += 1
				if c2.r < 0.08 and c2.g < 0.08 and c2.b < 0.08:
					near_black += 1
	# 全图白占比（占位图检测）
	var all_white := 0
	var all_opaque := 0
	var stride: int = max(1, int(round(float(iw) / 48.0)))
	for x2 in range(0, iw, stride):
		for y2 in range(0, ih, stride):
			var c3: Color = img.get_pixel(x2, y2)
			if c3.a > 0.5:
				all_opaque += 1
				if c3.r > 0.9 and c3.g > 0.9 and c3.b > 0.9:
					all_white += 1
	var ratio := 0.0
	if opaque > 0:
		ratio = float(white) / float(opaque)
	var all_ratio := 0.0
	if all_opaque > 0:
		all_ratio = float(all_white) / float(all_opaque)
	var display := ""
	if node is Control:
		display = str((node as Control).size)
	if ratio >= WHITE_LINE:
		_icon_rows.append("%s | %s | %s | 显示%s | 纹理%dx%d | 外圈近白%.0f%%(%d/%d) | 全图白%.0f%%" % [
			label, ctx, str(node.name), display, iw, ih, ratio * 100.0, white, opaque, all_ratio * 100.0])
		prints(">>>ICON_WHITE %s | %s | %s | %.0f%%" % [label, ctx, str(node.name), ratio * 100.0])
	elif all_ratio > 0.85:
		_icon_rows.append("%s | %s | %s | 显示%s | 纹理%dx%d | 疑似全白占位图 | 全图白%.0f%%" % [
			label, ctx, str(node.name), display, iw, ih, all_ratio * 100.0])
		prints(">>>ICON_ALLWHITE %s | %s | %s" % [label, ctx, str(node.name)])
	elif node is TextureRect and opaque == 0:
		_icon_rows.append("%s | %s | %s | 纹理 %dx%d 外圈全透明(可接受)" % [label, ctx, str(node.name), iw, ih])


func _check_scale_mismatch(tsz: Vector2, node: Node, label: String, ctx: String) -> void:
	if not (node is Control):
		return
	var dsz: Vector2 = (node as Control).size
	if dsz.x <= 4.0 or dsz.y <= 4.0:
		return
	if tsz.x > 900.0 and dsz.x < 120.0:
		_icon_rows.append("%s | %s | %s | 显示%s 但纹理 %s（大图缩到极小）" % [
			label, ctx, str(node.name), str(dsz), str(tsz)])
		prints(">>>ICON_BIGSMALL %s | %s | %s" % [label, ctx, str(node.name)])
	elif tsz.x < 40.0 and dsz.x > 128.0:
		_icon_rows.append("%s | %s | %s | 显示%s 但纹理 %s（小图拉大，疑糊/错图）" % [
			label, ctx, str(node.name), str(dsz), str(tsz)])
		prints(">>>ICON_SMALLBIG %s | %s | %s" % [label, ctx, str(node.name)])


# ══════════════ 符号 / emoji 图标 ══════════════

func _scan_symbols(root: Node, label: String) -> void:
	_walk_sym(root, label, 0)


func _walk_sym(n: Node, label: String, d: int) -> void:
	if d > 18:
		return
	if (n is Label or n is RichTextLabel or n is Button) and (n as Control).is_visible_in_tree():
		var t := ""
		if n is Button:
			t = (n as Button).text
		elif n is Label:
			t = (n as Label).text
		else:
			t = (n as RichTextLabel).text
		t = t.strip_edges()
		if _is_all_symbol(t):
			var kind := "Label"
			if n is Button:
				kind = "Button"
			elif n is RichTextLabel:
				kind = "RichText"
			_sym_rows.append("%s | %s | %s | '%s'(%s)" % [label, kind, str(n.name), t, _codes(t)])
			prints(">>>SYM %s | %s | %s | %s" % [label, kind, str(n.name), t])
	for c in n.get_children():
		_walk_sym(c, label, d + 1)


func _is_all_symbol(t: String) -> bool:
	if t == "" or t.length() > 6:
		return false
	# 排除刻意保留的提示标记
	if t == "ⓘ" or t == "?" or t == "？" or t == "!" or t == "！":
		return false
	var total := 0
	var sym := 0
	for i in t.length():
		var c: int = t.unicode_at(i)
		if c == 0xFE0F or c == 0x20 or c == 0x200B:
			continue
		total += 1
		if _is_sym_code(c):
			sym += 1
	return total > 0 and sym == total


func _is_sym_code(c: int) -> bool:
	if c < 0x2000:
		return false
	if c >= 0x1F000 and c <= 0x1FAFF:
		return true          # emoji
	if c >= 0x2190 and c <= 0x21FF:
		return true          # 箭头
	if c >= 0x2300 and c <= 0x23FF:
		return true          # 技术符号 ⌚⏳
	if c >= 0x2460 and c <= 0x24FF:
		return true          # 带圈数字
	if c >= 0x25A0 and c <= 0x25FF:
		return true          # 几何图形 ■▲►●
	if c >= 0x2600 and c <= 0x27BF:
		return true          # 杂项符号 ★☆♥◆✔◆
	if c >= 0x2B00 and c <= 0x2BFF:
		return true
	if c >= 0x1F000 and c <= 0x1FFFF:
		return true
	return false


func _codes(t: String) -> String:
	var s := ""
	for i in t.length():
		s += "U+%04X " % t.unicode_at(i)
	return s.strip_edges()


# ══════════════ 页面统计（复用布局三条断言）══════════════

func _scan_page_stats(root: Node, label: String) -> void:
	var st: Dictionary = {"vis": 0, "badscroll": 0, "collapse": 0, "offscreen": 0}
	_walk_stats(root, st, 0)
	if int(st["vis"]) < 3:
		_buf.append(">>>PAGE_SPARSE %s vis=%d" % [label, int(st["vis"])])
	_buf.append(">>>ISSUE_BLANK %s 可见元素=%d" % [label, int(st["vis"])])
	if int(st["badscroll"]) > 0:
		_buf.append(">>>ISSUE_BADSCROLL %s n=%d" % [label, int(st["badscroll"])])
	if int(st["offscreen"]) > 0:
		_buf.append(">>>ISSUE_OFFSCREEN %s n=%d" % [label, int(st["offscreen"])])


func _walk_stats(n: Node, st: Dictionary, d: int) -> void:
	if d > 16:
		return
	var vis := false
	if n is Control:
		vis = (n as Control).is_visible_in_tree()
		if vis:
			st["vis"] = int(st["vis"]) + 1
	if n is ScrollContainer and vis:
		var sc := n as ScrollContainer
		if sc.size.x < 60.0 or sc.size.y < 60.0:
			st["badscroll"] = int(st["badscroll"]) + 1
	if n is Control and vis and not (n is ScrollContainer):
		var ov := n as Control
		if ov.size.x > 4.0 and ov.size.y > 4.0 and ov.get_viewport() == get_viewport():
			var gr: Rect2 = ov.get_global_rect()
			var vr: Rect2 = get_viewport().get_visible_rect()
			var a: Node = ov.get_parent()
			var in_scroll := false
			while a != null:
				if a is ScrollContainer:
					in_scroll = true
					break
				a = a.get_parent()
			if not in_scroll and (gr.position.y >= vr.size.y or gr.end.y <= 0.0):
				st["offscreen"] = int(st["offscreen"]) + 1
	for c in n.get_children():
		_walk_stats(c, st, d + 1)


# ══════════════ 工具 ══════════════

func _collect_buttons(root: Node) -> Array:
	var out: Array = []
	_walk_btn(root, out, 0)
	return out


func _walk_btn(n: Node, out: Array, d: int) -> void:
	if d > 18:
		return
	if n is Button and not (n is PopupMenu) and (n as Button).is_visible_in_tree():
		out.append(n)
	for c in n.get_children():
		_walk_btn(c, out, d + 1)


func _desc(txt: String, nm: String, btn: Button) -> String:
	if txt != "":
		return txt
	var ic := ""
	if btn.icon != null:
		ic = "icon:" + str(btn.icon.get_size())
	return "[" + nm + ("" if ic == "" else " " + ic) + "]"


func _count_windows() -> int:
	var n := 0
	var stack: Array = [get_tree().root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		if cur is Window and cur != get_tree().root and (cur as Window).visible:
			n += 1
		for c in cur.get_children():
			stack.append(c)
	return n


func _hide_windows() -> void:
	var stack: Array = [get_tree().root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		if cur is Window and cur != get_tree().root and (cur as Window).visible:
			(cur as Window).hide()
		for c in cur.get_children():
			stack.append(c)


func _mkdir() -> void:
	var abs := ProjectSettings.globalize_path(OUT_DIR)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _settle(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var vp := get_viewport()
	if vp == null or vp.get_texture() == null:
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		return
	if SHOT_SCALE != 1.0:
		img.resize(int(img.get_width() * SHOT_SCALE), int(img.get_height() * SHOT_SCALE),
			Image.INTERPOLATE_LANCZOS)
	_shot_n += 1
	var fn: String = "%03d_%s.png" % [_shot_n, _safe(label)]
	var err: int = img.save_png(OUT_DIR + fn)
	_buf.append(">>>SHOT %s err=%d" % [fn, err])


func _safe(s: String) -> String:
	var out := ""
	for i in s.length():
		var c: String = s[i]
		if (c >= "0" and c <= "9") or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c == "-":
			out += c
		else:
			out += "_"
	return out


func _flush(tag: String) -> void:
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		printerr(">>>LOG 打不开 ", LOG_PATH)
		return
	f.store_line("=== 实机 UI 体检 tag=%s clicks=%d ===" % [tag, _clicks])
	f.store_line(">>>SUMMARY nav=%d noop=%d popup=%d skip=%d icon=%d sym=%d" % [
		_nav_rows.size(), _noop_rows.size(), _popup_rows.size(),
		_skip_rows.size(), _icon_rows.size(), _sym_rows.size()])
	f.store_line("")
	f.store_line("### ① 按钮跳转（NAV）")
	for r in _nav_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### ①b 点了没反应（NOOP，需人工判定「瞬时动作」还是「空转」）")
	for r in _noop_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### ①c 弹窗类（POPUP）")
	for r in _popup_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### ①d 跳过（危险/战斗黑名单）")
	for r in _skip_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### ② 图标嫌疑（白底 / 占位 / 尺寸异常）")
	for r in _icon_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### ④ 符号/emoji 当图标")
	for r in _sym_rows:
		f.store_line("  " + str(r))
	f.store_line("")
	f.store_line("### 逐页明细")
	for r in _buf:
		f.store_line("  " + str(r))
	f.close()
