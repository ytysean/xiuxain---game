extends Control
# 战斗场景UI（P1版本）
# 竖版分层立绘自动战斗：上方敌方/中间特效/下方我方/底部日志+控制栏
# 接收BattleManager战报，逐条播放战斗动画
# P1新增：技能名称横幅/技能特效/状态图标/车轮战切换/镜头聚焦

signal 战斗结束(战报: Dictionary)

const BattleManager = preload("res://BattleManager.gd")

# 战斗状态
var _战报: Dictionary = {}
var _当前日志索引: int = 0
var _播放中: bool = false
var _加速: bool = false
var _自动: bool = true
var _跳过: bool = false

# 单位数据（运行时）
var _攻方单位: Array = []   # [{快照, 立绘节点, 血条, 灵力条, 名字标签, 状态图标层}]
var _守方单位: Array = []
var _当前攻方索引: int = 0
var _当前守方索引: int = 0

# UI节点
var _敌方区域: HBoxContainer = null
var _我方区域: HBoxContainer = null
var _特效层: Control = null
var _日志面板: RichTextLabel = null
var _回合标签: Label = null
var _加速按钮: Button = null
var _自动按钮: Button = null
var _跳过按钮: Button = null
var _技能名称横幅: Label = null   # P1：技能名称大字横幅
var _镜头聚焦层: Control = null    # P1：镜头聚焦高亮层

# 动画参数
const 基础动画时长: float = 1.2
const 加速动画时长: float = 0.6
const 技能横幅时长: float = 0.8    # P1：技能横幅显示时长
const 车轮战切换时长: float = 0.5   # P1：车轮战切换动画时长

# P3性能优化：对象池（避免频繁创建销毁节点）
const 飘字池大小: int = 15
const 粒子池大小: int = 30
var _飘字池: Array = []       # 伤害飘字对象池
var _粒子池: Array = []       # 粒子效果对象池
var _飘字池索引: int = 0
var _粒子池索引: int = 0

# P3性能优化：战斗日志最大条数（避免无限增长）
const 最大日志条数: int = 50

# P3性能优化：粒子数量（根据加速状态动态调整）
var _技能粒子数: int = 8
var _阵亡粒子数: int = 12
var _灵兽粒子数: int = 6

func _ready() -> void:
	_build_ui()

# ============ UI构建 ============
func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.10, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# 顶部标题栏
	_build_header(root)

	# 敌方区域
	_build_enemy_area(root)

	# 中间特效区（弹性填充）
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 120)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)
	_特效层 = Control.new()
	_特效层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_特效层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.add_child(_特效层)

	# 我方区域
	_build_player_area(root)

	# 战斗日志
	_build_log_panel(root)

	# 底部控制栏
	_build_control_bar(root)

	# P1：技能名称大字横幅（全屏居中，默认隐藏）
	_技能名称横幅 = Label.new()
	_技能名称横幅.name = "SkillNameBanner"
	_技能名称横幅.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_技能名称横幅.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_技能名称横幅.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.apply_project_font(_技能名称横幅, 72, true)
	_技能名称横幅.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	_技能名称横幅.add_theme_color_override("font_shadow_color", Color(0.3, 0.5, 1.0, 0.8))
	_技能名称横幅.add_theme_constant_override("shadow_offset_x", 3)
	_技能名称横幅.add_theme_constant_override("shadow_offset_y", 3)
	_技能名称横幅.modulate.a = 0.0
	_技能名称横幅.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_技能名称横幅)

	# P1：镜头聚焦高亮层（全屏，默认隐藏）
	_镜头聚焦层 = Control.new()
	_镜头聚焦层.name = "CameraFocusLayer"
	_镜头聚焦层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_镜头聚焦层.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_镜头聚焦层.modulate.a = 0.0
	add_child(_镜头聚焦层)

func _build_header(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 70)
	bar.add_theme_constant_override("separation", 20)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(bar)

	var title := Label.new()
	title.text = "◆ 战斗中 ◆"
	UITheme.apply_project_font(title, 28, true)
	title.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
	bar.add_child(title)

	_回合标签 = Label.new()
	_回合标签.text = "回合 1"
	UITheme.apply_project_font(_回合标签, 22, false)
	_回合标签.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	bar.add_child(_回合标签)

func _build_enemy_area(parent: Control) -> void:
	var area := VBoxContainer.new()
	area.custom_minimum_size = Vector2(0, 420)
	area.add_theme_constant_override("separation", 10)
	parent.add_child(area)

	var label := Label.new()
	label.text = "【敌方】"
	UITheme.apply_project_font(label, 20, false)
	label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	area.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	area.add_child(hbox)
	_敌方区域 = hbox

func _build_player_area(parent: Control) -> void:
	var area := VBoxContainer.new()
	area.custom_minimum_size = Vector2(0, 420)
	area.add_theme_constant_override("separation", 10)
	parent.add_child(area)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 30)
	area.add_child(hbox)
	_我方区域 = hbox

	var label := Label.new()
	label.text = "【我方】"
	UITheme.apply_project_font(label, 20, false)
	label.add_theme_color_override("font_color", Color(0.8, 0.67, 0.4))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	area.add_child(label)

