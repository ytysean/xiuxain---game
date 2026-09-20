class_name CaravanSystem
extends RefCounted

# 商队系统 - 从game_state.gd拆分
# 包含：商队派遣/结算、灵舟坞、黑市、商路竞争、行情事件

# ===== 商队系统状态变量 =====
# ===== 商队派遣系统 =====
var 商队列表: Array = []  # 正在派遣的商队列：[{id, 地区, 出发日 预计返回日 货物, 弟子ID, 状态}]
var 商队历史: Array = []  # 商队历史记录
var 商队岗位表: Dictionary = {}  # S2 商路贸易：岗位配置（caravan_post_config.csv，表格驱动零硬编码）
var 商队载具表: Dictionary = {}  # S2 商路贸易：载具配置（caravan_vehicle_config.csv，表格驱动零硬编码）
var 商队地区: Array = []        # §11.15 数据驱动：运行时从 city_config.csv 装载派生（删除内联常量）
var 商队城市表: Dictionary = {}  # §11.15 数据驱动：city_id(String)→城市配置(dict)
var 商队商路表: Dictionary = {}  # §11.15 数据驱动：route_id(String)→商路配置(dict)
var 商队商品表: Dictionary = {}  # §11.15 数据驱动：goods_id(String)→商品配置(dict)
var 商队事件库: Array = []       # §11.15 数据驱动：trade_event_config 事件列表(Array[dict])
var 商队ID计数器: int= 0
var 累计贸易次数: int = 0          # 累计贸易结算次数（成就用）
var 累计贸易收益: int = 0          # 累计贸易结算收益（成就用）
# §11.15 优化：现实时间贸易模型（不升SAVE_VERSION，旧档缺键→默认零回归）
#   单次贸易 = 现实 6 小时（21600 秒）后结算；每日配额按现实日重置；月卡/季卡/永久卡 +1 次/日
var 商队每日已派: int = 0
var 上次配额日真实秒: int = 0
# §11.20 修复：行情刷新按现实日节流（原每次推演一月都刷新 → 1真实天≈360次，供需系数+0.02/次瞬间回满，压价机制失效）
var 上次行情日真实秒: int = 0
const 商队单次贸易现实秒: int = 21600   # 6 小时
# §11.15 优化：贸易现实时间加速体系——多途径缩短单次贸易现实耗时
const 贸易最短时间系数: float = 0.2       # 现实耗时封顶：最快≈72分钟（不破坏长途贸易感）
const 神行符_ID: String = "g048"
const 神行符名: String = "神行符"
const 神行符加速: float = 0.3             # 使用1张神行符：-30%时间（系数÷1.3）
const 仙玉即时完成费: int = 30            # 仙玉即时完成本次贸易的仙玉消耗（游戏内货币，不破经济红线）
const 阵法堂航速每级: float = 0.02        # 阵法堂司职每级 +2% 航速（满10级 +20%）
const 声望航速每500: float = 0.03         # 商队总声望每 500 +3% 航速
const 声望航速上限: float = 0.20          # 声望航速被动封顶 +20%
# §11.15 阶段三（黑市/灵舟/NPC商队竞争）：灵舟坞/黑市禁闭/竞争状态（不升SAVE_VERSION，旧档缺键→默认零回归）
var 灵舟坞等级: int = 0            # 0=未建；≥1 即 has_ship 为真（解锁跨域城 7/8）
var 灵舟坞表: Dictionary = {}      # ship_dock_config.csv（sd01-06 飞舟坞，按等级解锁）
var 宗门灵舟表: Dictionary = {}    # sect_ship_config.csv（ss01-04 灵舟）
var 灵舟库存: Array = []          # 已建成灵舟：{ship_id,名称,tier,ship_type,durability,max_durability,speed_bonus,risk_reduce}
var 灵舟坞建造中: Dictionary = {}  # {目标档:int, 完成日:int}（非空中表示坞在建造/升级）
var 灵舟建造队列: Array = []      # 灵舟炼制队列：[{ship_id, 完成日}]
var 灵材名称表: Dictionary = {}    # goods_config 桥接：goods_id→中文名（扣材时按名遍历宗门库房）
var 灵舟阵法表: Dictionary = {}    # 灵舟阵法配置：formation_id→{name,category,tier,effect_dim,effect_val,cost_lingstone,cost_material,required_array_tier}
var 虚空大阵冷却日: int = 0        # 破虚神舰·虚空大阵 瞬移冷却（累计游戏日；>0 表示冷却中）
const 灵核品阶物品: Dictionary = {1:"g021", 2:"g022", 3:"g023", 4:"g024", 5:"g025"}  # 灵舟所需能量核心品阶→goods_id
var 黑市禁闭日: int = 0            # 黑市查缉命中后禁闭计时（天），>0 时不可黑市交易
var 商路竞争状态: Dictionary = {}  # 黄金商路 NPC 竞争：city_id→{强度, 压价率, 策略}
var 跨域风险事件: Array = [        # 跨域商路顶级风险（轻量 const；设计 §11.15 L4366）
	{"名": "跨海妖兽袭击", "损失min": 0.4, "损失max": 0.7, "额外扣": 0},
	{"名": "飓风暴浪", "损失min": 0.3, "损失max": 0.6, "额外扣": 0},
	{"名": "海盗截掠", "损失min": 0.5, "损失max": 0.8, "额外扣": 300},
	{"名": "灵舟灵能故障", "损失min": 0.2, "损失max": 0.5, "额外扣": 0},
]
# §11.20：trade_event_config.csv 未提供独立声望数值列，reputation 类事件按 比例×20 折算商路声望（0.5~1.0 → 10~20）
const 事件声望折算: float = 20.0
# §11.15 策略深度（Game.声望/行情）：商路声望(city_id→int，影响价差) 与 全局行情事件队列(独立，不污染 EventManager)
var 商路声望: Dictionary = {}
var 行情事件列表: Array = []
var 正道特许商品表: Array = []      # 黑市双线·正道特许商品（拆分补声明）
var 特殊商单表: Array = []          # 特殊商单（奖励物品化）
var 商品名_类型: Dictionary = {}    # 物品名→goods_type 反向映射
const 虚空瞬移仙玉费: int = 50      # 仙核/灵石不足时仙玉抵扣虚空瞬移
# ── 商道境界系统（经商玩法加强 P0：经商是宗门运转一部分，纯加乘区，不碰核心派遣/结算流程）──
var 商道经验: int = 0
var 商道境界: String = "初入行商"
const 商道境界表: Array = [
	{"境界": "初入行商", "所需经验": 0,    "价差加成": 0.0,  "风险减免": 0.0},
	{"境界": "老练商人", "所需经验": 500,  "价差加成": 0.05, "风险减免": 0.05},
	{"境界": "商道大家", "所需经验": 2000, "价差加成": 0.15, "风险减免": 0.15},
	{"境界": "富可敌国", "所需经验": 5000, "价差加成": 0.30, "风险减免": 0.30},
]
# §商道P2 商铺经营：分店放置产出（不升SAVE_VERSION，旧档缺键→默认空/初值）
var 商铺列表: Array = []  # [{城市ID, 类型, 等级, 主营}]
const 商铺配置: Dictionary = {
	"妖兽材铺": {"基础产出": 60, "主营": "妖兽材", "解锁境界": "初入行商"},
	"灵草铺": {"基础产出": 50, "主营": "灵草", "解锁境界": "老练商人"},
	"法器铺": {"基础产出": 80, "主营": "矿石", "解锁境界": "老练商人"},
	"丹药铺": {"基础产出": 120, "主营": "丹药", "解锁境界": "商道大家"},
	"符箓铺": {"基础产出": 100, "主营": "符箓", "解锁境界": "商道大家"},
	"奇珍阁": {"基础产出": 200, "主营": "稀有", "解锁境界": "富可敌国"},
}
const 商铺等级上限表: Dictionary = {"初入行商": 3, "老练商人": 5, "商道大家": 8, "富可敌国": 10}
# §商道P3 稀有商品表（捡漏收集；仅跨域/高风险商路+境界>=老练商人触发；全部概率 [PLACEHOLDER]）
const 稀有商品表: Array = [
	{"名": "上古玉璧", "品阶": "仙品", "概率": 0.001, "价值": 50000},
	{"名": "残破仙甲", "品阶": "仙品", "概率": 0.0005, "价值": 100000},
	{"名": "九转金丹", "品阶": "仙品", "概率": 0.0002, "价值": 200000},
	{"名": "残破仙剑", "品阶": "仙品", "概率": 0.0002, "价值": 200000},
	{"名": "万年灵参", "品阶": "王品", "概率": 0.005, "价值": 10000},
	{"名": "龙涎香", "品阶": "王品", "概率": 0.003, "价值": 8000},
	{"名": "凤凰羽", "品阶": "王品", "概率": 0.003, "价值": 8000},
	{"名": "麒麟角", "品阶": "王品", "概率": 0.002, "价值": 12000},
]
# ===== S57 玩家间交易（委托商队运输）=====
# 符合修真世界观：宗门间距离远，委托商队运输物品
var 玩家交易列表: Array = []          # 所有交易记录（按时间倒序）
var 玩家运输中列表: Array = []        # 正在运输中的交易
var 最大玩家交易记录: int = 100       # 最大保留交易记录数
# 运输方式配置
const 玩家运输配置: Dictionary = {
	"普通商队": {
		"费用比例": 0.03,      # 成交价3%
		"最低费用": 50,        # 最低50灵石
		"运输时间_min": 3,     # 最少3游戏日
		"运输时间_max": 7,     # 最多7游戏日
		"被劫风险": 0.30,      # 30%被劫风险
		"赔偿比例": 0.5,       # 被劫赔偿50%
		"描述": "普通商队，费用低廉，但路途遥远，有被劫道风险。",
	},
	"精锐商队": {
		"费用比例": 0.08,      # 成交价8%
		"最低费用": 200,       # 最低200灵石
		"运输时间_min": 1,     # 最少1游戏日
		"运输时间_max": 3,     # 最多3游戏日
		"被劫风险": 0.10,      # 10%被劫风险
		"赔偿比例": 0.8,       # 被劫赔偿80%
		"描述": "精锐商队，有修士护卫，费用较高，但快捷稳妥。",
	},
	"传送阵": {
		"费用比例": 0.0,       # 不按比例
		"灵晶费用": 10,        # 10灵晶
		"运输时间": 0,         # 实时送达
		"被劫风险": 0.0,       # 无风险
		"赔偿比例": 1.0,       # 全额赔偿
		"描述": "宗门传送阵，瞬息可达，万无一失，但需消耗灵晶。",
	},
}
# 交易状态
const 交易状态_待确认 = "待买家确认"
const 交易状态_运输中 = "运输中"
const 交易状态_待收货 = "待收货"
const 交易状态_已完成 = "已完成"
const 交易状态_已取消 = "已取消"
const 交易状态_已被劫 = "已被劫"
# §商道周常 贸易大赛（仿休闲玩法周常；本周计数按周序重置，上限3参与，威望走 Game.宗主威望 防通胀）
var 商道周常本周参与: int = 0
var 商道周常上周序: int = -1
var 商道周常本周稀有: bool = false
# §商道消耗品 sink（商道令提价差 / 通商符降时 / 拜帖解锁商单；走宗门库房，使用即扣）
const 商道消耗品配置: Dictionary = {
	"商道令": {"效果": "价差", "数值": 0.08, "价格": 200},
	"通商符": {"效果": "降时", "数值": 0.3, "价格": 150},
	"拜帖": {"效果": "商单", "数值": 0.0, "价格": 120},
}


# ===== 商队系统函数 =====
func 加载商队配置() -> void:
	商队岗位表 = _读商队岗位表()
	商队载具表 = _读商队载具表()
	# §11.15 数据驱动：装载 city/goods/route/event 四表
	商队商品表 = _读商品表()
	商队城市表 = _读城市表()
	商队商路表 = _读商路表()
	商队事件库 = _读商路事件表()
	# §11.15 阶段三：装载灵舟坞 / 宗门灵舟 两表（数据已备，原未装载）
	灵舟坞表 = _读灵舟坞表()
	宗门灵舟表 = _读宗门灵舟表()
	灵材名称表 = _读灵材名称表()   # goods_id→中文名 桥接（灵舟炼制按名扣宗门库房灵材）
	灵舟阵法表 = _读灵舟阵法表()   # §11.15 阶段三·灵舟：装载灵舟可刻录阵法配置
	# §11.15 优化#73/#74：装载正道特许商品表 / 特殊商单表
	正道特许商品表 = _读正道特许表()
	特殊商单表 = _读特殊商单表()
	# BUG-C 修复：构建 物品名→goods_type 反向映射（与地区偏好类别同源）
	商品名_类型 = {}
	for _gid in 商队商品表.keys():
		var _g = 商队商品表[_gid]
		var _n = str(_g.get("goods_name", ""))
		var _t = str(_g.get("goods_type", ""))
		if _n != "" and _t != "" and not 商品名_类型.has(_n):
			商品名_类型[_n] = _t
	_构建商队地区()

func _读商队岗位表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/caravan_post_config.csv", FileAccess.READ)
	if f == null:
		push_warning("caravan_post_config.csv 缺失，商队岗位表为空")
		return 表
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 11:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"post_id": id,
			"post_name": p[1].strip_edges(),
			"min_realm": int(p[2]),
			"max_count": int(p[3]),
			"main_attr": p[4].strip_edges(),
			"price_bonus_per_attr": float(p[5]),
			"carry_capacity": int(p[6]),
			"speed_bonus": float(p[7]),
			"risk_reduce": float(p[8]),
			"extra_salary_rate": float(p[9]),
			"loyalty_cost": float(p[10]),
		}
	f.close()
	return 表

func _读商队载具表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/caravan_vehicle_config.csv", FileAccess.READ)
	if f == null:
		push_warning("caravan_vehicle_config.csv 缺失，商队载具表为空")
		return 表
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 10:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"vehicle_id": id,
			"vehicle_name": p[1].strip_edges(),
			"vehicle_type": p[2].strip_edges(),
			"unlock_condition": p[3].strip_edges(),
			"base_carry": int(p[4]),
			"speed_bonus": float(p[5]),
			"loss_reduce": float(p[6]),
			"buy_cost": int(p[7]),
			"monthly_maintain": int(p[8]),
			"max_stack": int(p[9]),
		}
	f.close()
	return 表

# ===== §11.15 数据驱动：city/goods/route/event 四表读取 + 运行时商队地区构建 =====
func _读商品表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/goods_config.csv", FileAccess.READ)
	if f == null:
		push_warning("goods_config.csv 缺失，商品表为空")
		return 表
	f.get_csv_line()  # 跳过表头
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 7:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"goods_id": id,
			"goods_name": p[1].strip_edges(),
			"goods_type": p[2].strip_edges(),
			"base_price": int(p[3]),
			"weight": int(p[4]),
			"is_illegal": int(p[5]),
			"tier": int(p[6]),
		}
	f.close()
	return 表

func _读城市表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/city_config.csv", FileAccess.READ)
	if f == null:
		push_warning("city_config.csv 缺失，城市表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 8:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"city_id": id,
			"city_name": p[1].strip_edges(),
			"city_level": int(p[2]),
			"unlock_condition": p[3].strip_edges(),
			"base_price_rate": float(p[4]),
			"special_goods": p[5].strip_edges(),
			"lack_goods": p[6].strip_edges(),
			"reputation_level": int(p[7]),
		}
	f.close()
	return 表

