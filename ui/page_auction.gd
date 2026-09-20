extends Control
# S34b 通用拍卖会：修真界拍卖行（常驻场 + 季度大拍）
# S34-P0 优化：声望等级系统、委托竞拍、延时结算、结算通知、私库自动使用
# 入口：main.gd 宗门页快捷网格「拍卖行」→ 二级页。
# 货币复用宗门灵石（不新建货币）；拍品由 game_state.gd 用现有 Item 池按稀有度抽取，AI 散修/宗门/商会估值封顶竞价。
# 代码纪律：局部变量一律 `var x: Type = ...`（禁 := walrus）；按钮回调用 Callable.connect；UITheme 0 臆造。

signal 返回主页
signal 打开全服拍卖  # S54：打开全服拍卖大典

var _built: bool = false
var _body: VBoxContainer = null
var _content: VBoxContainer = null
var _提示: String = ""
var _私库展开: bool = false
var _查看委托: bool = false
var _查看关注: bool = false
var _查看求购: bool = false
var _通知已显示: bool = false
var _牌价标: Label = null


func _ready() -> void:
	_build()
	refresh()


func _enter_tree() -> void:
	if _built:
		refresh.call_deferred()


func _on_back_pressed() -> void:
	返回主页.emit()

# S54：打开全服拍卖大典
func _打开全服拍卖() -> void:
	打开全服拍卖.emit()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content: Control = UITheme.make_scene_background(self)
	_body = VBoxContainer.new()
	_body.name = "Root"
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.GRID)
	_body.add_theme_constant_override("margin_bottom", UITheme.GRID)
	_body.add_theme_constant_override("separation", UITheme.GRID)
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)
	_build_header()
	_build_content_area()


func _build_header() -> void:
	# S34-P0：声望等级显示（置于顶栏右侧）
	var 等级: int = int(Game.拍卖行系统.拍卖会.get("等级", 1))
	var 等级名: String = _等级名称(等级)
	var 声望: int = int(Game.拍卖行系统.拍卖会.get("声望", 0))
	var 声望行: HBoxContainer = HBoxContainer.new()
	声望行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 声望图标: TextureRect = TextureRect.new()
	声望图标.texture = UITheme.load_hd_icon("auction_reputation_512")
	声望图标.custom_minimum_size = Vector2(20, 20)
	声望图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	声望图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	声望行.add_child(声望图标)
	var 等级标: Label = Label.new()
	等级标.text = "【%s】· 声望 %d" % [等级名, 声望]
	UITheme.apply_aux_text(等级标)
	声望行.add_child(等级标)
	_body.add_child(UITheme.建顶栏("修真界拍卖行", _on_back_pressed, [声望行]))
	# ECON-03 P0-A：今日牌价常驻页头下方一行（全页共用一处，不逐卡重复）
	_牌价标 = Label.new()
	_牌价标.name = "RateLabel"
	_牌价标.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_牌价标.text = _牌价行文本()
	UITheme.apply_aux_text(_牌价标)
	_牌价标.add_theme_color_override("font_color", UITheme.COLOR_TEXT_GOLD)
	_body.add_child(_牌价标)


## 页头副行文案：宗门灵石 + 今日牌价（同一行，避免两处各占一行）
func _牌价行文本() -> String:
	return "宗门灵石：%d ｜ %s" % [Game.灵石, _牌价文本()]

func _牌价文本() -> String:
	if is_instance_valid(Game) and Game.has_method("汇率牌价文案"):
		return Game.汇率牌价文案()
	return "今日牌价：—"


func _build_content_area() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", UITheme.GRID)
	scroll.add_child(_content)


func refresh() -> void:
	if not _built:
		_build()
	for c in _content.get_children():
		c.queue_free()
	# 牌价随「累计游戏日」轮换 ⇒ 每次刷新重取，避免页内久留后牌价失真
	if _牌价标 != null and is_instance_valid(_牌价标):
		_牌价标.text = _牌价行文本()
	if _提示 != "":
		var 提示: Label = Label.new()
		提示.text = _提示
		提示.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		提示.add_theme_color_override("font_color", UITheme.color_value(false))
		_content.add_child(提示)
		_提示 = ""
	_populate()


# ——— 通用小组件 ———
func _card() -> VBoxContainer:
	var p: PanelContainer = PanelContainer.new()
	UITheme.apply_panel_style(p, true)
	_content.add_child(p)
	p.modulate.a = 0.0
	p.create_tween().tween_property(p, "modulate:a", 1.0, 0.25)
	# PanelContainer 自身无子节点，必须先挂 VBox 再返回（原 p.get_child(0) 恒为 null）
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.modulate.a = 0.0
	v.create_tween().tween_property(v, "modulate:a", 1.0, 0.25)
	return v


func _label(文: String, 主: bool) -> Label:
	var l: Label = Label.new()
	l.text = 文
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if 主:
		UITheme.apply_body_text(l)
	else:
		UITheme.apply_aux_text(l)
	return l


func _段标题(文: String) -> void:
	# ★ 2026-09-16 修（#009 逐页精修 · 拍卖行）：原实现只 new 了 Label 却从未 add_child，
	#   导致全页 6 处分段标题（常驻拍卖行 / 大拍 / 竞拍记录 / 我的关注 / 求购大厅 / 当前求购）
	#   一处都不显示 —— 页面失去全部视觉分段。gdtoolkit 与 36 道闸门都看不见「创建了但没挂树」。
	var l: Label = Label.new()
	l.text = 文
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_section_title(l)
	l.add_theme_color_override("font_color", UITheme.获取金文字色())
	_content.add_child(l)

## S34-P2：特殊事件横幅显示
func _特殊事件横幅() -> void:
	var evt: Dictionary = Game.获取当前特殊事件_S34()
	if evt.is_empty():
		return
	var 卡: VBoxContainer = _card()
	var 名称: String = str(evt.get("名称", ""))
	var 描述: String = str(evt.get("描述", ""))
	var 剩余: int = int(evt.get("剩余日", 0))
	# 标题行：图标+文字
	var 标题行: HBoxContainer = HBoxContainer.new()
	标题行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 事件图标: TextureRect = TextureRect.new()
	事件图标.texture = UITheme.load_hd_icon("auction_special_event_512")
	事件图标.custom_minimum_size = Vector2(24, 24)
	事件图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	事件图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	标题行.add_child(事件图标)
	var 标题: Label = Label.new()
	标题.text = "【特殊事件】%s（剩余 %d 日）" % [名称, 剩余]
	标题.add_theme_color_override("font_color", UITheme.获取金文字色())
	UITheme.apply_body_text(标题)
	标题行.add_child(标题)
	卡.add_child(标题行)
	卡.add_child(_label(描述, false))



# S34-P0：等级名称映射
func _等级名称(等级: int) -> String:
	match 等级:
		1: return "普通客人"
		2: return "熟客"
		3: return "贵宾"
		4: return "黑金贵宾"
		5: return "至尊贵宾"
	return "普通客人"


