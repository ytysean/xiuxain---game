extends CanvasLayer

# 成就弹窗管理器 — Steam风格顶部弹窗
# 功绩堂/宗门史馆/宗门典藏 达成目标时触发
# 从顶部滑入 → 停留 → 滑出，支持队列

const POPUP_PREFAB: String = "res://components/achievement_popup.tscn"

var _队列: Array = []
var _显示中: bool = false

# 显示成就弹窗
# 类型：功绩堂/宗门史馆/宗门典藏
# 名称：成就/里程碑/藏品名称
# 描述：详细描述
# 图标色：图标背景色（不同系统不同颜色）
func show_achievement(类型: String, 名称: String, 描述: String = "", 图标色: Color = Color(0.9, 0.7, 0.2)) -> void:
	_队列.append({
		"类型": 类型,
		"名称": 名称,
		"描述": 描述,
		"图标色": 图标色,
	})
	_处理队列()

# 处理队列
func _处理队列() -> void:
	if _显示中:
		return
	if _队列.is_empty():
		return
	_显示中 = true
	var 数据: Dictionary = _队列.pop_front()
	_显示弹窗(数据)

# 显示单个弹窗
func _显示弹窗(数据: Dictionary) -> void:
	# 场景文件可能尚未落地（用代码兜底创建），先判存在性避免 load 喷 ERROR 噪声
	var scene: PackedScene = null
	if ResourceLoader.exists(POPUP_PREFAB):
		scene = load(POPUP_PREFAB) as PackedScene
	if scene == null:
		# 场景不存在，用代码创建
		_代码创建弹窗(数据)
		return
	var popup: Control = scene.instantiate() as Control
	if popup == null:
		_代码创建弹窗(数据)
		return
	add_child(popup)
	_设置弹窗内容(popup, 数据)
	_播放动画(popup)

# 代码创建弹窗（场景不存在时的兜底）
func _代码创建弹窗(数据: Dictionary) -> void:
	var popup: PanelContainer = PanelContainer.new()
	popup.name = "AchievementPopup"
	popup.custom_minimum_size = Vector2(420, 100)
	# P0-4：接入暗金 9-patch 皮（content_margin 收窄到 18，避免挤压弹窗内容）
	var _popup_sb: StyleBox = UITheme.取九宫格样式("card_bg")
	if _popup_sb != null:
		_popup_sb = _popup_sb.duplicate() as StyleBox
		_popup_sb.set_content_margin_all(18)
		popup.add_theme_stylebox_override("panel", _popup_sb)
	add_child(popup)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	popup.add_child(hbox)

	# 图标区域
	var 图标背景: ColorRect = ColorRect.new()
	图标背景.custom_minimum_size = Vector2(64, 64)
	图标背景.color = 数据.get("图标色", Color(0.9, 0.7, 0.2))
	hbox.add_child(图标背景)

	var 图标标签: Label = Label.new()
	图标标签.text = "★"
	UITheme.apply_project_font(图标标签, 32, false)
	图标标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	图标标签.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	图标背景.add_child(图标标签)

	# 文字区域
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)

	var 类型标签: Label = Label.new()
	类型标签.text = str(数据.get("类型", "成就")) + " 解锁！"
	类型标签.add_theme_color_override("font_color", UITheme.获取金文字色())
	UITheme.apply_project_font(类型标签, 14, false)
	vbox.add_child(类型标签)

	var 名称标签: Label = Label.new()
	名称标签.text = str(数据.get("名称", ""))
	UITheme.apply_project_font(名称标签, 18, false)
	vbox.add_child(名称标签)

	if str(数据.get("描述", "")) != "":
		var 描述标签: Label = Label.new()
		描述标签.text = str(数据.get("描述", ""))
		UITheme.apply_project_font(描述标签, 12, false)
		描述标签.add_theme_color_override("font_color", UITheme.获取弱文字色())
		vbox.add_child(描述标签)

	_播放动画(popup)

# 设置弹窗内容（如果是场景实例化）
func _设置弹窗内容(popup: Control, 数据: Dictionary) -> void:
	var 类型标签 = popup.get_node_or_null("类型")
	if 类型标签 is Label:
		(类型标签 as Label).text = str(数据.get("类型", "成就")) + " 解锁！"
	var 名称标签 = popup.get_node_or_null("名称")
	if 名称标签 is Label:
		(名称标签 as Label).text = str(数据.get("名称", ""))
	var 描述标签 = popup.get_node_or_null("描述")
	if 描述标签 is Label:
		(描述标签 as Label).text = str(数据.get("描述", ""))
	var 图标背景 = popup.get_node_or_null("图标背景")
	if 图标背景 is ColorRect:
		(图标背景 as ColorRect).color = 数据.get("图标色", Color(0.9, 0.7, 0.2))

# 播放动画
func _播放动画(popup: Control) -> void:
	var vp: Viewport = get_viewport()
	var sz: Vector2 = popup.get_combined_minimum_size()
	# 初始位置：屏幕顶部外
	popup.position = Vector2((vp.size.x - sz.x) / 2.0, -sz.y - 20)
	popup.modulate.a = 0.0

	var t: Tween = create_tween()
	# ★ 2026-09-16 终裁（#009 逐页精修）：弹窗**下沿与常驻顶栏下沿对齐**。
	#   坐标系经真实渲染探针（tests/_probe_popup_shot.gd）钉死：CanvasLayer 下 Control 的
	#   `position` 与 `custom_minimum_size` 同处**窗口物理像素空间**（实测 720×1280 窗口下
	#   vp.size=(720,1280)、弹出卡 size=(420,111)）；而顶栏高 189 是 **1920 设计空间**的
	#   常量 ⇒ 必须按 189/1920 比例换算到窗口空间，窗口尺寸变化时自动适配。
	#   三轮取舍，判定标准是「该区域是否可点」：
	#     首版 30（误当设计值用）→ 压顶栏宗门名；顶栏其实无按钮，可接受但非最优；
	#     二版 150 逻辑 → 在弟子页压住筛选条与列表首卡（**可点**），等于把「不阻碍
	#       操作」的瑕疵换成了「阻碍操作」的缺陷；
	#     终版让弹窗下沿贴顶栏下沿：弹窗完整落在顶栏内，**不覆盖任何可点控件**
	#       （下方「弟子录」标题卡的排序/测灵根/仙玉加速三按钮在顶栏之下）。
	#   顶栏被盖 3.5s 不阻碍任何操作，与 Steam 成就弹窗盖标题栏同构。
	var 顶栏底: float = vp.size.y * (189.0 / 1920.0)
	var 落点: float = max(8.0, 顶栏底 - sz.y)
	# 滑入（带弹性）
	t.tween_property(popup, "position:y", 落点, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(popup, "modulate:a", 1.0, 0.3)
	# 停留
	t.tween_interval(3.5)
	# 滑出
	t.tween_property(popup, "position:y", -sz.y - 20, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(popup, "modulate:a", 0.0, 0.3)
	# 结束
	t.tween_callback(popup.queue_free)
	t.tween_callback(_弹窗结束)

# 弹窗结束
func _弹窗结束() -> void:
	_显示中 = false
	_处理队列()
