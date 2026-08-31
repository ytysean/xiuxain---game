# -*- coding: utf-8 -*-
"""
修复长老坐化事件触发的typo
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 修复typo 1: "长：" -> "长老"
old1 = 'if d.身份 == "长：":'
new1 = 'if d.身份 == "长老":'

if old1 in content:
    content = content.replace(old1, new1)
    print("✅ 修复typo 1: '长：' -> '长老'")
else:
    print("❌ 未找到typo 1")

# 修复typo 2: "首位长老飞：" -> "首位长老飞升"
old2 = '_传承事件("首位长老飞：")'
new2 = '_传承事件("首位长老飞升")'

if old2 in content:
    content = content.replace(old2, new2)
    print("✅ 修复typo 2: '首位长老飞：' -> '首位长老飞升'")
else:
    print("❌ 未找到typo 2")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 长老坐化事件触发typo修复完成！")
