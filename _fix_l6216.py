with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6216: 原因.size() -> 原因池.size()
print(f'L6216原始: {repr(lines[6215])}')
lines[6215] = lines[6215].replace('原因.size()]', '原因池.size()]')
print(f'L6216修复后: {repr(lines[6215])}')

# 修复L6224: if not e.is_empty(): -> if not 事.is_empty():
print(f'L6224原始: {repr(lines[6223])}')
lines[6223] = lines[6223].replace('if not e.is_empty():', 'if not 事.is_empty():')
print(f'L6224修复后: {repr(lines[6223])}')

# 修复L6226: 文本 += "\n" + 纯文案 -> 文本 += "\n" + 事.get("文案", "")
print(f'L6226原始: {repr(lines[6225])}')
lines[6225] = lines[6225].replace('文本 += "\\n" + 纯文案', '文本 += "\\n" + 事.get("文案", "")')
print(f'L6226修复后: {repr(lines[6225])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
