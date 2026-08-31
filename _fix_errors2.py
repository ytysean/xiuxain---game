with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3500 - 变量名应该是"榜"不是"名"
print(f'L3500原始: {repr(lines[3499])}')
lines[3499] = '\tvar 榜: Array = []\n'
print(f'L3500修复后: {repr(lines[3499])}')

# 修复L3516 - 变量名应该是"名"不是"列表"
print(f'L3516原始: {repr(lines[3515])}')
lines[3515] = '\t\t\t\t名 = "%s·%s" % [宗门名, d.道号]\n'
print(f'L3516修复后: {repr(lines[3515])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
