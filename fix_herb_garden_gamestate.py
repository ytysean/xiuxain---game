# -*- coding: utf-8 -*-
"""
修复page_herb_garden.gd中的GameState错误
将所有的GameState替换为Game
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_herb_garden.gd"

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
    
    print(f"✅ page_herb_garden.gd：替换了 {count} 处 GameState -> Game")
else:
    print(f"ℹ️ page_herb_garden.gd：没有找到 GameState")

print(f"\n🎉 总共替换了 {count} 处 GameState -> Game")
