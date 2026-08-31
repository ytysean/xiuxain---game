# -*- coding: utf-8 -*-
"""
批量修复测试工具文件中的GDScript语法错误：
1. "=" * 60 → "=".repeat(60)
2. "-" * 40 → "-".repeat(40)
3. 其他字符串重复操作
"""

import os
import re

tests_dir = r"E:\Xiuxian\taixuanzongmenlu\tests"

# 需要修复的文件列表
files_to_fix = [
    "numerical_stats.gd",
    "battle_simulator.gd",
    "economy_simulator.gd",
    "test_tools_main.gd",
]

def fix_string_repeat(content):
    """修复字符串重复操作："xxx" * N → "xxx".repeat(N)"""
    # 匹配模式："字符串" * 数字
    pattern = r'"([^"]*)"\s*\*\s*(\d+)'

    def replacer(match):
        string = match.group(1)
        count = match.group(2)
        return '"%s".repeat(%s)' % (string, count)

    return re.sub(pattern, replacer, content)

# 修复每个文件
for filename in files_to_fix:
    filepath = os.path.join(tests_dir, filename)
    if not os.path.exists(filepath):
        print("⚠️  文件不存在: %s" % filename)
        continue

    print("\n" + "=" * 60)
    print("修复文件: %s" % filename)
    print("=" * 60)

    # 读取文件
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # 修复字符串重复操作
    content = fix_string_repeat(content)

    # 检查是否有修改
    if content != original_content:
        # 保存文件
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ 修复完成")
    else:
        print("ℹ️  无需修复")

print("\n" + "=" * 60)
print("所有文件修复完成！")
print("=" * 60)
