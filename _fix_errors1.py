with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复L2700 - 变量名冲突，把String类型的"价"改成"物品名"
print(f'L2700原始: {repr(lines[2699])}')
lines[2699] = '\tvar 物品名: String = str(it.get("名称", "未知物品"))\n'
print(f'L2700修复后: {repr(lines[2699])}')

# 修复L2704 - 灵石 += 名 应该是 灵石 += 价
print(f'L2704原始: {repr(lines[2703])}')
lines[2703] = '\t灵石 += 价\n'
print(f'L2704修复后: {repr(lines[2703])}')

# 修复L2712 - 语法错误
print(f'L2712原始: {repr(lines[2711])}')
lines[2711] = '\treturn {"ok": true, "msg": "售予商队 %s（高价回收%d%%）+%d灵石" % [物品名, int(商队回收系数 * 100), 价]}\n'
print(f'L2712修复后: {repr(lines[2711])}')

with open('game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(lines)
print('修复完成')
