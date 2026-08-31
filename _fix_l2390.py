with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2390: 列表 -> 配
print(f'L2390原始: {repr(lines[2389])}')
lines[2389] = lines[2389].replace('列表.get("稀有权重"', '配.get("稀有权重"')
print(f'L2390修复后: {repr(lines[2389])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
