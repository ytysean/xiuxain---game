with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6650: 时 -> 部件[4].to_int() if 部件.size() > 4 else 1
print(f'L6650原始: {repr(lines[6649])}')
lines[6649] = lines[6649].replace(
    'return "(%s产出%.1f倍，持续%d个月)" % [资源, 权, 时]',
    'return "(%s产出%.1f倍，持续%d个月)" % [资源, 倍, 部件[4].to_int() if 部件.size() > 4 else 1]'
)
print(f'L6650修复后: {repr(lines[6649])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
