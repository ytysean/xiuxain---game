# 阵营任务和商店页面
# 包含五大阵营的专属任务和商店
# 铁律：只读 Game.get() / Game.获取阵营任务() / Game.获取阵营商店()；领取/购买仅调 Game.领取阵营任务奖励() / Game.购买阵营商店商品() 公有 API

extends Control
class_name FactionQuestShopPage

signal 返回主页

const 阵营列表: Array = ["正道宗门", "魔道邪宗", "中立散修", "上古妖兽", "远古遗泽"]
const 阵营颜色: Dictionary = {
	"正道宗门": Color(0.3, 0.7, 1.0),
	"魔道邪宗": Color(0.9, 0.2, 0.3),
	"中立散修": Color(0.6, 0.6, 0.6),
	"上古妖兽": Color(0.2, 0.8, 0.4),
	"远古遗泽": Color(0.9, 0.7, 0.2),
}

var _built: bool = false
var _current_faction: String = "正道宗门"
var _current_tab: String = "任务"  # 任务 / 商店
var _body: VBoxContainer
var _faction_tabs: HBoxContainer
var _type_tabs: HBoxContainer
var _list_parent: VBoxContainer
var _toast_panel: Panel = null
var _toast_label: Label = null

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

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0.086, 0.125, 0.141, 0.95)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 主容器
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main.add_theme_constant_override("separation", 10)
	add_child(main)

	# 顶部标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	main.add_child(header)

	var back_btn := Button.new()
	back_btn.text = "← 返回"
	back_btn.custom_minimum_size = Vector2(80, 40)
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var title := Label.new()
	title.text = "阵营差事与坊市"
	UITheme.apply_project_font(title, UITheme.FONT_H1, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# 阵营选择标签
	_faction_tabs = HBoxContainer.new()
	_faction_tabs.add_theme_constant_override("separation", 5)
	main.add_child(_faction_tabs)

	for faction in 阵营列表:
		var btn := Button.new()
		btn.text = faction
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_faction_tab_pressed.bind(faction))
		_faction_tabs.add_child(btn)

	# 类型选择标签（任务/商店）
	_type_tabs = HBoxContainer.new()
	_type_tabs.add_theme_constant_override("separation", 5)
	main.add_child(_type_tabs)

	for tab in ["任务", "商店"]:
		var btn := Button.new()
		btn.text = "差事" if tab == "任务" else "坊市"
		btn.custom_minimum_size = Vector2(100, 36)
		btn.pressed.connect(_on_type_tab_pressed.bind(tab))
		_type_tabs.add_child(btn)

	# 阵营声望显示
	var rep_label := Label.new()
	rep_label.name = "声望标签"
	UITheme.apply_project_font(rep_label, UITheme.FONT_H2, true)
	main.add_child(rep_label)

	# 滚动列表
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)

	_list_parent = VBoxContainer.new()
	_list_parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_parent.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_parent)

	# Toast提示
	_toast_panel = Panel.new()
	_toast_panel.visible = false
	_toast_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.offset_top = -80
	_toast_panel.offset_bottom = -40
	_toast_panel.offset_left = -150
	_toast_panel.offset_right = 150
	add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_panel.add_child(_toast_label)

func refresh() -> void:
	if not _built:
		return
	# 更新阵营标签状态
	for i in range(_faction_tabs.get_child_count()):
		var btn = _faction_tabs.get_child(i)
		if btn is Button:
			var faction = 阵营列表[i]
			btn.disabled = (faction == _current_faction)
			btn.modulate = 阵营颜色.get(faction, Color.WHITE) if faction == _current_faction else Color.WHITE
	# 更新类型标签状态
	for i in range(_type_tabs.get_child_count()):
		var btn = _type_tabs.get_child(i)
		if btn is Button:
			var tab = ["任务", "商店"][i]
			btn.disabled = (tab == _current_tab)
	# 更新声望显示
	var rep_label = get_node_or_null("声望标签")
	if rep_label != null:
		var rep_value = Game.get("阵营声望").get(_current_faction, 0)
		var rep_level = Game.获取声望等级(_current_faction)
		rep_label.text = "当前阵营：%s | 声望：%d | 品阶：%s" % [_current_faction, rep_value, rep_level]
		rep_label.add_theme_color_override("font_color", 阵营颜色.get(_current_faction, Color.WHITE))
	# 清空列表
	for child in _list_parent.get_children():
		child.queue_free()
	# 根据当前标签显示内容
	if _current_tab == "任务":
		_show_faction_quests()
	else:
		_show_faction_shop()

func _show_faction_quests() -> void:
	var quests = Game.获取阵营任务(_current_faction)
	if quests.is_empty():
		var empty := Label.new()
		empty.text = "尚无阵营差事"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list_parent.add_child(empty)
		return
	for q in quests:
		var card := _make_quest_card(q)
		_list_parent.add_child(card)

