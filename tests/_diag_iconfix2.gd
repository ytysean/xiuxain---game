extends Node

## 2026-09-15 第二轮回归修复的 headless 验收（5 项）。
##
## 覆盖：
##   ① `UITheme.format_resource` —— 去掉 GDScript 不支持的 `%g`（「点坊市卡死」的真凶）
##   ② 图标底座**白名单制**（2026-09-15 v2）—— 总开关 true，但只有裸金器物图标
##      （UITheme.ICON_BASE_WHITELIST）才叠；旧版自带徽章图必须跳过。
##      反查断言：运行期每个 IconBase 的宿主图标都必须在白名单内（防「给旧图误叠」回归）。
##   ③ 隐藏UI：BGVeil（上下暗晕）必须随 chrome 同生共死（修「隐藏UI后上下还有蒙版」）
##   ④ 隐藏UI：浮标被二级页压下时必须彻底隐藏（修「点其他界面之后隐藏ui图标还是显示」）
##   ⑤ 隐藏UI：浮标新落点 (452, 430) 逻辑 + two-state alpha
##
## 运行：
##   godot --headless --path <proj> res://tests/_diag_iconfix2.tscn
## 产物：res://.scratch_backup/iconfix2_dump.txt（EXIT 码 0 = 全通过，1 = 有失败项）

const OUT_PATH := "res://.scratch_backup/iconfix2_dump.txt"
const HOME_SCRIPT := "res://ui/sect_home_page.gd"
const TAB_SCRIPT := "res://ui/bottom_tab_bar.gd"

var _lines: PackedStringArray = PackedStringArray()
var _fail: int = 0
var _done: bool = false


func _chk(ok: bool, title: String, detail: String) -> void:
	if not ok:
		_fail += 1
	_lines.append("%s %-46s | %s" % ["[PASS]" if ok else "[FAIL]", title, detail])


func _count_named(root: Node, target: String) -> int:
	var n: int = 0
	if root.name == target:
		n += 1
	for c in root.get_children():
		n += _count_named(c, target)
	return n

## 反查底座归属：对每个 IconBase，取同宿主下的 "Icon" 纹理路径反推 stem，
## 若该 stem 不在 UITheme.ICON_BASE_WHITELIST 内 → 记为误叠（旧版徽章被垫了底座）。
func _检查底座归属(root: Node, out: Array) -> void:
	if root is Node and root.name == "IconBase":
		var stem: String = ""
		for sib in root.get_parent().get_children():
			if sib.name == "Icon" and sib is TextureRect:
				var tex: Texture2D = sib.texture
				if tex != null and tex.resource_path != "":
					stem = tex.resource_path.get_file().get_basename()
				break
		if not UITheme.图标需要底座(stem):
			out.append("%s(图标=%s)" % [root.get_parent().name, stem if stem != "" else "?"])
	for c in root.get_children():
		_检查底座归属(c, out)


func _flush() -> void:
	if _done:
		return
	_done = true
	_lines.append("")
	_lines.append("========== 总判定：%s（FAIL=%d）=========="
		% ["[PASS] 全部通过" if _fail == 0 else "[FAIL] 有未通过项", _fail])
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines))
		f.close()


