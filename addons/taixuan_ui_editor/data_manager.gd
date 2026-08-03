@tool
extends RefCounted
class_name TaixuanUIData

# =============================================================================
# 太玄UI编辑器 —— 数据管理类（纯 GDScript / Godot 4.7 原生）
# =============================================================================
# 职责：
#   1. 控件数据工厂（create_default）：生成每种控件的默认属性字典
#   2. 数据与节点互转（build_control / apply_base / apply_style）
#   3. 工程文档序列化（build_doc / save_project / load_project）
#   4. 导出规范 JSON（export_json）
#   5. 颜色数组 <-> Color 互转
#
# 设计要点：
#   - 所有“可调参数/默认值”集中在文件顶部常量区，便于统一修改
#   - 控件数据全部以 Dictionary 存储，结构稳定，方便后续 AI 解析生成 .tscn
#   - 控件类型 6 种：TextureRect / Label / Button / Panel / AnimatedTexture(动画帧) / SpriteSheet(精灵表/图集)
#   - 所有控件使用绝对 position/size，不依赖任何容器（规避 Godot 4.7 容器压缩 bug）
#   - 必须加 @tool：在编辑器插件上下文被 @tool 脚本引用，否则 Godot 4.7 会解析失败
# =============================================================================


# ------------------------- 顶部可调常量（集中配置）-------------------------
# 画布默认分辨率（9:16 竖屏）
const DEFAULT_CANVAS_W: int = 768
const DEFAULT_CANVAS_H: int = 1344

# 控件类型常量
const TYPE_TEXTURE: String = "TextureRect"
const TYPE_LABEL:   String = "Label"
const TYPE_BUTTON:  String = "Button"
const TYPE_PANEL:   String = "Panel"
const TYPE_ANIMATED: String = "AnimatedTexture"   # 动画帧（导出为 TextureRect + AnimatedTexture 子资源）
const TYPE_SPRITESHEET: String = "SpriteSheet"     # 精灵表/图集（一张图按网格切片为 AtlasTexture 帧，导出为 TextureRect + AnimatedTexture，并附 SpriteFrames.tres）

# 导出/工程格式版本
const FORMAT_VERSION: String = "1.0"
const GENERATOR_NAME: String = "太玄UI编辑器"


# =============================================================================
# 一、控件数据工厂
# =============================================================================
# 生成单个控件的默认数据字典。
# index 用于自动命名（Label_001 等），避免重名。
static func create_default(type: String, index: int) -> Dictionary:
	var d: Dictionary = {
		"type": type,
		"name": "%s_%03d" % [type, index],
		"position": [100, 100],
		"size": _default_size(type),
		"min_size": _default_min_size(type),
		"z_index": 0,
		"anchor_preset": 0,          # Control.PRESET_TOP_LEFT
		"style": _default_style(type)
	}
	return d


# 各类控件默认尺寸 [宽, 高]
static func _default_size(type: String) -> Array:
	match type:
		TYPE_TEXTURE: return [200, 200]
		TYPE_LABEL:   return [220, 44]
		TYPE_BUTTON:  return [180, 60]
		TYPE_PANEL:   return [260, 160]
		TYPE_ANIMATED: return [200, 200]
		TYPE_SPRITESHEET: return [200, 200]
	return [120, 120]


# 各类控件默认最小尺寸（默认等于尺寸，保证文字/图标不被裁剪）
static func _default_min_size(type: String) -> Array:
	return _default_size(type)


# 各类控件默认样式字典（仅包含该类型用得到的字段）
static func _default_style(type: String) -> Dictionary:
	match type:
		TYPE_LABEL:
			return {
				"text": "文字",
				"font_size": 24,
				"color": [1.0, 1.0, 1.0, 1.0],
				"horizontal_alignment": 1,   # HORIZONTAL_ALIGNMENT_CENTER
				"vertical_alignment": 1,      # VERTICAL_ALIGNMENT_CENTER
				"font_path": ""
			}
		TYPE_TEXTURE:
			return {
				"texture_path": "",
				"modulate_alpha": 1.0,
				"stretch_mode": 0             # TextureRect.STRETCH_SCALE_ON_EXPAND
			}
		TYPE_BUTTON:
			return {
				"button_text": "按钮",
				"icon_path": "",
				"bg_path": "",
				"font_path": "",
				"font_size": 22,
				"color": [1.0, 1.0, 1.0, 1.0],
				# 纯色底板（新增，可沉淀项目色板）：有 bg_path 时优先纹理底板，否则用纯色
				"bg_color": [0.17, 0.37, 0.32, 1.0],       # 青黛主色 #2C5F52
				"border_color": [0.78, 0.66, 0.42, 1.0],   # 暗金 #C8A86A
				"border_width": 2,
				"corner_radius": 8,
				# 九宫格（nine-patch）：底板图按四边边距切分九区，缩放时四角不动、仅中间拉伸
				"bg_nine_patch": true,
				"bg_margin_left": 0,
				"bg_margin_top": 0,
				"bg_margin_right": 0,
				"bg_margin_bottom": 0,
				"bg_axis_h": 0,   # 0=拉伸 1=平铺 2=平铺适配
				"bg_axis_v": 0
			}
		TYPE_PANEL:
			return {
				"bg_color": [0.12, 0.18, 0.16, 1.0],
				"border_color": [0.72, 0.67, 0.35, 1.0],
				"border_width": 2,
				"corner_radius": 8,
				# 可选纹理底板（九宫格）：设置 bg_path 后改用纹理边框，未设置则仍是纯色面板
				"bg_path": "",
				"bg_nine_patch": true,
				"bg_margin_left": 0,
				"bg_margin_top": 0,
				"bg_margin_right": 0,
				"bg_margin_bottom": 0,
				"bg_axis_h": 0,
				"bg_axis_v": 0
			}
		TYPE_ANIMATED:
			return {
				"frames": [],               # 帧纹理路径列表（res://），按顺序播放
				"fps": 8.0,                 # 帧率
				"loop": true,               # 是否循环（AnimatedTexture 运行时始终循环，字段保留用于语义/后续扩展）
				"stretch_mode": 0,          # 复用 TextureRect 的缩放模式
				"modulate_alpha": 1.0       # 整体透明度
			}
		TYPE_SPRITESHEET:
			return {
				"sheet_path": "",        # 精灵表（图集）图片路径 res://
				"hframes": 4,            # 横向切片数（列）
				"vframes": 4,            # 纵向切片数（行）
				"frame_count": 0,        # 实际帧数（0 = 用 hframes*vframes；用于非满格表）
				"fps": 8.0,              # 帧率
				"loop": true,            # 是否循环（AnimatedTexture 运行时始终循环，字段保留语义）
				"stretch_mode": 0,       # 复用 TextureRect 的缩放模式
				"modulate_alpha": 1.0    # 整体透明度
			}
	return {}


