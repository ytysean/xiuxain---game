extends Node

## 炼器系统数据层（Autoload单例）

# P0-3 装备本体数据接入：装备模板缓存（来自equip_main.csv）
var _装备模板缓存: Array = []
var _装备模板已加载: bool = false

# 加载装备模板表（equip_main.csv）
static func 加载装备模板() -> Array:
	if ForgeSystem._装备模板已加载:
		return ForgeSystem._装备模板缓存
	var 结果: Array = []
	var csvPath := "res://config/equip_main.csv"
	if FileAccess.file_exists(csvPath):
		var f := FileAccess.open(csvPath, FileAccess.READ)
		if f != null:
			var 表头: Array = f.get_csv_line()
			while not f.eof_reached():
				var 行: Array = f.get_csv_line()
				if 行.size() >= 12 and 行[0] != "":
					var 模板: Dictionary = {
						"equip_id": str(行[0]),
						"equip_name": str(行[1]),
						"grade": str(行[2]),
						"sub_grade": str(行[3]),
						"equip_slot": str(行[4]),
						"apply_class": str(行[5]),
						"base_atk": int(行[6]),
						"base_def": int(行[7]),
						"base_hp": int(行[8]),
						"base_durability": int(行[9]),
						"repair_material": str(行[10]),
						"sell_price": int(行[11]),
					}
					结果.append(模板)
			f.close()
	ForgeSystem._装备模板缓存 = 结果
	ForgeSystem._装备模板已加载 = true
	return 结果

# 根据品阶+穿戴位匹配装备模板（优先匹配apply_class，其次通用）



# P0-3 材料配置接入：材料配置缓存（来自item_material.csv）
var _材料配置缓存: Array = []
var _材料配置已加载: bool = false

# 加载材料配置表（item_material.csv）
static func 加载材料配置() -> Array:
	if ForgeSystem._材料配置已加载:
		return ForgeSystem._材料配置缓存
	var 结果: Array = []
	var csvPath := "res://config/item_material.csv"
	if FileAccess.file_exists(csvPath):
		var f := FileAccess.open(csvPath, FileAccess.READ)
		if f != null:
			var 表头: Array = f.get_csv_line()
			while not f.eof_reached():
				var 行: Array = f.get_csv_line()
				if 行.size() >= 9 and 行[0] != "":
					var 材料: Dictionary = {
						"mat_id": str(行[0]),
						"mat_name": str(行[1]),
						"grade": str(行[2]),
						"mat_type": str(行[3]),
						"usage_desc": str(行[4]),
						"obtain_way": str(行[5]),
						"stack_max": int(行[6]),
						"sell_price_ling": int(行[7]),
						"realm_correspond": str(行[8]),
					}
					结果.append(材料)
			f.close()
	ForgeSystem._材料配置缓存 = 结果
	ForgeSystem._材料配置已加载 = true
	return 结果

# 材料名映射：硬编码材料名 → CSV材料名（用于向后兼容）
const 材料名映射: Dictionary = {
	"凡铁": "凡铁矿石",
	"灵铁": "精铁矿石",
	"宝铁": "百年玄铁",
	"王铁": "千年玄铁",
	"圣铁": "万年玄铁",
	"仙金": "万年玄铁",
	"混沌石": "万年玄铁",
	"初阶灵石": "灵晶",
	"中阶灵石": "灵晶",
	"高阶灵石": "玄晶",
	"极品灵石": "玄晶",
	"仙阶灵石": "圣晶",
	"道阶灵石": "圣晶",
	"天道灵石": "圣晶",
}

# 获取材料的CSV名称（支持硬编码名映射）
static func 获取材料CSV名(材料名: String) -> String:
	if 材料名映射.has(材料名):
		return str(材料名映射[材料名])
	return 材料名

# 获取材料配置（按名称查找）
static func 获取材料配置(材料名: String) -> Dictionary:
	var csv名: String = 获取材料CSV名(材料名)
	var 材料配置: Array = 加载材料配置()
	for 材料 in 材料配置:
		if str(材料.get("mat_name", "")) == csv名:
			return 材料
	return {}
# P0-3 装备图纸数据接入：图纸配置缓存（来自equip_blueprint.csv）
var _图纸配置缓存: Array = []
var _图纸配置已加载: bool = false

