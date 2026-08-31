# -*- coding: utf-8 -*-
"""
修复page_fragment_chest.gd中的FONT_SMALL错误
将UITheme.FONT_SMALL替换为UITheme.FONT_AUX
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_fragment_chest.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 替换FONT_SMALL为FONT_AUX
if 'UITheme.FONT_SMALL' in content:
    content = content.replace('UITheme.FONT_SMALL', 'UITheme.FONT_AUX')
    print("✅ FONT_SMALL替换为FONT_AUX成功，共替换%d处" % content.count('UITheme.FONT_AUX'))
else:
    print("❌ 未找到FONT_SMALL")

# 保存文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ 文件保存成功")
