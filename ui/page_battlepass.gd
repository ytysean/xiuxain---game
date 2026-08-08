extends Control

# 赛季战令（宗门令）页（GameUI 二级页，FAB 入口）：免费/付费双轨、经验进度、领取奖励。
# 读数经 is_instance_valid(Game) + .get() 守卫；操作仅调 Game 公有 API，不改数据层。
# 注意：本文件禁用 `var X := Game.某方法()` 写法（pre_f5 类型推断扫描会判 METHOD_CALL FAIL），
#       一律用显式类型标注（如 `var r: Dictionary = Game.某方法()`）。

signal 返回主页
signal 战令领取完成

const FONT_TITLE: int = 22
const FONT_BODY: int = 15
const FONT_AUX: int = 13

var _built: bool = false
var _scroll_vbox: VBoxContainer
var _余额标签: Label
var _反馈标签: Label
var _等级标签: Label
var _进度条: ProgressBar

func _ready() -> void:
	_build()
	refresh()

func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()

func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)

	# 头部：返回 + 标题 + 余额
	var bar := HBoxContainer.new()
	bar.name = "HeaderBar"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	bar.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	var back := SecondaryButton.new()
	back.name = "BackBtn"
	back.text = "← 宗门"
	back.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	back.pressed.connect(_on_back_pressed)
	bar.add_child(back)
	var title := Label.new()
	title.text = "赛季战令"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_title_font_sized(title, FONT_TITLE)
	title.add_theme_color_override("font_color", UITheme.color_text_title2())
	bar.add_child(title)
	vbox.add_child(bar)

	_余额标签 = Label.new()
	_余额标签.name = "Balance"
	UITheme.apply_value_font(_余额标签, false)
	vbox.add_child(_余额标签)

	# 等级 + 经验进度
	var lvl_row := HBoxContainer.new()
	lvl_row.name = "LevelRow"
	lvl_row.add_theme_constant_override("separation", UITheme.GRID)
	_等级标签 = Label.new()
	_等级标签.name = "Level"
	UITheme.apply_title_font_sized(_等级标签, FONT_BODY)
	_等级标签.add_theme_color_override("font_color", UITheme.color_text_title1())
	lvl_row.add_child(_等级标签)
	_进度条 = ProgressBar.new()
	_进度条.name = "ExpBar"
	_进度条.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_进度条.custom_minimum_size = Vector2(0, 24)
	_进度条.show_percentage = true
	# D2 收口：ExpBar 进度条 fill/bg 继承 main_theme.tres 默认（sb_pbar_fill=success 绿 / sb_pbar_bg=content），
	# 不再手写 StyleBoxFlat（P1-R 已对齐 radius=6，删 in-code 后无 regression，像素等价）。
	lvl_row.add_child(_进度条)
	vbox.add_child(lvl_row)

	_反馈标签 = Label.new()
	_反馈标签.name = "Feedback"
	UITheme.apply_aux_font(_反馈标签)
	_反馈标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(_反馈标签)

	# 滚动列表
	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_scroll_vbox = VBoxContainer.new()
	_scroll_vbox.name = "ListVBox"
	_scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_vbox.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_scroll_vbox)

func refresh() -> void:
	if not _built:
		_build()
	_populate()

func _populate() -> void:
	_刷新等级与余额()
	if _scroll_vbox == null:
		return
	for child in _scroll_vbox.get_children():
		_scroll_vbox.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		return
	if not Game.has_method("战令信息"):
		return

	var 信息: Dictionary = Game.战令信息()
	var 最大: int = int(信息.get("最大等级", 0))
	var 已购付费: bool = bool(信息.get("已购付费轨", false))
	var 已领免费: Array = 信息.get("已领免费", [])
	var 已领付费: Array = 信息.get("已领付费", [])

	var 免头 := Label.new()
	免头.text = "免费轨道"
	UITheme.apply_aux_font(免头)
	免头.add_theme_color_override("font_color", UITheme.color_text_title2())
	_scroll_vbox.add_child(免头)
	for lv in range(1, 最大 + 1):
		_scroll_vbox.add_child(_建奖励行("免费", lv, 已购付费, lv in 已领免费))

	var 付头 := Label.new()
	付头.text = "付费轨道（%s）" % ("已解锁" if 已购付费 else "未解锁")
	UITheme.apply_aux_font(付头)
	付头.add_theme_color_override("font_color", UITheme.color_text_title2())
	_scroll_vbox.add_child(付头)
	for lv in range(1, 最大 + 1):
		_scroll_vbox.add_child(_建奖励行("付费", lv, 已购付费, lv in 已领付费))

	# 解锁付费轨按钮
	var 付费按钮: Button = SecondaryButton.new() if 已购付费 else PrimaryButton.new()
	付费按钮.name = "UnlockPayBtn"
	付费按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	if 已购付费:
		付费按钮.text = "付费轨已解锁"
		付费按钮.disabled = true
	else:
		付费按钮.text = "解锁付费轨（%d 仙玉）" % BattlePass.付费轨价
		付费按钮.pressed.connect(_on_解锁付费轨)
	_scroll_vbox.add_child(付费按钮)

