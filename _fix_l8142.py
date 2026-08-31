with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L8142: 权+= float(r.get("weight", 0)) -> 总权+= float(r.get("weight", 0))
print(f'L8142原始: {repr(lines[8141])}')
lines[8141] = lines[8141].replace('权+= float(r.get("weight", 0))', '总权+= float(r.get("weight", 0))')
print(f'L8142修复后: {repr(lines[8141])}')

# 修复L8144: if 权<= 0: -> if 总权<= 0:
print(f'L8144原始: {repr(lines[8143])}')
lines[8143] = lines[8143].replace('if 权<= 0:', 'if 总权<= 0:')
print(f'L8144修复后: {repr(lines[8143])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
