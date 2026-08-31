# -*- coding: utf-8 -*-
"""
修复境界pill显示为白色框的问题
原因：get_realm_color期望英文stem，但传入的是中文境界名
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# 修复境界pill的颜色获取
old_code = """	# 核心标签2：境界（pill样式，境界色）
	var 境界色 = UIThemeConfig.get_realm_color(境界)
	var 境界pill = _make_pill(境界, 境界色, 4)"""

new_code = """	# 核心标签2：境界（pill样式，境界色）
	var 境界stem = _REALM_STEM.get(境界, "lianqi")
	var 境界色 = UIThemeConfig.get_realm_color(境界stem)
	var 境界pill = _make_pill(境界, 境界色, 4)"""

if old_code in content:
    content = content.replace(old_code, new_code)
    print("✅ 修复境界pill颜色获取")
else:
    print("❌ 未找到境界pill代码")
    # 尝试查找部分代码
    if "var 境界色 = UIThemeConfig.get_realm_color(境界)" in content:
        print("ℹ️  找到境界色代码，但格式不匹配")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 修改已保存到 page_disciple.gd")
else:
    print("\n❌ 没有任何修改")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

if "var 境界stem = _REALM_STEM.get(境界, \"lianqi\")" in verify_content:
    print("✅ 已添加境界stem转换")
else:
    print("❌ 未添加境界stem转换")

if "var 境界色 = UIThemeConfig.get_realm_color(境界stem)" in verify_content:
    print("✅ 已修改为使用境界stem获取颜色")
else:
    print("❌ 未修改为使用境界stem获取颜色")

print("\n🎉 境界pill白色框问题修复完成！")