# =============================================================================
# 二、数据与节点的互转
# =============================================================================
# 依据数据字典创建一个实际的 Control 节点（含类型、基础布局、样式）。
# default_font 为“项目默认字体”，当控件自身 font_path 为空时作为回退基准字体。
static func build_control(data: Dictionary, default_font: String = "") -> Control:
	var ctrl: Control
	match data.get("type", ""):
		TYPE_TEXTURE: ctrl = TextureRect.new()
		TYPE_LABEL:   ctrl = Label.new()
		TYPE_BUTTON:  ctrl = Button.new()
		TYPE_PANEL:   ctrl = Panel.new()
		TYPE_ANIMATED: ctrl = TextureRect.new()
		TYPE_SPRITESHEET: ctrl = TextureRect.new()
		_:            ctrl = Control.new()
	ctrl.name = data.get("name", "Control")
	TaixuanUIData.apply_base(ctrl, data)
	TaixuanUIData.apply_style(ctrl, data, default_font)
	return ctrl


# 应用“基础属性”：名称、坐标、尺寸、最小尺寸、Z层级、锚点预设
static func apply_base(ctrl: Control, data: Dictionary) -> void:
	ctrl.name = data.get("name", ctrl.name)
	var pos: Array = data.get("position", [0, 0])
	var sz: Array = data.get("size", [0, 0])
	var mn: Array = data.get("min_size", [0, 0])
	ctrl.position = Vector2(float(pos[0]), float(pos[1]))
	ctrl.size = Vector2(float(sz[0]), float(sz[1]))
	ctrl.custom_minimum_size = Vector2(float(mn[0]), float(mn[1]))
	ctrl.z_index = int(data.get("z_index", 0))
	ctrl.set_anchors_preset(int(data.get("anchor_preset", 0)))
	# 保证控件自身不被裁剪（父类已设置最小尺寸）
	ctrl.clip_contents = false


