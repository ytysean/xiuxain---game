extends Control

# 宗务页（05屏「任务·宗务」实机落地）
# 页头：标题「宗务」+ 今日活跃度进度条 + 活跃度宝箱（视觉脚手架）；四 Tab：主线/日常/周常/宗门里程碑；任务卡列表；底部尽数收取。
# 铁律：只读 Game.get() / Game.取主线任务列表()；领取仅调 Game.领取日常 / Game.领取周常 / Game.领取主线 公有 API；不写 GameState。
# Tab 分派：主线 → 实时计算的主线任务（Game.取主线任务列表，含进度/三态）；日常 → 当前日常；周常 → 当前周常；宗门里程碑 → 只读时间轴。
# 决策 3：任务卡 F-pattern（左类型色条 + 标题/描述分层 + 迷你资源图标奖励 + 右按钮）；主线卡额外带进度条与三态按钮。
# 决策 4：二级页统一背景（主背景复用 + 深青蒙层）。
# 红点：主线/日常/周常 存在可领取项时，对应 Tab 显示红点。

signal 任务领取完成
signal 返回主页

const TABS: Array = ["主线", "日常", "周常", "宗门里程碑", "成就", "悬赏榜"]

# 活跃度宝箱三态图标（决策 2 视觉脚手架，复用 art/icons/hd/ 已落盘资产）
const CHEST_LOCKED: String = "chest_locked_36"
const CHEST_CANCLAIM: String = "chest_canclaim_36"
const CHEST_CLAIMED: String = "chest_claimed_36"

var _built: bool = false
var _current_tab: String = "主线"
var _body: VBoxContainer
var _activity_label: Label
var _activity_fill: Panel
var _tab_btns: Dictionary = {}
var _tab_reddots: Dictionary = {}        # Tab 红点节点引用（tab名 -> Panel）
const TAB_COLOR_WEEKLY: Color = Color(0.710, 0.482, 0.910)  # 周常 紫
var _list_parent: VBoxContainer
var _toast_panel: Panel = null
var _toast_label: Label = null
# 宝箱按钮引用（threshold -> Button）+ 本页面内点击领取的本地记忆（数据层无领取状态，仅视觉反馈）
var _chest_buttons: Dictionary = {}
var _chest_local_claimed: Dictionary = {}
var _claim_all_btn: Button = null  # 尽数收取按钮引用（仅日常/周常显示）

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

	_body = VBoxContainer.new()
	_body.name = "Root"
	_body.add_theme_constant_override("margin_left", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_right", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_top", UITheme.MARGIN)
	_body.add_theme_constant_override("margin_bottom", UITheme.MARGIN)
	_body.add_theme_constant_override("separation", int(round(12.0 * UITheme.UI_SCALE)))
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.add_child(_body)

	_build_header(_body)
	_build_activity(_body)
	_build_tabs(_body)
	_build_activity_chests(_body)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)

	_list_parent = VBoxContainer.new()
	_list_parent.name = "List"
	_list_parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_parent.add_theme_constant_override("separation", int(round(12.0 * UITheme.UI_SCALE)))
	scroll.add_child(_list_parent)

	_build_claim_all(_body)

func _build_header(parent: Control) -> void:
	UITheme.make_page_header(parent, "宗务", _on_back_pressed)

func _build_activity(parent: Control) -> void:
	var act := VBoxContainer.new()
	act.name = "Activity"
	act.add_theme_constant_override("separation", int(round(8.0 * UITheme.UI_SCALE)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.GRID)
	var lab := Label.new()
	lab.text = "今日活跃度"
	UITheme.apply_aux_text(lab)
	lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	var val := Label.new()
	val.name = "ActivityValue"
	val.text = "0 / 100"
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_value_text(val)
	val.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	row.add_child(lab)
	row.add_child(val)
	act.add_child(row)

	var prog: Dictionary = _make_progress(UITheme.C05_PROG_TRACK, UITheme.C01_TEXT_GOLD, int(round(8.0 * UITheme.UI_SCALE)))
	_activity_fill = prog.fill
	act.add_child(prog.control)
	parent.add_child(act)
	_activity_label = val

func _build_tabs(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "Tabs"
	bar.add_theme_constant_override("separation", UITheme.GRID)
	for t in TABS:
		var b: Button = _make_tab_button(t)
		_tab_btns[t] = b
		bar.add_child(b)
	parent.add_child(bar)
	_update_tab_styles()

func _build_claim_all(parent: Control) -> void:
	var btn := Button.new()
	btn.name = "ClaimAll"
	btn.text = "尽数收取"
	btn.custom_minimum_size = Vector2(0, int(round(44.0 * UITheme.UI_SCALE)))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_gold_button(btn)
	UITheme.apply_button_label(btn, true)
	btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	btn.pressed.connect(_on_claim_all_pressed)
	parent.add_child(btn)
	_claim_all_btn = btn
	_update_claim_all_visibility()

# ───────── 刷新 ─────────
func refresh() -> void:
	if not _built:
		_build()
	_update_active()
	_update_chest_buttons()
	_populate()
	_update_tab_reddots()

func _update_active() -> void:
	var cur: int = _to_int(Game.get("今日活跃度"), 0)
	var mx: int = _to_int(Game.get("活跃度上限"), 100)
	if _activity_label != null:
		_activity_label.text = "%d / %d" % [cur, mx]
	if _activity_fill != null:
		_activity_fill.anchor_right = clamp(float(cur) / float(maxi(mx, 1)), 0.0, 1.0)

func _populate() -> void:
	if _list_parent == null:
		return
	for child in _list_parent.get_children():
		_list_parent.remove_child(child)
		child.queue_free()
	if not is_instance_valid(Game):
		_add_empty("宗务暂不可查")
		return
	match _current_tab:
		"宗门里程碑":
			_populate_里程碑()
			return
		"成就":
			_populate_成就()
			return
		"悬赏榜":
			_populate_悬赏榜()
			return
		"主线":
			var mains: Array = []
			if Game.has_method("取主线任务列表"):
				mains = Game.取主线任务列表()
			# P3联动：显示已解锁系统
			if Game.has_method("获取已解锁系统"):
				var 已解锁: Array = Game.获取已解锁系统()
				if not 已解锁.is_empty():
					var panel := PanelContainer.new()
					panel.custom_minimum_size = Vector2(0, 80)
					_list_parent.add_child(panel)
					var vb := VBoxContainer.new()
					vb.add_theme_constant_override("separation", 4)
					panel.add_child(vb)
					var title := Label.new()
					title.text = "【宗门已启道法】"
					UITheme.apply_aux_font_sized(title, 14)
					title.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
					vb.add_child(title)
					var sys_label := Label.new()
					sys_label.text = " · ".join(已解锁)
					UITheme.apply_body_font_sized(sys_label, 12)
					sys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					vb.add_child(sys_label)
			if mains.is_empty():
				_add_empty("宗务清闲，静待机缘")
			else:
				for m in mains:
					_add_main_card(m)
			return
		"周常":
			var wk: Variant = Game.get("当前周常")
			if wk is Dictionary and not wk.is_empty():
				var _wk_state: String = ""
				if Game.has_method("取周常任务"):
					var _wd: Variant = Game.取周常任务()
					if _wd is Dictionary:
						_wk_state = str(_wd.get("state", ""))
				_add_task_card({"q": wk, "claimed": bool(Game.get("周常已领")), "weekly": true, "state": _wk_state})
			else:
				_add_empty("本周宗务清闲")
			return
		_:
			var tasks: Array = _collect_tasks()
			if tasks.is_empty():
				_add_empty("宗务清闲，静待机缘" % _current_tab)
			else:
				for t in tasks:
					_add_task_card(t)

func _collect_tasks() -> Array:
	# 仅日常走通用任务卡；主线/周常已在 _populate 分流
	var out: Array = []
	var d: Array = _as_array(Game.get("当前日常"))
	var dl: Array = _as_array(Game.get("日常已领"))
	# S1-2：复用后端权威三态（取日常任务列表 已按 当前/目标 算出 state）
	var dlist: Array = []
	if Game.has_method("取日常任务列表"):
		dlist = Game.取日常任务列表()
	for i in d.size():
		var _st: String = ""
		if i < dlist.size():
			_st = str(dlist[i].get("state", ""))
		out.append({"q": d[i], "claimed": (dl[i] if i < dl.size() else false), "weekly": false, "idx": i, "state": _st})
	return out

# ───────── 宗门里程碑（拍板结论1/3）：只读时间轴，不复用任务卡 ─────────
func _populate_里程碑() -> void:
	var cfg: Array = _as_array(Game.get("里程碑配置"))
	# 达成序：已达成按「达成先后」(里程碑_已达成 列表顺序，越后越新) 降序；未达成置 -1 排末尾
	var 达成序: Array = _as_array(Game.get("里程碑_已达成"))
	var items: Array = []
	for m in cfg:
		var id: String = str(m.get("里程碑ID", ""))
		var done: bool = bool(m.get("已达成", false))
		var ord_idx: int = 达成序.find(id) if done else -1
		items.append({"m": m, "done": done, "ord": ord_idx})
	items.sort_custom(func(a, b): return a["ord"] > b["ord"])
	for it in items:
		_list_parent.add_child(_make_milestone_card(it["m"], it["done"]))
	_add_milestone_footer()

func _make_milestone_card(m: Dictionary, done: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "MilestoneCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_FLOAT_BG
	sb.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	sb.border_color = UITheme.C01_TEXT_GOLD if done else UITheme.C01_GOLD_LINE
	sb.set_content_margin_all(UITheme.PAD_PANEL)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 节点图标（状态圆点）：已达成金点、未达成灰点（零资源依赖、零臆造）
	var dot: Control = _make_milestone_dot(done)
	hb.add_child(dot)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))

	var title: Label = Label.new()
	title.text = str(m.get("名称", "—"))
	UITheme.apply_section_title(title)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if done else UITheme.C01_TEXT_PRIMARY)
	mid.add_child(title)

	var cond: Label = Label.new()
	cond.text = _里程碑条件描述(m)
	cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(cond)
	cond.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	mid.add_child(cond)

	var rew: Label = Label.new()
	rew.text = "奖励：" + _里程碑奖励描述(m)
	UITheme.apply_aux_text(rew)
	rew.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if done else UITheme.C01_TEXT_TERTIARY)
	mid.add_child(rew)

	hb.add_child(mid)

	# 状态标记位（拍板结论1：新增状态标识，去操作按钮区）
	var tag: Label = Label.new()
	tag.text = "已达成" if done else "未达成"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	tag.custom_minimum_size = Vector2(int(round(72.0 * UITheme.UI_SCALE)), 0)
	UITheme.apply_aux_text(tag)
	tag.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if done else UITheme.C01_TEXT_TERTIARY)
	hb.add_child(tag)

	card.add_child(hb)
	return card