# 加载图纸配置表（equip_blueprint.csv）
static func 加载图纸配置() -> Array:
	if ForgeSystem._图纸配置已加载:
		return ForgeSystem._图纸配置缓存
	var 结果: Array = []
	var csvPath := "res://config/equip_blueprint.csv"
	if FileAccess.file_exists(csvPath):
		var f := FileAccess.open(csvPath, FileAccess.READ)
		if f != null:
			var 表头: Array = f.get_csv_line()
			while not f.eof_reached():
				var 行: Array = f.get_csv_line()
				if 行.size() >= 8 and 行[0] != "":
					var 图纸: Dictionary = {
						"blueprint_id": str(行[0]),
						"blueprint_name": str(行[1]),
						"grade": str(行[2]),
						"sub_grade": str(行[3]),
						"target_equip_id": str(行[4]),
						"unlock_condition": str(行[5]),
						"craft_cost": int(行[6]),
						"sell_price": int(行[7]),
					}
					结果.append(图纸)
			f.close()
	ForgeSystem._图纸配置缓存 = 结果
	ForgeSystem._图纸配置已加载 = true
	return 结果

# 解析器殿等级条件（如"器殿1级解锁" → 1）
static func 解析器殿等级条件(条件字符串: String) -> int:
	if 条件字符串 == "":
		return 1
	var 正则: RegEx = RegEx.new()
	正则.compile("器殿([0-9]+)级")
	var 匹配: RegExMatch = 正则.search(条件字符串)
	if 匹配 != null:
		return int(匹配.get_string(1))
	return 1
# P0-3 装备套装数据接入：套装配置缓存（来自equip_set.csv）
var _套装配置缓存: Array = []
var _套装配置已加载: bool = false

# 加载套装配置表（equip_set.csv）
static func 加载套装配置() -> Array:
	if ForgeSystem._套装配置已加载:
		return ForgeSystem._套装配置缓存
	var 结果: Array = []
	var csvPath := "res://config/equip_set.csv"
	if FileAccess.file_exists(csvPath):
		var f := FileAccess.open(csvPath, FileAccess.READ)
		if f != null:
			var 表头: Array = f.get_csv_line()
			while not f.eof_reached():
				var 行: Array = f.get_csv_line()
				if 行.size() >= 10 and 行[0] != "":
					var 套装: Dictionary = {
						"set_id": str(行[0]),
						"set_name": str(行[1]),
						"grade": str(行[2]),
						"sub_grade": str(行[3]),
						"apply_class": str(行[4]),
						"set_2pc_effect": str(行[5]),
						"set_2pc_value": str(行[6]),
						"set_4pc_effect": str(行[7]),
						"set_4pc_value": str(行[8]),
					}
					结果.append(套装)
			f.close()
	ForgeSystem._套装配置缓存 = 结果
	ForgeSystem._套装配置已加载 = true
	return 结果

# 解析套装效果值（支持"2.5%"、"4.2%+6.0%"等格式）
static func 解析套装效果值(值字符串: String) -> float:
	if 值字符串 == "":
		return 0.0
	# 取第一个百分比值
	var 匹配: RegExMatch = null
	var 正则: RegEx = RegEx.new()
	正则.compile("([0-9.]+)%")
	匹配 = 正则.search(值字符串)
	if 匹配 != null:
		return float(匹配.get_string(1)) / 100.0
	return 0.0

# 计算弟子套装战力加成（检查已穿戴装备的套装ID）
static func 计算套装战力加成(弟子装备: Dictionary) -> Dictionary:
	var 结果: Dictionary = {"战力加成": 0, "套装列表": [], "2件套": [], "4件套": []}
	if 弟子装备 == null or 弟子装备.is_empty():
		return 结果
	# 统计每个套装ID的穿戴数量
	var 套装计数: Dictionary = {}
	for 槽位 in 弟子装备.keys():
		var 装备 = 弟子装备[槽位]
		if 装备 == null:
			continue
		var 套装ID: String = ""
		if typeof(装备) == TYPE_OBJECT:
			套装ID = str(装备.套装ID)
		elif typeof(装备) == TYPE_DICTIONARY:
			套装ID = str(装备.get("套装ID", ""))
		if 套装ID == "":
			continue
		# 提取套装基础ID（去掉品阶后缀，如 set_001_下品 -> set_001）
		var 基础ID: String = 套装ID
		var 下划线位置: int = 套装ID.rfind("_")
		if 下划线位置 > 0:
			基础ID = 套装ID.substr(0, 下划线位置)
		if 套装计数.has(基础ID):
			套装计数[基础ID] += 1
		else:
			套装计数[基础ID] = 1
	# 加载套装配置
	var 套装配置: Array = 加载套装配置()
	# 计算2件套和4件套效果
	for 基础ID in 套装计数.keys():
		var 数量: int = int(套装计数[基础ID])
		if 数量 < 2:
			continue
		# 找到该套装的配置（取最高品阶）
		var 匹配套装: Dictionary = {}
		for 套装 in 套装配置:
			if str(套装.get("set_id", "")).begins_with(基础ID):
				if 匹配套装.is_empty() or str(套装.get("grade", "")) > str(匹配套装.get("grade", "")):
					匹配套装 = 套装
		if 匹配套装.is_empty():
			continue
		结果["套装列表"].append(匹配套装.get("set_name", ""))
		# 2件套效果
		if 数量 >= 2:
			var 效果2: String = str(匹配套装.get("set_2pc_effect", ""))
			var 值2: float = 解析套装效果值(str(匹配套装.get("set_2pc_value", "")))
			结果["2件套"].append({"效果": 效果2, "值": 值2})
			# 转换为战力加成（攻击/全属性/法伤/灵力 → 战力；气血 → 战力×0.5）
			if 效果2 in ["攻击", "全属性", "法伤", "灵力", "水系伤害"]:
				结果["战力加成"] += int(值2 * 100)
			elif 效果2 == "气血":
				结果["战力加成"] += int(值2 * 50)
		# 4件套效果
		if 数量 >= 4:
			var 效果4: String = str(匹配套装.get("set_4pc_effect", ""))
			var 值4: float = 解析套装效果值(str(匹配套装.get("set_4pc_value", "")))
			结果["4件套"].append({"效果": 效果4, "值": 值4})
			# 复合效果取第一个值
			if 效果4.find("+") > 0:
				var 主效果: String = 效果4.substr(0, 效果4.find("+"))
				if 主效果 in ["攻击", "全属性", "法伤", "灵力", "暴击", "暴伤", "群伤", "破甲", "减伤", "减速"]:
					结果["战力加成"] += int(值4 * 80)
			elif 效果4 in ["攻击", "全属性", "法伤", "灵力", "减伤", "暴击", "暴伤"]:
				结果["战力加成"] += int(值4 * 80)
	return 结果
