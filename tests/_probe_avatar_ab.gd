extends Node
## 头像清晰度 A/B 探针（弟子头像 + 宗主头像）
##
## 目的：把两类头像在**真实显示尺寸**下的引擎实际渲染，与「理想参考」同屏并排，
##       用于量化纹理档位（size_limit / compress mode / mipmap）改动前后的观感差异。
##
## 判据：理想参考 = 原始源图 LANCZOS 降到目标显示尺寸 ⇒ 代表"完美管线"下的上限。
##       实测 = load(导入纹理) 缩放到同一尺寸 ⇒ 含 size_limit 丢弃 + GPU 采样损失 + 块压缩伪影。
##
## 用法：
##   godot --path E:/Xiuxian/taixuanzongmenlu res://tests/_probe_avatar_ab.tscn
## 产物：accept_shots_full/_probe_avatar_ab.png

const OUT_DIR: String = "res://accept_shots_full/"
const 宗主纹理: String = "res://art/characters/masters_circle/master_male_daopao.png"
# 理想参考必须以「同一张图的原始全分辨率源」为准 —— 宗主头像是 masters_circle 的 598×598 圆头版本，
# 不是 masters/ 下的 832×1216 全身立绘（两者构图不同，混用会让"理想"失真）。
const 宗主源图: String = "res://art/characters/masters_circle/master_male_daopao.png"
const 弟子纹理: String = "res://art/characters/disciples/弟子立绘/depth/depth_bao_男_halfbody.png"
const 弟子源图: String = "res://art/characters/disciples/弟子立绘/depth/depth_bao_男_halfbody.png"
const MASK_SHADER: String = "res://ui/avatar_circle_mask.gdshader"

# 真实显示档位（1080 画布物理像素）
#   弟子列表卡 = 50 * UI_SCALE(2.25) = 112.5
#   宗主顶栏   = AVATAR_RING_DIA(52) * 2.25 = 117
#   宗主弹窗网格 = 140*2.25 - 28*2.25 = 252
#   宗主弹窗预览 = 120 * 2.25 = 270
# mip 字段 = 该显示点在本项目里的真实滤镜配置（依据实测量化结论）：
#   缩小 ≥2.3x ⇒ 开 mipmap（消混叠）；≈2x ⇒ 保持 LINEAR（开 mipmap 会让 LOD1 被放大而变糊）
const COLS: Array = [
	{"x": 40.0, "dia": 112.5, "tag": "弟子卡 112.5", "mip": true},
	{"x": 200.0, "dia": 117.0, "tag": "宗主顶栏 117", "mip": true},
	{"x": 380.0, "dia": 252.0, "tag": "宗主网格 252", "mip": false},
	{"x": 680.0, "dia": 270.0, "tag": "宗主预览 270", "mip": false},
]
const ROW_NOMIP: float = 80.0
const ROW_MIP: float = 470.0
const ROW_IDEAL: float = 860.0

var _f: FileAccess = null

func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

# 从原始 PNG 字节读全分辨率图（绕开 import 链路的 size_limit / 压缩）
func _raw(path: String) -> Image:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var im := Image.new()
	if im.load_png_from_buffer(bytes) != OK:
		return null
	return im