func _build_log_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 220)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.9)
	style.border_color = Color(0.7, 0.59, 0.31, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	_日志面板 = RichTextLabel.new()
	_日志面板.bbcode_enabled = true
	_日志面板.scroll_following = true
	UITheme.apply_project_font(_日志面板, 16, false)
	margin.add_child(_日志面板)

func _build_control_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, 100)
	bar.add_theme_constant_override("separation", 20)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(bar)

	_加速按钮 = _make_ctrl_button("2x 加速", Color(0.16, 0.29, 0.42), Color(0.53, 0.8, 1.0))
	_加速按钮.pressed.connect(_on_speed_toggle)
	bar.add_child(_加速按钮)

	_自动按钮 = _make_ctrl_button("自动", Color(0.16, 0.42, 0.29), Color(0.53, 1.0, 0.67))
	_自动按钮.button_pressed = true
	_自动按钮.pressed.connect(_on_auto_toggle)
	bar.add_child(_自动按钮)

	_跳过按钮 = _make_ctrl_button("跳过", Color(0.42, 0.29, 0.16), Color(1.0, 0.8, 0.53))
	_跳过按钮.pressed.connect(_on_skip)
	bar.add_child(_跳过按钮)

	# P3性能优化：初始化对象池
	_初始化对象池()

# P3性能优化：初始化对象池（预创建飘字和粒子节点，避免战斗中频繁创建销毁）
func _初始化对象池() -> void:
	# 伤害飘字对象池
	for i in range(飘字池大小):
		var label := Label.new()
		UITheme.apply_project_font(label, 36, false)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.visible = false
		label.z_index = 100
		_特效层.add_child(label)
		_飘字池.append(label)

	# 粒子效果对象池
	for i in range(粒子池大小):
		var 粒子 := ColorRect.new()
		粒子.custom_minimum_size = Vector2(8, 8)
		粒子.color = Color.WHITE
		粒子.visible = false
		粒子.z_index = 50
		_特效层.add_child(粒子)
		_粒子池.append(粒子)

# P3性能优化：从对象池获取飘字
func _获取飘字() -> Label:
	var label: Label = _飘字池[_飘字池索引]
	_飘字池索引 = (_飘字池索引 + 1) % _飘字池.size()
	label.visible = true
	label.modulate.a = 1.0
	return label

# P3性能优化：从对象池获取粒子
func _获取粒子() -> ColorRect:
	var 粒子: ColorRect = _粒子池[_粒子池索引]
	_粒子池索引 = (_粒子池索引 + 1) % _粒子池.size()
	粒子.visible = true
	粒子.modulate.a = 1.0
	return 粒子

# P3性能优化：回收所有对象池节点（战斗结束时调用）
func _回收对象池() -> void:
	for label in _飘字池:
		label.visible = false
		var t = label.get_tree().create_tween()
		t.kill()
	for 粒子 in _粒子池:
		粒子.visible = false
		var t = 粒子.get_tree().create_tween()
		t.kill()

func _make_ctrl_button(text: String, bg: Color, fg: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 60)
	UITheme.apply_project_font(btn, 22, true)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg
	normal.set_corner_radius_all(8)
	normal.border_color = fg * Color(1, 1, 1, 0.5)
	normal.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = bg * Color(1.2, 1.2, 1.2)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate()
	pressed.bg_color = bg * Color(0.8, 0.8, 0.8)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", fg)
	return btn

# ============ 单位创建 ============
func _create_unit(快照: Dictionary, is_enemy: bool) -> Dictionary:
	var unit := VBoxContainer.new()
	unit.custom_minimum_size = Vector2(200, 380)
	unit.add_theme_constant_override("separation", 6)

	# 立绘
	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(180, 240)
	unit.add_child(portrait_box)

	var portrait := TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_box.add_child(portrait)

	# P1：状态图标层（立绘右上角）
	var status_layer := HBoxContainer.new()
	status_layer.name = "StatusIcons"
	status_layer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	status_layer.offset_left = -100
	status_layer.offset_top = 5
	status_layer.offset_right = -5
	status_layer.offset_bottom = 40
	status_layer.alignment = BoxContainer.ALIGNMENT_END
	status_layer.add_theme_constant_override("separation", 2)
	portrait_box.add_child(status_layer)

	# 尝试加载立绘
	var 立绘路径: String = ""
	if 快照.has("立绘路径"):
		立绘路径 = 快照["立绘路径"]
	elif 快照.has("名称"):
		# 怪物立绘路径
		立绘路径 = "res://art/characters/monsters/monster_%s_512.png" % _名称转拼音(快照.get("名称", ""))
	if 立绘路径 != "" and ResourceLoader.exists(立绘路径):
		var tex: Texture2D = load(立绘路径)
		if tex:
			portrait.texture = tex

	# 名字+境界
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 8)
	unit.add_child(name_row)

	var name_label := Label.new()
	name_label.text = 快照.get("名称", "?")
	UITheme.apply_project_font(name_label, 18, false)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_row.add_child(name_label)

	var realm_label := Label.new()
	realm_label.text = 快照.get("境界", "")
	UITheme.apply_project_font(realm_label, 14, false)
	realm_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.7))
	name_row.add_child(realm_label)

	# 血条
	var hp_bar := _make_progress_bar(Color(0.8, 0.2, 0.2), Color(1.0, 0.33, 0.33))
	unit.add_child(hp_bar)

	# 灵力条
	var mp_bar := _make_progress_bar(Color(0.2, 0.4, 0.8), Color(0.33, 0.53, 1.0))
	mp_bar.custom_minimum_size = Vector2(180, 14)
	unit.add_child(mp_bar)

	# 初始血量
	var max_hp: int = int(快照.get("属性", {}).get("血", 100))
	var max_mp: int = int(快照.get("灵力上限", 50))
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp
	mp_bar.max_value = max_mp
	mp_bar.value = max_mp

	return {"快照": 快照, "节点": unit, "立绘": portrait, "血条": hp_bar, "灵力条": mp_bar, "名字": name_label, "最大血": max_hp, "最大灵": max_mp, "is_enemy": is_enemy, "状态图标层": status_layer, "当前状态": []}

func _make_progress_bar(bg_color: Color, fg_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 20)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fg_color
	fg.set_corner_radius_all(10)
	fg.border_color = fg_color * Color(1, 1, 1, 0.5)
	fg.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

