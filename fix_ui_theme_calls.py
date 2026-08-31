# -*- coding: utf-8 -*-
"""
批量修复 page_faction.gd 和 page_zongmen_battle.gd 中的UITheme函数调用错误：
apply_title_text → apply_title_font
"""

import os

ui_dir = r"E:\Xiuxian\taixuanzongmenlu\ui"

# 需要修复的文件列表
files_to_fix = [
    "page_faction.gd",
    "page_zongmen_battle.gd",
]

# 修复映射
fixes = {
    "UITheme.apply_title_text(": "UITheme.apply_title_font(",
}

for filename in files_to_fix:
    filepath = os.path.join(ui_dir, filename)
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
    fix_count = 0

    # 应用修复
    for old, new in fixes.items():
        count = content.count(old)
        if count > 0:
            content = content.replace(old, new)
            fix_count += count
            print("✅ 修复 %s → %s (%d处)" % (old, new, count))

    # 检查是否有修改
    if content != original_content:
        # 保存文件
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print("✅ 共修复 %d 处，已保存到 %s" % (fix_count, filename))
    else:
        print("ℹ️  无需修复")

print("\n" + "=" * 60)
print("所有文件修复完成！")
print("=" * 60)

# 验证修复
print("\n验证修复结果：")
for filename in files_to_fix:
    filepath = os.path.join(ui_dir, filename)
    if not os.path.exists(filepath):
        continue
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    if "apply_title_text" in content:
        print("❌ %s: 仍存在 apply_title_text 错误" % filename)
    else:
        print("✅ %s: 已修复 apply_title_text 错误" % filename)
    if "apply_title_font" in content:
        print("✅ %s: 存在 apply_title_font 正确调用" % filename)