# ——— 主填充 ———
func _populate() -> void:
	Game.拍卖会确保就绪_S34()
	# S34-P0：结算通知（首次进入时显示）
	if not _通知已显示:
		_结算通知区()
		_通知已显示 = true
	# 切换按钮：拍卖行 / 我的委托 / 我的关注 / 求购大厅
	_切换栏()
	if _查看委托:
		_我的委托区()
	elif _查看关注:
		_我的关注区()
	elif _查看求购:
		_求购大厅区()
	else:
		_特殊事件横幅()
		_拍卖预告区_S53()  # S53：拍卖预告
		_代拍方略区_S53()  # S53：代拍方略
		_交付选择器()
		_常驻区()
		if Game.拍卖行系统.拍卖会.get("大拍激活", false):
			_大拍区()
	_记录区()


# S34-P0：切换栏（拍卖行 / 我的委托 / 我的关注 / 求购大厅）
func _切换栏() -> void:
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID / 2)
	# S54：全服拍卖入口按钮
	# ★ 2026-09-16：原 5 个钮塞同一 HBox，720 宽下每个只剩 ~110px、文字全挤在一起。
	#   ⇒ 全服大典（跨服玩法入口，层级不同）独占一行，其余 4 个视图 Tab 另起一行。
	var 行0: HBoxContainer = HBoxContainer.new()
	行0.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 全服钮: Button = Button.new()
	全服钮.text = "◆ 全服拍卖大典"
	全服钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	全服钮.add_theme_color_override("font_color", UITheme.获取金文字色())
	UITheme.apply_secondary_button_style(全服钮)
	全服钮.pressed.connect(func(): _打开全服拍卖())
	行0.add_child(全服钮)
	_content.add_child(行0)
	# 拍卖行按钮
	var 拍卖钮: Button = Button.new()
	var 拍卖选中: bool = (not _查看委托) and (not _查看关注) and (not _查看求购)
	拍卖钮.text = "◆ 拍卖行" if 拍卖选中 else "拍卖行"
	拍卖钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	if 拍卖选中:
		UITheme.apply_primary_button_style(拍卖钮)
	else:
		UITheme.apply_secondary_button_style(拍卖钮)
	拍卖钮.pressed.connect(func():
		_查看委托 = false
		_查看关注 = false
		_查看求购 = false
		refresh()
	)
	行.add_child(拍卖钮)
	# 我的委托按钮
	var 委托钮: Button = Button.new()
	var 活跃委托: int = _活跃委托数()
	委托钮.text = "◆ 委托(%d)" % 活跃委托 if _查看委托 else "委托(%d)" % 活跃委托
	委托钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	if _查看委托:
		UITheme.apply_primary_button_style(委托钮)
	else:
		UITheme.apply_secondary_button_style(委托钮)
	委托钮.pressed.connect(func():
		_查看委托 = true
		_查看关注 = false
		_查看求购 = false
		refresh()
	)
	行.add_child(委托钮)
	# 我的关注按钮
	var 关注钮: Button = Button.new()
	var 关注数: int = _关注数()
	关注钮.text = "◆ 关注(%d)" % 关注数 if _查看关注 else "关注(%d)" % 关注数
	关注钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	if _查看关注:
		UITheme.apply_primary_button_style(关注钮)
	else:
		UITheme.apply_secondary_button_style(关注钮)
	关注钮.pressed.connect(func():
		_查看委托 = false
		_查看关注 = true
		_查看求购 = false
		refresh()
	)
	行.add_child(关注钮)
	# 求购大厅按钮
	var 求购钮: Button = Button.new()
	var 求购数: int = _求购数()
	求购钮.text = "◆ 求购(%d)" % 求购数 if _查看求购 else "求购(%d)" % 求购数
	求购钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	if _查看求购:
		UITheme.apply_primary_button_style(求购钮)
	else:
		UITheme.apply_secondary_button_style(求购钮)
	求购钮.pressed.connect(func():
		_查看委托 = false
		_查看关注 = false
		_查看求购 = true
		refresh()
	)
	行.add_child(求购钮)
	_content.add_child(行)


# S34-P0：统计活跃委托数量
func _活跃委托数() -> int:
	var 数: int = 0
	for w in Game.拍卖行系统.拍卖会.get("委托列表", []):
		if str(w.get("状态", "")) == "活跃":
			数 += 1
	return 数


# S34-P0：结算通知区
func _结算通知区() -> void:
	var 通知: Array = Game.获取结算通知_S34()
	if 通知.is_empty():
		return
	var 卡: VBoxContainer = _card()
	卡.add_child(_label("◆ 拍卖行结算通知（离线期间）", true))
	for n in 通知:
		var 类型: String = str(n.get("类型", ""))
		var 名称: String = str(n.get("名称", ""))
		var 价: int = int(n.get("价", 0))
		var 文: String = ""
		if 类型 == "竞得":
			var 佣金: int = int(n.get("佣金", 0))
			var 交付: String = str(n.get("交付", "宗门库房"))
			文 = "✓ 竞得「%s」%d 灵石（佣金 %d）→ 已入 %s" % [名称, 价, 佣金, 交付]
		elif 类型 == "未竞得":
			var 领先: String = str(n.get("领先", ""))
			文 = "× 未竞得「%s」（被 %s 竞得，成交价 %d）" % [名称, 领先, 价]
		elif 类型 == "流拍":
			文 = "… 流拍「%s」（未达保留价）" % 名称
		var _fb1 := _label(文, false)
		卡.add_child(_fb1)
		_fb1.modulate.a = 0.0
		_fb1.create_tween().tween_property(_fb1, "modulate:a", 1.0, 0.25)
	var 清除钮: Button = Button.new()
	清除钮.text = "我知道了（清除通知）"
	清除钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(清除钮)
	清除钮.pressed.connect(func():
		Game.清除结算通知_S34()
		refresh()
	)
	卡.add_child(清除钮)


