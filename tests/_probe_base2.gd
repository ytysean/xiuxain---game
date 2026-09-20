extends Node
## 底座「恒定物理环宽」尺寸验证（走**真实** UITheme.建图标底座 路径 · 真实渲染）。
## 用法：<godot> --path . res://tests/_probe_base2.tscn
## 目的：确认 instance uniform ico_dia_px 生效 —— 大小为 30/40/66/96 逻辑时，
##       环带宽应都是 ~5.5 物理像素（而不是随尺寸线性缩放）。

const ICONS: Array = [
	["entry_dynasty_36", "凡人王朝"],
	["entry_lingniang_36", "灵酿"],
	["entry_zhenfa_36", "传送阵"],
	["entry_kucang_36", "库藏"],
]
const SIZES: Array = [30.0, 40.0, 66.222222, 96.0]

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	await _settle(4)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bgp := ColorRect.new()
	bgp.color = UITheme.C01_SCENE_BASE
	bgp.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bgp)

	var s: float = UITheme.UI_SCALE
	var y: float = 30.0
	for si in range(SIZES.size()):
		var dia: float = float(SIZES[si])
		var 物理: float = dia * s
		var hd := Label.new()
		hd.text = "%s 逻辑 = %.0f 物理   环宽应 ≈5.5px" % [str(dia), 物理]
		hd.position = Vector2(30.0, y * s)
		hd.size = Vector2(1000.0, 40.0)
		hd.add_theme_font_size_override("font_size", 20)
		hd.add_theme_color_override("font_color", UITheme.获取主文字色())
		root.add_child(hd)
		y += 34.0
		for ci in range(ICONS.size()):
			var stem: String = ICONS[ci][0]
			var x: float = 40.0 + ci * (物理 + 20.0) / s
			var base: TextureRect = UITheme.建图标底座(dia)
			base.position = Vector2(x * s, y * s)
			base.size = Vector2(物理, 物理)
			root.add_child(base)
			var icon := TextureRect.new()
			icon.texture = UITheme.load_hd_icon(stem)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.position = Vector2(x * s, y * s)
			icon.size = Vector2(物理, 物理)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(icon)
		y += 物理 / s + 24.0

	await _settle(10)
	await _save(get_viewport(), "res://_probe_base_size.png")
	prints(">>> 尺寸验证板 → _probe_base_size.png")
	prints(">>>PROBE_BASE2_DONE")
	get_tree().quit()

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(vp: Viewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img == null:
		prints(">>>WARN 截图失败 %s" % path)
		return
	img.save_png(path)
