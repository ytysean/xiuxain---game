extends Control

# 仙玉·供奉页（GameUI 二级页，顶栏🪙按钮入口）：签到 / 兑换 / 月卡 / 限时礼包。
# 读数经 is_instance_valid(Game) + .get() 守卫；操作仅调 Game 公有 API，不改数据层。
# 注意：本文件禁用 `var X := Game.某方法()` 写法（pre_f5 类型推断扫描会判 METHOD_CALL FAIL），
#       一律用显式类型标注（如 `var r: Dictionary = Game.某方法()`）。

signal 返回主页
signal 仙玉变更


var _built: bool = false
var _scroll_vbox: VBoxContainer
var _余额标签: Label
var _反馈标签: Label

# ───────── emoji 收口（2026-09-15 统一）─────────
# 项目铁则：UI 禁拿裸 emoji 字符当图标 —— 现代符号与修真世界观冲突，且字形随系统字体漂移、
# 各平台宽度不一（老大截图：日供页 ◇◆◇ 直接当图标用）。
# 已有资产：art/icons/emoji/ 58 张「圆形金框 + 黛底 + 金线描」由 UITheme.emoji_icon_sized()
# 按像素光栅化；货币类资源图走 load_hd_icon("res_*")。
func _图标文本(文本: String, 图标: String, 字号: int, 颜色: Color, 图标像素: int = 40, 粗体: bool = true) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var tex: Texture2D = null
	if 图标.begins_with("res_") or 图标.begins_with("entry_") or 图标.begins_with("emoji_"):
		tex = UITheme.load_hd_icon(图标)
	else:
		tex = UITheme.emoji_icon_sized(图标, 图标像素)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.custom_minimum_size = Vector2(图标像素, 图标像素)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(tr)
	var lb := Label.new()
	lb.text = 文本
	UITheme.apply_project_font(lb, 字号, 粗体)
	lb.add_theme_color_override("font_color", 颜色)
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(lb)
	return hb

