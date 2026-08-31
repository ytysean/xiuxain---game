with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 里程碑_已达. -> 里程碑_已达成.
old = '里程碑_已达.'
new = '里程碑_已达成.'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 成就_已达. -> 成就_已达成.
old = '成就_已达.'
new = '成就_已达成.'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')
