with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9584: 宠= 弟子.副宠灵兽 -> 兽= 弟子.副宠灵兽
print(f'L9584原始: {repr(lines[9583])}')
lines[9583] = lines[9583].replace('宠= 弟子.副宠灵兽', '兽= 弟子.副宠灵兽')
print(f'L9584修复后: {repr(lines[9583])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