func _建奖励行(轨道: String, lv: int, 已购付费: bool, 已领: bool) -> Control:
	var 行 := HBoxContainer.new()
	行.name = "Row_%s_%d" % [轨道, lv]
	行.add_theme_constant_override("separation", UITheme.GRID)
	var lv标签 := Label.new()
	lv标签.text = "Lv.%d" % lv
	lv标签.custom_minimum_size = Vector2(48, 0)
	UITheme.apply_value_font(lv标签, false)
	行.add_child(lv标签)

	var 奖: Dictionary = {}
	for r in BattlePass.等级表:
		if int(r.get("等级", -1)) == lv:
			奖 = r.get(轨道 + "奖励", {})
			break
	var 文本: String = _奖文本(奖)
	var 格: Button = PrimaryButton.new() if not (已领 or (轨道 == "付费" and not 已购付费)) else SecondaryButton.new()
	格.text = 文本 if 文本 != "" else "（无奖励）"
	格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	格.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	if 已领:
		格.text = "已领·" + 格.text
		格.disabled = true
	elif 轨道 == "付费" and not 已购付费:
		格.text = "未解锁·" + 格.text
		格.disabled = true
	else:
		格.pressed.connect(_on_领奖.bind(轨道, lv))
	行.add_child(格)
	return 行

func _奖文本(奖: Dictionary) -> String:
	if 奖.is_empty():
		return ""
	var 部件: Array = []
	if 奖.has("灵石"): 部件.append("灵石+%d" % int(奖["灵石"]))
	if 奖.has("灵气"): 部件.append("灵气+%d" % int(奖["灵气"]))
	if 奖.has("灵草"): 部件.append("灵草+%d" % int(奖["灵草"]))
	if 奖.has("矿石"): 部件.append("矿石+%d" % int(奖["矿石"]))
	if 奖.has("声望"): 部件.append("声望+%d" % int(奖["声望"]))
	if 奖.has("绑定仙玉"): 部件.append("绑定仙玉+%d" % int(奖["绑定仙玉"]))
	if 奖.has("皮肤"): 部件.append("外观·%s" % str(奖["皮肤"]))
	return "　".join(部件)

func _刷新等级与余额() -> void:
	if not is_instance_valid(Game) or not Game.has_method("战令信息"):
		return
	var 信息: Dictionary = Game.战令信息()
	if _余额标签 != null:
		_余额标签.text = "仙玉：%d" % int(Game.仙玉_非绑定)
	if _等级标签 != null:
		_等级标签.text = "赛季 %d · Lv.%d / %d" % [int(信息.get("赛季", 1)), int(信息.get("等级", 0)), int(信息.get("最大等级", 0))]
	if _进度条 != null:
		var 本级所需: int = int(信息.get("本级所需", 0))
		_进度条.max_value = maxi(1, 本级所需)
		_进度条.value = int(信息.get("经验", 0))

func _反馈(文本: String) -> void:
	if _反馈标签 != null:
		_反馈标签.text = 文本

func _on_领奖(轨道: String, lv: int) -> void:
	if not is_instance_valid(Game) or not Game.has_method("领战令奖励"):
		_反馈("数据未就绪")
		return
	var r: Dictionary = Game.领战令奖励(轨道, lv)
	_反馈(str(r.get("msg", "—")))
	refresh()
	战令领取完成.emit()

func _on_解锁付费轨() -> void:
	if not is_instance_valid(Game) or not Game.has_method("购战令付费轨"):
		_反馈("数据未就绪")
		return
	var r: Dictionary = Game.购战令付费轨()
	_反馈(str(r.get("msg", "—")))
	refresh()
	战令领取完成.emit()

func _on_back_pressed() -> void:
	返回主页.emit()
