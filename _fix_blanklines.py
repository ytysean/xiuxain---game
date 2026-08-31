with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 删除多余的单行空行：如果当前行是空行，前一行不是空行，也不是以冒号结尾的行（函数/类定义），就删除
new_lines = []
for i, line in enumerate(lines):
    if line.strip() == '':
        # 空行
        if i > 0 and lines[i-1].strip() != '':
            # 前一行不是空行
            # 检查前一行是否以冒号结尾（函数/类定义、if/for/while等）
            prev_line = lines[i-1].rstrip()
            if prev_line.endswith(':'):
                # 函数/类定义后面的空行保留
                new_lines.append(line)
            else:
                # 其他单行空行删除
                pass
        else:
            # 前一行也是空行，保留（连续空行）
            new_lines.append(line)
    else:
        new_lines.append(line)

with open(r'E:\Xiuxian\taixuanzongmenlu\game_state.gd', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print(f'原始行数: {len(lines)}')
print(f'修复后行数: {len(new_lines)}')
print(f'删除空行数: {len(lines) - len(new_lines)}')
