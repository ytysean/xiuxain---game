with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5408: 灵石 += 物 -> 灵石 += 额
print(f'L5408原始: {repr(lines[5407])}')
lines[5407] = lines[5407].replace('灵石 += 物', '灵石 += 额')
print(f'L5408修复后: {repr(lines[5407])}')

# 修复L5410: 奖 -> 额
print(f'L5410原始: {repr(lines[5409])}')
lines[5409] = lines[5409].replace('灵石+%d： %s" % [评级, 奖]', '灵石+%d： %s" % [评级, 额]')
print(f'L5410修复后: {repr(lines[5409])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