# S34-P0：我的委托区
func _我的委托区() -> void:
	# 标题行：图标+文字
	var 委托标题行: HBoxContainer = HBoxContainer.new()
	委托标题行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 委托图标: TextureRect = TextureRect.new()
	委托图标.texture = UITheme.load_hd_icon("auction_consignment_512")
	委托图标.custom_minimum_size = Vector2(24, 24)
	委托图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	委托图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	委托标题行.add_child(委托图标)
	var 委托标题: Label = Label.new()
	委托标题.text = "我的委托竞拍"
	UITheme.apply_body_text(委托标题)
	委托标题行.add_child(委托标题)
	_content.add_child(委托标题行)
	var 委托: Array = Game.拍卖行系统.拍卖会.get("委托列表", [])
	var 活跃: Array = []
	for w in 委托:
		if str(w.get("状态", "")) == "活跃":
			活跃.append(w)
	if 活跃.is_empty():
		_content.add_child(_label("（暂无活跃委托，可在拍卖行中设置委托出价）", false))
		return
	for w in 活跃:
		var 卡: VBoxContainer = _card()
		var 拍品ID: String = str(w.get("拍品ID", ""))
		var 委托价: int = int(w.get("最高委托价", 0))
		var 冻结: int = int(w.get("冻结灵石", 0))
		# 查找拍品当前信息
		var 拍品名: String = "（已结束）"
		var 当前价: int = 0
		var 领先: String = ""
		for lot in Game.拍卖行系统.拍卖会.get("常驻拍品", []):
			if str(lot.get("id", "")) == 拍品ID:
				拍品名 = str(lot.get("名称", ""))
				当前价 = int(lot.get("当前价", 0))
				领先 = str(lot.get("最高出价者", ""))
				break
		for lot in Game.拍卖行系统.拍卖会.get("大拍拍品", []):
			if str(lot.get("id", "")) == 拍品ID:
				拍品名 = str(lot.get("名称", ""))
				当前价 = int(lot.get("当前价", 0))
				领先 = str(lot.get("最高出价者", ""))
				break
		var _fb2 := _label(拍品名, true)
		卡.add_child(_fb2)
		_fb2.modulate.a = 0.0
		_fb2.create_tween().tween_property(_fb2, "modulate:a", 1.0, 0.25)
		var _fb3 := _label("委托上限：%d 灵石 ｜ 当前价：%d ｜ 领先：%s ｜ 已冻结：%d 灵石" % [委托价, 当前价, 领先, 冻结], false)
		卡.add_child(_fb3)
		_fb3.modulate.a = 0.0
		_fb3.create_tween().tween_property(_fb3, "modulate:a", 1.0, 0.25)
		var 取消钮: Button = Button.new()
		取消钮.text = "取消委托（解冻灵石）"
		取消钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(取消钮)
		取消钮.pressed.connect(func():
			var 果: Dictionary = Game.取消委托竞拍_S34(拍品ID)
			_提示 = str(果.get("原因", ""))
			refresh()
		)
		卡.add_child(取消钮)
		取消钮.modulate.a = 0.0
		取消钮.create_tween().tween_property(取消钮, "modulate:a", 1.0, 0.25)


func _交付选择器() -> void:
	var 卡: VBoxContainer = _card()
	var 当前: Dictionary = Game.拍卖行系统.拍卖会.get("默认交付", {"类型": "库房"})
	var 目标文: String = "库房" if str(当前.get("类型", "")) == "库房" else "弟子私库"
	卡.add_child(_label("交付至（竞得物品归处）：%s" % 目标文, true))
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 库房钮: Button = Button.new()
	库房钮.text = "宗门库房"
	库房钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(库房钮)
	库房钮.pressed.connect(func():
		Game.设置拍卖交付_S34({"类型": "库房"})
		_提示 = "交付目标已设为：宗门库房"
		refresh()
	)
	行.add_child(库房钮)
	var 私库钮: Button = Button.new()
	私库钮.text = "弟子私库" if not _私库展开 else "弟子私库 ▲"
	私库钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(私库钮)
	私库钮.pressed.connect(func():
		_私库展开 = not _私库展开
		refresh()
	)
	行.add_child(私库钮)
	卡.add_child(行)
	if _私库展开:
		var 有: bool = false
		for d in Game.弟子列表:
			if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
				continue
			有 = true
			var 钮: Button = Button.new()
			钮.text = "交付至 %s（%s·道行%d）私库" % [str(d.姓名), str(d.境界), int(d.总战力())]
			钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(钮)
			钮.pressed.connect(func():
				Game.设置拍卖交付_S34({"类型": "私库", "弟子ID": str(d.弟子ID)})
				_私库展开 = false
				_提示 = "交付目标已设为：%s 私库" % str(d.姓名)
				refresh()
			)
			卡.add_child(钮)
			钮.modulate.a = 0.0
			钮.create_tween().tween_property(钮, "modulate:a", 1.0, 0.25)
		if not 有:
			卡.add_child(_label("（无符合要求的在宗弟子）", false))


func _常驻区() -> void:
	_段标题("◆ 常驻拍卖行（持续开放，单件到期即补）")
	var 拍品: Array = Game.拍卖行系统.拍卖会.get("常驻拍品", [])
	if 拍品.is_empty():
		_content.add_child(_label("（暂无可拍品，推演数日后续刷新）", false))
		return
	for lot in 拍品:
		_lot_card(lot)


func _大拍区() -> void:
	_段标题("◆ 修真界大拍·进行中！稀世之宝云集，各方豪强竞逐（全服播报·声望×2）")
	var 拍品: Array = Game.拍卖行系统.拍卖会.get("大拍拍品", [])
	if 拍品.is_empty():
		_content.add_child(_label("（大拍拍品已尽数落槌）", false))
		return
	for lot in 拍品:
		_lot_card(lot)


func _记录区() -> void:
	_段标题("◆ 竞拍记录")
	var 记录: Array = Game.拍卖行系统.拍卖会.get("竞拍记录", [])
	if 记录.is_empty():
		_content.add_child(_label("（暂无竞拍记录）", false))
		return
	for r in 记录:
		var 文: String = "%s — %s（%d 灵石）" % [str(r.get("名称", "")), str(r.get("结果", "")), int(r.get("价", 0))]
		var _fb4 := _label(文, false)
		_content.add_child(_fb4)
		_fb4.modulate.a = 0.0
		_fb4.create_tween().tween_property(_fb4, "modulate:a", 1.0, 0.25)


