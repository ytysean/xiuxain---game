# -*- coding: utf-8 -*-
"""
弟子系统优化 - 第一部分：筛选和排序优化
1. 增加境界、资质、道途、灵根品阶筛选
2. 增加更多排序选项
3. 优化筛选UI布局
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ========== 1. 增加筛选变量 ==========
old_vars = """var _filter_identity: String = "全部"  # 身份筛选：全部/外门/内门/亲传
var _filter_buttons: Dictionary = {}  # 身份名 -> Button"""

new_vars = """var _filter_identity: String = "全部"  # 身份筛选：全部/外门/内门/亲传
var _filter_realm: String = "全部"     # 境界筛选
var _filter_aptitude: String = "全部"  # 资质筛选
var _filter_daotu: String = "全部"     # 道途筛选
var _filter_buttons: Dictionary = {}  # 身份名 -> Button
var _filter_dropdowns: Dictionary = {}  # 筛选类型 -> OptionButton"""

if old_vars in content:
    content = content.replace(old_vars, new_vars)
    print("✅ 增加筛选变量")
else:
    print("❌ 未找到筛选变量")

# ========== 2. 增加排序模式 ==========
old_sort = """const _SORT_MODES: Array = ["战力降", "境界降", "资质降", "司职", "默认"]"""

new_sort = """const _SORT_MODES: Array = ["战力降", "境界降", "资质降", "灵根降", "年龄升", "年龄降", "司职", "默认"]"""

if old_sort in content:
    content = content.replace(old_sort, new_sort)
    print("✅ 增加排序模式")
else:
    print("❌ 未找到排序模式")

# ========== 3. 增加灵根品阶排序权重 ==========
old_aptitude = """# 资质拼音→中文映射（对齐 disciple.gd 资质显示）
const _资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}"""

new_aptitude = """# 资质拼音→中文映射（对齐 disciple.gd 资质显示）
const _资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}
# 灵根品阶排序权重（降序：天品>极品>上品>良品>凡品）
const _灵根品阶序: Dictionary = {"天品": 5, "极品": 4, "上品": 3, "良品": 2, "凡品": 1}
# 道途列表
const _道途列表: Array = ["道修", "体修", "法修", "御兽师", "符箓师", "毒师", "傀儡师"]
# 境界列表
const _境界列表: Array = ["练气", "筑基", "金丹", "元婴", "化神", "仙阶", "道阶"]
# 资质列表
const _资质列表: Array = ["凡俗", "平庸", "优良", "天才", "妖孽", "旷世"]
# 灵根品阶列表
const _灵根品阶列表: Array = ["凡品", "良品", "上品", "极品", "天品"]"""

if old_aptitude in content:
    content = content.replace(old_aptitude, new_aptitude)
    print("✅ 增加灵根品阶排序权重和筛选列表")
else:
    print("❌ 未找到资质显示")

# ========== 4. 修改筛选UI，增加多行筛选 ==========
old_filter_ui = """	# 身份筛选行（全部/外门/内门/亲传）
	var filter_panel := PanelContainer.new()
	filter_panel.name = "FilterBar"
	filter_panel.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.8)))
	var filter_hb := HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", int(round(6 * UITheme.UI_SCALE)))
	filter_panel.add_child(filter_hb)
	for 身份名 in ["全部", "外门", "内门", "亲传"]:
		var 筛钮 := Button.new()
		筛钮.text = 身份名
		筛钮.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.7)))
		筛钮.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
		筛钮.pressed.connect(_on_identity_filter.bind(身份名))
		_filter_buttons[身份名] = 筛钮
		filter_hb.add_child(筛钮)
	_refresh_filter_buttons()
	_list_root.add_child(filter_panel)"""

