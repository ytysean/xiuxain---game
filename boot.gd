extends Control
## 启动加载场景（run/main_scene = res://boot.tscn）
##
## 目的：把「main.tscn 编译装配」这段原本黑屏假死的等待，变成有品牌感的开屏页。
##       （更早的「引擎 init + 21 个 Autoload 编译」无法用 GDScript 干预，
##         由 project.godot 的 boot_splash 原生闪屏覆盖。闪屏与本场景共用同一张底图，
##         且底图不含任何文字 —— 标题由本场景以矢量真字体渲染，切换点零跳变。）
##
## 铁律：
##   1. 本脚本必须保持极轻 —— 零 preload、零跨场景引用。它自己若变重，改造即失效。
##   2. 颜色一律走 UITheme 色令牌，不写裸 Color 字面量。
##   3. 装饰件复用 UITheme.make_divider_control()（云纹细线），不自造图标。
##   4. 进度条自绘（track + fill），不用 ProgressBar —— 避免与 .tres 默认样式漂移。
##   5. 文案修真化，禁现代词。
##
## 版式基准：视口 1080 × 1920（竖屏）。

const MAIN_SCENE: String = "res://main.tscn"
const SPLASH_TEX: String = "res://art/splash/boot_splash.png"
const TITLE_FONT_PATH: String = "res://art/fonts/SourceHanSerifCN-Regular.otf"

## 卡死兜底：超过该毫秒数仍未就绪则降级为同步加载
const THREAD_TIMEOUT_MS: int = 90000

## 阶段提示（按推进顺序轮播，纯文案，无数值）
const 阶段文案: Array[String] = [
	"灵气初聚",
	"开辟山门",
	"点检殿阁",
	"召集门人",
	"演算天机",
	"山门将启",
]

# ── 版式常量（逻辑像素，视口 1080×1920）──
const 标题顶距: int = 232
const 主标题字号: int = 116
const 主标题字距: int = 18
const 副标题字号: int = 34
const 副标题字距: int = 12
const 底栏左右: int = 96
const 底栏底距: int = 78
const 底栏高: int = 118
const 进度条高: int = 3

var _bg: TextureRect
var _title_box: VBoxContainer
var _title: Label
var _ornament: Control
var _subtitle: Label
var _bottom_box: VBoxContainer
var _tip: Label
var _pct: Label
var _track: Control
var _fill: Panel

var _begin_ms: int = 0
var _tip_idx: int = 0
var _requested: bool = false
var _switched: bool = false
var _显示值: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_建背景()
	_建标题组()
	_建底栏()
	_待入场()

	_begin_ms = Time.get_ticks_msec()
	# 先让开屏页真正渲染出一帧，再去发起重活；否则首帧会被 load 吞掉，仍是黑屏
	await get_tree().process_frame
	_对齐轴心()
	_播放入场()
	_背景缓推()
	await get_tree().process_frame
	ResourceLoader.load_threaded_request(MAIN_SCENE)
	_requested = true
	set_process(true)


# ────────────────────────── 构建 ──────────────────────────

func _建背景() -> void:
	var 贴图: Texture2D = _取开屏底图()
	if 贴图 != null:
		_bg = TextureRect.new()
		_bg.texture = 贴图
		_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
	else:
		var 底 := ColorRect.new()
		底.color = UITheme.获取背景色()
		底.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		底.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(底)


## 开屏底图：正式走资源导入管线；若工程尚未导入该图（新克隆 / CI / 刚替换过图，
## 此时 ResourceLoader.exists 为 false），退回直读原图，避免整页静默退化成纯色底。
func _取开屏底图() -> Texture2D:
	if ResourceLoader.exists(SPLASH_TEX):
		return load(SPLASH_TEX) as Texture2D
	var f := FileAccess.open(SPLASH_TEX, FileAccess.READ)
	if f == null:
		return null
	var 字节 := f.get_buffer(f.get_length())
	f.close()
	var img := Image.new()
	if img.load_png_from_buffer(字节) != OK:
		return null
	push_warning("[boot] boot_splash 尚未导入，已直读原图；导出前请让编辑器完成导入")
	return ImageTexture.create_from_image(img)


