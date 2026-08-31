with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L4948: 战报更新.emit(果) -> 战报更新.emit(报)
print(f'L4948原始: {repr(lines[4947])}')
lines[4947] = lines[4947].replace('战报更新.emit(果)', '战报更新.emit(报)')
print(f'L4948修复后: {repr(lines[4947])}')

# 修复L4950: return 果 -> return 报
print(f'L4950原始: {repr(lines[4949])}')
lines[4949] = lines[4949].replace('return 果', 'return 报')
print(f'L4950修复后: {repr(lines[4949])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