## 单个图标控件（替代「只放 emoji 的图标位」，如礼包卡左侧 72×72 位）
func _图标控件(图标: String, 像素: int) -> Control:
	var tex: Texture2D = null
	if 图标.begins_with("res_") or 图标.begins_with("entry_") or 图标.begins_with("emoji_"):
		tex = UITheme.load_hd_icon(图标)
	else:
		tex = UITheme.emoji_icon_sized(图标, 像素)
	if tex == null:
		return Label.new()
	var tr := TextureRect.new()
	tr.name = "IconTex"
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

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

	# 二级页工业化背景（决策 4 升级：顶部氛围场景图 + 下方不透明纯色内容区）
	var content: Control = UITheme.make_scene_background(self)

	var vbox := VBoxContainer.new()
	vbox.name = "Root"
	vbox.add_theme_constant_override("margin_left", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_right", UITheme.MARGIN)
	vbox.add_theme_constant_override("margin_top", UITheme.GRID)
	vbox.add_theme_constant_override("margin_bottom", UITheme.GRID)
	vbox.add_theme_constant_override("separation", UITheme.GRID * 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(vbox)

	UITheme.make_page_header(vbox, "日供", _on_back_pressed)

	_余额标签 = Label.new()
	_余额标签.name = "Balance"
	UITheme.apply_value_font(_余额标签, false)
	vbox.add_child(_余额标签)

	_反馈标签 = Label.new()
	_反馈标签.name = "Feedback"
	UITheme.apply_aux_font(_反馈标签)
	_反馈标签.add_theme_color_override("font_color", UITheme.color_text_body_dim())
	vbox.add_child(_反馈标签)

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
	_刷新余额()
	if _scroll_vbox == null:
		return
	for child in _scroll_vbox.get_children():
		_scroll_vbox.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		return

	# 日供
	var 日供状态: Dictionary = {}
	if Game.has_method("日供状态"):
		日供状态 = Game.日供状态()
	var 今日可领: bool = bool(日供状态.get("今日可领", true))
	var 连续天数: int = int(日供状态.get("连续天数", 0))
	var 加成列表: Array = 日供状态.get("加成", [])
	var 日供按钮 := PrimaryButton.new()
	日供按钮.text = "领取日供（+30 绑定仙玉）" if 今日可领 else "今日供奉已受领"
	if not 今日可领:
		日供按钮.disabled = true
	日供按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	日供按钮.pressed.connect(_on_领取日供)
	_scroll_vbox.add_child(日供按钮)
	# PH6·M5c：统一刷新时刻口径文案（与 game_state 每日重置小时=8 一致）
	var 日供重置提示 := Label.new()
	日供重置提示.text = "每日 08:00 更替"
	UITheme.apply_aux_font_sized(日供重置提示, UITheme.FONT_AUX)
	_scroll_vbox.add_child(日供重置提示)

	var 状态行 := Label.new()
	状态行.text = "连续理事天数：%d" % 连续天数
	UITheme.apply_aux_text(状态行)
	_scroll_vbox.add_child(状态行)

	var 进度行 := Label.new()
	var 小周天: int = mini(连续天数, 7)
	var 月度: int = mini(连续天数, 30)
	进度行.text = "小周天进度：%d/7　｜　月度道统：%d/30" % [小周天, 月度]
	UITheme.apply_aux_text(进度行)
	_scroll_vbox.add_child(进度行)
	
	# 大厂标准：今日日贡奖励详情（使用新添加的Game.获取今日日贡奖励()）
	if is_instance_valid(Game) and Game.has_method("获取今日日贡奖励"):
		var 今日奖励: Dictionary = Game.获取今日日贡奖励()
		if not 今日奖励.is_empty():
			_scroll_vbox.add_child(_图标文本("今日供奉奖励", "emoji_shop_gift", UITheme.FONT_H2, UITheme.获取金文字色(), 44))
			
			var 奖励详情卡 := PanelContainer.new()
			奖励详情卡.name = "TodayRewardCard"
			奖励详情卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var 奖励卡样式 := StyleBoxFlat.new()
			奖励卡样式.bg_color = UITheme.C01_FLOAT_BG
			奖励卡样式.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
			奖励卡样式.set_border_width_all(1)
			奖励卡样式.border_color = UITheme.C01_GOLD_LINE
			奖励卡样式.set_content_margin_all(UITheme.PAD_PANEL)
			奖励详情卡.add_theme_stylebox_override("panel", 奖励卡样式)
			
			var 奖励详情vbox := VBoxContainer.new()
			奖励详情vbox.name = "RewardDetailVBox"
			奖励详情vbox.add_theme_constant_override("separation", 8)
			奖励详情卡.add_child(奖励详情vbox)
			
			# 连续天数
			var 连续天数列 := Label.new()
			连续天数列.text = "连续供奉：%d日" % int(今日奖励.get("连续天数", 0))
			UITheme.apply_project_font(连续天数列, UITheme.FONT_H2, true)
			连续天数列.add_theme_color_override("font_color", UITheme.获取主文字色())
			奖励详情vbox.add_child(连续天数列)
			
			# 奖励内容
			var 奖励内容hb := HBoxContainer.new()
			奖励内容hb.name = "RewardContentHBox"
			奖励内容hb.add_theme_constant_override("separation", 16)
			奖励详情vbox.add_child(奖励内容hb)
			
			# 灵石奖励
			var 灵石奖励: int = int(今日奖励.get("灵石", 0))
			if 灵石奖励 > 0:
				奖励内容hb.add_child(_图标文本("灵石 +%d" % 灵石奖励, "res_lingshi_36", UITheme.FONT_H2, UITheme.获取金文字色(), 40))
			
			# 灵气奖励
			var 灵气奖励: int = int(今日奖励.get("灵气", 0))
			if 灵气奖励 > 0:
				奖励内容hb.add_child(_图标文本("灵气 +%d" % 灵气奖励, "res_lingqi_36", UITheme.FONT_H2, UITheme.C05_REWARD_BLUE, 40))
			
			# 悟道点奖励
			var 悟道点奖励: int = int(今日奖励.get("悟道点", 0))
			if 悟道点奖励 > 0:
				奖励内容hb.add_child(_图标文本("悟道点 +%d" % 悟道点奖励, "emoji_general_book", UITheme.FONT_H2, Color(0.7, 0.5, 0.9, 1.0), 40))
			
			# 奖励描述
			var 奖励描述: String = str(今日奖励.get("描述", ""))
			if 奖励描述 != "":
				var 描述列 := Label.new()
				描述列.text = 奖励描述
				UITheme.apply_project_font(描述列, UITheme.FONT_BODY, false)
				描述列.add_theme_color_override("font_color", UITheme.获取弱文字色())
				奖励详情vbox.add_child(描述列)
			
			_scroll_vbox.add_child(奖励详情卡)
	
	# 大厂标准：累计签到奖励列表（使用新添加的Game.获取累计签到奖励列表()）
	if is_instance_valid(Game) and Game.has_method("获取累计签到奖励列表"):
		var 累计奖励列表: Array = Game.获取累计签到奖励列表()
		if not 累计奖励列表.is_empty():
			_scroll_vbox.add_child(_图标文本("累计供奉奖励", "emoji_activity_trophy", UITheme.FONT_H2, UITheme.获取金文字色(), 44))
			
			for 累计奖励 in 累计奖励列表:
				var 天数: int = int(累计奖励.get("天数", 0))
				var 已达成: bool = bool(累计奖励.get("已达成", false))
				var 描述: String = str(累计奖励.get("描述", ""))
				
				var 累计奖励卡 := PanelContainer.new()
				累计奖励卡.name = "CumulativeRewardCard_%d" % 天数
				累计奖励卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var 累计卡样式 := StyleBoxFlat.new()
				if 已达成:
					累计卡样式.bg_color = Color(0.12, 0.18, 0.12, 1.0)
					累计卡样式.border_color = UITheme.获取金文字色()
				else:
					累计卡样式.bg_color = UITheme.C01_FLOAT_BG
					累计卡样式.border_color = UITheme.C01_GOLD_LINE
				累计卡样式.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
				累计卡样式.set_border_width_all(1)
				累计卡样式.set_content_margin_all(UITheme.PAD_PANEL)
				累计奖励卡.add_theme_stylebox_override("panel", 累计卡样式)
				
				var 累计奖励hb := HBoxContainer.new()
				累计奖励hb.name = "CumulativeRewardHBox"
				累计奖励hb.add_theme_constant_override("separation", 12)
				累计奖励卡.add_child(累计奖励hb)
				累计奖励hb.modulate.a = 0.0
				累计奖励hb.create_tween().tween_property(累计奖励hb, "modulate:a", 1.0, 0.25)
				
				# 天数图标（达成=日历金框图标 / 未达成=锁形金框图标；原为 ◇/◇ 裸 emoji）
				var _fb1 := _图标控件("emoji_activity_calendar" if 已达成 else "emoji_shop_lock", 40)
				累计奖励hb.add_child(_fb1)
				_fb1.modulate.a = 0.0
				_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
				
				var 累计奖励info := VBoxContainer.new()
				累计奖励info.name = "CumulativeRewardInfo"
				累计奖励info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				累计奖励info.add_theme_constant_override("separation", 4)
				累计奖励hb.add_child(累计奖励info)
				累计奖励info.modulate.a = 0.0
				累计奖励info.create_tween().tween_property(累计奖励info, "modulate:a", 1.0, 0.25)
				
				# 天数标题
				var 天数标题 := Label.new()
				天数标题.text = "连续供奉 %d 日" % 天数
				UITheme.apply_project_font(天数标题, UITheme.FONT_H2, true)
				if 已达成:
					天数标题.add_theme_color_override("font_color", UITheme.获取金文字色())
				else:
					天数标题.add_theme_color_override("font_color", UITheme.获取主文字色())
				累计奖励info.add_child(天数标题)
				天数标题.modulate.a = 0.0
				天数标题.create_tween().tween_property(天数标题, "modulate:a", 1.0, 0.25)
				
				# 奖励描述
				var 累计描述 := Label.new()
				累计描述.text = 描述
				UITheme.apply_project_font(累计描述, UITheme.FONT_BODY, false)
				累计描述.add_theme_color_override("font_color", UITheme.获取弱文字色())
				累计奖励info.add_child(累计描述)
				累计描述.modulate.a = 0.0
				累计描述.create_tween().tween_property(累计描述, "modulate:a", 1.0, 0.25)
				
				# 状态标签
				var 状态标签 := Label.new()
				状态标签.text = "已达成" if 已达成 else "未达成"
				状态标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				状态标签.size_flags_horizontal = Control.SIZE_SHRINK_END
				UITheme.apply_project_font(状态标签, UITheme.FONT_BODY, false)
				if 已达成:
					状态标签.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
				else:
					状态标签.add_theme_color_override("font_color", UITheme.获取弱文字色())
				累计奖励hb.add_child(状态标签)
				状态标签.modulate.a = 0.0
				状态标签.create_tween().tween_property(状态标签, "modulate:a", 1.0, 0.25)
				
				_scroll_vbox.add_child(累计奖励卡)
				累计奖励卡.modulate.a = 0.0
				累计奖励卡.create_tween().tween_property(累计奖励卡, "modulate:a", 1.0, 0.25)

	if 加成列表.size() > 0:
		var 加成头 := Label.new()
		加成头.text = "职司供奉加成"
		UITheme.apply_section_title(加成头)
		_scroll_vbox.add_child(加成头)
		for b in 加成列表:
			var 加成项 := Label.new()
			加成项.text = "%s：%s" % [b.get("堂主", "—"), b.get("描述", "")]
			UITheme.apply_aux_text(加成项)
			_scroll_vbox.add_child(加成项)
			加成项.modulate.a = 0.0
			加成项.create_tween().tween_property(加成项, "modulate:a", 1.0, 0.25)

	# 仙玉兑换（带每日上限）：数据层未就绪时显示为筹备中，按钮置灰
	var 兑换就绪: bool = is_instance_valid(Game) and Game.has_method("仙玉兑换")
	var 兑头 := Label.new()
	兑头.text = "仙玉兑换（每次耗仙玉十枚，有每日限额）"
	UITheme.apply_section_title(兑头)
	_scroll_vbox.add_child(兑头)
	# P2优化：修真化描述
	var 兑换修真名: Dictionary = {
		"灵石": "灵石",
		"战功": "战功",
		"传承积分": "道统传承",
		"宗门贡献": "宗门功勋",
	}
	for 类型 in ["灵石", "战功", "传承积分", "宗门贡献"]:
		var t: Dictionary = XianyuShop.仙玉兑换表.get(类型, {})
		if t.is_empty():
			continue
		var 修真名: String = 兑换修真名.get(类型, 类型)
		var b := Button.new()
		b.text = "以仙玉易%s（十枚仙玉换%d，每日限%d）%s" % [修真名, int(t["率"]), int(t["日上限"]), "（筹备中）" if not 兑换就绪 else ""]
		b.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		b.disabled = not 兑换就绪
		if 兑换就绪:
			b.pressed.connect(_on_兑换.bind(类型))
		_scroll_vbox.add_child(b)
		b.modulate.a = 0.0
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.25)

	# 特权卡系统（月卡/季卡/永久卡）
	var 特权卡头 := Label.new()
	特权卡头.text = "◆ 特权卡"
	UITheme.apply_section_title(特权卡头)
	_scroll_vbox.add_child(特权卡头)

	# 特权卡状态
	var 卡状态行 := Label.new()
	var 月卡有效 = Game.月卡有效() if is_instance_valid(Game) else false
	var 季卡有效 = Game.季卡有效() if is_instance_valid(Game) else false
	var 永久卡有效 = Game.永久卡有效() if is_instance_valid(Game) else false
	var 月卡剩余 = 0
	var 季卡剩余 = 0
	if is_instance_valid(Game):
		if Game.月卡到期日 >= Game.累计游戏日:
			月卡剩余 = Game.月卡到期日 - Game.累计游戏日
		if Game.季卡到期日 >= Game.累计游戏日:
			季卡剩余 = Game.季卡到期日 - Game.累计游戏日
	卡状态行.text = "清修卡(月卡): %s | 悟道卡(季卡): %s | 道统卡(永久): %s" % [
		"有效(%d日)" % 月卡剩余 if 月卡有效 else "未开",
		"有效(%d日)" % 季卡剩余 if 季卡有效 else "未开",
		"已开" if 永久卡有效 else "未开"
	]
	UITheme.apply_aux_text(卡状态行)
	_scroll_vbox.add_child(卡状态行)

	# 月卡购买按钮
	var 月卡按钮 := PrimaryButton.new()
	月卡按钮.text = "清修卡（月卡）- 30仙玉/30日 - 离线+20%、历练+1、一键收取"
	if 月卡有效 and not 永久卡有效:
		月卡按钮.text = "续期清修卡（月卡）- 30仙玉/30日"
	月卡按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	月卡按钮.pressed.connect(_on_购买月卡)
	_scroll_vbox.add_child(月卡按钮)

	# 季卡购买按钮
	var 季卡按钮 := Button.new()
	季卡按钮.text = "悟道卡（季卡）- 80仙玉/90日 - 月卡权益+炼制加速30%+商队+15%"
	if 季卡有效 and not 永久卡有效:
		季卡按钮.text = "续期悟道卡（季卡）- 80仙玉/90日"
	季卡按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	季卡按钮.pressed.connect(_on_购买季卡)
	_scroll_vbox.add_child(季卡按钮)

	# 永久卡购买按钮
	var 永久卡按钮 := Button.new()
	永久卡按钮.text = "道统卡（永久）- 298仙玉 - 全部权益+终身日供翻倍+离线上限十二时辰"
	if 永久卡有效:
		永久卡按钮.text = "道统卡（永久）- 已激活"
		永久卡按钮.disabled = true
	永久卡按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	永久卡按钮.pressed.connect(_on_购买永久卡)
	_scroll_vbox.add_child(永久卡按钮)

	# ===== VIP特权展示（P0新增）=====
	_build_vip_section()

	# S1-4 付费：仙玉购买全局增益(+5%战斗通用增益，共享封顶)
	var 增益btn := PrimaryButton.new()
	增益btn.name = "PayGlobalBuffBtn"
	增益btn.text = "购买全局增益（%d仙玉）" % (Game.付费单价.get("全局增益", 50) if is_instance_valid(Game) else 50)
	增益btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
	增益btn.pressed.connect(_on_付费_全局增益)
	_scroll_vbox.add_child(增益btn)

	# 付费礼包系统
	var 礼包头 := Label.new()
	礼包头.text = "◆ 付费礼包"
	UITheme.apply_section_title(礼包头)
	_scroll_vbox.add_child(礼包头)
	
	# 大厂标准：限时活动礼包（使用新添加的Game.获取限时礼包活动()）
	if is_instance_valid(Game) and Game.has_method("获取限时礼包活动"):
		var 限时活动列表: Array = Game.获取限时礼包活动()
		if not 限时活动列表.is_empty():
			_scroll_vbox.add_child(_图标文本("限时缘法", "emoji_activity_fire", UITheme.FONT_TITLE, Color(1.0, 0.8, 0.4, 1.0), 48))
			
			for 活动礼包 in 限时活动列表:
				var 礼包 = 活动礼包.get("礼包", {})
				var 原价 = int(活动礼包.get("原价", 0))
				var 活动价 = int(活动礼包.get("活动价", 0))
				var 折扣百分比 = int(活动礼包.get("折扣百分比", 0))
				var 剩余天数 = int(活动礼包.get("剩余天数", 0))
				
				var 礼包卡片 = _make_limited_gift_card(礼包, 原价, 活动价, 折扣百分比, 剩余天数)
				_scroll_vbox.add_child(礼包卡片)
				礼包卡片.modulate.a = 0.0
				礼包卡片.create_tween().tween_property(礼包卡片, "modulate:a", 1.0, 0.25)

	if is_instance_valid(Game):
		for 礼包 in Game.礼包配置:
			var 礼包ID = 礼包["id"]
			var 已购次数 = Game.已购买礼包.get(礼包ID, 0)
			var 限购 = 礼包["限购"]
			var 可购买 = 已购次数 < 限购
			if 礼包.get("每日重置", false) and Game.每日礼包购买日 != Game.累计游戏日:
				可购买 = true
			var 礼包按钮 := Button.new()
			礼包按钮.text = "%s - %d仙玉 - %s (%d/%d)" % [
				礼包["名称"], 礼包["价格"], 礼包["描述"],
				已购次数 if 可购买 else 限购, 限购
			]
			礼包按钮.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
			礼包按钮.disabled = not 可购买
			if 可购买:
				礼包按钮.pressed.connect(_on_购买礼包.bind(礼包ID))
			_scroll_vbox.add_child(礼包按钮)
			礼包按钮.modulate.a = 0.0
			礼包按钮.create_tween().tween_property(礼包按钮, "modulate:a", 1.0, 0.25)

func _刷新余额() -> void:
	if _余额标签 != null and is_instance_valid(Game):
		var 绑定: int = 0
		var 非绑定: int = 0
		if Game.get("仙玉_绑定") != null:
			绑定 = int(Game.仙玉_绑定)
		if Game.get("仙玉_非绑定") != null:
			非绑定 = int(Game.仙玉_非绑定)
		_余额标签.text = "绑定仙玉：%d　｜　仙玉：%d" % [绑定, 非绑定]

func _反馈(文本: String) -> void:
	if _反馈标签 != null:
		_反馈标签.text = 文本

func _on_领取日供() -> void:
	if not is_instance_valid(Game) or not Game.has_method("领取日供"):
		_反馈("天机未定，稍后再观")
		return
	var r: Dictionary = Game.领取日供()
	_反馈(str(r.get("msg", "—")))
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_兑换(类型: String) -> void:
	if not is_instance_valid(Game) or not Game.has_method("仙玉兑换"):
		_反馈("天机未定，稍后再观")
		return
	var r: Dictionary = Game.仙玉兑换(类型, 10)
	_反馈(str(r.get("msg", "—")))
	_刷新余额()
	仙玉变更.emit()

func _on_购买月卡() -> void:
	if not is_instance_valid(Game):
		_反馈("天机未定，稍后再观")
		return
	# 检查仙玉
	if Game.仙玉_绑定 < 30 and Game.仙玉_非绑定 < 30:
		_反馈("仙玉匮乏，需要30仙玉")
		return
	# 扣除仙玉（优先绑定）
	if Game.仙玉_绑定 >= 30:
		Game.仙玉_绑定 -= 30
	else:
		Game.仙玉_非绑定 -= (30 - Game.仙玉_绑定)
		Game.仙玉_绑定 = 0
	Game.激活月卡(30)
	_反馈("清修卡（月卡）激活成功，有效期30日")
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_购买季卡() -> void:
	if not is_instance_valid(Game):
		_反馈("天机未定，稍后再观")
		return
	if Game.仙玉_绑定 < 80 and Game.仙玉_非绑定 < 80:
		_反馈("仙玉匮乏，需要80仙玉")
		return
	if Game.仙玉_绑定 >= 80:
		Game.仙玉_绑定 -= 80
	else:
		Game.仙玉_非绑定 -= (80 - Game.仙玉_绑定)
		Game.仙玉_绑定 = 0
	Game.激活季卡(90)
	_反馈("悟道卡（季卡）激活成功，有效期90日")
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_购买永久卡() -> void:
	if not is_instance_valid(Game):
		_反馈("天机未定，稍后再观")
		return
	if Game.永久卡有效():
		_反馈("道统卡已激活")
		return
	if Game.仙玉_绑定 < 298 and Game.仙玉_非绑定 < 298:
		_反馈("仙玉匮乏，需要298仙玉")
		return
	if Game.仙玉_绑定 >= 298:
		Game.仙玉_绑定 -= 298
	else:
		Game.仙玉_非绑定 -= (298 - Game.仙玉_绑定)
		Game.仙玉_绑定 = 0
	Game.激活永久卡()
	_反馈("道统卡（永久）激活成功，终身享受所有权益！")
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_购买礼包(礼包ID: String) -> void:
	if not is_instance_valid(Game):
		_反馈("天机未定，稍后再观")
		return
	var 礼包 = null
	for g in Game.礼包配置:
		if g["id"] == 礼包ID:
			礼包 = g
			break
	if 礼包 == null:
		_反馈("未知礼包")
		return
	var 价格 = 礼包["价格"]
	if Game.仙玉_绑定 < 价格 and Game.仙玉_非绑定 < 价格:
		_反馈("仙玉匮乏，需要%d仙玉" % 价格)
		return
	if Game.仙玉_绑定 >= 价格:
		Game.仙玉_绑定 -= 价格
	else:
		Game.仙玉_非绑定 -= (价格 - Game.仙玉_绑定)
		Game.仙玉_绑定 = 0
	var 结果 = Game.购买礼包(礼包ID)
	_反馈(str(结果.get("消息", "购买成功")))
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_back_pressed() -> void:
	返回主页.emit()

# 大厂标准：限时活动礼包卡片（带原价、活动价、折扣标签、限时标签）
func _make_limited_gift_card(礼包: Dictionary, 原价: int, 活动价: int, 折扣百分比: int, 剩余天数: int) -> Control:
	var card := PanelContainer.new()
	card.name = "LimitedGiftCard"
	card.custom_minimum_size = Vector2(0, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.12, 0.2, 1.0)
	card_style.border_color = Color(0.7, 0.4, 0.9, 1.0)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.set_corner_radius_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	
	var hb := HBoxContainer.new()
	hb.name = "CardHBox"
	hb.add_theme_constant_override("separation", 12)
	card.add_child(hb)
	hb.modulate.a = 0.0
	hb.create_tween().tween_property(hb, "modulate:a", 1.0, 0.25)
	
	# 图标区域
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(72, 72)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.1, 0.08, 0.15, 1.0)
	icon_style.set_corner_radius_all(10)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	# 图标位：改用「圆形金框礼盒」资产（原为 ◇ 裸 emoji，字形随系统字体漂移）
	var _fb2 := _图标控件("emoji_shop_gift", 60)
	icon_panel.add_child(_fb2)
	_fb2.modulate.a = 0.0
	_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
	hb.add_child(icon_panel)
	icon_panel.modulate.a = 0.0
	icon_panel.create_tween().tween_property(icon_panel, "modulate:a", 1.0, 0.25)
	
	# 信息区域
	var info := VBoxContainer.new()
	info.name = "InfoVBox"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	info.modulate.a = 0.0
	info.create_tween().tween_property(info, "modulate:a", 1.0, 0.25)
	
	# 礼包名称和限时标签
	var name_hb := HBoxContainer.new()
	name_hb.name = "NameHBox"
	name_hb.add_theme_constant_override("separation", 8)
	info.add_child(name_hb)
	name_hb.modulate.a = 0.0
	name_hb.create_tween().tween_property(name_hb, "modulate:a", 1.0, 0.25)
	
	var name_label := Label.new()
	name_label.name = "GiftName"
	name_label.text = str(礼包.get("名称", "未知礼包"))
	UITheme.apply_project_font(name_label, UITheme.FONT_H2, true)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0, 1.0))
	name_hb.add_child(name_label)
	name_label.modulate.a = 0.0
	name_label.create_tween().tween_property(name_label, "modulate:a", 1.0, 0.25)
	
	if 剩余天数 > 0:
		var limited_badge := PanelContainer.new()
		limited_badge.name = "LimitedBadge"
		limited_badge.custom_minimum_size = Vector2(56, 20)
		var limited_style := StyleBoxFlat.new()
		limited_style.bg_color = Color(0.95, 0.6, 0.1, 1.0)
		limited_style.set_corner_radius_all(4)
		limited_badge.add_theme_stylebox_override("panel", limited_style)
		
		var limited_label := Label.new()
		limited_label.name = "LimitedLabel"
		limited_label.text = "剩%d日" % 剩余天数
		limited_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		limited_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_project_font(limited_label, UITheme.FONT_BODY, false)
		limited_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		limited_badge.add_child(limited_label)
		limited_label.modulate.a = 0.0
		limited_label.create_tween().tween_property(limited_label, "modulate:a", 1.0, 0.25)
		name_hb.add_child(limited_badge)
		limited_badge.modulate.a = 0.0
		limited_badge.create_tween().tween_property(limited_badge, "modulate:a", 1.0, 0.25)
	
	# 礼包描述
	var desc_label := Label.new()
	desc_label.name = "GiftDesc"
	desc_label.text = str(礼包.get("描述", ""))
	UITheme.apply_project_font(desc_label, UITheme.FONT_BODY, false)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	info.add_child(desc_label)
	desc_label.modulate.a = 0.0
	desc_label.create_tween().tween_property(desc_label, "modulate:a", 1.0, 0.25)
	
	# 价格区域
	var price_hb := HBoxContainer.new()
	price_hb.name = "PriceHBox"
	price_hb.add_theme_constant_override("separation", 8)
	info.add_child(price_hb)
	price_hb.modulate.a = 0.0
	price_hb.create_tween().tween_property(price_hb, "modulate:a", 1.0, 0.25)
	
	# 活动价：仙玉图标（res_xianyu_36）+ 数字（原为「◇ %d」裸 emoji 前缀）
	var _fb3 := _图标文本("%d" % 活动价, "res_xianyu_36", UITheme.FONT_TITLE, Color(1.0, 0.8, 0.4, 1.0), 44)
	price_hb.add_child(_fb3)
	_fb3.modulate.a = 0.0
	_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
	
	# 原价（划线）
	if 原价 > 活动价:
		var original_price := Label.new()
		original_price.name = "OriginalPrice"
		original_price.text = "%d" % 原价
		UITheme.apply_project_font(original_price, UITheme.FONT_H2, true)
		original_price.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		price_hb.add_child(original_price)
		original_price.modulate.a = 0.0
		original_price.create_tween().tween_property(original_price, "modulate:a", 1.0, 0.25)
	
	# 折扣标签
	if 折扣百分比 > 0:
		var discount_badge := PanelContainer.new()
		discount_badge.name = "DiscountBadge"
		discount_badge.custom_minimum_size = Vector2(48, 20)
		var discount_style := StyleBoxFlat.new()
		discount_style.bg_color = Color(0.9, 0.2, 0.2, 1.0)
		discount_style.set_corner_radius_all(4)
		discount_badge.add_theme_stylebox_override("panel", discount_style)
		
		var discount_label := Label.new()
		discount_label.name = "DiscountLabel"
		discount_label.text = "-%d%%" % 折扣百分比
		discount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		discount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.apply_project_font(discount_label, UITheme.FONT_BODY, false)
		discount_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		discount_badge.add_child(discount_label)
		discount_label.modulate.a = 0.0
		discount_label.create_tween().tween_property(discount_label, "modulate:a", 1.0, 0.25)
		price_hb.add_child(discount_badge)
		discount_badge.modulate.a = 0.0
		discount_badge.create_tween().tween_property(discount_badge, "modulate:a", 1.0, 0.25)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "立即请购"
	buy_btn.custom_minimum_size = Vector2(0, 36)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	var btn_style_normal := StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.7, 0.3, 0.9, 1.0)
	btn_style_normal.set_corner_radius_all(8)
	buy_btn.add_theme_stylebox_override("normal", btn_style_normal)
	var btn_style_hover := StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.75, 0.35, 0.95, 1.0)
	btn_style_hover.set_corner_radius_all(8)
	buy_btn.add_theme_stylebox_override("hover", btn_style_hover)
	buy_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	UITheme.apply_project_font(buy_btn, UITheme.FONT_H2, true)
	var 礼包ID = str(礼包.get("id", ""))
	buy_btn.pressed.connect(_on_购买礼包.bind(礼包ID))
	info.add_child(buy_btn)
	buy_btn.modulate.a = 0.0
	buy_btn.create_tween().tween_property(buy_btn, "modulate:a", 1.0, 0.25)
	
	return card


