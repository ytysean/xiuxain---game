extends Node

## P0-3 组件库自检（headless 实机）
##
## 覆盖 compile_all 覆盖不到、但会直接导致「整页空白」的三类问题：
##   [A] 6 张 9-patch 资产能否被引擎真正加载（此前只有颜色常量引用，贴图零消费）
##   [B] StyleBoxTexture 边距是否与源图一致（错一位=拉伸时圆角变形）
##   [C] 组件工厂能否实例化并挂到真实控件树（含按钮三态/角标/九宫格图）
##   [D] 缓存是否生效（同一名字两次取必须是同一实例，否则性能红线失守）

var _fail: int = 0

const PATCH_SPEC := {
	"panel_bg": [384, 384, 48],
	"card_bg": [256, 256, 36],
	"card_row_bg": [256, 256, 36],
	"btn_fill": [384, 160, 40],
	"btn_frame": [384, 160, 40],
	"corner_tab": [64, 64, 0],
}


func _ready() -> void:
	prints("=== P0-3 组件库自检 ===")
	get_tree().create_timer(40.0).timeout.connect(_看门狗)

	_check("U0 UITheme 单例已挂载", UITheme != null)
	if UITheme == null:
		_finish()

	_资产加载()
	_边距一致()
	_组件实例化()
	_缓存生效()
	_兜底不崩()

	_finish()


# ── A. 资产真加载（不是只有常量引用）──
func _资产加载() -> void:
	prints("\n[A] 9-patch 资产加载")
	for 名 in PATCH_SPEC:
		var tex: Texture2D = UITheme.取九宫格贴图(名)
		_check("A %s 可加载" % 名, tex != null)
		if tex == null:
			continue
		var sz: Vector2 = tex.get_size()
		var want: Array = PATCH_SPEC[名]
		_check("A %s 尺寸 %dx%d" % [名, want[0], want[1]],
			int(sz.x) == want[0] and int(sz.y) == want[1])


# ── B. 边距与源图一致 ──
func _边距一致() -> void:
	prints("\n[B] 九宫格边距")
	for 名 in PATCH_SPEC:
		var want: int = PATCH_SPEC[名][2]
		if want == 0:
			continue  # corner_tab 非九宫格
		var sb: StyleBoxTexture = UITheme.取九宫格样式(名)
		if sb == null:
			_check("B %s 样式可建" % 名, false)
			continue
		_check("B %s margin=%d" % [名, want],
			sb.texture_margin_left == want and sb.texture_margin_top == want
			and sb.texture_margin_right == want and sb.texture_margin_bottom == want)


# ── C. 组件工厂实例化 + 真实挂树 ──
func _组件实例化() -> void:
	prints("\n[C] 组件工厂")
	var 页: Panel = UITheme.建页面底面板()
	var 卡: Panel = UITheme.建卡片容器()
	var 行: Panel = UITheme.建列表行容器()
	_check("C1 建页面底面板", 页 != null)
	_check("C2 建卡片容器", 卡 != null)
	_check("C3 建列表行容器", 行 != null)
	for n in [页, 卡, 行]:
		if n != null:
			add_child(n)

	var 图: NinePatchRect = UITheme.建九宫格图("card_bg", 620.0, 240.0)
	_check("C4 建九宫格图", 图 != null and 图.texture != null)
	if 图 != null:
		add_child(图)

	var 角标: TextureRect = UITheme.建状态角标()
	_check("C5 建状态角标", 角标 != null and 角标.texture != null)
	if 角标 != null:
		add_child(角标)

	# 按钮三态：normal/hover/pressed/disabled 必须全部非空，否则实机点击会闪白
	var 主钮 := Button.new()
	UITheme.应用主按钮皮(主钮)
	add_child(主钮)
	_check("C6 主按钮 normal", 主钮.get_theme_stylebox("normal") != null)
	_check("C7 主按钮 hover", 主钮.get_theme_stylebox("hover") != null)
	_check("C8 主按钮 pressed", 主钮.get_theme_stylebox("pressed") != null)
	_check("C9 主按钮 disabled", 主钮.get_theme_stylebox("disabled") != null)

	var 次钮 := Button.new()
	UITheme.应用次按钮皮(次钮)
	add_child(次钮)
	_check("C10 次按钮四态齐全",
		次钮.get_theme_stylebox("normal") != null
		and 次钮.get_theme_stylebox("hover") != null
		and 次钮.get_theme_stylebox("pressed") != null
		and 次钮.get_theme_stylebox("disabled") != null)


# ── D. 缓存是同一个实例（性能红线）──
func _缓存生效() -> void:
	prints("\n[D] 缓存单例")
	var a: Texture2D = UITheme.取九宫格贴图("card_bg")
	var b: Texture2D = UITheme.取九宫格贴图("card_bg")
	_check("D1 贴图缓存命中同一实例", a != null and a == b)
	var s1: StyleBoxTexture = UITheme.取九宫格样式("card_bg")
	var s2: StyleBoxTexture = UITheme.取九宫格样式("card_bg")
	_check("D2 样式缓存命中同一实例", s1 != null and s1 == s2)
	# 变体只走公开 API 验证：套皮后 pressed 必须是从 normal 派生的**不同**实例（下移生效），
	# 且 normal 仍等于缓存本体（说明变体是 duplicate 出来的，没就地改写共享缓存）
	var 试钮 := Button.new()
	UITheme.应用主按钮皮(试钮)
	add_child(试钮)
	var n_sb: StyleBox = 试钮.get_theme_stylebox("normal")
	var p_sb: StyleBox = 试钮.get_theme_stylebox("pressed")
	_check("D3 按下态是派生变体（非同一实例）", n_sb != null and p_sb != null and n_sb != p_sb)
	_check("D4 变体未就地改写共享缓存", n_sb == UITheme.取九宫格样式("btn_fill"))
	if p_sb != null:
		_check("D5 按下态内容下移生效",
			p_sb.get_content_margin(SIDE_TOP) > p_sb.get_content_margin(SIDE_BOTTOM))


# ── E. 陌生资产名的兜底（不崩、返回 Flat）──
func _兜底不崩() -> void:
	prints("\n[E] 兜底")
	var 空: Texture2D = UITheme.取九宫格贴图("__不存在__")
	_check("E1 陌生贴图返回 null 而非崩溃", 空 == null)
	var 兜底面板: Panel = UITheme.建九宫格面板("__不存在__")
	_check("E2 陌生名字仍建得出面板", 兜底面板 != null)
	if 兜底面板 != null:
		add_child(兜底面板)
		_check("E3 兜底面板确实套上了 StyleBox",
			兜底面板.get_theme_stylebox("panel") != null)


func _check(项: String, 通过: bool) -> void:
	if 通过:
		prints("  [OK]  ", 项)
	else:
		_fail += 1
		printerr("  [FAIL]", 项)


func _看门狗() -> void:
	printerr("FATAL: 看门狗超时")
	get_tree().quit(2)


func _finish() -> void:
	prints("")
	if _fail == 0:
		prints(">>>P0_3_ALL_DONE  失败=0")
	else:
		printerr(">>>P0_3_FAILED  失败=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
