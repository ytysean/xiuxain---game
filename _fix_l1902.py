with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1902: e -> 条
print(f'L1902原始: {repr(lines[1901])}')
lines[1901] = lines[1901].replace('结果.append(e)', '结果.append(条)')
print(f'L1902修复后: {repr(lines[1901])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