func _建标题组() -> void:
	var 衬线 := _取衬线字体()

	_title_box = VBoxContainer.new()
	_title_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title_box.offset_left = 48
	_title_box.offset_right = -48
	_title_box.offset_top = 标题顶距
	_title_box.add_theme_constant_override("separation", 0)
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_box)

	_title = Label.new()
	_title.text = "太玄宗门录"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_装字体(_title, 衬线, 主标题字号, 主标题字距)
	_title.add_theme_color_override("font_color", UITheme.color_text_gold())
	_title.add_theme_color_override("font_outline_color", _暗晕(0.55))
	_title.add_theme_constant_override("outline_size", 10)
	_title_box.add_child(_title)

	_title_box.add_child(_取间隔(30))

	# 装饰：项目自带云纹细线（256×4，可无缝横铺），压窄成一枚居中的短饰
	_ornament = UITheme.make_divider_control()
	# 高度取原图高度（256×4）—— 高于 4 会让 STRETCH_TILE 纵向再铺一次，出现第二条线
	_ornament.custom_minimum_size = Vector2(340, 4)
	_ornament.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 云纹线本体只有 1.5px，满不透明度仍偏灰；提亮让它读成「亮金发丝」
	_ornament.modulate = Color(1.30, 1.22, 1.10, 1.0)
	_title_box.add_child(_ornament)

	_title_box.add_child(_取间隔(26))

	_subtitle = Label.new()
	_subtitle.text = "开局接手太玄宗"
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_装字体(_subtitle, 衬线, 副标题字号, 副标题字距)
	_subtitle.add_theme_color_override("font_color", _带透明度(UITheme.color_text_gold(), 0.70))
	_subtitle.add_theme_color_override("font_outline_color", _暗晕(0.42))
	_subtitle.add_theme_constant_override("outline_size", 6)
	_title_box.add_child(_subtitle)


func _建底栏() -> void:
	_bottom_box = VBoxContainer.new()
	_bottom_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_box.offset_left = 底栏左右
	_bottom_box.offset_right = -底栏左右
	_bottom_box.offset_top = -(底栏底距 + 底栏高)
	_bottom_box.offset_bottom = -底栏底距
	_bottom_box.add_theme_constant_override("separation", 0)
	_bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom_box)

	# 提示行：左「开辟山门」／右百分比
	var 行 := HBoxContainer.new()
	行.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_box.add_child(行)

	_tip = Label.new()
	_tip.text = 阶段文案[0]
	_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_body_font_sized(_tip, 26)
	_tip.add_theme_color_override("font_color", _带透明度(UITheme.color_text_gold(), 0.78))
	行.add_child(_tip)

	_pct = Label.new()
	_pct.text = ""
	_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct.size_flags_horizontal = Control.SIZE_SHRINK_END
	_pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_body_font_sized(_pct, 26)
	_pct.add_theme_color_override("font_color", UITheme.color_text_gold())
	行.add_child(_pct)

	_bottom_box.add_child(_取间隔(14))

	# 进度条：自绘 track + fill（不用 ProgressBar，避免与 .tres 单源样式漂移）
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 进度条高)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_box.add_child(_track)

	var 轨条 := Panel.new()
	轨条.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	轨条.add_theme_stylebox_override("panel", _圆条(_带透明度(UITheme.获取金色描边(), 0.32)))
	轨条.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_child(轨条)

	_fill = Panel.new()
	_fill.anchor_left = 0.0
	_fill.anchor_right = 0.0
	_fill.anchor_top = 0.0
	_fill.anchor_bottom = 1.0
	_fill.offset_left = 0.0
	_fill.offset_top = 0.0
	_fill.offset_right = 0.0
	_fill.offset_bottom = 0.0
	_fill.add_theme_stylebox_override("panel", _圆条(UITheme.color_text_gold()))
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.visible = false
	_track.add_child(_fill)

	_bottom_box.add_child(_取间隔(18))

	var 版本 := Label.new()
	版本.text = _版本文案()
	版本.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	版本.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_aux_font(版本)
	版本.add_theme_color_override("font_color", _带透明度(UITheme.color_text_body_dim(), 0.55))
	_bottom_box.add_child(版本)


# ────────────────────────── 入场 ──────────────────────────

func _待入场() -> void:
	_title.modulate.a = 0.0
	_ornament.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	_bottom_box.modulate.a = 0.0
	_title_box.offset_top = 标题顶距 + 30


func _对齐轴心() -> void:
	if _bg != null:
		_bg.pivot_offset = _bg.size * 0.5
	_ornament.pivot_offset = _ornament.size * 0.5
	_ornament.scale = Vector2(0.02, 1.0)


