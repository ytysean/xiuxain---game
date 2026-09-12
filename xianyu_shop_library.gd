extends RefCounted
class_name XianyuShop

# 仙玉商店内容库（机制数据驱动；不新增 CSV，避开 csv_validator 摩擦；扩礼包仅加 const 条目）
# P0优化：修正商品名称与奖励匹配，增加护道人道具、机缘道具

# 月卡价：非绑定仙玉价（§12 / §11.20.6）
const 月卡价: int = 30

# 仙玉兑换表：每次消耗 10 仙玉，按类型给出兑换率与每日上限
const 仙玉兑换表: Dictionary = {
	"灵石": {"率": 100, "日上限": 1000},
	"战功": {"率": 10, "日上限": 500},
	"传承积分": {"率": 5, "日上限": 200},
	"宗门贡献": {"率": 20, "日上限": 300},
}

# 限时礼包：id 唯一；cost=非绑定仙玉（玩家侧显示为「仙玉」）；rewards 发放项
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
	{
		"id": "pkg_hudao", "name": "护道人礼包", "cost": 98,
		"rewards": {"护道玉符": 1, "护道续缘符": 2, "功德玉牌": 1},
		"desc": "护道人专属补给：护道玉符、续缘符、功德玉牌。",
	},
	{
		"id": "pkg_jiyuan", "name": "机缘礼包", "cost": 68,
		"rewards": {"机缘符": 3, "悟道令": 1},
		"desc": "增加每日机缘次数：机缘符×3、悟道令×1。",
	},
]

static func 取礼包(id: String) -> Dictionary:
	for p in 限时礼包库:
		if p.get("id", "") == id:
			return p
	return {}

# === 仙玉商品商店（坊市·仙玉商店）===
# 分类与商品库；P1优化：增加VIP经验丹、更多丹药/符箓
const 分类列表: Array = ["推荐", "灵宝", "功法", "灵兽", "护道", "机缘", "VIP", "符箓", "外观"]