func _名称转拼音(name: String) -> String:
	# 简单映射，后续可扩展
	var mapping: Dictionary = {
		"野狼": "yelang", "山贼": "shanzei", "低阶妖兽": "dijieyaoshou",
		"山贼喽啰": "shanzeilouluo", "山匪头目": "shanfeitoumu",
		"林间精怪": "linjianjingguai", "矿洞石傀": "kuangdongshikui",
		"后山狼王": "houshanlangwang", "青冥散修": "qingmingsanxiu",
		"古道魔头": "gudaomotou", "玄雾阴魂": "xuanwuyinhun",
		"峡谷亡灵将": "xiaguwanglingjiang", "青鳞蛇妖": "qinglinsheyao",
		"赤焰狐妖": "chiyanhuyao", "黑熊精": "heixiongjing",
		"血修": "xuexiu", "噬魂魔": "shihunmo", "厉鬼": "ligui",
		"阴魂将": "yinhunjiang", "蛟妖": "jiaoyao",
		"妖王": "yaowang", "魔尊": "mozun", "鬼帝": "guidi",
		"应龙": "yinglong", "上古凶兽": "shangguxiongshou",
		"妖皇": "yaohuang", "魔帝": "modi", "青龙": "qinglong",
		"混沌凶兽": "hundunxiongshou"
	}
	return mapping.get(name, name)

# ============ 战斗播放 ============
func 开始战斗(攻方列表: Array, 守方列表: Array, 战斗标题: String = "战斗") -> void:
	# 清空旧单位
	_clear_units()

	# 创建单位
	for u in 攻方列表:
		var unit = _create_unit(u, false)
		_我方区域.add_child(unit["节点"])
		_攻方单位.append(unit)
	for u in 守方列表:
		var unit = _create_unit(u, true)
		_敌方区域.add_child(unit["节点"])
		_守方单位.append(unit)

	# 计算战报
	_战报 = BattleManager.发起3v3(攻方列表, 守方列表, "full", false)
	_当前日志索引 = 0
	_播放中 = true
	_跳过 = false

	_日志面板.clear()
	_日志面板.append_text("[color=#d4af37]战斗开始！[/color]\n")

	_播放下一条()

# P2接入：播放已计算好的战报（不重新计算，用于接入现有战斗入口）
func 播放战报(战报: Dictionary, 攻方列表: Array, 守方列表: Array, 战斗标题: String = "战斗") -> void:
	# 清空旧单位
	_clear_units()

	# 创建单位
	for u in 攻方列表:
		var unit = _create_unit(u, false)
		_我方区域.add_child(unit["节点"])
		_攻方单位.append(unit)
	for u in 守方列表:
		var unit = _create_unit(u, true)
		_敌方区域.add_child(unit["节点"])
		_守方单位.append(unit)

	# 使用传入的战报（不重新计算）
	_战报 = 战报
	_当前日志索引 = 0
	_播放中 = true
	_跳过 = false

	_日志面板.clear()
	_日志面板.append_text("[color=#d4af37]%s 开始！[/color]\n" % 战斗标题)

	_播放下一条()

func _clear_units() -> void:
	for u in _攻方单位:
		if is_instance_valid(u["节点"]):
			u["节点"].queue_free()
	for u in _守方单位:
		if is_instance_valid(u["节点"]):
			u["节点"].queue_free()
	_攻方单位.clear()
	_守方单位.clear()
	_当前攻方索引 = 0
	_当前守方索引 = 0

func _播放下一条() -> void:
	if not _播放中:
		return
	if _跳过:
		_finish_battle()
		return

	var 日志: Array = _战报.get("battle_log", [])
	if _当前日志索引 >= 日志.size():
		_finish_battle()
		return

	var entry: Dictionary = 日志[_当前日志索引]
	_当前日志索引 += 1

	# 更新回合
	var round: int = int(entry.get("round", 1))
	_回合标签.text = "回合 %d" % round

	# 播放日志
	_play_log_entry(entry)

	# 延迟播放下一条
	var 时长: float = 加速动画时长 if _加速 else 基础动画时长
	await get_tree().create_timer(时长).timeout
	_播放下一条()

