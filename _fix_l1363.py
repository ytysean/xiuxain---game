with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1363和L1369: 悟道值 -> 悟道点
for i in [1362, 1368]:
    print(f'L{i+1}原始: {repr(lines[i])}')
    lines[i] = lines[i].replace('悟道值', '悟道点')
    print(f'L{i+1}修复后: {repr(lines[i])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
