with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1059: const -> var
print(f'L1059原始: {repr(lines[1058])}')
lines[1058] = lines[1058].replace('const 礼包配置', 'var 礼包配置')
print(f'L1059修复后: {repr(lines[1058])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
