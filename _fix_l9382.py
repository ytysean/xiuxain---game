with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9382: 文本列.append -> 文本行.append
print(f'L9382原始: {repr(lines[9381])}')
lines[9381] = lines[9381].replace('文本列.append(条目.get("text", ""))', '文本行.append(条目.get("text", ""))')
print(f'L9382修复后: {repr(lines[9381])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