# S1-4 付费：仙玉购买全局增益（调用 Game._pay_reserved_全局增益）
func _on_付费_全局增益() -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_全局增益()
	if r.get("成功", false):
		var g: float = float(r.get("当前增益", 0.0)) * 100.0
		UIHint.show_hint(self, "全局增益+5%", "战斗通用增益提升至 %.0f%%" % g)
		Game.添加提示("全局增益+5%")
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
		Game.添加提示("仙玉匮乏")
	refresh()

# ===== VIP特权展示（P0新增）=====
func _build_vip_section() -> void:
	if not is_instance_valid(Game):
		return
	if not Game.has_method("获取VIP统计") or not Game.has_method("get_vip_benefits"):
		return

	var 统计: Dictionary = Game.获取VIP统计()
	var 权益: Dictionary = Game.get_vip_benefits()
	var 当前等级: int = int(统计.get("当前等级", 0))
	var 下一等级: int = int(统计.get("下一等级", 1))
	var 累充额: int = int(统计.get("累充额", 0))
	var 下一级金额: int = int(统计.get("下一级金额", 0))
	var 升级进度: float = float(统计.get("升级进度", 0.0))
	var 离线上限: int = int(统计.get("离线上限小时", 8))
	var 机缘加成: float = float(统计.get("机缘加成", 0.0))

	# VIP标题
	var vip头 := Label.new()
	vip头.text = "◆ 仙阶礼遇 · 第 %d 阶" % 当前等级
	UITheme.apply_section_title(vip头)
	vip头.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	_scroll_vbox.add_child(vip头)

	# VIP等级卡片
	var vip卡 := PanelContainer.new()
	vip卡.name = "VIPCard"
	vip卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vip卡样式 := StyleBoxFlat.new()
	vip卡样式.bg_color = Color(0.15, 0.12, 0.08, 0.9)
	vip卡样式.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	vip卡样式.set_border_width_all(2)
	vip卡样式.border_color = Color(0.7, 0.55, 0.3)
	vip卡样式.set_content_margin_all(UITheme.PAD_PANEL)
	vip卡.add_theme_stylebox_override("panel", vip卡样式)

	var vip卡vbox := VBoxContainer.new()
	vip卡vbox.name = "VIPCardVBox"
	vip卡vbox.add_theme_constant_override("separation", 8)
	vip卡.add_child(vip卡vbox)

	# 等级展示行
	var 等级行 := HBoxContainer.new()
	等级行.add_theme_constant_override("separation", 16)
	vip卡vbox.add_child(等级行)

	var 当前等级label := Label.new()
	当前等级label.text = "当前仙阶：第 %d 阶" % 当前等级
	UITheme.apply_project_font(当前等级label, UITheme.FONT_TITLE, true)
	当前等级label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	等级行.add_child(当前等级label)

	var 累充label := Label.new()
	累充label.text = "累充：%d元" % 累充额
	UITheme.apply_project_font(累充label, UITheme.FONT_H2, true)
	累充label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	等级行.add_child(累充label)

	# 升级进度条
	if 当前等级 < 12:
		var 进度label := Label.new()
		进度label.text = "距第 %d 阶还需%d元（%.0f%%）" % [下一等级, max(0, 下一级金额 - 累充额), 升级进度 * 100]
		UITheme.apply_project_font(进度label, UITheme.FONT_BODY, false)
		进度label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
		vip卡vbox.add_child(进度label)

		var 进度条 := ProgressBar.new()
		进度条.min_value = 0.0
		进度条.max_value = 1.0
		进度条.value = clamp(升级进度, 0.0, 1.0)
		进度条.custom_minimum_size = Vector2(0, 12)
		# fill/background 继承 main_theme.tres 的 ProgressBar 默认（门禁「进度条单源化」）
		vip卡vbox.add_child(进度条)
	else:
		var 已满级label := Label.new()
		已满级label.text = "★ 已达最高仙阶 ★"
		UITheme.apply_project_font(已满级label, UITheme.FONT_H2, true)
		已满级label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		已满级label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vip卡vbox.add_child(已满级label)

	# 核心权益概览
	var 权益概览行 := HBoxContainer.new()
	权益概览行.add_theme_constant_override("separation", 20)
	vip卡vbox.add_child(权益概览行)

	var 离线label := Label.new()
	离线label.text = "离线上限：%d小时" % 离线上限
	UITheme.apply_project_font(离线label, UITheme.FONT_BODY, false)
	离线label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	权益概览行.add_child(离线label)

	var 机缘label := Label.new()
	机缘label.text = "机缘加成：+%d%%" % int(机缘加成 * 100)
	UITheme.apply_project_font(机缘label, UITheme.FONT_BODY, false)
	机缘label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	权益概览行.add_child(机缘label)

	var 倍率label := Label.new()
	倍率label.text = "战斗倍速：%.0fx" % float(统计.get("战斗倍率", 1.0))
	UITheme.apply_project_font(倍率label, UITheme.FONT_BODY, false)
	倍率label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
	权益概览行.add_child(倍率label)

	_scroll_vbox.add_child(vip卡)

	# 已解锁权益列表
	var 已解锁: Array = 权益.get("已解锁权益", [])
	if 已解锁.size() > 0:
		var 已解锁头 := Label.new()
		已解锁头.text = "【已解锁礼遇】"
		UITheme.apply_project_font(已解锁头, UITheme.FONT_H2, true)
		已解锁头.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		_scroll_vbox.add_child(已解锁头)

		var 权益网格 := GridContainer.new()
		权益网格.columns = 2
		权益网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		权益网格.add_theme_constant_override("h_separation", 12)
		权益网格.add_theme_constant_override("v_separation", 4)
		for 权 in 已解锁:
			var 权label := Label.new()
			权label.text = str(权)
			UITheme.apply_project_font(权label, UITheme.FONT_BODY, false)
			权label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7))
			权益网格.add_child(权label)
			权label.modulate.a = 0.0
			权label.create_tween().tween_property(权label, "modulate:a", 1.0, 0.25)
		_scroll_vbox.add_child(权益网格)

	# 下一等级权益预览
	if 当前等级 < 12:
		var 下一级权益: Array = 权益.get("下一等级权益", [])
		if 下一级权益.size() > 0:
			var 下一级头 := Label.new()
			下一级头.text = "【第 %d 阶新增礼遇】" % 下一等级
			UITheme.apply_project_font(下一级头, UITheme.FONT_H2, true)
			下一级头.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
			_scroll_vbox.add_child(下一级头)

			for 权 in 下一级权益:
				var 权label := Label.new()
				权label.text = "○ %s" % str(权)
				UITheme.apply_project_font(权label, UITheme.FONT_BODY, false)
				权label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
				_scroll_vbox.add_child(权label)
				权label.modulate.a = 0.0
				权label.create_tween().tween_property(权label, "modulate:a", 1.0, 0.25)

	# 充值引导按钮
	if 当前等级 < 12:
		var 充值引导btn := PrimaryButton.new()
		充值引导btn.text = "提升仙阶（还需%d元）" % max(0, 下一级金额 - 累充额)
		充值引导btn.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		充值引导btn.pressed.connect(_on_vip_recharge_guide)
		_scroll_vbox.add_child(充值引导btn)

	# ===== P1新增：4个功能 =====
	_build_vip_activities()
	_build_vip_appearance()
	_build_vip_comparison()
	_build_recharge_recommendation()

