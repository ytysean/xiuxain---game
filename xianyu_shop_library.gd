extends RefCounted
class_name XianyuShop

# 仙玉商店内容库（机制数据驱动；不新增 CSV，避开 csv_validator 摩擦；扩礼包仅加 const 条目）
# 注：数值均为 [PLACEHOLDER]，待真机平衡校准（S1 竖切内容）。

# 月卡价：非绑定仙玉价（§12 / §11.20.6）
const 月卡价: int = 30

# 仙玉兑换表：每次消耗 10 仙玉，按类型给出兑换率与每日上限
# 数值为 PLACEHOLDER，待真机平衡校准（S1 竖切内容）
const 仙玉兑换表: Dictionary = {
	"灵石": {"率": 100, "日上限": 1000},
	"战功": {"率": 10, "日上限": 500},
	"传承积分": {"率": 5, "日上限": 200},
	"宗门贡献": {"率": 20, "日上限": 300},
}

# 限时礼包：id 唯一；cost=非绑定仙玉（玩家侧显示为「仙玉」）；rewards 发放项（灵石/灵气/灵草/矿石/绑定仙玉/声望）
const 限时礼包库: Array = [
	{
		"id": "pkg_starter", "name": "新秀礼包", "cost": 6,
		"rewards": {"灵石": 500, "绑定仙玉": 30},
		"desc": "初入宗门的新秀补给：少量灵石与供奉绑定仙玉。",
	},
	{
		"id": "pkg_cult", "name": "修行礼包", "cost": 30,
		"rewards": {"灵气": 300, "灵草": 50},
		"desc": "助弟子精进修为的灵气与灵草补给。",
	},
	{
		"id": "pkg_sect", "name": "宗门兴隆礼包", "cost": 68,
		"rewards": {"灵石": 2000, "矿石": 100, "声望": 50},
		"desc": "助宗门大兴的资粮、矿石与声望。",
	},
]

static func 取礼包(id: String) -> Dictionary:
	for p in 限时礼包库:
		if p.get("id", "") == id:
			return p
	return {}

# === S1 竖切：仙玉商品商店（06 屏坊市）===
# 分类与商品库；数值 / 奖励均为 PLACEHOLDER，供真机平衡与视觉验证。
const 分类列表: Array = ["推荐", "灵宝", "功法", "灵兽", "外观"]

const 商品库: Array = [
	{
		"id": "tower_featured",
		"name": "九霄玲珑塔",
		"category": "灵宝",
		"grade": "道品",
		"desc": "镇派至宝 · 道品",
		"price": 128,
		"original_price": 648,
		"icon": "res://assets/ui/icons/fabao.svg",
		"rewards": {"皮肤": "jiuxiao_tower"},
	},
	{
		"id": "xuantie_sword",
		"name": "玄铁重剑",
		"category": "灵宝",
		"grade": "凡品",
		"desc": "攻击 +128 · 凡品",
		"price": 128,
		"original_price": 0,
		"icon": "res://assets/ui/icons/zhuangbei.svg",
		"rewards": {"灵石": 1000},
	},
	{
		"id": "ningyuan_dan",
		"name": "凝元丹",
		"category": "灵宝",
		"grade": "灵品",
		"desc": "修为 +5000 · 灵品",
		"price": 88,
		"original_price": 0,
		"icon": "res://assets/ui/icons/danyao.svg",
		"rewards": {"灵气": 5000},
	},
	{
		"id": "yufeng_jue",
		"name": "御风诀",
		"category": "功法",
		"grade": "宝品",
		"desc": "身法 +60 · 宝品",
		"price": 268,
		"original_price": 0,
		"icon": "res://assets/ui/icons/gongfa.svg",
		"rewards": {"声望": 60},
	},
	{
		"id": "chiyan_egg",
		"name": "赤焰灵兽蛋",
		"category": "灵兽",
		"grade": "圣品",
		"desc": "灵兽 · 赤焰兽",
		"price": 520,
		"original_price": 0,
		"icon": "res://assets/ui/icons/lingshou.svg",
		"rewards": {"灵草": 200},
	},
	{
		"id": "jiuxiao_tower",
		"name": "九霄玲珑塔",
		"category": "灵宝",
		"grade": "道品",
		"desc": "镇派至宝 · 道品",
		"price": 1288,
		"original_price": 0,
		"icon": "res://assets/ui/icons/fabao.svg",
		"rewards": {"皮肤": "jiuxiao_tower"},
	},
	# ==================== 碎片宝箱商品 ====================
	{
		"id": "frag_equip_common_pack",
		"name": "凡品装备碎片包",
		"category": "灵宝",
		"grade": "凡品",
		"desc": "凡品装备碎片×5",
		"price": 30,
		"original_price": 0,
		"icon": "res://assets/ui/icons/zhuangbei.svg",
		"rewards": {"frag_equip_common": 5},
	},
	{
		"id": "frag_equip_rare_pack",
		"name": "灵品装备碎片包",
		"category": "灵宝",
		"grade": "灵品",
		"desc": "灵品装备碎片×5",
		"price": 88,
		"original_price": 0,
		"icon": "res://assets/ui/icons/zhuangbei.svg",
		"rewards": {"frag_equip_rare": 5},
	},
	{
		"id": "frag_gongfa_rare_pack",
		"name": "灵品功法碎片包",
		"category": "功法",
		"grade": "灵品",
		"desc": "灵品功法碎片×5",
		"price": 68,
		"original_price": 0,
		"icon": "res://assets/ui/icons/gongfa.svg",
		"rewards": {"frag_gongfa_rare": 5},
	},
	{
		"id": "chest_common_pack",
		"name": "普通宝箱",
		"category": "灵宝",
		"grade": "凡品",
		"desc": "普通宝箱×1，内含基础资源与碎片",
		"price": 50,
		"original_price": 0,
		"icon": "res://assets/ui/icons/fabao.svg",
		"rewards": {"chest_common": 1},
	},
	{
		"id": "chest_rare_pack",
		"name": "稀有宝箱",
		"category": "灵宝",
		"grade": "灵品",
		"desc": "稀有宝箱×1，内含较好资源与碎片",
		"price": 128,
		"original_price": 0,
		"icon": "res://assets/ui/icons/fabao.svg",
		"rewards": {"chest_rare": 1},
	},
	{
		"id": "chest_epic_pack",
		"name": "史诗宝箱",
		"category": "灵宝",
		"grade": "宝品",
		"desc": "史诗宝箱×1，内含珍贵资源与碎片",
		"price": 328,
		"original_price": 0,
		"icon": "res://assets/ui/icons/fabao.svg",
		"rewards": {"chest_epic": 1},
	},
]

static func 取商品(id: String) -> Dictionary:
	for p in 商品库:
		if p.get("id", "") == id:
			return p.duplicate()
	return {}

static func 取限时特惠() -> Dictionary:
	for p in 商品库:
		if int(p.get("original_price", 0)) > 0:
			return p.duplicate()
	return {}

static func 取分类商品(category: String) -> Array:
	if category == "推荐":
		return 商品库.duplicate()
	var list: Array = []
	for p in 商品库:
		if p.get("category", "") == category:
			list.append(p.duplicate())
	return list
