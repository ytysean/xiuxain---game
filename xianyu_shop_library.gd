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
		"icon": "res://art/icons/resource/res_lingshi_36.png",
		"rewards": {"灵石": 500, "绑定仙玉": 30},
		"desc": "初入宗门的新秀补给：少量灵石与供奉绑定仙玉。",
	},
	{
		"id": "pkg_cult", "name": "修行礼包", "cost": 30,
		"icon": "res://art/icons/resource/res_lingqi_36.png",
		"rewards": {"灵气": 300, "灵草": 50},
		"desc": "助弟子精进修为的灵气与灵草补给。",
	},
	{
		"id": "pkg_sect", "name": "宗门兴隆礼包", "cost": 68,
		"icon": "res://art/icons/resource/res_kuangshi_36.png",
		"rewards": {"灵石": 2000, "矿石": 100, "声望": 50},
		"desc": "助宗门大兴的资粮、矿石与声望。",
	},
	{
		"id": "pkg_hudao", "name": "护道人礼包", "cost": 98,
		"icon": "res://art/icons/resource/talisman_zhaohuan_512.png",
		"rewards": {"护道玉符": 1, "护道续缘符": 2, "功德玉牌": 1},
		"desc": "护道人专属补给：护道玉符、续缘符、功德玉牌。",
	},
	{
		"id": "pkg_jiyuan", "name": "机缘礼包", "cost": 68,
		"icon": "res://art/icons/resource/item_xingyun_fu_512.png",
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
# 分类与商品库；P1优化：增加客卿玉牒、更多丹药/符箓
const 分类列表: Array = ["推荐", "灵宝", "功法", "灵兽", "护道", "机缘", "客卿", "符箓", "外观"]

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
		"icon": "res://art/icons/equipment/fabao_dao.png",
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
		"icon": "res://art/icons/resource/pill_ningjin_512.png",
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
		"icon": "res://art/icons/resource/pill_juqi_512.png",
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
		"icon": "res://art/icons/resource/pill_guyuan_512.png",
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
		"icon": "res://art/icons/skill/skill_daoxiu_02_512.png",
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
		"icon": "res://art/icons/skill/skill_daoxiu_05_512.png",
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
		"icon": "res://art/characters/beasts/beast_egg_sheng_512.png",
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
		"icon": "res://art/characters/beasts/beast_egg_xian_512.png",
		"rewards": {"灵气": 1000},
	},
	# ==================== 客卿类（原「VIP 类」· 2026-09-15 文案修真化）====================
	# ★ 老大：「坊市里还有 VIP 字样，这个不符合修真世界」。
	#   「VIP」是典型现代词 ⇒ 改为**客卿**：宗门语境里客卿是受特别礼遇的正式身份，
	#   与"弟子 / 长老 / 宗主"同一套身份语义体系，玩家一看就懂。
	# 注意：**分类名与下面的 category 字段必须同步改** —— 取分类商品() 是按 category 精确匹配的，
	#   只改一个会导致该 Tab 点进去空白。
	# 另外「累充额 xx 元」是充值金额，属通用数值表达 —— 老大 2026-09-16 裁决：
	#   数值一律沿用手游通用做法（阿拉伯数字+%），不做「增三成」式中换算。
	# ⚠ rewards 键 "VIP经验" 是**内部数据契约**（被 购买仙玉商品() 消费），保持不变 ——
	#   它不出现在任何玩家可见文案里，改了反而会断掉结算。
	{
		"id": "vip_dan_small",
		"name": "客卿玉牒·下品",
		"category": "客卿",
		"grade": "灵品",
		"desc": "记入客卿功缘十缕，助客卿品阶擢升",
		"price": 100,
		"original_price": 0,
		"icon": "res://art/icons/resource/item_jingyan_dan_512.png",
		"rewards": {"VIP经验": 10},
	},
	{
		"id": "vip_dan_medium",
		"name": "客卿玉牒·中品",
		"category": "客卿",
		"grade": "宝品",
		"desc": "记入客卿功缘六十缕，助客卿品阶擢升",
		"price": 500,
		"original_price": 0,
		"icon": "res://art/icons/resource/item_jingyan_dan_512.png",
		"rewards": {"VIP经验": 60},
	},
	{
		"id": "vip_dan_large",
		"name": "客卿玉牒·上品",
		"category": "客卿",
		"grade": "仙品",
		"desc": "记入客卿功缘百二十八缕，助客卿品阶擢升",
		"price": 1000,
		"original_price": 0,
		"icon": "res://art/icons/resource/item_jingyan_dan_512.png",
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
		"icon": "res://art/icons/resource/talisman_fangyu_512.png",
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
		"icon": "res://art/icons/resource/talisman_gongji_512.png",
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
		"icon": "res://art/icons/resource/talisman_zhiliao_512.png",
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
		"icon": "res://art/icons/resource/talisman_chuansong_512.png",
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
		"icon": "res://art/icons/resource/talisman_zhaohuan_512.png",
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
		"icon": "res://art/icons/resource/talisman_jiasu_512.png",
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
		"icon": "res://art/icons/equipment/fabao_ling.png",
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
		"icon": "res://art/icons/resource/talisman_zengyi_512.png",
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
		"icon": "res://art/icons/resource/talisman_yinshen_512.png",
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
		"icon": "res://art/icons/resource/item_xingyun_fu_512.png",
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
		"icon": "res://art/icons/resource/item_wudao_cha_512.png",
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
		"icon": "res://art/icons/resource/talisman_fengyin_512.png",
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
		"icon": "res://art/icons/equipment/fabao_dao.png",
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
		"icon": "res://art/icons/equipment/faqi_ling.png",
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
		"icon": "res://art/icons/skill/skill_daoxiu_03_512.png",
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
		"icon": "res://art/icons/equipment/fabao_ling.png",
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
		"icon": "res://art/icons/equipment/fabao_bao.png",
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

## ★ 2026-09-15 新增（老大：「最上方的远古传承玉简怎么一直置顶…能增加更多特价物品更好了，
##   可以花仙玉刷新。现在没有图标，只有一个钻石样式的 emoji」）
##
## 「每日特供」= 从仙缘阁**自己的**商品库按游戏日确定性轮换抽 N 件。
##
## 为什么推翻原来的 Game.获取商城每日特惠() 链路（三条真因，逐条实测）：
##   ① 数据源是 config/faction_shop.csv = **阵营声望商店**（灵石计价 + 声望门槛），
##      与「仙缘阁 = 仙玉商城」语义错位 —— 所以会冒出「远古传承玉简」这种阵营至高道具；
##   ② 它按 `shop_id` 去重，而该表列名是 `item_id` ⇒ 去重键恒为 ""，第二件起全被 continue
##      ⇒ **永远只出一件**（这正是老大看到的「一直置顶」）；
##   ③ 它读 `price_lingjing`，该表列名是 `price` ⇒ **价格恒 0**（老大看到的「◇ 0」）。
##   ④ emoji 是硬编码的 `"◇ %d"` 前缀，与商品毫无对应。
##
## 本函数改从 `商品库` 取 —— 该库每条自带 id/name/price/original_price/icon/desc/grade，
## 图标与价格天然齐备，无需再补任何字段。
##
## 确定性洗牌：**同一天多次进入商店结果稳定**（不会"一刷新页面就换货"，那是廉价手游的坏味道），
## 跨游戏日自动换一批；`偏移` 由「仙玉刷新」递增，让玩家付费换一批。seed 与 日/偏移 绑定，可复现、不必存档。
static func 取每日特供(日: int, 数量: int = 4, 偏移: int = 0) -> Array:
	var 池: Array = []
	for p in 商品库:
		池.append(p.duplicate())
	if 池.is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A17C3 ^ (日 * 2654435761) ^ (偏移 * 40503)
	# Fisher-Yates：rng 由 seed 驱动，同参数必得同序列 ⇒ 确定性轮换
	for i in range(池.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = 池[i]
		池[i] = 池[j]
		池[j] = tmp
	return 池.slice(0, mini(数量, 池.size()))