# VIP充值引导
func _on_vip_recharge_guide() -> void:
	if not is_instance_valid(Game):
		return
	var 统计: Dictionary = Game.获取VIP统计()
	var 当前等级: int = int(统计.get("当前等级", 0))
	var 下一等级: int = int(统计.get("下一等级", 1))
	var 下一级金额: int = int(统计.get("下一级金额", 0))
	var 累充额: int = int(统计.get("累充额", 0))
	var 还需: int = max(0, 下一级金额 - 累充额)
	UIHint.show_hint(self, "仙阶提升", "累计充值%d元即可晋升第 %d 阶\n当前累充：%d元\n还需：%d元" % [下一级金额, 下一等级, 累充额, 还需])
	Game.添加提示("仙阶提升")

# ===== P1：VIP专属活动入口 =====
func _build_vip_activities() -> void:
	if not is_instance_valid(Game):
		return
	var 当前等级: int = Game.当前VIP等级()

	# 标题
	var 活动头 := Label.new()
	活动头.text = "◆ 仙阶专属活动"
	UITheme.apply_section_title(活动头)
	活动头.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35))
	_scroll_vbox.add_child(活动头)

	# VIP专属活动列表
	var 活动列表: Array = [
		{"名称": "每日仙阶礼遇", "描述": "仙阶每日奖励领取", "最低VIP": 1, "入口": "日供"},
		{"名称": "仙阶缘法礼包", "描述": "仙阶专属让利礼包", "最低VIP": 3, "入口": "礼包"},
		{"名称": "仙阶双倍日供", "描述": "永久卡用户日供翻倍", "最低VIP": 6, "入口": "日供"},
		{"名称": "仙阶专属秘境", "描述": "高阶仙阶专属秘境探索", "最低VIP": 9, "入口": "历练"},
		{"名称": "仙阶专属拍卖", "描述": "高阶仙阶专属拍卖场次", "最低VIP": 10, "入口": "拍卖行"},
	]

	for 活动 in 活动列表:
		var 最低VIP: int = int(活动.get("最低VIP", 1))
		var 已解锁: bool = 当前等级 >= 最低VIP

		var 活动卡 := PanelContainer.new()
		活动卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var 活动卡样式 := StyleBoxFlat.new()
		活动卡样式.bg_color = Color(0.12, 0.10, 0.08, 0.8) if 已解锁 else Color(0.08, 0.08, 0.08, 0.6)
		活动卡样式.set_corner_radius_all(8)
		活动卡样式.set_border_width_all(1)
		活动卡样式.border_color = Color(0.6, 0.5, 0.3) if 已解锁 else Color(0.3, 0.3, 0.3)
		活动卡样式.set_content_margin_all(12)
		活动卡.add_theme_stylebox_override("panel", 活动卡样式)

		var 活动hb := HBoxContainer.new()
		活动hb.add_theme_constant_override("separation", 12)
		活动卡.add_child(活动hb)
		活动hb.modulate.a = 0.0
		活动hb.create_tween().tween_property(活动hb, "modulate:a", 1.0, 0.25)

		var 活动信息vbox := VBoxContainer.new()
		活动信息vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		活动hb.add_child(活动信息vbox)
		活动信息vbox.modulate.a = 0.0
		活动信息vbox.create_tween().tween_property(活动信息vbox, "modulate:a", 1.0, 0.25)

		var 活动名称label := Label.new()
		活动名称label.text = "%s%s" % [str(活动.get("名称", "")), "" if 已解锁 else "（未开启）"]
		UITheme.apply_project_font(活动名称label, UITheme.FONT_H2, true)
		活动名称label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.5) if 已解锁 else Color(0.5, 0.5, 0.5))
		活动信息vbox.add_child(活动名称label)
		活动名称label.modulate.a = 0.0
		活动名称label.create_tween().tween_property(活动名称label, "modulate:a", 1.0, 0.25)

		var 活动描述label := Label.new()
		活动描述label.text = "%s（需第 %d 阶）" % [str(活动.get("描述", "")), 最低VIP]
		UITheme.apply_project_font(活动描述label, UITheme.FONT_BODY, false)
		活动描述label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
		活动信息vbox.add_child(活动描述label)
		活动描述label.modulate.a = 0.0
		活动描述label.create_tween().tween_property(活动描述label, "modulate:a", 1.0, 0.25)

		_scroll_vbox.add_child(活动卡)
		活动卡.modulate.a = 0.0
		活动卡.create_tween().tween_property(活动卡, "modulate:a", 1.0, 0.25)