# 应用“样式属性”：按控件类型分别处理
# default_font：项目默认字体路径，控件自身 font_path 为空时回退使用（真实字体预览关键）
static func apply_style(ctrl: Control, data: Dictionary, default_font: String = "") -> void:
	var s: Dictionary = data.get("style", {})
	match data.get("type", ""):
		TYPE_LABEL:
			var lbl: Label = ctrl
			lbl.text = str(s.get("text", ""))
			lbl.horizontal_alignment = int(s.get("horizontal_alignment", 1))
			lbl.vertical_alignment = int(s.get("vertical_alignment", 1))
			lbl.add_theme_font_size_override("font_size", int(s.get("font_size", 24)))
			lbl.add_theme_color_override("font_color", _arr_to_color(s.get("color", [1, 1, 1, 1])))
			var fp: String = s.get("font_path", "")
			if fp == "":
				fp = default_font
			if fp != "" and ResourceLoader.exists(fp):
				var fnt = load(fp)
				if fnt is Font:
					lbl.add_theme_font_override("font", fnt)
		TYPE_TEXTURE:
			var tr: TextureRect = ctrl
			var tp: String = s.get("texture_path", "")
			if tp != "" and ResourceLoader.exists(tp):
				tr.texture = load(tp)
			# 绝对尺寸驱动纹理：忽略节点尺寸约束，由 stretch_mode 决定填充方式
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = int(s.get("stretch_mode", 0))
			var a: float = float(s.get("modulate_alpha", 1.0))
			tr.modulate = Color(1, 1, 1, a)
		TYPE_BUTTON:
			var btn: Button = ctrl
			btn.text = str(s.get("button_text", "按钮"))
			btn.add_theme_font_size_override("font_size", int(s.get("font_size", 22)))
			btn.add_theme_color_override("font_color", _arr_to_color(s.get("color", [1, 1, 1, 1])))
			var fp: String = s.get("font_path", "")
			if fp == "":
				fp = default_font
			if fp != "" and ResourceLoader.exists(fp):
				var fnt = load(fp)
				if fnt is Font:
					btn.add_theme_font_override("font", fnt)
			var ip: String = s.get("icon_path", "")
			if ip != "" and ResourceLoader.exists(ip):
				var ic = load(ip)
				if ic is Texture2D:
					btn.icon = ic
			var bp: String = s.get("bg_path", "")
			if bp != "" and ResourceLoader.exists(bp):
				var sb_tex: StyleBoxTexture = StyleBoxTexture.new()
				sb_tex.texture = load(bp)
				_apply_nine_patch(sb_tex, s)
				# 普通/悬停/按下都使用同一底板图，避免状态切换时露底色
				btn.add_theme_stylebox_override("normal", sb_tex)
				btn.add_theme_stylebox_override("hover", sb_tex)
				btn.add_theme_stylebox_override("pressed", sb_tex)
			elif s.has("bg_color"):
				# 纯色底板（无纹理时）：直接沉淀项目色板，hover/pressed 同色避免露底色
				var sb_flat: StyleBoxFlat = StyleBoxFlat.new()
				sb_flat.bg_color = _arr_to_color(s.get("bg_color", [0.17, 0.37, 0.32, 1.0]))
				if int(s.get("border_width", 0)) > 0:
					sb_flat.border_color = _arr_to_color(s.get("border_color", [0.78, 0.66, 0.42, 1.0]))
					var bw: int = int(s.get("border_width", 2))
					sb_flat.border_width_left = bw
					sb_flat.border_width_right = bw
					sb_flat.border_width_top = bw
					sb_flat.border_width_bottom = bw
				var cr: int = int(s.get("corner_radius", 8))
				sb_flat.corner_radius_top_left = cr
				sb_flat.corner_radius_top_right = cr
				sb_flat.corner_radius_bottom_left = cr
				sb_flat.corner_radius_bottom_right = cr
				btn.add_theme_stylebox_override("normal", sb_flat)
				btn.add_theme_stylebox_override("hover", sb_flat)
				btn.add_theme_stylebox_override("pressed", sb_flat)
		TYPE_PANEL:
			var pnl: Panel = ctrl
			var bp: String = s.get("bg_path", "")
			if bp != "" and ResourceLoader.exists(bp):
				# 纹理底板：走九宫格 StyleBoxTexture（适合带边框/纹理的面板）
				var sb: StyleBoxTexture = StyleBoxTexture.new()
				sb.texture = load(bp)
				_apply_nine_patch(sb, s)
				pnl.add_theme_stylebox_override("panel", sb)
			else:
				# 纯色面板：保持原有 StyleBoxFlat 行为
				var sb: StyleBoxFlat = StyleBoxFlat.new()
				sb.bg_color = _arr_to_color(s.get("bg_color", [0.12, 0.18, 0.16, 1.0]))
				sb.border_color = _arr_to_color(s.get("border_color", [0.72, 0.67, 0.35, 1.0]))
				var bw: int = int(s.get("border_width", 2))
				sb.border_width_left = bw
				sb.border_width_right = bw
				sb.border_width_top = bw
				sb.border_width_bottom = bw
				var cr: int = int(s.get("corner_radius", 8))
				sb.corner_radius_top_left = cr
				sb.corner_radius_top_right = cr
				sb.corner_radius_bottom_left = cr
				sb.corner_radius_bottom_right = cr
				pnl.add_theme_stylebox_override("panel", sb)
		TYPE_ANIMATED:
			var tr: TextureRect = ctrl
			var frames: Array = s.get("frames", [])
			var valid: Array = []
			for fp in frames:
				if fp != "" and ResourceLoader.exists(fp):
					var tx = load(fp)
					if tx is Texture2D:
						valid.append(tx)
			if valid.size() == 1:
				tr.texture = valid[0]
			elif valid.size() > 1:
				# 多帧：构造 AnimatedTexture，赋值后由引擎按时间自动播放（无需 Timer）
				var at: AnimatedTexture = AnimatedTexture.new()
				at.frames = valid.size()
				at.fps = float(s.get("fps", 8.0))
				for i in range(valid.size()):
					at.set_frame_texture(i, valid[i])
				tr.texture = at
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = int(s.get("stretch_mode", 0))
			var a: float = float(s.get("modulate_alpha", 1.0))
			tr.modulate = Color(1, 1, 1, a)
		TYPE_SPRITESHEET:
			var sr: TextureRect = ctrl
			var sp: String = s.get("sheet_path", "")
			if sp != "" and ResourceLoader.exists(sp):
				var sheet = load(sp)
				if sheet is Texture2D:
					var sw: float = float(sheet.get_width())
					var sh: float = float(sheet.get_height())
					var hf: int = int(s.get("hframes", 4))
					var vf: int = int(s.get("vframes", 4))
					hf = max(1, hf); vf = max(1, vf)
					var fw: float = sw / float(hf)
					var fh: float = sh / float(vf)
					var total: int = hf * vf
					var fc: int = int(s.get("frame_count", 0))
					if fc > 0:
						total = min(fc, total)
					if total == 1:
						# 单帧：退化为整图（不浪费 AnimatedTexture）
						sr.texture = sheet
					else:
						var at: AnimatedTexture = AnimatedTexture.new()
						at.frames = total
						at.fps = float(s.get("fps", 8.0))
						var idx: int = 0
						for r in range(vf):
							for c in range(hf):
								if idx >= total:
									break
								var atl: AtlasTexture = AtlasTexture.new()
								atl.atlas = sheet
								atl.region = Rect2(c * fw, r * fh, fw, fh)
								at.set_frame_texture(idx, atl)
								idx += 1
						sr.texture = at
					sr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					sr.stretch_mode = int(s.get("stretch_mode", 0))
					var sa: float = float(s.get("modulate_alpha", 1.0))
					sr.modulate = Color(1, 1, 1, sa)


# 将九宫格参数写入 StyleBoxTexture 实例（预览与运行时共用）。
# bg_nine_patch=false 时退化为整图拉伸（与旧行为一致）；
# 边距为 0 时四角区塌缩，等价于整图缩放，保证旧工程向后兼容。
static func _apply_nine_patch(sb: StyleBoxTexture, s: Dictionary) -> void:
	sb.nine_patch_stretch = bool(s.get("bg_nine_patch", true))
	sb.margin_left = float(s.get("bg_margin_left", 0))
	sb.margin_top = float(s.get("bg_margin_top", 0))
	sb.margin_right = float(s.get("bg_margin_right", 0))
	sb.margin_bottom = float(s.get("bg_margin_bottom", 0))
	sb.axis_stretch_horizontal = int(s.get("bg_axis_h", 0))
	sb.axis_stretch_vertical = int(s.get("bg_axis_v", 0))


# =============================================================================
# 三、文档构造与序列化
# =============================================================================
# 构造标准“工程文档”字典（canvas + reference_image + controls）。
# 这是保存与导出的共同数据源。
static func build_doc(canvas_w: int, canvas_h: int, bg_color: Color,
		ref_image: Dictionary, controls: Array, default_font: String = "") -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"generator": GENERATOR_NAME,
		"canvas": {
			"width": canvas_w,
			"height": canvas_h,
			"background_color": _color_to_arr(bg_color)
		},
		"default_font": default_font,
		"reference_image": ref_image,
		"controls": controls
	}