func _读商路表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/trade_route_config.csv", FileAccess.READ)
	if f == null:
		push_warning("trade_route_config.csv 缺失，商路表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 6:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"route_id": id,
			"start_city": p[1].strip_edges(),
			"end_city": p[2].strip_edges(),
			"travel_day": float(p[3]),
			"base_risk_rate": float(p[4]),
			"unlock_need": p[5].strip_edges(),
		}
	f.close()
	return 表

func _读商路事件表() -> Array:
	var 表: Array = []
	var f = FileAccess.open("res://config/trade_event_config.csv", FileAccess.READ)
	if f == null:
		push_warning("trade_event_config.csv 缺失，商路事件库为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 15:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表.append({
			"event_id": id,
			"event_name": p[1].strip_edges(),
			"event_level": int(p[2]),
			"base_chance": float(p[3]),
			"risk_mult": float(p[4]),
			"effect_type": p[5].strip_edges(),
			"effect_value_min": float(p[6]),
			"effect_value_max": float(p[7]),
			"option1_text": p[8].strip_edges(),
			"option1_cost": p[9].strip_edges(),
			"option1_result": float(p[10]),
			"option2_text": p[11].strip_edges(),
			"option2_cost": p[12].strip_edges(),
			"option2_result": float(p[13]),
			"cooldown_day": int(p[14]),
		})
	f.close()
	return 表

func _读灵舟坞表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/ship_dock_config.csv", FileAccess.READ)
	if f == null:
		push_warning("ship_dock_config.csv 缺失，灵舟坞表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 13:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"dock_id": id,
			"dock_name": p[1].strip_edges(),
			"level": int(p[2]),
			"unlock_sect_level": int(p[3]),
			"max_ship_count": int(p[4]),
			"build_speed_bonus": float(p[5]),
			"repair_speed_bonus": float(p[6]),
			"daily_maintain_cost": int(p[7]),
			"upgrade_lingstone": int(p[8]),
			"upgrade_material": p[9].strip_edges(),
			"upgrade_days": int(p[10]),
			"unlock_ship_tier": int(p[11]),
			"can_build_war_ship": int(p[12]),
		}
	f.close()
	return 表

func _读宗门灵舟表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/sect_ship_config.csv", FileAccess.READ)
	if f == null:
		push_warning("sect_ship_config.csv 缺失，宗门灵舟表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 17:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"ship_id": id,
			"ship_name": p[1].strip_edges(),
			"ship_type": p[2].strip_edges(),
			"tier": int(p[3]) if p.size() > 3 else int(id.replace("ss", "")),
			"unlock_condition": p[4].strip_edges(),
			"base_carry": int(p[5]),
			"speed_bonus": float(p[6]),
			"risk_reduce": float(p[7]),
			"max_durability": int(p[8]),
			"per_trip_durability": int(p[9]),
			"max_passenger": int(p[10]),
			"war_power": int(p[11]),
			"build_cost": int(p[12]),
			"monthly_maintain": int(p[13]),
			"max_stack": int(p[14]),
			"build_material": p[15].strip_edges(),
			"build_days": int(p[16]),
			"required_forge_tier": int(p[17]) if p.size() > 17 else 1,
			"required_core_tier": int(p[18]) if p.size() > 18 else 1,
			"formation_slots": int(p[19]) if p.size() > 19 else 0,
			"features": p[20].strip_edges() if p.size() > 20 else "",
		}
	f.close()
	return 表

