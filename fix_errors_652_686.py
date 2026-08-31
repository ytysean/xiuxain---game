# -*- coding: utf-8 -*-
"""
修复game_state.gd第652-686行的错误
1. 添加道心和攻击变量定义
2. 修复mini()函数调用（改为min()，并将体力上限改为体力上限()）
3. 修复get()函数调用
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 1. 在第2588行附近添加道心和攻击变量定义
# 第2588行是 "var 体力 := 50"
print("=== 1. 添加道心和攻击变量定义 ===")
for i in range(len(lines)):
    if lines[i].strip() == "var 体力 := 50":
        # 在这行后面添加道心和攻击变量定义
        lines.insert(i+1, "var 道心 := 50  # 道心值，影响修炼效率\n")
        lines.insert(i+2, "var 攻击 := 10  # 攻击力，影响战斗输出\n")
        print(f"已在第{i+1}行后添加道心和攻击变量定义")
        break

# 重新读取行号（因为插入了新行）
# 2. 修复第660行和第669行的mini()函数调用
print("\n=== 2. 修复mini()函数调用 ===")
for i in range(len(lines)):
    if "mini(体力 + 30, 体力上限)" in lines[i]:
        lines[i] = lines[i].replace("mini(体力 + 30, 体力上限)", "min(体力 + 30, 体力上限())")
        print(f"已修复第{i+1}行的mini()函数调用")
    elif "mini(体力 + 20, 体力上限)" in lines[i]:
        lines[i] = lines[i].replace("mini(体力 + 20, 体力上限)", "min(体力 + 20, 体力上限())")
        print(f"已修复第{i+1}行的mini()函数调用")

# 3. 修复第686行的get()函数调用
print("\n=== 3. 修复get()函数调用 ===")
for i in range(len(lines)):
    if '兽["亲密度"] = int(兽.get("亲密度", 0)) + 5' in lines[i]:
        lines[i] = lines[i].replace('兽["亲密度"] = int(兽.get("亲密度", 0)) + 5', '兽["亲密度"] = int(兽.get("亲密度") if "亲密度" in 兽 else 0) + 5')
        print(f"已修复第{i+1}行的get()函数调用")
        break

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n✅ 第652-686行的错误已修复！")
