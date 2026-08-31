# -*- coding: utf-8 -*-
"""
添加灵根和年龄排序函数
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 在资质排序函数后面添加灵根和年龄排序函数
old_text = """func _sort_key_资质(d: Variant) -> int:
	var 资质 = str(_safe_get(d, "资质", "fan_su"))
	var 权重 = _资质序.get(资质, 0)
	return int(权重)

func _sort_key_司职(d: Variant) -> int:"""

new_text = """func _sort_key_资质(d: Variant) -> int:
	var 资质 = str(_safe_get(d, "资质", "fan_su"))
	var 权重 = _资质序.get(资质, 0)
	return int(权重)

func _sort_key_灵根(d: Variant) -> int:
	var 灵根 = str(_safe_get(d, "灵根品阶", "凡品"))
	var 权重 = _灵根品阶序.get(灵根, 0)
	return int(权重)

func _sort_key_年龄(d: Variant) -> int:
	var v = _safe_get(d, "年龄", 0)
	return int(v) if (typeof(v) in [TYPE_INT, TYPE_FLOAT]) else 0

func _sort_key_司职(d: Variant) -> int:"""

if old_text in content:
    content = content.replace(old_text, new_text)
    print("✅ 添加灵根和年龄排序函数")
else:
    print("❌ 未找到资质排序函数")
    # 尝试查找部分文本
    if "_sort_key_资质" in content:
        print("ℹ️  找到 _sort_key_资质，但格式不匹配")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修改已保存到 page_disciple.gd")
else:
    print("\n❌ 没有任何修改")

print("\n🎉 灵根和年龄排序函数添加完成！")