func _lot_card(lot: Dictionary) -> void:
	var 卡: VBoxContainer = _card()
	var it: Item = Item.new()
	it.from_dict(lot.get("物品", {}))
	# S34-P0：品类标签
	var 品类: String = str(lot.get("品类", "装备"))
	var 品阶: String = str(lot.get("品阶", ""))
	# S53：捡漏区标签
	var 捡漏标签: String = ""
	if bool(lot.get("捡漏区", false)):
		捡漏标签 = " 【捡漏区】"
	# S53：未知宝物显示
	var 未知宝物: bool = bool(lot.get("未知宝物", false))
	var 已鉴定: bool = bool(lot.get("已鉴定", false))
	if 未知宝物 and not 已鉴定:
		var _fb5 := _label("[%s·???] 未知宝物%s（蒙尘之物，需鉴定方知真伪）" % [品类, 捡漏标签], true)
		卡.add_child(_fb5)
		_fb5.modulate.a = 0.0
		_fb5.create_tween().tween_property(_fb5, "modulate:a", 1.0, 0.25)
	else:
		# ★ 2026-09-16：`Item.简介()` 自身已以「名称 [类别·品阶·槽·道途] 战力+N」开头，
		#   再前置一遍 [品类·品阶] 就成了「百年灵草 [灵材·灵阶]」念两遍（截图实证）。
		var _fb6 := _label("%s%s" % [it.简介(), 捡漏标签], true)
		卡.add_child(_fb6)
		_fb6.modulate.a = 0.0
		_fb6.create_tween().tween_property(_fb6, "modulate:a", 1.0, 0.25)
	var 当前价: int = int(lot.get("当前价", 0))
	var 起拍价: int = int(lot.get("起拍价", 0))
	var 领先: String = str(lot.get("最高出价者", "（暂无）"))
	var 剩余: int = max(0, int(lot.get("结束日", 0)) - Game.累计游戏日)
	var 状态: String = str(lot.get("状态", "竞拍中"))
	# S34-P0：检查是否有玩家委托
	var 有委托: bool = false
	var 委托价: int = 0
	for w in (lot.get("委托列表", []) as Array):
		if str(w.get("状态", "")) == "活跃" and str(w.get("委托者类型", "")) == "玩家":
			有委托 = true
			委托价 = int(w.get("最高委托价", 0))
			break
	var 委托文: String = " ｜ 委托中(上限%d)" % 委托价 if 有委托 else ""
	var _fb7 := _label("起拍价 %d ｜ 当前价 %d ｜ 领先：%s ｜ 剩余 %d 日 ｜ 状态：%s%s" % [起拍价, 当前价, 领先, 剩余, 状态, 委托文], false)
	卡.add_child(_fb7)
	_fb7.modulate.a = 0.0
	_fb7.create_tween().tween_property(_fb7, "modulate:a", 1.0, 0.25)
	# ECON-03 P0-D：双币报价行 —— 同一底价同时给「仙玉价」与「灵石等价」；
	# 等价里已含硬通货溢价，玩家一眼看清用仙玉实付到底贵多少（既有出价链路零改动）。
	if 起拍价 > 0 and is_instance_valid(Game) and Game.has_method("灵石折仙玉"):
		var 仙玉价: int = Game.拍卖行系统.拍品底价仙玉(lot)
		if 仙玉价 > 0:
			var _fb8 := _label("双币结算：%d 灵石 ＝ %d 仙玉（仙玉灵石等价 %d · 硬通货溢价 15%%）" % [起拍价, 仙玉价, Game.拍卖行系统.出价灵石等价(仙玉价, "仙玉")], false)
			卡.add_child(_fb8)
			_fb8.modulate.a = 0.0
			_fb8.create_tween().tween_property(_fb8, "modulate:a", 1.0, 0.25)
	# S53：未知宝物鉴定按钮
	if 未知宝物 and not 已鉴定:
		var 鉴定费: int = max(10, int(float(起拍价) * 0.1))
		var 鉴定提示行: HBoxContainer = HBoxContainer.new()
		鉴定提示行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 鉴定图标: TextureRect = TextureRect.new()
		鉴定图标.texture = UITheme.load_hd_icon("auction_appraisal_512")
		鉴定图标.custom_minimum_size = Vector2(18, 18)
		鉴定图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		鉴定图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		鉴定提示行.add_child(鉴定图标)
		鉴定图标.modulate.a = 0.0
		鉴定图标.create_tween().tween_property(鉴定图标, "modulate:a", 1.0, 0.25)
		var 鉴定提示: Label = Label.new()
		鉴定提示.text = "此宝蒙尘，灵气内敛，非慧眼不能识。鉴定费%d灵石，一鉴便知真伪。" % 鉴定费
		UITheme.apply_aux_text(鉴定提示)
		鉴定提示行.add_child(鉴定提示)
		鉴定提示.modulate.a = 0.0
		鉴定提示.create_tween().tween_property(鉴定提示, "modulate:a", 1.0, 0.25)
		卡.add_child(鉴定提示行)
		鉴定提示行.modulate.a = 0.0
		鉴定提示行.create_tween().tween_property(鉴定提示行, "modulate:a", 1.0, 0.25)
		var 鉴定行: HBoxContainer = HBoxContainer.new()
		鉴定行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 鉴定钮: Button = Button.new()
		鉴定钮.text = "鉴定宝物（%d灵石）" % 鉴定费
		鉴定钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(鉴定钮)
		鉴定钮.pressed.connect(func(): _鉴定宝物_S53(lot))
		鉴定行.add_child(鉴定钮)
		鉴定钮.modulate.a = 0.0
		鉴定钮.create_tween().tween_property(鉴定钮, "modulate:a", 1.0, 0.25)
		卡.add_child(鉴定行)
		鉴定行.modulate.a = 0.0
		鉴定行.create_tween().tween_property(鉴定行, "modulate:a", 1.0, 0.25)
		return
	# S53：已鉴定结果显示
	if 未知宝物 and 已鉴定:
		var 鉴定结果: String = str(lot.get("鉴定结果", ""))
		var 真实倍率: float = float(lot.get("真实倍率", 1.0))
		var 结果文: String = ""
		match 鉴定结果:
			"增值": 结果文 = "◇ 鉴定结果：慧眼识珠！此宝竟是稀世之珍，价值暴涨%.0f%%！" % ((真实倍率 - 1.0) * 100)
			"保值": 结果文 = "◇ 鉴定结果：此宝价值与预估相若。"
			"贬值": 结果文 = "◇ 鉴定结果：可惜！此宝竟是寻常之物，价值大跌%.0f%%。" % ((1.0 - 真实倍率) * 100)
			_: 结果文 = "◇ 鉴定结果：%s" % 鉴定结果
		var _fb9 := _label(结果文, false)
		卡.add_child(_fb9)
		_fb9.modulate.a = 0.0
		_fb9.create_tween().tween_property(_fb9, "modulate:a", 1.0, 0.25)
	# 竞价台词（最近 3 条）
	var 台词: Array = lot.get("竞价台词", [])
	if 台词.size() > 0:
		var 最近: Array = 台词.slice(max(0, 台词.size() - 3), 台词.size())
		for t in 最近:
			var _fb10 := _label("　· " + str(t), false)
			卡.add_child(_fb10)
			_fb10.modulate.a = 0.0
			_fb10.create_tween().tween_property(_fb10, "modulate:a", 1.0, 0.25)
	# S34-P2：暗拍拍品特殊UI
	if 品类 == "暗拍":
		var 暗拍提示行: HBoxContainer = HBoxContainer.new()
		暗拍提示行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 暗拍图标: TextureRect = TextureRect.new()
		暗拍图标.texture = UITheme.load_hd_icon("auction_sealed_bid_512")
		暗拍图标.custom_minimum_size = Vector2(18, 18)
		暗拍图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		暗拍图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		暗拍提示行.add_child(暗拍图标)
		暗拍图标.modulate.a = 0.0
		暗拍图标.create_tween().tween_property(暗拍图标, "modulate:a", 1.0, 0.25)
		var 暗拍提示: Label = Label.new()
		暗拍提示.text = "暗拍模式：密封出价，其他人看不到你的出价，结束时最高价得"
		UITheme.apply_aux_text(暗拍提示)
		暗拍提示行.add_child(暗拍提示)
		暗拍提示.modulate.a = 0.0
		暗拍提示.create_tween().tween_property(暗拍提示, "modulate:a", 1.0, 0.25)
		卡.add_child(暗拍提示行)
		暗拍提示行.modulate.a = 0.0
		暗拍提示行.create_tween().tween_property(暗拍提示行, "modulate:a", 1.0, 0.25)
		var 暗拍行: HBoxContainer = HBoxContainer.new()
		暗拍行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 暗拍输入: LineEdit = LineEdit.new()
		暗拍输入.placeholder_text = "密封出价（≥%d）" % 起拍价
		暗拍输入.custom_minimum_size = Vector2(160, int(round(34.0 * UITheme.UI_SCALE)))
		暗拍行.add_child(暗拍输入)
		暗拍输入.modulate.a = 0.0
		暗拍输入.create_tween().tween_property(暗拍输入, "modulate:a", 1.0, 0.25)
		var 暗拍钮: Button = Button.new()
		暗拍钮.text = "密封出价"
		暗拍钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(暗拍钮)
		暗拍钮.pressed.connect(func(): _暗拍出价(lot, 暗拍输入))
		暗拍行.add_child(暗拍钮)
		暗拍钮.modulate.a = 0.0
		暗拍钮.create_tween().tween_property(暗拍钮, "modulate:a", 1.0, 0.25)
		卡.add_child(暗拍行)
		暗拍行.modulate.a = 0.0
		暗拍行.create_tween().tween_property(暗拍行, "modulate:a", 1.0, 0.25)
		return
	if 状态 == "竞拍中":
		var 行: HBoxContainer = HBoxContainer.new()
		行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 输入: LineEdit = LineEdit.new()
		输入.placeholder_text = "出价（≥%d）" % (当前价 + 1)
		输入.custom_minimum_size = Vector2(140, int(round(34.0 * UITheme.UI_SCALE)))
		输入.set_meta("_bid_cur", "灵石")   # ★ 本卡的结算货币（随卡独立，卡片之间互不影响）
		行.add_child(输入)
		输入.modulate.a = 0.0
		输入.create_tween().tween_property(输入, "modulate:a", 1.0, 0.25)
		# ★ 2026-09-16（ECON-03 P1 双币）：切换本卡结算货币，输入框按当日汇率同步换算。
		#   注意：lambda **按值捕获**局部变量 ⇒ 可变状态必须放 Array 容器里，否则改了不生效。
		var 币钮: Button = Button.new()
		币钮.text = "灵石"
		币钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(币钮)
		var 币态: Array = ["灵石"]
		币钮.pressed.connect(func():
			var 下一: String = "仙玉" if str(币态[0]) == "灵石" else "灵石"
			币态[0] = 下一
			币钮.text = 下一
			输入.set_meta("_bid_cur", 下一)
			_同步出价输入(输入, lot, 下一)
		)
		行.add_child(币钮)
		币钮.modulate.a = 0.0
		币钮.create_tween().tween_property(币钮, "modulate:a", 1.0, 0.25)
		var 加价钮: Button = Button.new()
		var 步进: int = max(10, int(float(当前价) * 0.1))
		加价钮.text = "+%d" % 步进
		加价钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(加价钮)
		加价钮.pressed.connect(func():
			输入.text = str(int(lot.get("当前价", 0)) + max(10, int(float(lot.get("当前价", 0)) * 0.1)))
		)
		行.add_child(加价钮)
		加价钮.modulate.a = 0.0
		加价钮.create_tween().tween_property(加价钮, "modulate:a", 1.0, 0.25)
		var 出价钮: Button = Button.new()
		出价钮.text = "出价"
		出价钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_secondary_button_style(出价钮)
		出价钮.pressed.connect(func(): _出价(lot, 输入))
		行.add_child(出价钮)
		出价钮.modulate.a = 0.0
		出价钮.create_tween().tween_property(出价钮, "modulate:a", 1.0, 0.25)
		# S34-P0：委托出价按钮
		var 委托钮: Button = Button.new()
		委托钮.text = "委托" if not 有委托 else "改委托"
		委托钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
		UITheme.apply_primary_button_style(委托钮)
		委托钮.pressed.connect(func(): _委托出价(lot, 输入))
		行.add_child(委托钮)
		委托钮.modulate.a = 0.0
		委托钮.create_tween().tween_property(委托钮, "modulate:a", 1.0, 0.25)
		卡.add_child(行)
		行.modulate.a = 0.0
		行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
		# S34-P2：关注按钮
		var 关注行: HBoxContainer = HBoxContainer.new()
		关注行.add_theme_constant_override("separation", UITheme.GRID / 2)
		var 拍品ID: String = str(lot.get("id", ""))
		var 已关注: bool = _是否已关注(拍品ID)
		var 关注钮: Button = Button.new()
		关注钮.text = "★ 已关注（轻触取消）" if 已关注 else "☆ 关注此拍品"
		关注钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
		if 已关注:
			关注钮.add_theme_color_override("font_color", UITheme.获取金文字色())
		else:
			UITheme.apply_secondary_button_style(关注钮)
		关注钮.pressed.connect(func(): _切换关注(拍品ID))
		关注行.add_child(关注钮)
		关注钮.modulate.a = 0.0
		关注钮.create_tween().tween_property(关注钮, "modulate:a", 1.0, 0.25)
		卡.add_child(关注行)
		关注行.modulate.a = 0.0
		关注行.create_tween().tween_property(关注行, "modulate:a", 1.0, 0.25)
	else:
		var _fb11 := _label("（本拍品竞拍已结束）", false)
		卡.add_child(_fb11)
		_fb11.modulate.a = 0.0
		_fb11.create_tween().tween_property(_fb11, "modulate:a", 1.0, 0.25)