# 从源图裁中间正方形后 LANCZOS 降到目标边长（理想参考）
func _ideal(src: Image, dia: int) -> ImageTexture:
	if src == null:
		return null
	var w: int = src.get_width()
	var h: int = src.get_height()
	var side: int = w
	if h < side:
		side = h
	var y0: int = int((h - side) * 0.5)
	var crop: Image = src.get_region(Rect2i(0, y0, side, side))
	crop.resize(dia, dia, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(crop)

func _mk(tex: Texture2D, x: float, y: float, dia: float, mask: Shader, use_mip: bool) -> TextureRect:
	var tr := TextureRect.new()
	# ★ 顺序至关重要：texture → expand_mode → custom_minimum_size → size
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if use_mip:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if mask != null:
		var m := ShaderMaterial.new()
		m.shader = mask
		tr.material = m
	tr.custom_minimum_size = Vector2(dia, dia)
	tr.position = Vector2(x, y)
	tr.size = Vector2(dia, dia)
	add_child(tr)
	tr.size = Vector2(dia, dia)
	return tr

func _label(t: String, x: float, y: float, w: float, fs: int) -> void:
	var l := Label.new()
	l.text = t
	l.position = Vector2(x, y)
	l.size = Vector2(w, 26.0)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	add_child(l)

func _shot() -> void:
	await RenderingServer.frame_post_draw
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var img: Image = vp.get_texture().get_image()
	if img == null:
		_L(">>> 截图失败：get_image() 返回空")
		return
	var out: String = OUT_DIR + "_probe_avatar_ab.png"
	var err: int = img.save_png(out)
	_L(">>> 截图 save_png=%d  %s" % [err, out])

func _ready() -> void:
	_f = FileAccess.open("res://.scratch_backup/_probe_avatar_ab.txt", FileAccess.WRITE)
	_L("=".repeat(70))
	_L("头像清晰度 A/B 探针")
	_L("=".repeat(70))
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
			# 窗口设为画布尺寸（1080×1920）⇒ content_scale_factor = 1.0，
			# 画布像素 1:1 落到窗口像素，截图即等价于实机观感（规避预览 0.6667 缩放）。
			w.size = Vector2i(1080, 1920)
			for _i in range(6):
				await get_tree().process_frame
			var wv: Vector2 = Vector2(w.size)
			_L("  window.size = %s   content_scale_size = %s" % [str(wv), str(w.content_scale_size)])

	var mask: Shader = load(MASK_SHADER) as Shader
	if mask == null:
		_L(">>> mask shader 加载失败，改圆将不生效")

	# 引擎实际使用的导入纹理（含 size_limit 丢弃 + compress mode）
	var tex_sect: Texture2D = load(宗主纹理) as Texture2D
	var tex_disc: Texture2D = load(弟子纹理) as Texture2D
	if tex_sect == null:
		_L(">>> FAIL 宗主纹理加载失败 %s" % 宗主纹理)
	if tex_disc == null:
		_L(">>> FAIL 弟子纹理加载失败 %s" % 弟子纹理)
	var ts_sect: Vector2 = Vector2.ZERO
	var ts_disc: Vector2 = Vector2.ZERO
	if tex_sect != null:
		ts_sect = tex_sect.get_size()
	if tex_disc != null:
		ts_disc = tex_disc.get_size()
	_L("宗主导入纹理 = %.0fx%.0f" % [ts_sect.x, ts_sect.y])
	_L("弟子导入纹理 = %.0fx%.0f" % [ts_disc.x, ts_disc.y])

	var src_sect: Image = _raw(宗主源图)
	var src_disc: Image = _raw(弟子源图)
	if src_sect != null:
		_L("宗主源图 = %dx%d" % [src_sect.get_width(), src_sect.get_height()])
	if src_disc != null:
		_L("弟子源图 = %dx%d" % [src_disc.get_width(), src_disc.get_height()])

	_label("行1 = 引擎渲染 · 全部 LINEAR（统一基准）", 40.0, 34.0, 900.0, 20)
	_label("行2 = 本次落地配置（按档位分别 LINEAR / LINEAR_WITH_MIPMAPS）", 40.0, 424.0, 980.0, 20)
	_label("行3 = 理想参考（源图 LANCZOS 降到同一尺寸 = 管线质量上限）", 40.0, 814.0, 980.0, 20)

	for c in COLS:
		var col: Dictionary = c
		var x: float = float(col["x"])
		var dia: float = float(col["dia"])
		var tag: String = str(col["tag"])
		var use_mip: bool = bool(col.get("mip", false))
		var is_disc: bool = tag.begins_with("弟子")
		var used: Texture2D = tex_disc if is_disc else tex_sect
		var src: Image = src_disc if is_disc else src_sect
		if used != null:
			_mk(used, x, ROW_NOMIP, dia, mask, false)
			_mk(used, x, ROW_MIP, dia, mask, use_mip)
		var ideal: ImageTexture = _ideal(src, int(round(dia)))
		if ideal != null:
			_mk(ideal, x, ROW_IDEAL, dia, mask, false)
		_label(tag, x, ROW_NOMIP + dia + 6.0, 280.0, 19)

	await _shot()
	_L("PROBE_AVATAR_AB_DONE")
	if _f != null:
		_f.close()
	get_tree().quit()