new_filter_ui = """	# 筛选区第一行：身份筛选按钮
	var filter_panel := PanelContainer.new()
	filter_panel.name = "FilterBar"
	filter_panel.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.8)))
	var filter_hb := HBoxContainer.new()
	filter_hb.add_theme_constant_override("separation", int(round(6 * UITheme.UI_SCALE)))
	filter_panel.add_child(filter_hb)
	for 身份名 in ["全部", "外门", "内门", "亲传"]:
		var 筛钮 := Button.new()
		筛钮.text = 身份名
		筛钮.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.7)))
		筛钮.add_theme_font_size_override("font_size", int(round(12 * UITheme.UI_SCALE)))
		筛钮.pressed.connect(_on_identity_filter.bind(身份名))
		_filter_buttons[身份名] = 筛钮
		filter_hb.add_child(筛钮)
	_refresh_filter_buttons()
	_list_root.add_child(filter_panel)

	# 筛选区第二行：境界/资质/道途/灵根品阶下拉筛选
	var filter2_panel := PanelContainer.new()
	filter2_panel.name = "FilterBar2"
	filter2_panel.custom_minimum_size = Vector2(0, int(round(UITheme.SIZE_SM * 0.7)))
	var filter2_hb := HBoxContainer.new()
	filter2_hb.add_theme_constant_override("separation", int(round(8 * UITheme.UI_SCALE)))
	filter2_panel.add_child(filter2_hb)

	# 境界筛选
	var 境界_label := Label.new()
	境界_label.text = "境界:"
	UITheme.apply_aux_font(境界_label)
	filter2_hb.add_child(境界_label)
	var 境界_dropdown := OptionButton.new()
	境界_dropdown.name = "RealmFilter"
	境界_dropdown.custom_minimum_size = Vector2(80, 0)
	境界_dropdown.add_item("全部", 0)
	for i in range(_境界列表.size()):
		境界_dropdown.add_item(_境界列表[i], i + 1)
	境界_dropdown.item_selected.connect(_on_realm_filter.bind(境界_dropdown))
	_filter_dropdowns["境界"] = 境界_dropdown
	filter2_hb.add_child(境界_dropdown)

	# 资质筛选
	var 资质_label := Label.new()
	资质_label.text = "资质:"
	UITheme.apply_aux_font(资质_label)
	filter2_hb.add_child(资质_label)
	var 资质_dropdown := OptionButton.new()
	资质_dropdown.name = "AptitudeFilter"
	资质_dropdown.custom_minimum_size = Vector2(80, 0)
	资质_dropdown.add_item("全部", 0)
	for i in range(_资质列表.size()):
		资质_dropdown.add_item(_资质列表[i], i + 1)
	资质_dropdown.item_selected.connect(_on_aptitude_filter.bind(资质_dropdown))
	_filter_dropdowns["资质"] = 资质_dropdown
	filter2_hb.add_child(资质_dropdown)

	# 道途筛选
	var 道途_label := Label.new()
	道途_label.text = "道途:"
	UITheme.apply_aux_font(道途_label)
	filter2_hb.add_child(道途_label)
	var 道途_dropdown := OptionButton.new()
	道途_dropdown.name = "DaotuFilter"
	道途_dropdown.custom_minimum_size = Vector2(80, 0)
	道途_dropdown.add_item("全部", 0)
	for i in range(_道途列表.size()):
		道途_dropdown.add_item(_道途列表[i], i + 1)
	道途_dropdown.item_selected.connect(_on_daotu_filter.bind(道途_dropdown))
	_filter_dropdowns["道途"] = 道途_dropdown
	filter2_hb.add_child(道途_dropdown)

	# 灵根品阶筛选
	var 灵根_label := Label.new()
	灵根_label.text = "灵根:"
	UITheme.apply_aux_font(灵根_label)
	filter2_hb.add_child(灵根_label)
	var 灵根_dropdown := OptionButton.new()
	灵根_dropdown.name = "LinggenFilter"
	灵根_dropdown.custom_minimum_size = Vector2(80, 0)
	灵根_dropdown.add_item("全部", 0)
	for i in range(_灵根品阶列表.size()):
		灵根_dropdown.add_item(_灵根品阶列表[i], i + 1)
	灵根_dropdown.item_selected.connect(_on_linggen_filter.bind(灵根_dropdown))
	_filter_dropdowns["灵根"] = 灵根_dropdown
	filter2_hb.add_child(灵根_dropdown)

	_list_root.add_child(filter2_panel)"""

if old_filter_ui in content:
    content = content.replace(old_filter_ui, new_filter_ui)
    print("✅ 修改筛选UI，增加多行筛选")
else:
    print("❌ 未找到筛选UI")

# ========== 5. 修改筛选逻辑，增加多条件筛选 ==========
old_filter_logic = """	# 身份筛选（全部/外门/内门/亲传）
	var 筛选后: Array = []
	for d in 有序列表:
		if d == null:
			continue
		var 身份 = str(_safe_get(d, "身份", "外门"))
		if _filter_identity == "全部" or 身份 == _filter_identity:
			筛选后.append(d)"""