func _play_log_entry(entry: Dictionary) -> void:
	var log_type: String = entry.get("log_type", "damage")
	var actor: String = entry.get("actor", "")
	var target: String = entry.get("target", "")
	var damage: int = int(entry.get("damage", 0))
	var is_crit: bool = entry.get("is_crit", false)
	var is_restrain: bool = entry.get("is_restrain", false)
	var a_hp: int = int(entry.get("attacker_hp", 0))
	var d_hp: int = int(entry.get("defender_hp", 0))

	# P1：镜头聚焦当前行动单位
	var 行动单位 = _find_unit_by_name(actor)
	if not 行动单位.is_empty():
		_镜头聚焦(行动单位)
		# P2：行动指示器
		_显示行动指示器(行动单位)

	match log_type:
		"damage", "cast_skill":
			# 找到攻击方和受击方
			var 攻单位 = _find_unit_by_name(actor)
			var 守单位 = _find_unit_by_name(target)

			if 攻单位 and 守单位:
				# 攻击动画
				_play_attack_anim(攻单位, 守单位, damage, is_crit)

			# P1：技能名称横幅+技能特效
			if log_type == "cast_skill":
				var skill_name: String = entry.get("ref_name", "技能")
				_显示技能横幅(skill_name)
				if 攻单位 and 守单位:
					_播放技能特效(攻单位, 守单位, skill_name)

			# 更新血条
			if 守单位:
				var tween := create_tween()
				tween.tween_property(守单位["血条"], "value", d_hp, 0.3)

			# 日志
			var 颜色: String = "#ffcc44" if is_crit else "#aabbcc"
			var 暴击标记: String = " [color=#ff6644]【暴击】[/color]" if is_crit else ""
			var 克制标记: String = " [color=#44aaff]【克制】[/color]" if is_restrain else ""
			if log_type == "cast_skill":
				var skill_name: String = entry.get("ref_name", "技能")
				_日志面板.append_text("[color=#66aaff]%s 释放【%s】[/color]\n" % [actor, skill_name])
			_日志面板.append_text("[color=%s]%s → %s  伤害 %d%s%s[/color]\n" % [颜色, actor, target, damage, 暴击标记, 克制标记])

		"buff_apply":
			var buff_name: String = entry.get("ref_name", "效果")
			_日志面板.append_text("[color=#cc99ff]%s 获得【%s】[/color]\n" % [actor, buff_name])
			# P1：添加状态图标
			var buff单位 = _find_unit_by_name(actor)
			if not buff单位.is_empty():
				_添加状态图标(buff单位, buff_name, true)

		"buff_tick":
			var buff_name: String = entry.get("ref_name", "效果")
			_日志面板.append_text("[color=#99ccff]%s 【%s】生效[/color]\n" % [actor, buff_name])

		"buff_expire":
			var buff_name: String = entry.get("ref_name", "效果")
			_日志面板.append_text("[color=#888888]%s 【%s】消散[/color]\n" % [actor, buff_name])
			# P1：移除状态图标
			var buff单位 = _find_unit_by_name(actor)
			if not buff单位.is_empty():
				_移除状态图标(buff单位, buff_name)

		"control_skip":
			_日志面板.append_text("[color=#aaaaaa]%s 被控制，跳过行动[/color]\n" % actor)
			# P1：添加控制状态图标
			var ctrl单位 = _find_unit_by_name(actor)
			if not ctrl单位.is_empty():
				_添加状态图标(ctrl单位, "控制", false)

		"heal":
			_日志面板.append_text("[color=#66ff88]%s 恢复 %d 点气血[/color]\n" % [actor, damage])
			# 更新血条
			var heal单位 = _find_unit_by_name(actor)
			if not heal单位.is_empty():
				var tween := create_tween()
				tween.tween_property(heal单位["血条"], "value", a_hp, 0.3)

		_:
			# P2：灵兽协战动画
			if entry.get("pet_action", false):
				var 灵兽主人 = _find_unit_by_name(actor.split("·")[0])
				var 灵兽目标 = _find_unit_by_name(target)
				if not 灵兽主人.is_empty() and not 灵兽目标.is_empty():
					var 灵兽名: String = actor.split("·")[1] if actor.contains("·") else "灵兽"
					_播放灵兽协战(灵兽主人, 灵兽名, 灵兽目标)
				_日志面板.append_text("[color=#66ffaa]%s → %s  灵兽协战[/color]\n" % [actor, target])
			else:
				_日志面板.append_text("%s → %s  伤害 %d\n" % [actor, target, damage])

	# 检查阵亡
	if d_hp <= 0 and target != "":
		_日志面板.append_text("[color=#ff4444]%s 阵亡！[/color]\n" % target)
		var dead_unit = _find_unit_by_name(target)
		if dead_unit:
			# P2：播放阵亡动画
			_播放阵亡动画(dead_unit)
			# P1：车轮战切换（查找下一位未阵亡单位）
			var is_attack方: bool = false
			var 单位列表: Array = _守方单位
			for u in _攻方单位:
				if u == dead_unit:
					is_attack方 = true
					单位列表 = _攻方单位
					break
			# 查找下一位
			var 下一位: Dictionary = {}
			var found: bool = false
			for u in 单位列表:
				if found and u["节点"].modulate != Color(0.4, 0.4, 0.4):
					下一位 = u
					break
				if u == dead_unit:
					found = true
			if not 下一位.is_empty():
				_车轮战切换(dead_unit, 下一位, is_attack方)

func _find_unit_by_name(name: String) -> Dictionary:
	for u in _攻方单位:
		if u["快照"].get("名称", "") == name:
			return u
	for u in _守方单位:
		if u["快照"].get("名称", "") == name:
			return u
	return {}

func _play_attack_anim(攻单位: Dictionary, 守单位: Dictionary, damage: int, is_crit: bool) -> void:
	if 攻单位.is_empty() or 守单位.is_empty():
		return

	# 攻击方高亮
	var 攻节点: Control = 攻单位["节点"]
	var 守节点: Control = 守单位["节点"]

	# 攻击方位移动画
	var original_pos: Vector2 = 攻节点.position
	var target_pos: Vector2 = 守节点.position
	var dir: Vector2 = (target_pos - original_pos).normalized()
	var move_dist: float = 60.0

	var tween := create_tween()
	tween.tween_property(攻节点, "position", original_pos + dir * move_dist, 0.2)
	tween.tween_callback(func():
		# 受击闪红
		守节点.modulate = Color(1.5, 0.5, 0.5)
		# 伤害飘字
		_spawn_damage_text(守节点, damage, is_crit)
	)
	tween.tween_interval(0.15)
	tween.tween_property(守节点, "modulate", Color(1, 1, 1), 0.15)
	tween.tween_property(攻节点, "position", original_pos, 0.25)

func _spawn_damage_text(target_node: Control, damage: int, is_crit: bool) -> void:
	# P3性能优化：使用对象池，避免频繁创建销毁
	var label: Label = _获取飘字()
	label.text = "-%d" % damage
	UITheme.apply_project_font(label, 36 if is_crit else 28, false)
	if is_crit:
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.27))
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	# 定位到目标节点上方
	var global_pos: Vector2 = target_node.global_position + Vector2(target_node.size.x / 2, 0)
	var local_pos: Vector2 = _特效层.to_local(global_pos)
	label.position = local_pos

	# 飘字动画（结束后隐藏，不销毁）
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -60), 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func(): label.visible = false)