static func 匹配装备模板(品阶: String, 穿戴位: String, 道途: String = "") -> Dictionary:
	var 模板列表: Array = 加载装备模板()
	# 穿戴位映射：代码中的穿戴位 → CSV中的equip_slot
	var 槽位映射: Dictionary = {
		"wuqi": "武器", "toukui": "头盔", "yipao": "衣袍", "huzhi": "护腕",
		"yaodai": "腰带", "changku": "裤子", "xuezi": "靴子", "peishi": "配饰",
	}
	var csv槽位: String = str(槽位映射.get(穿戴位, 穿戴位))
	# 优先匹配：品阶+槽位+道途
	for 模板 in 模板列表:
		if str(模板.get("grade", "")) == 品阶 and str(模板.get("equip_slot", "")) == csv槽位:
			var 适用: String = str(模板.get("apply_class", "通用"))
			if 道途 != "" and (适用 == 道途 or 适用 == "通用"):
				return 模板
			elif 道途 == "" and 适用 == "通用":
				return 模板
	# 次选：品阶+槽位+通用
	for 模板 in 模板列表:
		if str(模板.get("grade", "")) == 品阶 and str(模板.get("equip_slot", "")) == csv槽位 and str(模板.get("apply_class", "")) == "通用":
			return 模板
	# 最后：品阶+任意槽位
	for 模板 in 模板列表:
		if str(模板.get("grade", "")) == 品阶:
			return 模板
	return {}

## 炼器配方定义、炼器逻辑、装备产出

