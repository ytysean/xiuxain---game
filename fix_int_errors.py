# -*- coding: utf-8 -*-
"""
修复game_state.gd中第9810-9811行和第10076-10094行的错误
将int/String类型的变量名改为Dictionary类型的变量名a
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
count = 0

# 修复第9810-9811行（索引从0开始，所以是9809-9810）
for i in [9809, 9810]:
    if i < len(lines):
        old_line = lines[i]
        # 将 "in t else" 改为 "in a else"
        if ' in t else' in old_line:
            lines[i] = lines[i].replace(' in t else', ' in a else')
            count += 1
            print(f"第{i+1}行: t -> a")
        # 将 "in p else" 改为 "in a else"
        if ' in p else' in lines[i]:
            lines[i] = lines[i].replace(' in p else', ' in a else')
            count += 1
            print(f"第{i+1}行: p -> a")

# 修复第10076-10094行（索引从0开始，所以是10075-10093）
for i in range(10075, 10094):
    if i < len(lines):
        old_line = lines[i]
        # 将 "in id else" 改为 "in a else"
        if ' in id else' in old_line:
            lines[i] = lines[i].replace(' in id else', ' in a else')
            count += 1
            print(f"第{i+1}行: id -> a")
        # 将 "in rls else" 改为 "in a else"
        if ' in rls else' in lines[i]:
            lines[i] = lines[i].replace(' in rls else', ' in a else')
            count += 1
            print(f"第{i+1}行: rls -> a")
        # 将 "in rlq else" 改为 "in a else"
        if ' in rlq else' in lines[i]:
            lines[i] = lines[i].replace(' in rlq else', ' in a else')
            count += 1
            print(f"第{i+1}行: rlq -> a")
        # 将 "in rsw else" 改为 "in a else"
        if ' in rsw else' in lines[i]:
            lines[i] = lines[i].replace(' in rsw else', ' in a else')
            count += 1
            print(f"第{i+1}行: rsw -> a")
        # 将 "in rid else" 改为 "in a else"
        if ' in rid else' in lines[i]:
            lines[i] = lines[i].replace(' in rid else', ' in a else')
            count += 1
            print(f"第{i+1}行: rid -> a")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\n✅ 总共修复了 {count} 个错误")
