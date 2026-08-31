with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6498 - 变量名改成"段文本"
print(f'L6498原始: {repr(lines[6497])}')
lines[6497] = '\t\t\tvar 段文本: String = 段.strip_edges()\n'
print(f'L6498修复后: {repr(lines[6497])}')

# 修复L6500 - 变量名改成"段文本"
print(f'L6500原始: {repr(lines[6499])}')
lines[6499] = '\t\t\tif 段文本 == "":\n'
print(f'L6500修复后: {repr(lines[6499])}')

# 修复L6504 - 变量名改成"段文本"
print(f'L6504原始: {repr(lines[6503])}')
lines[6503] = '\t\t\tif not 段文本.contains(":"):\n'
print(f'L6504修复后: {repr(lines[6503])}')

# 修复L6506 - 变量名改成"段文本"
print(f'L6506原始: {repr(lines[6505])}')
lines[6505] = '\t\t\t\t摘要 += " " + 段文本\n'
print(f'L6506修复后: {repr(lines[6505])}')

# 修复L6510 - 变量名改成"段文本"，并修复split调用
print(f'L6510原始: {repr(lines[6509])}')
lines[6509] = '\t\t\tvar 部件: Array = 段文本.split(":", false)\n'
print(f'L6510修复后: {repr(lines[6509])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
