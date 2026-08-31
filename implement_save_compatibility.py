# -*- coding: utf-8 -*-
"""
实现存档兼容（版本管理、迁移逻辑）
1. 升级存档版本号从2到3
2. 在存档保存中添加新增的变量
3. 在存档加载中添加新增变量的读取
4. 添加存档迁移逻辑
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\game_state.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# ============ 1. 升级存档版本号 ============
print("步骤1：升级存档版本号从2到3...")

old_version = '''const SAVE_VERSION := 2   # 存档结构版本号：损坏检测与跨版本兼容用。v2：图鉴系统标识符重命名（图鉴配置/收藏图鉴_已收集/图鉴更新/图鉴ID/图鉴_已收集存档键 → 图录*），旧档载入时版本不符将自动备份并重新初始化'''

new_version = '''const SAVE_VERSION := 3   # 存档结构版本号：损坏检测与跨版本兼容用。v3：新增阵营任务/商店、道友互动（拜访/切磋/结义）、探索事件分支选择系统；旧档载入时版本不符将自动备份并迁移'''

if old_version in content:
    content = content.replace(old_version, new_version)
    print("  ✅ 存档版本号升级成功")
else:
    print("  ❌ 未找到存档版本号")

# ============ 2. 在存档保存中添加新增的变量 ============
print("\n步骤2：在存档保存中添加新增的变量...")

old_save = '''		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
	}'''

new_save = '''		# 历练派遣系统（不升SAVE_VERSION，旧档缺键→默认零回归）
		"历练系统": ExpeditionSystem.to_dict() if ExpeditionSystem != null else {},
		# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
		"阵营任务进度": 阵营任务进度,
		"阵营商店购买记录": 阵营商店购买记录,
		# v3 新增：道友互动系统（旧档缺键→默认零回归）
		"结义道友列表": 结义道友列表,
		"道友拜访冷却": 道友拜访冷却,
		"道友切磋冷却": 道友切磋冷却,
		# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
		"探索事件冷却": 探索事件冷却,
	}'''

if old_save in content:
    content = content.replace(old_save, new_save)
    print("  ✅ 存档保存新增变量添加成功")
else:
    print("  ❌ 未找到存档保存插入位置")

# ============ 3. 在存档加载中添加新增变量的读取 ============
print("\n步骤3：在存档加载中添加新增变量的读取...")

old_load = '''	# 老档兼容：加载后数值合法性校验与兜底修正（防坏档崩溃 / 异常数据自动修正：
	灵石 = _修正负值(灵石, "灵石")'''

new_load = '''	# v3 新增：阵营任务和商店系统（旧档缺键→默认零回归）
	阵营任务进度 = data.get("阵营任务进度", {})
	阵营商店购买记录 = data.get("阵营商店购买记录", {})
	# v3 新增：道友互动系统（旧档缺键→默认零回归）
	结义道友列表 = data.get("结义道友列表", [])
	道友拜访冷却 = data.get("道友拜访冷却", {})
	道友切磋冷却 = data.get("道友切磋冷却", {})
	# v3 新增：探索事件分支选择系统（旧档缺键→默认零回归）
	探索事件冷却 = data.get("探索事件冷却", {})
	# 老档兼容：加载后数值合法性校验与兜底修正（防坏档崩溃 / 异常数据自动修正：
	灵石 = _修正负值(灵石, "灵石")'''

if old_load in content:
    content = content.replace(old_load, new_load)
    print("  ✅ 存档加载新增变量读取添加成功")
else:
    print("  ❌ 未找到存档加载插入位置")

# ============ 4. 添加存档迁移逻辑 ============
print("\n步骤4：添加存档迁移逻辑...")

# 查找_迁移存档函数
old_migrate = '''func _迁移存档(data: Dictionary, 旧版本: int) -> Dictionary:
	# v1 → v2：图鉴系统标识符重命名
	if 旧版本 < 2:
		# 图鉴配置 → 图录配置（如果存在）
		if "图鉴配置" in data:
			data["图录配置"] = data["图鉴配置"]
			data.erase("图鉴配置")
		# 收藏图鉴_已收集 → 收藏图录_已收集
		if "收藏图鉴_已收集" in data:
			data["图录_已收集"] = data["收藏图鉴_已收集"]
			data.erase("收藏图鉴_已收集")
		# 图鉴更新 → 图录更新（信号名，不影响存档，但这里标记一下）
		# 图鉴ID → 图录ID
		# 图鉴_已收集存档键 → 图录_已收集存档键
		push_warning("存档迁移：v1 → v2 完成（图鉴系统标识符重命名）")
	return data'''

new_migrate = '''func _迁移存档(data: Dictionary, 旧版本: int) -> Dictionary:
	# v1 → v2：图鉴系统标识符重命名
	if 旧版本 < 2:
		# 图鉴配置 → 图录配置（如果存在）
		if "图鉴配置" in data:
			data["图录配置"] = data["图鉴配置"]
			data.erase("图鉴配置")
		# 收藏图鉴_已收集 → 收藏图录_已收集
		if "收藏图鉴_已收集" in data:
			data["图录_已收集"] = data["收藏图鉴_已收集"]
			data.erase("收藏图鉴_已收集")
		# 图鉴更新 → 图录更新（信号名，不影响存档，但这里标记一下）
		# 图鉴ID → 图录ID
		# 图鉴_已收集存档键 → 图录_已收集存档键
		push_warning("存档迁移：v1 → v2 完成（图鉴系统标识符重命名）")
	# v2 → v3：新增阵营任务/商店、道友互动、探索事件分支选择系统
	if 旧版本 < 3:
		# 新增字段默认零回归（load时会用.get默认值处理，这里确保键存在）
		if "阵营任务进度" not in data:
			data["阵营任务进度"] = {}
		if "阵营商店购买记录" not in data:
			data["阵营商店购买记录"] = {}
		if "结义道友列表" not in data:
			data["结义道友列表"] = []
		if "道友拜访冷却" not in data:
			data["道友拜访冷却"] = {}
		if "道友切磋冷却" not in data:
			data["道友切磋冷却"] = {}
		if "探索事件冷却" not in data:
			data["探索事件冷却"] = {}
		push_warning("存档迁移：v2 → v3 完成（新增阵营任务/商店、道友互动、探索事件系统）")
	return data'''

if old_migrate in content:
    content = content.replace(old_migrate, new_migrate)
    print("  ✅ 存档迁移逻辑添加成功")
else:
    print("  ❌ 未找到_迁移存档函数，尝试搜索...")
    # 搜索_迁移存档函数
    if "_迁移存档" in content:
        print("  找到_迁移存档函数，但内容不匹配")
    else:
        print("  未找到_迁移存档函数，需要创建")

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("\n🎉 存档兼容（版本管理、迁移逻辑）实现完成！")
print("\n📋 存档版本升级说明：")
print("  版本号：v2 → v3")
print("  新增系统：")
print("    1. 阵营任务和商店系统")
print("    2. 道友互动系统（拜访、切磋、结义）")
print("    3. 探索事件分支选择系统")
print("\n📋 存档保存新增字段：")
print("  - 阵营任务进度")
print("  - 阵营商店购买记录")
print("  - 结义道友列表")
print("  - 道友拜访冷却")
print("  - 道友切磋冷却")
print("  - 探索事件冷却")
print("\n📋 存档迁移逻辑：")
print("  - v1 → v2：图鉴系统标识符重命名")
print("  - v2 → v3：新增字段默认零回归")
print("  - 旧版本存档自动备份后迁移")
