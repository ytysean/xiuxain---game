import re

def get_functions(filepath):
    functions = set()
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            match = re.match(r'^func\s+(\w+)', line)
            if match:
                functions.add(match.group(1))
    return functions

current = get_functions('game_state.gd')
backup = get_functions('game_state_backup_safe.gd')

print(f'当前文件函数数量: {len(current)}')
print(f'备份文件函数数量: {len(backup)}')
print()

# 检查当前文件中缺失的函数
missing = backup - current
if missing:
    print(f'当前文件中缺失的函数 ({len(missing)} 个):')
    for func in sorted(missing):
        print(f'  - {func}')
else:
    print('当前文件没有缺失函数')

print()

# 检查当前文件中新增的函数
added = current - backup
if added:
    print(f'当前文件中新增的函数 ({len(added)} 个):')
    for func in sorted(added):
        print(f'  - {func}')
else:
    print('当前文件没有新增函数')
