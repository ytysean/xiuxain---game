with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L10881
print(f'L10881原始: {repr(lines[10880])}')
lines[10880] = '\t\tpush_warning("save_game: 当前账号id 为空，跳过存档")\n'
print(f'L10881修复后: {repr(lines[10880])}')

# 修复L10967
print(f'L10967原始: {repr(lines[10966])}')
lines[10966] = '\t\tpush_error("主存档解析失败，尝试从历史备份恢复")\n'
print(f'L10967修复后: {repr(lines[10966])}')

# 修复L11515
print(f'L11515原始: {repr(lines[11514])}')
lines[11514] = '\t\tpush_warning("new_game: 当前账号id 为空，跳过")\n'
print(f'L11515修复后: {repr(lines[11514])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
