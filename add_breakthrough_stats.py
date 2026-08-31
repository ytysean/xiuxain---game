# -*- coding: utf-8 -*-
"""
精确添加弟子突破次数自增和成就检测
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 查找弟子突破的代码位置
found = False
for i, line in enumerate(lines):
    if '周期评分.记突破()' in line and 'P1：突破计入周期评' in line:
        print(f"找到弟子突破代码在第{i+1}行: {line.strip()}")
        # 在这一行之后插入累计弟子突破次数自增和成就检测
        indent = '\t\t\t\t'  # 四个tab缩进（根据实际缩进调整）
        insert_lines = [
            f'{indent}# 成就统计：累计弟子突破次数自增\n',
            f'{indent}累计弟子突破次数 += 1\n',
            f'{indent}_复检成就()\n',
        ]
        lines[i+1:i+1] = insert_lines
        found = True
        print("✅ 累计弟子突破次数自增添加成功")
        break

if not found:
    print("❌ 未找到弟子突破代码")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n🎉 弟子突破次数自增和成就检测添加完成！")
