# -*- coding: utf-8 -*-
"""
修复game_state.gd中获取商城商品列表函数未找到的错误
添加获取商城商品列表()函数，直接调用获取所有商城商品列表()函数
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 在第3312行的获取所有商城商品列表()函数后面添加获取商城商品列表()函数
print("=== 添加获取商城商品列表()函数 ===")
for i in range(len(lines)):
    if "func 获取所有商城商品列表() -> Array:" in lines[i]:
        # 找到函数结束的位置（下一个func或空行+注释）
        j = i + 1
        while j < len(lines):
            if lines[j].strip().startswith("func ") or (lines[j].strip().startswith("# ") and j+1 < len(lines) and lines[j+1].strip().startswith("func ")):
                break
            j += 1
        # 在j位置插入获取商城商品列表()函数
        lines.insert(j, "\n")
        lines.insert(j+1, "# 获取商城商品列表（简化版本，直接调用获取所有商城商品列表）\n")
        lines.insert(j+2, "func 获取商城商品列表() -> Array:\n")
        lines.insert(j+3, "\treturn 获取所有商城商品列表()\n")
        print(f"已在第{j+1}行后添加获取商城商品列表()函数")
        break

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n✅ 获取商城商品列表函数未找到的错误已修复！")
