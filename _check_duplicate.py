with open('game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

print(f'总行数: {len(lines)}')
half = len(lines) // 2
print(f'一半行数: {half}')

# 检查前半部分和后半部分是否相同
same = True
diff_count = 0
for i in range(half):
    if lines[i] != lines[i + half]:
        diff_count += 1
        if diff_count <= 10:
            print(f'不同行 L{i+1} vs L{i+half+1}:')
            print(f'  前: {lines[i][:80].rstrip()}')
            print(f'  后: {lines[i+half][:80].rstrip()}')

if diff_count == 0:
    print('\n✅ 文件完全重复！前半部分和后半部分完全相同。')
else:
    print(f'\n⚠️ 文件不完全重复，有 {diff_count} 行不同。')

# 看看前10行和后10行
print('\n=== 前10行 ===')
for i in range(10):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')

print('\n=== 中间10行 (L5850-5860) ===')
for i in range(5849, min(5860, len(lines))):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')

print('\n=== 后10行 ===')
for i in range(len(lines)-10, len(lines)):
    print(f'L{i+1}: {lines[i].rstrip()[:80]}')
