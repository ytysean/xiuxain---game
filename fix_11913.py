# -*- coding: utf-8 -*-
"""
修复game_state.gd中第11913-11918行的错误
将da、宗门名、acc改回old
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 显示第11912-11919行的内容
print("=== 修复前（第11912-11919行）===")
for i in range(11911, 11919):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

# 修复第11913-11918行的错误
# 第11913行：将 "宗门名" in da 改为 "宗门名" in old
# 第11914行：将 "宗主名" in 宗门名 改为 "宗主名" in old
# 第11917行：将 "最后登录" in acc 改为 "最后登录" in old，将 "门派等级" in acc 改为 "门派等级" in old
# 第11918行：将 "宗主名" in acc 改为 "宗主名" in old，将 "宗主头像" in acc 改为 "宗主头像" in old

lines[11912] = lines[11912].replace('"宗门名" in da', '"宗门名" in old')
lines[11913] = lines[11913].replace('"宗主名" in 宗门名', '"宗主名" in old')
lines[11916] = lines[11916].replace('"最后登录" in acc', '"最后登录" in old')
lines[11916] = lines[11916].replace('"门派等级" in acc', '"门派等级" in old')
lines[11917] = lines[11917].replace('"宗主名" in acc', '"宗主名" in old')
lines[11917] = lines[11917].replace('"宗主头像" in acc', '"宗主头像" in old')

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n=== 修复后（第11912-11919行）===")
for i in range(11911, 11919):
    if i < len(lines):
        print(f"{i+1}: {lines[i].rstrip()}")

print("\n✅ 第11913-11918行的错误已修复！")
