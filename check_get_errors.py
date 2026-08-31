# -*- coding: utf-8 -*-
"""
批量修复game_state.gd中的get方法调用错误
将 dict.get(key, default) 改为 dict.get(key) if dict.has(key) else default
但是，考虑到代码量很大，我们先查看一下具体的错误位置
"""

import re

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 错误行号列表
error_lines = [2248, 4963, 4973, 4979, 4985, 4991, 5001, 5007, 5013, 5016, 5044, 5203, 5231, 5235, 5243, 5250, 5257, 5263, 5269, 5271, 5278, 5285, 5297]

print("=== 错误行内容 ===")
for line_num in error_lines:
    if line_num <= len(lines):
        line = lines[line_num - 1].strip()
        print(f"第{line_num}行: {line}")

print("\n=== 修复方案 ===")
print("由于错误数量较多，建议手动检查这些行的get方法调用")
print("如果确实是Dictionary的get方法调用，可以改为：")
print("  dict.get(key) if dict.has(key) else default")
print("或者：")
print("  dict.get(key, default)  # 如果Godot 4.7支持的话")