# ===== P1：VIP专属外观预览 =====
func _build_vip_appearance() -> void:
	if not is_instance_valid(Game):
		return
	var 当前等级: int = Game.当前VIP等级()

	# 标题
	var 外观头 := Label.new()
	外观头.text = "◆ 仙阶专属外观"
	UITheme.apply_section_title(外观头)
	外观头.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35))
	_scroll_vbox.add_child(外观头)

	# 宗主头像专属外观
	var 头像头 := Label.new()
	头像头.text = "【宗主头像】"
	UITheme.apply_project_font(头像头, UITheme.FONT_BODY, false)
	头像头.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	_scroll_vbox.add_child(头像头)

	# VIP专属头像列表（基于宗主头像目录中的unlock类别）
	var vip头像: Array = [
		{"名称": "幽冢剑客/仙子", "最低VIP": 4, "渠道": "秘境探索"},
		{"名称": "驭兽灵修/仙姬", "最低VIP": 5, "渠道": "秘境探索"},
		{"名称": "星陨道君/灵姬", "最低VIP": 6, "渠道": "秘境探索"},
		{"名称": "幽冥修士/玄女", "最低VIP": 7, "渠道": "秘境探索"},
		{"名称": "丹霞道君/仙姬", "最低VIP": 8, "渠道": "秘境探索"},
		{"名称": "寒玉真君/冰仙", "最低VIP": 9, "渠道": "秘境探索"},
		{"名称": "太宗主尊/凤尊", "最低VIP": 10, "渠道": "宗门晋升"},
		{"名称": "太上玄翁/玄姬", "最低VIP": 11, "渠道": "宗门晋升"},
		{"名称": "护法神将", "最低VIP": 12, "渠道": "宗门晋升"},
	]

	var 头像网格 := GridContainer.new()
	头像网格.columns = 2
	头像网格.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	头像网格.add_theme_constant_override("h_separation", 8)
	头像网格.add_theme_constant_override("v_separation", 4)

	for 头像 in vip头像:
		var 最低VIP: int = int(头像.get("最低VIP", 1))
		var 已解锁: bool = 当前等级 >= 最低VIP
		var 头像label := Label.new()
		头像label.text = "%s（第 %d 阶）%s" % [str(头像.get("名称", "")), 最低VIP, "" if 已解锁 else " 未开启"]
		UITheme.apply_project_font(头像label, UITheme.FONT_BODY, false)
		头像label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55) if 已解锁 else Color(0.45, 0.45, 0.45))
		头像网格.add_child(头像label)
		头像label.modulate.a = 0.0
		头像label.create_tween().tween_property(头像label, "modulate:a", 1.0, 0.25)

	_scroll_vbox.add_child(头像网格)

	# 宗门外观专属
	var 宗门外观头 := Label.new()
	宗门外观头.text = "【宗门外观】"
	UITheme.apply_project_font(宗门外观头, UITheme.FONT_BODY, false)
	宗门外观头.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
	_scroll_vbox.add_child(宗门外观头)

	var 宗门外观列表: Array = [
		{"名称": "青竹别院", "最低VIP": 1, "描述": "基础宗门外观"},
		{"名称": "紫云仙府", "最低VIP": 4, "描述": "第 4 阶专属宗门外观"},
		{"名称": "九霄天宫", "最低VIP": 7, "描述": "第 7 阶专属宗门外观"},
		{"名称": "太玄圣殿", "最低VIP": 10, "描述": "第 10 阶专属宗门外观"},
	]

	for 外观 in 宗门外观列表:
		var 最低VIP: int = int(外观.get("最低VIP", 1))
		var 已解锁: bool = 当前等级 >= 最低VIP
		var 外观label := Label.new()
		外观label.text = "%s - %s（第 %d 阶）%s" % [str(外观.get("名称", "")), str(外观.get("描述", "")), 最低VIP, "" if 已解锁 else " 未开启"]
		UITheme.apply_project_font(外观label, UITheme.FONT_BODY, false)
		外观label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55) if 已解锁 else Color(0.45, 0.45, 0.45))
		_scroll_vbox.add_child(外观label)
		外观label.modulate.a = 0.0
		外观label.create_tween().tween_property(外观label, "modulate:a", 1.0, 0.25)

