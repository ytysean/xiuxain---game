# -*- coding: utf-8 -*-
"""
精确添加坊市购买的统计变量自增逻辑
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 查找更新阵营任务进度的行
found = False
for i, line in enumerate(lines):
    if '更新阵营任务进度("中立散修", "daily", 1)' in line and '坊市跑腿' in lines[i-1]:
        print(f"找到坊市购买更新阵营任务进度在第{i+1}行: {line.strip()}")
        # 在这一行之后插入累计坊市交易次数自增和成就检测
        indent = '\t'  # 一个tab缩进
        insert_lines = [
            f'{indent}# 成就统计：累计坊市交易次数自增\n',
            f'{indent}累计坊市交易次数 += 1\n',
            f'{indent}_复检成就()\n',
        ]
        lines[i+1:i+1] = insert_lines
        found = True
        print("✅ 累计坊市交易次数自增添加成功")
        break

if not found:
    print("❌ 未找到坊市购买更新阵营任务进度")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n🎉 坊市购买统计变量自增逻辑添加完成！")
