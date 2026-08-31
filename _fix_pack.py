with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L628: "描述": 文案表["pack_growth_blessing_desc"], -> "描述": "成长助力，含灵石×5000、悟道×100",
print(f'L628原始: {repr(lines[627])}')
lines[627] = lines[627].replace('"描述": 文案表["pack_growth_blessing_desc"],', '"描述": "成长助力，含灵石×5000、悟道×100",')
print(f'L628修复后: {repr(lines[627])}')

# 修复L636: "描述": 文案表["pack_supreme_desc"], -> "描述": "至尊尊享，含灵石×20000、绑定仙玉×1000",
print(f'L636原始: {repr(lines[635])}')
lines[635] = lines[635].replace('"描述": 文案表["pack_supreme_desc"],', '"描述": "至尊尊享，含灵石×20000、绑定仙玉×1000",')
print(f'L636修复后: {repr(lines[635])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