func _出价(lot: Dictionary, 输入: LineEdit) -> void:
	var 价: int = int(输入.text)
	# ★ 2026-09-16（ECON-03 P1）：取本卡选中的结算货币；缺省「灵石」⇒ 与既有行为逐字节一致。
	var 货币: String = "灵石"
	if 输入.has_meta("_bid_cur"):
		货币 = str(输入.get_meta("_bid_cur"))
	var 果: Dictionary = Game.玩家竞拍出价_S34(str(lot.get("id", "")), 价, Game.拍卖行系统.拍卖会.get("默认交付", {"类型": "库房"}), 货币)
	if bool(果.get("成功", false)):
		_提示 = "已出价 %d %s，当前领先：%s" % [价, 货币, str(果.get("领先", ""))]
	else:
		_提示 = str(果.get("原因", "出价失败"))
	refresh()

## ★ 2026-09-16（ECON-03 P1）：切换结算货币时同步输入框（所见即所付）。
## 换算基准＝「灵石口径的当前价 + 一步加价」，按当日汇率折成仙玉报价；
## 汇率逐日浮动且不落盘 ⇒ 这里只是**填一个合理的默认值**，最终以提交时的后端校验为准。
func _同步出价输入(输入: LineEdit, lot: Dictionary, 货币: String) -> void:
	if 输入 == null or not is_instance_valid(输入):
		return
	var 当前价: int = int(lot.get("当前价", 0))
	var 参考: int = 当前价 + max(10, int(float(当前价) * 0.1))
	if 货币 == "仙玉" and is_instance_valid(Game) and Game.has_method("拍卖行系统"):
		var 玉: int = max(1, Game.拍卖行系统.拍品底价仙玉({"起拍价": 参考}))
		输入.placeholder_text = "出价（≥%d 仙玉）" % 玉
		输入.text = str(玉)
	else:
		输入.placeholder_text = "出价（≥%d）" % (当前价 + 1)
		输入.text = str(参考)


