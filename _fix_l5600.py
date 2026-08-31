with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L5600: var 物: Item = _造低阶物品掉落.get("类型", "fabao")
# -> var 物: Item = _造低阶物品(掉落.get("类型", "fabao"), 掉落.get("品阶", "上品"))
print(f'L5600原始: {repr(lines[5599])}')
lines[5599] = lines[5599].replace(
    'var 物: Item = _造低阶物品掉落.get("类型", "fabao")',
    'var 物: Item = _造低阶物品(掉落.get("类型", "fabao"), 掉落.get("品阶", "上品"))'
)
print(f'L5600修复后: {repr(lines[5599])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