# 默认基准图配置
static func default_reference() -> Dictionary:
	return {
		"path": "",
		"opacity": 1.0,
		"locked": false,
		"visible": true,
		"fit": "contain"          # contain / cover / origin
	}


# 保存工程文件（.taixuan_ui）。在文档外包裹 format/version/editor 临时态。
static func save_project(path: String, doc: Dictionary, editor_meta: Dictionary) -> bool:
	var full: Dictionary = {
		"format": "taixuan_ui",
		"version": FORMAT_VERSION,
		"doc": doc,
		"editor": editor_meta
	}
	return _write_json(path, full)


# 打开工程文件（.taixuan_ui），返回 {doc, editor}；失败返回 {}。
static func load_project(path: String) -> Dictionary:
	var txt: String = _read_text(path)
	if txt == "":
		return {}
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("太玄UI编辑器：JSON 解析失败 %s" % path)
		return {}
	var doc: Dictionary = parsed.get("doc", parsed)
	var ed: Dictionary = parsed.get("editor", {})
	return {"doc": doc, "editor": ed}


# 导出规范 JSON（仅含 canvas/reference_image/controls，供 AI 解析生成 .tscn）。
static func export_json(path: String, doc: Dictionary) -> bool:
	var out: Dictionary = doc.duplicate(true)
	out["generator"] = GENERATOR_NAME
	out["version"] = FORMAT_VERSION
	return _write_json(path, out)


