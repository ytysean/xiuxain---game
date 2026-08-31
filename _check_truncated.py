import re

# 检查game_state.gd中是否还有被截断的变量名或函数名
with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 常见的被截断的函数名模式
truncated_func_patterns = [
    r'_CSV去\b',
    r'_加载负面开关\b',
    r'_平衡器平衡\b',
    r'_造低阶物品掉落\b',
    r'_结算俸禄\b',
    r'_结算运维成本\b',
    r'_结算负面事件\b',
    r'_可能触发特殊登门\b',
    r'_结算香火\b',
    r'_检查正邪解锁\b',
    r'_结算大阵耐久\b',
    r'_器殿赠宝\b',
    r'_新手_检测\b',
    r'_主线当前进度\b',
    r'_存在长寿弟子\b',
    r'兽随机成蛋\b',
    r'兽取消出战\b',
    r'现负责加成评分\b',
    r'悟道值推进修炼\b',
    r'取历\b',
]

# 常见的被截断的变量名模式
truncated_var_patterns = [
    r'\b堂\b',
    r'\b额\b',
    r'\b产\b',
    r'\b记\b',
    r'\b行\b',
    r'\b奖\b',
    r'\b表\b',
    r'\b池\b',
    r'\b果\b',
    r'\b天\b',
    r'\b年\b',
    r'\b名\b',
    r'\b时\b',
    r'\b权\b',
    r'\b档\b',
    r'\b序\b',
    r'\b纪\b',
    r'\b新\b',
    r'\b宠\b',
    r'\b享\b',
    r'\b物\b',
    r'\b卡\b',
    r'\b发\b',
    r'\b级\b',
    r'旧负\b',
    r'存姓名\b',
    r'存弟子ID\b',
]

# 点号丢失的模式
missing_dot_patterns = [
    r'eget\(',
    r'eis_empty\(',
    r'永久卡激活or\b',
    r'已锁定and\b',
    r'buff\(\)',
]

print('检查被截断的函数名:')
print('=' * 60)
found_func = False
for i, line in enumerate(lines):
    for pattern in truncated_func_patterns:
        if re.search(pattern, line):
            print(f'L{i+1}: {line.strip()[:80]}')
            found_func = True
            break
if not found_func:
    print('未发现被截断的函数名')

print()
print('检查点号丢失的模式:')
print('=' * 60)
found_dot = False
for i, line in enumerate(lines):
    for pattern in missing_dot_patterns:
        if re.search(pattern, line):
            print(f'L{i+1}: {line.strip()[:80]}')
            found_dot = True
            break
if not found_dot:
    print('未发现点号丢失的模式')