const 商品库: Array = [
	# ==================== 灵宝类 ====================
	{
		"id": "tower_featured",
		"name": "九霄玲珑塔",
		"category": "灵宝",
		"grade": "道品",
		"desc": "镇派至宝 · 道品，宗门外观专属",
		"price": 128,
		"original_price": 648,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"皮肤": "jiuxiao_tower"},
	},
	{
		"id": "ningyuan_dan",
		"name": "凝元丹",
		"category": "灵宝",
		"grade": "灵品",
		"desc": "辅助修炼的灵丹，服用后灵气+5000",
		"price": 88,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"灵气": 5000},
	},
	{
		"id": "juqi_dan",
		"name": "聚气丹",
		"category": "灵宝",
		"grade": "凡品",
		"desc": "基础修炼丹药，服用后灵气+1000",
		"price": 30,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"灵气": 1000},
	},
	{
		"id": "peiyuan_dan",
		"name": "培元丹",
		"category": "灵宝",
		"grade": "宝品",
		"desc": "固本培元的珍贵丹药，服用后灵气+20000",
		"price": 268,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"灵气": 20000},
	},
	# ==================== 功法类 ====================
	{
		"id": "yufeng_jue",
		"name": "御风诀",
		"category": "功法",
		"grade": "宝品",
		"desc": "身法功法，学习后闪避+60，宗门贡献+200",
		"price": 268,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"宗门贡献": 200},
	},
	{
		"id": "taiyi_jue",
		"name": "太一经",
		"category": "功法",
		"grade": "仙品",
		"desc": "玄门正宗功法，学习后全属性+100，传承积分+100",
		"price": 648,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"传承积分": 100},
	},
	# ==================== 灵兽类 ====================
	{
		"id": "chiyan_egg",
		"name": "赤焰灵兽蛋",
		"category": "灵兽",
		"grade": "圣品",
		"desc": "赤焰兽之蛋，孵化后获得赤焰兽，灵草+200",
		"price": 520,
		"original_price": 0,
		"icon": "res://art/characters/beasts/beast_lintu_36.png",
		"rewards": {"灵草": 200},
	},
	{
		"id": "hanbing_egg",
		"name": "寒冰灵兽蛋",
		"category": "灵兽",
		"grade": "仙品",
		"desc": "寒冰兽之蛋，孵化后获得寒冰兽，灵气+1000",
		"price": 328,
		"original_price": 0,
		"icon": "res://art/characters/beasts/beast_lintu_36.png",
		"rewards": {"灵气": 1000},
	},
	# ==================== VIP类（P1新增）====================
	{
		"id": "vip_dan_small",
		"name": "VIP经验丹（小）",
		"category": "VIP",
		"grade": "灵品",
		"desc": "增加累充额10元，加速VIP等级提升",
		"price": 100,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"VIP经验": 10},
	},
	{
		"id": "vip_dan_medium",
		"name": "VIP经验丹（中）",
		"category": "VIP",
		"grade": "宝品",
		"desc": "增加累充额60元，加速VIP等级提升",
		"price": 500,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"VIP经验": 60},
	},
	{
		"id": "vip_dan_large",
		"name": "VIP经验丹（大）",
		"category": "VIP",
		"grade": "仙品",
		"desc": "增加累充额128元，加速VIP等级提升",
		"price": 1000,
		"original_price": 0,
		"icon": "res://art/icons/equipment/danyao_fan.png",
		"rewards": {"VIP经验": 128},
	},
	# ==================== 符箓类（P1新增）====================
	{
		"id": "fu_hushen",
		"name": "护身符",
		"category": "符箓",
		"grade": "灵品",
		"desc": "战斗中防御+20%，持续5回合，库房+3张",
		"price": 68,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"符箓_护身符": 3},
	},
	{
		"id": "fu_gongji",
		"name": "攻击符",
		"category": "符箓",
		"grade": "灵品",
		"desc": "战斗中攻击+20%，持续5回合，库房+3张",
		"price": 68,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"符箓_攻击符": 3},
	},
	{
		"id": "fu_zhiliao",
		"name": "治疗符",
		"category": "符箓",
		"grade": "宝品",
		"desc": "战斗中恢复30%生命，库房+3张",
		"price": 88,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"符箓_治疗符": 3},
	},
	{
		"id": "fu_dunzhe",
		"name": "遁者符",
		"category": "符箓",
		"grade": "宝品",
		"desc": "历练失败时概率逃脱，库房+3张",
		"price": 128,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"符箓_遁者符": 3},
	},
	# ==================== 护道人类（P0新增）====================
	{
		"id": "hudao_yufu",
		"name": "护道玉符",
		"category": "护道",
		"grade": "宝品",
		"desc": "召唤一名护道人，为天才弟子保驾护航",
		"price": 198,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"护道玉符": 1},
	},
	{
		"id": "hudao_xuyuan",
		"name": "护道续缘符",
		"category": "护道",
		"grade": "灵品",
		"desc": "延长护道人保护时间365日",
		"price": 68,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"护道续缘符": 1},
	},
	{
		"id": "hudao_gongde",
		"name": "功德玉牌",
		"category": "护道",
		"grade": "灵品",
		"desc": "增加护道人功德200，加速护道人晋升",
		"price": 88,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"功德玉牌": 1},
	},
	{
		"id": "hudao_qiyun",
		"name": "气运符箓",
		"category": "护道",
		"grade": "宝品",
		"desc": "临时提升护道人效果20%，持续7日",
		"price": 128,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"气运符箓": 1},
	},
	{
		"id": "hudao_tisi",
		"name": "替死玉符",
		"category": "护道",
		"grade": "仙品",
		"desc": "确保一次危机救援成功，弟子濒死时护道人倾力相救",
		"price": 328,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"替死玉符": 1},
	},
	# ==================== 机缘类（P0新增）====================
	{
		"id": "jiyuan_fu",
		"name": "机缘符",
		"category": "机缘",
		"grade": "灵品",
		"desc": "增加当日所有机缘次数+1（探秘境缘/游历机缘/历练机缘等）",
		"price": 30,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"机缘符": 1},
	},
	{
		"id": "wudao_ling",
		"name": "悟道令",
		"category": "机缘",
		"grade": "宝品",
		"desc": "增加当日所有机缘次数+3，珍稀悟道令牌",
		"price": 88,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"悟道令": 1},
	},
	{
		"id": "tianji_fu",
		"name": "天机符",
		"category": "机缘",
		"grade": "仙品",
		"desc": "增加当日所有机缘次数+10，窥探天机的神符",
		"price": 268,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
		"rewards": {"天机符": 1},
	},
	# ==================== 外观类 ====================
	{
		"id": "jiuxiao_tower",
		"name": "九霄玲珑塔",
		"category": "外观",
		"grade": "道品",
		"desc": "镇派至宝外观 · 道品，宗门专属外观",
		"price": 1288,
		"original_price": 0,
		"icon": "res://art/icons/equipment/fabao_fan.png",
		"rewards": {"皮肤": "jiuxiao_tower"},
	},
	# ==================== 碎片宝箱类 ====================
	{
		"id": "frag_equip_common_pack",
		"name": "凡品装备碎片包",
		"category": "灵宝",
		"grade": "凡品",
		"desc": "凡品装备碎片×5，可用于合成凡品装备",
		"price": 30,
		"original_price": 0,
		"icon": "res://art/icons/equipment/faqi_fan.png",
		"rewards": {"frag_equip_common": 5},
	},
	{
		"id": "frag_equip_rare_pack",
		"name": "灵品装备碎片包",
		"category": "灵宝",
		"grade": "灵品",
		"desc": "灵品装备碎片×5，可用于合成灵品装备",
		"price": 88,
		"original_price": 0,
		"icon": "res://art/icons/equipment/faqi_fan.png",
		"rewards": {"frag_equip_rare": 5},
	},
	{
		"id": "frag_gongfa_rare_pack",
		"name": "灵品功法碎片包",
		"category": "功法",
		"grade": "灵品",
		"desc": "灵品功法碎片×5，可用于合成灵品功法",
		"price": 68,
		"original_price": 0,
		"icon": "res://art/icons/skill/skill_taichu_36.png",
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
		"icon": "res://art/icons/equipment/fabao_fan.png",
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
		"icon": "res://art/icons/equipment/fabao_fan.png",
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
		"icon": "res://art/icons/equipment/fabao_fan.png",
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
