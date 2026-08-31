with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5750 - 变量名改成"列"
print(f'L5750原始: {repr(lines[5749])}')
lines[5749] = '\t\t\tvar 列: PackedStringArray = 行.split(",")\n'
print(f'L5750修复后: {repr(lines[5749])}')

# 修复L5752 - 变量名改成"列"
print(f'L5752原始: {repr(lines[5751])}')
lines[5751] = '\t\t\tif 列.size() >= 2:\n'
print(f'L5752修复后: {repr(lines[5751])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