func _finish_battle() -> void:
	_播放中 = false
	# P3性能优化：战斗结束后回收对象池节点
	_回收对象池()
	var 胜方: String = "我方" if _战报.get("is_win", false) else "敌方"
	_日志面板.append_text("\n[color=#d4af37]═══ 战斗结束 ═══[/color]\n")
	_日志面板.append_text("[color=#44ff88]%s 胜利！[/color]  回合数：%d  剩余气血：%d\n" % [胜方, _战报.get("round_count", 0), _战报.get("remaining_hp", 0)])

	# P2：显示胜负结算画面（点击确认后发送结束信号）
	await get_tree().create_timer(0.5).timeout
	_显示胜负结算(_战报)

# ============ 控制按钮 ============
func _on_speed_toggle() -> void:
	_加速 = not _加速
	if _加速:
		_加速按钮.add_theme_color_override("font_color", Color(0.67, 0.87, 1.0))
	else:
		_加速按钮.add_theme_color_override("font_color", Color(0.53, 0.8, 1.0))

func _on_auto_toggle() -> void:
	_自动 = not _自动

func _on_skip() -> void:
	_跳过 = true

# ============ P1：技能名称大字横幅 ============
func _显示技能横幅(技能名: String) -> void:
	if _技能名称横幅 == null:
		return
	_技能名称横幅.text = "【%s】" % 技能名
	_技能名称横幅.modulate.a = 0.0
	_技能名称横幅.visible = true

	var 时长: float = 技能横幅时长 * (0.5 if _加速 else 1.0)
	var tween := create_tween()
	tween.tween_property(_技能名称横幅, "modulate:a", 1.0, 时长 * 0.2)
	tween.tween_interval(时长 * 0.4)
	tween.tween_property(_技能名称横幅, "modulate:a", 0.0, 时长 * 0.4)
	tween.tween_callback(func(): _技能名称横幅.visible = false)

# ============ P1：技能特效 ============
func _播放技能特效(攻单位: Dictionary, 守单位: Dictionary, 技能名: String) -> void:
	if 攻单位.is_empty() or 守单位.is_empty():
		return

	# 根据技能名选择特效颜色
	var 特效颜色: Color = _技能名转颜色(技能名)

	# 在特效层生成技能特效
	var 特效节点 := Control.new()
	特效节点.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	特效节点.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_特效层.add_child(特效节点)

	# 生成法阵光环
	var 光环 := ColorRect.new()
	光环.color = 特效颜色
	光环.modulate.a = 0.3
	光环.size = Vector2(200, 200)
	光环.position = Vector2(_特效层.size.x / 2 - 100, _特效层.size.y / 2 - 100)
	特效节点.add_child(光环)

	# 光环扩散动画
	var 时长: float = 0.6 * (0.5 if _加速 else 1.0)
	var tween := create_tween()
	tween.tween_property(光环, "scale", Vector2(2.5, 2.5), 时长)
	tween.parallel().tween_property(光环, "modulate:a", 0.0, 时长)
	tween.tween_callback(特效节点.queue_free)

	# P3性能优化：生成剑光/法术粒子（使用对象池，根据加速状态动态调整数量）
	var 粒子数: int = _技能粒子数 if not _加速 else int(_技能粒子数 * 0.5)
	for i in range(粒子数):
		var 粒子: ColorRect = _获取粒子()
		粒子.color = 特效颜色
		粒子.size = Vector2(8, 8)
		粒子.position = Vector2(_特效层.size.x / 2, _特效层.size.y / 2)

		var 角度: float = deg_to_rad(i * (360.0 / 粒子数))
		var 距离: float = 150.0
		var ptween := create_tween()
		ptween.tween_property(粒子, "position", Vector2(
			_特效层.size.x / 2 + cos(角度) * 距离,
			_特效层.size.y / 2 + sin(角度) * 距离
		), 时长 * 0.8)
		ptween.parallel().tween_property(粒子, "modulate:a", 0.0, 时长 * 0.8)
		ptween.tween_callback(func(): 粒子.visible = false)

func _技能名转颜色(技能名: String) -> Color:
	if 技能名.contains("剑") or 技能名.contains("刃") or 技能名.contains("斩"):
		return Color(1.0, 0.9, 0.7)  # 金白
	elif 技能名.contains("火") or 技能名.contains("焰") or 技能名.contains("炎"):
		return Color(1.0, 0.4, 0.2)  # 红
	elif 技能名.contains("水") or 技能名.contains("冰") or 技能名.contains("寒"):
		return Color(0.4, 0.7, 1.0)  # 蓝
	elif 技能名.contains("雷") or 技能名.contains("电"):
		return Color(0.9, 0.8, 0.2)  # 黄
	elif 技能名.contains("木") or 技能名.contains("藤") or 技能名.contains("毒"):
		return Color(0.4, 0.9, 0.4)  # 绿
	elif 技能名.contains("土") or 技能名.contains("岩") or 技能名.contains("盾"):
		return Color(0.8, 0.6, 0.4)  # 土黄
	elif 技能名.contains("暗") or 技能名.contains("魔") or 技能名.contains("鬼"):
		return Color(0.6, 0.3, 0.8)  # 紫
	else:
		return Color(0.7, 0.8, 1.0)  # 淡蓝

