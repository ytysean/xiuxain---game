with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6596的return 摘要缩进
print(f'L6596原始: {repr(lines[6595])}')
lines[6595] = '\treturn 摘要\n'
print(f'L6596修复后: {repr(lines[6595])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
