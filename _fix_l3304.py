with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3304: return 表 -> return 价
print(f'L3304原始: {repr(lines[3303])}')
lines[3303] = lines[3303].replace('return 表', 'return 价')
print(f'L3304修复后: {repr(lines[3303])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