# ============ P1：状态图标管理 ============
func _添加状态图标(单位: Dictionary, 状态名: String, is_buff: bool) -> void:
	if 单位.is_empty() or not 单位.has("状态图标层"):
		return

	# 检查是否已存在
	if 单位["当前状态"].has(状态名):
		return

	var 图标 := Label.new()
	图标.text = 状态名.left(1)  # 取第一个字作为图标
	图标.custom_minimum_size = Vector2(28, 28)
	UITheme.apply_project_font(图标, 16, false)
	图标.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	图标.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_buff:
		图标.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	else:
		图标.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

	# 背景
	var 背景 := StyleBoxFlat.new()
	背景.bg_color = Color(0, 0, 0, 0.7)
	背景.set_corner_radius_all(4)
	背景.border_color = Color(1, 1, 1, 0.3) if is_buff else Color(1, 0.3, 0.3, 0.5)
	背景.set_border_width_all(1)
	图标.add_theme_stylebox_override("normal", 背景)

	单位["状态图标层"].add_child(图标)
	单位["当前状态"].append(状态名)

func _移除状态图标(单位: Dictionary, 状态名: String) -> void:
	if 单位.is_empty() or not 单位.has("状态图标层"):
		return
	if not 单位["当前状态"].has(状态名):
		return

	# 查找并移除
	for child in 单位["状态图标层"].get_children():
		if child is Label and child.text == 状态名.left(1):
			child.queue_free()
			break
	单位["当前状态"].erase(状态名)

# ============ P1：车轮战切换动画 ============
func _车轮战切换(阵亡单位: Dictionary, 新单位: Dictionary, is_attack方: bool) -> void:
	if 阵亡单位.is_empty() or 新单位.is_empty():
		return

	# 阵亡单位淡出+缩小
	var tween1 := create_tween()
	tween1.tween_property(阵亡单位["节点"], "modulate:a", 0.0, 车轮战切换时长 * 0.4)
	tween1.parallel().tween_property(阵亡单位["节点"], "scale", Vector2(0.5, 0.5), 车轮战切换时长 * 0.4)
	tween1.tween_callback(func(): 阵亡单位["节点"].visible = false)

	# 新单位淡入+放大（延迟）
	新单位["节点"].modulate.a = 0.0
	新单位["节点"].scale = Vector2(0.5, 0.5)
	新单位["节点"].visible = true

	var tween2 := create_tween()
	tween2.tween_interval(车轮战切换时长 * 0.3)
	tween2.tween_property(新单位["节点"], "modulate:a", 1.0, 车轮战切换时长 * 0.4)
	tween2.parallel().tween_property(新单位["节点"], "scale", Vector2(1.0, 1.0), 车轮战切换时长 * 0.4)

	# 日志
	var 方向: String = "敌方" if is_attack方 else "我方"
	_日志面板.append_text("[color=#ffaa44]%s %s 阵亡，下一位上场！[/color]\n" % [方向, 阵亡单位["快照"].get("名称", "?")])

# ============ P1：镜头聚焦当前行动单位 ============
func _镜头聚焦(单位: Dictionary) -> void:
	if 单位.is_empty() or _镜头聚焦层 == null:
		return

	# 清除旧的聚焦高亮
	for child in _镜头聚焦层.get_children():
		child.queue_free()

	# 获取单位全局位置
	var 单位节点: Control = 单位["节点"]
	var 全局位置: Vector2 = 单位节点.global_position
	var 单位大小: Vector2 = 单位节点.size

	# 创建聚焦高亮框
	var 高亮 := ColorRect.new()
	高亮.color = Color(1.0, 0.9, 0.5, 0.0)
	高亮.position = _镜头聚焦层.to_local(全局位置)
	高亮.size = 单位大小 + Vector2(20, 20)
	高亮.position -= Vector2(10, 10)
	_镜头聚焦层.add_child(高亮)

	# 高亮闪烁动画
	var 时长: float = 0.5 * (0.5 if _加速 else 1.0)
	var tween := create_tween()
	tween.tween_property(高亮, "color:a", 0.3, 时长 * 0.3)
	tween.tween_property(高亮, "color:a", 0.0, 时长 * 0.7)
	tween.tween_callback(高亮.queue_free)

	# 其他单位变暗
	for u in _攻方单位:
		if u != 单位 and u.has("节点"):
			u["节点"].modulate = Color(0.6, 0.6, 0.6)
	for u in _守方单位:
		if u != 单位 and u.has("节点"):
			u["节点"].modulate = Color(0.6, 0.6, 0.6)

	# 延迟恢复
	await get_tree().create_timer(时长 * 1.5).timeout
	for u in _攻方单位:
		if u.has("节点") and u["节点"].modulate != Color(0.4, 0.4, 0.4):
			u["节点"].modulate = Color(1, 1, 1)
	for u in _守方单位:
		if u.has("节点") and u["节点"].modulate != Color(0.4, 0.4, 0.4):
			u["节点"].modulate = Color(1, 1, 1)

# ============ P2：阵亡动画 ============
func _播放阵亡动画(单位: Dictionary) -> void:
	if 单位.is_empty() or not 单位.has("节点"):
		return

	var 节点: Control = 单位["节点"]
	var 时长: float = 0.8 * (0.5 if _加速 else 1.0)

	# 倒地动画：旋转+下移+淡出
	var tween := create_tween()
	tween.tween_property(节点, "rotation", deg_to_rad(15), 时长 * 0.3)
	tween.parallel().tween_property(节点, "position", 节点.position + Vector2(0, 30), 时长 * 0.5)
	tween.parallel().tween_property(节点, "modulate:a", 0.0, 时长 * 0.7)
	tween.tween_callback(func(): 节点.visible = false)

	# P3性能优化：消散粒子效果（使用对象池，根据加速状态动态调整数量）
	var 阵亡粒子数: int = _阵亡粒子数 if not _加速 else int(_阵亡粒子数 * 0.5)
	for i in range(阵亡粒子数):
		var 粒子: ColorRect = _获取粒子()
		粒子.color = Color(0.7, 0.7, 0.8, 0.8)
		粒子.size = Vector2(6, 6)
		var 单位全局位置: Vector2 = 节点.global_position + Vector2(节点.size.x / 2, 节点.size.y / 2)
		粒子.position = _特效层.to_local(单位全局位置)

		var 角度: float = deg_to_rad(randf() * 360)
		var 距离: float = 80.0 + randf() * 60.0
		var ptween := create_tween()
		ptween.tween_property(粒子, "position", Vector2(
			粒子.position.x + cos(角度) * 距离,
			粒子.position.y + sin(角度) * 距离
		), 时长)
		ptween.parallel().tween_property(粒子, "modulate:a", 0.0, 时长)
		ptween.parallel().tween_property(粒子, "scale", Vector2(0.3, 0.3), 时长)
		ptween.tween_callback(func(): 粒子.visible = false)