# ===== P1：VIP等级对比表 =====
func _build_vip_comparison() -> void:
	if not is_instance_valid(Game):
		return
	var 当前等级: int = Game.当前VIP等级()

	# 标题
	var 对比头 := Label.new()
	对比头.text = "◆ 仙阶礼遇对比"
	UITheme.apply_section_title(对比头)
	对比头.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35))
	_scroll_vbox.add_child(对比头)

	# 对比表
	var 对比表 := GridContainer.new()
	对比表.columns = 5
	对比表.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	对比表.add_theme_constant_override("h_separation", 4)
	对比表.add_theme_constant_override("v_separation", 2)

	# 表头
	var 表头: Array = ["仙阶", "离线上限", "机缘加成", "战斗倍速", "核心礼遇"]
	for 头 in 表头:
		var 头label := Label.new()
		头label.text = str(头)
		UITheme.apply_project_font(头label, UITheme.FONT_BODY, false)
		头label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		头label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		对比表.add_child(头label)
		头label.modulate.a = 0.0
		头label.create_tween().tween_property(头label, "modulate:a", 1.0, 0.25)

	# 对比数据
	var 对比数据: Array = [
		{"等级": 0, "离线": "8h", "机缘": "0%", "倍速": "1x", "礼遇": "基础功能"},
		{"等级": 3, "离线": "8h", "机缘": "0%", "倍速": "2x", "礼遇": "背包扩容/跳过战斗"},
		{"等级": 6, "离线": "12h", "机缘": "0%", "倍速": "2x", "礼遇": "炼制加成/商队加成"},
		{"等级": 9, "离线": "24h", "机缘": "20%", "倍速": "3x", "礼遇": "自动熔炼/专属皮肤"},
		{"等级": 12, "离线": "48h", "机缘": "50%", "倍速": "3x", "礼遇": "全功能解锁/专属客服"},
	]

	for 数据 in 对比数据:
		var 等级: int = int(数据.get("等级", 0))
		var 是当前: bool = 等级 == 当前等级

		var 等级label := Label.new()
		等级label.text = "第 %d 阶%s" % [等级, " ←当前" if 是当前 else ""]
		UITheme.apply_project_font(等级label, UITheme.FONT_AUX, false)
		等级label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5) if 是当前 else Color(0.7, 0.7, 0.65))
		等级label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		对比表.add_child(等级label)
		等级label.modulate.a = 0.0
		等级label.create_tween().tween_property(等级label, "modulate:a", 1.0, 0.25)

		var 离线label := Label.new()
		离线label.text = str(数据.get("离线", ""))
		UITheme.apply_project_font(离线label, UITheme.FONT_AUX, false)
		离线label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.7))
		离线label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		对比表.add_child(离线label)
		离线label.modulate.a = 0.0
		离线label.create_tween().tween_property(离线label, "modulate:a", 1.0, 0.25)

		var 机缘label := Label.new()
		机缘label.text = str(数据.get("机缘", ""))
		UITheme.apply_project_font(机缘label, UITheme.FONT_AUX, false)
		机缘label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
		机缘label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		对比表.add_child(机缘label)
		机缘label.modulate.a = 0.0
		机缘label.create_tween().tween_property(机缘label, "modulate:a", 1.0, 0.25)

		var 倍速label := Label.new()
		倍速label.text = str(数据.get("倍速", ""))
		UITheme.apply_project_font(倍速label, UITheme.FONT_AUX, false)
		倍速label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6))
		倍速label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		对比表.add_child(倍速label)
		倍速label.modulate.a = 0.0
		倍速label.create_tween().tween_property(倍速label, "modulate:a", 1.0, 0.25)

		var 礼遇label := Label.new()
		礼遇label.text = str(数据.get("礼遇", ""))
		UITheme.apply_project_font(礼遇label, UITheme.FONT_AUX, false)
		礼遇label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.6))
		对比表.add_child(礼遇label)
		礼遇label.modulate.a = 0.0
		礼遇label.create_tween().tween_property(礼遇label, "modulate:a", 1.0, 0.25)

	_scroll_vbox.add_child(对比表)