# 炼器配方库：配方ID → {名称, 品阶, 产出装备名, 产出类别, 产出穿戴位, 材料[{名, 数量}], 基础成功率, 描述}
const 配方库: Dictionary = {
	# 凡阶
	"tie_jian": {
		"名称": "铁剑配方", "品阶": "凡阶",
		"产出名": "铁剑", "产出类别": "fa_qi", "产出穿戴位": "wuqi",
		"材料": [{"名": "凡铁", "数量": 3}, {"名": "初阶灵石", "数量": 1}],
		"基础成功率": 75, "描述": "入门法器，凡铁锻造。"
	},
	"bu_yi": {
		"名称": "布衣配方", "品阶": "凡阶",
		"产出名": "粗布道袍", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "凡铁", "数量": 2}, {"名": "初阶灵石", "数量": 1}],
		"基础成功率": 80, "描述": "入门法袍，粗布缝制。"
	},
	# 灵阶
	"qingfeng_jian": {
		"名称": "青锋剑配方", "品阶": "灵阶",
		"产出名": "青锋剑", "产出类别": "fa_qi", "产出穿戴位": "wuqi",
		"材料": [{"名": "灵铁", "数量": 3}, {"名": "中阶灵石", "数量": 1}],
		"基础成功率": 65, "描述": "灵铁锻造，剑刃泛青芒。"
	},
	"suozi_jia": {
		"名称": "锁子甲配方", "品阶": "灵阶",
		"产出名": "锁子甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "灵铁", "数量": 2}, {"名": "中阶灵石", "数量": 1}],
		"基础成功率": 70, "描述": "灵铁锁环，护身有道。"
	},
	# 宝阶
	"liuguang_jian": {
		"名称": "流光剑配方", "品阶": "宝阶",
		"产出名": "流光剑", "产出类别": "shen_bing", "产出穿戴位": "wuqi", "产出道途": "法修",
		"材料": [{"名": "宝铁", "数量": 3}, {"名": "高阶灵石", "数量": 1}],
		"基础成功率": 55, "描述": "宝铁淬炼，剑光如流水。"
	},
	"xuantie_jia": {
		"名称": "玄铁甲配方", "品阶": "宝阶",
		"产出名": "玄铁甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "宝铁", "数量": 2}, {"名": "高阶灵石", "数量": 1}],
		"基础成功率": 60, "描述": "玄铁重铸，防御惊人。"
	},
	# 王阶
	"zhuxian_jian": {
		"名称": "诛仙剑配方", "品阶": "王阶",
		"产出名": "诛仙剑", "产出类别": "shen_bing", "产出穿戴位": "wuqi", "产出道途": "法修",
		"材料": [{"名": "王铁", "数量": 3}, {"名": "极品灵石", "数量": 1}],
		"基础成功率": 45, "描述": "王阶神兵，剑气凌人。"
	},
	"zijin_jia": {
		"名称": "紫金甲配方", "品阶": "王阶",
		"产出名": "紫金甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "王铁", "数量": 2}, {"名": "极品灵石", "数量": 1}],
		"基础成功率": 50, "描述": "紫金镶嵌，王者之甲。"
	},
	# 圣阶
	"taiji_jian": {
		"名称": "太极剑配方", "品阶": "圣阶",
		"产出名": "太极剑", "产出类别": "shen_bing", "产出穿戴位": "wuqi", "产出道途": "道修",
		"材料": [{"名": "圣铁", "数量": 3}, {"名": "仙阶灵石", "数量": 1}],
		"基础成功率": 35, "描述": "圣阶神兵，阴阳相生。"
	},
	"xuanwu_jia": {
		"名称": "玄武甲配方", "品阶": "圣阶",
		"产出名": "玄武甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "圣铁", "数量": 2}, {"名": "仙阶灵石", "数量": 1}],
		"基础成功率": 40, "描述": "玄武之象，固若金汤。"
	},
	# 仙阶
	"xuanyuan_jian": {
		"名称": "轩辕剑配方", "品阶": "仙阶",
		"产出名": "轩辕剑", "产出类别": "shen_bing", "产出穿戴位": "wuqi", "产出道途": "道修",
		"材料": [{"名": "仙金", "数量": 3}, {"名": "道阶灵石", "数量": 1}],
		"基础成功率": 25, "描述": "仙阶神兵，人皇之剑。"
	},
	"tiandi_jia": {
		"名称": "天帝甲配方", "品阶": "仙阶",
		"产出名": "天帝甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "仙金", "数量": 2}, {"名": "道阶灵石", "数量": 1}],
		"基础成功率": 30, "描述": "天帝之威，万法不侵。"
	},
	# 道阶
	"tiandao_jian": {
		"名称": "天道剑配方", "品阶": "道阶",
		"产出名": "天道剑", "产出类别": "shen_bing", "产出穿戴位": "wuqi", "产出道途": "道修",
		"材料": [{"名": "混沌石", "数量": 3}, {"名": "天道灵石", "数量": 1}],
		"基础成功率": 15, "描述": "道阶神兵，天道轮转。"
	},
	"hundun_jia": {
		"名称": "混沌甲配方", "品阶": "道阶",
		"产出名": "混沌甲", "产出类别": "fa_qi", "产出穿戴位": "yipao",
		"材料": [{"名": "混沌石", "数量": 2}, {"名": "天道灵石", "数量": 1}],
		"基础成功率": 20, "描述": "混沌初开，万法归一。"
	},
}
# S46 P1：配置表扩展配方（运行时从 forge_recipe_config.csv 加载，合并到 配方库）
static var 配置表扩展配方: Dictionary = {}

## 检查材料是否足够
# P0-3：支持材料名映射（硬编码名 → CSV名），同时检查两种名称
static func 检查材料(配方ID: String, 背包: Array) -> Dictionary:
	var 配方 = 获取配方(配方ID)
	if 配方.is_empty():
		return {"足够": false, "原因": "配方不存在"}
	for mat in 配方["材料"]:
		var 需求名: String = str(mat["名"])
		var 需求数: int = int(mat["数量"])
		# P0-3：获取CSV材料名（用于向后兼容）
		var csv需求名: String = 获取材料CSV名(需求名)
		var 拥有数: int = 0
		for item in 背包:
			if item != null and typeof(item) == TYPE_OBJECT and "名称" in item:
				var 物品名: String = str(item.名称)
				# P0-3：同时检查硬编码名和CSV名
				if 物品名 == 需求名 or 物品名 == csv需求名:
					拥有数 += 1
		if 拥有数 < 需求数:
			return {"足够": false, "原因": "材料不足：%s（%d/%d）" % [需求名, 拥有数, 需求数], "缺失": 需求名}
	return {"足够": true}