# S34-P0：委托出价
func _委托出价(lot: Dictionary, 输入: LineEdit) -> void:
	var 价: int = int(输入.text)
	if 价 <= 0:
		var 当前价: int = int(lot.get("当前价", 0))
		var 步进: int = max(10, int(float(当前价) * 0.1))
		价 = 当前价 + 步进 * 2
	var 果: Dictionary = Game.设置委托竞拍_S34(str(lot.get("id", "")), 价)
	if bool(果.get("成功", false)):
		_提示 = "已设置委托上限 %d 灵石，系统将自动代您出价（离线也生效）" % 价
	else:
		_提示 = str(果.get("原因", "委托失败"))
	refresh()

## S34-P2：暗拍出价
func _暗拍出价(lot: Dictionary, 输入: LineEdit) -> void:
	var 价: int = int(输入.text)
	var 果: Dictionary = Game.暗拍出价_S34(str(lot.get("id", "")), 价)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", ""))
	else:
		_提示 = str(果.get("原因", "出价失败"))
	refresh()

## S34-P2：鉴定拍品
func _鉴定拍品(lot: Dictionary) -> void:
	var 果: Dictionary = Game.鉴定拍品_S34(str(lot.get("id", "")))
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", ""))
	else:
		_提示 = str(果.get("原因", "鉴定失败"))
	refresh()


# ============ S34-P2：关注/求购系统 ============

## 统计关注数量
func _关注数() -> int:
	var 关注列表: Array = Game.拍卖行系统.拍卖会.get("关注列表", [])
	return 关注列表.size()


## 统计求购数量
func _求购数() -> int:
	var 求购列表: Array = Game.拍卖行系统.拍卖会.get("求购列表", [])
	return 求购列表.size()


## 检查是否已关注某拍品
func _是否已关注(拍品ID: String) -> bool:
	var 关注列表: Array = Game.拍卖行系统.拍卖会.get("关注列表", [])
	for 关注 in 关注列表:
		if str(关注.get("拍品ID", "")) == 拍品ID:
			return true
	return false


## 切换关注状态
func _切换关注(拍品ID: String) -> void:
	if _是否已关注(拍品ID):
		var 果: Dictionary = Game.取消关注_S34(拍品ID)
		_提示 = str(果.get("原因", "已取消关注"))
	else:
		var 果: Dictionary = Game.关注拍品_S34(拍品ID)
		_提示 = str(果.get("原因", "关注成功，开拍时将提醒您"))
	refresh()


## 我的关注区
func _我的关注区() -> void:
	_段标题("◆ 我的关注（开拍/出价变动时提醒）")
	var 关注列表: Array = Game.拍卖行系统.拍卖会.get("关注列表", [])
	if 关注列表.is_empty():
		_content.add_child(_label("（暂无关注拍品，可在拍卖行中轻触「关注此拍品」）", false))
		return
	# 遍历关注列表，查找对应拍品信息
	for 关注 in 关注列表:
		var 拍品ID: String = str(关注.get("拍品ID", ""))
		var 关注时间: int = int(关注.get("关注时间", 0))
		# 查找拍品
		var 找到: bool = false
		for lot in Game.拍卖行系统.拍卖会.get("常驻拍品", []):
			if str(lot.get("id", "")) == 拍品ID:
				_lot_card(lot)
				找到 = true
				break
		if not 找到:
			for lot in Game.拍卖行系统.拍卖会.get("大拍拍品", []):
				if str(lot.get("id", "")) == 拍品ID:
					_lot_card(lot)
					找到 = true
					break
		if not 找到:
			# 拍品已结束，显示结束信息
			var 卡: VBoxContainer = _card()
			var 拍品名: String = str(关注.get("拍品名", "（未知拍品）"))
			var _fb12 := _label(拍品名, true)
			卡.add_child(_fb12)
			_fb12.modulate.a = 0.0
			_fb12.create_tween().tween_property(_fb12, "modulate:a", 1.0, 0.25)
			var _fb13 := _label("（该拍品竞拍已结束）", false)
			卡.add_child(_fb13)
			_fb13.modulate.a = 0.0
			_fb13.create_tween().tween_property(_fb13, "modulate:a", 1.0, 0.25)
			var 取消钮: Button = Button.new()
			取消钮.text = "移除关注"
			取消钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(取消钮)
			取消钮.pressed.connect(func(): _切换关注(拍品ID))
			卡.add_child(取消钮)
			取消钮.modulate.a = 0.0
			取消钮.create_tween().tween_property(取消钮, "modulate:a", 1.0, 0.25)


