with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5440: 保类别 -> 物.类别, 阶品阶 -> 物.品阶, 名名称 -> 物.名称
print(f'L5440原始: {repr(lines[5439])}')
lines[5439] = lines[5439].replace(
    '七载待发掉落.append({"类型": 保类别, "品阶": 阶品阶, "名称": 名名称})',
    '七载待发掉落.append({"类型": 物.类别, "品阶": 物.品阶, "名称": 物.名称})'
)
print(f'L5440修复后: {repr(lines[5439])}')

# 修复L5442: 名称 -> 物.名称
print(f'L5442原始: {repr(lines[5441])}')
lines[5441] = lines[5441].replace('上品法宝：%s】" % [评级, 名称]', '上品法宝：%s】" % [评级, 物.名称]')
print(f'L5442修复后: {repr(lines[5441])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
