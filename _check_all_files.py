import re
import os

def get_functions(filepath):
    functions = set()
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                match = re.match(r'^(static\s+)?func\s+(\w+)', line)
                if match:
                    functions.add(match.group(2))
    except Exception as e:
        print(f'读取文件 {filepath} 出错: {e}')
    return functions

# 遍历所有.gd文件
all_gd_files = []
for root, dirs, files in os.walk('.'):
    # 跳过备份文件和插件目录
    if 'backup' in root or 'addons' in root or 'tests' in root:
        continue
    for f in files:
        if f.endswith('.gd') and 'backup' not in f and 'recovered' not in f:
            all_gd_files.append(os.path.join(root, f))

print('所有.gd文件函数数量统计:')
print('=' * 60)
total_funcs = 0
zero_func_files = []
for f in sorted(all_gd_files):
    funcs = get_functions(f)
    total_funcs += len(funcs)
    if len(funcs) == 0:
        zero_func_files.append(f)
        print(f'{f}: {len(funcs)} 个函数 ⚠️')
    else:
        print(f'{f}: {len(funcs)} 个函数')

print('=' * 60)
print(f'总文件数: {len(all_gd_files)}')
print(f'总函数数量: {total_funcs}')
if zero_func_files:
    print(f'⚠️ 0个函数的文件 ({len(zero_func_files)} 个):')
    for f in zero_func_files:
        print(f'  - {f}')
else:
    print('✅ 所有文件都有函数定义')
