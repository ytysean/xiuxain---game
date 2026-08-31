with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6512-L6594的缩进问题：去掉一个tab
# L6596的return 摘要：加上一个tab
for i in range(6511, 6595):  # L6512-L6595
    line = lines[i]
    if line.startswith('\t'):
        lines[i] = line[1:]  # 去掉一个tab
        print(f'L{i+1}: 去掉一个tab')

# 修复L6596的return 摘要
print(f'L6596原始: {repr(lines[6595])}')
lines[6595] = '\treturn 摘要\n'
print(f'L6596修复后: {repr(lines[6595])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