## 求购大厅区
func _求购大厅区() -> void:
	_段标题("◆ 求购大厅（发布求购，等待卖家上门）")
	# 发布求购表单
	var 发布卡: VBoxContainer = _card()
	发布卡.add_child(_label("发布求购信息", true))
	发布卡.add_child(_label("选择物品类别和品阶，设置最高出价，符合条件的卖家会主动联系您", false))
	# 类别选择
	var 类别行: HBoxContainer = HBoxContainer.new()
	类别行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 类别标签: Label = Label.new()
	类别标签.text = "物品类别："
	类别标签.custom_minimum_size = Vector2(80, 0)
	UITheme.apply_aux_text(类别标签)
	类别行.add_child(类别标签)
	var 类别选项: OptionButton = OptionButton.new()
	类别选项.add_item("装备")
	类别选项.add_item("丹药")
	类别选项.add_item("功法")
	类别选项.add_item("灵兽")
	类别选项.add_item("材料")
	类别选项.add_item("法宝")
	类别选项.custom_minimum_size = Vector2(120, int(round(34.0 * UITheme.UI_SCALE)))
	类别行.add_child(类别选项)
	发布卡.add_child(类别行)
	# 品阶选择
	var 品阶行: HBoxContainer = HBoxContainer.new()
	品阶行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 品阶标签: Label = Label.new()
	品阶标签.text = "物品品阶："
	品阶标签.custom_minimum_size = Vector2(80, 0)
	UITheme.apply_aux_text(品阶标签)
	品阶行.add_child(品阶标签)
	var 品阶选项: OptionButton = OptionButton.new()
	品阶选项.add_item("凡阶")
	品阶选项.add_item("灵阶")
	品阶选项.add_item("宝阶")
	品阶选项.add_item("王阶")
	品阶选项.add_item("圣阶")
	品阶选项.add_item("仙阶")
	品阶选项.custom_minimum_size = Vector2(120, int(round(34.0 * UITheme.UI_SCALE)))
	品阶行.add_child(品阶选项)
	发布卡.add_child(品阶行)
	# 最高出价
	var 价格行: HBoxContainer = HBoxContainer.new()
	价格行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 价格标签: Label = Label.new()
	价格标签.text = "最高出价："
	价格标签.custom_minimum_size = Vector2(80, 0)
	UITheme.apply_aux_text(价格标签)
	价格行.add_child(价格标签)
	var 价格输入: LineEdit = LineEdit.new()
	价格输入.placeholder_text = "灵石数量"
	价格输入.custom_minimum_size = Vector2(160, int(round(34.0 * UITheme.UI_SCALE)))
	价格行.add_child(价格输入)
	发布卡.add_child(价格行)
	# 发布按钮
	var 发布钮: Button = Button.new()
	发布钮.text = "发布求购"
	发布钮.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	UITheme.apply_primary_button_style(发布钮)
	发布钮.pressed.connect(func(): _发布求购(类别选项, 品阶选项, 价格输入))
	发布卡.add_child(发布钮)
	# 现有求购列表
	_段标题("◆ 当前求购信息")
	var 求购列表: Array = Game.拍卖行系统.拍卖会.get("求购列表", [])
	if 求购列表.is_empty():
		_content.add_child(_label("（暂无求购信息）", false))
		return
	for 求购 in 求购列表:
		var 卡: VBoxContainer = _card()
		var 求购者: String = str(求购.get("求购者", "未知"))
		var 物品类别: String = str(求购.get("物品类别", ""))
		var 品阶: String = str(求购.get("品阶", ""))
		var 最高出价: int = int(求购.get("最高出价", 0))
		var 发布时间: int = int(求购.get("发布时间", 0))
		var 状态: String = str(求购.get("状态", "求购中"))
		var _fb14 := _label("[%s·%s] 求购" % [物品类别, 品阶], true)
		卡.add_child(_fb14)
		_fb14.modulate.a = 0.0
		_fb14.create_tween().tween_property(_fb14, "modulate:a", 1.0, 0.25)
		var _fb15 := _label("求购者：%s ｜ 最高出价：%d 灵石 ｜ 状态：%s" % [求购者, 最高出价, 状态], false)
		卡.add_child(_fb15)
		_fb15.modulate.a = 0.0
		_fb15.create_tween().tween_property(_fb15, "modulate:a", 1.0, 0.25)
		# 如果是玩家发布的，显示取消按钮
		if 求购者 == "宗门" or 求购者 == "玩家":
			var 取消钮: Button = Button.new()
			取消钮.text = "取消求购"
			取消钮.custom_minimum_size = Vector2(0, int(round(30.0 * UITheme.UI_SCALE)))
			UITheme.apply_secondary_button_style(取消钮)
			取消钮.pressed.connect(func():
				var 果: Dictionary = Game.取消求购_S34(str(求购.get("id", "")))
				_提示 = str(果.get("原因", "操作完成"))
				refresh()
			)
			卡.add_child(取消钮)
			取消钮.modulate.a = 0.0
			取消钮.create_tween().tween_property(取消钮, "modulate:a", 1.0, 0.25)


## 发布求购
func _发布求购(类别选项: OptionButton, 品阶选项: OptionButton, 价格输入: LineEdit) -> void:
	var 类别列表: Array = ["装备", "丹药", "功法", "灵兽", "材料", "法宝"]
	var 品阶列表: Array = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶"]
	var 物品类别: String = 类别列表[类别选项.selected]
	var 品阶: String = 品阶列表[品阶选项.selected]
	var 最高出价: int = int(价格输入.text)
	if 最高出价 <= 0:
		_提示 = "请输入有效的最高出价"
		refresh()
		return
	var 果: Dictionary = Game.发布求购_S34(物品类别, 品阶, 最高出价)
	if bool(果.get("成功", false)):
		_提示 = str(果.get("原因", "求购发布成功"))
	else:
		_提示 = str(果.get("原因", "发布失败"))
	refresh()

# ===== S53 拍卖预告区 =====
func _拍卖预告区_S53() -> void:
	var 信息: Dictionary = Game.拍卖行系统.获取下次拍卖信息_S53()
	var 卡: VBoxContainer = _card()
	# 标题
	var 标题: Label = Label.new()
	if 信息.get("大拍进行中", false):
		var 当前类型: String = str(信息.get("当前拍卖类型", ""))
		var 类型名: String = {"月拍": "月度拍卖", "季拍": "季度大典", "年拍": "年度盛典"}.get(当前类型, "拍卖盛会")
		标题.text = "◆ 【进行中】聚宝阁%s" % 类型名
		标题.add_theme_color_override("font_color", UITheme.获取吉色())
	else:
		标题.text = "◆ 【预告】下次拍卖：%s（%d日后）" % [str(信息.get("类型名", "")), int(信息.get("距离", 0))]
		标题.add_theme_color_override("font_color", UITheme.获取金文字色())
	UITheme.apply_body_text(标题)
	卡.add_child(标题)
	# 说明
	var 说明: Label = Label.new()
	if 信息.get("大拍进行中", false):
		说明.text = "拍卖盛会正在进行中，诸位道友可前往竞逐稀世之宝。"
	else:
		var 距离: int = int(信息.get("距离", 0))
		var 现实分钟: int = 距离 * 4  # 1游戏日=4现实分钟
		说明.text = "距下次拍卖还有%d游戏日（约%d现实分钟），届时将有稀世之宝现世。" % [距离, 现实分钟]
	UITheme.apply_aux_text(说明)
	卡.add_child(说明)
	# 预热期提示（距离<=3日）
	if not 信息.get("大拍进行中", false) and int(信息.get("距离", 0)) <= 3:
		var 预热: Label = Label.new()
		预热.text = "【预热期】拍卖临近，坊市传闻四起，各方修士云集，竞价活跃度提升！"
		预热.add_theme_color_override("font_color", UITheme.获取警色())
		UITheme.apply_aux_text(预热)
		卡.add_child(预热)
	# 压轴宝物预告（如果距离<=7日）
	if not 信息.get("大拍进行中", false) and int(信息.get("距离", 0)) <= 7:
		var 预告: Label = Label.new()
		预告.text = "【压轴宝物预告】本次拍卖将有王阶及以上宝物现世，具体品相等阁下亲临品鉴。"
		预告.add_theme_color_override("font_color", UITheme.获取警色())
		UITheme.apply_aux_text(预告)
		卡.add_child(预告)
	# 坊市传闻（随机显示一条）
	if randf() < 0.3:  # 30%概率显示传闻
		var 传闻列表: Array = [
			"听说了吗？聚宝阁这次有好东西！",
			"坊市传闻：此次拍卖可能有上古遗物现世。",
			"我听说道友们都在准备灵石，等着大拍呢。",
			"聚宝阁的掌柜这次笑得合不拢嘴，看来有压轴之宝。",
		]
		var 传闻: Label = Label.new()
		传闻.text = "【坊市传闻】%s" % 传闻列表[randi() % 传闻列表.size()]
		传闻.add_theme_color_override("font_color", UITheme.获取弱文字色())
		UITheme.apply_aux_text(传闻)
		卡.add_child(传闻)

