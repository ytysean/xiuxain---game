with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L9492: "引育计划%s" % ("启用" if 新 else "停用") -> "引育计划%s" % ("启用" if 新增 else "停用")
print(f'L9492原始: {repr(lines[9491])}')
lines[9491] = lines[9491].replace('"引育计划%s" % ("启用" if 新 else "停用")', '"引育计划%s" % ("启用" if 新增 else "停用")')
print(f'L9492修复后: {repr(lines[9491])}')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
