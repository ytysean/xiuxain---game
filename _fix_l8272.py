with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8272: 档= 弟子列表 -> 候选= 弟子列表
print(f'L8272原始: {repr(lines[8271])}')
lines[8271] = lines[8271].replace('档= 弟子列表', '候选= 弟子列表')
print(f'L8272修复后: {repr(lines[8271])}')

# 修复L8274: return 档[randi() % 档.size()] -> return 候选[randi() % 候选.size()]
print(f'L8274原始: {repr(lines[8273])}')
lines[8273] = lines[8273].replace('return 档[randi() % 档.size()]', 'return 候选[randi() % 候选.size()]')
print(f'L8274修复后: {repr(lines[8273])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