func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		_lines.append("!! 看门狗超时")
		_flush()
		get_tree().quit(1))

	# headless 虚拟屏是正方形，不强制设计视口则一切 viewport 相对判断失真
	if DisplayServer.get_name() == "headless":
		get_window().size = Vector2i(1080, 1920)
		await get_tree().process_frame
		await get_tree().process_frame

	var vp: Vector2 = get_viewport().get_visible_rect().size
	_lines.append("显示后端 = %s / 视口 = %.0f x %.0f" % [DisplayServer.get_name(), vp.x, vp.y])
	_lines.append("")

	# ==================== ① format_resource：%g 致命 bug ====================
	_lines.append("---------- ① format_resource（%g 已移除）----------")
	var cases: Array = [
		[0, false], [999, false], [9999, false],
		[10000, true], [12345, true], [99999999, true], [250000000, true],
	]
	for c in cases:
		var v: int = int(c[0])
		var s: String = UITheme.format_resource(v)
		# 崩溃点特征：GDScript 的 % 遇到非法转换符会返回原串或空串，且必然残留 '%'。
		# 合法输出必须非空、不含 '%'、且仅当 >= 10000 才带「万 / 亿」量词。
		var 该带量词: bool = bool(c[1])
		var 带量词: bool = s.contains("万") or s.contains("亿")
		var ok: bool = s != "" and not s.contains("%") and 带量词 == 该带量词
		_chk(ok, "format_resource(%d)" % v, "-> \"%s\"" % s)
	_lines.append("")

	# ==================== ② 底座白名单制（v2：从全局开关改为按图标） ====================
	_lines.append("---------- ② 图标底座白名单 ----------")
	_chk(UITheme.ENABLE_ICON_BASE == true, "ENABLE_ICON_BASE 总开关 = true",
		"= %s" % str(UITheme.ENABLE_ICON_BASE))
	_chk(UITheme.图标需要底座("entry_fangshi_36") == true,
		"白名单内（裸金器物 entry_fangshi_36）→ 需要底座", "= false")
	# 2026-09-15 二次裁定：天下是从不被误判为"自带徽章"的裸器物，必须叠底座。
	# （旧断言 == false 系半径启发式误判所留，已更正；判据改为全量目视核验，见 ui_theme.gd 白名单注释。）
	_chk(UITheme.图标需要底座("entry_tianxia_36") == true,
		"白名单内（裸器物 entry_tianxia_36）→ 需要底座", "= false")
	_chk(UITheme.图标需要底座("tab_zongmen_36") == false,
		"tab_* 旧版金边图 → 不叠底座（叠加会成双影）", "= true")
	_chk(UITheme.图标需要底座("") == false, "空 stem → 不叠底座", "= true")

	# ==================== ③④⑤ 首页：隐藏UI 三连 ====================
	_lines.append("")
	_lines.append("---------- ③④⑤ 首页 隐藏UI 状态机 ----------")
	var HomeScript: GDScript = load(HOME_SCRIPT)
	if HomeScript == null:
		_chk(false, "load sect_home_page.gd", "失败")
	else:
		var home: Control = HomeScript.new()
		add_child(home)
		await get_tree().process_frame
		await get_tree().process_frame

		var n_base: int = _count_named(home, "IconBase")
		_chk(n_base > 0, "首页子树 IconBase 节点数 > 0（白名单内有已解锁入口）", "count = %d" % n_base)
		# ★ 反查：每个 IconBase 的宿主图标都必须在白名单内 —— 这条抓的是"给旧版徽章误叠底座"。
		#   拿 IconBase 的兄弟节点 Icon 的纹理路径反推 stem，再问白名单。
		var 误叠: Array = []
		_检查底座归属(home, 误叠)
		_chk(误叠.is_empty(), "所有 IconBase 的宿主图标均在白名单内（无误叠）",
			"误叠 %d 个: %s" % [误叠.size(), str(误叠)])

		var chrome: Control = home.get("_chrome")
		var veil: TextureRect = home.get("_bg_veil")
		var eye: Button = home.get("_eye_btn")

		_chk(chrome != null, "chrome 节点已就位", "= %s" % str(chrome))
		_chk(veil != null, "BGVeil 已被 _bg_veil 引用", "= %s" % str(veil))
		_chk(eye != null, "HideUIBtn 已被 _eye_btn 引用", "= %s" % str(eye))

		# --- 常态 ---
		_chk(chrome != null and chrome.visible, "常态 chrome 可见",
			"= %s" % (str(chrome.visible) if chrome != null else "n/a"))
		_chk(veil != null and veil.visible, "常态 BGVeil 可见（仍给顶栏/快捷栏托底）",
			"= %s" % (str(veil.visible) if veil != null else "n/a"))
		if eye != null:
			_chk(eye.visible, "常态 浮标可见", "= %s" % str(eye.visible))
			_chk(absf(eye.modulate.a - 0.55) < 0.01, "常态 浮标 α0.55 待机",
				"α = %.2f" % eye.modulate.a)
			# 落点：offset 是 1080×1920 坐标系，÷UI_SCALE 回逻辑
			var cx: float = (eye.offset_left + eye.offset_right) * 0.5 / UITheme.UI_SCALE
			var cy: float = (eye.offset_top + eye.offset_bottom) * 0.5 / UITheme.UI_SCALE
			_chk(absf(cx - 452.0) < 0.6 and absf(cy - 430.0) < 0.6,
				"浮标落点 = 逻辑 (452, 430) 右边缘悬浮位",
				"实测 (%.1f, %.1f)" % [cx, cy])
			_lines.append("        · 屏幕占比 x %.1f%% / y %.1f%%"
				% [cx / 480.0 * 100.0, cy / 854.0 * 100.0])

		# --- 玩家按「隐藏UI」 ---
		home.call("_on_hide_ui_pressed")
		await get_tree().process_frame
		_chk(chrome != null and not chrome.visible, "按隐藏UI -> chrome 收起",
			"= %s" % (str(chrome.visible) if chrome != null else "n/a"))
		_chk(veil != null and not veil.visible,
			"按隐藏UI -> BGVeil 同步收起（修「上下还有蒙版」）",
			"= %s" % (str(veil.visible) if veil != null else "n/a"))
		if eye != null:
			_chk(eye.visible, "按隐藏UI -> 浮标仍可见（否则回不来）", "= %s" % str(eye.visible))
			_chk(absf(eye.modulate.a - 0.95) < 0.01, "按隐藏UI -> 浮标提亮 α0.95",
				"α = %.2f" % eye.modulate.a)

		# --- game_ui._show_sub_page 的真实调用：set_chrome_visible(false) ---
		home.call("set_chrome_visible", false)
		await get_tree().process_frame
		if eye != null:
			_chk(not eye.visible,
				"二级页压下 -> 浮标彻底隐藏（修「点其他界面还显示」）",
				"= %s" % str(eye.visible))
		_chk(veil != null and not veil.visible, "二级页压下 -> BGVeil 保持收起",
			"= %s" % (str(veil.visible) if veil != null else "n/a"))

		# --- game_ui._close_sub_page 的真实调用：set_chrome_visible(true) ---
		home.call("set_chrome_visible", true)
		await get_tree().process_frame
		_chk(chrome != null and chrome.visible, "返回首页 -> chrome 恢复",
			"= %s" % (str(chrome.visible) if chrome != null else "n/a"))
		_chk(veil != null and veil.visible, "返回首页 -> BGVeil 恢复",
			"= %s" % (str(veil.visible) if veil != null else "n/a"))
		if eye != null:
			_chk(eye.visible, "返回首页 -> 浮标恢复", "= %s" % str(eye.visible))
			_chk(absf(eye.modulate.a - 0.55) < 0.01, "返回首页 -> 浮标回到 α0.55",
				"α = %.2f" % eye.modulate.a)

		home.queue_free()
		await get_tree().process_frame

	# ==================== 底栏 Tab 底座计数 ====================
	_lines.append("")
	_lines.append("---------- 底栏 Tab ----------")
	var TabScript: GDScript = load(TAB_SCRIPT)
	if TabScript == null:
		_chk(false, "load bottom_tab_bar.gd", "失败")
	else:
		var tab: Control = TabScript.new()
		add_child(tab)
		await get_tree().process_frame
		await get_tree().process_frame
		var n_tab_base: int = _count_named(tab, "IconBase")
		_chk(n_tab_base == 0, "底栏 Tab 子树 IconBase 节点数 = 0", "count = %d" % n_tab_base)
		var n_ring: int = _count_named(tab, "Ring_宗门") + _count_named(tab, "Ring_弟子") \
			+ _count_named(tab, "Ring_殿阁") + _count_named(tab, "Ring_历练") \
			+ _count_named(tab, "Ring_纪事")
		_chk(n_ring == 5, "底栏 5 个选中金环仍在（未被误删）", "count = %d" % n_ring)
		tab.queue_free()
		await get_tree().process_frame

	_flush()
	print("\n".join(_lines))
	get_tree().quit(1 if _fail > 0 else 0)
