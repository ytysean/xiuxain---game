extends Node
## 图标清晰度 —— 实机并排 A/B 探针（完全确定、可复现）
##
## 为什么不用坊市页做 A/B：坊市上架走 `randi_range(8,12)` + `shuffle()`，
## 每次启动商品列表都不同，两次运行无法逐件对比（2026-09-16 实测踩到）。
##
## 本探针在同一屏内并排「同一图标的多种纹理分辨率 + 固定显示尺寸」，
## 唯一变量是纹理分辨率，GPU 采样路径与真实商品卡完全一致 ⇒ 可肉眼一锤定音。
##
## 用法：<godot> --path <proj> res://tests/_probe_ab_sharp.tscn

const SRC := "res://art/icons/shop/shop_zhengdao_003_512.png"
const OUT_DIR := "res://accept_shots_full/"
const LOG := "res://.scratch_backup/_probe_ab_sharp.log"

## 行1：真实商品卡尺寸（画布 104px，720 预览下约 69 物理像素）
const ROW1_SIZES: Array = [1024, 512, 256, 192, 128]
const ROW1_DISPLAY := 104.0
## 行2：放大到 208px 观察细节（纹理 512 在此行等价于「行1 的 256」）
const ROW2_SIZES: Array = [1024, 512, 256]
const ROW2_DISPLAY := 208.0

var _f: FileAccess = null


func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()


func _ready() -> void:
	var w: Window = get_window()
	if w != null and DisplayServer.get_name() != "headless":
		w.position = Vector2i(-6000, -6000)
	_f = FileAccess.open(LOG, FileAccess.WRITE)

	# 底色（便于观察透明边缘是否发脏）
	var bg := ColorRect.new()
	bg.color = Color(0.075, 0.180, 0.153)
	bg.position = Vector2.ZERO
	bg.size = Vector2(1080, 1920)
	add_child(bg)

	# 取**原始 PNG 字节**，绕开 import 链路，拿到完整 1024 源图
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SRC)
	var base := Image.new()
	var err: int = base.load_png_from_buffer(bytes)
	_L("源图加载 err=%d  size=%dx%d" % [err, base.get_width(), base.get_height()])
	if err != OK:
		_L("FAIL 源图加载失败")
		get_tree().quit()
		return

	var title := Label.new()
	title.text = "纹理分辨率 vs 显示尺寸（同一图标 · 唯一变量=纹理大小）"
	title.position = Vector2(40, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.59))
	add_child(title)

	_L("")
	_L("行1  显示尺寸 = %d 画布px（720 预览窗口下约 %.1f 物理像素）" % [int(ROW1_DISPLAY), ROW1_DISPLAY * 720.0 / 1080.0])
	_build_row(base, ROW1_SIZES, ROW1_DISPLAY, 130.0)
	_L("")
	_L("行2  显示尺寸 = %d 画布px（放大观察细节）" % int(ROW2_DISPLAY))
	_build_row(base, ROW2_SIZES, ROW2_DISPLAY, 420.0)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_L("")
	_L("── 实测控件尺寸自检（验证 expand_mode 修正是否生效）──")
	_L("  viewport.visible_rect = %s" % str(get_viewport().get_visible_rect().size))
	_L("  window.size = %s   content_scale_size = %s   factor = %.4f"
		% [str(w.size), str(w.content_scale_size), w.content_scale_factor])
	_L("  （物理占比 = 窗口宽 / 画布宽 = %.4f）" % (float(w.size.x) / float(w.content_scale_size.x)))
	for c in get_children():
		if c is TextureRect:
			var t2: TextureRect = c
			_L("  TextureRect pos=%-14s size=%-14s expand=%d filter=%d"
				% ["(%.0f,%.0f)" % [t2.position.x, t2.position.y],
				   "(%.0f,%.0f)" % [t2.size.x, t2.size.y], t2.expand_mode, t2.texture_filter])
	var shot: Image = get_viewport().get_texture().get_image()
	var out: String = OUT_DIR + "_probe_ab_sharp.png"
	var se: int = shot.save_png(out)
	_L("")
	_L("SAVED %s err=%d  size=%dx%d" % [out, se, shot.get_width(), shot.get_height()])
	_L("PROBE_AB_SHARP_DONE")
	if _f != null:
		_f.close()
	get_tree().quit()


func _build_row(base: Image, sizes: Array, disp: float, y0: float) -> void:
	var gap: float = 34.0
	var x: float = 40.0
	for s_v in sizes:
		var s: int = int(s_v)
		var im: Image = base.duplicate() as Image
		var maxside: int = max(im.get_width(), im.get_height())
		if maxside > s:
			var k: float = float(s) / float(maxside)
			im.resize(int(round(im.get_width() * k)), int(round(im.get_height() * k)),
				Image.INTERPOLATE_LANCZOS)
		var tex: ImageTexture = ImageTexture.create_from_image(im)
		var tr := TextureRect.new()
		# ★ 顺序至关重要（2026-09-16 实测踩坑）：
		#   若先设 tr.size 再设 expand_mode，赋值 size 的那一刻 expand_mode 仍是默认
		#   EXPAND_KEEP_SIZE，get_minimum_size() 会返回 max(custom_min, texture.size())
		#   = 1024，尺寸即被 clamp 到 1024；之后即使改成 IGNORE_SIZE，size 也不会自动回退，
		#   实测 size 恒为 (1024,1024) —— 「size 设了却无效」的真正原因。
		#   正确顺序：先 texture + expand_mode，最后设 size；add_child 后再兜一次。
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.custom_minimum_size = Vector2(disp, disp)
		tr.position = Vector2(x, y0)
		tr.size = Vector2(disp, disp)
		add_child(tr)
		tr.size = Vector2(disp, disp)

		var lb := Label.new()
		lb.text = "%dpx\n%.2f 倍" % [s, float(s) / (disp * 720.0 / 1080.0)]
		lb.position = Vector2(x, y0 + disp + 6.0)
		lb.add_theme_font_size_override("font_size", 24)
		lb.add_theme_color_override("font_color", Color(0.86, 0.90, 0.88))
		add_child(lb)

		_L("   纹理 %4dpx  显示 %.0f 画布px  => 纹理/屏幕 = %.2f 倍" % [
			s, disp, float(s) / (disp * 720.0 / 1080.0)])
		x += disp + gap
