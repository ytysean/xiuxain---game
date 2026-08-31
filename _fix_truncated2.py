with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复被截断的函数名
fixes = [
    ('_新手_检测(', '_新手_检查条件('),
    ('汇总负责人全局', '汇总负责人全局buff()'),
    ('设置气运', '设置气运buff('),
]

fix_count = 0
for old, new in fixes:
    count = content.count(old)
    if count > 0:
        content = content.replace(old, new)
        fix_count += count
        print(f'修复 {old} -> {new}: {count} 处')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print(f'\n总共修复了 {fix_count} 处')
