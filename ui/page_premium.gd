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
			var 奖励详情头 := Label.new()
			奖励详情头.text = "🎁 今日供奉奖励"
			奖励详情头.add_theme_font_size_override("font_size", 16)
			奖励详情头.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
			_scroll_vbox.add_child(奖励详情头)
			
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
			连续天数列.add_theme_font_size_override("font_size", 14)
			连续天数列.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
			奖励详情vbox.add_child(连续天数列)
			
			# 奖励内容
			var 奖励内容hb := HBoxContainer.new()
			奖励内容hb.name = "RewardContentHBox"
			奖励内容hb.add_theme_constant_override("separation", 16)
			奖励详情vbox.add_child(奖励内容hb)
			
			# 灵石奖励
			var 灵石奖励: int = int(今日奖励.get("灵石", 0))
			if 灵石奖励 > 0:
				var 灵石项 := Label.new()
				灵石项.text = "💎 灵石 +%d" % 灵石奖励
				灵石项.add_theme_font_size_override("font_size", 14)
				灵石项.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
				奖励内容hb.add_child(灵石项)
			
			# 灵气奖励
			var 灵气奖励: int = int(今日奖励.get("灵气", 0))
			if 灵气奖励 > 0:
				var 灵气项 := Label.new()
				灵气项.text = "✨ 灵气 +%d" % 灵气奖励
				灵气项.add_theme_font_size_override("font_size", 14)
				灵气项.add_theme_color_override("font_color", UITheme.C05_REWARD_BLUE)
				奖励内容hb.add_child(灵气项)
			
			# 悟道点奖励
			var 悟道点奖励: int = int(今日奖励.get("悟道点", 0))
			if 悟道点奖励 > 0:
				var 悟道点项 := Label.new()
				悟道点项.text = "📖 悟道点 +%d" % 悟道点奖励
				悟道点项.add_theme_font_size_override("font_size", 14)
				悟道点项.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9, 1.0))
				奖励内容hb.add_child(悟道点项)
			
			# 奖励描述
			var 奖励描述: String = str(今日奖励.get("描述", ""))
			if 奖励描述 != "":
				var 描述列 := Label.new()
				描述列.text = 奖励描述
				描述列.add_theme_font_size_override("font_size", 12)
				描述列.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				奖励详情vbox.add_child(描述列)
			
			_scroll_vbox.add_child(奖励详情卡)
	
	# 大厂标准：累计签到奖励列表（使用新添加的Game.获取累计签到奖励列表()）
	if is_instance_valid(Game) and Game.has_method("获取累计签到奖励列表"):
		var 累计奖励列表: Array = Game.获取累计签到奖励列表()
		if not 累计奖励列表.is_empty():
			var 累计奖励头 := Label.new()
			累计奖励头.text = "🏆 累计供奉奖励"
			累计奖励头.add_theme_font_size_override("font_size", 16)
			累计奖励头.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
			_scroll_vbox.add_child(累计奖励头)
			
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
					累计卡样式.border_color = UITheme.C01_TEXT_GOLD
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
				
				# 天数图标
				var 天数图标 := Label.new()
				天数图标.text = "📅" if 已达成 else "🔒"
				天数图标.add_theme_font_size_override("font_size", 24)
				累计奖励hb.add_child(天数图标)
				
				var 累计奖励info := VBoxContainer.new()
				累计奖励info.name = "CumulativeRewardInfo"
				累计奖励info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				累计奖励info.add_theme_constant_override("separation", 4)
				累计奖励hb.add_child(累计奖励info)
				
				# 天数标题
				var 天数标题 := Label.new()
				天数标题.text = "连续供奉 %d 日" % 天数
				天数标题.add_theme_font_size_override("font_size", 14)
				if 已达成:
					天数标题.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
				else:
					天数标题.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
				累计奖励info.add_child(天数标题)
				
				# 奖励描述
				var 累计描述 := Label.new()
				累计描述.text = 描述
				累计描述.add_theme_font_size_override("font_size", 12)
				累计描述.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				累计奖励info.add_child(累计描述)
				
				# 状态标签
				var 状态标签 := Label.new()
				状态标签.text = "✅ 已达成" if 已达成 else "未达成"
				状态标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				状态标签.size_flags_horizontal = Control.SIZE_SHRINK_END
				状态标签.add_theme_font_size_override("font_size", 12)
				if 已达成:
					状态标签.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
				else:
					状态标签.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				累计奖励hb.add_child(状态标签)
				
				_scroll_vbox.add_child(累计奖励卡)

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

	# 仙玉兑换（带每日上限）：数据层未就绪时显示为筹备中，按钮置灰
	var 兑换就绪: bool = is_instance_valid(Game) and Game.has_method("仙玉兑换")
	var 兑头 := Label.new()
	兑头.text = "仙玉兑换（每次 10 仙玉，带每日上限）"
	UITheme.apply_section_title(兑头)
	_scroll_vbox.add_child(兑头)
	for 类型 in ["灵石", "战功", "传承积分", "宗门贡献"]:
		var t: Dictionary = XianyuShop.仙玉兑换表.get(类型, {})
		if t.is_empty():
			continue
		var b := Button.new()
		b.text = "仙玉 → %s（1:%d，日上限 %d）%s" % [类型, int(t["率"]), int(t["日上限"]), "（筹备中）" if not 兑换就绪 else ""]
		b.custom_minimum_size = Vector2(0, UITheme.SIZE_SM)
		b.disabled = not 兑换就绪
		if 兑换就绪:
			b.pressed.connect(_on_兑换.bind(类型))
		_scroll_vbox.add_child(b)

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
		"有效(%d日)" % 月卡剩余 if 月卡有效 else "未激活",
		"有效(%d日)" % 季卡剩余 if 季卡有效 else "未激活",
		"已激活" if 永久卡有效 else "未激活"
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
			var 限时活动头 := Label.new()
			限时活动头.text = "🔥 限时特惠"
			限时活动头.add_theme_font_size_override("font_size", 18)
			限时活动头.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
			_scroll_vbox.add_child(限时活动头)
			
			for 活动礼包 in 限时活动列表:
				var 礼包 = 活动礼包.get("礼包", {})
				var 原价 = int(活动礼包.get("原价", 0))
				var 活动价 = int(活动礼包.get("活动价", 0))
				var 折扣百分比 = int(活动礼包.get("折扣百分比", 0))
				var 剩余天数 = int(活动礼包.get("剩余天数", 0))
				
				var 礼包卡片 = _make_limited_gift_card(礼包, 原价, 活动价, 折扣百分比, 剩余天数)
				_scroll_vbox.add_child(礼包卡片)

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
		_反馈("数据未就绪")
		return
	var r: Dictionary = Game.领取日供()
	_反馈(str(r.get("msg", "—")))
	_刷新余额()
	仙玉变更.emit()
	_populate()