# 灵舟炼制桥接：goods_config 的 goods_id → 中文名（宗门库房灵材按中文名存，扣材需按名遍历）
func _读灵材名称表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/goods_config.csv", FileAccess.READ)
	if f == null:
		push_warning("goods_config.csv 缺失，灵材名称表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 7:
			continue
		var gid = p[0].strip_edges()
		var gname = p[1].strip_edges()
		if gid.is_empty() or gname.is_empty():
			continue
		表[gid] = gname
	f.close()
	return 表

# §11.15 阶段三·灵舟：装载灵舟可刻录阵法配置（ship_formation_config.csv）
func _读灵舟阵法表() -> Dictionary:
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/ship_formation_config.csv", FileAccess.READ)
	if f == null:
		push_warning("ship_formation_config.csv 缺失，灵舟阵法表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 10:
			continue
		var fid = p[0].strip_edges()
		if fid.is_empty():
			continue
		表[fid] = {
			"formation_id": fid,
			"name": p[1].strip_edges(),
			"category": p[2].strip_edges(),
			"tier": int(p[3]),
			"effect_dim": p[4].strip_edges(),
			"effect_val": float(p[5]),
			"cost_lingstone": int(p[6]),
			"cost_material": p[7].strip_edges(),
			"required_array_tier": int(p[8]),
			"ship_only": str(p[9]).strip_edges() == "1",
		}
	f.close()
	return 表

# §11.15 优化#73：正道特许商品表（黑市双线·正道线，无查缉/低查缉）
func _读正道特许表() -> Array:
	var 表: Array = []
	var f = FileAccess.open("res://config/黑市特许经营.csv", FileAccess.READ)
	if f == null:
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 3:
			continue
		var 名 = p[0].strip_edges()
		if 名.is_empty():
			continue
		表.append({"名": 名, "单价": int(p[1]), "类别": p[2].strip_edges()})
	f.close()
	return 表

# §11.15 优化#74：特殊商单表（奖励物品化）
func _读特殊商单表() -> Array:
	var 表: Array = []
	var f = FileAccess.open("res://config/特殊商单.csv", FileAccess.READ)
	if f == null:
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 6:
			continue
		var cid = p[0].strip_edges()
		if cid.is_empty():
			continue
		表.append({
			"city_id": cid,
			"req_type": p[1].strip_edges(),
			"req_count": int(p[2]),
			"reward_item": p[3].strip_edges(),
			"reward_count": int(p[4]),
			"reward_lingstone": int(p[5]),
		})
	f.close()
	return 表

# §11.15 数据驱动：从 城市表/商路表/商品表 构建运行时 商队地区（保留旧字段名供 UI/结算消费）
func _构建商队地区() -> void:
	商队地区 = []
	for cid in 商队城市表.keys():
		var 城 = 商队城市表[cid]
		var 距离 = 1.0
		var 风险 = 0.05
		var 最优距离 = 99999.0
		var 最优风险 = 99999.0
		for rid in 商队商路表.keys():
			var r = 商队商路表[rid]
			if str(r.get("end_city", "")) == cid:
				if float(r.get("travel_day", 999.0)) < 最优距离:
					最优距离 = float(r.get("travel_day", 999.0))
				if float(r.get("base_risk_rate", 1.0)) < 最优风险:
					最优风险 = float(r.get("base_risk_rate", 1.0))
		if 最优距离 < 99999.0:
			距离 = 最优距离
		if 最优风险 < 99999.0:
			风险 = 最优风险
		var 偏好: Array = []
		for gid in str(城.get("special_goods", "")).split("|"):
			gid = gid.strip_edges()
			if gid != "" and 商队商品表.has(gid):
				var t = str(商队商品表[gid].get("goods_type", ""))
				if t != "" and not 偏好.has(t):
					偏好.append(t)
		var 层级 = int(城.get("city_level", 1))
		var 溢价倍率 = 1.0 + float(层级 - 1) * 0.1
		var 物价 = float(城.get("base_price_rate", 1.0))
		# S58-P1：从世界地图系统获取城镇区域
		var 城镇区域: String = "中州"
		if Game.世界地图系统 != null and Game.世界地图系统.城镇坐标表.has(cid):
			城镇区域 = str(Game.世界地图系统.城镇坐标表[cid].get("区域", "中州"))
		商队地区.append({
			"id": cid,
			"名称": str(城.get("city_name", cid)),
			"距离": 距离,
			"特产": str(城.get("special_goods", "")).split("|"),
			"收购价": 物价,
			"风险": 风险,
			"偏好类别": 偏好,
			"溢价倍率": 溢价倍率,
			"当前收购价": 物价,
			"供需系数": 1.0,
			"city_level": 层级,
			"unlock_condition": str(城.get("unlock_condition", "")),
			"reputation_level": int(城.get("reputation_level", 0)),
			"区域": 城镇区域,   # S58-P1：城镇所在区域
		})

# §11.15 数据驱动：按 实际风险 从 商队事件库 抽取商路事件（替硬编码四分支）
func _抽取商路事件(实际风险: float) -> Dictionary:
	if 商队事件库.is_empty():
		return {}
	var 候选: Array = []
	var 总权: float = 0.0
	for e in 商队事件库:
		var 权 = float(e.get("base_chance", 0.0)) * float(e.get("risk_mult", 1.0))
		if 权 <= 0.0:
			continue
		候选.append({"e": e, "权": 权})
		总权 += 权
	if 候选.is_empty() or 总权 <= 0.0:
		return {}
	var r = randf_range(0.0, 总权)
	for c in 候选:
		r -= c["权"]
		if r <= 0.0:
			var e = c["e"]
			return {
			"事件名": str(e.get("event_name", "商路事件")),
			"effect_type": str(e.get("effect_type", "")),
			"effect_value_min": float(e.get("effect_value_min", 0.0)),
			"effect_value_max": float(e.get("effect_value_max", 0.0)),
			"option1_text": str(e.get("option1_text", "")),
			"option1_cost": str(e.get("option1_cost", "")),
			"option1_result": float(e.get("option1_result", 1.0)),
			"option2_text": str(e.get("option2_text", "")),
			"option2_cost": str(e.get("option2_cost", "")),
			"option2_result": float(e.get("option2_result", 1.0)),
		}
	return {}

# 派遣商队
# S2 商路贸易：派遣商队（运力/智谋价差/战力抗风险/载具 三要素）
#   人员列表: Array[Dictionary{"弟子ID":int, "post_id":String}]；载具ID: 商队载具表 key（可空）
# §11.15 优化#64：判断商队是否满足事件 option1 代价（人员属性 / 资源）
func _事件可取优选项(事件: Dictionary, 人员: Array) -> bool:
	var cost = str(事件.get("option1_cost", ""))
	if cost == "" or cost == "none":
		return true
	var 部分 = cost.split(":")
	if 部分.size() < 2:
		return true
	var 类型 = 部分[0].strip_edges()
	var 数值 = float(部分[1].strip_edges())
	match 类型:
		"lingstone":
			return Game.灵石 >= 数值
		"power":
			for 人 in 人员:
				var d = _取弟子(int(人.get("弟子ID", -1)))
				if d != null and float(d.战力) >= 数值:
					return true
			return false
		"wisdom":
			for 人 in 人员:
				var d = _取弟子(int(人.get("弟子ID", -1)))
				if d != null and float(d.道心) >= 数值:
					return true
			return false
		"reputation":
			var 最高 = 0
			for v in Game.阵营声望系统.阵营声望.values():
				最高 = max(最高, int(v))
			return 最高 >= 数值
		"loyalty":
			for 人 in 人员:
				var d = _取弟子(int(人.get("弟子ID", -1)))
				if d != null and float(d.忠诚) >= 数值:
					return true
			return false
		"day":
			return true
		_:
			return true

# §11.21 BUG-A 修复：crew 总战力×2 + 总声望 判定（老大拍板：截图要求人员按属性自动判定 option 命中）
#   用途：取优门槛——cost 满足 + crew 总分 ≥ 120 才走 option1（最优）；否则走 option2（保守）
func _crew总分(人员: Array) -> float:
	var 总战力: float = 0.0
	var 总声望: float = 0.0
	for 人 in 人员:
		var d = _取弟子(int(人.get("弟子ID", -1)))
		if d != null:
			总战力 += float(d.战力)
			var 声望: Dictionary = Game.阵营声望系统.阵营声望
			for v in 声望.values():
				总声望 += float(v)
	return 总战力 * 2.0 + 总声望

func 派遣商队(地区ID: String, 货物列表: Array, 弟子ID: int = -1, 载具ID: String = "", 人员列表: Array = [], 灵舟索引: int = -1, 使用神行符: bool = false, 接商单: String = "") -> Dictionary:

	var 地区 = null
	for d in 商队地区:
		if d["id"] == 地区ID:
			地区 = d
			break
	if 地区 == null:
		return {"成功": false, "消息": "未知地区"}
	# 校验货物
	var 货物总价值 = 0
	for 货物 in 货物列表:
		货物总价值 += int(货物.get("价", 0))
	if 货物总价值 <= 0:
		return {"成功": false, "消息": "货物为空"}
	# 运力校验：人员岗位运力 + 载具运力（纯配置固定值，不依赖弟子属性）
	var 运力 = 0
	for 人 in 人员列表:
		var pid = str(人.get("post_id", ""))
		if 商队岗位表.has(pid):
			运力 += int(商队岗位表[pid].get("carry_capacity", 0))
	if 载具ID != "" and 商队载具表.has(载具ID):
		运力 += int(商队载具表[载具ID].get("base_carry", 0))
	if 运力 <= 0:
		return {"成功": false, "消息": "未配置运力（需至少1名脚夫或1辆载具）"}
	if 货物总价值 > 运力:
		return {"成功": false, "消息": "运力不足（需%d，当前%d）" % [货物总价值, 运力]}
	# §11.15 优化：商队槽位 / 每日配额（现实时间模型）
	刷新商队配额()
	if 商队列表.size() >= 商队槽位数():
		return {"成功": false, "消息": "出征槽位已满（%d/%d），请等待商队返回" % [商队列表.size(), 商队槽位数()]}
	if 商队每日已派 >= 商队每日配额():
		return {"成功": false, "消息": "今日派遣配额已用尽（%d/%d），明日可再派遣" % [商队每日已派, 商队每日配额()]}
	# 启动资金（货值10%）
	var 启动资金 = int(货物总价值 * 0.1)
	if Game.灵石 < 启动资金:
		return {"成功": false, "消息": "灵石不足，需要启动资金%d" % 启动资金}
	# §11.20 修复：装载货物须真实出库（原实现只扣启动资金、不扣货物 → 货物白嫖，空手套白狼无限套利）
	var 货主 = _取弟子(弟子ID)
	if 货主 == null and Game.弟子列表.size() > 0:
		货主 = Game.弟子列表[0]   # 货物固定取自宗主背包；缺省宗主ID 时回退列表首位
	if 货主 != null:
		var 校验结果: Dictionary = _校验货物库存(货主, 货物列表)
		if not bool(校验结果.get("充足", false)):
			return {"成功": false, "消息": str(校验结果.get("消息", "货物不足"))}
	Game.灵石 -= 启动资金
	if 货主 != null:
		_出库货物(货主, 货物列表)
	# 汇总 掌柜智谋价差加成（道心代理）/ 风险减免 / 速度加成
	var 价差加成 = 0.0
	var 风险减免 = 0.0
	var 速度加成 = 0.0
	for 人 in 人员列表:
		var pid = str(人.get("post_id", ""))
		if not 商队岗位表.has(pid):
			continue
		var 岗 = 商队岗位表[pid]
		var 弟子 = _取弟子(int(人.get("弟子ID", -1)))
		if 弟子 == null:
			continue
		if str(岗.get("main_attr", "")) == "wisdom":
			价差加成 += float(岗.get("price_bonus_per_attr", 0)) * float(弟子.道心)
		风险减免 += float(岗.get("risk_reduce", 0))
		速度加成 += float(岗.get("speed_bonus", 0))
	if 载具ID != "" and 商队载具表.has(载具ID):
		var 载 = 商队载具表[载具ID]
		风险减免 += float(载.get("loss_reduce", 0))
		速度加成 += float(载.get("speed_bonus", 0))
	# §11.15 阶段三·灵舟：指派某艘灵舟出使（套用其有效属性；枯竭不可驱使；含虚空瞬移）
	var 灵舟指派索引 = -1
	var 虚空瞬移 = false
	if 灵舟索引 >= 0 and 灵舟索引 < 灵舟库存.size():
		var 舟 = 灵舟库存[灵舟索引]
		if str(舟.get("核心状态", "正常")) == "枯竭":
			return {"成功": false, "消息": "灵舟能量核心枯竭，无法驱使，请先补充核心"}
		var 舟定义 = 宗门灵舟表.get(str(舟.get("ship_id", "")), {})
		var eff = 灵舟有效属性(舟)
		风险减免 += eff["risk_reduce"]
		速度加成 += eff["speed_bonus"]
		灵舟指派索引 = 灵舟索引
		# 虚空大阵·破碎虚空：跨域（city_level≥4）且冷却就绪 → 瞬移（即时+风险归零），耗仙品核心+Game.灵石，冷却30日
		if "sf07" in 舟.get("阵法", []) and int(地区.get("city_level", 1)) >= 4 and 虚空大阵冷却日 <= 0:
			var 仙核名 = 灵舟核心物品名(5)
			if _库房灵材数量(仙核名) >= 1 and Game.灵石 >= 50000:
				Game.灵石 -= 50000
				_扣灵材([{"id": 灵核品阶物品.get(5, "g025"), "名": 仙核名, "需": 1, "有": 1}])
				虚空大阵冷却日 = Game.累计游戏日 + 30
				虚空瞬移 = true
				Game.添加纪事("神异", "破碎虚空", "【%s】催动虚空大阵，破碎虚空瞬抵%s！" % [str(舟.get("名称", "")), 地区["名称"]], 3)
		elif (Game.仙玉_非绑定 + Game.仙玉_绑定) >= 虚空瞬移仙玉费:
			var 余 = 虚空瞬移仙玉费
			if Game.仙玉_非绑定 >= 余:
				Game.仙玉_非绑定 -= 余
			else:
				var 先 = Game.仙玉_非绑定
				Game.仙玉_非绑定 = 0
				Game.仙玉_绑定 -= (余 - 先)
			虚空大阵冷却日 = Game.累计游戏日 + 30
			虚空瞬移 = true
			Game.添加纪事("神异", "虚空瞬移·仙玉", "【%s】以%d仙玉引动虚空大阵，瞬抵%s！" % [str(舟.get("名称", "")), 虚空瞬移仙玉费, 地区["名称"]], 3)
		else:
			Game.添加纪事("庶务", "灵舟刻阵", "【%s】虚空大阵就绪，然仙品核心、灵石与仙玉均不足，未能瞬移" % str(舟.get("名称", "")), 1)
	风险减免 = clamp(风险减免, 0.0, 0.8)   # 风险减免硬上限 0.8
	var 速度 = 1.0 + 速度加成
	# S58-P1：区域距离修正——同区域商路更短，跨区域需翻山越岭
	var 区域修正: float = 1.0
	var 城镇区域: String = str(地区.get("区域", "中州"))
	if Game.世界地图系统 != null:
		if 城镇区域 == Game.世界地图系统.宗门区域:
			区域修正 = 0.8   # 同区域：距离缩短20%
		else:
			区域修正 = 1.3   # 跨区域：距离增加30%
	var 行程 = max(1, int(round(float(地区["距离"]) * 区域修正 / 速度)))
	# §11.15 优化：现实时间加速——聚合多途径航速加成，换算现实耗时（封顶 贸易最短时间系数）
	var 航速被动 = _阵法堂航速被动() + _声望航速被动()
	var 符箓加成 = 0.0
	if 使用神行符:
		if _库房灵材数量(神行符名) >= 1:
			# S45-3 神行符 改读表：加速系数取自 item_talisman.csv 真源（g048 的 effect_value），缺省回落硬编码常量
			var _神行cfg: Dictionary = Game.符箓配置(神行符_ID)
			符箓加成 = float(_神行cfg.get("effect_value", "0.3")) if not _神行cfg.is_empty() else 神行符加速
			_扣灵材([{"id": 神行符_ID, "名": 神行符名, "需": 1, "有": 1}])
		else:
			return {"成功": false, "消息": "背包无神行符，无法使用（坊市可购置）"}
	var 总速度加成 = 速度加成 + 航速被动 + 符箓加成
	var 贸易耗时秒 = _计算贸易现实秒(总速度加成)
	Game.灵石 -= 启动资金
	商队ID计数器 += 1
	var 商队 = {
		"id": 商队ID计数器,
		"地区": 地区ID,
		"地区名": 地区["名称"],
		"出发日": Game.累计游戏日,
		"预计返回日": Game.累计游戏日 + int(ceil(float(贸易耗时秒) / Game.现实秒每游戏日)),   # 仅展示用（≈现实耗时折算游戏日）
		"预计完成真实秒": int(Time.get_unix_time_from_system()) + 贸易耗时秒,
		"货物": 货物列表,
		"货物价值": 货物总价值,
		"弟子ID": 弟子ID,
		"载具ID": 载具ID,
		"人员": 人员列表,
		"灵舟索引": 灵舟指派索引,
		"虚空瞬移": 虚空瞬移,
		"价差加成": 价差加成,
		"风险减免": 风险减免,
		"速度": 速度,
		"状态": "派遣中",
		"接商单": 接商单,
	}
	商队列表.append(商队)
	商队每日已派 += 1
	var 加速说明 = ""
	if 符箓加成 > 0:
		加速说明 = "【神行符加速】"
	Game.添加纪事("庶务", "商队出发", "商队前往%s贸易，货物价值%d灵石，运力%d，预计%d分钟后返回%s" % [地区["名称"], 货物总价值, 运力, int(贸易耗时秒 / 60), 加速说明], 1)
	return {"成功": true, "消息": "商队已出发，预计%d分钟后返回%s" % [int(贸易耗时秒 / 60), 加速说明], "商队ID": 商队ID计数器}

# S2 商路贸易：按 ID 取弟子对象（商队编组用）
func _取弟子(目标ID: int) -> Object:
	for d in Game.弟子列表:
		if d.弟子ID == 目标ID:
			return d
	return null

# §11.20 修复：派遣前全量校验背包货物（先校验再出库，避免部分扣货后失败留下残缺库存）
func _校验货物库存(货主: Variant, 货物列表: Array) -> Dictionary:
	if 货主 == null:
		return {"充足": true, "消息": ""}
	var 需求: Dictionary = {}
	for 货物 in 货物列表:
		var 名 = str(货物.get("名称", ""))
		var 数 = int(货物.get("数量", 0))
		if 名 == "" or 数 <= 0:
			continue
		需求[名] = int(需求.get(名, 0)) + 数
	var 持有: Dictionary = {}
	for it in 货主.背包:
		持有[str(it.名称)] = int(持有.get(str(it.名称), 0)) + 1
	for 名 in 需求.keys():
		var 需 = int(需求[名])
		var 有 = int(持有.get(名, 0))
		if 有 < 需:
			return {"充足": false, "消息": "货物不足：%s（需%d，现存%d）" % [名, 需, 有]}
	return {"充足": true, "消息": ""}

# §11.20 修复：从背包移除已装车货物（真实出库；货物成本 = 货值，贸易利润 = 结算收益 - 货值 - 启动资金）
func _出库货物(货主: Variant, 货物列表: Array) -> int:
	var 已扣: int = 0
	if 货主 == null:
		return 已扣
	for 货物 in 货物列表:
		var 名 = str(货物.get("名称", ""))
		var 需 = int(货物.get("数量", 0))
		if 名 == "" or 需 <= 0:
			continue
		for it in 货主.背包.duplicate():
			if 需 <= 0:
				break
			if str(it.名称) == 名:
				货主.背包.erase(it)
				需 -= 1
				已扣 += 1
	return 已扣

# 结算返回的商：
# ── 商道境界：加成 / 减免 / 经验 / 突破 ──
func 获取商道境界加成() -> float:
	var 加成 = 0.0
	for 行 in 商道境界表:
		if str(行.get("境界", "")) == 商道境界:
			加成 = float(行.get("价差加成", 0.0))
			break
	return 加成

func 获取商道风险减免() -> float:
	var 减免 = 0.0
	for 行 in 商道境界表:
		if str(行.get("境界", "")) == 商道境界:
			减免 = float(行.get("风险减免", 0.0))
			break
	return 减免

func 增加商道经验(收益: int, 接商单: String = "") -> void:
	var 得 = 10
	if 收益 > 1000:
		得 += 20
	if str(接商单) != "":
		得 += 50
	商道经验 += 得
	# 取当前经验可达的最高境界（表按所需经验升序，末次命中即最高）
	var 目标境 = 商道境界
	for 行 in 商道境界表:
		if 商道经验 >= int(行.get("所需经验", 0)):
			目标境 = str(行.get("境界", ""))
	if 目标境 != 商道境界:
		商道境界 = 目标境
		Game.添加纪事("商道", "境界突破", "【商道·境界突破】商道修为突破至%s！" % 商道境界, 2)

func 结算商队(商队: Dictionary) -> Dictionary:

	var 地区 = null
	for d in 商队地区:
		if d["id"] == 商队["地区"]:
			地区 = d
			break
	if 地区 == null:
		return {"成功": false, "消息": "未知地区"}
	# S2 品类溢价：货物名称匹配目的地偏好类别 → 该部分按溢价倍率计价（低买高卖核心）
	var 货值 = int(商队["货物价值"])
	var 匹配价值 = 0
	for 货物 in 商队["货物"]:
		var 类 = str(货物.get("类别", ""))
		if 类 != "" and 类 in 地区.get("偏好类别", []):
			匹配价值 += int(货物.get("价", 0))
	var 匹配占比 = 0.0
	if 货值 > 0:
		匹配占比 = float(匹配价值) / float(货值)
	var 溢价系数 = 匹配占比 * float(地区.get("溢价倍率", 1.0)) + (1.0 - 匹配占比) * 1.0
	# 基础收益 = 货值 × 当前收购价(浮动) × (1+掌柜智谋价差加成) × 品类溢价系数
	var 价差加成 = float(商队.get("价差加成", 0.0))
	# §11.15 策略深度：商路声望 → 卖价价差加成（随声望升）
	价差加成 += _商路声望价差加成(地区["id"])
	价差加成 += 获取商道境界加成()
	价差加成 += 计算护卫专长收益加成(商队.get("人员", []))
	# §11.15 策略深度：全局行情事件 → 匹配本城偏好品类时叠加溢价倍率
	var 事件倍率 = _行情事件倍率(地区)
	if 事件倍率 > 1.0:
		溢价系数 = 匹配占比 * float(地区.get("溢价倍率", 1.0)) * 事件倍率 + (1.0 - 匹配占比) * 1.0
	# §11.15 阶段三：商路竞争压价（NPC 对手压低该城有效收购价；独占→红利×1.2）
	var 有效收购价 = float(地区.get("当前收购价", 地区["收购价"]))
	var 城市id = str(地区.get("id", ""))
	var 竞争压价率 = 0.0
	if 商路竞争状态.has(城市id):
		竞争压价率 = float(商路竞争状态[城市id].get("压价率", 0.0))
		有效收购价 *= (1.0 - 竞争压价率)
	# §11.20 BUG-D 修复：竞争压价率=0（独占 OR 无记录）→ 给红利 ×1.2；NPC 实际压价则不叠加
	var 独占红利: bool = false
	if 竞争压价率 <= 0.0:
		有效收购价 *= 1.2   # 独占红利：首访默认独占 / 已独占状态均为 1.2
		独占红利 = true
	var 基础收益 = int(float(货值) * 有效收购价 * (1.0 + 价差加成) * 溢价系数 * float(地区.get("供需系数", 1.0)) * (1.0 + _区域商路加成()))
	# 风险判定：实际风险 = 地区风险 × (1 - 商队风险减免)，护卫/载具降风险
	# S58-P1：区域风险修正——跨区域商路更危险（翻山越岭、盗匪出没）
	var 区域风险修正: float = 1.0
	var 城镇区域: String = str(地区.get("区域", "中州"))
	if Game.世界地图系统 != null and 城镇区域 != Game.世界地图系统.宗门区域:
		区域风险修正 = 1.3   # 跨区域风险增加30%
	var 实际风险 = clamp(float(地区["风险"]) * 区域风险修正 * (1.0 - (float(商队.get("风险减免", 0.0)) + 获取商道风险减免())), 0.0, 1.0) - 计算护卫专长风险减免(商队.get("人员", []))
	var 随机值 = randf()
	var 实际收益 = 基础收益
	var 事件 = "顺利贸易"
	var 事件灵石扣: int = 0
	var 事件声望扣: int = 0
	if 随机值 < 实际风险:
		# §11.15 数据驱动：从 trade_event_config.csv 抽取风险事件替代硬编码四分支
		var 事件结果 = _抽取商路事件(实际风险)
		if not 事件结果.is_empty():
			事件 = str(事件结果.get("事件名", "商路生变"))
			var emin = float(事件结果.get("effect_value_min", 0.0))
			var emax = float(事件结果.get("effect_value_max", 0.0))
			var ev = randf_range(emin, emax) if emax > emin else emin
			# §11.20 修复（原实现两处致命语义错误）：
			#   ① effect_value 语义 = 损失率(0~1) / 绝对值(>=1，仅 lingstone_cost)。
			#      原 `实际收益 = 基础收益 * ev` 把损失率当保留率：颠簸设计丢 8% → 实丢 92%
			#   ② effect_type 支持 "a+b" 组合（CSV 中 4 条），原 `==` 精确匹配使组合事件全部落 else，
			#      被乘 option1_result（那是「选项减免后的损失系数」，不是收益系数）
			var 留存系数 = 1.0
			for eff in str(事件结果.get("effect_type", "")).split("+"):
				var 效 = str(eff).strip_edges()
				if 效 == "goods_loss":
					留存系数 *= clamp(1.0 - ev, 0.0, 1.0)
				elif 效 == "disciple_hurt":
					留存系数 *= clamp(1.0 - ev * 0.5, 0.0, 1.0)   # 受伤弟子照看不力，货款按半额折损
				elif 效 == "lingstone_cost":
					事件灵石扣 += int(ev * float(货值)) if emax <= 1.0 else int(ev)
				elif 效 == "reputation":
					事件声望扣 += int(ev * 事件声望折算) if emax <= 1.0 else int(ev)
			实际收益 = int(float(基础收益) * 留存系数)
			# §11.21 BUG-A 修复：人员/资源满足 option1 代价 + crew 总分 ≥ 120 才取优，否则失策（截图 crew 自动判定）
			var 取优 = _事件可取优选项(事件结果, 商队.get("人员", [])) and _crew总分(商队.get("人员", [])) >= 120.0
			事件 = "%s·%s" % [事件, "优策" if 取优 else "失策"]
			# 按 option.result 替换整体留存系数（option.result 是「整体损失率」，留存 = 1 - result）
			var opt_result: float = 0.0
			if 取优:
				opt_result = float(事件结果.get("option1_result", ev))
			else:
				opt_result = float(事件结果.get("option2_result", ev))
			var opt_留存: float = clamp(1.0 - opt_result, 0.0, 1.0)
			# 取 option 路径：直接以 option.result 作为整体留存
			# 失策/无 option 字段：仍走 ev 计算的留存系数
			if 取优 or str(事件结果.get("option1_text", "")) != "":
				实际收益 = int(float(基础收益) * opt_留存)
			# §11.21 BUG-A 修复：妖兽 × 邪修伏击（te004 / te006：goods_loss+disciple_hurt）→ 招妖兽潮，额外扣 1/3
			if ("goods_loss" in 事件结果.get("effect_type", "") and
					"disciple_hurt" in 事件结果.get("effect_type", "")):
				for 货 in 商队.get("货物", []):
					if str(货.get("类别", "")) == "妖兽":
						实际收益 = int(float(实际收益) * 2.0 / 3.0)
						break
		else:
			# 事件库为空时 Fallback 旧硬编码：山贼/颠簸/失踪
			var 风险类型 = randf()
			if 风险类型 < 0.4:
				实际收益 = int(基础收益 * 0.5)
				事件 = "遭遇山贼，损失一半货物"
			elif 风险类型 < 0.7:
				实际收益 = int(基础收益 * 0.8)
				事件 = "路途颠簸，部分货物损坏"
			else:
				实际收益 = 0
				事件 = "商队失踪，全部货物损失"
	elif 随机值 > 1.0 - 0.1:   # 10% 偶遇高人
		实际收益 = int(基础收益 * 1.5)
		事件 = "偶遇高人指点，贸易大获成功"
	elif 随机值 > 1.0 - 0.15:  # 5% 发现宝藏
		实际收益 = int(基础收益 * 1.3)
		Game.灵石 += int(EconomyBalance.new().平衡(500.0))  # 额外发现宝藏（过阀门）
		事件 = "途中发现古代宝藏"
	elif 随机值 > 1.0 - 0.2:   # 5% 遇到同行
		实际收益 = int(基础收益 * 1.1)
		Game.阵营声望系统.增加阵营声望("散修联盟", 10)
		事件 = Game.文案表["friendly_caravan_event"]
	# §11.15 阶段三：跨域商路（城7/8，city_level≥4）顶级风险：跨海妖兽/风暴/海盗/灵舟故障
	if 实际收益 > 0 and int(地区.get("city_level", 1)) >= 4:
		# 虚空瞬移：直接零风险（指派灵舟刻有虚空大阵且已瞬移抵达）
		var 跨域险 = 0.0
		if not 商队.get("虚空瞬移", false):
			# 灵舟运力降险：指定灵舟用其有效属性；否则舰队级取最优（均含阵法加成，枯竭不计）
			var 灵舟减险 = 0.0
			var 指idx = int(商队.get("灵舟索引", -1))
			if 指idx >= 0 and 指idx < 灵舟库存.size():
				var 指舟 = 灵舟库存[指idx]
				if str(指舟.get("核心状态", "正常")) != "枯竭":
					灵舟减险 = 灵舟有效属性(指舟)["risk_reduce"]
			else:
				var 需求tier = int(地区.get("city_level", 1)) - 3
				for 舟 in 灵舟库存:
					if int(舟.get("tier", 0)) >= 需求tier and str(舟.get("核心状态", "正常")) != "枯竭":
						灵舟减险 = max(灵舟减险, 灵舟有效属性(舟)["risk_reduce"])
			跨域险 = clamp(float(地区.get("风险", 0.1)) * 0.5 + 0.15 - 灵舟减险, 0.0, 0.9)
		if 跨域险 > 0.0 and randf() < 跨域险:
			var d = 跨域风险事件[randi() % 跨域风险事件.size()]
			var dl = float(d.get("损失min", 0.3))
			var dh = float(d.get("损失max", 0.6))
			var 损失 = randf_range(dl, dh)
			# §11.20 修复：以「当前实际收益」为基数（原用基础收益 → 偶遇高人1.5x、事件减免全被抹掉，
			#                                 导致高级跨域城收益低于低级安全城，形成逆向激励）
			实际收益 = int(float(实际收益) * (1.0 - 损失))
			事件 = str(d.get("名", "跨域生变"))
			var 扣 = int(d.get("额外扣", 0))
			if 扣 > 0:
				Game.灵石 = max(0, Game.灵石 - 扣)
		# §11.15 优化#72：跨域正向分支（非瞬移跨域抵港、未触发风险时，稀有货物被异域豪商溢价收购）
		elif 实际收益 > 0 and not 商队.get("虚空瞬移", false) and randf() < 0.35:
			实际收益 = int(float(实际收益) * 1.3)
			事件 = "跨域通商·稀有货物被异域豪商溢价收购"
	# §11.20 修复：毛收益封顶（阶梯随「商队总声望」提升，货值×1.5 → 最高×4.5）
	#   原 1.0~4.0x 会把正常加成（收购价×溢价×掌柜价差≈1.2x）削平 93%，溢价/Game.声望/行情事件全部作废；
	#   阀门须先行、封顶后置——封顶是硬红线，原顺序允许阀门纠偏结果突破上限
	#   接 F2 经济阀门（trade_profit_rate 等），补全商队结算审计缺口
	实际收益 = int(EconomyBalance.new().平衡(float(实际收益)))
	var 封顶倍率 = _商队收益封顶倍率()
	var 收益上限 = int(float(货值) * 封顶倍率)
	if 实际收益 > 收益上限:
		实际收益 = 收益上限
	# 结算入灵石主账户（不新建独立资金池，守 GDD 九·3）
	Game.灵石 += 实际收益
	# P3联动：商队交易 → 宗门经济繁荣度（每1000灵石收益+1繁荣经营值，上限50）
	if 实际收益 > 0:
		var 繁荣增量: int = min(50 - Game.繁荣经营值, int(实际收益 / 1000))
		if 繁荣增量 > 0:
			Game.繁荣经营值 += 繁荣增量
	# §11.15 优化#75：贸易统计 + 成就 + 收藏图录
	累计贸易次数 += 1
	累计贸易收益 += 实际收益
	增加商道经验(实际收益, str(商队.get("接商单", "")))
	for 货物 in 商队["货物"]:
		Game._记录图录(str(货物.get("名称", "")), "贸易")
	# §11.15 优化#74：特殊商单结算发奖（按在途货物校验）
	if str(商队.get("接商单", "")) != "":
		_结算特殊商单(商队)
	# §11.15 优化#74：奖励物品化（低频掉落，守经济红线）
	if 实际收益 > 0 and randf() < 0.15:
		_发放贸易物品奖励(实际收益)
	Game._复检成就()
	if 事件灵石扣 > 0:
		Game.灵石 = max(0, Game.灵石 - 事件灵石扣)
	if 事件声望扣 > 0:
		商路声望[地区["id"]] = int(商路声望.get(地区["id"], 0)) - 事件声望扣
	# §11.15 策略深度：累加商路声望 + 大批量抛售压价（供需系数跌，逐日回升）
	_累加商路声望(地区["id"], 实际收益)
	if 货值 >= 500:
		地区["供需系数"] = max(0.6, float(地区.get("供需系数", 1.0)) - 0.1)
	商队["状态"] = "已返回"
	商队["实际收益"] = 实际收益
	商队["事件"] = 事件
	商队历史.insert(0, 商队)
	if 商队历史.size() > 100:
		商队历史.resize(100)
	Game.添加纪事("庶务", "商队返回", "商队%s返回，%s，获%d灵石" % [商队["地区名"], 事件, 实际收益], 1)
	# §商道深化（P2/P3/周常/奇遇，纯加乘区，不碰核心结算）：周常计数 + 稀有捡漏 + 受控奇遇
	商道周常本周参与 += 1
	触发稀有商品(商队)
	if randf() < 0.03:
		Game._尝试触发奇遇(Game.宗主, "商道")
	return {"成功": true, "消息": "商队返回，%s，获%d灵石" % [事件, 实际收益], "收益": 实际收益}

# §11.15 优化#74：特殊商单结算发奖（校验在途货物含 req_type 足量）
func _结算特殊商单(商队: Dictionary) -> void:
	var cid = str(商队.get("接商单", ""))
	for 单 in 特殊商单表:
		if str(单.get("city_id", "")) == cid:
			var 够 = false
			for 货物 in 商队["货物"]:
				if str(货物.get("类别", "")) == str(单.get("req_type", "")) and int(货物.get("数量", 0)) >= int(单.get("req_count", 0)):
					够 = true
					break
			if 够:
				Game.灵石 += int(单.get("reward_lingstone", 0))
				_发放物品(str(单.get("reward_item", "")), int(单.get("reward_count", 1)))
				Game.添加纪事("庶务", "特殊商单", "完成特殊商单（%s），获灵石%d及物品" % [cid, int(单.get("reward_lingstone", 0))], 1)
			break

# §11.15 优化#74：贸易物品奖励发放（入宗主背包，按 goods_type 取一件随机合规商品）
func _发放贸易物品奖励(收益: int) -> void:
	if 商队商品表.is_empty() or Game.弟子列表.size() <= 0:
		return
	var 候选: Array = []
	for gid in 商队商品表.keys():
		var g = 商队商品表[gid]
		if int(g.get("is_illegal", 0)) == 0:
			候选.append(g)
	if 候选.is_empty():
		return
	var g = 候选[randi() % 候选.size()]
	var it: Item = Item.new()
	it.名称 = str(g.get("goods_name", "货物"))
	it.品阶 = "灵品"
	it.类别 = str(g.get("goods_type", "杂货"))
	Game.弟子列表[0].背包.append(it)
	Game.添加纪事("庶务", "贸易奇遇", "贸易归来，获赠%s×1" % it.名称, 1)

# §11.15 优化#74：按名发放物品到宗主背包
func _发放物品(名: String, 数: int) -> void:
	if 名 == "" or 数 <= 0 or Game.弟子列表.size() <= 0:
		return
	for _i in range(数):
		var it: Item = Item.new()
		it.名称 = 名
		it.品阶 = "灵品"
		it.类别 = "特殊"
		Game.弟子列表[0].背包.append(it)
# 每日更新商队状态
# S2 商路贸易：月度行情刷新（商队周期补货世界观），收购价/风险 ±10% 浮动，锁定 ±15% 红线
func 刷新商队行情() -> void:
	# §11.20 修复：按现实日节流（原每次「推演一月」都刷新 → 1真实天≈360次，
	#   ① 供需系数 +0.02/次 → 大批量抛售的 -0.1 压价瞬间回满，压价机制形同虚设；
	#   ② 收购价/风险每 4 分钟跳变，玩家派遣时看到的价格与 6 小时后结算时的价格脱节）
	var 现在 = int(Time.get_unix_time_from_system())
	var 跨日: bool = (现在 - 上次行情日真实秒) >= 86400
	if 跨日:
		上次行情日真实秒 = 现在
		for 地区 in 商队地区:
			var 基准价 = float(地区["收购价"])
			var 价浮 = randf_range(-0.15, 0.15)
			var 新价 = clamp(基准价 * (1.0 + 价浮), 基准价 * 0.85, 基准价 * 1.15)  # §11.15 设计值：硬锁 ±15%
			地区["当前收购价"] = round(新价 * 100) / 100.0
			var 基准险 = float(地区["风险"])
			var 险浮 = randf_range(-0.10, 0.10)
			地区["风险"] = clamp(基准险 * (1.0 + 险浮), 0.0, 0.5)
			# §11.20 修复：供需系数按现实日回升（+0.10/日，与结算抛售压价 -0.10 对称；原 +0.02/次 × 360 次/天 → 压价瞬间回满）
			var 供需 = float(地区.get("供需系数", 1.0))
			地区["供需系数"] = clamp(供需 + 0.10, 0.6, 1.0)
		# §11.15 策略深度：行情事件倒计时按现实日递减，过期移除
		for i in range(行情事件列表.size() - 1, -1, -1):
			var ev = 行情事件列表[i]
			ev["剩余天数"] = int(ev.get("剩余天数", 0)) - 1
			if int(ev.get("剩余天数", 0)) <= 0:
				行情事件列表.remove_at(i)

func 更新商队状态() -> void:
	刷新商队行情()   # S2 商路贸易：月度行情刷新（接推演一月调用）
	# §商道周常：按周序重置（周=累计游戏日/7）
	var 商道周序 = int(Game.累计游戏日 / 7) % 4
	if 商道周常上周序 != 商道周序:
		商道周常上周序 = 商道周序
		商道周常本周参与 = 0
		商道周常本周稀有 = false
	_推进灵舟建造()   # §11.15 阶段三：灵舟坞/灵舟炼制 推演追帧完工
	_结算灵舟月度()    # §11.15 阶段三·灵舟：灵石维护 + 能量核心月度消耗
	if Game.累计游戏日 % 30 == 0:
		_刷新行情事件()   # §11.15 策略深度：每月触发全局行情事件
		_刷新商路竞争()    # §11.15 阶段三：月度 NPC 商队竞争推演
	if 黑市禁闭日 > 0:     # §11.15 阶段三：黑市查缉禁闭倒计时
		黑市禁闭日 = max(0, 黑市禁闭日 - 1)

	结算商铺产出()
	结算到期商队()

# §11.15 优化：现实时间结算——到期（预计完成真实秒）即结算，不依赖游戏日 tick；离线/未推演也能正确返还
func 结算到期商队() -> void:
	var 现在 = int(Time.get_unix_time_from_system())
	var 待结算: Array = []
	for 商队 in 商队列表:
		if 商队["状态"] != "派遣中":
			continue
		var 到期 = int(商队.get("预计完成真实秒", 0))
		var 到期标志 = false
		if 到期 > 0:
			到期标志 = 现在 >= 到期
		else:
			# 旧档兼容：无真实秒字段则按游戏日
			到期标志 = Game.累计游戏日 >= int(商队.get("预计返回日", 0))
		if 到期标志:
			待结算.append(商队)
	for 商队 in 待结算:
		结算商队(商队)
		商队列表.erase(商队)

# ===== §11.15 预留接口：PVP / 全服事件 / 域外战斗（本期不实装，仅留钩子供后期版本接入）=====
# 设计意图：灵舟系统已具「破损虚空瞬移」「灵舟坞」「阵法刻录」等修真基底，后期可在此分支接入：
#   - PVP：宗门敌对城（city 11）开放「灵舟斗法」，以 灵舟有效属性 为战力投影
#   - 全服事件：稀缺商路/秘境产出全服竞拍，复用 商路声望 / 行情事件队列
#   - 域外战斗：破虚神舰（ss05）虚空瞬移抵达 域外 后触发战斗（预留 _预留_域外战斗）
func 预留_域外战斗(目标: Dictionary = {}) -> Dictionary:
	# TODO(预留): 后期版本接入 PVP / 全服事件 / 域外战斗，当前返回未实装
	return {"成功": false, "消息": "域外战斗接口预留中（未实装）"}

# ===== §11.15 阶段三：灵舟坞 / 黑市 / NPC 商队竞争 =====
func 已建灵舟坞() -> bool:
	return 灵舟坞等级 > 0

func 灵舟坞建造信息() -> Dictionary:
	if not 灵舟坞建造中.is_empty():
		return {"可建": false, "建造中": true, "目标档": int(灵舟坞建造中.get("目标档", 0)), "完成日": int(灵舟坞建造中.get("完成日", 0))}
	var 目标 = 灵舟坞等级 + 1
	if 目标 > 灵舟坞表.size():
		return {"可建": false, "已满": true}
	var 档 = 灵舟坞表.get("sd%02d" % 目标, null)
	if 档 == null:
		return {"可建": false}
	var 清单 = _解析材料清单(档.get("upgrade_material", ""))
	for m in 清单:
		m["有"] = _库房灵材数量(m["名"])
	return {"可建": true, "等级": 目标, "名称": str(档.get("dock_name", "")),
		"需门派等级": int(档.get("unlock_sect_level", 99)), "工费": int(档.get("upgrade_lingstone", 0)),
		"时日": int(档.get("upgrade_days", 0)), "材料": 清单}

# 建造/升级飞舟坞（顺序解锁 sd01→sd06）：主成本=各阶灵材 + 时日；工费灵石为祭炼之资，不可替材料。
# 提交后进入「建造中」，由 _推进灵舟建造() 在推演中按 累计游戏日 完工。
func 建造灵舟坞() -> Dictionary:
	if not 灵舟坞建造中.is_empty():
		return {"成功": false, "消息": "飞舟坞正在建造中，不可重复开工"}
	var 信息 = 灵舟坞建造信息()
	if not 信息.get("可建", false):
		if 信息.get("已满", false):
			return {"成功": false, "消息": "飞舟坞已达最高品级"}
		return {"成功": false, "消息": "飞舟坞配置缺失"}
	if Game.门派等级 < int(信息.get("需门派等级", 99)):
		return {"成功": false, "消息": "宗门品级不足（需%d品）" % int(信息.get("需门派等级", 99))}
	var 费 = int(信息.get("工费", 0))
	if Game.灵石 < 费:
		return {"成功": false, "消息": "祭炼灵石不足（需%d）" % 费}
	var 扣 = _扣灵材(信息.get("材料", []))
	if not 扣.get("成功", false):
		return {"成功": false, "消息": "灵材不足：" + "、".join(扣.get("缺", []))}
	Game.灵石 -= 费
	var 目标档 = int(信息.get("等级", 1))
	灵舟坞建造中 = {"目标档": 目标档, "完成日": Game.累计游戏日 + int(信息.get("时日", 0))}
	Game.添加纪事("庶务", "飞舟坞", "历时%d日，动工兴建%s（%d品），灵材已耗、祭炼灵石已付" % [int(信息.get("时日", 0)), str(信息.get("名称", "")), 目标档], 1)
	return {"成功": true, "消息": "飞舟坞（%s）动工，预计%d日完工" % [str(信息.get("名称", "")), int(信息.get("时日", 0))], "等级": 目标档, "完成日": 灵舟坞建造中["完成日"]}

# 灵材清单解析： "g010:20|g003:15" → [{id, 名, 需}]（名由 goods_config 桥接）
func _解析材料清单(mat_str: String) -> Array:
	var 清单: Array = []
	if mat_str == null:
		return 清单
	var s = str(mat_str).strip_edges()
	if s.is_empty():
		return 清单
	for 段 in s.split("|"):
		var t = 段.strip_edges()
		if t.is_empty():
			continue
		var 部分 = t.split(":")
		if 部分.size() < 2:
			continue
		var gid = 部分[0].strip_edges()
		var 数 = int(部分[1].strip_edges())
		if gid.is_empty() or 数 <= 0:
			continue
		清单.append({"id": gid, "名": 灵材名称表.get(gid, gid), "需": 数})
	return 清单

# 宗门库房内某中文名灵材现有数量
func _库房灵材数量(名: String) -> int:
	var n = 0
	for it in Game.宗门库房:
		if it is Item and str(it.名称) == 名:
			n += 1
	return n

# 扣灵材（按中文名遍历宗门库房逐一移除）；够则扣净返回成功，不足返回缺项（不扣，避免半扣）
func _扣灵材(清单: Array) -> Dictionary:
	var 缺: Array = []
	for m in 清单:
		var 有 = _库房灵材数量(m["名"])
		if 有 < m["需"]:
			缺.append("%s（缺%d）" % [m["名"], m["需"] - 有])
	if 缺.size() > 0:
		return {"成功": false, "缺": 缺}
	for m in 清单:
		var 剩 = m["需"]
		var i = 0
		while i < Game.宗门库房.size() and 剩 > 0:
			var it = Game.宗门库房[i]
			if it is Item and str(it.名称) == m["名"]:
				Game.宗门库房.remove_at(i)
				剩 -= 1
			else:
				i += 1
	return {"成功": true, "缺": []}

# 推演追帧：灵舟坞建造/升级 + 灵舟炼制队列 完工（接 更新商队状态 调用）
func _推进灵舟建造() -> void:
	if not 灵舟坞建造中.is_empty():
		if Game.累计游戏日 >= int(灵舟坞建造中.get("完成日", 0)):
			var 目标档 = int(灵舟坞建造中.get("目标档", 1))
			var 档 = 灵舟坞表.get("sd%02d" % 目标档, null)
			灵舟坞等级 = 目标档
			灵舟坞建造中 = {}
			if 档 != null:
				Game.添加纪事("庶务", "飞舟坞", "历时%d日，%s（%d品）建成，自此可跨域通商" % [int(档.get("upgrade_days", 0)), str(档.get("dock_name", "")), 灵舟坞等级], 1)
	var 仍进行: Array = []
	for q in 灵舟建造队列:
		if Game.累计游戏日 >= int(q.get("完成日", 0)):
			var sid = str(q.get("ship_id", ""))
			var 舟 = 宗门灵舟表.get(sid, null)
			if 舟 != null:
				灵舟库存.append({
					"ship_id": sid, "名称": str(舟.get("ship_name", "")),
					"tier": int(舟.get("tier", 0)), "ship_type": str(舟.get("ship_type", "")),
					"durability": int(舟.get("max_durability", 0)), "max_durability": int(舟.get("max_durability", 0)),
					"speed_bonus": float(舟.get("speed_bonus", 0)), "risk_reduce": float(舟.get("risk_reduce", 0)),
					"核心品阶": int(舟.get("required_core_tier", 1)), "阵法": [], "核心状态": "正常", "可命名次数": 1,
				})
				Game.添加纪事("庶务", "灵舟炼成", "历时%d日，灵舟【%s】炼制功成！" % [int(舟.get("build_days", 0)), str(舟.get("ship_name", ""))], 1)
		else:
			仍进行.append(q)
	灵舟建造队列 = 仍进行

# 炼制灵舟（需已建坞，受坞解锁档位与容量限制）：主成本=各阶灵材 + 时日；工费灵石为祭炼之资。
func 炼制灵舟(ship_id: String) -> Dictionary:
	if 灵舟坞等级 <= 0:
		return {"成功": false, "消息": "须先建成飞舟坞"}
	var 舟 = 宗门灵舟表.get(ship_id, null)
	if 舟 == null:
		return {"成功": false, "消息": "灵舟型号不存在"}
	var 舟tier = int(舟.get("tier", 0))
	var 坞 = 灵舟坞表.get("sd%02d" % 灵舟坞等级, null)
	if 坞 == null:
		return {"成功": false, "消息": "飞舟坞状态异常"}
	var 需等级 = int(str(舟.get("unlock_condition", "sect_level=1")).replace("sect_level=", ""))
	if Game.门派等级 < 需等级:
		return {"成功": false, "消息": "宗门品级不足（需%d品）" % 需等级}
	if int(坞.get("unlock_ship_tier", 0)) < 舟tier:
		return {"成功": false, "消息": "当前飞舟坞仅可炼制 tier%d 及以下灵舟" % int(坞.get("unlock_ship_tier", 0))}
	# §11.15 阶段三·灵舟：炼器师品阶门槛（复用 ForgeSystem.获取炼器等级）
	var 所需炼器师 = int(舟.get("required_forge_tier", 1))
	if ForgeSystem.获取炼器等级(Game.炼器经验值) < 所需炼器师:
		return {"成功": false, "消息": "炼器师品阶不足（需 %d 品炼器师）" % 所需炼器师}
	# 战舰型灵舟需更高级船坞（坞 can_build_war_ship≥1）
	if str(舟.get("ship_type", "")) == "war" and int(坞.get("can_build_war_ship", 0)) < 1:
		return {"成功": false, "消息": "当前飞舟坞不可炼制战舰（需更高级船坞）"}
	if 灵舟库存.size() + 灵舟建造队列.size() >= int(坞.get("max_ship_count", 1)):
		return {"成功": false, "消息": "飞舟坞容量已满（上限%d）" % int(坞.get("max_ship_count", 1))}
	for q in 灵舟建造队列:
		if str(q.get("ship_id", "")) == ship_id:
			return {"成功": false, "消息": "该灵舟已在炼制队列中"}
	var 清单 = _解析材料清单(舟.get("build_material", ""))
	for m in 清单:
		m["有"] = _库房灵材数量(m["名"])
	var 费 = int(舟.get("build_cost", 0))
	if Game.灵石 < 费:
		return {"成功": false, "消息": "祭炼灵石不足（需%d）" % 费}
	var 扣 = _扣灵材(清单)
	if not 扣.get("成功", false):
		return {"成功": false, "消息": "灵材不足：" + "、".join(扣.get("缺", []))}
	Game.灵石 -= 费
	灵舟建造队列.append({"ship_id": ship_id, "完成日": Game.累计游戏日 + int(舟.get("build_days", 0))})
	Game.添加纪事("庶务", "灵舟炼制", "历时%d日，开工炼制【%s】，灵材已耗、祭炼灵石已付" % [int(舟.get("build_days", 0)), str(舟.get("ship_name", ""))], 1)
	return {"成功": true, "消息": "【%s】动工炼制，预计%d日完工" % [str(舟.get("ship_name", "")), int(舟.get("build_days", 0))], "完成日": Game.累计游戏日 + int(舟.get("build_days", 0))}

# ===== §11.15 阶段三：Game.拍卖会（双向市场）=====
# 唯一「纯灵石直接获得灵舟」途径：购买 NPC/其他势力成品（跳过材料+时日）。
# 反向：本宗炼制的灵舟亦可挂拍换灵石。
func 获取拍卖会灵舟() -> Array:
	var 势力池: Array = ["玄天宫", "万宝楼", "散修联盟", "北海龙宫", "天机阁", "九幽邪宗"]
	var 列表: Array = []
	for sid in 宗门灵舟表.keys():
		var 舟 = 宗门灵舟表[sid]
		var tier = int(舟.get("tier", 0))
		var 价 = int(float(舟.get("build_cost", 0)) * (1.5 + 0.5 * tier))   # 成品较自炼溢价（省材料+时日）
		列表.append({
			"ship_id": sid, "名称": str(舟.get("ship_name", "")), "tier": tier,
			"ship_type": str(舟.get("ship_type", "")), "价": 价,
			"卖家": 势力池[randi() % 势力池.size()],
		})
	return 列表

# 拍卖购买灵舟（纯灵石，唯一直接途径，跳过材料+时日）
func 拍卖购买灵舟(ship_id: String) -> Dictionary:
	var 在售 = 获取拍卖会灵舟()
	var 命中 = null
	for s in 在售:
		if str(s.get("ship_id", "")) == ship_id:
			命中 = s
			break
	if 命中 == null:
		return {"成功": false, "消息": "该灵舟不在拍卖会"}
	var 价 = int(命中.get("价", 0))
	if Game.灵石 < 价:
		return {"成功": false, "消息": "灵石不足（需%d）" % 价}
	Game.灵石 -= 价
	var 舟 = 宗门灵舟表.get(ship_id, null)
	if 舟 != null:
		灵舟库存.append({
			"ship_id": ship_id, "名称": str(舟.get("ship_name", "")), "tier": int(舟.get("tier", 0)),
			"ship_type": str(舟.get("ship_type", "")), "durability": int(舟.get("max_durability", 0)),
			"max_durability": int(舟.get("max_durability", 0)), "speed_bonus": float(舟.get("speed_bonus", 0)),
			"risk_reduce": float(舟.get("risk_reduce", 0)),
			"核心品阶": int(舟.get("required_core_tier", 1)), "阵法": [], "核心状态": "正常",
		})
		Game.添加纪事("拍卖", "购得灵舟", "于拍卖会力压群雄，以 %d 灵石拍得【%s】（出自 %s），此舟定能助我宗纵横四海！" % [价, str(舟.get("ship_name", "")), str(命中.get("卖家", ""))], 1)
	return {"成功": true, "消息": "以%d灵石拍得【%s】" % [价, str(舟.get("ship_name", ""))]}

# 拍卖出售本宗灵舟（换取灵石）
func 拍卖出售灵舟(索引: int, 价: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 灵舟库存.size():
		return {"成功": false, "消息": "灵舟库存索引越界"}
	var 舟 = 灵舟库存[索引]
	灵舟库存.remove_at(索引)
	Game.灵石 += 价
	Game.添加纪事("拍卖", "售出灵舟", "于拍卖会售出【%s】，得灵石 %d，此舟终觅明主。" % [str(舟.get("名称", "")), 价], 0)
	return {"成功": true, "消息": "售出【%s】，得灵石%d" % [str(舟.get("名称", "")), 价]}

# 通用灵舟奖励发放（秘境/斗法/成就等渠道调用）：直接入库存，无需材料+时日
func 发放灵舟奖励(ship_id: String) -> Dictionary:
	var 舟 = 宗门灵舟表.get(ship_id, null)
	if 舟 == null:
		return {"成功": false, "消息": "灵舟型号不存在"}
	灵舟库存.append({
		"ship_id": ship_id, "名称": str(舟.get("ship_name", "")), "tier": int(舟.get("tier", 0)),
		"ship_type": str(舟.get("ship_type", "")), "durability": int(舟.get("max_durability", 0)),
		"max_durability": int(舟.get("max_durability", 0)), "speed_bonus": float(舟.get("speed_bonus", 0)),
		"risk_reduce": float(舟.get("risk_reduce", 0)),
		"核心品阶": int(舟.get("required_core_tier", 1)), "阵法": [], "核心状态": "正常",
	})
	Game.添加纪事("奇遇", "灵舟现世", "于秘境/斗法之中获赠灵舟【%s】！" % str(舟.get("ship_name", "")), 2)
	return {"成功": true, "消息": "获得灵舟【%s】" % str(舟.get("ship_name", ""))}

# §11.15 阶段三·灵舟：能量核心品阶→物品中文名
func 灵舟核心物品名(品阶: int) -> String:
	var gid = 灵核品阶物品.get(品阶, "g021")
	return 灵材名称表.get(gid, gid)

# §11.15 阶段三·灵舟：聚合一艘灵舟的「有效属性」（基础 + 已刻阵法加成）
func 灵舟有效属性(舟: Dictionary) -> Dictionary:
	var 有效: Dictionary = {
		"speed_bonus": float(舟.get("speed_bonus", 0.0)),
		"risk_reduce": float(舟.get("risk_reduce", 0.0)),
		"max_durability": int(舟.get("max_durability", 0)),
		"war_power": int(舟.get("war_power", 0)),
		"有回灵": false,
	}
	for fid in 舟.get("阵法", []):
		var fm = 灵舟阵法表.get(str(fid), null)
		if fm == null:
			continue
		var dim = str(fm.get("effect_dim", ""))
		var val = float(fm.get("effect_val", 0.0))
		if dim == "speed":
			有效["speed_bonus"] += val
		elif dim == "risk":
			有效["risk_reduce"] += val
		elif dim == "durability":
			有效["max_durability"] += int(val)
		elif dim == "war":
			有效["war_power"] += int(val)
		elif dim == "regen":
			有效["有回灵"] = true
	return 有效

# §11.15 阶段三·灵舟：刻录阵法（消耗灵石+灵材，受阵法堂司职等级+槽位+特性门槛）
func 刻录灵舟阵法(索引: int, formation_id: String) -> Dictionary:
	if 索引 < 0 or 索引 >= 灵舟库存.size():
		return {"成功": false, "消息": "灵舟库存索引越界"}
	var 舟 = 灵舟库存[索引]
	var 舟定义 = 宗门灵舟表.get(str(舟.get("ship_id", "")), {})
	var fm = 灵舟阵法表.get(formation_id, null)
	if fm == null:
		return {"成功": false, "消息": "阵法不存在"}
	var 已刻 = 舟.get("阵法", [])
	if 已刻.size() >= int(舟定义.get("formation_slots", 0)):
		return {"成功": false, "消息": "灵舟阵法槽已满（%d/%d）" % [已刻.size(), int(舟定义.get("formation_slots", 0))]}
	if formation_id in 已刻:
		return {"成功": false, "消息": "该阵法已刻录"}
	# 虚空大阵仅「虚空」特性灵舟可刻（破虚神舰）
	if str(fm.get("category", "")) == "虚空" and not ("虚空" in str(舟定义.get("features", "")).split("|")):
		return {"成功": false, "消息": "仅「虚空」特性灵舟（破虚神舰）可刻录虚空大阵"}
	# 阵法堂司职等级门槛
	var 阵法堂等级: int = 1
	if Game.司职列表.has("zhenfa"):
		var v = Game.司职列表["zhenfa"].get("等级", 1)
		阵法堂等级 = int(v) if v != null else 1
	if 阵法堂等级 < int(fm.get("required_array_tier", 1)):
		return {"成功": false, "消息": "阵法堂品级不足（需 %d 品）" % int(fm.get("required_array_tier", 1))}
	var 费 = int(fm.get("cost_lingstone", 0))
	if Game.灵石 < 费:
		return {"成功": false, "消息": "灵石不足（需%d）" % 费}
	var 清单 = _解析材料清单(str(fm.get("cost_material", "")))
	for m in 清单:
		m["有"] = _库房灵材数量(m["名"])
	var 扣 = _扣灵材(清单)
	if not 扣.get("成功", false):
		return {"成功": false, "消息": "灵材不足：" + "、".join(扣.get("缺", []))}
	Game.灵石 -= 费
	已刻.append(formation_id)
	舟["阵法"] = 已刻
	Game.添加纪事("器殿", "灵舟刻阵", "于【%s】刻录【%s】" % [str(舟.get("名称", "")), str(fm.get("name", ""))], 1)
	return {"成功": true, "消息": "灵舟刻录【%s】成功" % str(fm.get("name", ""))}

# §11.15 阶段三·灵舟：补充能量核心（手动，耗 1 枚对应品阶核心恢复驱动）
func 补充灵舟核心(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 灵舟库存.size():
		return {"成功": false, "消息": "灵舟库存索引越界"}
	var 舟 = 灵舟库存[索引]
	if str(舟.get("核心状态", "正常")) == "正常":
		return {"成功": false, "消息": "灵舟核心状态正常，无需补充"}
	var 品阶 = int(舟.get("核心品阶", 1))
	var gid = 灵核品阶物品.get(品阶, "g021")
	var 名 = 灵材名称表.get(gid, gid)
	if _库房灵材数量(名) < 1:
		return {"成功": false, "消息": "宗门库房无【%s】（需1枚）" % 名}
	_扣灵材([{"id": gid, "名": 名, "需": 1, "有": 1}])
	舟["核心状态"] = "正常"
	Game.添加纪事("庶务", "灵舟补核", "为【%s】补充%s，恢复驱动" % [str(舟.get("名称", "")), 名], 1)
	return {"成功": true, "消息": "已为【%s】补充%s" % [str(舟.get("名称", "")), 名]}

# §11.15 阶段三·灵舟：重命名（每名仅一次机会，可于库存面板随时触发）
func 重命名灵舟(索引: int, 新名: String) -> Dictionary:
	if 索引 < 0 or 索引 >= 灵舟库存.size():
		return {"成功": false, "消息": "灵舟库存索引越界"}
	var 舟 = 灵舟库存[索引]
	var 余 = int(舟.get("可命名次数", 1))
	if 余 <= 0:
		return {"成功": false, "消息": "【%s】已无重命名机会（每舟仅可命名一次）" % str(舟.get("名称", ""))}
	var 名 = str(新名).strip_edges()
	if 名.is_empty():
		return {"成功": false, "消息": "灵舟名不可为空"}
	if 名.length() > 12:
		return {"成功": false, "消息": "灵舟名过长（限12字）"}
	var 旧名 = str(舟.get("名称", ""))
	舟["名称"] = 名
	舟["可命名次数"] = 余 - 1
	Game.添加纪事("庶务", "灵舟命名", "【%s】更名为【%s】" % [旧名, 名], 1)
	return {"成功": true, "消息": "已将【%s】更名为【%s】" % [旧名, 名]}

# §11.15 阶段三·灵舟：月度结算——灵石维护 + 能量核心消耗（驱使灵舟之耗，按月）
func _结算灵舟月度() -> void:
	var 总维护 = 0
	for 舟 in 灵舟库存:
		var 定义 = 宗门灵舟表.get(str(舟.get("ship_id", "")), {})
		总维护 += int(定义.get("monthly_maintain", 0))
		# 回灵聚气阵：自续核心，不耗宗门库房核心
		var 有回灵 = false
		for fid in 舟.get("阵法", []):
			var fm = 灵舟阵法表.get(str(fid), null)
			if fm != null and str(fm.get("effect_dim", "")) == "regen":
				有回灵 = true
		if 有回灵:
			舟["核心状态"] = "正常"
			continue
		var 品阶 = int(舟.get("核心品阶", 1))
		var gid = 灵核品阶物品.get(品阶, "g021")
		var 名 = 灵材名称表.get(gid, gid)
		if _库房灵材数量(名) >= 1:
			_扣灵材([{"id": gid, "名": 名, "需": 1, "有": 1}])
			舟["核心状态"] = "正常"
		else:
			舟["核心状态"] = "枯竭"
	if 总维护 > 0:
		Game.灵石 = max(0, Game.灵石 - 总维护)

# 黑市：魔道专属（设计 L105-106）；正道不可入，查缉命中扣正道声望+禁闭
func 黑市可交易() -> bool:
	return Game.正邪路线 == "九幽邪道" and 黑市禁闭日 <= 0

func 黑市违禁品列表() -> Array:
	var 表: Array = []
	for gid in 商队商品表.keys():
		var g = 商队商品表[gid]
		if int(g.get("is_illegal", 0)) == 1:
			表.append({"名": str(g.get("goods_name", "")), "单价": int(g.get("base_price", 0)) * 2})
	return 表

func 黑市出售(货物名: String, 数量: int = 1) -> Dictionary:
	if Game.正邪路线 != "九幽邪道":
		return {"成功": false, "消息": "黑市仅魔道势力可入（需择九幽邪道）"}
	if 黑市禁闭日 > 0:
		return {"成功": false, "消息": "正道执法封禁中（剩余%d天）" % 黑市禁闭日}
	var 目标 = null
	for gid in 商队商品表.keys():
		var g = 商队商品表[gid]
		if str(g.get("goods_name", "")) == 货物名 and int(g.get("is_illegal", 0)) == 1:
			目标 = g
			break
	if 目标 == null:
		return {"成功": false, "消息": "该货物非违禁品或不存在"}
	var 单价 = int(目标.get("base_price", 0)) * 2   # 黑市价差翻倍
	var 收益 = 单价 * max(1, 数量)
	Game.灵石 += 收益
	# 查缉判定：基础 15%，魔道声望越高越隐蔽
	var 查缉率 = clamp(0.15 - int(Game.阵营声望系统.阵营声望.get("魔道邪宗", 0)) / 5000.0, 0.03, 0.15)
	if randf() < 查缉率:
		黑市禁闭日 = 30
		Game.阵营声望系统.阵营声望["正道宗门"] = max(0, int(Game.阵营声望系统.阵营声望.get("正道宗门", 0)) - 50)
		Game.添加纪事("庶务", "黑市查缉", "黑市交易被正道执法队查获，遭禁闭30日，正道声望-50", 1)
		return {"成功": true, "消息": "黑市售出%s×%d获%d灵石，但被查获！禁闭30日" % [货物名, 数量, 收益], "收益": 收益, "查获": true}
	Game.添加纪事("庶务", "黑市交易", "于黑市售出%s×%d，获%d灵石" % [货物名, 数量, 收益], 1)
	return {"成功": true, "消息": "黑市售出%s×%d，获%d灵石" % [货物名, 数量, 收益], "收益": 收益}


# ===== §11.15 优化#73：黑市双线·正道特许线（非魔道势力亦可，低查缉/无查缉）=====
func 正道特许可交易() -> bool:
	return Game.正邪路线 != "九幽邪道"

func 正道特许商品列表() -> Array:
	return 正道特许商品表

func 正道特许出售(货物名: String, 数量: int = 1) -> Dictionary:
	if Game.正邪路线 == "九幽邪道":
		return {"成功": false, "消息": "正道特许仅向非魔道势力开放"}
	var 目标 = null
	for 物 in 正道特许商品表:
		if str(物.get("名", "")) == 货物名:
			目标 = 物
			break
	if 目标 == null:
		return {"成功": false, "消息": "该特许商品不存在"}
	var 单价 = int(目标.get("单价", 0))
	var 收益 = 单价 * max(1, 数量)
	Game.灵石 += 收益
	Game.添加纪事("庶务", "正道特许", "经正道特许渠道售出%s×%d，获%d灵石" % [货物名, 数量, 收益], 1)
	return {"成功": true, "消息": "正道特许售出%s×%d，获%d灵石" % [货物名, 数量, 收益], "收益": 收益}

# NPC 商队竞争：黄金商路（物价系数≥1.1）月度推演
func 黄金商路列表() -> Array:
	var 表: Array = []
	for 地区 in 商队地区:
		if float(地区.get("收购价", 1.0)) >= 1.1:
			表.append(地区)
	return 表

func _刷新商路竞争() -> void:
	for 地区 in 黄金商路列表():
		var cid = str(地区.get("id", ""))
		if not 商路竞争状态.has(cid):
			商路竞争状态[cid] = {"强度": randi_range(30, 80), "压价率": randf_range(0.10, 0.25), "策略": "压价"}
		else:
			var s = 商路竞争状态[cid]
			s["强度"] = clamp(int(s["强度"]) + randi_range(-10, 15), 10, 100)
			s["压价率"] = clamp(float(s["压价率"]) + randf_range(-0.03, 0.03), 0.0, 0.35)

func _检查独占(城市id: String) -> void:
	if not 商路竞争状态.has(城市id):
		return
	var s = 商路竞争状态[城市id]
	if float(s.get("压价率", 0.0)) <= 0.0:
		s["策略"] = "已独占"

func 商路竞争价格战(城市id: String) -> Dictionary:
	if not 商路竞争状态.has(城市id):
		return {"成功": false, "消息": "该商路无竞争者"}
	var s = 商路竞争状态[城市id]
	var 费 = 2000
	if Game.灵石 < 费:
		return {"成功": false, "消息": "灵石不足（需%d）" % 费}
	Game.灵石 -= 费
	s["压价率"] = clamp(float(s["压价率"]) - 0.08, 0.0, 0.35)
	_检查独占(城市id)
	return {"成功": true, "消息": "发动价格战，压价率降至%.0f%%" % [float(s["压价率"]) * 100]}

func 商路竞争打压(城市id: String) -> Dictionary:
	if not 商路竞争状态.has(城市id):
		return {"成功": false, "消息": "该商路无竞争者"}
	var s = 商路竞争状态[城市id]
	var 费 = 5000
	if Game.灵石 < 费:
		return {"成功": false, "消息": "灵石不足（需%d）" % 费}
	Game.灵石 -= 费
	s["强度"] = clamp(int(s["强度"]) - 30, 0, 100)
	if int(s["强度"]) <= 0:
		s["压价率"] = 0.0
	_检查独占(城市id)
	return {"成功": true, "消息": "打压对手，其强度降至%d" % int(s["强度"])}

func 商路竞争协商(城市id: String) -> Dictionary:
	if not 商路竞争状态.has(城市id):
		return {"成功": false, "消息": "该商路无竞争者"}
	var s = 商路竞争状态[城市id]
	var 费 = 3000
	if Game.灵石 < 费:
		return {"成功": false, "消息": "灵石不足（需%d）" % 费}
	Game.灵石 -= 费
	s["策略"] = "协商分润"
	s["压价率"] = clamp(float(s["压价率"]) * 0.5, 0.0, 0.35)
	return {"成功": true, "消息": "与对手协商分润，压价缓和至%.0f%%" % [float(s["压价率"]) * 100]}

# ===== §11.15 策略深度：商路声望 / 全局行情事件 辅助 =====
func _商路声望价差加成(地区id: String) -> float:
	var 阈值 = [0, 100, 500, 2000, 5000]
	var 加成 = [0.0, 0.03, 0.06, 0.10, 0.15]
	var rep = int(商路声望.get(地区id, 0))
	var tier = 0
	for i in range(阈值.size()):
		if rep >= 阈值[i]:
			tier = i
	return 加成[tier]

func _累加商路声望(地区id: String, 收益: int) -> void:
	商路声望[地区id] = int(商路声望.get(地区id, 0)) + max(1, int(收益 / 100))

# §11.15 优化：商队总声望（全局聚合，用于槽位解锁 / 阶梯封顶）
func _商队总声望() -> int:
	var tot = 0
	for v in 商路声望.values():
		tot += int(v)
	return tot

# §11.15 优化 + §11.20 修复：阶梯封顶倍率（毛收益口径 = 货值 × 倍率）
#   原 1.0~4.0x 会把基础加成（收购价×溢价×掌柜价差≈1.2x）削平 → 策略深度归零；
#   改为 1.5~4.5x：低声望也不削正常加成，高声望放开到 4.5x（此时收益主要靠跨域高物价城 + 溢价匹配）
func _商队收益封顶倍率() -> float:
	var tot = _商队总声望()
	var 阈值 = [0, 200, 600, 1500, 3500, 7000]
	var 倍率 = [1.5, 2.0, 2.5, 3.0, 3.5, 4.5]
	var m = 1.0
	for i in range(阈值.size()):
		if tot >= 阈值[i]:
			m = 倍率[i]
	return m

# §11.15 优化：贸易现实时间加速——多途径缩短单次贸易现实耗时（统一封顶系数）
func _阵法堂航速被动() -> float:
	var lv = 1
	if Game.司职列表.has("zhenfa"):
		var v = Game.司职列表["zhenfa"].get("等级", 1)
		lv = int(v) if v != null else 1
	return float(lv) * 阵法堂航速每级

func _声望航速被动() -> float:
	var 总 = _商队总声望()
	return min(声望航速上限, float(总) / 500.0 * 声望航速每500)

# 总速度加成 → 现实耗时秒（封顶 贸易最短时间系数）
func _计算贸易现实秒(总速度加成: float) -> int:
	var 系数 = clamp(1.0 / (1.0 + 总速度加成), 贸易最短时间系数, 1.0)
	return int(round(float(商队单次贸易现实秒) * 系数))

# §11.15 优化：仙玉即时完成贸易——消耗仙玉将本次贸易立即结算（仅时间加速，不破经济红线）
func 仙玉即时完成贸易(商队ID: int) -> Dictionary:
	for 商队 in 商队列表:
		if int(商队.get("id", -1)) == 商队ID and str(商队.get("状态", "")) == "派遣中":
			if Game.仙玉_非绑定 + Game.仙玉_绑定 < 仙玉即时完成费:
				return {"成功": false, "消息": "仙玉不足（需%d）" % 仙玉即时完成费}
			var 余 = 仙玉即时完成费
			if Game.仙玉_非绑定 >= 余:
				Game.仙玉_非绑定 -= 余
			else:
				var 先 = Game.仙玉_非绑定
				Game.仙玉_非绑定 = 0
				Game.仙玉_绑定 -= (余 - 先)
			商队["预计完成真实秒"] = int(Time.get_unix_time_from_system())
			结算到期商队()
			Game.添加纪事("神异", "仙玉催行", "以%d仙玉催动神行法，商队即刻返航" % 仙玉即时完成费, 1)
			return {"成功": true, "消息": "已消耗%d仙玉，贸易即时完成" % 仙玉即时完成费}
	return {"成功": false, "消息": "未找到该派遣中商队"}

# §11.15 优化：商队槽位数——初始1，随商队总声望解锁，最多6
func 商队槽位数() -> int:
	var tot = _商队总声望()
	var 阈值 = [0, 200, 600, 1500, 3500, 7000]
	var n = 1
	for i in range(阈值.size()):
		if tot >= 阈值[i]:
			n = i + 1
	return min(n, 6)

# §11.15 优化：每日派遣配额——= 槽位数 ×（1 + 月卡/季卡/永久卡增益）
func 商队每日配额() -> int:
	var 增益 = 0
	if Game.月卡有效() or Game.季卡有效() or Game.永久卡激活:
		增益 = 1
	return 商队槽位数() * (1 + 增益)

# §11.15 优化：每日配额按现实日重置（复用项目 real-time 范式）
func 刷新商队配额() -> void:
	var 现在 = int(Time.get_unix_time_from_system())
	if 现在 - 上次配额日真实秒 >= 86400:
		商队每日已派 = 0
		上次配额日真实秒 = 现在

func _行情事件倍率(地区: Dictionary) -> float:
	var m = 1.0
	for ev in 行情事件列表:
		if int(ev.get("剩余天数", 0)) > 0 and str(ev.get("地区", "")) == str(地区.get("id", "")):
			for 偏好 in 地区.get("偏好类别", []):
				if str(ev.get("品类", "")) == 偏好:
					m = max(m, float(ev.get("倍率", 1.0)))
	return m

# §商道P1 行情可视化：分品类行情查询（纯读取，不改结算逻辑）
func 获取城市行情(地区id: String) -> Array:
	var 结果: Array = []
	var 类别清单: Array = ["灵草", "矿石", "妖兽材", "丹药", "法器", "天材地宝"]
	var 目标 = null
	for 地区 in 商队地区:
		if str(地区.get("id", "")) == str(地区id) or str(地区.get("名称", "")) == str(地区id):
			目标 = 地区
			break
	if 目标 == null:
		return 结果
	var 地区名 = str(目标.get("名称", ""))
	var 地区编号 = str(目标.get("id", ""))
	for 类别 in 类别清单:
		var m = 1.0
		for ev in 行情事件列表:
			if int(ev.get("剩余天数", 0)) > 0:
				var ev地 = str(ev.get("地区", ""))
				if (ev地 == 地区名 or ev地 == 地区编号) and str(ev.get("品类", "")) == 类别:
					m = max(m, float(ev.get("倍率", 1.0)))
		var 状态 = "平稳"
		if m <= 0.8:
			状态 = "低迷"
		elif m <= 0.95:
			状态 = "偏低"
		elif m >= 1.2:
			状态 = "暴涨"
		elif m > 1.0:
			状态 = "偏高"
		结果.append({"类别": 类别, "倍率": m, "状态": 状态})
	return 结果

func 获取行情一览() -> Array:
	var 总览: Array = []
	for 地区 in 商队地区:
		var rid = str(地区.get("id", ""))
		if not 检查商路城市解锁(str(地区.get("unlock_condition", "")), rid):
			continue
		总览.append({"地区名": str(地区.get("名称", "")), "行情": 获取城市行情(rid)})
	return 总览

# §11.15 数据驱动：解析城市/商路 unlock_condition / unlock_need
func 检查商路城市解锁(条件: String, 地区id: String = "") -> bool:
	if 条件.strip_edges() == "" or 条件.strip_edges() == "none":
		return true
	var 项列表 = 条件.split(" AND ", false)
	for 项 in 项列表:
		var t = str(项).strip_edges()
		if t == "":
			continue
		# sect_level=N / sect_level>=N
		if t.begins_with("sect_level"):
			var 需 = int(t.split("=")[-1])
			if Game.门派等级 < 需:
				return false
		elif t.begins_with("has_shop"):
			# 交易市场（坊市）系统已存在，视为满足
			pass
		elif t.begins_with("has_ship"):
			# §11.15 阶段三：已实装灵舟坞；已建坞(has_ship)才解锁跨域城 7/8
			if 灵舟坞等级 <= 0:
				return false
		elif t.begins_with("reputation"):
			# 本地区商路声望
			var 需 = int(t.split("=")[-1]) if "=" in t else int(t.split(">=")[-1])
			if int(商路声望.get(地区id, 0)) < 需:
				return false
		else:
			push_warning("未知商路解锁条件: %s" % t)
	return true

func _刷新行情事件() -> void:
	# §11.15 策略深度：每月 1~2 次全局行情事件（独立队列，不污染 EventManager）
	var 池 = [
		{"地区": "附近城镇", "品类": "灵草", "倍率": 1.4, "天数": 8, "名": "灵草疫疾，药价飙升"},
		{"地区": "修真集市", "品类": "矿石", "倍率": 1.5, "天数": 10, "名": "矿脉告急，矿石暴涨"},
		{"地区": "仙城坊市", "品类": "法器", "倍率": 1.6, "天数": 12, "名": "法器盛会，法器稀缺"},
		{"地区": "秘境边境", "品类": "天材地宝", "倍率": 1.8, "天数": 15, "名": "天材地宝争夺战"},
		{"地区": "仙城坊市", "品类": "法器", "倍率": 0.7, "天数": 10, "名": "法器滞销，价格承压"},
		{"地区": "修真集市", "品类": "矿石", "倍率": 0.75, "天数": 9, "名": "矿石过剩，行情走低"},
	]
	var 次数 = 1 + int(randf() * 2)
	for _n in range(次数):
		var t = 池[randi() % 池.size()]
		var 重复 = false
		for ev in 行情事件列表:
			if str(ev.get("地区", "")) == t["地区"] and str(ev.get("品类", "")) == t["品类"]:
				重复 = true
				break
		if 重复:
			continue
		var ev = {"地区": t["地区"], "品类": t["品类"], "倍率": t["倍率"], "剩余天数": t["天数"], "名": t["名"]}
		行情事件列表.append(ev)
		Game.添加纪事("庶务", "行情事件", "商路行情：%s" % t["名"], 1)
# ===== §商道深化：商铺经营 / 护卫专长 / 稀有商品 / 周常 / 消耗品 =====
# 境界→等级上限 / 可开类型
func 商铺等级上限() -> int:
	return int(商铺等级上限表.get(商道境界, 3))

func _境界所需经验(境: String) -> int:
	for 行 in 商道境界表:
		if str(行.get("境界", "")) == 境:
			return int(行.get("所需经验", 0))
	return 0

func 可开商铺类型() -> Array:
	var 可: Array = []
	for 类型 in 商铺配置.keys():
		if 商道经验 >= _境界所需经验(商铺配置[类型].get("解锁境界", "")):
			可.append(类型)
	return 可

# P2 商铺：开设 / 升级 / 关闭
func 开设商铺(城市ID: String, 类型: String) -> Dictionary:
	if not 商铺配置.has(类型):
		return {"成功": false, "消息": "未知商铺类型"}
	var 需经 = _境界所需经验(商铺配置[类型].get("解锁境界", ""))
	if 商道经验 < 需经:
		return {"成功": false, "消息": "商道境界不足（需%s）" % 商铺配置[类型].get("解锁境界", "")}
	var 地区 = null
	for d in 商队地区:
		if d["id"] == 城市ID:
			地区 = d
			break
	if 地区 == null:
		return {"成功": false, "消息": "该城尚未开通商路"}
	for 铺 in 商铺列表:
		if str(铺.get("城市ID", "")) == 城市ID and str(铺.get("类型", "")) == 类型:
			return {"成功": false, "消息": "该城已开设同类商铺"}
	var 费 = int(商铺配置[类型].get("基础产出", 50)) * 10
	if Game.灵石 < 费:
		return {"成功": false, "消息": "开设灵石不足（需%d）" % 费}
	Game.灵石 -= 费
	商铺列表.append({"城市ID": 城市ID, "类型": 类型, "等级": 1, "主营": 商铺配置[类型].get("主营", "")})
	Game.添加纪事("商道", "开设商铺", "于%s开设%s，自此商道又进一步" % [str(地区.get("名称", "")), 类型], 1)
	return {"成功": true, "消息": "于%s开设%s成功" % [str(地区.get("名称", "")), 类型]}

func 升级商铺(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 商铺列表.size():
		return {"成功": false, "消息": "商铺索引越界"}
	var 铺 = 商铺列表[索引]
	var 上限 = 商铺等级上限()
	var 级 = int(铺.get("等级", 1))
	if 级 >= 上限:
		return {"成功": false, "消息": "已达本境界品级上限（%d品）" % 上限}
	if 级 >= 10:
		return {"成功": false, "消息": "商铺已满级"}
	var 费 = int(商铺配置.get(铺.get("类型", ""), {}).get("基础产出", 50)) * 级 * 5
	if Game.灵石 < 费:
		return {"成功": false, "消息": "升级灵石不足（需%d）" % 费}
	Game.灵石 -= 费
	铺["等级"] = 级 + 1
	Game.添加纪事("商道", "商铺升级", "%s升至%d级，日进斗金" % [str(铺.get("类型", "")), 级 + 1], 1)
	return {"成功": true, "消息": "%s升至%d级" % [str(铺.get("类型", "")), 级 + 1]}

func 关闭商铺(索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 商铺列表.size():
		return {"成功": false, "消息": "商铺索引越界"}
	var 铺 = 商铺列表[索引]
	商铺列表.remove_at(索引)
	var 返 = int(商铺配置.get(铺.get("类型", ""), {}).get("基础产出", 50)) * int(铺.get("等级", 1)) * 3
	Game.灵石 += 返
	Game.添加纪事("商道", "关闭商铺", "关闭%s，返还灵石%d" % [str(铺.get("类型", "")), 返], 0)
	return {"成功": true, "消息": "关闭%s，返还灵石%d" % [str(铺.get("类型", "")), 返]}

# P2 商铺放置产出：每日自动结算（真实消耗闭环：自动从宗门库房扣主营货物，否则当日不出产；产出过经济阀门防通胀）
func 结算商铺产出() -> void:
	for 铺 in 商铺列表:
		var 配置 = 商铺配置.get(铺.get("类型", ""), {})
		var 基础 = float(配置.get("基础产出", 50))
		var 级 = float(铺.get("等级", 1))
		var 需求 = int(基础 * 级 * 0.2)   # 每日耗货量 [PLACEHOLDER]
		var 类型集 = _主营匹配类型(str(铺.get("主营", "")))
		var 扣了 = 0
		var i = 0
		while i < Game.宗门库房.size() and 扣了 < 需求:
			var it = Game.宗门库房[i]
			if it is Item and str(it.类别) in 类型集:
				Game.宗门库房.remove_at(i)
				扣了 += 1
			else:
				i += 1
		if 扣了 < 需求:
				continue   # 货不足，当日不出产
		var 系数 = 1.0
		for d in 商队地区:
			if d["id"] == 铺.get("城市ID", ""):
				系数 = float(d.get("当前收购价", d.get("收购价", 1.0)))
				break
		var 日产 = int(基础 * 级 * 系数 * (1.0 + 获取商道境界加成()))
		var 净 = int(EconomyBalance.new().平衡(float(日产)))
		Game.灵石 += 净
		Game.添加纪事("庶务", "商铺进项", "%s（%d级）日进灵石%d" % [str(铺.get("类型", "")), int(级), 净], 0)

func _主营匹配类型(主营: String) -> Array:
	match 主营:
		"妖兽材": return ["妖兽"]
		"灵草": return ["材料"]
		"矿石": return ["材料"]
		"法器": return ["法器"]
		"丹药": return ["丹药"]
		"符箓": return ["材料"]
		"稀有": return ["丹药", "法器", "妖兽", "材料"]
	return ["材料"]

# P3 护卫专长加成（按弟子道途映射，纯加乘区，不碰核心结算）
func 计算护卫专长收益加成(人员: Array) -> float:
	var 加成 = 0.0
	for 人 in 人员:
		var d = _取弟子(int(人.get("弟子ID", -1)))
		if d == null:
			continue
		match str(d.道途):
			"符箓师", "傀儡师": 加成 += 0.10   # 商道类：周转快，收益+10%
			"毒师": 加成 += 0.15              # 丹道类：对应商品+15%
			"法修": 加成 += 0.15              # 器道类：法器+15%
	return 加成

func 计算护卫专长风险减免(人员: Array) -> float:
	var 减免 = 0.0
	for 人 in 人员:
		var d = _取弟子(int(人.get("弟子ID", -1)))
		if d == null:
			continue
		match str(d.道途):
			"符箓师", "傀儡师": 减免 += 0.10   # 商道类：风险-10%
			"体修", "御兽师": 减免 += 0.20   # 武道类：风险-20%
	return 减免

# P3 稀有商品捡漏（仅跨域/高风险商路+境界>=老练商人；入宗主背包+商道录图录+周常稀有标记）
func 触发稀有商品(商队: Dictionary) -> void:
	if 商道经验 < 500:
		return   # 至少老练商人
	var 地区 = null
	for d in 商队地区:
		if d["id"] == 商队["地区"]:
			地区 = d
			break
	if 地区 == null:
		return
	var 跨域 = int(地区.get("city_level", 1)) >= 4
	var 高风险 = float(地区.get("风险", 0.1)) >= 0.25
	if not 跨域 and not 高风险:
		return
	for 物 in 稀有商品表:
		if randf() < float(物.get("概率", 0.0)):
			var 名 = str(物.get("名", ""))
			var it: Item = Item.new()
			it.名称 = 名
			it.品阶 = str(物.get("品阶", "灵品"))
			it.类别 = "商道奇珍"
			if Game.弟子列表.size() > 0:
				Game.弟子列表[0].背包.append(it)
			Game._记录图录(名, "商道")
			Game.添加纪事("商道", "捡漏", "商队于%s淘得稀世奇珍【%s】，价值连城！" % [地区["名称"], 名], 3)
			商道周常本周稀有 = true
			return

# 商道周常 贸易大赛（参与上限3/周，威望走 Game.宗主威望，防通胀）
func 参与贸易大赛() -> Dictionary:
	var 周序 = int(Game.累计游戏日 / 7) % 4
	if 商道周常上周序 != 周序:
		商道周常上周序 = 周序
		商道周常本周参与 = 0
		商道周常本周稀有 = false
	if 商道周常本周参与 >= 3:
		return {"成功": false, "消息": "本周贸易大赛已参与满3次"}
	商道周常本周参与 += 1
	Game.宗主威望 += 30
	Game.添加纪事("商道", "贸易大赛", "参与宗门商道会贸易大赛，商道声望大涨，威望+30", 1)
	return {"成功": true, "消息": "参与贸易大赛成功，威望+30（本周%d/3）" % 商道周常本周参与}

# 商道消耗品 sink：求购（走宗门库房，灵石购货）
func 求购商道令() -> Dictionary:
	return _求购商道消耗品("商道令")
func 求购通商符() -> Dictionary:
	return _求购商道消耗品("通商符")
func 求购拜帖() -> Dictionary:
	return _求购商道消耗品("拜帖")
func _求购商道消耗品(名: String) -> Dictionary:
	if not 商道消耗品配置.has(名):
		return {"成功": false, "消息": "未知商道消耗品"}
	var 价 = int(商道消耗品配置[名].get("价格", 0))
	if Game.灵石 < 价:
		return {"成功": false, "消息": "灵石不足（需%d）" % 价}
	Game.灵石 -= 价
	var it: Item = Item.new()
	it.名称 = 名
	it.品阶 = "灵品"
	it.类别 = "商道消耗"
	if Game.弟子列表.size() > 0:
		Game.弟子列表[0].背包.append(it)
	Game.添加纪事("商道", "求购消耗", "于商道求购%s×1" % 名, 1)
	return {"成功": true, "消息": "求购%s成功（%d灵石）" % [名, 价]}

# ===== S57 玩家间交易（委托商队运输）=====
# 发起交易
func 发起玩家交易(买家ID: String, 买家名称: String, 物品列表: Array, 价格: int, 运输方式: String, 货到付款: bool = false) -> Dictionary:
	if 物品列表.is_empty():
		return {"成功": false, "原因": "物品列表为空"}
	if 价格 < 0:
		return {"成功": false, "原因": "价格不能为负"}
	if 运输方式 not in 玩家运输配置:
		return {"成功": false, "原因": "无效的运输方式"}
	var 配置: Dictionary = 玩家运输配置[运输方式]
	var 运输费用: int = 0
	var 灵晶费用: int = 0
	if 运输方式 == "传送阵":
		灵晶费用 = int(配置["灵晶费用"])
		if Game.仙玉_绑定 < 灵晶费用:
			return {"成功": false, "原因": "灵晶不足，需%d灵晶" % 灵晶费用}
		Game.仙玉_绑定 -= 灵晶费用
	else:
		运输费用 = max(int(配置["最低费用"]), int(float(价格) * float(配置["费用比例"])))
		if Game.灵石 < 运输费用:
			return {"成功": false, "原因": "灵石不足，需%d灵石运费" % 运输费用}
		Game.灵石 -= 运输费用
	var 交易: Dictionary = {
		"id": "trade_%d_%d" % [Game.累计游戏日, randi() % 100000],
		"卖家ID": "玩家",
		"卖家名称": Game.宗主名,
		"买家ID": 买家ID,
		"买家名称": 买家名称,
		"物品列表": 物品列表,
		"价格": 价格,
		"运输方式": 运输方式,
		"运输费用": 运输费用,
		"灵晶费用": 灵晶费用,
		"货到付款": 货到付款,
		"状态": 交易状态_待确认,
		"发起日": Game.累计游戏日,
		"预计送达日": 0,
		"完成日": 0,
		"买家已确认": false,
		"卖家已确认": true,
	}
	if 运输方式 == "传送阵":
		交易["状态"] = 交易状态_待收货
		交易["预计送达日"] = Game.累计游戏日
	else:
		# S58：运输时间基于买卖双方宗门距离动态计算
		var 模拟买家位置: Dictionary = _模拟买家位置(买家ID)
		var 距离: float = Game.世界地图系统.计算宗门间距离(
			Game.世界地图系统.宗门区域,
			Game.世界地图系统.宗门坐标X,
			Game.世界地图系统.宗门坐标Y,
			模拟买家位置["区域"],
			模拟买家位置["x"],
			模拟买家位置["y"]
		)
		var 运输时间: int = Game.世界地图系统.计算运输时间(距离, 运输方式)
		交易["预计送达日"] = Game.累计游戏日 + 运输时间
		交易["运输距离"] = 距离
	玩家交易列表.push_front(交易)
	玩家运输中列表.append(交易)
	if 玩家交易列表.size() > 最大玩家交易记录:
		玩家交易列表.pop_back()
	Game.消息系统.发送密语传音("交易委托", "您委托%s向%s运送%d件物品，价值%d灵石。" % [运输方式, 买家名称, 物品列表.size(), 价格], "商队掌柜")
	return {"成功": true, "交易": 交易, "运输费用": 运输费用, "灵晶费用": 灵晶费用}

# 买家确认交易
func 买家确认玩家交易(交易ID: String) -> Dictionary:
	var 交易: Dictionary = _找玩家交易(交易ID)
	if 交易.is_empty():
		return {"成功": false, "原因": "交易不存在"}
	if str(交易.get("状态", "")) != 交易状态_待确认:
		return {"成功": false, "原因": "交易状态不正确"}
	交易["买家已确认"] = true
	交易["状态"] = 交易状态_运输中
	if bool(交易.get("货到付款", false)):
		var 价格: int = int(交易.get("价格", 0))
		if Game.灵石 < 价格:
			return {"成功": false, "原因": "灵石不足，需支付%d灵石" % 价格}
		Game.灵石 -= 价格
		交易["货款已付"] = true
	Game.消息系统.发送密语传音("交易确认", "买家已确认交易，物品正在运输中。", "商队掌柜")
	return {"成功": true, "交易": 交易}

# 确认收货
func 确认玩家收货(交易ID: String) -> Dictionary:
	var 交易: Dictionary = _找玩家交易(交易ID)
	if 交易.is_empty():
		return {"成功": false, "原因": "交易不存在"}
	if str(交易.get("状态", "")) != 交易状态_待收货:
		return {"成功": false, "原因": "交易状态不正确，当前状态：%s" % str(交易.get("状态", ""))}
	交易["状态"] = 交易状态_已完成
	交易["完成日"] = Game.累计游戏日
	_从玩家运输中移除(交易ID)
	if bool(交易.get("货到付款", false)) and bool(交易.get("货款已付", false)):
		var 价格: int = int(交易.get("价格", 0))
		Game.灵石 += 价格
		交易["货款已结算"] = true
	Game.消息系统.发送密语传音("交易完成", "买家已确认收货，交易完成。", "商队掌柜")
	return {"成功": true, "交易": 交易}

# 取消交易
func 取消玩家交易(交易ID: String) -> Dictionary:
	var 交易: Dictionary = _找玩家交易(交易ID)
	if 交易.is_empty():
		return {"成功": false, "原因": "交易不存在"}
	var 状态: String = str(交易.get("状态", ""))
	if 状态 == 交易状态_已完成 or 状态 == 交易状态_已被劫:
		return {"成功": false, "原因": "交易已结束，无法取消"}
	if 状态 == 交易状态_运输中:
		return {"成功": false, "原因": "物品已在运输途中，无法取消"}
	交易["状态"] = 交易状态_已取消
	交易["完成日"] = Game.累计游戏日
	_从玩家运输中移除(交易ID)
	var 运输费用: int = int(交易.get("运输费用", 0))
	if 运输费用 > 0:
		Game.灵石 += int(运输费用 * 0.5)
	var 灵晶费用: int = int(交易.get("灵晶费用", 0))
	if 灵晶费用 > 0:
		Game.仙玉_绑定 += int(灵晶费用 * 0.5)
	if bool(交易.get("货款已付", false)):
		var 价格: int = int(交易.get("价格", 0))
		Game.灵石 += 价格
	Game.消息系统.发送密语传音("交易取消", "交易已取消，退还50%运输费用。", "商队掌柜")
	return {"成功": true, "交易": 交易}

# 每日推进：检查运输到达和被劫
func 玩家交易每日推进() -> void:
	var 到达列表: Array = []
	var 被劫列表: Array = []
	for 交易 in 玩家运输中列表:
		var 状态: String = str(交易.get("状态", ""))
		if 状态 != 交易状态_运输中 and 状态 != 交易状态_待确认:
			continue
		var 预计送达日: int = int(交易.get("预计送达日", 0))
		var 运输方式: String = str(交易.get("运输方式", ""))
		var 配置: Dictionary = 玩家运输配置.get(运输方式, {})
		if 状态 == 交易状态_运输中:
			var 被劫风险: float = float(配置.get("被劫风险", 0.0))
			var 每日风险: float = 被劫风险 / max(1, int(配置.get("运输时间_max", 7)))
			if randf() < 每日风险:
				交易["状态"] = 交易状态_已被劫
				交易["完成日"] = Game.累计游戏日
				var 赔偿比例: float = float(配置.get("赔偿比例", 0.5))
				var 价格: int = int(交易.get("价格", 0))
				var 赔偿: int = int(float(价格) * 赔偿比例)
				Game.灵石 += 赔偿
				交易["赔偿金额"] = 赔偿
				被劫列表.append(交易)
				Game.消息系统.发送密语传音("商队被劫", "您的商队在途中被劫！获得赔偿%d灵石。" % 赔偿, "商队掌柜")
				continue
		if Game.累计游戏日 >= 预计送达日:
			if 状态 == 交易状态_待确认:
				continue
			交易["状态"] = 交易状态_待收货
			到达列表.append(交易)
			Game.消息系统.发送密语传音("物品送达", "您的物品已送达，请确认收货。", "商队掌柜")
	for 交易 in 被劫列表:
		_从玩家运输中移除(str(交易.get("id", "")))
	for 交易 in 到达列表:
		_从玩家运输中移除(str(交易.get("id", "")))

# 查询函数
func 获取玩家交易列表(数量: int = 50) -> Array:
	return 玩家交易列表.slice(0, min(数量, 玩家交易列表.size()))
func 获取玩家运输中列表() -> Array:
	return 玩家运输中列表.duplicate()
func 获取玩家待收货列表() -> Array:
	var 结果: Array = []
	for 交易 in 玩家交易列表:
		if str(交易.get("状态", "")) == 交易状态_待收货:
			结果.append(交易)
	return 结果

# 辅助函数
func _找玩家交易(交易ID: String) -> Dictionary:
	for 交易 in 玩家交易列表:
		if str(交易.get("id", "")) == 交易ID:
			return 交易
	return {}

# S58-P2：区域商路加成（西域商路要冲+25%、东域海运发达+20%、中州+15%、南疆+5%、北域+0%）
func _区域商路加成() -> float:
	if Game.世界地图系统 == null:
		return 0.0
	return float(Game.世界地图系统.获取当前区域特性().get("商路加成", 0.0))

# S58：模拟买家位置（基于买家ID生成稳定的随机位置）
func _模拟买家位置(买家ID: String) -> Dictionary:
	# 使用买家ID的哈希值作为种子，生成稳定的位置
	var 哈希: int = 0
	for c in 买家ID:
		哈希 = (哈希 * 31 + c.unicode_at(0)) % 1000000
	var 区域索引: int = 哈希 % 5
	var 区域: String = Game.世界地图系统.所有区域[区域索引]
	var x: float = float((哈希 / 7) % 400) - 200.0
	var y: float = float((哈希 / 13) % 400) - 200.0
	return {"区域": 区域, "x": x, "y": y}
func _从玩家运输中移除(交易ID: String) -> void:
	for i in range(玩家运输中列表.size() - 1, -1, -1):
		if str(玩家运输中列表[i].get("id", "")) == 交易ID:
			玩家运输中列表.remove_at(i)
			break

# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["商队列表"] = 商队列表
	data["商队历史"] = 商队历史
	data["商队ID计数器"] = 商队ID计数器
	data["商队岗位表"] = 商队岗位表
	data["商队载具表"] = 商队载具表
	data["商队地区"] = 商队地区
	data["商队城市表"] = 商队城市表
	data["商队商路表"] = 商队商路表
	data["商队商品表"] = 商队商品表
	data["商队事件库"] = 商队事件库
	data["商队每日已派"] = 商队每日已派
	data["上次配额日真实秒"] = 上次配额日真实秒
	data["上次行情日真实秒"] = 上次行情日真实秒
	data["灵舟坞等级"] = 灵舟坞等级
	data["灵舟坞表"] = 灵舟坞表
	data["宗门灵舟表"] = 宗门灵舟表
	data["灵舟库存"] = 灵舟库存
	data["灵舟坞建造中"] = 灵舟坞建造中
	data["灵舟建造队列"] = 灵舟建造队列
	data["灵材名称表"] = 灵材名称表
	data["灵舟阵法表"] = 灵舟阵法表
	data["虚空大阵冷却日"] = 虚空大阵冷却日
	data["黑市禁闭日"] = 黑市禁闭日
	data["商路竞争状态"] = 商路竞争状态
	data["商路声望"] = 商路声望
	data["行情事件列表"] = 行情事件列表
	data["累计贸易次数"] = 累计贸易次数
	data["累计贸易收益"] = 累计贸易收益
	data["商道经验"] = 商道经验
	data["商道境界"] = 商道境界
	data["商铺列表"] = 商铺列表
	data["商道周常本周参与"] = 商道周常本周参与
	data["商道周常上周序"] = 商道周常上周序
	data["商道周常本周稀有"] = 商道周常本周稀有
	data["玩家交易列表"] = 玩家交易列表
	data["玩家运输中列表"] = 玩家运输中列表
	return data

func from_dict(data: Dictionary) -> void:
	if "商队列表" in data:
		商队列表 = data["商队列表"]
	if "商队历史" in data:
		商队历史 = data["商队历史"]
	if "商队ID计数器" in data:
		商队ID计数器 = data["商队ID计数器"]
	if "商队岗位表" in data:
		商队岗位表 = data["商队岗位表"]
	if "商队载具表" in data:
		商队载具表 = data["商队载具表"]
	if "商队地区" in data:
		商队地区 = data["商队地区"]
	if "商队城市表" in data:
		商队城市表 = data["商队城市表"]
	if "商队商路表" in data:
		商队商路表 = data["商队商路表"]
	if "商队商品表" in data:
		商队商品表 = data["商队商品表"]
	if "商队事件库" in data:
		商队事件库 = data["商队事件库"]
	if "商队每日已派" in data:
		商队每日已派 = data["商队每日已派"]
	if "上次配额日真实秒" in data:
		上次配额日真实秒 = data["上次配额日真实秒"]
	if "上次行情日真实秒" in data:
		上次行情日真实秒 = data["上次行情日真实秒"]
	if "灵舟坞等级" in data:
		灵舟坞等级 = data["灵舟坞等级"]
	if "灵舟坞表" in data:
		灵舟坞表 = data["灵舟坞表"]
	if "宗门灵舟表" in data:
		宗门灵舟表 = data["宗门灵舟表"]
	if "灵舟库存" in data:
		灵舟库存 = data["灵舟库存"]
	if "灵舟坞建造中" in data:
		灵舟坞建造中 = data["灵舟坞建造中"]
	if "灵舟建造队列" in data:
		灵舟建造队列 = data["灵舟建造队列"]
	if "灵材名称表" in data:
		灵材名称表 = data["灵材名称表"]
	if "灵舟阵法表" in data:
		灵舟阵法表 = data["灵舟阵法表"]
	if "虚空大阵冷却日" in data:
		虚空大阵冷却日 = data["虚空大阵冷却日"]
	if "黑市禁闭日" in data:
		黑市禁闭日 = data["黑市禁闭日"]
	if "商路竞争状态" in data:
		商路竞争状态 = data["商路竞争状态"]
	if "商路声望" in data:
		商路声望 = data["商路声望"]
	if "行情事件列表" in data:
		行情事件列表 = data["行情事件列表"]
	if "累计贸易次数" in data:
		累计贸易次数 = data["累计贸易次数"]
	if "累计贸易收益" in data:
		累计贸易收益 = data["累计贸易收益"]
	if "商道经验" in data:
		商道经验 = int(data["商道经验"])
	if "商道境界" in data:
		商道境界 = str(data["商道境界"])
	if "商铺列表" in data:
		商铺列表 = data["商铺列表"]
	if "商道周常本周参与" in data:
		商道周常本周参与 = int(data["商道周常本周参与"])
	if "商道周常上周序" in data:
		商道周常上周序 = int(data["商道周常上周序"])
	if "商道周常本周稀有" in data:
		商道周常本周稀有 = bool(data["商道周常本周稀有"])
	if "玩家交易列表" in data:
		玩家交易列表 = data["玩家交易列表"]
	if "玩家运输中列表" in data:
		玩家运输中列表 = data["玩家运输中列表"]
