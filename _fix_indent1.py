with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5750 - 缩进应该是3个tab（while循环内，if块外）
print(f'L5750原始: {repr(lines[5749])}')
lines[5749] = '\t\t\tvar 列: PackedStringArray = 行.split(",")\n'
print(f'L5750修复后: {repr(lines[5749])}')

# 修复L5752 - if语句缩进应该是3个tab
print(f'L5752原始: {repr(lines[5751])}')
lines[5751] = '\t\t\tif 列.size() >= 2:\n'
print(f'L5752修复后: {repr(lines[5751])}')

# 修复L5754 - 应该在if块内，缩进4个tab
print(f'L5754原始: {repr(lines[5753])}')
lines[5753] = '\t\t\t\t_经济基线缓存[列[0].strip_edges()] = 列[1].strip_edges()\n'
print(f'L5754修复后: {repr(lines[5753])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