func _on_兑换(类型: String) -> void:
	if not is_instance_valid(Game) or not Game.has_method("仙玉兑换"):
		_反馈("数据未就绪")
		return
	var r: Dictionary = Game.仙玉兑换(类型, 10)
	_反馈(str(r.get("msg", "—")))
	_刷新余额()
	仙玉变更.emit()

func _on_购买月卡() -> void:
	if not is_instance_valid(Game):
		_反馈("数据未就绪")
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
		_反馈("数据未就绪")
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
		_反馈("数据未就绪")
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
		_反馈("数据未就绪")
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
	
	# 图标区域
	var icon_panel := PanelContainer.new()
	icon_panel.name = "IconPanel"
	icon_panel.custom_minimum_size = Vector2(72, 72)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.1, 0.08, 0.15, 1.0)
	icon_style.set_corner_radius_all(10)
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = "🎁"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_panel.add_child(icon_label)
	hb.add_child(icon_panel)
	
	# 信息区域
	var info := VBoxContainer.new()
	info.name = "InfoVBox"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hb.add_child(info)
	
	# 礼包名称和限时标签
	var name_hb := HBoxContainer.new()
	name_hb.name = "NameHBox"
	name_hb.add_theme_constant_override("separation", 8)
	info.add_child(name_hb)
	
	var name_label := Label.new()
	name_label.name = "GiftName"
	name_label.text = str(礼包.get("名称", "未知礼包"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 1.0, 1.0))
	name_hb.add_child(name_label)
	
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
		limited_label.add_theme_font_size_override("font_size", 12)
		limited_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		limited_badge.add_child(limited_label)
		name_hb.add_child(limited_badge)
	
	# 礼包描述
	var desc_label := Label.new()
	desc_label.name = "GiftDesc"
	desc_label.text = str(礼包.get("描述", ""))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1.0))
	info.add_child(desc_label)
	
	# 价格区域
	var price_hb := HBoxContainer.new()
	price_hb.name = "PriceHBox"
	price_hb.add_theme_constant_override("separation", 8)
	info.add_child(price_hb)
	
	# 活动价
	var special_price := Label.new()
	special_price.name = "SpecialPrice"
	special_price.text = "💎 %d" % 活动价
	special_price.add_theme_font_size_override("font_size", 18)
	special_price.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	price_hb.add_child(special_price)
	
	# 原价（划线）
	if 原价 > 活动价:
		var original_price := Label.new()
		original_price.name = "OriginalPrice"
		original_price.text = "%d" % 原价
		original_price.add_theme_font_size_override("font_size", 14)
		original_price.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		price_hb.add_child(original_price)
	
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
		discount_label.add_theme_font_size_override("font_size", 12)
		discount_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		discount_badge.add_child(discount_label)
		price_hb.add_child(discount_badge)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "立即抢购"
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
	buy_btn.add_theme_font_size_override("font_size", 14)
	var 礼包ID = str(礼包.get("id", ""))
	buy_btn.pressed.connect(_on_购买礼包.bind(礼包ID))
	info.add_child(buy_btn)
	
	return card


# S1-4 付费：仙玉购买全局增益（调用 Game._pay_reserved_全局增益）
func _on_付费_全局增益() -> void:
	if not is_instance_valid(Game):
		return
	var r: Dictionary = Game._pay_reserved_全局增益()
	if r.get("成功", false):
		var g: float = float(r.get("当前增益", 0.0)) * 100.0
		UIHint.show_hint(self, "全局增益+5%", "战斗通用增益提升至 %.0f%%" % g)
	else:
		UIHint.show_hint(self, "仙玉匮乏", str(r.get("原因", "")))
	refresh()