func _make_quest_card(q: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192, 0.90)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = 阵营颜色.get(_current_faction, Color(0.5, 0.5, 0.5))
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	# 左侧信息
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	hb.add_child(mid)

	var title := Label.new()
	title.text = str(q.get("quest_name", ""))
	UITheme.apply_project_font(title, UITheme.FONT_TITLE, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	mid.add_child(title)

	var desc := Label.new()
	desc.text = str(q.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mid.add_child(desc)

	var target := Label.new()
	var current = int(q.get("当前进度", 0))
	var target_num = int(q.get("target_num", 1))
	target.text = "进度：%d/%d | 类型：%s | 解锁声望：%s" % [current, target_num, q.get("quest_type", ""), q.get("unlock_reputation", "")]
	target.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6) if current >= target_num else Color(0.8, 0.6, 0.6))
	mid.add_child(target)

	var reward := Label.new()
	reward.text = "奖励：%d灵石 | %d灵气 | %d声望" % [int(q.get("reward_lingjing", 0)), int(q.get("reward_lingqi", 0)), int(q.get("reward_reputation", 0))]
	reward.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))
	mid.add_child(reward)

	# 右侧按钮
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 50)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not q.get("是否解锁", false):
		btn.text = "未解锁"
		btn.disabled = true
	elif q.get("已受领", false):
		btn.text = "已受领"
		btn.disabled = true
	elif current >= target_num:
		btn.text = "领取奖励"
		btn.pressed.connect(_on_claim_quest_pressed.bind(str(q.get("quest_id", ""))))
	else:
		btn.text = "进行中"
		btn.disabled = true
	hb.add_child(btn)

	return card

func _show_faction_shop() -> void:
	var items = Game.获取阵营商店(_current_faction)
	if items.is_empty():
		var empty := Label.new()
		empty.text = "尚无阵营商店商品"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_list_parent.add_child(empty)
		return
	for item in items:
		var card := _make_shop_card(item)
		_list_parent.add_child(card)

func _make_shop_card(item: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.122, 0.169, 0.192, 0.90)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = 阵营颜色.get(_current_faction, Color(0.5, 0.5, 0.5))
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	card.add_child(hb)

	# 左侧信息
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 4)
	hb.add_child(mid)

	var title := Label.new()
	title.text = str(item.get("item_name", ""))
	UITheme.apply_project_font(title, UITheme.FONT_TITLE, true)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	mid.add_child(title)

	var desc := Label.new()
	desc.text = str(item.get("description", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	mid.add_child(desc)

	var info := Label.new()
	var original_price = int(item.get("price", 0))
	var discount_price = int(item.get("折扣价", 0))
	var bought = int(item.get("购买次数", 0))
	info.text = "品类：%s ｜ 原值：%d ｜ 折后值：%d ｜ 已得：%d 次 ｜ 需声望：%s" % [item.get("item_type", ""), original_price, discount_price, bought, item.get("unlock_reputation", "")]
	info.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	mid.add_child(info)

	# 右侧按钮
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 50)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not item.get("是否解锁", false):
		btn.text = "未解锁"
		btn.disabled = true
	else:
		btn.text = "纳之（%d）" % discount_price
		btn.pressed.connect(_on_buy_item_pressed.bind(str(item.get("item_id", ""))))
	hb.add_child(btn)

	return card

func _on_back_pressed() -> void:
	返回主页.emit()

func _on_faction_tab_pressed(faction: String) -> void:
	_current_faction = faction
	refresh()

func _on_type_tab_pressed(tab: String) -> void:
	_current_tab = tab
	refresh()

func _on_claim_quest_pressed(quest_id: String) -> void:
	var result = Game.领取阵营任务奖励(quest_id)
	if result.get("成功", false):
		_show_toast("收取成功！获得%d灵石、%d灵气、%d声望" % [result.get("灵石", 0), result.get("灵气", 0), result.get("声望", 0)])
	else:
		_show_toast("收取失败：%s" % result.get("原因", "卦象错乱"))
	refresh()

func _on_buy_item_pressed(item_id: String) -> void:
	var result = Game.购买阵营商店商品(item_id)
	if result.get("成功", false):
		_show_toast("购入成功！获得%s，花费%d灵石" % [result.get("商品名", ""), result.get("花费", 0)])
	else:
		_show_toast("购入失败：%s" % result.get("原因", "卦象错乱"))
	refresh()

func _show_toast(msg: String) -> void:
	if _toast_label != null:
		_toast_label.text = msg
	if _toast_panel != null:
		_toast_panel.visible = true
		_toast_panel.modulate.a = 1.0
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.5)
		tween.tween_callback(_toast_panel.set_visible.bind(false))