## 炼器品质定义
const 品质列表: Array = ["普通", "精良", "极品", "传说"]
const 品质加成: Dictionary = {
	"普通": 1.0,
	"精良": 1.2,
	"极品": 1.5,
	"传说": 2.0,
}
const 品质概率: Dictionary = {
	"凡阶": {"普通": 0.7, "精良": 0.25, "极品": 0.05, "传说": 0.0},
	"灵阶": {"普通": 0.5, "精良": 0.35, "极品": 0.13, "传说": 0.02},
	"宝阶": {"普通": 0.3, "精良": 0.4, "极品": 0.25, "传说": 0.05},
	"王阶": {"普通": 0.15, "精良": 0.35, "极品": 0.35, "传说": 0.15},
	"圣阶": {"普通": 0.05, "精良": 0.25, "极品": 0.45, "传说": 0.25},
	"仙阶": {"普通": 0.0, "精良": 0.15, "极品": 0.5, "传说": 0.35},
	"道阶": {"普通": 0.0, "精良": 0.05, "极品": 0.45, "传说": 0.5},
}

## 炼器经验系统
## 炼器等级：影响成功率和高品质概率
## 经验值：炼器成功获得经验，失败获得一半经验
const 炼器等级表: Array = [
	{"等级": 1, "所需经验": 0, "成功率加成": 0, "高品质加成": 0},
	{"等级": 2, "所需经验": 100, "成功率加成": 2, "高品质加成": 0.02},
	{"等级": 3, "所需经验": 300, "成功率加成": 4, "高品质加成": 0.04},
	{"等级": 4, "所需经验": 600, "成功率加成": 6, "高品质加成": 0.06},
	{"等级": 5, "所需经验": 1000, "成功率加成": 8, "高品质加成": 0.08},
	{"等级": 6, "所需经验": 1500, "成功率加成": 10, "高品质加成": 0.10},
	{"等级": 7, "所需经验": 2100, "成功率加成": 12, "高品质加成": 0.12},
	{"等级": 8, "所需经验": 2800, "成功率加成": 14, "高品质加成": 0.14},
	{"等级": 9, "所需经验": 3600, "成功率加成": 16, "高品质加成": 0.16},
	{"等级": 10, "所需经验": 4500, "成功率加成": 20, "高品质加成": 0.20},
]

## 根据经验值获取炼器等级
static func 获取炼器等级(经验值: int) -> int:
	var 等级: int = 1
	for 配置 in 炼器等级表:
		if 经验值 >= int(配置["所需经验"]):
			等级 = int(配置["等级"])
	return 等级

## 获取炼器等级加成
static func 获取炼器加成(经验值: int) -> Dictionary:
	var 等级: int = 获取炼器等级(经验值)
	for 配置 in 炼器等级表:
		if int(配置["等级"]) == 等级:
			return {"等级": 等级, "成功率加成": float(配置["成功率加成"]), "高品质加成": float(配置["高品质加成"])}
	return {"等级": 1, "成功率加成": 0.0, "高品质加成": 0.0}

## 计算炼器获得经验（根据配方品阶）
static func 计算炼器经验(配方品阶: String, 成功: bool) -> int:
	var 基础经验: Dictionary = {
		"凡阶": 10, "灵阶": 20, "宝阶": 40, "王阶": 80,
		"圣阶": 120, "仙阶": 200, "道阶": 300
	}
	var 经验: int = int(基础经验.get(配方品阶, 10))
	if not 成功:
		经验 = int(经验 * 0.5)  # 失败获得一半经验
	return 经验

## S46 P1：设置配置表扩展配方（从game_state.gd调用）
static func 设置配置表配方(配方表: Dictionary) -> void:
	配置表扩展配方 = 配方表

## 获取配方（优先配置表，回落硬编码）
static func 获取配方(配方ID: String) -> Dictionary:
	if 配置表扩展配方.has(配方ID):
		return 配置表扩展配方[配方ID] as Dictionary
	return 配方库.get(配方ID, {}) as Dictionary

