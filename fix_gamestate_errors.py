# -*- coding: utf-8 -*-
"""
批量修复UI页面中的GameState错误，将GameState替换为Game
"""

import os

# 需要修复的文件列表
files_to_fix = [
    r"E:\Xiuxian\taixuanzongmenlu\ui\page_puppet.gd",
    r"E:\Xiuxian\taixuanzongmenlu\ui\page_library.gd",
    r"E:\Xiuxian\taixuanzongmenlu\ui\page_pill_formula.gd",
    r"E:\Xiuxian\taixuanzongmenlu\ui\page_equipment_blueprint.gd",
]

total_replacements = 0

for file_path in files_to_fix:
    if not os.path.exists(file_path):
        print(f"❌ 文件不存在：{file_path}")
        continue
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 统计替换次数
    count = content.count("GameState")
    
    if count > 0:
        # 替换GameState为Game
        content = content.replace("GameState", "Game")
        
        # 写回文件
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"✅ {os.path.basename(file_path)}：替换了 {count} 处 GameState -> Game")
        total_replacements += count
    else:
        print(f"ℹ️ {os.path.basename(file_path)}：没有找到 GameState")

print(f"\n🎉 总共替换了 {total_replacements} 处 GameState -> Game")