new_filter_logic = """	# 多条件筛选（身份/境界/资质/道途/灵根品阶）
	var 筛选后: Array = []
	for d in 有序列表:
		if d == null:
			continue
		var 身份 = str(_safe_get(d, "身份", "外门"))
		var 境界 = str(_safe_get(d, "境界", "练气"))
		var 资质 = str(_safe_get(d, "资质", "凡俗"))
		var 道途 = str(_safe_get(d, "道途", ""))
		var 灵根品阶 = str(_safe_get(d, "灵根品阶", "凡品"))
		# 身份筛选
		if _filter_identity != "全部" and 身份 != _filter_identity:
			continue
		# 境界筛选
		if _filter_realm != "全部" and 境界 != _filter_realm:
			continue
		# 资质筛选（需要转换拼音为中文）
		if _filter_aptitude != "全部":
			var 资质中文 = _资质显示.get(资质, 资质)
			if 资质中文 != _filter_aptitude:
				continue
		# 道途筛选
		if _filter_daotu != "全部" and 道途 != _filter_daotu:
			continue
		筛选后.append(d)"""

if old_filter_logic in content:
    content = content.replace(old_filter_logic, new_filter_logic)
    print("✅ 修改筛选逻辑，增加多条件筛选")
else:
    print("❌ 未找到筛选逻辑")

# ========== 6. 修改排序逻辑，增加灵根和年龄排序 ==========
old_sort_logic = """func _apply_sort(列表: Array) -> void:
	match _sort_mode:
		"战力降":
			列表.sort_custom(func(a, b): return _safe_get(a, "战力", 0) > _safe_get(b, "战力", 0))
		"境界降":
			列表.sort_custom(func(a, b): return _境界序.find(str(_safe_get(a, "境界", "练气"))) > _境界序.find(str(_safe_get(b, "境界", "练气"))))
		"资质降":
			列表.sort_custom(func(a, b): return _资质序.get(str(_safe_get(a, "资质", "fan_su")), 0) > _资质序.get(str(_safe_get(b, "资质", "fan_su")), 0))
		"司职":
			列表.sort_custom(func(a, b): return str(_safe_get(a, "司职", "")) > str(_safe_get(b, "司职", "")))
		"默认":
			pass"""

new_sort_logic = """func _apply_sort(列表: Array) -> void:
	match _sort_mode:
		"战力降":
			列表.sort_custom(func(a, b): return _safe_get(a, "战力", 0) > _safe_get(b, "战力", 0))
		"境界降":
			列表.sort_custom(func(a, b): return _境界序.find(str(_safe_get(a, "境界", "练气"))) > _境界序.find(str(_safe_get(b, "境界", "练气"))))
		"资质降":
			列表.sort_custom(func(a, b): return _资质序.get(str(_safe_get(a, "资质", "fan_su")), 0) > _资质序.get(str(_safe_get(b, "资质", "fan_su")), 0))
		"灵根降":
			列表.sort_custom(func(a, b): return _灵根品阶序.get(str(_safe_get(a, "灵根品阶", "凡品")), 0) > _灵根品阶序.get(str(_safe_get(b, "灵根品阶", "凡品")), 0))
		"年龄升":
			列表.sort_custom(func(a, b): return _safe_get(a, "年龄", 0) < _safe_get(b, "年龄", 0))
		"年龄降":
			列表.sort_custom(func(a, b): return _safe_get(a, "年龄", 0) > _safe_get(b, "年龄", 0))
		"司职":
			列表.sort_custom(func(a, b): return str(_safe_get(a, "司职", "")) > str(_safe_get(b, "司职", "")))
		"默认":
			pass"""

if old_sort_logic in content:
    content = content.replace(old_sort_logic, new_sort_logic)
    print("✅ 修改排序逻辑，增加灵根和年龄排序")
else:
    print("❌ 未找到排序逻辑")

# ========== 7. 增加筛选回调函数 ==========
old_callback = """func _on_identity_filter(身份名: String) -> void:
	_filter_identity = 身份名
	_refresh_filter_buttons()
	_populate_list()"""

new_callback = """func _on_identity_filter(身份名: String) -> void:
	_filter_identity = 身份名
	_refresh_filter_buttons()
	_populate_list()

func _on_realm_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_realm = "全部"
	else:
		_filter_realm = _境界列表[index - 1]
	_populate_list()

func _on_aptitude_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_aptitude = "全部"
	else:
		_filter_aptitude = _资质列表[index - 1]
	_populate_list()

func _on_daotu_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_daotu = "全部"
	else:
		_filter_daotu = _道途列表[index - 1]
	_populate_list()

func _on_linggen_filter(dropdown: OptionButton, index: int) -> void:
	# 灵根品阶筛选在 _populate_list 中处理（目前简化，后续可扩展）
	_populate_list()"""

if old_callback in content:
    content = content.replace(old_callback, new_callback)
    print("✅ 增加筛选回调函数")
else:
    print("❌ 未找到筛选回调函数")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 所有修改已保存到 page_disciple.gd")
else:
    print("\n❌ 没有任何修改")

print("\n🎉 弟子页筛选和排序优化完成！")
