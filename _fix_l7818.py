with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L7818: 额.get("等级", 1) -> 职.get("等级", 1)
print(f'L7818原始: {repr(lines[7817])}')
lines[7817] = lines[7817].replace('额.get("等级", 1)', '职.get("等级", 1)')
print(f'L7818修复后: {repr(lines[7817])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
