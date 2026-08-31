with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6512-L6594的缩进问题：去掉1个tab
for i in range(6511, 6595):  # L6512-L6595
    line = lines[i]
    if line.startswith('\t'):
        lines[i] = line[1:]  # 去掉1个tab
        print(f'L{i+1}: 去掉1个tab')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
