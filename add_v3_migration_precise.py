# -*- coding: utf-8 -*-
"""
添加v2→v3的存档迁移逻辑（精确匹配）
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 查找"# 更新版本号"这一行
found = False
for i, line in enumerate(lines):
    if '# 更新版本号' in line:
        print(f"找到更新版本号在第{i+1}行: {line.strip()}")
        # 在这一行之前插入v2→v3的迁移逻辑
        indent = '\t\t'  # 两个tab缩进
        migration_code = [
            f'{indent}# v2→v3：新增阵营任务/商店、道友互动、探索事件分支选择系统\n',
            f'{indent}if 旧版本 < 3:\n',
            f'{indent}\t# 新增字段默认零回归（确保键存在，load时也会用.get默认值处理）\n',
            f'{indent}\tif not 迁移后.has("阵营任务进度"):\n',
            f'{indent}\t\t迁移后["阵营任务进度"] = {{}}\n',
            f'{indent}\tif not 迁移后.has("阵营商店购买记录"):\n',
            f'{indent}\t\t迁移后["阵营商店购买记录"] = {{}}\n',
            f'{indent}\tif not 迁移后.has("结义道友列表"):\n',
            f'{indent}\t\t迁移后["结义道友列表"] = []\n',
            f'{indent}\tif not 迁移后.has("道友拜访冷却"):\n',
            f'{indent}\t\t迁移后["道友拜访冷却"] = {{}}\n',
            f'{indent}\tif not 迁移后.has("道友切磋冷却"):\n',
            f'{indent}\t\t迁移后["道友切磋冷却"] = {{}}\n',
            f'{indent}\tif not 迁移后.has("探索事件冷却"):\n',
            f'{indent}\t\t迁移后["探索事件冷却"] = {{}}\n',
            f'{indent}\tpush_warning("存档迁移 v2→v3：新增阵营任务/商店、道友互动、探索事件系统字段")\n',
        ]
        # 插入代码
        lines[i:i] = migration_code
        found = True
        print("✅ v2→v3存档迁移逻辑添加成功")
        break

if not found:
    print("❌ 未找到更新版本号行")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("\n🎉 v2→v3存档迁移逻辑添加完成！")