## S46 P3 器纹系统（对应炼丹的丹纹系统）
## 器纹等级：0-9（0=无纹），每级+5%战力
## 器纹名称：根据等级命名
static func 器纹名称(纹: int) -> String:
	var 纹名: Dictionary = {
		0: "无纹", 1: "凡纹", 2: "灵纹", 3: "宝纹",
		4: "王纹", 5: "圣纹", 6: "仙纹", 7: "道纹",
		8: "神纹", 9: "天纹"
	}
	return str(纹名.get(纹, "无纹"))

## 器纹战力加成：每级+5%战力
static func 器纹战力加成(纹: int) -> float:
	return 1.0 + float(纹) * 0.05

## 掷器纹：根据品阶和器堂等级决定器纹等级
static func 掷器纹(品阶: String, 器堂等级: int = 1, 额外出纹: float = 0.0) -> int:
	# 品阶基础出纹率
	var 品阶出纹率: Dictionary = {
		"凡阶": 0.1, "灵阶": 0.2, "宝阶": 0.35, "王阶": 0.5,
		"圣阶": 0.65, "仙阶": 0.8, "道阶": 0.9
	}
	var 基础率: float = float(品阶出纹率.get(品阶, 0.1))
	# 器堂等级加成：每级+3%出纹率
	var 等级加成: float = float(max(0, 器堂等级 - 1)) * 0.03
	# 额外出纹加成
	var 总出纹率: float = clamp(基础率 + 等级加成 + 额外出纹, 0.05, 0.95)
	# 判定是否出纹
	if randf() > 总出纹率:
		return 0
	# 出纹等级：1-9，品阶越高越容易出高纹
	var 纹等级概率: Dictionary = {
		"凡阶": [0.6, 0.25, 0.1, 0.05, 0, 0, 0, 0, 0],
		"灵阶": [0.4, 0.3, 0.2, 0.08, 0.02, 0, 0, 0, 0],
		"宝阶": [0.25, 0.3, 0.25, 0.15, 0.04, 0.01, 0, 0, 0],
		"王阶": [0.15, 0.25, 0.3, 0.2, 0.08, 0.02, 0, 0, 0],
		"圣阶": [0.08, 0.17, 0.25, 0.3, 0.15, 0.04, 0.01, 0, 0],
		"仙阶": [0.04, 0.1, 0.2, 0.3, 0.25, 0.08, 0.02, 0.01, 0],
		"道阶": [0.02, 0.05, 0.13, 0.25, 0.3, 0.17, 0.05, 0.02, 0.01]
	}
	var 概率列表: Array = 纹等级概率.get(品阶, [0.6, 0.25, 0.1, 0.05, 0, 0, 0, 0, 0]) as Array
	var 随机值: float = randf()
	var 累计: float = 0.0
	for i in range(概率列表.size()):
		累计 += float(概率列表[i])
		if 随机值 <= 累计:
			return i + 1
	return 1

## S46 P2：装备战力加成差异化（不同武器类型和装备部位有不同战力系数）
static func 计算装备战力(品阶: String, 穿戴位: String, 配方ID: String = "") -> int:
	# 品阶基础战力
	var 品阶战力: Dictionary = {"凡阶":10, "灵阶":30, "宝阶":80, "王阶":200, "圣阶":500, "仙阶":1200, "道阶":3000}
	var 基础: int = int(品阶战力.get(品阶, 10))
	# 武器类型战力系数
	var 武器系数: Dictionary = {
		"dao": 1.3, "chui": 1.3, "fu": 1.3,  # 高攻击型：刀、锤、斧
		"jian": 1.0, "qiang": 1.0, "gun": 1.0,  # 平衡型：剑、枪、棍
		"huan": 0.9, "bian": 0.9, "gou": 0.9,  # 敏捷型：环、鞭、钩
		"shan": 1.1, "zhu": 1.1, "qin": 1.1,  # 法术型：扇、珠、琴
		"ta": 0.8, "zhong": 0.8, "ding": 0.8,  # 防御型：塔、钟、鼎
		"fuchen": 0.85, "jing": 0.85, "yin": 0.85,  # 辅助型：拂尘、镜、印
		"suo": 0.9, "jian2": 0.95  # 控制型：索、锏
	}
	# 装备部位战力系数
	var 部位系数: Dictionary = {
		"yipao": 1.0, "touku": 0.8, "huwan": 0.7, "hutui": 0.75,
		"xuezi": 0.6, "yaodai": 0.65, "xianglian": 0.7, "jiezhi": 0.65,
		"shouzhuo": 0.6, "yupei": 0.55, "pifeng": 0.65
	}
	var 系数: float = 1.0
	if 穿戴位 == "wuqi":
		# 从配方ID提取武器类型（如 jian_fan → jian）
		var 类型: String = 配方ID.substr(0, 配方ID.find("_"))
		系数 = float(武器系数.get(类型, 1.0))
	else:
		系数 = float(部位系数.get(穿戴位, 0.7))
	return int(基础 * 系数)

