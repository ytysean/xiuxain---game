with open('game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复明显的点号丢失和关键字空格丢失
fixes = [
    ('eget()', 'e.get()'),
    ('eis_empty()', 'e.is_empty()'),
    ('已锁定and()', '已锁定 and'),
    ('永久卡激活or()', '永久卡激活 or'),
    ('器殿主destiny_id', '器殿主.destiny_id'),
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
