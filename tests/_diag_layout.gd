extends Node

## 布局实机诊断（headless）：dump 真实 Control 矩形。
## 回答「图标溢出按钮 / 标签错位 / 返回键不在最左」这类**只有真实布局才知道**的问题。
##
## 运行（autoload 会正常加载，UITheme / Game 均可用）：
##   godot --headless --path <proj> res://tests/_diag_layout.tscn
## 产物：res://.scratch_backup/layout_dump.txt

const OUT_PATH := "res://.scratch_backup/layout_dump.txt"

var _lines: PackedStringArray = PackedStringArray()


func _rec(n: Node, depth: int) -> void:
	if n is Control:
		var c := n as Control
		var r: Rect2 = c.get_global_rect()
		var pad := "  ".repeat(depth)
		var extra := ""
		if c is Label:
			extra = " text=\"%s\"" % (c as Label).text
		elif c is Button:
			extra = " text=\"%s\"" % (c as Button).text
		var min_s: Vector2 = c.get_combined_minimum_size()
		_lines.append("%s%-24s rect[%7.1f,%7.1f %7.1f x %7.1f] min[%.1f x %.1f] vis=%s%s"
			% [pad, c.name, r.position.x, r.position.y, r.size.x, r.size.y,
			   min_s.x, min_s.y, str(c.visible), extra])
	for ch in n.get_children():
		_rec(ch, depth + 1)


func _dump(node: Node, title: String) -> void:
	_lines.append("")
	_lines.append("=========== %s ===========" % title)
	_rec(node, 0)


