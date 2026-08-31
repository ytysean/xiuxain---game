with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L3320: 表 = str(v) -> 阶 = str(v)
print(f'L3320原始: {repr(lines[3319])}')
lines[3319] = lines[3319].replace('表 = str(v)', '阶 = str(v)')
print(f'L3320修复后: {repr(lines[3319])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
