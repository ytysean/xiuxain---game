with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L6056: id= str(目标.get_instance_id()) -> 名= str(目标.get_instance_id())
print(f'L6056原始: {repr(lines[6055])}')
lines[6055] = lines[6055].replace('id= str(目标.get_instance_id())', '名= str(目标.get_instance_id())')
print(f'L6056修复后: {repr(lines[6055])}')

# 修复L6058: if not _弟子负面属性累计.has(id): -> if not _弟子负面属性累计.has(名):
print(f'L6058原始: {repr(lines[6057])}')
lines[6057] = lines[6057].replace('if not _弟子负面属性累计.has(id):', 'if not _弟子负面属性累计.has(名):')
print(f'L6058修复后: {repr(lines[6057])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
