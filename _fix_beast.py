with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 兽孵化中 -> 兽.孵化中
old = '兽孵化中'
new = '兽.孵化中'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 兽等级上限 -> 兽.等级上限
old = '兽等级上限'
new = '兽.等级上限'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 兽等级 -> 兽.等级
old = '兽等级'
new = '兽.等级'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 兽忠诚 -> 兽.忠诚
old = '兽忠诚'
new = '兽.忠诚'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')
