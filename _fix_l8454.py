with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8454: 现分 = 现负责加成评分(维度) -> 现分 = 现负责.加成评分(维度)
print(f'L8454原始: {repr(lines[8453])}')
lines[8453] = lines[8453].replace('现分 = 现负责加成评分(维度)', '现分 = 现负责.加成评分(维度)')
print(f'L8454修复后: {repr(lines[8453])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
