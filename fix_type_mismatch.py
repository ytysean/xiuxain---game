# -*- coding: utf-8 -*-
"""
修复game_state.gd第10451行的类型不匹配错误
将获取弟子本命法宝函数的参数从String改为int
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第10458-10465行的内容
print("=== 修复前（第10458-10465行）===")
for i in range(10457, 10465):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 修复第10459行（索引10458）的函数参数
# 将 "func 获取弟子本命法宝(弟子ID: String) -> Dictionary:"
# 改为 "func 获取弟子本命法宝(弟子ID: int) -> Dictionary:"
for i in range(len(lines)):
    if "func 获取弟子本命法宝(弟子ID: String) -> Dictionary:" in lines[i]:
        lines[i] = lines[i].replace("func 获取弟子本命法宝(弟子ID: String) -> Dictionary:", "func 获取弟子本命法宝(弟子ID: int) -> Dictionary:")
        print(f"\n已修复第{i+1}行的函数参数类型")
        break

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第10458-10465行）===")
for i in range(10457, 10465):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第10451行的类型不匹配错误已修复！")
