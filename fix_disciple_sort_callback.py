# -*- coding: utf-8 -*-
"""
修复弟子页排序逻辑和筛选回调函数
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ========== 1. 修改排序逻辑，增加灵根和年龄排序 ==========
old_sort = """func _apply_sort(列表: Array) -> void:
	if _sort_mode == "默认":
		return
	if _sort_mode == "战力降":
		列表.sort_custom(func(a, b): return _sort_key_战力(a) > _sort_key_战力(b))
	elif _sort_mode == "境界降":
		列表.sort_custom(func(a, b): return _sort_key_境界(a) > _sort_key_境界(b))
	elif _sort_mode == "资质降":
		列表.sort_custom(func(a, b): return _sort_key_资质(a) > _sort_key_资质(b))
	elif _sort_mode == "司职":
		列表.sort_custom(func(a, b): return _sort_key_司职(a) < _sort_key_司职(b))"""

new_sort = """func _apply_sort(列表: Array) -> void:
	if _sort_mode == "默认":
		return
	if _sort_mode == "战力降":
		列表.sort_custom(func(a, b): return _sort_key_战力(a) > _sort_key_战力(b))
	elif _sort_mode == "境界降":
		列表.sort_custom(func(a, b): return _sort_key_境界(a) > _sort_key_境界(b))
	elif _sort_mode == "资质降":
		列表.sort_custom(func(a, b): return _sort_key_资质(a) > _sort_key_资质(b))
	elif _sort_mode == "灵根降":
		列表.sort_custom(func(a, b): return _sort_key_灵根(a) > _sort_key_灵根(b))
	elif _sort_mode == "年龄升":
		列表.sort_custom(func(a, b): return _sort_key_年龄(a) < _sort_key_年龄(b))
	elif _sort_mode == "年龄降":
		列表.sort_custom(func(a, b): return _sort_key_年龄(a) > _sort_key_年龄(b))
	elif _sort_mode == "司职":
		列表.sort_custom(func(a, b): return _sort_key_司职(a) < _sort_key_司职(b))"""

if old_sort in content:
    content = content.replace(old_sort, new_sort)
    print("✅ 修改排序逻辑，增加灵根和年龄排序")
else:
    print("❌ 未找到排序逻辑")

# ========== 2. 增加灵根和年龄排序函数 ==========
old_sort_funcs = """func _sort_key_资质(d: Variant) -> int:
	var v = _safe_get(d, "资质", "fan_su")
	return _资质序.get(str(v), 0)"""

new_sort_funcs = """func _sort_key_资质(d: Variant) -> int:
	var v = _safe_get(d, "资质", "fan_su")
	return _资质序.get(str(v), 0)

func _sort_key_灵根(d: Variant) -> int:
	var v = _safe_get(d, "灵根品阶", "凡品")
	return _灵根品阶序.get(str(v), 0)

func _sort_key_年龄(d: Variant) -> int:
	var v = _safe_get(d, "年龄", 0)
	return int(v) if (typeof(v) in [TYPE_INT, TYPE_FLOAT]) else 0"""

if old_sort_funcs in content:
    content = content.replace(old_sort_funcs, new_sort_funcs)
    print("✅ 增加灵根和年龄排序函数")
else:
    print("❌ 未找到资质排序函数")

# ========== 3. 增加筛选回调函数 ==========
old_callback = """# 身份筛选处理
func _on_identity_filter(身份: String) -> void:
	_filter_identity = 身份
	_refresh_filter_buttons()
	_populate_list()"""

new_callback = """# 身份筛选处理
func _on_identity_filter(身份: String) -> void:
	_filter_identity = 身份
	_refresh_filter_buttons()
	_populate_list()

# 境界筛选处理
func _on_realm_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_realm = "全部"
	else:
		_filter_realm = _境界列表[index - 1]
	_populate_list()

# 资质筛选处理
func _on_aptitude_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_aptitude = "全部"
	else:
		_filter_aptitude = _资质列表[index - 1]
	_populate_list()

# 道途筛选处理
func _on_daotu_filter(dropdown: OptionButton, index: int) -> void:
	if index == 0:
		_filter_daotu = "全部"
	else:
		_filter_daotu = _道途列表[index - 1]
	_populate_list()

# 灵根品阶筛选处理
func _on_linggen_filter(dropdown: OptionButton, index: int) -> void:
	_populate_list()"""

if old_callback in content:
    content = content.replace(old_callback, new_callback)
    print("✅ 增加筛选回调函数")
else:
    print("❌ 未找到身份筛选回调函数")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 所有修改已保存到 page_disciple.gd")
else:
    print("\n❌ 没有任何修改")

print("\n🎉 弟子页排序逻辑和筛选回调函数修复完成！")
