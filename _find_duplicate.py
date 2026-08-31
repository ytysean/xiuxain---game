with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'当前总行数: {len(lines)}')

# 检查重复点：从哪里开始重复
# 找第二个 extends Node 或第二个 func _ready()
for i in range(1, len(lines)):
    if 'extends Node' in lines[i] and i > 10:
        print(f'第二个 extends Node 在 L{i+1}')
        break

# 找第二个 # game_state.gd
for i in range(1, len(lines)):
    if '# game_state.gd' in lines[i] and i > 10:
        print(f'第二个 # game_state.gd 在 L{i+1}')
        break

# 看看L11700-L11710的内容
print('\n=== L11700-L11710 ===')
for i in range(11699, min(11710, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')

# 看看前10行和L11705-L11715是否相同
print('\n=== 前10行 ===')
for i in range(10):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')

print('\n=== L11705-L11715 ===')
for i in range(11704, min(11715, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')
