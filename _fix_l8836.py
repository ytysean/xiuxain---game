with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8836: d.试炼冷却剩余 = 试炼冷却剩余 -> d.试炼冷却剩余 = 试炼冷却日
print(f'L8836原始: {repr(lines[8835])}')
lines[8835] = lines[8835].replace('d.试炼冷却剩余 = 试炼冷却剩余', 'd.试炼冷却剩余 = 试炼冷却日')
print(f'L8836修复后: {repr(lines[8835])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
