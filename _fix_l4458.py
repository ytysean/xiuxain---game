with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4458: 表.get -> 日.get
print(f'L4458原始: {repr(lines[4457])}')
lines[4457] = lines[4457].replace('return 表.get(稀有度, 20)', 'return 日.get(稀有度, 20)')
print(f'L4458修复后: {repr(lines[4457])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
