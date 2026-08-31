with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复所有 Disciple.境界表.get(d.境界) < 目标值 -> 境界顺序.find(d.境界) < 目标值
old = 'Disciple.境界表.get(d.境界) < 目标值'
new = '境界顺序.find(d.境界) < 目标值'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')