# ===== S53 代拍方略区 =====
func _代拍方略区_S53() -> void:
	var 方略: Dictionary = Game.代拍方略
	var 卡: VBoxContainer = _card()
	# 标题行：图标+文字
	var 标题行: HBoxContainer = HBoxContainer.new()
	标题行.add_theme_constant_override("separation", UITheme.GRID / 2)
	var 代拍图标: TextureRect = TextureRect.new()
	代拍图标.texture = UITheme.load_hd_icon("auction_delegate_bid_512")
	代拍图标.custom_minimum_size = Vector2(24, 24)
	代拍图标.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	代拍图标.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	标题行.add_child(代拍图标)
	var 标题: Label = Label.new()
	var 启用: bool = bool(方略.get("启用", false))
	标题.text = "【代拍方略】%s" % ("已启用" if 启用 else "未启用")
	标题.add_theme_color_override("font_color", UITheme.获取吉色() if 启用 else UITheme.获取弱文字色())
	UITheme.apply_body_text(标题)
	标题行.add_child(标题)
	卡.add_child(标题行)
	# 状态说明
	var 说明: Label = Label.new()
	if Game.副宗主弟子ID < 0:
		说明.text = "尚未任命副宗主，无法使用代拍功能。"
		说明.add_theme_color_override("font_color", UITheme.获取凶色())
	elif Game.门派等级 < 2:
		说明.text = "宗门品级不足二品，暂不可使用代拍功能。"
		说明.add_theme_color_override("font_color", UITheme.获取凶色())
	else:
		var 已花费: int = int(方略.get("已花费", 0))
		var 总预算: int = int(方略.get("总预算上限", 0))
		说明.text = "副宗主将依方略代拍，已花费%d/%d灵石。" % [已花费, 总预算]
	UITheme.apply_aux_text(说明)
	卡.add_child(说明)
	# 启用/禁用按钮
	var 行: HBoxContainer = HBoxContainer.new()
	行.add_theme_constant_override("separation", UITheme.GRID)
	var 启用钮: Button = Button.new()
	启用钮.text = "禁用代拍" if 启用 else "启用代拍"
	启用钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	if 启用:
		UITheme.apply_secondary_button_style(启用钮)
	else:
		UITheme.apply_primary_button_style(启用钮)
	启用钮.pressed.connect(func():
		var 新方略: Dictionary = Game.代拍方略.duplicate()
		新方略["启用"] = not 启用
		var 果: Dictionary = Game.拍卖行系统.设置代拍方略_S53(新方略)
		if bool(果.get("成功", false)):
			_提示 = "代拍方略已更新"
		else:
			_提示 = str(果.get("原因", "设置失败"))
		refresh()
	)
	行.add_child(启用钮)
	# 查看报告按钮
	var 报告钮: Button = Button.new()
	报告钮.text = "代拍报告"
	报告钮.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
	UITheme.apply_secondary_button_style(报告钮)
	报告钮.pressed.connect(func():
		_显示代拍报告_S53()
	)
	行.add_child(报告钮)
	卡.add_child(行)
	# 方略详情（如果启用）
	if 启用:
		var 详情: Label = Label.new()
		var 品类: Array = 方略.get("可代拍品类", [])
		详情.text = "可代拍品类：%s\n最低品阶：%s\n单件上限：%d灵石\n优先策略：%s" % [
			", ".join(品类),
			str(方略.get("最低品阶", "宝阶")),
			int(方略.get("单件出价上限", 5000)),
			str(方略.get("优先策略", "品阶优先"))
		]
		UITheme.apply_aux_text(详情)
		卡.add_child(详情)

# 显示代拍报告
func _显示代拍报告_S53() -> void:
	var 报告: Dictionary = Game.拍卖行系统.获取代拍报告_S53()
	var 卡: VBoxContainer = _card()
	var 标题: Label = Label.new()
	标题.text = "【代拍报告】"
	UITheme.apply_body_text(标题)
	卡.add_child(标题)
	# 汇总
	var 汇总: Label = Label.new()
	汇总.text = "总花费：%d灵石 | 剩余预算：%d灵石" % [int(报告.get("总花费", 0)), int(报告.get("剩余预算", 0))]
	UITheme.apply_aux_text(汇总)
	卡.add_child(汇总)
	# 已竞得
	var 已竞得: Array = 报告.get("已竞得", [])
	if 已竞得.size() > 0:
		var 标: Label = Label.new()
		标.text = "✓ 已竞得："
		标.add_theme_color_override("font_color", UITheme.获取吉色())
		UITheme.apply_aux_text(标)
		卡.add_child(标)
		for r in 已竞得:
			var 行: Label = Label.new()
			行.text = "  · %s（%s）- %d灵石" % [str(r.get("物品", "")), str(r.get("品阶", "")), int(r.get("成交价", 0))]
			UITheme.apply_aux_text(行)
			卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	# 未竞得
	var 未竞得: Array = 报告.get("未竞得", [])
	if 未竞得.size() > 0:
		var 标: Label = Label.new()
		标.text = "× 未竞得："
		标.add_theme_color_override("font_color", UITheme.获取凶色())
		UITheme.apply_aux_text(标)
		卡.add_child(标)
		for r in 未竞得:
			var 行: Label = Label.new()
			行.text = "  · %s - %s" % [str(r.get("物品", "")), str(r.get("原因", ""))]
			UITheme.apply_aux_text(行)
			卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)
	# 竞价中
	var 竞价中: Array = 报告.get("竞价中", [])
	if 竞价中.size() > 0:
		var 标: Label = Label.new()
		标.text = "◇ 竞价中："
		标.add_theme_color_override("font_color", UITheme.获取金文字色())
		UITheme.apply_aux_text(标)
		卡.add_child(标)
		for r in 竞价中:
			var 行: Label = Label.new()
			行.text = "  · %s - 出价%d灵石" % [str(r.get("物品", "")), int(r.get("出价", 0))]
			UITheme.apply_aux_text(行)
			卡.add_child(行)
			行.modulate.a = 0.0
			行.create_tween().tween_property(行, "modulate:a", 1.0, 0.25)

# S53：鉴定宝物
func _鉴定宝物_S53(lot: Dictionary) -> void:
	var 拍品ID: String = str(lot.get("id", ""))
	var 果: Dictionary = Game.拍卖行系统.鉴定宝物_S53(拍品ID)
	if bool(果.get("成功", false)):
		var 结果: String = str(果.get("结果", ""))
		var 倍率: float = float(果.get("真实倍率", 1.0))
		if 结果 == "增值":
			_提示 = "慧眼识珠！此宝竟是稀世之珍，价值暴涨%.0f%%！" % ((倍率 - 1.0) * 100)
		elif 结果 == "保值":
			_提示 = "鉴定完毕，此宝价值与预估相若。"
		else:
			_提示 = "可惜！此宝竟是寻常之物，价值大跌%.0f%%。" % ((1.0 - 倍率) * 100)
	else:
		_提示 = str(果.get("原因", "鉴定失败"))
	refresh()