# ===== P1：充值套餐推荐 =====
func _build_recharge_recommendation() -> void:
	if not is_instance_valid(Game):
		return
	var 统计: Dictionary = Game.获取VIP统计()
	var 当前等级: int = int(统计.get("当前等级", 0))
	var 累充额: int = int(统计.get("累充额", 0))
	var 下一级金额: int = int(统计.get("下一级金额", 0))

	# 标题
	var 推荐头 := Label.new()
	推荐头.text = "◆ 充值套餐推荐"
	UITheme.apply_section_title(推荐头)
	推荐头.add_theme_color_override("font_color", Color(0.85, 0.65, 0.35))
	_scroll_vbox.add_child(推荐头)

	# 推荐套餐
	var 推荐套餐: Array = []
	if 当前等级 < 12:
		var 还需: int = max(0, 下一级金额 - 累充额)
		# 根据还需金额推荐最合适的套餐
		if 还需 <= 6:
			推荐套餐.append({"名称": "6元套餐", "价格": 6, "仙玉": 60, "推荐": "刚好晋升第 %d 阶" % min(当前等级 + 1, 12)})
		elif 还需 <= 30:
			推荐套餐.append({"名称": "30元套餐", "价格": 30, "仙玉": 300, "推荐": "刚好晋升第 %d 阶" % min(当前等级 + 1, 12)})
		elif 还需 <= 68:
			推荐套餐.append({"名称": "68元套餐", "价格": 68, "仙玉": 680, "推荐": "刚好晋升第 %d 阶" % min(当前等级 + 1, 12)})
		elif 还需 <= 128:
			推荐套餐.append({"名称": "128元套餐", "价格": 128, "仙玉": 1280, "推荐": "刚好晋升第 %d 阶" % min(当前等级 + 1, 12)})
		elif 还需 <= 298:
			推荐套餐.append({"名称": "298元套餐", "价格": 298, "仙玉": 2980, "推荐": "刚好晋升第 %d 阶，含永久卡" % min(当前等级 + 1, 12)})
		else:
			推荐套餐.append({"名称": "648元套餐", "价格": 648, "仙玉": 6480, "推荐": "大额充值，快速提升仙阶"})
			推荐套餐.append({"名称": "12888元套餐", "价格": 12888, "仙玉": 128880, "推荐": "直达第 12 阶，全功能解锁"})

	# 热门套餐（始终显示）
	推荐套餐.append({"名称": "月卡（清修卡）", "价格": 30, "仙玉": 300, "推荐": "30天离线+20%、历练+1、一键收取"})
	推荐套餐.append({"名称": "季卡（悟道卡）", "价格": 80, "仙玉": 800, "推荐": "90天炼制+30%、商队+15%"})
	推荐套餐.append({"名称": "永久卡（道统卡）", "价格": 298, "仙玉": 2980, "推荐": "终身日供翻倍、离线上限48h"})

	for 套餐 in 推荐套餐:
		var 套餐卡 := PanelContainer.new()
		套餐卡.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var 套餐卡样式 := StyleBoxFlat.new()
		套餐卡样式.bg_color = Color(0.10, 0.12, 0.08, 0.8)
		套餐卡样式.set_corner_radius_all(8)
		套餐卡样式.set_border_width_all(1)
		套餐卡样式.border_color = Color(0.4, 0.6, 0.4)
		套餐卡样式.set_content_margin_all(12)
		套餐卡.add_theme_stylebox_override("panel", 套餐卡样式)

		var 套餐hb := HBoxContainer.new()
		套餐hb.add_theme_constant_override("separation", 12)
		套餐卡.add_child(套餐hb)
		套餐hb.modulate.a = 0.0
		套餐hb.create_tween().tween_property(套餐hb, "modulate:a", 1.0, 0.25)

		var 套餐信息vbox := VBoxContainer.new()
		套餐信息vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		套餐hb.add_child(套餐信息vbox)
		套餐信息vbox.modulate.a = 0.0
		套餐信息vbox.create_tween().tween_property(套餐信息vbox, "modulate:a", 1.0, 0.25)

		var 套餐名称label := Label.new()
		套餐名称label.text = str(套餐.get("名称", ""))
		UITheme.apply_project_font(套餐名称label, UITheme.FONT_H2, true)
		套餐名称label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
		套餐信息vbox.add_child(套餐名称label)
		套餐名称label.modulate.a = 0.0
		套餐名称label.create_tween().tween_property(套餐名称label, "modulate:a", 1.0, 0.25)

		var 套餐描述label := Label.new()
		套餐描述label.text = "%s | %s" % [str(套餐.get("推荐", "")), "含%d仙玉" % int(套餐.get("仙玉", 0))]
		UITheme.apply_project_font(套餐描述label, UITheme.FONT_BODY, false)
		套餐描述label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6))
		套餐信息vbox.add_child(套餐描述label)
		套餐描述label.modulate.a = 0.0
		套餐描述label.create_tween().tween_property(套餐描述label, "modulate:a", 1.0, 0.25)

		var 购买btn := Button.new()
		购买btn.text = "%d元" % int(套餐.get("价格", 0))
		购买btn.custom_minimum_size = Vector2(80, 36)
		UITheme.apply_project_font(购买btn, UITheme.FONT_BODY, false)
		购买btn.pressed.connect(_on_recharge_package.bind(str(套餐.get("名称", "")), int(套餐.get("价格", 0))))
		套餐hb.add_child(购买btn)
		购买btn.modulate.a = 0.0
		购买btn.create_tween().tween_property(购买btn, "modulate:a", 1.0, 0.25)

		_scroll_vbox.add_child(套餐卡)
		套餐卡.modulate.a = 0.0
		套餐卡.create_tween().tween_property(套餐卡, "modulate:a", 1.0, 0.25)

# 充值套餐购买
func _on_recharge_package(名称: String, 价格: int) -> void:
	UIHint.show_hint(self, "充值指引", "选择【%s】（%d元）\n请前往充值中心完成支付\n支付成功后仙阶礼遇自动生效" % [名称, 价格])
	Game.添加提示("充值指引")
