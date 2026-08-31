# -*- coding: utf-8 -*-
"""
清理game_state.gd文件中的行尾空格和多余的空行
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 统计修改数量
trailing_spaces_removed = 0
consecutive_empty_removed = 0

# 清理行尾空格
for i in range(len(lines)):
    old_line = lines[i]
    # 保留换行符，移除行尾空格
    if old_line.endswith('\r\n'):
        lines[i] = old_line.rstrip() + '\r\n'
    elif old_line.endswith('\n'):
        lines[i] = old_line.rstrip() + '\n'
    elif old_line.endswith('\r'):
        lines[i] = old_line.rstrip() + '\r'
    else:
        lines[i] = old_line.rstrip()
    if old_line != lines[i]:
        trailing_spaces_removed += 1

# 移除连续的空行（最多保留1个空行）
new_lines = []
prev_empty = False
for line in lines:
    is_empty = line.strip() == ''
    if is_empty and prev_empty:
        consecutive_empty_removed += 1
        continue
    new_lines.append(line)
    prev_empty = is_empty

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f"✅ 清理完成！")
print(f"移除行尾空格: {trailing_spaces_removed} 行")
print(f"移除连续空行: {consecutive_empty_removed} 行")
print(f"原总行数: {len(lines)}")
print(f"新总行数: {len(new_lines)}")
