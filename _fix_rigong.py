with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 "日供总领取次": 日供_总领取次, -> "日供总领取次": 日供_总领取次数,
old = '"日供总领取次": 日供_总领取次,'
new = '"日供总领取次": 日供_总领取次数,'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')
