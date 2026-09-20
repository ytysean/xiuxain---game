extends Node
## 图标清晰度链路数值探针（纯数值，可不截图 —— 支持 --headless）
##
## 目的：实测「纹理实际分辨率 → 控件画布尺寸 → 屏幕物理像素」的真实比值，
##       不依赖任何猜测（project.godot 的 scale 只是配置，控件实际 size 由布局决定）。
##
## 用法：
##   godot --headless --path E:/Xiuxian/taixuanzongmenlu res://tests/_probe_sharp.tscn
## 产物：stdout（同时写 .scratch_backup/_probe_sharp.log）

const LOG_PATH := "res://.scratch_backup/_probe_sharp.log"
var _f: FileAccess = null

func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

func _ready() -> void:
	_f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_L("=".repeat(78))
	_L("① 工程渲染配置实测（不读 project.godot，读引擎生效值）")
	_L("=".repeat(78))
	var win: Window = get_window()
	var vp: Viewport = get_viewport()
	_L("  window.size            = %s" % str(win.size))
	_L("  window.content_scale_size   = %s" % str(win.content_scale_size))
	_L("  window.content_scale_factor = %.4f" % win.content_scale_factor)
	_L("  window.content_scale_mode   = %d  (0=DISABLED 1=CANVAS_ITEMS 2=VIEWPORT)" % win.content_scale_mode)
	_L("  window.content_scale_aspect = %d  (0=IGNORE 1=KEEP 2=KEEP_WIDTH 3=KEEP_HEIGHT 4=EXPAND)" % win.content_scale_aspect)
	_L("  viewport.size          = %s" % str(vp.get_visible_rect().size))
	var ft: Transform2D = vp.get_final_transform()
	_L("  viewport.get_final_transform() = scale(%.4f, %.4f) origin(%s)"
		% [ft.get_scale().x, ft.get_scale().y, str(ft.origin)])
	_L("  DisplayServer.window_get_size() = %s" % str(DisplayServer.window_get_size()))
	_L("  屏幕 size / DPI scale = %s / %.2f"
		% [str(DisplayServer.screen_get_size()), DisplayServer.screen_get_scale()])
	_L("")
	_L("  ── ProjectSettings 关键渲染项（引擎生效值）──")
	for k in ["rendering/textures/canvas_textures/default_texture_filter",
			"rendering/anti_aliasing/quality/msaa_2d",
			"rendering/anti_aliasing/quality/screen_space_aa",
			"rendering/2d/snap/snap_2d_transforms_to_pixel",
			"rendering/2d/snap/snap_2d_vertices_to_pixel",
			"rendering/scaling_3d/mode",
			"display/window/stretch/mode",
			"display/window/stretch/scale",
			"display/window/stretch/scale_mode"]:
		_L("    %-56s = %s" % [k, str(ProjectSettings.get_setting(k, "<未设置>"))])

	# ── 计算「画布坐标 → 屏幕物理像素」的换算率 ──
	var canvas_w: float = float(win.content_scale_size.x) if win.content_scale_size.x > 0 else float(vp.get_visible_rect().size.x)
	var phys_w: float = float(win.size.x)
	var ratio: float = phys_w / canvas_w
	_L("")
	_L("  ★ 画布坐标 → 屏幕物理像素 换算率 = %.4f  （窗口宽 %.0f / 画布宽 %.0f）" % [ratio, phys_w, canvas_w])
	_L("     注意：这是**开发预览**的值。实机打包后 window_width_override 为 0，窗口=1080 ⇒ 该值为 1.0")
	_L("")

	await get_tree().process_frame
	await _probe_home(ratio)
	await _probe_shop(ratio)

	_L("")
	_L("PROBE_SHARP_DONE")
	if _f != null:
		_f.close()

func _probe_home(ratio: float) -> void:
	_L("=".repeat(78))
	_L("② 首页入口图标（含 UITheme.建图标底座 的底座直径）")
	_L("=".repeat(78))
	await get_tree().process_frame
	var home: Node = null
	for n in get_tree().root.find_children("*", "Control", true, false):
		var _scr: Variant = n.get_script()
		var _sp: String = str((_scr as Script).resource_path) if _scr != null else ""
		if _sp.contains("sect_home_page"):
			home = n
			break
	if home == null:
		_L("  未找到首页（sect_home_page）—— 可能主场景未加载首页，跳过")
		return
	var found: int = 0
	for n in home.find_children("*", "TextureRect", true, false):
		var t: TextureRect = n
		if t.texture == null:
			continue
		var ts: Vector2 = t.texture.get_size()
		var cs: Vector2 = t.size
		_L("    %-34s tex=%-11s size=%-14s 屏幕px=%-14s 缩小倍率=%.2f  filter=%d stretch=%d" % [
			str(t.name).left(33), "%dx%d" % [int(ts.x), int(ts.y)],
			"(%.1f,%.1f)" % [cs.x, cs.y],
			"(%.1f,%.1f)" % [cs.x * ratio, cs.y * ratio],
			(max(ts.x, 1.0) / max(cs.x * ratio, 0.01)),
			t.texture_filter, t.stretch_mode])
		found += 1
		if found >= 18:
			break
	if found == 0:
		_L("    首页暂无带贴图的 TextureRect")
	var lbl: int = 0
	for n in home.find_children("*", "Label", true, false):
		var l: Label = n
		var fs: int = l.get_theme_font_size("font_size")
		if lbl < 6:
			_L("    [Label] %-22s 字号=%d 画布px  → 屏幕 %.1fpx" % [str(l.name).left(21), fs, float(fs) * ratio])
		lbl += 1
	_L("")

func _probe_shop(ratio: float) -> void:
	_L("=".repeat(78))
	_L("③ 坊市页商品图标 / 特供图标")
	_L("=".repeat(78))
	await get_tree().process_frame
	var shop: Node = null
	for n in get_tree().root.find_children("*", "Control", true, false):
		var _scr2: Variant = n.get_script()
		var _sp2: String = str((_scr2 as Script).resource_path) if _scr2 != null else ""
		if _sp2.contains("page_shop"):
			shop = n
			break
	if shop == null:
		_L("  未打开坊市页，跳过（探针不强制开页，避免引入 UI 副作用）")
		return
	for n in shop.find_children("*", "TextureRect", true, false):
		var t: TextureRect = n
		if t.texture == null:
			continue
		var ts: Vector2 = t.texture.get_size()
		var cs: Vector2 = t.size
		_L("    %-30s tex=%-11s size=%-14s 屏幕px=%-14s 缩小倍率=%.2f" % [
			str(t.name).left(29), "%dx%d" % [int(ts.x), int(ts.y)],
			"(%.1f,%.1f)" % [cs.x, cs.y], "(%.1f,%.1f)" % [cs.x * ratio, cs.y * ratio],
			(max(ts.x, 1.0) / max(cs.x * ratio, 0.01))])
