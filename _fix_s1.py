with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    content = f.read()

# 修复 _结算俸禄._S1() -> _结算俸禄_S1()
old = '_结算俸禄._S1()'
new = '_结算俸禄_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _结算运维成本._S1() -> _结算运维成本_S1()
old = '_结算运维成本._S1()'
new = '_结算运维成本_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _结算负面事件._S1() -> _结算负面事件_S1()
old = '_结算负面事件._S1()'
new = '_结算负面事件_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _可能触发特殊登门._S1() -> _可能触发特殊登门_S1()
old = '_可能触发特殊登门._S1()'
new = '_可能触发特殊登门_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _结算香火._S1() -> _结算香火_S1()
old = '_结算香火._S1()'
new = '_结算香火_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _检查正邪解锁._S1() -> _检查正邪解锁_S1()
old = '_检查正邪解锁._S1()'
new = '_检查正邪解锁_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

# 修复 _结算大阵耐久._S1() -> _结算大阵耐久_S1()
old = '_结算大阵耐久._S1()'
new = '_结算大阵耐久_S1()'
count = content.count(old)
content = content.replace(old, new)
print(f'修复 {old} -> {new}: {count} 处')

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('修复完成')