func _播放入场() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_title_box, "offset_top", float(标题顶距), 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_title, "modulate:a", 1.0, 0.85).set_delay(0.08)
	t.tween_property(_ornament, "modulate:a", 0.85, 0.60).set_delay(0.42)
	t.tween_property(_ornament, "scale:x", 1.0, 0.75).set_delay(0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_subtitle, "modulate:a", 1.0, 0.70).set_delay(0.58)
	t.tween_property(_bottom_box, "modulate:a", 1.0, 0.75).set_delay(0.85)

	# 提示文案极缓呼吸，让等待期间画面始终「活着」
	var 呼吸 := create_tween().set_loops()
	呼吸.tween_property(_tip, "modulate:a", 0.58, 1.6)
	呼吸.tween_property(_tip, "modulate:a", 1.0, 1.6)


func _背景缓推() -> void:
	if _bg == null:
		return
	_bg.scale = Vector2(1.02, 1.02)
	create_tween().tween_property(_bg, "scale", Vector2(1.10, 1.10), 16.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ────────────────────────── 加载推进 ──────────────────────────

func _process(delta: float) -> void:
	if _switched or not _requested:
		return

	var 进度: Array = []
	var 状态: int = ResourceLoader.load_threaded_get_status(MAIN_SCENE, 进度)
	var 比值: float = float(进度[0]) if 进度.size() > 0 else 0.0

	if 状态 == ResourceLoader.THREAD_LOAD_LOADED:
		_切换()
		return
	if 状态 == ResourceLoader.THREAD_LOAD_FAILED:
		push_warning("[boot] 后台加载失败，降级为同步载入")
		_降级同步载入()
		return
	if Time.get_ticks_msec() - _begin_ms > THREAD_TIMEOUT_MS:
		push_warning("[boot] 后台加载超时，降级为同步载入")
		_降级同步载入()
		return

	if 比值 > 0.0:
		# 真实进度是台阶式跳变的（实测 0→0.13→0.15 停 6s→0.25→完成），直接喂给进度条会一顿一顿。
		# 让显示值平滑逼近真实值，且只慢不超前 —— 数字仍是真的，不做时间轴猜测。
		_显示值 = minf(比值, _显示值 + delta * 0.45)
		_pct.text = "%d%%" % int(_显示值 * 100.0)
	else:
		# 首批子资源尚未上报：只留空轨，不编造百分比
		_pct.text = ""

	_更新条宽()
	_轮播文案()


func _更新条宽() -> void:
	if _fill == null or _track == null:
		return
	_fill.visible = _显示值 > 0.001
	_fill.offset_right = _track.size.x * clampf(_显示值, 0.0, 1.0)


func _轮播文案() -> void:
	var 序: int = clampi(int((Time.get_ticks_msec() - _begin_ms) / 1600), 0, 阶段文案.size() - 1)
	if 序 != _tip_idx:
		_tip_idx = 序
		_tip.text = 阶段文案[序]


func _切换() -> void:
	_switched = true
	set_process(false)
	var 包 := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
	if 包 != null:
		_显示值 = 1.0
		_更新条宽()
		_pct.text = "100%"
		_tip.text = 阶段文案[阶段文案.size() - 1]
		# 让 100% 这一帧有机会画出来，再切场景
		await get_tree().process_frame
		get_tree().change_scene_to_packed(包)
	else:
		push_error("[boot] main.tscn 加载结果不是 PackedScene，降级为同步载入")
		_降级同步载入()


func _降级同步载入() -> void:
	if _switched:
		return
	_switched = true
	set_process(false)
	await get_tree().process_frame
	get_tree().change_scene_to_file(MAIN_SCENE)


# ────────────────────────── 小工具 ──────────────────────────

func _取衬线字体() -> Font:
	if ResourceLoader.exists(TITLE_FONT_PATH):
		return load(TITLE_FONT_PATH) as Font
	return null


## 装字体：可选加字距（FontVariation.spacing_glyph）。基字体缺失时退回主题默认，不报错。
func _装字体(控件: Control, 基: Font, 字号: int, 字距: int) -> void:
	if 基 != null:
		if 字距 > 0:
			var fv := FontVariation.new()
			fv.base_font = 基
			fv.spacing_glyph = 字距
			控件.add_theme_font_override("font", fv)
		else:
			控件.add_theme_font_override("font", 基)
	控件.add_theme_font_size_override("font_size", 字号)


func _圆条(色: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = 色
	var r: int = maxi(1, 进度条高 / 2)
	sb.corner_radius_top_left = r
	sb.corner_radius_top_right = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


func _带透明度(色: Color, 透明: float) -> Color:
	var c: Color = 色
	c.a = 透明
	return c


func _暗晕(透明: float) -> Color:
	return _带透明度(UITheme.获取背景色(), 透明)


func _取间隔(高: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 高)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _版本文案() -> String:
	var v: String = str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	return "" if v == "" else "v" + v