# ============ P2：胜负结算画面 ============
func _显示胜负结算(战报: Dictionary) -> void:
	var 胜方: bool = 战报.get("is_win", false)
	var 回合数: int = int(战报.get("round_count", 0))
	var 剩余气血: int = int(战报.get("remaining_hp", 0))

	# 创建结算面板
	var 结算层 := Control.new()
	结算层.name = "BattleResult"
	结算层.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	结算层.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(结算层)

	# 半透明背景
	var 背景 := ColorRect.new()
	背景.color = Color(0, 0, 0, 0.75)
	背景.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	结算层.add_child(背景)

	# 居中容器
	var 容器 := VBoxContainer.new()
	容器.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	容器.custom_minimum_size = Vector2(600, 500)
	容器.alignment = BoxContainer.ALIGNMENT_CENTER
	容器.add_theme_constant_override("separation", 20)
	结算层.add_child(容器)

	# 胜负标题
	var 标题 := Label.new()
	标题.text = "胜 利" if 胜方 else "失 败"
	UITheme.apply_project_font(标题, 96, true)
	标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if 胜方:
		标题.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		标题.add_theme_color_override("font_shadow_color", Color(0.8, 0.5, 0.1, 0.6))
	else:
		标题.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		标题.add_theme_color_override("font_shadow_color", Color(0.5, 0.1, 0.1, 0.6))
	标题.add_theme_constant_override("shadow_offset_x", 4)
	标题.add_theme_constant_override("shadow_offset_y", 4)
	容器.add_child(标题)

	# 分割线
	var 分割线 := ColorRect.new()
	分割线.color = Color(0.7, 0.59, 0.31, 0.5)
	分割线.custom_minimum_size = Vector2(400, 2)
	容器.add_child(分割线)

	# 战斗统计
	var 统计 := VBoxContainer.new()
	统计.alignment = BoxContainer.ALIGNMENT_CENTER
	统计.add_theme_constant_override("separation", 10)
	容器.add_child(统计)

	var 回合标签 := Label.new()
	回合标签.text = "战斗回合：%d" % 回合数
	UITheme.apply_project_font(回合标签, 28, false)
	回合标签.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	回合标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	统计.add_child(回合标签)

	if 胜方:
		var 气血标签 := Label.new()
		气血标签.text = "胜方剩余气血：%d" % 剩余气血
		UITheme.apply_project_font(气血标签, 24, false)
		气血标签.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		气血标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		统计.add_child(气血标签)

	# 奖励区域（预留）
	var 奖励区域 := VBoxContainer.new()
	奖励区域.alignment = BoxContainer.ALIGNMENT_CENTER
	奖励区域.add_theme_constant_override("separation", 8)
	容器.add_child(奖励区域)

	var 奖励标题 := Label.new()
	奖励标题.text = "— 战斗奖励 —"
	UITheme.apply_project_font(奖励标题, 22, false)
	奖励标题.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4))
	奖励标题.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	奖励区域.add_child(奖励标题)

	# 从战报中读取奖励
	var 奖励列表: Array = 战报.get("drop_reward", [])
	if 奖励列表.size() > 0:
		for 奖励 in 奖励列表:
			var 奖励名: String = ""
			var 奖励数: int = 1
			if typeof(奖励) == TYPE_DICTIONARY:
				奖励名 = 奖励.get("名称", 奖励.get("name", "未知"))
				奖励数 = int(奖励.get("数量", 奖励.get("count", 1)))
			else:
				奖励名 = str(奖励)
			var 奖励行 := Label.new()
			奖励行.text = "◆ %s  ×%d" % [奖励名, 奖励数]
			UITheme.apply_project_font(奖励行, 20, false)
			奖励行.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
			奖励行.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			奖励区域.add_child(奖励行)
	else:
		var 无奖励 := Label.new()
		无奖励.text = "（暂无奖励）"
		UITheme.apply_project_font(无奖励, 18, false)
		无奖励.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		无奖励.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		奖励区域.add_child(无奖励)

	# 确认按钮
	var 按钮容器 := HBoxContainer.new()
	按钮容器.alignment = BoxContainer.ALIGNMENT_CENTER
	容器.add_child(按钮容器)

	var 确认按钮 := Button.new()
	确认按钮.text = "确 认"
	确认按钮.custom_minimum_size = Vector2(200, 70)
	UITheme.apply_project_font(确认按钮, 28, true)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.2, 0.3, 0.5)
	btn_normal.set_corner_radius_all(10)
	btn_normal.border_color = Color(0.5, 0.7, 1.0, 0.6)
	btn_normal.set_border_width_all(2)
	确认按钮.add_theme_stylebox_override("normal", btn_normal)
	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.3, 0.4, 0.6)
	确认按钮.add_theme_stylebox_override("hover", btn_hover)
	确认按钮.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	按钮容器.add_child(确认按钮)

	确认按钮.pressed.connect(func():
		结算层.queue_free()
		战斗结束.emit(战报)
	)

	# 入场动画
	结算层.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(结算层, "modulate:a", 1.0, 0.3)

