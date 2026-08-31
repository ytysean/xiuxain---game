# -*- coding: utf-8 -*-
"""
添加v2→v3的存档迁移逻辑
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_migrate = '''		# 更新版本号
	迁移后["version"] = SAVE_VERSION
	return 迁移后'''

new_migrate = '''	# v2→v3：新增阵营任务/商店、道友互动、探索事件分支选择系统
	if 旧版本 < 3:
		# 新增字段默认零回归（确保键存在，load时也会用.get默认值处理）
		if not 迁移后.has("阵营任务进度"):
			迁移后["阵营任务进度"] = {}
		if not 迁移后.has("阵营商店购买记录"):
			迁移后["阵营商店购买记录"] = {}
		if not 迁移后.has("结义道友列表"):
			迁移后["结义道友列表"] = []
		if not 迁移后.has("道友拜访冷却"):
			迁移后["道友拜访冷却"] = {}
		if not 迁移后.has("道友切磋冷却"):
			迁移后["道友切磋冷却"] = {}
		if not 迁移后.has("探索事件冷却"):
			迁移后["探索事件冷却"] = {}
		push_warning("存档迁移 v2→v3：新增阵营任务/商店、道友互动、探索事件系统字段")
	# 更新版本号
	迁移后["version"] = SAVE_VERSION
	return 迁移后'''

if old_migrate in content:
    content = content.replace(old_migrate, new_migrate)
    print("✅ v2→v3存档迁移逻辑添加成功")
else:
    print("❌ 未找到迁移函数插入位置")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 v2→v3存档迁移逻辑添加完成！")