func _make_milestone_dot(done: bool) -> Control:
	var p: Panel = Panel.new()
	p.name = "Dot"
	p.custom_minimum_size = Vector2(int(round(16.0 * UITheme.UI_SCALE)), int(round(16.0 * UITheme.UI_SCALE)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_TEXT_GOLD if done else Color(0.5, 0.5, 0.5, 0.6)
	sb.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	sb.set_content_margin_all(0)
	sb.set_border_width_all(0)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _里程碑条件描述(m: Dictionary) -> String:
	var t: String = str(m.get("触发类型", ""))
	var e: String = str(m.get("触发事件", ""))
	var v: String = str(m.get("触发阈值", ""))
	match t:
		"事件": return "触发事件：「%s」" % e
		"状态": return "达成状态：弟子%s" % e
		"阈值": return "指标「%s」达到 %s" % [e, v]
		_: return "达成条件"

func _里程碑奖励描述(m: Dictionary) -> String:
	var t: String = str(m.get("赏赐增益类型", ""))
	var v: float = float(m.get("赏赐增益值", 0))
	if t == "声望":
		return "声望+%d" % int(v)
	elif t == "产出池":
		return "产出池+%d%%" % int(v * 100)
	return "宗门增益"

func _add_milestone_footer() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", int(round(16.0 * UITheme.UI_SCALE)))
	_list_parent.add_child(sep)
	var lab: Label = Label.new()
	lab.text = "传承史册·宗门里程碑一览"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(lab)
	lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	_list_parent.add_child(lab)

# ───────── 成就（拍板结论1：成就 Tab 真实化；S1 安全子集 19 条接线 + 145 条 placeholder 置灰容错）─────────
func _populate_成就() -> void:
	var cfg: Array = _as_array(Game.get("成就配置"))
	if cfg.is_empty():
		_add_empty("（成就配置加载中）")
		return
	var 达成序: Array = _as_array(Game.get("成就_已达成"))
	var items: Array = []
	for a in cfg:
		var id: String = str(a.get("achievement_id", ""))
		var done: bool = bool(a.get("已达成", false))
		var ord_idx: int = 达成序.find(id) if done else -1
		items.append({"a": a, "done": done, "ord": ord_idx})
	items.sort_custom(func(x, y): return x["ord"] > y["ord"])
	# 头部：点数累计（仅统计已接线成就，placeholder 不计入分母）
	var 已得: int = 0
	var 总: int = 0
	for it in items:
		var pn: int = _to_int(it["a"].get("point_num"), 0)
		if str(it["a"].get("condition_type", "placeholder")) != "placeholder":
			总 += pn
			if it["done"]:
				已得 += pn
	_list_parent.add_child(_make_achievement_header(已得, 总))
	for it in items:
		_list_parent.add_child(_make_achievement_card(it["a"], it["done"]))
	_add_achievement_footer()

# ───────── 悬赏榜（S28）─────────
func _populate_悬赏榜() -> void:
	# 发布悬赏按钮
	var pub_btn := Button.new()
	pub_btn.name = "PublishBounty"
	pub_btn.text = "发布悬赏"
	pub_btn.custom_minimum_size = Vector2(0, int(round(44.0 * UITheme.UI_SCALE)))
	pub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_gold_button(pub_btn)
	UITheme.apply_button_label(pub_btn, true)
	pub_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	pub_btn.pressed.connect(_on_publish_bounty_pressed)
	_list_parent.add_child(pub_btn)
	# 悬赏列表
	var 悬赏榜: Dictionary = Game.get("宗门悬赏榜") if is_instance_valid(Game) else {}
	if 悬赏榜 == null or 悬赏榜.is_empty():
		_add_empty("悬赏榜空空如也，点击上方按钮发布悬赏")
		return
	for bid in 悬赏榜:
		var b: Dictionary = 悬赏榜[bid]
		_list_parent.add_child(_make_bounty_card(b))

func _make_bounty_card(b: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "BountyCard_" + str(b.get("悬赏ID", ""))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_FLOAT_BG
	sb.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	var 状态: String = str(b.get("状态", ""))
	var border_col: Color = UITheme.C01_TEXT_GOLD if 状态 == "进行中" else (UITheme.C05_PROG_FILL if 状态 == "招募中" else Color(0.5, 0.5, 0.5))
	sb.border_color = border_col
	sb.set_content_margin_all(UITheme.PAD_PANEL)
	card.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))
	card.add_child(vb)
	# 标题行
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", UITheme.GRID)
	var title := Label.new()
	title.text = "【%s】%s×%d" % [str(b.get("目标物类别", "")), str(b.get("目标物名称", "")), int(b.get("需求数量", 0))]
	UITheme.apply_title_text(title)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	# 评级标签
	var 评级: String = str(b.get("评级", "C"))
	var rating_lab := Label.new()
	rating_lab.text = 评级 + "级"
	UITheme.apply_value_text(rating_lab)
	var rating_col: Color = Color(1.0, 0.84, 0.0)  # S级金色
	match 评级:
		"A": rating_col = Color(0.8, 0.2, 0.2)  # A级红色
		"B": rating_col = Color(0.2, 0.6, 1.0)  # B级蓝色
		"C": rating_col = Color(0.5, 0.5, 0.5)  # C级灰色
	rating_lab.add_theme_color_override("font_color", rating_col)
	title_row.add_child(rating_lab)
	var status_lab := Label.new()
	status_lab.text = 状态
	UITheme.apply_aux_text(status_lab)
	status_lab.add_theme_color_override("font_color", border_col)
	title_row.add_child(status_lab)
	vb.add_child(title_row)
	# 进度
	var 已收集: int = int(b.get("已收集", 0))
	var 需求: int = int(b.get("需求数量", 0))
	var prog: Dictionary = _make_progress(UITheme.C05_PROG_TRACK, UITheme.C01_TEXT_GOLD, int(round(6.0 * UITheme.UI_SCALE)))
	prog.fill.anchor_right = clamp(float(已收集) / float(max(需求, 1)), 0.0, 1.0)
	vb.add_child(prog.control)
	var prog_lab := Label.new()
	prog_lab.text = "进度：%d/%d" % [已收集, 需求]
	UITheme.apply_aux_text(prog_lab)
	prog_lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	vb.add_child(prog_lab)
	# 奖励和接取人
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", UITheme.GRID)
	var reward_lab := Label.new()
	var 奖励类型: String = str(b.get("奖励类型", ""))
	if 奖励类型 == "物品":
		reward_lab.text = "奖励：%s" % str(b.get("奖励物品名称", "未知物品"))
	else:
		reward_lab.text = "奖励：%s×%d" % [奖励类型, int(b.get("奖励数量", 0))]
	UITheme.apply_aux_text(reward_lab)
	reward_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(reward_lab)
	var 接取人ID: int = int(b.get("接取弟子ID", -1))
	if 接取人ID >= 0:
		var d: Object = Game._取弟子(接取人ID) if Game.has_method("_取弟子") else null
		var taker_lab := Label.new()
		taker_lab.text = "接取人：%s" % (str(d.姓名) if d != null else "未知")
		UITheme.apply_aux_text(taker_lab)
		taker_lab.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		info_row.add_child(taker_lab)
	vb.add_child(info_row)
	# 有效期
	var 累计日: int = int(Game.累计游戏日) if "累计游戏日" in Game else 0
	var 剩余日: int = int(b.get("发布日", 0)) + int(b.get("有效期", 30)) - 累计日
	var expire_lab := Label.new()
	expire_lab.text = "剩余：%d日" % max(0, 剩余日)
	UITheme.apply_aux_text(expire_lab)
	expire_lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	vb.add_child(expire_lab)
	# 撤销按钮（仅招募中状态）
	if 状态 == "招募中":
		var cancel_btn := Button.new()
		cancel_btn.text = "撤销悬赏"
		cancel_btn.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_ghost_button(cancel_btn)
		UITheme.apply_button_label(cancel_btn, false)
		cancel_btn.pressed.connect(_on_cancel_bounty.bind(str(b.get("悬赏ID", ""))))
		vb.add_child(cancel_btn)
	return card

# 发布面板状态
var _publish_panel: Panel = null
var _publish_category: String = "灵草"
var _publish_item: String = ""
var _publish_count: int = 5
var _publish_reward_type: String = "灵石"
var _publish_reward_count: int = 1000
var _publish_duration: int = 30
var _publish_item_list: VBoxContainer = null
var _publish_reward_item: String = ""
var _reward_item_list_panel: VBoxContainer = null

# 预设物品库（按分类）
const 悬赏物品库: Dictionary = {
	"灵草": ["百年灵芝", "千年人参", "雪莲", "何首乌", "紫河车", "九叶灵芝", "幽冥草", "太阳神花"],
	"矿石": ["玄精铁", "寒铁", "紫金", "星辰砂", "九天玄铁", "万年寒铁", "混沌石", "太阳神金"],
	"妖兽材料": ["妖兽内丹", "妖兽精血", "妖兽皮", "妖兽骨", "妖丹", "妖王内丹", "神兽精血", "凶兽骸骨"],
	"丹药": ["筑基丹", "疗伤丹", "培元丹", "突破丹", "金丹", "元婴丹", "化神丹", "渡劫丹"],
	"符箓": ["火球符", "护盾符", "传送符", "隐身符", "天雷符", "冰封符", "巨力符", "定神符"],
	"特殊物品": ["储物袋", "秘境钥匙", "古地图", "传承玉简", "天材地宝", "空间戒指", "传讯玉符", "护身玉佩"],
}

func _on_publish_bounty_pressed() -> void:
	# 打开完整发布面板
	_open_publish_panel()

func _open_publish_panel() -> void:
	if _publish_panel != null:
		_close_publish_panel()
	_publish_category = "灵草"
	_publish_item = ""
	_publish_count = 5
	_publish_reward_type = "灵石"
	_publish_reward_count = 1000
	_publish_duration = 30
	# 半透明遮罩
	var overlay := ColorRect.new()
	overlay.name = "PublishOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	# 面板
	var panel := Panel.new()
	panel.name = "PublishPanel"
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(UITheme.C01_FLOAT_BG, UITheme.C01_GOLD_LINE, 12, 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(int(round(340.0 * UITheme.UI_SCALE)), int(round(480.0 * UITheme.UI_SCALE)))
	overlay.add_child(panel)
	_publish_panel = panel
	var vb := VBoxContainer.new()
	vb.name = "PublishVB"
	vb.add_theme_constant_override("separation", int(round(8.0 * UITheme.UI_SCALE)))
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("margin_left", UITheme.PAD_PANEL)
	vb.add_theme_constant_override("margin_right", UITheme.PAD_PANEL)
	vb.add_theme_constant_override("margin_top", UITheme.PAD_PANEL)
	vb.add_theme_constant_override("margin_bottom", UITheme.PAD_PANEL)
	panel.add_child(vb)
	# 标题
	var title := Label.new()
	title.text = "发布悬赏"
	UITheme.apply_title_text(title)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	# 分类标签（横向滚动）
	var cat_scroll := ScrollContainer.new()
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
	vb.add_child(cat_scroll)
	var cat_hb := HBoxContainer.new()
	cat_hb.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))
	cat_scroll.add_child(cat_hb)
	for cat in 悬赏物品库.keys():
		var btn := Button.new()
		btn.text = str(cat)
		btn.custom_minimum_size = Vector2(int(round(60.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if str(cat) == _publish_category:
			_style_gold_button(btn)
			btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		else:
			_style_ghost_button(btn)
		UITheme.apply_button_label(btn, false)
		btn.pressed.connect(_on_select_category.bind(str(cat), btn))
		cat_hb.add_child(btn)
	# 物品列表（纵向滚动）
	var item_scroll := ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_scroll.custom_minimum_size = Vector2(0, int(round(160.0 * UITheme.UI_SCALE)))
	vb.add_child(item_scroll)
	_publish_item_list = VBoxContainer.new()
	_publish_item_list.name = "ItemList"
	_publish_item_list.add_theme_constant_override("separation", int(round(4.0 * UITheme.UI_SCALE)))
	_publish_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(_publish_item_list)
	_refresh_publish_item_list()
	# 数量选择
	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", UITheme.GRID)
	var count_lab := Label.new()
	count_lab.text = "需求数量："
	UITheme.apply_aux_text(count_lab)
	count_row.add_child(count_lab)
	var count_minus := Button.new()
	count_minus.text = "-"
	count_minus.custom_minimum_size = Vector2(int(round(36.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
	_style_ghost_button(count_minus)
	count_minus.pressed.connect(func(): _publish_count = max(1, _publish_count - 1); _refresh_publish_labels())
	count_row.add_child(count_minus)
	var count_val := Label.new()
	count_val.name = "CountVal"
	count_val.text = str(_publish_count)
	count_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_value_text(count_val)
	count_row.add_child(count_val)
	var count_plus := Button.new()
	count_plus.text = "+"
	count_plus.custom_minimum_size = Vector2(int(round(36.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
	_style_gold_button(count_plus)
	count_plus.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	count_plus.pressed.connect(func(): _publish_count += 1; _refresh_publish_labels())
	count_row.add_child(count_plus)
	vb.add_child(count_row)
	# 奖励类型选择
	var reward_row := HBoxContainer.new()
	reward_row.add_theme_constant_override("separation", UITheme.GRID)
	var reward_lab := Label.new()
	reward_lab.text = "奖励类型："
	UITheme.apply_aux_text(reward_lab)
	reward_row.add_child(reward_lab)
	for rt in ["灵石", "贡献点", "物品"]:
		var rt_btn := Button.new()
		rt_btn.text = rt
		rt_btn.custom_minimum_size = Vector2(int(round(60.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
		if rt == _publish_reward_type:
			_style_gold_button(rt_btn)
			rt_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		else:
			_style_ghost_button(rt_btn)
		UITheme.apply_button_label(rt_btn, false)
		rt_btn.pressed.connect(func(): _publish_reward_type = rt; _publish_reward_item = ""; _refresh_publish_panel())
		reward_row.add_child(rt_btn)
	vb.add_child(reward_row)
	# 物品奖励选择（仅当奖励类型为物品时显示）
	if _publish_reward_type == "物品":
		var item_reward_row := HBoxContainer.new()
		item_reward_row.add_theme_constant_override("separation", UITheme.GRID)
		var ir_lab := Label.new()
		ir_lab.text = "奖励物品："
		UITheme.apply_aux_text(ir_lab)
		item_reward_row.add_child(ir_lab)
		var ir_val := Label.new()
		ir_val.text = _publish_reward_item if _publish_reward_item != "" else "未选择"
		ir_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ir_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UITheme.apply_value_text(ir_val)
		ir_val.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		item_reward_row.add_child(ir_val)
		var ir_btn := Button.new()
		ir_btn.text = "选择"
		ir_btn.custom_minimum_size = Vector2(int(round(60.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
		_style_gold_button(ir_btn)
		ir_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		UITheme.apply_button_label(ir_btn, false)
		ir_btn.pressed.connect(_show_reward_item_selector)
		item_reward_row.add_child(ir_btn)
		vb.add_child(item_reward_row)
	# 奖励数量
	var reward_count_row := HBoxContainer.new()
	reward_count_row.add_theme_constant_override("separation", UITheme.GRID)
	var rc_lab := Label.new()
	rc_lab.text = "奖励数量："
	UITheme.apply_aux_text(rc_lab)
	reward_count_row.add_child(rc_lab)
	var rc_minus := Button.new()
	rc_minus.text = "-"
	rc_minus.custom_minimum_size = Vector2(int(round(36.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
	_style_ghost_button(rc_minus)
	rc_minus.pressed.connect(func(): _publish_reward_count = max(10, _publish_reward_count - 100); _refresh_publish_labels())
	reward_count_row.add_child(rc_minus)
	var rc_val := Label.new()
	rc_val.name = "RewardVal"
	rc_val.text = str(_publish_reward_count)
	rc_val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rc_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_value_text(rc_val)
	reward_count_row.add_child(rc_val)
	var rc_plus := Button.new()
	rc_plus.text = "+"
	rc_plus.custom_minimum_size = Vector2(int(round(36.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
	_style_gold_button(rc_plus)
	rc_plus.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	rc_plus.pressed.connect(func(): _publish_reward_count += 100; _refresh_publish_labels())
	reward_count_row.add_child(rc_plus)
	vb.add_child(reward_count_row)
	# 有效期选择
	var dur_row := HBoxContainer.new()
	dur_row.add_theme_constant_override("separation", UITheme.GRID)
	var dur_lab := Label.new()
	dur_lab.text = "有效期："
	UITheme.apply_aux_text(dur_lab)
	dur_row.add_child(dur_lab)
	for d in [7, 15, 30, 60]:
		var d_btn := Button.new()
		d_btn.text = "%d天" % d
		d_btn.custom_minimum_size = Vector2(int(round(50.0 * UITheme.UI_SCALE)), int(round(32.0 * UITheme.UI_SCALE)))
		if d == _publish_duration:
			_style_gold_button(d_btn)
			d_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		else:
			_style_ghost_button(d_btn)
		UITheme.apply_button_label(d_btn, false)
		d_btn.pressed.connect(func(): _publish_duration = d; _refresh_publish_panel())
		dur_row.add_child(d_btn)
	vb.add_child(dur_row)
	# 确认/取消按钮
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UITheme.GRID)
	var cancel_btn := Button.new()
	cancel_btn.text = "取消"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.custom_minimum_size = Vector2(0, int(round(40.0 * UITheme.UI_SCALE)))
	_style_ghost_button(cancel_btn)
	UITheme.apply_button_label(cancel_btn, false)
	cancel_btn.pressed.connect(_close_publish_panel)
	btn_row.add_child(cancel_btn)
	var confirm_btn := Button.new()
	confirm_btn.text = "确认发布"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size = Vector2(0, int(round(40.0 * UITheme.UI_SCALE)))
	_style_gold_button(confirm_btn)
	UITheme.apply_button_label(confirm_btn, true)
	confirm_btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
	confirm_btn.pressed.connect(_on_confirm_publish)
	btn_row.add_child(confirm_btn)
	vb.add_child(btn_row)

func _refresh_publish_item_list() -> void:
	if _publish_item_list == null:
		return
	for child in _publish_item_list.get_children():
		_publish_item_list.remove_child(child)
		child.queue_free()
	var items: Array = 悬赏物品库.get(_publish_category, [])
	for item in items:
		var btn := Button.new()
		btn.text = str(item)
		btn.custom_minimum_size = Vector2(0, int(round(36.0 * UITheme.UI_SCALE)))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if str(item) == _publish_item:
			_style_gold_button(btn)
			btn.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		else:
			_style_ghost_button(btn)
		UITheme.apply_button_label(btn, false)
		btn.pressed.connect(_on_select_item.bind(str(item)))
		_publish_item_list.add_child(btn)

func _on_select_category(cat: String, btn: Button) -> void:
	_publish_category = cat
	_publish_item = ""
	_refresh_publish_panel()

func _on_select_item(item: String) -> void:
	_publish_item = item
	_refresh_publish_item_list()

func _refresh_publish_labels() -> void:
	if _publish_panel == null:
		return
	var count_val = _publish_panel.find_child("CountVal", true, false)
	if count_val != null:
		count_val.text = str(_publish_count)
	var reward_val = _publish_panel.find_child("RewardVal", true, false)
	if reward_val != null:
		reward_val.text = str(_publish_reward_count)

func _refresh_publish_panel() -> void:
	# 简化：关闭重开（避免复杂的状态刷新）
	_close_publish_panel()
	_open_publish_panel()

func _on_confirm_publish() -> void:
	if _publish_item == "":
		_show_toast("请先选择目标物品")
		return
	var r: Dictionary = Game.发布悬赏(_publish_category, _publish_item, _publish_count, _publish_reward_type, _publish_reward_count, _publish_duration, _publish_reward_item)
	if bool(r.get("成功", false)):
		_show_toast("悬赏发布成功！")
		_close_publish_panel()
		refresh()
	else:
		_show_toast("发布失败：%s" % str(r.get("原因", "")))

func _show_reward_item_selector() -> void:
	# 显示宗门库房中的物品列表（简化：显示前20件）
	if _publish_panel == null:
		return
	# 移除旧的物品列表面板
	if _reward_item_list_panel != null and is_instance_valid(_reward_item_list_panel):
		_reward_item_list_panel.queue_free()
		_reward_item_list_panel = null
	var panel := VBoxContainer.new()
	panel.name = "RewardItemSelector"
	panel.add_theme_constant_override("separation", int(round(4.0 * UITheme.UI_SCALE)))
	# 从宗门库房读取物品
	var 库房: Array = Game.get("宗门库房") if is_instance_valid(Game) else []
	var 显示数: int = 0
	for it in 库房:
		if it != null and it is Item:
			var btn := Button.new()
			btn.text = "%s（%s）" % [str(it.名称), str(it.品阶)]
			btn.custom_minimum_size = Vector2(0, int(round(32.0 * UITheme.UI_SCALE)))
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_style_ghost_button(btn)
			UITheme.apply_button_label(btn, false)
			btn.pressed.connect(_on_select_reward_item.bind(str(it.名称)))
			panel.add_child(btn)
			显示数 += 1
			if 显示数 >= 15:
				break
	if 显示数 == 0:
		var empty_lab := Label.new()
		empty_lab.text = "宗门库房为空"
		empty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(empty_lab)
	# 插入到发布面板中（在奖励类型行后面）
	var publish_vb = _publish_panel.find_child("PublishVB", true, false)
	if publish_vb != null:
		# 找到奖励类型行的索引，在其后插入
		var insert_idx: int = -1
		for i in range(publish_vb.get_child_count()):
			var child = publish_vb.get_child(i)
			if child is HBoxContainer and child.get_child_count() > 0:
				var first = child.get_child(0)
				if first is Label and "奖励类型" in str(first.text):
					insert_idx = i + 1
					break
		if insert_idx >= 0:
			panel.add_theme_constant_override("margin_left", int(round(20.0 * UITheme.UI_SCALE)))
			publish_vb.add_child(panel)
			publish_vb.move_child(panel, insert_idx)
	_reward_item_list_panel = panel

func _on_select_reward_item(物品名: String) -> void:
	_publish_reward_item = 物品名
	_refresh_publish_panel()

func _close_publish_panel() -> void:
	if _publish_panel != null and is_instance_valid(_publish_panel):
		var overlay = _publish_panel.get_parent()
		_publish_panel.queue_free()
		if overlay != null:
			overlay.queue_free()
	_publish_panel = null
	_publish_item_list = null
	_reward_item_list_panel = null

func _on_cancel_bounty(悬赏ID: String) -> void:
	var r: Dictionary = Game.撤销悬赏(悬赏ID)
	if bool(r.get("成功", false)):
		_show_toast("悬赏已撤销")
	else:
		_show_toast("撤销失败：%s" % str(r.get("原因", "")))
	refresh()

func _make_achievement_header(已得: int, 总: int) -> Control:
	var hb := HBoxContainer.new()
	hb.name = "PointsHeader"
	hb.add_theme_constant_override("separation", UITheme.GRID)
	var lab := Label.new()
	lab.text = "成就点数"
	UITheme.apply_aux_text(lab)
	lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	hb.add_child(lab)
	var val := Label.new()
	val.text = "%d / %d" % [已得, 总]
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.apply_value_text(val)
	val.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	hb.add_child(val)
	return hb

func _make_achievement_card(a: Dictionary, done: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "AchievementCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grade: String = str(a.get("grade", ""))
	var is_placeholder: bool = str(a.get("condition_type", "placeholder")) == "placeholder"
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_FLOAT_BG
	sb.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	var border_col: Color = UITheme.C01_TEXT_GOLD if done else (UITheme.C01_GOLD_LINE if not is_placeholder else Color(0.4, 0.4, 0.4, 0.5))
	sb.border_color = border_col
	sb.set_content_margin_all(UITheme.PAD_PANEL)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bar_color: Color = _achievement_grade_color(grade) if not is_placeholder else Color(0.4, 0.4, 0.4, 0.5)
	var bar: Control = _make_card_left_bar(bar_color)
	hb.add_child(bar)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(round(8.0 * UITheme.UI_SCALE)))
	var title: Label = Label.new()
	title.text = str(a.get("ach_name", "—"))
	UITheme.apply_section_title(title)
	var title_col: Color = UITheme.C01_TEXT_GOLD if done else (UITheme.C01_TEXT_PRIMARY if not is_placeholder else Color(0.6, 0.6, 0.6, 0.8))
	title.add_theme_color_override("font_color", title_col)
	title_row.add_child(title)
	var cat_lab: Label = Label.new()
	cat_lab.text = "[%s]" % str(a.get("category", ""))
	UITheme.apply_aux_text(cat_lab)
	cat_lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	title_row.add_child(cat_lab)
	mid.add_child(title_row)

	var cond: Label = Label.new()
	cond.text = _成就条件描述(a)
	cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(cond)
	var cond_col: Color = UITheme.C01_TEXT_TERTIARY if not is_placeholder else Color(0.5, 0.5, 0.5, 0.8)
	cond.add_theme_color_override("font_color", cond_col)
	mid.add_child(cond)
	
	# 大厂标准：未达成成就添加进度条（使用新添加的Game.获取成就进度()）
	if not done and not is_placeholder and is_instance_valid(Game) and Game.has_method("获取成就进度"):
		var 成就ID: String = str(a.get("achievement_id", ""))
		if 成就ID != "":
			var 进度: Dictionary = Game.获取成就进度(成就ID)
			if bool(进度.get("成功", false)) and not bool(进度.get("已达成", true)):
				var 当前值: float = float(进度.get("当前值", 0))
				var 目标值: float = float(进度.get("目标值", 1))
				var 进度百分比: float = clamp(当前值 / max(目标值, 1), 0.0, 1.0)
				
				# 进度条容器
				var progress_container := VBoxContainer.new()
				progress_container.name = "ProgressContainer"
				progress_container.add_theme_constant_override("separation", 4)
				
				# 进度文字
				var progress_text := Label.new()
				progress_text.name = "ProgressText"
				progress_text.text = "进度：%d / %d (%.0f%%)" % [int(当前值), int(目标值), 进度百分比 * 100]
				progress_text.add_theme_font_size_override("font_size", 12)
				progress_text.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
				progress_container.add_child(progress_text)
				
				# 进度条背景
				var progress_bg := Panel.new()
				progress_bg.name = "ProgressBG"
				progress_bg.custom_minimum_size = Vector2(0, 8)
				var bg_style := StyleBoxFlat.new()
				bg_style.bg_color = Color(0.2, 0.2, 0.25, 1.0)
				bg_style.set_corner_radius_all(4)
				bg_style.set_content_margin_all(0)
				bg_style.set_border_width_all(0)
				progress_bg.add_theme_stylebox_override("panel", bg_style)
				
				# 进度条填充
				var progress_fill := Panel.new()
				progress_fill.name = "ProgressFill"
				progress_fill.anchor_left = 0.0
				progress_fill.anchor_top = 0.0
				progress_fill.anchor_bottom = 1.0
				progress_fill.anchor_right = 进度百分比
				progress_fill.size_flags_horizontal = Control.SIZE_FILL
				var fill_style := StyleBoxFlat.new()
				fill_style.bg_color = UITheme.C05_REWARD_BLUE
				fill_style.set_corner_radius_all(4)
				fill_style.set_content_margin_all(0)
				fill_style.set_border_width_all(0)
				progress_fill.add_theme_stylebox_override("panel", fill_style)
				progress_bg.add_child(progress_fill)
				
				progress_container.add_child(progress_bg)
				mid.add_child(progress_container)
	
	_add_achievement_reward(mid, a, is_placeholder)
	hb.add_child(mid)

	var tag: Label = Label.new()
	tag.text = "已达成" if done else ("神秘奖励" if is_placeholder else "未达成")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_horizontal = Control.SIZE_SHRINK_END
	tag.custom_minimum_size = Vector2(int(round(72.0 * UITheme.UI_SCALE)), 0)
	UITheme.apply_aux_text(tag)
	var tag_col: Color = UITheme.C01_TEXT_GOLD if done else (Color(0.5, 0.5, 0.5, 0.8) if is_placeholder else UITheme.C01_TEXT_TERTIARY)
	tag.add_theme_color_override("font_color", tag_col)
	hb.add_child(tag)

	card.add_child(hb)
	if is_placeholder:
		card.modulate = Color(0.65, 0.65, 0.65, 0.85)
	return card

func _add_achievement_reward(parent: Control, a: Dictionary, is_placeholder: bool) -> void:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", int(round(10.0 * UITheme.UI_SCALE)))
	if is_placeholder:
		var lab: Label = Label.new()
		lab.text = "奖励：神秘奖励（S2 待实装）"
		UITheme.apply_aux_text(lab)
		lab.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.8))
		hb.add_child(lab)
		parent.add_child(hb)
		return
	# 标准资源（q-1 拍板：灵石/灵气/声望 三标准资源；功勋非标准资源，不发）
	var parts: Array = [
		["reward_lingshi", "灵石", UITheme.C01_TEXT_GOLD],
		["reward_lingqi", "灵气", UITheme.C05_REWARD_BLUE],
		["reward_shengwang", "声望", UITheme.C01_TEXT_GOLD],
	]
	var any: bool = false
	for p in parts:
		var key: String = p[0]
		var nm: String = p[1]
		var col: Color = p[2]
		var v: int = _to_int(a.get(key), 0)
		if v <= 0:
			continue
		var icon: Texture2D = UITheme.load_icon(nm)
		if icon != null:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(int(round(20.0 * UITheme.UI_SCALE)), int(round(20.0 * UITheme.UI_SCALE)))
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(tr)
		var lab: Label = Label.new()
		lab.text = "+%d" % v
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", col)
		hb.add_child(lab)
		any = true
	if not any:
		var lab: Label = Label.new()
		lab.text = "无奖励"
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		hb.add_child(lab)
	parent.add_child(hb)

func _成就条件描述(a: Dictionary) -> String:
	var desc: String = str(a.get("condition_desc", ""))
	if desc != "":
		return desc
	var ct: String = str(a.get("condition_type", ""))
	var p: String = str(a.get("condition_param", ""))
	var extra: String = str(a.get("condition_extra", ""))
	match ct:
		"sect_level": return "门派等级 ≥ %s" % p
		"disciple_count": return "弟子数 ≥ %s" % p
		"disciple_realm_count": return "拥有 %s 期弟子 ≥ %s 名" % [extra, p]
		"disciple_all_realm": return "全宗弟子均达 %s" % extra
		"disciple_linggen": return "拥有 %s 灵根弟子 ≥ %s 名" % [extra, p]
		"master_realm": return "掌门境界 ≥ 第 %s 重" % p
		"beast_count": return "灵兽数 ≥ %s" % p
		"building_level": return "%s 殿阁等级 ≥ %s" % [extra, p]
		"building_any_level": return "任意殿阁等级 ≥ %s" % p
		"building_total_level": return "殿阁总等级 ≥ %s" % p
		"reputation": return "声望 ≥ %s" % p
		"prosperity": return "繁荣度 ≥ %s" % p
		_: return "达成条件"

func _achievement_grade_color(grade: String) -> Color:
	match grade:
		"传说": return Color(0.95, 0.55, 0.25)
		"史诗": return Color(0.65, 0.35, 0.85)
		"稀有": return UITheme.C01_TEXT_GOLD
		"普通": return UITheme.C01_FLOAT_BG
		_: return UITheme.C01_FLOAT_BG

func _add_achievement_footer() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", int(round(16.0 * UITheme.UI_SCALE)))
	_list_parent.add_child(sep)
	var lab: Label = Label.new()
	lab.text = "（共 %d 条成就，S1 已实装 %d 条，更多内容 S2 续作）" % [int(Game.get("成就配置").size()) if Game.get("成就配置") is Array else 0, _wired_count()]
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.apply_aux_text(lab)
	lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	_list_parent.add_child(lab)

func _wired_count() -> int:
	var n: int = 0
	for a in _as_array(Game.get("成就配置")):
		if str(a.get("condition_type", "placeholder")) != "placeholder":
			n += 1
	return n

# ───────── 任务卡（决策 3 F-pattern）─────────
func _add_task_card(task: Dictionary) -> void:
	var q: Dictionary = task["q"]
	var card := PanelContainer.new()
	card.name = "Card"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_stylebox())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 决策 3 F-pattern：左侧类型色条（替代原图标圆，强化类型识别与视觉层级）
	var bar: Control = _make_card_left_bar(_tab_type_color())
	hb.add_child(bar)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))
	var title: Label = Label.new()
	title.text = str(q.get("quest_name", "—"))
	UITheme.apply_section_title(title)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	mid.add_child(title)
	var desc: Label = Label.new()
	desc.text = str(q.get("target_desc", "—"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(desc)
	desc.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	mid.add_child(desc)

	_add_reward(mid, q)
	hb.add_child(mid)

	var btn: Button = _make_card_button(task)
	hb.add_child(btn)

	card.add_child(hb)
	_list_parent.add_child(card)

# ───────── 主线任务卡（实时进度 + 三态按钮）─────────
func _add_main_card(task: Dictionary) -> void:
	var card := PanelContainer.new()
	card.name = "MainCard"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_stylebox())
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", UITheme.GRID)
	hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var bar: Control = _make_card_left_bar(UITheme.CARD_TYPE_COLOR_MAIN)
	hb.add_child(bar)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", int(round(6.0 * UITheme.UI_SCALE)))

	var title: Label = Label.new()
	title.text = str(task.get("name", "—"))
	UITheme.apply_section_title(title)
	title.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
	mid.add_child(title)

	var desc: Label = Label.new()
	desc.text = str(task.get("desc", "—"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_body_text(desc)
	desc.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	mid.add_child(desc)

	# 进度条 current / target
	var prog_row := HBoxContainer.new()
	prog_row.add_theme_constant_override("separation", UITheme.GRID)
	var prog: Dictionary = _make_progress(UITheme.C05_PROG_TRACK, UITheme.C01_TEXT_GOLD, int(round(8.0 * UITheme.UI_SCALE)))
	prog.control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tgt: int = _to_int(task.get("target"), 1)
	var cur: int = _to_int(task.get("current"), 0)
	prog.fill.anchor_right = clamp(float(cur) / float(maxi(tgt, 1)), 0.0, 1.0)
	prog_row.add_child(prog.control)
	var prog_lab := Label.new()
	prog_lab.text = "%d / %d" % [cur, tgt]
	UITheme.apply_aux_text(prog_lab)
	prog_lab.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
	prog_row.add_child(prog_lab)
	mid.add_child(prog_row)

	_add_main_reward(mid, task)
	hb.add_child(mid)

	var btn: Button = _make_main_button(task)
	hb.add_child(btn)

	card.add_child(hb)
	_list_parent.add_child(card)

func _add_main_reward(parent: Control, task: Dictionary) -> void:
	# reward_caoyao 对应真实资源「灵草」
	var parts: Array = [
		["reward_lingjing", "灵石", UITheme.C01_TEXT_GOLD],
		["reward_lingqi", "灵气", UITheme.C05_REWARD_BLUE],
		["reward_shengwang", "声望", UITheme.C01_TEXT_GOLD],
		["reward_caoyao", "灵草", UITheme.C01_TEXT_GOLD],
	]
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", int(round(10.0 * UITheme.UI_SCALE)))
	var any: bool = false
	for p in parts:
		var key: String = p[0]
		var name: String = p[1]
		var col: Color = p[2]
		var v: int = _to_int(task.get(key), 0)
		if v <= 0:
			continue
		var icon: Texture2D = UITheme.load_icon(name)
		if icon != null:
			var tr := TextureRect.new()
			tr.texture = icon
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(int(round(20.0 * UITheme.UI_SCALE)), int(round(20.0 * UITheme.UI_SCALE)))
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(tr)
		var lab: Label = Label.new()
		lab.text = "+%d" % v
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", col)
		hb.add_child(lab)
		any = true
	if not any:
		var lab: Label = Label.new()
		lab.text = "无奖励"
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		hb.add_child(lab)
	parent.add_child(hb)

func _make_main_button(task: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(int(round(56.0 * UITheme.UI_SCALE)), int(round(26.0 * UITheme.UI_SCALE)))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var state: String = str(task.get("state", "in_progress"))
	match state:
		"done":
			b.text = "已收取"
			b.disabled = true
			_apply_dark_capsule(b)
		"claimable":
			b.text = "收取"
			_style_gold_button(b)
			UITheme.apply_button_label(b, true)
			b.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
			b.pressed.connect(_on_claim_main.bind(str(task.get("id", ""))))
		_:
			b.text = "进行中"
			b.disabled = true
			_apply_dark_capsule(b)
	return b

func _on_claim_main(quest_id: String) -> void:
	if not is_instance_valid(Game) or not Game.has_method("领取主线"):
		return
	var res: Dictionary = Game.领取主线(quest_id)
	if res.get("ok", false):
		任务领取完成.emit()
	refresh()

func _add_reward(parent: Control, q: Dictionary) -> void:
	var coef: float = 1.0
	if is_instance_valid(Game) and Game.has_method("差事赏赐系数"):
		coef = Game.差事赏赐系数()
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", int(round(10.0 * UITheme.UI_SCALE)))
	var parts: Array = [
		["reward_lingjing", "灵石", UITheme.C01_TEXT_GOLD],
		["reward_lingqi", "灵气", UITheme.C05_REWARD_BLUE],
		["reward_shengwang", "声望", UITheme.C01_TEXT_GOLD],
		["reward_xianyu", "仙玉", UITheme.C01_TEXT_GOLD],
	]
	var any: bool = false
	for p in parts:
		var key: String = p[0]
		var name: String = p[1]
		var col: Color = p[2]
		if q.has(key):
			var v: int = int(float(str(q.get(key, "0"))) * coef)
			# 决策 3：迷你资源图标（复用现有资产，零额外美术成本）+ 数值
			var icon: Texture2D = UITheme.load_icon(name)
			if icon != null:
				var tr := TextureRect.new()
				tr.texture = icon
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tr.custom_minimum_size = Vector2(int(round(20.0 * UITheme.UI_SCALE)), int(round(20.0 * UITheme.UI_SCALE)))
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hb.add_child(tr)
			var lab: Label = Label.new()
			lab.text = "+%d" % v
			UITheme.apply_body_text(lab)
			lab.add_theme_color_override("font_color", col)
			hb.add_child(lab)
			any = true
	if not any:
		var lab: Label = Label.new()
		lab.text = "无奖励"
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
		hb.add_child(lab)
	parent.add_child(hb)

func _make_card_button(task: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(int(round(56.0 * UITheme.UI_SCALE)), int(round(26.0 * UITheme.UI_SCALE)))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var 状态: String = str(task.get("state", ""))
	if bool(task["claimed"]):
		b.text = "已收取"
		b.disabled = true
		_apply_dark_capsule(b)
	elif 状态 == "in_progress":
		# S1-2：未达成不可领取——对齐主线三态，进行中禁用（后端 领取日常/领取周常 亦守卫）
		b.text = "进行中"
		b.disabled = true
		_apply_dark_capsule(b)
	else:
		# claimable 或兜底：可领取（亮金）
		b.text = "收取"
		_style_gold_button(b)
		UITheme.apply_button_label(b, true)
		b.add_theme_color_override("font_color", UITheme.C05_BTN_TEXT_DARK)
		if bool(task["weekly"]):
			b.pressed.connect(_on_claim_weekly)
		else:
			b.pressed.connect(_on_claim_daily.bind(int(task["idx"])))
	return b

func _add_empty(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.apply_aux_text(l)
	l.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)
	_list_parent.add_child(l)

# ───────── 交互 ─────────
func _on_claim_daily(序号: int) -> void:
	if not is_instance_valid(Game) or not Game.has_method("领取日常"):
		return
	Game.领取日常(序号)
	任务领取完成.emit()
	refresh()

func _on_claim_weekly() -> void:
	if not is_instance_valid(Game) or not Game.has_method("领取周常"):
		return
	Game.领取周常()
	任务领取完成.emit()
	refresh()

func _on_claim_all_pressed() -> void:
	if not is_instance_valid(Game):
		return
	var claimed_any: bool = false
	if Game.has_method("领取日常"):
		var d: Array = _as_array(Game.get("当前日常"))
		var dl: Array = _as_array(Game.get("日常已领"))
		for i in d.size():
			if i < dl.size() and not bool(dl[i]):
				Game.领取日常(i)
				claimed_any = true
	if Game.has_method("领取周常"):
		var wk: Variant = Game.get("当前周常")
		if wk is Dictionary and not wk.is_empty() and not bool(Game.get("周常已领")):
			Game.领取周常()
			claimed_any = true
	if Game.has_method("领取主线"):
		if Game.has_method("取主线任务列表"):
			for m in Game.取主线任务列表():
				if str(m.get("state", "")) == "claimable":
					Game.领取主线(str(m.get("id", "")))
					claimed_any = true
	if claimed_any:
		任务领取完成.emit()
	refresh()

func _on_tab_pressed(t: String) -> void:
	_current_tab = t
	_update_tab_styles()
	_populate()
	_update_claim_all_visibility()

## 更新尽数收取按钮的显示状态（仅日常/周常显示，成就/宗门里程碑隐藏）
func _update_claim_all_visibility() -> void:
	if _claim_all_btn == null or not is_instance_valid(_claim_all_btn):
		return
	_claim_all_btn.visible = (_current_tab == "日常" or _current_tab == "周常")

func _on_back_pressed() -> void:
	返回主页.emit()

# ───────── 控件工厂 ─────────
func _make_tab_button(t: String) -> Button:
	var b := Button.new()
	b.name = "Tab_" + t
	b.text = t
	b.custom_minimum_size = Vector2(0, int(round(34.0 * UITheme.UI_SCALE)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(_on_tab_pressed.bind(t))
	# 使用统一红点样式
	var dot: Panel = UITheme.make_red_dot(12.0)
	dot.name = "RedDot"
	dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -14
	dot.offset_right = -2
	dot.offset_top = 2
	dot.offset_bottom = 14
	dot.visible = false
	b.add_child(dot)
	_tab_reddots[t] = dot
	return b

func _update_tab_styles() -> void:
	for t in _tab_btns.keys():
		var b: Button = _tab_btns[t]
		var sel: bool = (t == _current_tab)
		var sb := StyleBoxFlat.new()
		if sel:
			sb.bg_color = UITheme.C01_AVATAR_BG
			sb.border_color = UITheme.C01_TEXT_GOLD
			sb.set_border_width_all(1)
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
		sb.set_content_margin_all(UITheme.GRID)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		UITheme.apply_section_title(b)
		b.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD if sel else UITheme.C01_TEXT_TERTIARY)

func _update_tab_reddots() -> void:
	if _tab_reddots.is_empty() or not is_instance_valid(Game):
		return
	var has_claim: Dictionary = {}
	for t in TABS:
		has_claim[t] = false
	if Game.has_method("取主线任务列表"):
		for m in Game.取主线任务列表():
			if str(m.get("state", "")) == "claimable":
				has_claim["主线"] = true
				break
	var d: Array = _as_array(Game.get("当前日常"))
	var dl: Array = _as_array(Game.get("日常已领"))
	for i in d.size():
		if i < dl.size() and not bool(dl[i]):
			has_claim["日常"] = true
			break
	var wk: Variant = Game.get("当前周常")
	if wk is Dictionary and not wk.is_empty() and not bool(Game.get("周常已领")):
		has_claim["周常"] = true
	# S1 批7：成就 Tab 红点——存在任何已达成成就时点亮（提示有成就可看）
	var 成就达成数: int = _as_array(Game.get("成就_已达成")).size()
	if 成就达成数 > 0:
		has_claim["成就"] = true
	for t in _tab_reddots.keys():
		_tab_reddots[t].visible = bool(has_claim.get(t, false))

func _make_card_left_bar(col: Color) -> Control:
	var c := ColorRect.new()
	c.name = "TypeBar"
	c.custom_minimum_size = Vector2(int(round(6.0 * UITheme.UI_SCALE)), 0)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.color = col
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _tab_type_color() -> Color:
	if _current_tab == "日常":
		return UITheme.CARD_TYPE_COLOR_DAILY
	if _current_tab == "周常":
		return TAB_COLOR_WEEKLY
	if _current_tab == "成就":
		return UITheme.CARD_TYPE_COLOR_ACHV
	return UITheme.CARD_TYPE_COLOR_ACHV

func _make_progress(track_color: Color, fill_color: Color, h: int) -> Dictionary:
	var track := Panel.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.custom_minimum_size = Vector2(0, h)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = track_color
	tsb.set_corner_radius_all(h / 2)
	tsb.set_content_margin_all(0)
	tsb.set_border_width_all(0)
	track.add_theme_stylebox_override("panel", tsb)
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = 0.0
	fill.size_flags_horizontal = Control.SIZE_FILL
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = fill_color
	fsb.set_corner_radius_all(h / 2)
	fsb.set_content_margin_all(0)
	fsb.set_border_width_all(0)
	fill.add_theme_stylebox_override("panel", fsb)
	track.add_child(fill)
	return {"control": track, "fill": fill}

func _card_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.C01_FLOAT_BG
	sb.set_corner_radius_all(int(round(10.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	sb.border_color = UITheme.C01_GOLD_LINE
	sb.set_content_margin_all(UITheme.PAD_PANEL)
	return sb

func _style_gold_button(b: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UITheme.C05_BTN_GRAD
	normal.border_color = UITheme.C05_BTN_GRAD_DK
	normal.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	normal.set_border_width_all(1)
	normal.set_content_margin_all(UITheme.GRID)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = UITheme.C05_BTN_GRAD_DK
	pressed.border_color = UITheme.C05_BTN_GRAD_DK
	pressed.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	pressed.set_border_width_all(1)
	pressed.set_content_margin_all(UITheme.GRID)
	var disabled := StyleBoxFlat.new()
	disabled.bg_color = UITheme.COLOR_BTN_DISABLED
	disabled.border_color = UITheme.C01_GOLD_LINE
	disabled.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	disabled.set_border_width_all(1)
	disabled.set_content_margin_all(UITheme.GRID)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("hover", normal)

func _style_ghost_button(b: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.1, 0.15, 0.6)
	normal.border_color = UITheme.C01_TEXT_TERTIARY
	normal.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	normal.set_border_width_all(1)
	normal.set_content_margin_all(UITheme.GRID)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("disabled", normal)

func _show_toast(text: String) -> void:
	if _toast_panel == null:
		_toast_panel = Panel.new()
		_toast_panel.name = "ToastPanel"
		_toast_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(Color(0.043, 0.078, 0.094, 0.92), UITheme.C01_GOLD_LINE, 8, 1))
		_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_panel.visible = false
		var lab := Label.new()
		lab.name = "ToastText"
		UITheme.apply_aux_text(lab)
		lab.add_theme_color_override("font_color", UITheme.C01_TEXT_GOLD)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_panel.add_child(lab)
		_toast_label = lab
		add_child(_toast_panel)
	_toast_label.text = text
	_toast_panel.visible = true
	var font: Font = _toast_label.get_theme_font("font")
	var text_size: Vector2 = font.get_string_size(_toast_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(round(14.0 * UITheme.UI_SCALE)))
	var panel_w: float = text_size.x + 32.0 * UITheme.UI_SCALE
	var panel_h: float = text_size.y + 16.0 * UITheme.UI_SCALE
	_toast_panel.size = Vector2(panel_w, panel_h)
	_toast_panel.global_position = Vector2((size.x - panel_w) / 2, 100.0 * UITheme.UI_SCALE)
	if get_tree() != null:
		get_tree().create_timer(1.5).timeout.connect(_hide_toast)

func _apply_dark_capsule(b: BaseButton) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UITheme.COLOR_PANEL_BG
	normal.border_color = UITheme.C01_GOLD_LINE
	normal.set_corner_radius_all(int(round(13.0 * UITheme.UI_SCALE)))
	normal.set_border_width_all(1)
	normal.set_content_margin_all(UITheme.GRID)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("disabled", normal)
	UITheme.apply_aux_text(b)
	b.add_theme_color_override("font_color", UITheme.C01_TEXT_TERTIARY)

# ───────── 活跃度宝箱（决策 2：视觉脚手架 + 置灰禁用，点击弹轻提示，不碰数据层）─────────
func _build_activity_chests(parent: Control) -> void:
	var wrap := HBoxContainer.new()
	wrap.name = "ActivityChests"
	wrap.add_theme_constant_override("separation", int(round(12.0 * UITheme.UI_SCALE)))
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var thresholds: Array = [20, 50, 80, 100]
	for th in thresholds:
		var chest: Button = _make_chest_button(th)
		_chest_buttons[th] = chest
		wrap.add_child(chest)
	parent.add_child(wrap)
	_update_chest_buttons()

func _make_chest_button(threshold: int) -> Button:
	var b := Button.new()
	b.name = "Chest_%d" % threshold
	b.custom_minimum_size = Vector2(int(round(72.0 * UITheme.UI_SCALE)), int(round(72.0 * UITheme.UI_SCALE)))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = ""

	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(int(round(44.0 * UITheme.UI_SCALE)), int(round(44.0 * UITheme.UI_SCALE)))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)

	var lab := Label.new()
	lab.name = "Threshold"
	lab.text = "%d" % threshold
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.apply_aux_text(lab)
	inner.add_child(lab)

	b.add_child(inner)
	b.pressed.connect(_on_chest_pressed.bind(threshold, b))
	return b

func _get_chest_state(threshold: int) -> String:
	if bool(_chest_local_claimed.get(threshold, false)):
		return "claimed"
	var cur: int = _to_int(Game.get("今日活跃度"), 0)
	if cur >= threshold:
		return "canclaim"
	return "locked"

func _update_chest_buttons() -> void:
	for th in _chest_buttons.keys():
		var b: Button = _chest_buttons[th]
		_refresh_chest_button(int(th), b)

func _refresh_chest_button(threshold: int, b: Button) -> void:
	var state: String = _get_chest_state(threshold)
	var icon: TextureRect = b.get_node_or_null("Inner/Icon") as TextureRect
	var lab: Label = b.get_node_or_null("Inner/Threshold") as Label

	var tex_path: String = CHEST_LOCKED
	var bg: Color = UITheme.C01_FLOAT_BG
	var border: Color = UITheme.C01_GOLD_LINE
	var icon_mod: Color = Color(0.55, 0.55, 0.55, 0.65)
	var font_col: Color = UITheme.C01_TEXT_TERTIARY

	match state:
		"canclaim":
			tex_path = CHEST_CANCLAIM
			bg = UITheme.C01_FLOAT_BG
			border = UITheme.C01_TEXT_GOLD
			icon_mod = Color.WHITE
			font_col = UITheme.C01_TEXT_GOLD
		"claimed":
			tex_path = CHEST_CLAIMED
			bg = Color(UITheme.C01_FLOAT_BG, 0.55)
			border = UITheme.C01_GOLD_LINE
			icon_mod = Color(0.55, 0.55, 0.55, 0.55)
			font_col = UITheme.C01_TEXT_TERTIARY

	var tex: Texture2D = UITheme.load_hd_icon(tex_path)
	if icon != null:
		icon.texture = tex
		icon.modulate = icon_mod
	if lab != null:
		lab.add_theme_color_override("font_color", font_col)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(int(round(8.0 * UITheme.UI_SCALE)))
	sb.set_border_width_all(1)
	sb.set_content_margin_all(UITheme.GRID)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)

func _on_chest_pressed(threshold: int, btn: Button) -> void:
	var state: String = _get_chest_state(threshold)
	match state:
		"locked":
			_toast_at("活跃度不足，宝箱未解锁 (%d)" % threshold, btn)
		"canclaim":
			_chest_local_claimed[threshold] = true
			_update_chest_buttons()
			_toast_at("活跃度奖励筹备中", btn)
		"claimed":
			_toast_at("奖励已收取", btn)

# ───────── 轻提示（二级页本地 Toast，纯展示零数据层触碰）─────────
func _toast_at(text: String, anchor_btn: Button) -> void:
	if _toast_panel == null:
		_toast_panel = Panel.new()
		_toast_panel.name = "ToastPanel"
		_toast_panel.add_theme_stylebox_override("panel", UITheme.make_panel_stylebox_flat(Color(0.043, 0.078, 0.094, 0.92), UITheme.C01_GOLD_LINE, 8, 1))
		_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_panel.visible = false
		var lab := Label.new()
		lab.name = "ToastText"
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_OFF
		lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lab.add_theme_constant_override("margin_left", int(round(12.0 * UITheme.UI_SCALE)))
		lab.add_theme_constant_override("margin_right", int(round(12.0 * UITheme.UI_SCALE)))
		UITheme.apply_body_text(lab)
		lab.add_theme_color_override("font_color", UITheme.C01_TEXT_PRIMARY)
		_toast_panel.add_child(lab)
		_toast_label = lab
		add_child(_toast_panel)
	_toast_label.text = text
	_toast_panel.visible = true

	# 计算尺寸：水平内边距 24@480，最小宽 160@480，高 40@480
	var pad_x: float = 24.0 * UITheme.UI_SCALE
	var min_w: float = 160.0 * UITheme.UI_SCALE
	var font_size: int = int(round(14.0 * UITheme.UI_SCALE))
	var font: Font = _toast_label.get_theme_font("font")
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var panel_w: float = maxf(min_w, text_w + pad_x * 2.0)
	var panel_h: float = 40.0 * UITheme.UI_SCALE
	_toast_panel.size = Vector2(panel_w, panel_h)

	# 定位在触发按钮上方居中；若按钮上方空间不足则显示在按钮下方
	var btn_rect: Rect2 = anchor_btn.get_global_rect()
	var target_x: float = btn_rect.position.x + (btn_rect.size.x - panel_w) * 0.5
	var target_y: float = btn_rect.position.y - panel_h - 8.0 * UITheme.UI_SCALE
	if target_y < UITheme.TOPBAR_H:
		target_y = btn_rect.position.y + btn_rect.size.y + 8.0 * UITheme.UI_SCALE
	# 限制在屏幕安全区内，避免长文本提示框在左右边缘跑出屏幕
	var viewport: Vector2 = get_viewport_rect().size
	var margin: float = 8.0 * UITheme.UI_SCALE
	target_x = clampf(target_x, margin, viewport.x - panel_w - margin)
	_toast_panel.global_position = Vector2(target_x, target_y)

	if is_instance_valid(get_tree()):
		get_tree().create_timer(1.5).timeout.connect(_hide_toast)

func _hide_toast() -> void:
	if _toast_panel != null:
		_toast_panel.visible = false

# ───────── 工具 ─────────
func _to_int(v: Variant, default: int) -> int:
	if v == null:
		return default
	if v is int or v is float:
		return int(v)
	return default

func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	return []
