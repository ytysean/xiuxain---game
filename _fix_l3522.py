with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3522: 列表.append -> 榜.append
print(f'L3522原始: {repr(lines[3521])}')
lines[3521] = lines[3521].replace('列表.append', '榜.append')
print(f'L3522修复后: {repr(lines[3521])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
