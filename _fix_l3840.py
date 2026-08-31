with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3840: 列表.append -> 表.append
print(f'L3840原始: {repr(lines[3839])}')
lines[3839] = lines[3839].replace('列表.append', '表.append')
print(f'L3840修复后: {repr(lines[3839])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
