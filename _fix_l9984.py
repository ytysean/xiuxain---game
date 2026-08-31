with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9984: "名称": 名, -> "名称": 宗门名,
print(f'L9984原始: {repr(lines[9983])}')
lines[9983] = lines[9983].replace('"名称": 名,', '"名称": 宗门名,')
print(f'L9984修复后: {repr(lines[9983])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
