extends Control
## 底座系统运行时探针：打印真实纹理/材质/uniform，并渲染实机尺寸画面截图。
## 运行：Godot_v4.7 --path . tests/_probe_iconbase.tscn
## 产出：accept_shots_full/_probe_iconbase.txt + _probe_iconbase.png

const OUT_TXT := "res://accept_shots_full/_probe_iconbase.txt"
const OUT_PNG := "res://accept_shots_full/_probe_iconbase.png"

var _log: Array[String] = []

func _行(s: String) -> void:
	_log.append(s)
	print(s)


func _ready() -> void:
	# ★ 铁律（2026-09-15 老大定）：跑探针不许弹窗打扰 → 立即把窗口移出屏幕。
	#   不能用 --headless：dummy 渲染器截不出图（本探针价值就在真实渲染）。
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	_行("=== 底座系统运行时探针 ===")
	_行("ATLAS_PATH       = %s" % UITheme.ICON_BASE_ATLAS)
	_行("SHADER_PATH      = %s" % UITheme.ICON_BASE_SHADER)
	_行("EXISTS_ATLAS     = %s" % str(ResourceLoader.exists(UITheme.ICON_BASE_ATLAS)))
	_行("EXISTS_SHADER    = %s" % str(ResourceLoader.exists(UITheme.ICON_BASE_SHADER)))
	_行("GRID_CONST       = %s" % str(UITheme.ICON_BASE_GRID))

	var atlas: Resource = load(UITheme.ICON_BASE_ATLAS) if ResourceLoader.exists(UITheme.ICON_BASE_ATLAS) else null
	if atlas is Texture2D:
		_行("ATLAS_SIZE       = %s" % str((atlas as Texture2D).get_size()))
	else:
		_行("ATLAS_SIZE       = !! 加载失败 / 非 Texture2D")

	var sh: Resource = load(UITheme.ICON_BASE_SHADER) if ResourceLoader.exists(UITheme.ICON_BASE_SHADER) else null
	_行("SHADER_LOAD      = %s" % str(sh))
	if sh is Shader:
		_行("SHADER_CODE_LEN  = %d" % (sh as Shader).code.length())

	# ---- 核心：真实创建一个底座，看参数到底设没设 ----
	var b: TextureRect = UITheme.建图标底座(66.222)
	_行("BASE_NODE        = %s" % str(b != null))
	if b != null:
		_行("BASE.texture     = %s" % str(b.texture))
		if b.texture != null:
			_行("BASE.tex.size    = %s" % str(b.texture.get_size()))
		_行("BASE.material    = %s" % str(b.material))
		if b.material is ShaderMaterial:
			var m: ShaderMaterial = b.material
			_行("MAT.shader       = %s" % str(m.shader))
			_行("MAT.ico_grid     = %s   <<< 期望 (8, 1)" % str(m.get_shader_parameter("ico_grid")))
			_行("MAT.ico_frame    = %s" % str(m.get_shader_parameter("ico_frame")))
			_行("MAT.ico_hue      = %s" % str(m.get_shader_parameter("ico_hue")))
			_行("MAT.ico_sat      = %s" % str(m.get_shader_parameter("ico_sat")))
			_行("MAT.ico_val      = %s" % str(m.get_shader_parameter("ico_val")))
			_行("MAT.ico_tint     = %s" % str(m.get_shader_parameter("ico_tint")))
			var g: Variant = m.get_shader_parameter("ico_grid")
			if g is Vector2 and (g as Vector2).x > 1.5:
				_行("判定             = OK 图集分支已启用")
			else:
				_行("判定             = ★FAIL ico_grid 未生效 → 整张图集被压进 1 帧")
		else:
			_行("★★ MAT 为空 → TextureRect 直画整张图集 = 你看到的『6 个底座连在一起』")

	# ---- 渲染实机画面 ----
	_build_showcase()

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(OUT_PNG)
		_行("SHOT             = %s  %s" % [OUT_PNG, str(img.get_size())])
		var f := FileAccess.open(OUT_TXT, FileAccess.WRITE)
		if f != null:
			f.store_string("\n".join(_log))
			f.close()
	get_tree().quit()


## 按实机尺寸渲染：左=新版裸金+底座，右=旧版自带徽章（用不叠底座的同尺寸对照）
func _build_showcase() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.24, 0.25, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.position = Vector2(24, 60)
	add_child(row)

	var stems: Array[String] = ["entry_fangshi_36", "entry_qiandao_36", "entry_library_36", "entry_master_36"]
	for s in stems:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(149, 149)
		var tex: Texture2D = UITheme.load_hd_icon(s)
		# 新版（白名单内）→ 叠底座；不在白名单 → 不叠
		if UITheme.图标需要底座(s):
			var base: TextureRect = UITheme.建图标底座(149.0)
			base.size = Vector2(149, 149)
			base.position = Vector2.ZERO
			cell.add_child(base)
			# 复刻 _make_entry 的覆写（若有）
			_套用入口底座覆写(base)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(149, 149)
		icon.position = Vector2.ZERO
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
		row.add_child(cell)

	var tip := Label.new()
	tip.text = "左4 = 白名单图标(+底座)   |   %s" % str(stems)
	tip.position = Vector2(24, 20)
	tip.add_theme_color_override("font_color", Color.WHITE)
	add_child(tip)


func _套用入口底座覆写(_b: TextureRect) -> void:
	pass