func _ready() -> void:
	# 看门狗：异常时不挂死
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		_lines.append("!! 看门狗超时")
		_flush()
		get_tree().quit())

	# ★ headless 下 Godot 的虚拟屏是正方形（实测 1920×1920），而本项目是 1080×1920 竖屏。
	#   不强制设计视口，一切 viewport 相对的几何判断都会失真。
	if DisplayServer.get_name() == "headless":
		get_window().size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame
	_lines.append("显示后端 = %s" % DisplayServer.get_name())

	var vp: Vector2 = get_viewport().get_visible_rect().size
	_lines.append("视口 = %.0f x %.0f" % [vp.x, vp.y])

	# ---------- 1) 首页「更多」面板（全部组展开 = 最坏情况）----------
	var HomeScript: GDScript = load("res://ui/sect_home_page.gd")
	if HomeScript == null:
		_lines.append("!! 无法加载 sect_home_page.gd")
	else:
		var home: Control = HomeScript.new()
		get_tree().root.add_child(home)
		await get_tree().process_frame
		await get_tree().process_frame
		# MorePanel 是懒构建的：面板宿主名为 MoreBG，其子节点 MorePanel。
		# 若尚未构建，直接调用私有构建入口（诊断脚本允许触碰）。
		var more_bg: Node = home.find_child("MoreBG", true, false)
		if more_bg == null and home.has_method("_build_more_panel"):
			home.call("_build_more_panel")
			await get_tree().process_frame
			more_bg = home.find_child("MoreBG", true, false)
		var more: Node = home.find_child("MorePanel", true, false)
		if more_bg == null:
			_lines.append("!! 未找到 MoreBG（更多面板未构建）")
		elif more == null:
			_lines.append("!! 找到 MoreBG 但无 MorePanel")
		else:
			(more_bg as Control).visible = true
			(more as Control).visible = true
			var heads: Array = home.find_children("MoreGroupHead_*", "Button", true, false)
			_lines.append("组标题数 = %d" % heads.size())
			for h in heads:
				(h as Button).pressed.emit()
			await get_tree().process_frame
			await get_tree().process_frame
			await get_tree().process_frame
			_dump(more, "更多面板 MorePanel（全部组展开）")
			# 逐格核对「按钮矩形是否包住图标与标签」
			var bad := 0
			for b in home.find_children("MoreBtn_*", "Button", true, false):
				var bb: Button = b as Button
				var br: Rect2 = bb.get_global_rect()
				for sub in bb.get_children():
					if sub is Control and (sub as Control).name != "Label":
						var sr: Rect2 = (sub as Control).get_global_rect()
						if not br.encloses(sr):
							bad += 1
							_lines.append("  !! 溢出: %s 按钮[%s] 不包含 %s[%s]"
								% [bb.name, str(br), (sub as Control).name, str(sr)])
			_lines.append("★ 图标溢出按钮的格数 = %d" % bad)
		home.queue_free()

	# ---------- 2) 宗门典藏顶栏 ----------
	var CodexScript: GDScript = load("res://ui/page_codex.gd")
	if CodexScript == null:
		_lines.append("!! 无法加载 page_codex.gd")
	else:
		await get_tree().process_frame
		var page: Control = CodexScript.new()
		get_tree().root.add_child(page)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var tb: Node = page.find_child("TopBar", true, false)
		if tb == null:
			_lines.append("!! 未找到 TopBar")
		else:
			_dump(tb, "宗门典藏 TopBar")
			var back: Node = page.find_child("BackBtn", true, false)
			if back != null:
				var br: Rect2 = (back as Control).get_global_rect()
				var cx: float = br.position.x + br.size.x * 0.5
				_lines.append("")
				_lines.append("★ 返回键中心 x = %.1f / 视口 %.1f = %.1f%%（期望贴左，<15%% 为正常）"
					% [cx, vp.x, cx / vp.x * 100.0])
			else:
				_lines.append("!! 未找到 BackBtn")
		page.queue_free()

	# ---------- 3) 殿阁页：红点不得盖满卡片（PanelContainer 会把直接子节点拉伸满铺）----------
	var BuildScript: GDScript = load("res://ui/page_building.gd")
	if BuildScript == null:
		_lines.append("!! 无法加载 page_building.gd")
	else:
		# 逼出「可升级」态：红点只在 可升级==true 时创建，否则根本无从验证拉伸回归。
		# 只改内存值、不落盘（诊断进程退出即丢）。
		if Game != null:
			if "灵石" in Game:
				Game.set("灵石", 999999999)
			# 殿阁等级存于 Game.司职列表[key]["等级"]。压到 1 让 level < 上限 成立，
			# 红点才会被创建（只改内存，不落盘）。
			if "司职列表" in Game:
				var lst = Game.get("司职列表")
				if lst is Dictionary:
					var n := 0
					for k in lst.keys():
						if lst[k] is Dictionary:
							lst[k]["等级"] = 1
							n += 1
					_lines.append("临时压低殿阁等级: %d 座 -> 1" % n)
			_lines.append("临时灵石 = %s（仅为逼出红点，未落盘）" % str(Game.get("灵石")))
		var pb: Control = BuildScript.new()
		get_tree().root.add_child(pb)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var cards: Array = pb.find_children("Card_*", "PanelContainer", true, false)
		var dots: Array = pb.find_children("RedDot", "PanelContainer", true, false)
		_lines.append("")
		_lines.append("=========== 殿阁页 卡片/红点 ===========")
		_lines.append("卡片数 = %d" % cards.size())
		if not cards.is_empty():
			var c0: Control = cards[0] as Control
			var subs: PackedStringArray = PackedStringArray()
			for ch in c0.get_children():
				subs.append("%s(%s)" % [ch.name, ch.get_class()])
			_lines.append("首卡 rect[%.1f x %.1f] 直接子节点 = %s"
				% [c0.size.x, c0.size.y, ", ".join(subs)])
		_lines.append("RedDot 数 = %d（0 = 当前账号无可升级殿阁，属正常，需 F5 目视确认）" % dots.size())
		var huge := 0
		for d in dots:
			var dn := d as Control
			var dr: Rect2 = dn.get_global_rect()
			var holder: Node = dn.get_parent()
			var hr: Rect2 = (holder as Control).get_global_rect() if holder is Control else Rect2()
			if holder is Control and dr.size.x > hr.size.x * 0.5:
				huge += 1
			_lines.append("  %s rect[%.1f x %.1f] 宿主 %s[%.1f x %.1f]"
				% [dn.name, dr.size.x, dr.size.y, holder.name, hr.size.x, hr.size.y])
		_lines.append("★ 与宿主同宽的红点数 = %d（应 0；修复前红点直接挂在卡片上，必为卡片全宽）" % huge)
		pb.queue_free()

	await get_tree().process_frame
	_flush()
	get_tree().quit()


func _flush() -> void:
	DirAccess.make_dir_recursive_absolute("res://.scratch_backup")
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()
		print("WROTE ", OUT_PATH)
	for l in _lines:
		print(l)
