with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9442: 兽随机成蛋( -> 兽.随机成蛋(
print(f'L9442原始: {repr(lines[9441])}')
lines[9441] = lines[9441].replace('兽随机成蛋(', '兽.随机成蛋(')
print(f'L9442修复后: {repr(lines[9441])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
