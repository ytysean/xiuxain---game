with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 删除L265-L269的重复return语句（只保留L264）
# 注意：行号从0开始，所以L265是lines[264]，L269是lines[268]
print(f'删除前L264-L269:')
for i in range(263, 269):
    print(f'  L{i+1}: {repr(lines[i])}')

# 删除L265-L269（lines[264]到lines[268]）
del lines[264:269]

print(f'删除后L264: {repr(lines[263])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print(f'修复完成，当前行数: {len(lines)}')
