# -*- coding: utf-8 -*-
"""
重命名game_state.gd第4863行的增加功法熟练度函数为增加弟子功法熟练度
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 显示第4860-4870行的内容
lines = content.split('\n')
print("=== 重命名前（第4860-4870行）===")
for i in range(4859, 4870):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}")

# 重命名第4863行的函数
# 将 "func 增加功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:"
# 改为 "func 增加弟子功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:"
old_func = "func 增加功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:"
new_func = "func 增加弟子功法熟练度(弟子, 功法ID: String, 数量: int) -> Dictionary:"

if old_func in content:
    content = content.replace(old_func, new_func)
    print(f"\n已重命名函数：增加功法熟练度 -> 增加弟子功法熟练度")
else:
    print(f"\n未找到函数定义：{old_func}")

# 同时更新注释
old_comment = "# 增加功法熟练度"
new_comment = "# 增加弟子功法熟练度"
# 只替换第4862行的注释（在函数定义之前）
# 由于有多个"# 增加功法熟练度"注释，我们需要精确替换
lines = content.split('\n')
for i in range(len(lines)):
    if lines[i].strip() == "# 增加功法熟练度" and i+1 < len(lines) and "增加弟子功法熟练度" in lines[i+1]:
        lines[i] = "# 增加弟子功法熟练度"
        print(f"已更新第{i+1}行的注释")
        break

content = '\n'.join(lines)

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n=== 重命名后（第4860-4870行）===")
lines = content.split('\n')
for i in range(4859, 4870):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}")

print("\n✅ 第4863行的函数已重命名为增加弟子功法熟练度！")