# ------------------------- JSON 读写底层 -------------------------
static func _write_json(path: String, data: Dictionary) -> bool:
	var json: String = JSON.stringify(data, "\t", false)
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("太玄UI编辑器：无法写入文件 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(json)
	f.close()
	return true


static func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("太玄UI编辑器：文件不存在 %s" % path)
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt: String = f.get_as_text()
	f.close()
	return txt


# ------------------------- 颜色互转 -------------------------
static func _arr_to_color(arr: Array) -> Color:
	if arr.size() >= 4:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
	if arr.size() >= 3:
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
	return Color(1, 1, 1, 1)


static func _color_to_arr(c: Color) -> Array:
	return [c.r, c.g, c.b, c.a]


# =============================================================================
# 六、导出 Godot 原生场景文件（.tscn）
# =============================================================================
# 将标准文档字典直接生成 Godot 4 可打开的 .tscn 场景。
# 节点类型、绝对坐标、锚点、主题覆盖、资源引用与编辑器预览一一对应，
# 导入 Godot 实机后视觉零偏差（根节点固定为设计画布尺寸）。
#
# 关键一致性保证：
#   - 控件锚点采用精确 anchor_* + offset_* 写法（非 anchors_preset 便捷属性），
#     避免 Godot 加载时重算 offset 导致错位。
#   - offset 按“相对锚点的像素偏移”换算：offset = 视觉坐标 - anchor * 父尺寸，
#     父尺寸即画布尺寸，与编辑器预览的渲染基准完全一致。
# =============================================================================
static func export_tscn(path: String, doc: Dictionary) -> bool:
	var canvas: Dictionary = doc.get("canvas", {})
	var cw: int = int(canvas.get("width", DEFAULT_CANVAS_W))
	var ch: int = int(canvas.get("height", DEFAULT_CANVAS_H))
	var bg: Array = canvas.get("background_color", [0.0, 0.0, 0.0, 0.0])
	var controls: Array = doc.get("controls", [])
	var df: String = doc.get("default_font", "")   # 项目默认字体（回退基准）

	# ---- 收集外部资源（纹理/字体），去重并分配 id ----
	var res_order: Array = []           # path 列表（顺序即 id 顺序）
	var res_id_of: Dictionary = {}      # path -> id 字符串
	var res_type_of: Dictionary = {}    # path -> "Texture2D"/"FontFile"
	var ridx: int = 1
	for ci in controls:
		var s: Dictionary = ci.get("style", {})
		var t: String = ci.get("type", "")
		var paths: Array = []
		if t == TYPE_TEXTURE:
			paths.append(s.get("texture_path", ""))
		elif t == TYPE_BUTTON:
			paths.append(s.get("icon_path", ""))
			paths.append(s.get("bg_path", ""))
		elif t == TYPE_PANEL:
			paths.append(s.get("bg_path", ""))
		elif t == TYPE_ANIMATED:
			for fp in s.get("frames", []):
				paths.append(fp)
		elif t == TYPE_SPRITESHEET:
			paths.append(s.get("sheet_path", ""))
		# 字体：Label/Button 优先自身 font_path，否则回退项目默认字体
		if t == TYPE_LABEL or t == TYPE_BUTTON:
			var fp: String = s.get("font_path", "")
			if fp == "":
				fp = df
			paths.append(fp)
		else:
			paths.append(s.get("font_path", ""))
		for p in paths:
			if p != "" and not res_id_of.has(p):
				res_id_of[p] = str(ridx)
				res_type_of[p] = _res_type_of(p)
				res_order.append(p)
				ridx += 1

	# ---- 子资源（StyleBoxFlat / StyleBoxTexture）----
	var subs: PackedStringArray = []
	var sub_id: int = 1

	# ---- 节点段 ----
	var nodes: PackedStringArray = []

	# 根节点：固定设计画布尺寸（layout_mode=3 不受父容器约束）
	nodes.append("[node name=\"UI\" type=\"Control\"]")
	nodes.append("layout_mode = 3")
	nodes.append("offset_left = 0")
	nodes.append("offset_top = 0")
	nodes.append("offset_right = %d" % cw)
	nodes.append("offset_bottom = %d" % ch)

	# 背景色（透明则跳过，保留根节点透明）
	if bg.size() >= 4 and bg[3] > 0.0:
		nodes.append("[node name=\"BgColor\" type=\"ColorRect\" parent=\".\"]")
		nodes.append("layout_mode = 1")
		nodes.append("anchors_preset = 15")
		nodes.append("offset_left = 0")
		nodes.append("offset_top = 0")
		nodes.append("offset_right = %d" % cw)
		nodes.append("offset_bottom = %d" % ch)
		nodes.append("color = Color(%s, %s, %s, %s)" % [_f(bg[0]), _f(bg[1]), _f(bg[2]), _f(bg[3])])

	# 基准图（作为最底参考层）
	var ref: Variant = doc.get("reference_image", {})
	if typeof(ref) == TYPE_DICTIONARY and ref.get("path", "") != "":
		var rpath: String = str(ref["path"])
		var rid: String = res_id_of.get(rpath, "")
		if rid != "":
			nodes.append("[node name=\"Reference\" type=\"TextureRect\" parent=\".\"]")
			nodes.append("layout_mode = 1")
			nodes.append("anchors_preset = 15")
			nodes.append("offset_left = 0")
			nodes.append("offset_top = 0")
			nodes.append("offset_right = %d" % cw)
			nodes.append("offset_bottom = %d" % ch)
			nodes.append("texture = ExtResource(\"%s\")" % rid)
			nodes.append("expand_mode = 1")
			nodes.append("stretch_mode = 0")
			var op: float = float(ref.get("opacity", 1.0))
			nodes.append("modulate = Color(1, 1, 1, %s)" % _f(op))
			if not bool(ref.get("visible", true)):
				nodes.append("visible = false")

	# 各控件
	for cj in controls:
		var t: String = cj.get("type", "")
		var nm: String = str(cj.get("name", "Node"))
		var pos: Array = cj.get("position", [0, 0])
		var sz: Array = cj.get("size", [0, 0])
		var mn: Array = cj.get("min_size", [0, 0])
		var z: int = int(cj.get("z_index", 0))
		var preset: int = int(cj.get("anchor_preset", 0))
		var s: Dictionary = cj.get("style", {})
		var x: float = float(pos[0]); var y: float = float(pos[1])
		var w: float = float(sz[0]); var h: float = float(sz[1])
		var node_type: String = t
		if t == TYPE_ANIMATED:
			node_type = "TextureRect"   # AnimatedTexture 是纹理，挂在 TextureRect 上自动播放
		elif t == TYPE_SPRITESHEET:
			node_type = "TextureRect"   # 切片后的 AtlasTexture 帧组合同理挂在 TextureRect 上自动播放
		nodes.append("[node name=\"%s\" type=\"%s\" parent=\".\"]" % [nm, node_type])
		nodes.append("layout_mode = 1")
		var anch: Array = _preset_anchors(preset)
		nodes.append("anchor_left = %s" % _f(anch[0]))
		nodes.append("anchor_top = %s" % _f(anch[1]))
		nodes.append("anchor_right = %s" % _f(anch[2]))
		nodes.append("anchor_bottom = %s" % _f(anch[3]))
		nodes.append("offset_left = %s" % _f(x - anch[0] * cw))
		nodes.append("offset_top = %s" % _f(y - anch[1] * ch))
		nodes.append("offset_right = %s" % _f((x + w) - anch[2] * cw))
		nodes.append("offset_bottom = %s" % _f((y + h) - anch[3] * ch))
		if mn[0] != 0 or mn[1] != 0:
			nodes.append("custom_minimum_size = Vector2(%s, %s)" % [_f(float(mn[0])), _f(float(mn[1]))])
		if z != 0:
			nodes.append("z_index = %d" % z)
		match t:
			TYPE_LABEL:
				nodes.append("text = \"%s\"" % _esc(str(s.get("text", ""))))
				nodes.append("horizontal_alignment = %d" % int(s.get("horizontal_alignment", 1)))
				nodes.append("vertical_alignment = %d" % int(s.get("vertical_alignment", 1)))
				nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 24)))
				var col: Array = s.get("color", [1, 1, 1, 1])
				nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % [_f(col[0]), _f(col[1]), _f(col[2]), _f(col[3])])
				var fp: String = s.get("font_path", "")
				if fp == "":
					fp = df
				if fp != "" and res_id_of.has(fp):
					nodes.append("theme_override_fonts/font = ExtResource(\"%s\")" % res_id_of[fp])
			TYPE_TEXTURE:
				var tp: String = s.get("texture_path", "")
				if tp != "" and res_id_of.has(tp):
					nodes.append("texture = ExtResource(\"%s\")" % res_id_of[tp])
				nodes.append("expand_mode = 1")
				nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
				var al: float = float(s.get("modulate_alpha", 1.0))
				nodes.append("modulate = Color(1, 1, 1, %s)" % _f(al))
			TYPE_BUTTON:
				nodes.append("text = \"%s\"" % _esc(str(s.get("button_text", "按钮"))))
				nodes.append("theme_override_font_sizes/font_size = %d" % int(s.get("font_size", 22)))
				var col2: Array = s.get("color", [1, 1, 1, 1])
				nodes.append("theme_override_colors/font_color = Color(%s, %s, %s, %s)" % [_f(col2[0]), _f(col2[1]), _f(col2[2]), _f(col2[3])])
				var fp2: String = s.get("font_path", "")
				if fp2 == "":
					fp2 = df
				if fp2 != "" and res_id_of.has(fp2):
					nodes.append("theme_override_fonts/font = ExtResource(\"%s\")" % res_id_of[fp2])
				var ip: String = s.get("icon_path", "")
				if ip != "" and res_id_of.has(ip):
					nodes.append("icon = ExtResource(\"%s\")" % res_id_of[ip])
				var bp: String = s.get("bg_path", "")
				if bp != "" and res_id_of.has(bp):
					var sid: String = "StyleBoxTexture_%d" % sub_id; sub_id += 1
					subs.append("[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % sid)
					subs.append("texture = ExtResource(\"%s\")" % res_id_of[bp])
					_emit_nine_patch(subs, s)
					nodes.append("theme_override_styles/normal = SubResource(\"%s\")" % sid)
					nodes.append("theme_override_styles/hover = SubResource(\"%s\")" % sid)
					nodes.append("theme_override_styles/pressed = SubResource(\"%s\")" % sid)
			TYPE_PANEL:
				var bp2: String = s.get("bg_path", "")
				if bp2 != "" and res_id_of.has(bp2):
					# 纹理底板：九宫格 StyleBoxTexture
					var sid2: String = "StyleBoxTexture_%d" % sub_id; sub_id += 1
					subs.append("[sub_resource type=\"StyleBoxTexture\" id=\"%s\"]" % sid2)
					subs.append("texture = ExtResource(\"%s\")" % res_id_of[bp2])
					_emit_nine_patch(subs, s)
					nodes.append("theme_override_styles/panel = SubResource(\"%s\")" % sid2)
				else:
					# 纯色面板：StyleBoxFlat（原有行为）
					var sid2: String = "StyleBoxFlat_%d" % sub_id; sub_id += 1
					subs.append("[sub_resource type=\"StyleBoxFlat\" id=\"%s\"]" % sid2)
					var bc: Array = s.get("bg_color", [0.12, 0.18, 0.16, 1])
					var bc2: Array = s.get("border_color", [0.72, 0.67, 0.35, 1])
					var bw: int = int(s.get("border_width", 2))
					var cr: int = int(s.get("corner_radius", 8))
					subs.append("bg_color = Color(%s, %s, %s, %s)" % [_f(bc[0]), _f(bc[1]), _f(bc[2]), _f(bc[3])])
					subs.append("border_color = Color(%s, %s, %s, %s)" % [_f(bc2[0]), _f(bc2[1]), _f(bc2[2]), _f(bc2[3])])
					subs.append("border_width_left = %d" % bw)
					subs.append("border_width_top = %d" % bw)
					subs.append("border_width_right = %d" % bw)
					subs.append("border_width_bottom = %d" % bw)
					subs.append("corner_radius_top_left = %d" % cr)
					subs.append("corner_radius_top_right = %d" % cr)
					subs.append("corner_radius_bottom_left = %d" % cr)
					subs.append("corner_radius_bottom_right = %d" % cr)
					nodes.append("theme_override_styles/panel = SubResource(\"%s\")" % sid2)
			TYPE_ANIMATED:
				var fr: Array = s.get("frames", [])
				var valid_fr: Array = []
				for fp_v2 in fr:
					if fp_v2 != "" and res_id_of.has(fp_v2):
						valid_fr.append(fp_v2)
				if valid_fr.size() >= 2:
					# 多帧：生成 AnimatedTexture 子资源（实机自动播放）
					var asid: String = "AnimatedTexture_%d" % sub_id; sub_id += 1
					subs.append("[sub_resource type=\"AnimatedTexture\" id=\"%s\"]" % asid)
					subs.append("fps = %s" % _f(float(s.get("fps", 8.0))))
					subs.append("frames = %d" % valid_fr.size())
					for i in range(valid_fr.size()):
						subs.append("frame_%d/texture = ExtResource(\"%s\")" % [i, res_id_of[valid_fr[i]]])
					nodes.append("texture = SubResource(\"%s\")" % asid)
				elif valid_fr.size() == 1:
					nodes.append("texture = ExtResource(\"%s\")" % res_id_of[valid_fr[0]])
				nodes.append("expand_mode = 1")
				nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
				var al2: float = float(s.get("modulate_alpha", 1.0))
				nodes.append("modulate = Color(1, 1, 1, %s)" % _f(al2))
			TYPE_SPRITESHEET:
				var shp: String = s.get("sheet_path", "")
				if shp != "" and res_id_of.has(shp):
					var sw: float = 0.0; var shh: float = 0.0
					if ResourceLoader.exists(shp):
						var sheet = load(shp)
						if sheet is Texture2D:
							sw = float(sheet.get_width()); shh = float(sheet.get_height())
					var hf: int = max(1, int(s.get("hframes", 4)))
					var vf: int = max(1, int(s.get("vframes", 4)))
					var fw: float = sw / float(hf)
					var fh: float = shh / float(vf)
					var total: int = hf * vf
					var fc: int = int(s.get("frame_count", 0))
					if fc > 0:
						total = min(fc, total)
					if total <= 1:
						# 单帧：退化为整图
						nodes.append("texture = ExtResource(\"%s\")" % res_id_of[shp])
					else:
						var atid: String = "AnimatedTexture_%d" % sub_id; sub_id += 1
						subs.append("[sub_resource type=\"AnimatedTexture\" id=\"%s\"]" % atid)
						subs.append("fps = %s" % _f(float(s.get("fps", 8.0))))
						subs.append("frames = %d" % total)
						var idx: int = 0
						for r in range(vf):
							for col in range(hf):
								if idx >= total:
									break
								var asid: String = "AtlasTexture_%d" % sub_id; sub_id += 1
								subs.append("[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % asid)
								subs.append("atlas = ExtResource(\"%s\")" % res_id_of[shp])
								subs.append("region = Rect2(%s, %s, %s, %s)" % [_f(col * fw), _f(r * fh), _f(fw), _f(fh)])
								subs.append("frame_%d/texture = SubResource(\"%s\")" % [idx, asid])
								idx += 1
						nodes.append("texture = SubResource(\"%s\")" % atid)
					nodes.append("expand_mode = 1")
					nodes.append("stretch_mode = %d" % int(s.get("stretch_mode", 0)))
					var sla: float = float(s.get("modulate_alpha", 1.0))
					nodes.append("modulate = Color(1, 1, 1, %s)" % _f(sla))

	# ---- 组装文件 ----
	# load_steps = 1(场景本身) + 外部资源数 + 子资源个数（按“资源对象数”计，非行数，
	# 避免数值虚高；Godot 对该值仅作载入进度提示，过高不影响解析，过低才报错）。
	var sub_count: int = sub_id - 1
	var load_steps: int = 1 + res_order.size() + sub_count
	var out: PackedStringArray = []
	out.append("[gd_scene load_steps=%d format=3]" % load_steps)
	for p_v2 in res_order:
		out.append("[ext_resource type=\"%s\" path=\"%s\" id=\"%s\"]" % [res_type_of[p_v2], p_v2, res_id_of[p_v2]])
	for sline in subs:
		out.append(sline)
	for nline in nodes:
		out.append(nline)
	out.append("")
	return _write_text(path, "\n".join(out))


# 导出独立 SpriteFrames 资源（.tres），可直接赋给 AnimatedSprite2D 的 sprites 属性，
# 用于弟子战斗帧等内容场景（与 UI 编辑器内的 TextureRect+AnimatedTexture 双轨并存）。
static func export_spritesheet_tres(out_path: String, sheet_path: String,
		hframes: int, vframes: int, fps: float, loop: bool, frame_count: int = 0) -> bool:
	if sheet_path == "" or not ResourceLoader.exists(sheet_path):
		push_error("太玄UI编辑器：精灵表路径无效 %s" % sheet_path)
		return false
	var sheet = load(sheet_path)
	if not (sheet is Texture2D):
		return false
	var sw: float = float(sheet.get_width())
	var sh: float = float(sheet.get_height())
	var hf: int = max(1, hframes); var vf: int = max(1, vframes)
	var fw: float = sw / float(hf); var fh: float = sh / float(vf)
	var total: int = hf * vf
	if frame_count > 0:
		total = min(frame_count, total)
	var dur: float = 1.0 / max(0.001, fps)
	var lines: PackedStringArray = []
	lines.append("[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (2 + total * 2))
	lines.append("")
	lines.append("[ext_resource type=\"Texture2D\" path=\"%s\" id=\"1\"]" % sheet_path)
	lines.append("")
	var sf_ids: PackedStringArray = []
	var idx: int = 0
	for r in range(vf):
		for c in range(hf):
			if idx >= total:
				break
			var aid: String = "AtlasTexture_%d" % (idx + 1)
			var sid: String = "SpriteFrame_%d" % (idx + 1)
			lines.append("[sub_resource type=\"AtlasTexture\" id=\"%s\"]" % aid)
			lines.append("atlas = ExtResource(\"1\")")
			lines.append("region = Rect2(%s, %s, %s, %s)" % [_f(c * fw), _f(r * fh), _f(fw), _f(fh)])
			lines.append("")
			lines.append("[sub_resource type=\"SpriteFrame\" id=\"%s\"]" % sid)
			lines.append("texture = SubResource(\"%s\")" % aid)
			lines.append("duration = %s" % _f(dur))
			lines.append("")
			sf_ids.append(sid)
			idx += 1
	var fr_refs: String = ""
	for sid in sf_ids:
		if fr_refs != "":
			fr_refs += ", "
		fr_refs += "SubResource(\"%s\")" % sid
	lines.append("[resource]")
	lines.append("animations = [{")
	lines.append("\"frames\": [%s]," % fr_refs)
	lines.append("\"loop\": %s," % ("true" if loop else "false"))
	lines.append("\"name\": \"default\",")
	lines.append("\"speed\": %s" % _f(fps))
	lines.append("}]")
	lines.append("")
	return _write_text(out_path, "\n".join(lines))


# 资源类型推断（按扩展名）
static func _res_type_of(path: String) -> String:
	var ext: String = path.get_extension().to_lower()
	if ext in ["ttf", "otf", "font"]:
		return "FontFile"
	return "Texture2D"


# 向 sub_resource 段写入九宫格参数（与 _apply_nine_patch 一一对应）。
# 边距 0 + nine_patch_stretch=true 等价于整图拉伸，旧工程向后兼容。
static func _emit_nine_patch(subs: PackedStringArray, s: Dictionary) -> void:
	subs.append("nine_patch_stretch = %s" % ("true" if bool(s.get("bg_nine_patch", true)) else "false"))
	subs.append("margin_left = %s" % _f(float(s.get("bg_margin_left", 0))))
	subs.append("margin_top = %s" % _f(float(s.get("bg_margin_top", 0))))
	subs.append("margin_right = %s" % _f(float(s.get("bg_margin_right", 0))))
	subs.append("margin_bottom = %s" % _f(float(s.get("bg_margin_bottom", 0))))
	subs.append("axis_stretch_horizontal = %d" % int(s.get("bg_axis_h", 0)))
	subs.append("axis_stretch_vertical = %d" % int(s.get("bg_axis_v", 0)))


# 锚点预设 → [anchor_left, anchor_top, anchor_right, anchor_bottom]
static func _preset_anchors(preset: int) -> Array:
	match preset:
		0:  return [0.0, 0.0, 0.0, 0.0]      # TOP_LEFT
		1:  return [1.0, 0.0, 1.0, 0.0]      # TOP_RIGHT
		2:  return [0.0, 1.0, 0.0, 1.0]      # BOTTOM_LEFT
		3:  return [1.0, 1.0, 1.0, 1.0]      # BOTTOM_RIGHT
		4:  return [0.0, 0.5, 0.0, 0.5]      # CENTER_LEFT
		5:  return [1.0, 0.5, 1.0, 0.5]      # CENTER_RIGHT
		6:  return [0.5, 0.0, 0.5, 0.0]      # CENTER_TOP
		7:  return [0.5, 1.0, 0.5, 1.0]      # CENTER_BOTTOM
		8:  return [0.5, 0.5, 0.5, 0.5]      # CENTER
		9:  return [0.0, 0.0, 0.0, 1.0]      # LEFT_WIDE
		10: return [0.0, 0.0, 1.0, 0.0]      # TOP_WIDE
		11: return [1.0, 0.0, 1.0, 1.0]      # RIGHT_WIDE
		12: return [0.0, 1.0, 1.0, 1.0]      # BOTTOM_WIDE
		13: return [0.5, 0.0, 0.5, 1.0]      # VCENTER_WIDE
		14: return [0.0, 0.5, 1.0, 0.5]      # HCENTER_WIDE
		15: return [0.0, 0.0, 1.0, 1.0]      # FULL_RECT
		_:  return [0.0, 0.0, 0.0, 0.0]


# 浮点格式化：去尾零，保留 3 位精度
static func _f(v: float) -> String:
	var s: String = "%.3f" % v
	while s.length() > 1 and s.ends_with("0") and s[s.length() - 2] != ".":
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s += "0"
	return s


# 字符串转义（.tscn 文本字符串用双引号包裹）
static func _esc(s: String) -> String:
	return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\t", "\\t")


# 文本文件写出（复用错误提示风格）
static func _write_text(path: String, txt: String) -> bool:
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("太玄UI编辑器：无法写入文件 %s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	f.store_string(txt)
	f.close()
	return true


# =============================================================================
# 七、可复用模板库（控件样式模板 / 页面布局模板）
# =============================================================================
# 模板让编辑器沉淀项目 UI 规范：常用控件样式、整页布局可保存为一键复用。
# 存储：.tuit（JSON）文件
#   - 内置模板目录（随插件发布，只读）：res://addons/taixuan_ui_editor/templates
#   - 用户模板目录（项目级，可保存/删除）：res://ui_editor_templates
# 模板结构：
#   style  : {"kind":"style","type":<TYPE>,"name":<str>,"style":{...}}
#   layout : {"kind":"layout","name":<str>,"canvas":{...},"controls":[...]}

const BUILTIN_TEMPLATE_DIR: String = "res://addons/taixuan_ui_editor/templates"
const USER_TEMPLATE_DIR: String = "res://ui_editor_templates"

# 确保目录存在（用户目录首次保存时创建）
static func ensure_template_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


# 列出全部模板（内置 + 用户），返回元信息数组
# 每项：{"path":..., "kind":"style"/"layout", "type":..., "name":..., "source":"builtin"/"user"}
static func list_templates() -> Array:
	var out: Array = []
	var dirs: Array = [BUILTIN_TEMPLATE_DIR, USER_TEMPLATE_DIR]
	var sources: Array = ["builtin", "user"]
	for di in range(dirs.size()):
		var dir: String = dirs[di]
		ensure_template_dir(dir)
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var files: PackedStringArray = DirAccess.get_files_at(dir)
		for fl in files:
			if fl.get_extension().to_lower() != "tuit":
				continue
			var full: String = dir.path_join(fl)
			var t: Dictionary = load_template(full)
			if t.is_empty():
				continue
			out.append({
				"path": full,
				"kind": t.get("kind", ""),
				"type": t.get("type", ""),
				"name": t.get("name", fl.get_basename()),
				"source": sources[di]
			})
	return out


# 保存控件样式模板（仅存 style 字典 + 类型）
static func save_style_template(path: String, type: String, name: String, style: Dictionary) -> bool:
	var d: Dictionary = {
		"kind": "style",
		"type": type,
		"name": name,
		"style": style.duplicate(true)
	}
	return _write_json(path, d)


# 保存页面布局模板（存 canvas + controls，不含基准图）
static func save_layout_template(path: String, name: String, canvas: Dictionary, controls: Array) -> bool:
	var d: Dictionary = {
		"kind": "layout",
		"name": name,
		"canvas": canvas.duplicate(true),
		"controls": controls.duplicate(true)
	}
	return _write_json(path, d)


# 读取单个模板文件，失败返回 {}
static func load_template(path: String) -> Dictionary:
	var txt: String = _read_text(path)
	if txt == "":
		return {}
	var p = JSON.parse_string(txt)
	if typeof(p) != TYPE_DICTIONARY:
		return {}
	return p


# 删除用户模板（内置模板不应被删）
static func delete_template(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


# 首次启用：向内置目录写入示例模板（贴合项目色板，真正沉淀规范）
static func ensure_builtin_samples() -> void:
	ensure_template_dir(BUILTIN_TEMPLATE_DIR)
	# 主按钮（青黛底 + 暗金描边）
	_sample_style(BUILTIN_TEMPLATE_DIR.path_join("button_main.tuit"),
		TYPE_BUTTON, "主按钮(青黛)",
		{
			"button_text": "按钮", "icon_path": "", "bg_path": "", "font_path": "",
			"font_size": 22, "color": [1.0, 1.0, 1.0, 1.0],
			"bg_color": [0.17, 0.37, 0.32, 1.0], "border_color": [0.78, 0.66, 0.42, 1.0],
			"border_width": 2, "corner_radius": 8,
			"bg_nine_patch": true, "bg_margin_left": 0, "bg_margin_top": 0,
			"bg_margin_right": 0, "bg_margin_bottom": 0, "bg_axis_h": 0, "bg_axis_v": 0
		})
	# 玉石面板（深青玉底 + 暗金描边）
	_sample_style(BUILTIN_TEMPLATE_DIR.path_join("panel_jade.tuit"),
		TYPE_PANEL, "玉石面板",
		{
			"bg_color": [0.07, 0.13, 0.11, 1.0], "border_color": [0.78, 0.66, 0.42, 1.0],
			"border_width": 2, "corner_radius": 8,
			"bg_path": "", "bg_nine_patch": true, "bg_margin_left": 0, "bg_margin_top": 0,
			"bg_margin_right": 0, "bg_margin_bottom": 0, "bg_axis_h": 0, "bg_axis_v": 0
		})
	# 标题文字（米白、大号、居中）
	_sample_style(BUILTIN_TEMPLATE_DIR.path_join("label_title.tuit"),
		TYPE_LABEL, "标题文字(米白)",
		{
			"text": "标题", "font_size": 32, "color": [0.96, 0.94, 0.89, 1.0],
			"horizontal_alignment": 1, "vertical_alignment": 1, "font_path": ""
		})


# 仅当目标文件不存在才写入（避免覆盖用户的自定义内置同名模板）
static func _sample_style(path: String, type: String, name: String, style: Dictionary) -> void:
	if FileAccess.file_exists(path):
		return
	save_style_template(path, type, name, style)


static func _sample_layout(path: String, name: String, canvas: Dictionary, controls: Array) -> void:
	if FileAccess.file_exists(path):
		return
	save_layout_template(path, name, canvas, controls)