## 执行炼器（支持弟子技能影响和品质随机）
## 返回：{成功, 产出装备(Item/null), 消耗材料, 原因, 品质, 获得经验, 器灵觉醒}
static func 炼器(配方ID: String, 背包: Array, 器堂等级: int = 1, 炼器弟子 = null, 炼器经验值: int = 0, 因子: Variant = null) -> Dictionary:
	var 检查 = 检查材料(配方ID, 背包)
	if not 检查["足够"]:
		return {"成功": false, "产出": null, "消耗": [], "原因": 检查.get("原因", "材料不足"), "品质": "普通"}
	var 配方 = 获取配方(配方ID)
	# 计算成功率：基础 + 器堂等级加成（每级+2%）+ 炼器等级加成 + 弟子炼器技能加成
	var 炼器加成: Dictionary = 获取炼器加成(炼器经验值)
	var 因子2: Dictionary = {}
	if 因子 != null and typeof(因子) == TYPE_DICTIONARY:
		因子2 = 因子 as Dictionary
	# S42 炼器因子网络：铸匠人因子 + 器堂/图谱/气运（通过 因子 传入）
	var 成功率: float = float(配方.get("基础成功率", 50)) + float(max(0, 器堂等级 - 1)) * 2.0 + float(炼器加成["成功率加成"]) + float(因子2.get("成率", 0.0))
	# 弟子炼器技能加成（如果有炼器弟子）
	if 炼器弟子 != null and typeof(炼器弟子) == TYPE_OBJECT:
		var 炼器技能 = 0
		if "炼器等级" in 炼器弟子:
			炼器技能 = int(炼器弟子.炼器等级)
		成功率 += float(炼器技能) * 0.5  # 每级炼器技能+0.5%成功率
		# 弟子心境影响
		var 心境 = ""
		if "心境" in 炼器弟子:
			心境 = str(炼器弟子.心境)
		elif 炼器弟子.has_method("get"):
			心境 = str(炼器弟子.get("心境", ""))
		if 心境 == "专注":
			成功率 += 5.0
		elif 心境 == "浮躁":
			成功率 -= 5.0
	成功率 = clampf(成功率, 5.0, 95.0)
	# 消耗材料
	var 消耗列表: Array = []
	for mat in 配方["材料"]:
		var 需求名: String = str(mat["名"])
		var 需求数: int = int(mat["数量"])
		var 已消耗: int = 0
		for i in range(背包.size() - 1, -1, -1):
			if 已消耗 >= 需求数:
				break
			var item = 背包[i]
			if item != null and typeof(item) == TYPE_OBJECT and "名称" in item and str(item.名称) == 需求名:
				消耗列表.append(item)
				背包.remove_at(i)
				已消耗 += 1
	# 成功率判定
	if randf() * 100.0 > 成功率:
		# 失败补偿：30%概率返还一半材料，70%概率获得装备碎片
		var 补偿文本: String = ""
		if randf() < 0.30:
			# 返还一半材料
			for mat in 消耗列表.duplicate():
				if randf() < 0.5:
					背包.append(mat)
					消耗列表.erase(mat)
			补偿文本 = "，部分材料已返还"
		else:
			# 获得装备碎片（根据配方品阶）
			var 碎片品阶: String = str(配方.get("品阶", "凡阶"))
			var 碎片ID: String = "frag_equip_" + 碎片品阶
			# 这里简化处理，实际应该添加到碎片库存
			补偿文本 = "，获得%s碎片×1" % 碎片品阶
		var 获得经验: int = 计算炼器经验(str(配方.get("品阶", "凡阶")), false)
		return {"成功": false, "产出": null, "消耗": 消耗列表, "原因": "炼器失败，材料已消耗（成功率%.0f%%）%s" % [成功率, 补偿文本], "品质": "普通", "获得经验": 获得经验, "器灵觉醒": false}
	# 成功，产出装备
	var 新品 = Item.new()
	新品.类别 = str(配方.get("产出类别", "fa_qi"))
	新品.品阶 = str(配方.get("品阶", "凡阶"))
	新品.穿戴位 = str(配方.get("产出穿戴位", "wuqi"))
	if 配方.has("产出道途"):
		新品.道途 = str(配方["产出道途"])
	新品.名称 = str(配方.get("产出名", "未知装备"))
	新品.功效 = str(配方.get("描述", ""))
	新品.描述 = str(配方.get("描述", ""))
	# P0-3 装备本体数据接入：从equip_main.csv匹配基础属性
	var 装备模板: Dictionary = 匹配装备模板(新品.品阶, 新品.穿戴位, 新品.道途)
	if not 装备模板.is_empty():
		新品.基础攻击 = int(装备模板.get("base_atk", 0))
		新品.基础防御 = int(装备模板.get("base_def", 0))
		新品.基础气血 = int(装备模板.get("base_hp", 0))
		新品.基础耐久 = int(装备模板.get("base_durability", 0))
		新品.装备模板ID = str(装备模板.get("equip_id", ""))
	# P2 装备战力加成差异化（不同武器类型和装备部位有不同战力）
	# P0-3：战力 = 基础攻击×0.4 + 基础防御×0.3 + 基础气血×0.3（加权计算）
	var 基础战力: int = 0
	if 新品.基础攻击 > 0 or 新品.基础防御 > 0 or 新品.基础气血 > 0:
		基础战力 = int(新品.基础攻击 * 0.4 + 新品.基础防御 * 0.3 + 新品.基础气血 * 0.3)
	else:
		基础战力 = 计算装备战力(新品.品阶, 新品.穿戴位, 配方ID)
	# P3 器纹系统：炼器成功时掷器纹
	var 器纹等级: int = 掷器纹(新品.品阶, 器堂等级, float(因子2.get("出纹", 0.0)))
	新品.器纹 = 器纹等级
	# 器纹战力加成：每级+5%战力
	新品.战力加成 = int(基础战力 * 器纹战力加成(器纹等级))
	# 滚词缀（品阶决定词缀数量）
	新品.滚词缀()
	新品.滚极品()
	# 套装概率：宝阶及以上15%概率生成套装件
	if 新品.品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"] and randf() < 0.15:
		新品.套装ID = Item.套装库.keys().pick_random()
	# 祭炼上限按品阶
	新品.祭炼上限 = {"凡阶":5, "灵阶":6, "宝阶":7, "王阶":8, "圣阶":9, "仙阶":10, "道阶":10}.get(新品.品阶, 5)
	# 炼器品质随机（S42：高品质偏移由 因子.高品质 + 炼器等级.高品质加成 驱动）
	var 品阶概率 = 品质概率.get(新品.品阶, 品质概率["凡阶"])
	var 品质偏移: float = clamp(float(因子2.get("高品质", 0.0)) + float(炼器加成.get("高品质加成", 0.0)), -0.5, 0.5)
	var 随机值 = clamp(randf() + 品质偏移, 0.0, 1.0)
	var 累计概率 = 0.0
	var 炼器品质 = "普通"
	for 品质 in 品质列表:
		累计概率 += float(品阶概率.get(品质, 0))
		if 随机值 <= 累计概率:
			炼器品质 = 品质
			break
	# 弟子炼器技能提升高品质概率
	if 炼器弟子 != null and typeof(炼器弟子) == TYPE_OBJECT:
		var 炼器技能 = 0
		if "炼器等级" in 炼器弟子:
			炼器技能 = int(炼器弟子.炼器等级)
		# 每10级炼器技能，品质提升一档
		if 炼器技能 >= 30 and 炼器品质 == "普通":
			炼器品质 = "精良"
		elif 炼器技能 >= 50 and 炼器品质 == "精良":
			炼器品质 = "极品"
		elif 炼器技能 >= 80 and 炼器品质 == "极品":
			炼器品质 = "传说"
	# 应用品质加成
	var 品质系数 = float(品质加成.get(炼器品质, 1.0))
	新品.品质 = 炼器品质
	# 战力加成受品质影响
	新品.算战力()
	if "战力加成" in 新品:
		新品.战力加成 = int(新品.战力加成 * 品质系数)
	# 名称前缀
	if 炼器品质 != "普通":
		新品.名称 = "[%s]%s" % [炼器品质, 新品.名称]
	# 器灵觉醒：宝阶及以上5%概率触发器灵觉醒，装备获得额外属性
	var 器灵觉醒: bool = false
	if 新品.品阶 in ["宝阶", "王阶", "圣阶", "仙阶", "道阶"] and randf() < 0.05:
		器灵觉醒 = true
		新品.战力加成 = int(新品.战力加成 * 1.3)  # 器灵觉醒装备战力+30%
		新品.名称 = "【器灵】" + 新品.名称
	# 计算获得经验
	var 获得经验: int = 计算炼器经验(str(配方.get("品阶", "凡阶")), true)
	背包.append(新品)
	var 原因文本: String = "炼器成功！获得%s（品质：%s，成功率%.0f%%）" % [新品.名称, 炼器品质, 成功率]
	if 器灵觉醒:
		原因文本 += "，器灵觉醒！"
	return {"成功": true, "产出": 新品, "消耗": 消耗列表, "原因": 原因文本, "品质": 炼器品质, "获得经验": 获得经验, "器灵觉醒": 器灵觉醒}