# ============ P2：战斗节奏优化 - 行动指示器 ============
func _显示行动指示器(单位: Dictionary) -> void:
	if 单位.is_empty() or not 单位.has("节点"):
		return

	# 在单位下方显示"行动中"指示器
	var 节点: Control = 单位["节点"]
	var 指示器 := Label.new()
	指示器.text = "▼ 行动中"
	UITheme.apply_project_font(指示器, 16, false)
	指示器.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	指示器.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	指示器.name = "ActionIndicator"

	# 定位到单位下方
	指示器.position = Vector2(节点.size.x / 2 - 50, 节点.size.y + 5)
	节点.add_child(指示器)

	# 闪烁动画
	var 时长: float = 0.6 * (0.5 if _加速 else 1.0)
	var tween := create_tween()
	tween.tween_property(指示器, "modulate:a", 0.3, 时长 * 0.5)
	tween.tween_property(指示器, "modulate:a", 1.0, 时长 * 0.5)
	tween.set_loops()

	# 延迟移除
	await get_tree().create_timer(时长 * 2).timeout
	if is_instance_valid(指示器):
		指示器.queue_free()

# ============ P2：法宝出场特效 ============
func _播放法宝特效(单位: Dictionary, 法宝名: String) -> void:
	if 单位.is_empty() or not 单位.has("节点"):
		return

	var 节点: Control = 单位["节点"]
	var 时长: float = 0.7 * (0.5 if _加速 else 1.0)

	# 法宝光环
	var 光环 := ColorRect.new()
	光环.color = Color(0.9, 0.8, 0.4, 0.0)
	光环.size = Vector2(120, 120)
	var 单位全局位置: Vector2 = 节点.global_position + Vector2(节点.size.x / 2, 节点.size.y / 2)
	光环.position = (_特效层.to_local(单位全局位置)) - Vector2(60, 60)
	_特效层.add_child(光环)

	# 光环旋转+扩散
	var tween := create_tween()
	tween.tween_property(光环, "modulate:a", 0.6, 时长 * 0.2)
	tween.parallel().tween_property(光环, "rotation", deg_to_rad(180), 时长)
	tween.parallel().tween_property(光环, "scale", Vector2(2.0, 2.0), 时长 * 0.6)
	tween.tween_property(光环, "modulate:a", 0.0, 时长 * 0.4)
	tween.tween_callback(光环.queue_free)

	# 法宝名称小字
	var 法宝标签 := Label.new()
	法宝标签.text = "【%s】" % 法宝名
	UITheme.apply_project_font(法宝标签, 24, false)
	法宝标签.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	法宝标签.add_theme_color_override("font_shadow_color", Color(0.5, 0.3, 0.0, 0.8))
	法宝标签.position = (_特效层.to_local(单位全局位置)) - Vector2(100, -80)
	_特效层.add_child(法宝标签)

	var ftween := create_tween()
	ftween.tween_property(法宝标签, "modulate:a", 1.0, 时长 * 0.2)
	ftween.tween_interval(时长 * 0.4)
	ftween.tween_property(法宝标签, "modulate:a", 0.0, 时长 * 0.4)
	ftween.tween_callback(法宝标签.queue_free)

# ============ P2：灵兽协战动画 ============
func _播放灵兽协战(主人单位: Dictionary, 灵兽名: String, 目标单位: Dictionary) -> void:
	if 主人单位.is_empty() or 目标单位.is_empty():
		return

	var 时长: float = 0.5 * (0.5 if _加速 else 1.0)

	# 灵兽名称飘字
	var 灵兽标签 := Label.new()
	灵兽标签.text = "灵兽协战：%s" % 灵兽名
	UITheme.apply_project_font(灵兽标签, 20, false)
	灵兽标签.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	灵兽标签.add_theme_color_override("font_shadow_color", Color(0.0, 0.3, 0.1, 0.8))
	var 主人位置: Vector2 = 主人单位["节点"].global_position + Vector2(主人单位["节点"].size.x / 2, 0)
	灵兽标签.position = (_特效层.to_local(主人位置)) - Vector2(80, 30)
	_特效层.add_child(灵兽标签)

	var tween := create_tween()
	tween.tween_property(灵兽标签, "position", 灵兽标签.position + Vector2(0, -40), 时长)
	tween.parallel().tween_property(灵兽标签, "modulate:a", 0.0, 时长)
	tween.tween_callback(灵兽标签.queue_free)

	# P3性能优化：绿色粒子特效（使用对象池，根据加速状态动态调整数量）
	var 灵兽粒子数: int = _灵兽粒子数 if not _加速 else int(_灵兽粒子数 * 0.5)
	for i in range(灵兽粒子数):
		var 粒子: ColorRect = _获取粒子()
		粒子.color = Color(0.5, 1.0, 0.6, 0.8)
		粒子.size = Vector2(5, 5)
		var 目标位置: Vector2 = 目标单位["节点"].global_position + Vector2(目标单位["节点"].size.x / 2, 目标单位["节点"].size.y / 2)
		粒子.position = _特效层.to_local(目标位置)

		var 角度: float = deg_to_rad(randf() * 360)
		var 距离: float = 40.0 + randf() * 30.0
		var ptween := create_tween()
		ptween.tween_property(粒子, "position", Vector2(
			粒子.position.x + cos(角度) * 距离,
			粒子.position.y + sin(角度) * 距离
		), 时长)
		ptween.parallel().tween_property(粒子, "modulate:a", 0.0, 时长)
		ptween.tween_callback(func(): 粒子.visible = false)
		ptween.tween_callback(粒子.queue_free)
