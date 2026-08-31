# -*- coding: utf-8 -*-
"""
修复game_state.gd中未声明的标识符错误
添加累计探索次数、修炼进度、累计培养弟子数、灵晶变量定义
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 在第2588行附近（var 体力 := 50）添加这些变量定义
print("=== 添加未声明的变量定义 ===")
for i in range(len(lines)):
    if lines[i].strip() == "var 体力 := 50":
        # 在这行后面添加变量定义
        lines.insert(i+1, "var 累计探索次数 := 0  # 累计探索次数\n")
        lines.insert(i+2, "var 修炼进度 := 0.0  # 修炼进度（0-1）\n")
        lines.insert(i+3, "var 累计培养弟子数 := 0  # 累计培养弟子数\n")
        lines.insert(i+4, "var 灵晶 := 0  # 灵晶数量\n")
        print(f"已在第{i+1}行后添加累计探索次数、修炼进度、累计培养弟子数、灵晶变量定义")
        break

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n✅ 未声明的标识符错误已修复！")
