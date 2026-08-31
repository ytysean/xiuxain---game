with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L1257: const -> var
print(f'L1257原始: {repr(lines[1256])}')
lines[1256] = lines[1256].replace('const 互动配置', 'var 互动配置')
print(f'L1257修复后: {repr(lines[1256])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
