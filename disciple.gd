# disciple.gd —— 弟子数据类（M1.5：突破进度 / 筑基判定职业 / 堂口 / 加成评分 / 效果表）
class_name Disciple
extends RefCounted

const Item = preload("res://item.gd")
const Beast = preload("res://beast.gd")
const Lore = preload("res://lore.gd")
const DestinyDataLoader = preload("res://DestinyDataLoader.gd")

const 资质表: Dictionary = {
	"fan_su": {"上限": "练气", "速度": 1.0},
	"pingyong": {"上限": "筑基", "速度": 1.4},
	"youliang": {"上限": "金丹", "速度": 1.8},
	"tiancai": {"上限": "元婴", "速度": 2.5},
	"yaonie": {"上限": "化神", "速度": 3.5},
	"kuangshi": {"上限": "道阶", "速度": 4.8},
}
const 资质显示: Dictionary = {"fan_su": "凡俗", "pingyong": "平庸", "youliang": "优良", "tiancai": "天才", "yaonie": "妖孽", "kuangshi": "旷世"}
# 资质→终身境界天花板（终局机制 P0：资质决定根骨上限，灵根只决定到达速度）
# 凡俗止步金丹、平庸止步元婴、优良止步化神、天才止步仙阶、妖孽/旷世可冲道阶
const 资质境界天花板: Dictionary = {
	"fan_su": "金丹", "pingyong": "元婴", "youliang": "化神",
	"tiancai": "仙阶", "yaonie": "道阶", "kuangshi": "道阶",
}
const 资质权重: Dictionary = {"fan_su": 50.0, "pingyong": 30.0, "youliang": 14.0, "tiancai": 5.0, "yaonie": 0.9, "kuangshi": 0.1}

const 灵根五行: Array = ["金", "木", "水", "火", "土"]
const 灵根变异: Array = ["雷", "冰", "风", "光", "暗"]
# 命格系统（重构）：命格由 destiny_id 驱动，配置见 config/destiny_main.csv + DestinyDataLoader.gd
# 旧档「命格名」→ destiny_id 映射（兼容从字符串名升级）
const 旧命格映射: Dictionary = {
	"战狂":"D_ZHANWANG","剑痴":"D_JIANCHI","战体":"D_ZHANTI","武曲":"D_WUQU","将星":"D_JIANGXING",
	"福星":"D_FUXING","寻宝":"D_XUNBAO","商道":"D_SHANGDAO","聚灵":"D_JULING","丹心":"D_DANXIN",
	"匠心":"D_JIANGXIN","书香":"D_SHUXIANG","阵道":"D_ZHENDAO","符道":"D_FUDAO","御兽":"D_YUSHOU",
	"长生":"D_CHANGSHENG","桃花":"D_TAOHUA","衰星":"D_SHUAIXING","孤煞":"D_GUSHA","血光":"D_XUEGUANG",
	"天命":"D_JIANCHI",  # 旧「天命」特殊命格 → 极品战斗命格兜底（老大 2026-07-19 拍板）
}
# 资质（弟子基础品质，6档）→ 命格品质档（4档）
const 资质到品质档: Dictionary = {
	"fan_su":"凡品","pingyong":"凡品","youliang":"良品","tiancai":"良品","yaonie":"上品","kuangshi":"极品"
}
# 品质档 → 命格品级抽取权重（老大 2026-07-19 拍板）
const 品质档命格权重: Dictionary = {
	"凡品": {"凡品":90.0,"良品":10.0},
	"良品": {"凡品":30.0,"良品":60.0,"上品":10.0},
	"上品": {"良品":40.0,"上品":50.0,"极品":10.0},
	"极品": {"上品":40.0,"极品":60.0},
}
# 十二修仙性格：独立显示字段，决定日后道号与奇遇/任务抉择（不替代命格）
const 性格表: Array = ["沉稳守道","锐意争先","恬淡悟道","桀骜不羁","仁心济世","杀伐果断",
				"谨慎多疑","豪迈仗义","孤僻清修","贪心逐缘","守礼尊师","狂傲绝世"]

# 全部职业：基础 3（开局可招）+ 后期解锁 4（门派达品阶后解锁）
const 职业名: Array = ["道修","体修","法修","御兽师","符箓师","毒师","傀儡师"]
const 职业天赋: Dictionary = {
	"道修": "极速破防、斩灵克法",
	"体修": "厚血高防、近战碾压",
	"法修": "远程群攻、道法制衡",
	"御兽师": "灵兽协同、兽魂增益",
	"符箓师": "符箓术法、范围控场",
	"毒师": "毒伤持续、减益削弱",
	"傀儡师": "傀儡代战、机关增幅",
}
# 职业初始属性权重（攻/防/血/速，合计=1）：总属性不变，仅侧重不同；""=未入门中性权重
const 职业属性权重: Dictionary = {
	"": {"攻":0.25,"防":0.25,"血":0.25,"速":0.25},
	"道修": {"攻":0.40,"防":0.15,"血":0.20,"速":0.25},
	"体修": {"攻":0.20,"防":0.40,"血":0.30,"速":0.10},
	"法修": {"攻":0.35,"防":0.10,"血":0.15,"速":0.40},
	"御兽师": {"攻":0.20,"防":0.20,"血":0.25,"速":0.35},
	"符箓师": {"攻":0.30,"防":0.10,"血":0.10,"速":0.50},
	"毒师": {"攻":0.30,"防":0.15,"血":0.15,"速":0.40},
	"傀儡师": {"攻":0.25,"防":0.35,"血":0.20,"速":0.20},
}

# 境界表（战力/寿元，对应七品阶；仙阶/道阶为顶两阶）
const 境界表: Dictionary = {
	"练气": {"品阶": "fan_jie", "战力": 100, "寿元": 80},
	"筑基": {"品阶": "ling_jie", "战力": 400, "寿元": 200},
	"金丹": {"品阶": "bao_jie", "战力": 1500, "寿元": 500},
	"元婴": {"品阶": "wang_jie", "战力": 6000, "寿元": 1200},
	"化神": {"品阶": "sheng_jie", "战力": 25000, "寿元": 3000},
	"仙阶": {"品阶": "xian_jie", "战力": 35000, "寿元": 5000},
	"道阶": {"品阶": "dao_jie", "战力": 40000, "寿元": 8000},
}
# 各境界每层所需游戏日基准值（10层体系：练气25天/层 ×10层=250天≈0.7年→筑基）
# 实际天数受 修炼速度/宗门修炼乘区 影响，这是纯基准（灵根主导速度）
# === P0+P1 修炼周期治理（2026-07-23）：层基准日重基线 + 灵根主导 + 年龄锁 + 开关 ===
const 新修炼规则 := true   # 全局开关：false→回退旧规则（资质驱动速度/旧层基准日/无年龄锁）
const 每层所需日_旧: Dictionary = {"练气":25.0, "筑基":60.0, "金丹":120.0, "元婴":240.0, "化神":480.0, "仙阶":900.0, "道阶":99999.0}
const 每层所需日_新: Dictionary = {"练气":108.0, "筑基":288.0, "金丹":720.0, "元婴":1800.0, "化神":3600.0, "仙阶":7200.0, "道阶":99999.0}
# 灵根品阶→修炼速度倍率（P1：灵根100%主导修炼速度，替换原资质速度；凡/良/上/极/天）
const 灵根品阶速度: Dictionary = {"凡品":1.0, "良品":1.3, "上品":1.8, "极品":2.5, "天品":2.5}
# 资质→突破成功率系数（P1：资质转向突破判定；凡俗难破，呼应偏科天才）
const 资质突破系数: Dictionary = {"fan_su":0.60, "pingyong":0.75, "youliang":1.00, "tiancai":1.00, "yaonie":1.10, "kuangshi":1.20}
# 最低突破年龄（D方案硬兜底，单位游戏年；炼气≥10 已由初始年龄覆盖）
const 最低突破年龄: Dictionary = {"筑基":14.0, "金丹":22.0, "元婴":50.0, "化神":100.0, "仙阶":200.0, "道阶":400.0}
# 突破后强制稳固期（游戏日；期间修炼效率×0.5，禁止连跳）
const 稳固期天数: Dictionary = {"筑基":365.0, "金丹":1095.0, "元婴":0.0, "化神":0.0, "仙阶":0.0, "道阶":0.0}
# 大圆满(10层)后尝试突破下一境界的成功率（温和型：失败回退+冷却，不致命）
const 突破成功率: Dictionary = {"练气":1.00, "筑基":0.70, "金丹":0.50, "元婴":0.35, "化神":0.20, "仙阶":0.10, "道阶":0.00}
# 失败回退层数（温和型）
const 突败回退层: Dictionary = {"筑基":2, "金丹":3, "元婴":3, "化神":4, "仙阶":5}
# 失败冷却天数（冷却期内无法再次尝试突破）
const 突败冷却日: Dictionary = {"筑基":30.0, "金丹":60.0, "元婴":90.0, "化神":120.0, "仙阶":180.0}
const 境界序: Array = ["练气","筑基","金丹","元婴","化神","仙阶","道阶"]


# 境界战斗倍率（乘性加成到 get_final_combat_attr 的四维实战属性）
# 设计意图：高境界者四维碾压低境界，体现修仙境界鸿沟
const 境界战斗倍率: Dictionary = {
	"练气": 1.0,
	"筑基": 2.0,
	"金丹": 4.0,
	"元婴": 8.0,
	"化神": 15.0,
	"仙阶": 25.0,
	"道阶": 40.0,
}
# 战力公式系数（ADR-001 §4 裁决基线；数值为 [DESIGN_BASELINE] 待实测校准，非阻断 E4）
const 资质系数表: Dictionary = {
	"fan_su": 1.0, "pingyong": 1.0,      # 普通（凡俗/平庸）
	"youliang": 1.15, "tiancai": 1.15,   # 优秀（优良/天才）
	"yaonie": 1.6, "kuangshi": 1.6,      # 顶级（妖孽/旷世/道胎）
}
const 灵根系数表: Dictionary = {
	"天灵根": 1.08,
}

const 姓库: Array = ["云","玄","青","墨","尘","凌","苏","叶","林","楚","姬","慕容","南宫","东方"]
const 名库: Array = ["霄","霜","青","渊","岚","芷","瑶","尘","逸","寒","羽","冥","玄","翰"]

# 解锁职业池（由 Game 按门派等级设置，筑基判定职业时使用）
static var 解锁职业池: Array = ["道修","体修","法修"]
# WAVE-B #2：稳定弟子ID分配器（类级自增；load 后由 Game 重置为 max+1，保证跨弟子不重/重载不丢）
static var 下一弟子ID: int = 1

var 姓名: String = ""
var 弟子ID: int = 0   # WAVE-B #2：稳定唯一ID（创建时分配，存档持久化，旧档缺键则保留 _init 分配的临时ID）
var 资质: String = ""
var 灵根: String = ""
var 灵根品阶: String = "凡品"   # 灵根品阶轴（天品/极品/上品/良品/凡品），对齐 spec 概率生成。
# 注：P0 简化为「灵根类型→品阶」直接映射（天灵根=天品/变异=极品/五行按纯度分三档），
# 统一映射到同一套 0-4 品阶值（见 Lore._灵根品阶值），逻辑自洽；后续若做「上品变异灵根」等细分，
# 再将「类型」与「品阶」拆为两独立字段，底层无需重构。
var 身份: String = "外门"       # 弟子身份（外门/内门弟子/核心弟子），天品/极品破格标记
var 来源: String = ""           # 接引来源标签（凡俗子弟/散修投奔/世家旁支），纯展示，不影响数值
const 弟子来源池: Array[String] = ["凡俗子弟", "散修投奔", "世家旁支"]
# === S1 端口：身份层级序（修为层级，境界驱动、只升不降）===
# ✅ 已裁决「方案 B · 双轴并行」（2026-07-21）：本常量保留现有 5 级身份轴（外门→内门弟子→核心弟子→亲传弟子→长老），完全不动；
#    新增独立 `阶位` 轴（执事→堂主→长老→供奉，考核驱动权限分层）为 S1 扩展，详见 S1-S2功能储备与扩展端口清单.md §5.6。
const 身份层级序: Array[String] = ["外门", "内门弟子", "核心弟子", "亲传弟子", "长老"]
# === S1 批1：阶位轴（方案 B 双轴并行，独立于身份轴；与身份轴正交，互不写对方字段）===
const 阶位层级序: Array[String] = ["执事", "堂主", "长老", "供奉"]   # 阶位轴 4 级，与 身份层级序 并列
var 阶位: String = "无"            # 当前阶位：无/执事/堂主/长老/供奉（默认无 = 未授阶）
# === S1 批5-B：辈分礼制（辈分序=辈分字派索引，0=开山第1字；道号玩家可改）===
var 辈分序: int = 0
var 道号: String = ""
var 考核冷却剩余: int = 0          # 考核失败后的冷却（游戏日），>0 时不可再对其发起考核
var 考核心得: bool = false         # 失败后获得，下次考核 +10%，一次性消耗（消耗后清零）
var destiny_id: String = ""
var 性格: String = ""
var 境界: String = "练气"
var 寿元: int = 80
var 修炼速度: float = 1.0
var 基础修炼速度: float = 1.0   # 不含命格加成的底值，供 _应用命格养成加成 幂等重算
var 战力: int = 100
var 备注: String = ""
var 职业: String = ""            # 筑基前为 ""（未入门），筑基后由系统判定
var 堂口: String = ""            # 筑基入堂后填充（堂口 key）
var 修炼进度: float = 0.0       # 当前层内进度 0~1，满则升一层
var 层数: int = 1                 # 当前境界内层数 (1-10)，10层=大圆满可尝试突破
var 突破冷却剩余: float = 0.0    # 失败后的冷却剩余天数（>0时不可再尝试突破）
var 年龄: float = 0.0           # 游戏年
var 瓶颈打磨值: float = 0.0     # D方案：大圆满后瓶颈打磨进度 0~1，满则解锁突破（受年龄锁）
var 稳固期剩余: float = 0.0     # P1：突破后稳固期剩余天数（>0时修炼效率×0.5）
var 丹毒: float = 0.0           # P1：丹毒积累（降突破率，每月自然-1）
var 物品: Array[Item] = []       # [DEPRECATED] 旧档兼容字段；新代码统一用 背包/装备（见 ADR-001 D1/D5）
var 背包: Array[Item] = []       # 未穿戴物品（原 物品）
var 装备: Dictionary = {}        # 槽位 key -> Item（仅已穿戴；key 取 item.穿戴位）
var 主宠灵兽: Beast = null
var 副宠灵兽: Beast = null
var 属性: Dictionary = {}
var 履历: Array = []        # [ADR-002 D5] 奇遇/历练摘要；§11.21 三原则新增字段（默认 []）
var 已修功法: Array[String] = []   # S1 批3：已修功法 skill_cultivation.skill_id 列表（默认 []，现役战斗零变化）
var 当前法阵: Dictionary = {}        # S1 批6-B：当前单人法阵 {"array_id": String, "等级": int}；空 {} = 未装备（独立字段，非 装备 Dictionary，D2 强约束）

func _init():
	随机生成()
	# WAVE-B #2：分配稳定唯一ID（_init 在 创建 与 from_dict 前均会执行；from_dict 会按需覆盖为存档ID）
	弟子ID = 下一弟子ID
	下一弟子ID += 1

func 总战力() -> int:
	# 对齐 ADR-001 §4.2：仅计已穿戴装备，走乘性公式
	return 计算战力()

# ============ 战力结算（ADR-001 D3，§4.2 乘性公式）============
func 计算战力() -> int:
	var base: float = float(境界表[境界]["战力"])
	# 已穿戴装备的 flat 基础（§4.7：基础战力表[品阶] + 极品 flat，并入 base 前；仅已穿戴）
	for it in 装备.values():
		base += float(it.装备基础战力())
	var 资质系数: float = _取资质系数()
	var 灵根系数: float = _取灵根系数()
	var 职业系数: float = _取职业综合系数()
	var 通用增益: float = 聚合通用增益()        # 已穿戴词缀%（装备单源子帽≤8%，全局软25/硬30）
	var 道心增益: float = 0.0                  # 当前无道心系统（§4.1 裁决①D 占位正确）
	var 主体: int = int(base * 资质系数 * 灵根系数 * 职业系数 * (1.0 + 通用增益) * (1.0 + 道心增益))
	var 灵兽加成: int = 灵兽契约战力()
	return max(0, 主体 + 灵兽加成)       # UX 边缘情况⑤：下限夹 0

# 通用增益聚合（ADR-001 §4.6）：当前仅装备单一来源，后续功法/大阵/羁绊并入同池
func 聚合通用增益() -> float:
	var 装备词缀池: float = 0.0
	for it in 装备.values():
		for a in it.词缀:
			装备词缀池 += float(a.get("数值", 0)) / 100.0
	var 装备子帽: float = clamp(装备词缀池, 0.0, 0.08)   # 单源子帽 ≤8%（裁决②基线）
	var 通用增益总和: float = 装备子帽
	return _clamp_soft(通用增益总和, 0.25, 0.30, 0.2)  # 软25%/硬30%，溢出按20%衰减

# 软上限：≤hard 全计；>hard 仅溢出部分按 decay 计入（硬上限附近衰减，对应 E4）
func _clamp_soft(v: float, soft: float, hard: float, decay: float) -> float:
	if v <= hard:
		return v
	return hard + (v - hard) * decay

func _取资质系数() -> float:
	return 资质系数表.get(资质, 1.0)

func _取灵根系数() -> float:
	if 灵根 in 灵根变异:
		return 1.1     # 变异灵根（§4.2）
	return 灵根系数表.get(灵根, 1.0)   # 天灵根1.08 / 普通五行1.0

func _取职业综合系数() -> float:
	# 当前仅单职业（主修）；多职业（主辅/三修）H8 未落地，落地后按 §4.3 取 1.7/2.1
	return 1.0

# ============ 灵兽契约战力（P0 双槽 + 双层适配加成）============
# 公式：灵兽总战力 = Σ(主宠/副宠) [ 本体战力 × (1+适配加成) × 战力比例(0.30) × 槽位比例(主1.0/副0.3) ]
# 适配加成 = 职业类型适配 +20% + 灵根属性适配 +8%，加法叠加，上限 28%（无匹配不惩罚，基础全额）
func 灵兽契约战力() -> int:
	var 总和: int = 0
	for b in [主宠灵兽, 副宠灵兽]:
		if b == null or b.孵化中:
			continue
		var 本体: int = b.本体战力()
		var 加成后: int = int(float(本体) * (1.0 + calc_beast_bonus(b, self)))
		总和 += b.战力贡献(加成后)
	return 总和

# P0 双槽双层适配加成：职业类型适配 +20% + 灵根属性适配 +8%，加法叠加，上限 28%
# 第一层：灵兽类型 ↔ 弟子职业适配（attack→道修/法修；defense→体修；support→御兽师/符箓师/毒师/傀儡师）
# 第二层：灵根属性适配（原"随机天赋契合"转化；天赋为灵根类型且关联=弟子灵根）
func calc_beast_bonus(兽: Beast, 弟子: Disciple) -> float:
	var 加成: float = 0.0
	if 弟子.职业 != "" and 兽.beast_type in Beast.类型适配职业:
		if 弟子.职业 in Beast.类型适配职业[兽.beast_type]:
			加成 += 0.20
	if 兽.天赋类型 == "灵根" and 兽.天赋关联 == 弟子.灵根:
		加成 += 0.08
	# T14 忠诚度：满忠诚额外+8%加法叠加，忠诚0不惩罚（只加不减），与职业/灵根同链路
	加成 += (float(兽.忠诚度) / 100.0) * 0.08
	return min(加成, 0.36)   # 职业0.20+灵根0.08+忠诚0.08 = 0.36 总上限

# ============ 灵兽实战属性映射（S1 战斗生效·优先级1）============
# 与 灵兽契约战力() 共用同一「本体战力 × 战力比例帽(0.30) × 槽位比例(主1.0/副0.3) × 适配加成(1+bonus)」因子；
# 仅前者坍缩为标量战力（进 总战力()/战力 字段）、后者按类型权重分发为 攻防血速 四维增量。
# 加法叠加进 get_final_combat_attr 的 战斗属性（经 _聚合未来战力来源 统一入口），不新增独立乘区，满足战力映射铁律。
func 灵兽单宠实战属性(兽: Beast) -> Dictionary:
	var 零: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	if 兽 == null or 兽.孵化中:
		return 零
	if not 兽.is_main_pet and not 兽.is_deputy_pet:
		return 零   # 仅持有未出战：不折算实战属性
	var 槽位比例: float = 1.0 if 兽.is_main_pet else 0.3
	var 系数: float = 兽.战力比例 * 槽位比例 * (1.0 + calc_beast_bonus(兽, self))
	var 本体: Dictionary = 兽.本体属性()
	var r: Dictionary = {}
	for _st in ["攻", "防", "血", "速"]:
		r[_st] = int(float(本体.get(_st, 0)) * 系数)
	return r

# 双槽灵兽折算后的实战属性增量汇总（主宠100%帽内 + 副宠30%帽内）
func 灵兽属性加成() -> Dictionary:
	var 聚合: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	for b in [主宠灵兽, 副宠灵兽]:
		if b == null or b.孵化中:
			continue
		var 单兽: Dictionary = 灵兽单宠实战属性(b)
		for _st in ["攻", "防", "血", "速"]:
			聚合[_st] += 单兽.get(_st, 0)
	return 聚合

# 出战灵兽快照（S1 战斗生效·优先级2）：仅含已设主/副宠的 名/类型/主副，供 BattleManager 编排层注入战斗日志
func _灵兽出战快照() -> Array:
	var r: Array = []
	for b in [主宠灵兽, 副宠灵兽]:
		if b != null and not b.孵化中 and (b.is_main_pet or b.is_deputy_pet):
			r.append({"名": b.种类名, "类型": Beast.类型中文.get(b.beast_type, ""), "主副": "主" if b.is_main_pet else "副"})
	return r

# ============ 装备穿戴（ADR-001 D1 / Epic A2）============
# 背包=未穿戴；装备=槽位 key -> Item（仅已穿戴）。槽位 key 取 item.穿戴位（本 Sprint 沿用既有 9 值，9→7 重命名留后续 Sprint）
func 穿戴(槽: String, it: Item):
	if it == null or 槽 == "" or not it.可穿戴():
		return
	if 背包.has(it):
		背包.erase(it)
	# 若 it 已在其它槽，先摘下（防同物双槽）
	for k in 装备.keys():
		if 装备[k] == it:
			装备.erase(k)
			break
	if 装备.has(槽):
		var 旧: Item = 装备[槽]
		背包.append(旧)        # 原槽物退回背包
	装备[槽] = it

func 卸载(槽: String):
	if 装备.has(槽):
		var 旧: Item = 装备[槽]
		装备.erase(槽)
		if not 背包.has(旧):
			背包.append(旧)

# 获得物品：入背包并尝试自动穿戴（更优则替换）；受 品阶≤境界 佩戴限制
func 获得物品(it: Item):
	背包.append(it)
	自动穿戴(it)

# 自动穿戴：空槽直接上；占槽则 战力加成 更高者替换（贪心，对齐 UX 一键最优口径）
func 自动穿戴(it: Item):
	if it == null or not it.可穿戴():
		return
	if not _品阶不高于境界(it):
		return
	var 槽: String = it.穿戴位
	var 现: Item = 装备.get(槽)
	if 现 == null or it.战力加成 > 现.战力加成:
		穿戴(槽, it)

# 一键最优穿戴：遍历背包可穿戴物，按 战力加成 贪心填各槽（受 品阶≤境界 限制）
func 一键最优穿戴():
	var 候选: Array = 背包.duplicate()
	for it in 候选:
		if it.可穿戴() and _品阶不高于境界(it):
			var 槽: String = it.穿戴位
			var 现: Item = 装备.get(槽)
			if 现 == null or it.战力加成 > 现.战力加成:
				穿戴(槽, it)

func _品阶不高于境界(it: Item) -> bool:
	var 境阶: String = 境界表[境界].get("品阶", "fan_jie")
	var i物: int = Item.品阶序key.find(it.品阶)
	var i境: int = Item.品阶序key.find(境阶)
	if i物 < 0 or i境 < 0:
		return true      # 未知品阶不拦截（防御）
	return i物 <= i境

# §11.21.5 自修复：装备物不应重复出现在背包；穿戴位须与槽 key 一致；材料/丹药不可穿戴
func _修复装备一致性():
	for 槽 in 装备.keys():
		var it = 装备[槽]
		if it == null:
			装备.erase(槽)
			continue
		# 防御旧档/历史 bug：材料或丹药误穿到装备槽，卸载回背包并清空穿戴位
		# 双保险：按类别判断 + 按名称兜底（旧档中材料名被误存为法器/神兵/法宝类别）
		if it.类别 in ["ling_cai", "dan_yao"] or it.是材料名称(it.名称):
			it.穿戴位 = ""
			it.类别 = "ling_cai"
			背包.append(it)
			装备.erase(槽)
			continue
		if not it.可穿戴():
			背包.append(it)
			装备.erase(槽)
			continue
		if 背包.has(it):
			背包.erase(it)
		if it.穿戴位 != 槽:
			if 装备.has(it.穿戴位):
				背包.append(it)
				装备.erase(槽)
			else:
				装备.erase(槽)
				装备[it.穿戴位] = it
	_去重背包()

func _去重背包():
	var 唯一: Array[Item] = []
	for it in 背包:
		if not 唯一.has(it):
			唯一.append(it)
	背包 = 唯一

func 加权随机(权重: Dictionary) -> String:
	var 总: float = 0.0
	for k in 权重:
		总 += 权重[k]
	var 抽: float = randf() * 总
	for k in 权重:
		抽 -= 权重[k]
		if 抽 <= 0:
			return k
	return 权重.keys()[0]

# 命格生成：按品质档权重池抽取 destiny_id（CSV 驱动，无隐藏特殊概率）
func _按权重抽命格(权重: Dictionary) -> String:
	var 池: Array = []
	for g in 权重.keys():
		for id in DestinyDataLoader.ids_by_grade().get(g, []):
			池.append({"id": id, "w": float(权重[g])})
	if 池.is_empty():
		return ""
	var 总: float = 0.0
	for x in 池:
		总 += x["w"]
	var r: float = randf() * 总
	for x in 池:
		r -= x["w"]
		if r <= 0:
			return x["id"]
	return 池[池.size() - 1]["id"]

# 修炼速度倍率（乘性归集）：灵根主导已并入 基础修炼速度；此处仅叠加 修行型命格。
# 宗门加成（灵脉/负责人/藏经阁/气运）改为 推演一月 加法叠加封顶，不在此乘入，避免双重叠加。
func 总修炼速度倍率() -> float:
	var 倍率: float = 1.0
	# 来源：修行型命格（常驻）
	var 命格数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	if 命格数据.get("类型", "") == "修行" and 命格数据.get("维度", "") == "修炼":
		倍率 *= (1.0 + float(命格数据.get("数值", 0)) / 100.0)
	# S1 批6-B：当前单人法阵·修炼辅助（乘性并入；宗门大阵聚灵走 推演一月 宗门加成pct，不在此）
	if not 当前法阵.is_empty():
		var 阵cfg: Dictionary = Game.阵法配置表.get(当前法阵.get("array_id", ""), {})
		if not 阵cfg.is_empty() and "修炼" in 阵cfg.get("eff_dim", ""):
			var 阵eff: float = float(阵cfg.get("eff_val_base", "0")) * (1.0 + (int(当前法阵.get("等级", 1)) - 1) * float(阵cfg.get("level_growth_coef", "0")))
			if _灵根匹配法阵(阵cfg):
				阵eff *= 1.05
			倍率 *= (1.0 + clamp(阵eff, 0.0, 0.15))   # 单源子帽 ≤15%（[PLACEHOLDER] 真机校准）
	return 倍率

# 基础修炼速度（灵根主导；旧规则回退资质速度）
func _基础修炼速度值() -> float:
	if 新修炼规则:
		return 灵根品阶速度.get(灵根品阶, 1.0)
	return 资质表.get(资质, {}).get("速度", 1.0)

# 修行型命格常驻加成：乘入修炼速度（含突破加速等效）
func _应用命格养成加成():
	# 先回到基础值，避免 from_dict / 重复调用时累乘
	修炼速度 = 基础修炼速度 * 总修炼速度倍率()

func 随机生成():
	资质 = 加权随机(资质权重)
	基础修炼速度 = _基础修炼速度值()
	修炼速度 = 基础修炼速度 * 总修炼速度倍率()
	# 灵根品阶轴（对齐 spec 概率）：天品0.5% / 极品3% / 上品25% / 良品40% / 凡品31.5%
	var rp: float = randf()
	if rp < 0.005:
		灵根 = "天灵根"; 灵根品阶 = "天品"
	elif rp < 0.035:
		灵根 = 灵根变异.pick_random(); 灵根品阶 = "极品"
	elif rp < 0.285:
		灵根 = 灵根五行.pick_random(); 灵根品阶 = "上品"
	elif rp < 0.685:
		灵根 = 灵根五行.pick_random(); 灵根品阶 = "良品"
	else:
		灵根 = 灵根五行.pick_random(); 灵根品阶 = "凡品"
	# 命格：弟子品质 → 品级权重池抽取（废弃旧 1% 天命特殊分支）
	var 档: String = 资质到品质档.get(资质, "凡品")
	var 权重: Dictionary = 品质档命格权重.get(档, {"凡品": 100.0})
	destiny_id = _按权重抽命格(权重)
	性格 = 性格表.pick_random()
	职业 = ""            # 延后至筑基判定
	堂口 = ""
	修炼进度 = 0.0
	# 初始年龄：按渠道规则（§6.10.1.5），默认=下山测灵招募 10~16 岁凡人少年
	# 后续渠道扩展（散修/招贤阁）可加参数覆盖
	年龄 = randi_range(10, 16)
	姓名 = 姓库.pick_random() + 名库.pick_random()
	境界 = "练气"
	寿元 = 境界表["练气"]["寿元"]
	战力 = 境界表["练气"]["战力"]
	算属性()
	_应用命格养成加成()   # 命格修行加成乘入修炼速度（含突破加速等效）

# 初始属性：总属性随资质缩放；职业仅决定侧重（合计不变）；未入门用中性权重
func 算属性():
	var 总量: int = int(150 + 资质系数表.get(资质, 1.0) * 30)
	var w: Dictionary = 职业属性权重.get(职业, 职业属性权重[""])
	属性 = {
		"攻": int(总量 * w["攻"]),
		"防": int(总量 * w["防"]),
		"血": int(总量 * w["血"]),
		"速": int(总量 * w["速"]),
	}

# 灵根决定可修职业数（变异/天灵根/全灵根→3；单双五行→2；杂灵根→1）
func 可修职业数() -> int:
	if 灵根 == "天灵根" or 灵根 == "先天五行全灵根":
		return 3
	if 灵根 in 灵根变异:
		return 3
	if 灵根 in 灵根五行:
		return 2
	return 1

# 层基准日（按开关返回新旧；speed=1.0 时每层所需游戏日）
func _层基准日(境: String) -> float:
	if 新修炼规则:
		return 每层所需日_新.get(境, 99999.0)
	return 每层所需日_旧.get(境, 99999.0)

# 瓶颈打磨（D方案）：筑基大圆满后修为停涨，累计打磨值，满1.0解锁突破；
# 自然增长按资质，且受「年龄/22」硬锁，最快突破不早于22岁（杜绝道具堆早金丹）
const 瓶颈灵气消耗 := 10                     # 灵气助破瓶颈：单次消耗灵气（config化待S1）
const 瓶颈灵气打磨加成 := 0.05               # 单次打磨加成，严守单buff≤5%红线
# 节奏校准（双周期评级配套）：稳固期/瓶颈打磨分阶系数由 config/节奏校准.csv 驱动，缺失回落默认
func _稳固期天数(境: String) -> float:
	if Game.节奏校准.is_empty():
		Game._加载节奏校准()
	var s: String = Game.节奏校准.get("稳固期_" + 境, "")
	if s == "":
		return 稳固期天数.get(境, 0.0)
	return float(s)

func _瓶颈打磨系数(境: String) -> float:
	if Game.节奏校准.is_empty():
		Game._加载节奏校准()
	var s: String = Game.节奏校准.get("瓶颈打磨_" + 境, "")
	if s == "":
		return 1.0
	return float(s)

func 累计瓶颈打磨(日: float):
	if 瓶颈打磨值 >= 1.0:
		return
	var 自然增量: float = 日 * 资质突破系数.get(资质, 1.0) / 2880.0 * _瓶颈打磨系数(境界)
	瓶颈打磨值 = min(1.0, 瓶颈打磨值 + 自然增量)
	瓶颈打磨值 = min(瓶颈打磨值, clamp(年龄 / 22.0, 0.0, 1.0))

# 主动打磨入口（历练/讲道/悟道丹药/奇遇 调用，增量0~1；仍受年龄锁夹制）
func 加瓶颈打磨(增量: float):
	if 增量 <= 0 or 瓶颈打磨值 >= 1.0:
		return
	瓶颈打磨值 = min(1.0, 瓶颈打磨值 + 增量)
	瓶颈打磨值 = min(瓶颈打磨值, clamp(年龄 / 22.0, 0.0, 1.0))

# 灵气助破瓶颈（经济S0：灵气→瓶颈打磨消耗出口，复用D方案瓶颈系统）
# 消耗灵气加快瓶颈打磨进度，是灵气的首个真实消耗出口；无灵气/已满则失败，不惩罚
func 灵气助破瓶颈() -> bool:
	if 瓶颈打磨值 >= 1.0:
		return false
	if Game.灵气 < 瓶颈灵气消耗:
		return false
	Game.灵气 -= 瓶颈灵气消耗
	加瓶颈打磨(瓶颈灵气打磨加成)
	return true

# 推进修炼（游戏日）；修炼乘区 由宗门传入（加法叠加封顶后的总倍率，默认1.0）
# 10层体系：每日积累当前层进度 → 满则升层数 → 大圆满累计打磨 → 打磨满尝试突破
func 推进修炼(日: float, 修炼乘区: float = 1.0):
	年龄 += 日 / 360.0
	# 稳固期：修炼效率减半，且期间不可突破（P1）
	var 效率: float = 1.0
	if 稳固期剩余 > 0:
		稳固期剩余 = max(0.0, 稳固期剩余 - 日)
		效率 = 0.5
	# 丹毒自然消解（每月-1，P1基础）
	if 丹毒 > 0:
		丹毒 = max(0.0, 丹毒 - 日 / 30.0)
	var 层基准日: float = _层基准日(境界)
	if 层基准日 >= 99999.0:
		return   # 已至顶阶，不再推进
	# 失败冷却倒计时（冷却期内不积累突破进度，但仍正常升层）
	if 突破冷却剩余 > 0:
		突破冷却剩余 = max(0.0, 突破冷却剩余 - 日)
	# 积累当前层进度（灵根主导速度 × 宗门加算封顶乘区 × 稳固期效率）
	修炼进度 += 日 * 修炼速度 * 效率 * 修炼乘区 / 层基准日
	# 升层循环（溢出结转：一天内可能连升多层）
	while 修炼进度 >= 1.0 and 层数 < 10:
		修炼进度 -= 1.0
		层数 += 1
	# 大圆满(10层) → 累计瓶颈打磨值（D方案：替代纯空等，进度受年龄上限锁）
	if 层数 >= 10 and 突破冷却剩余 <= 0:
		累计瓶颈打磨(日)
	# 大圆满 + 打磨满 + 无冷却 → 尝试突破
	if 层数 >= 10 and 修炼进度 >= 1.0 and 突破冷却剩余 <= 0 and 瓶颈打磨值 >= 1.0:
		尝试突破()

# 终局机制 P0：资质→境界天花板查询与判定
func 资质上限境界() -> String:
	return 资质境界天花板.get(资质, "道阶")

# 是否已触及资质天花板（达到上限境即封顶，无法再突破）
func 是否达资质上限() -> bool:
	return 境界序.find(境界) >= 境界序.find(资质上限境界())

# 尝试突破到下一境界（仅在大圆满时调用）；返回是否成功
func 尝试突破() -> bool:
	var i: int = 境界序.find(境界)
	if i < 0 or i >= 境界序.size() - 1:
		return false   # 已至顶阶或非法境界
	if 层数 < 10:
		return false   # 非大圆满不可突破
	# D方案：瓶颈打磨未满 / 年龄未达下限 → 不突破（无惩罚，仅不突破，避免空等期误触失败）
	var 目标境: String = 境界序[i + 1]
	# 终局机制 P0：资质天花板硬锁——目标境超出资质上限则永久无法突破（不消耗资源、不触发失败惩罚）
	if 境界序.find(目标境) > 境界序.find(资质上限境界()):
		return false
	if 瓶颈打磨值 < 1.0:
		return false
	if 最低突破年龄.has(目标境) and 年龄 < 最低突破年龄[目标境]:
		return false
	# 突破率 = 境界基础率 × 资质突破系数（资质低→难破，呼应偏科天才）；丹毒降率（P1）
	var 基础率: float = 突破成功率.get(境界, 0.0)
	var 率: float = min(1.0, 基础率 * 资质突破系数.get(资质, 1.0))
	率 = max(0.0, 率 - 丹毒 * 0.08)
	if 率 >= 1.0 or randf() < 率:
		# 突破成功
		突破()
		return true
	else:
		# 突破失败（温和型惩罚：回退层数 + 进度清零 + 冷却）
		var 回退: int = 突败回退层.get(境界, 3)
		层数 = max(1, 层数 - 回退)
		修炼进度 = 0.0
		突破冷却剩余 = 突败冷却日.get(境界, 60.0)
		return false

# 突破到下一境界；练气→筑基 触发职业判定 + 入堂
func 突破():
	# === S1 端口：突破「走火入魔」小概率负面效果（心魔/损伤/药毒反噬）===
	# 调用位置：突破() 成功（境界已升、属性已重算、_刷新身份 已执行）之后插入判定。
	# 入参（S1 实装时）：无（读取 self.境界 / 灵根品阶 / 药毒）
	# 返回值：void；副作用：randf() 命中则施加负面状态（心魔标记 / 属性临时下降 / 突破冷却延长）
	# 依赖：突破链路（本函数）、药毒机制（§四）。状态：仅注释标记，未插入判定。
	var i: int = 境界序.find(境界)
	if i < 0 or i >= 境界序.size() - 1:
		return
	境界 = 境界序[i + 1]
	层数 = 1          # 重置到新境界第1层
	修炼进度 = 0.0    # 层内进度清零
	突破冷却剩余 = 0.0 # 清除冷却
	瓶颈打磨值 = 0.0  # 重置瓶颈打磨（新境界重新打磨）
	稳固期剩余 = _稳固期天数(境界)  # P1 突破后强制稳固期（效率减半），天数由节奏校准驱动
	寿元 = 境界表[境界]["寿元"]
	战力 = 境界表[境界]["战力"]
	算属性()
	_刷新身份()
	if 境界 == "筑基" and 职业 == "":
		判定职业(解锁职业池)
		入堂()

# 身份（宗门层级）随境界晋升：只升不降；天品/极品测灵时已破格，保持或继续抬升
func _刷新身份():
	# 身份层级（外门→长老）仅由境界晋升驱动，只升不降。
	# 注意：身份层级 与「天赋标签（天纵奇才/天资卓绝）」是两件独立的事——
	# 天赋标签仅由灵根品阶决定且永久唯一（见 简介()），不因境界晋升获得；
	# 常规弟子（凡/良/上品）堆到金丹也会成「核心弟子」层级，但不携带天赋标签、不触发天赋特权，
	# 从而保住天品/极品弟子的稀缺性（后续 S1 修炼位准入以灵根品阶值为准，而非身份层级）。
	var 身份序: Array = 身份层级序   # S1 端口：引用类级常量，便于晋升/分层逻辑复用
	var 境界身份: Dictionary = {
		"筑基": "内门弟子", "金丹": "核心弟子", "元婴": "亲传弟子",
		"化神": "长老", "仙阶": "长老", "道阶": "长老"
	}
	if not 境界身份.has(境界):
		return
	var 目标: String = 境界身份[境界]
	if 身份序.find(目标) > 身份序.find(身份):
		身份 = 目标

# 旧存档兼容：身份字段缺失时的默认身份。
# 规则：破格优先级高于境界晋升——天品必核心弟子、极品必内门弟子（保住天赋稀缺性）；
#       常规弟子按境界映射（炼气外门 / 筑基内门 / 金丹核心 / 元婴亲传 / 化神及以上长老）。
func _默认身份(品阶: String, 境: String) -> String:
	if 品阶 == "天品":
		return "核心弟子"
	if 品阶 == "极品":
		return "内门弟子"
	match 境:
		"练气": return "外门"
		"筑基": return "内门弟子"
		"金丹": return "核心弟子"
		"元婴": return "亲传弟子"
		_: return "长老"

# === S1 批1：阶位轴边界 / 默认函数（与身份轴正交，互不写对方字段）===
# 旧档弟子（存档无 阶位 键）按身份轴层级推导 legacy 阶位（祖父条款，D1 豁免名额上限）
func _默认阶位(身份值: String) -> String:
	match 身份值:
		"内门弟子": return "执事"
		"核心弟子": return "堂主"
		"亲传弟子": return "长老"
		"长老": return "供奉"
		_: return "无"

# 至少内门弟子才可授阶（身份层级序索引 ≥ 1）
func 可授阶() -> bool:
	return 身份层级序.find(身份) >= 1

# 当前阶位索引（"无" → -1）
func 阶位索引() -> int:
	return 阶位层级序.find(阶位)

# 阶位上限索引（破格 +1 阶，仍须 ≥ 内门；封顶 3=供奉）。D2。
func 阶位上限索引(破格: bool) -> int:
	var i: int = 身份层级序.find(身份)
	var cap: int = clamp(i - 1, -1, 3)
	if 破格:
		cap = clamp(i, -1, 3)
	return cap

# 特殊命格（经营/宗门类）→ 破格/考核加成资格。数据来自 DestinyDataLoader.类型。
func 有特殊命格() -> bool:
	var 数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	return 数据.get("类型", "") == "经营"

# 阶位考核成功率（基础 60% / 满配 90%，clamp）。D3：复用全局 贡献点；D5：灵根/命格加成。
func 考核成功率() -> float:
	var P: float = 0.60
	P += clamp(float(Game.贡献点) / Game.考核贡献阈值, 0.0, 1.0) * 0.20
	if 灵根品阶 in ["极品", "天品"]:
		P += 0.05
	if 有特殊命格():
		P += 0.05
	if 考核心得:
		P += 0.10
	return clamp(P, 0.0, 0.90)

# 筑基判定职业：按属性/灵根对各职业打分，取候选池中最高分者
func 判定职业(候选: Array = ["道修","体修","法修"]):
	var 分: Dictionary = {
		"道修": 属性.get("攻", 0)*1.5 + 属性.get("速", 0)*1.0,
		"体修": 属性.get("防", 0)*1.5 + 属性.get("血", 0)*1.5,
		"法修": 属性.get("速", 0)*1.5 + 属性.get("攻", 0)*1.0,
		"御兽师": 属性.get("速", 0)*1.0 + 属性.get("血", 0)*1.0,
		"符箓师": 属性.get("速", 0)*1.8,
		"毒师": 属性.get("攻", 0)*1.2 + 属性.get("速", 0)*1.0,
		"傀儡师": 属性.get("防", 0)*1.3 + 属性.get("攻", 0)*1.0,
	}
	if 灵根 in ["火","雷"]:
		分["法修"] += 20; 分["毒师"] += 10
	if 灵根 in ["冰","水"]:
		分["御兽师"] += 15
	if 灵根 in ["土","金"]:
		分["体修"] += 15; 分["傀儡师"] += 10
	var 最佳: String = "道修"
	var 最佳分: float = -1.0
	for 职 in 候选:
		var v: float = 分.get(职, -1.0)
		if v > 最佳分:
			最佳分 = v; 最佳 = 职
	职业 = 最佳

# 筑基后按职业加入对应堂口
func 入堂():
	堂口 = Lore.职业堂口.get(职业, "yuying")

# P0-BUILD-2：职业 → 对口建筑（加成评分职业对口加权用；不影响战斗数值，仅用于负责人竞争/排序）
const 职业对口建筑: Dictionary = {
	"毒师": ["dantang"], "傀儡师": ["qitang"], "御兽师": ["yushou"],
	"符箓师": ["cangjing"], "道修": ["cangjing", "qitang"],
	"法修": ["cangjing"], "体修": ["qitang", "zhifa"],
}

# 加成评分（供堂口负责人自动任命/替换用）；维度来自堂口定义的加成维度
func 加成评分(维度: String) -> float:
	var 总和: float = float(属性.get("攻", 0) + 属性.get("防", 0) + 属性.get("血", 0) + 属性.get("速", 0))
	var k: float = 资质系数表.get(资质, 1.0) / 1.6
	var s: float = 总和 * (0.5 + 0.5 * k)
	if 维度 in ["攻","防","血","速"]:
		var 占比: float = 属性.get(维度, 0) / max(1.0, 总和)
		s *= (1.0 + 占比)
	if 维度 == "木" and (灵根 in 灵根五行 or 灵根 == "天灵根" or 灵根 == "先天五行全灵根"):
		s *= 1.1
	# P0-BUILD-2 加成评分权重①：弟子职业对口当前建筑职能 → ×1.2
	var 对口key: String = 堂口
	if 对口key != "" and 对口key in 职业对口建筑.get(职业, []):
		s *= 1.2
	# P0-BUILD-2 加成评分权重②：经营型 + 对应维度命格 → ×1.15（参考 _资源建筑产出 经营命格判定）
	var 命格数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	if 命格数据.get("类型", "") == "经营" and 命格数据.get("维度", "") == 维度:
		s *= 1.15
	return s

# 天赋标签：灵根品阶 × 资质 双维度组合（P0 映射，纯文案、零数值影响）
# 仅双高组合（高灵根+高资质）标「天纵奇才」；高灵根+低资质标「灵根绝世·璞玉待琢」点明偏科短板
# 异常数据（灵根/资质不在枚举内）降级为「庸碌之辈」，符合降级不崩铁律
func _天赋标签() -> String:
	var 灵根档: String = "低"
	match 灵根品阶:
		"凡品": 灵根档 = "低"
		"良品", "上品": 灵根档 = "中"
		"极品", "天品": 灵根档 = "高"
	var 资质档: String = "低"
	match 资质:
		"fan_su", "pingyong": 资质档 = "低"
		"youliang": 资质档 = "中"
		"tiancai", "yaonie", "kuangshi": 资质档 = "高"
	var 表: Dictionary = {
		"低": {"低": "庸碌之辈", "中": "勤能补拙", "高": "根基扎实"},
		"中": {"低": "偏科之资", "中": "中规中矩", "高": "可造之材"},
		"高": {"低": "灵根绝世·璞玉待琢", "中": "天赋异禀", "高": "天纵奇才"},
	}
	return 表[灵根档][资质档]

func 简介() -> String:
	var 显示名: String = 姓名
	if 备注 != "":
		显示名 = "%s（%s）" % [姓名, 备注]
	# 身份标签 = 天赋标签（灵根品阶 × 资质 双维度组合，详见 _天赋标签）；
	# 仅双高组合标「天纵奇才」，高灵根+低资质标「灵根绝世·璞玉待琢」点明偏科，消除认知冲突。
	var 身份标签: String = "「" + _天赋标签() + "」"
	# 身份（宗门层级：外门/内门弟子/核心弟子/亲传弟子/长老）随境界晋升，突破练气后露出
	if 身份 != "" and 身份 != "外门":
		if 身份标签 != "":
			身份标签 += " · 身份·" + 身份
		else:
			身份标签 = " · 身份·" + 身份
	var 职业显: String = 职业 if 职业 != "" else "未入门"
	var 命格数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	var 命格显: String = ("%s[%s]" % [命格数据.get("名称", "—"), 命格数据.get("品级", "")]) if destiny_id != "" else "—"
	var 年龄文本: String = "??" if 年龄 <= 0 else ("%.0f岁" % 年龄)
	var 灵根显: String = "%s·%s" % [灵根, 灵根品阶]
	# 境界合并写法：练气三层·修业49%
	var 中文层数: Array = ["零","一","二","三","四","五","六","七","八","九","十"]
	var 层数中文: String = "大圆满" if 层数 >= 10 else (中文层数[层数] + "层")
	var 境界合并: String = "%s%s·修业%d%%" % [境界, 层数中文, int(修炼进度*100)]
	var s: String = "%s\n资质:%s  灵根:%s%s  命格:%s  性格:%s  职业:%s\n%s  寿元:%d  战力:%d  修炼x%.1f  年龄%s" % \
		[显示名, 资质显示.get(资质, 资质), 灵根显, 身份标签, 命格显, 性格, 职业显, 境界合并, 寿元, 战力, 修炼速度, 年龄文本]
	s += "\n  属性(攻%d/防%d/血%d/速%d)  职位:%s  来源:%s" % \
		[属性.get("攻", 0), 属性.get("防", 0), 属性.get("血", 0), 属性.get("速", 0), _职位文案(), (来源 if 来源 != "" else "—")]
	# S1 批1：阶位轴双轴呈现（阶位· 前缀消歧，与 身份·长老 区分）
	var 阶位显: String = ("阶位·无（未授阶）" if 阶位 == "无" else "阶位·" + 阶位)
	s += "\n  阶位：%s" % 阶位显
	if 考核冷却剩余 > 0:
		s += " ｜ 考核冷却 %d 日" % 考核冷却剩余
	if 考核心得:
		s += " ｜ 考核心得"
	var 上限境: String = 资质上限境界()
	if 是否达资质上限():
		s += "\n  ⚠ 资质所限，此生已无更进一步可能（上限：%s）" % 上限境
	else:
		s += "\n  资质上限：%s" % 上限境
	if 背包.size() > 0:
		s += "\n  持有(储物袋)："
		for it in 背包:
			s += "\n    · " + it.简介()
	if 装备.size() > 0:
		s += "\n  已穿戴："
		for 槽 in 装备.keys():
			var it = 装备[槽]
			s += "\n    ·[%s] %s" % [Item.槽显示.get(槽, 槽), it.名称]
	for _槽兽 in [主宠灵兽, 副宠灵兽]:
		if _槽兽 != null:
			var 显示本体: int = int(float(_槽兽.本体战力()) * (1.0 + calc_beast_bonus(_槽兽, self)))
			s += "\n  灵兽：" + _槽兽.简介(显示本体)
			var 单兽: Dictionary = 灵兽单宠实战属性(_槽兽)
			if 单兽["攻"] + 单兽["防"] + 单兽["血"] + 单兽["速"] > 0:
				s += "（实战+攻%d/防%d/血%d/速%d）" % [单兽["攻"], 单兽["防"], 单兽["血"], 单兽["速"]]
			var 联动: String = 灵兽联动(_槽兽)
			if 联动 != "":
				s += "\n    ☆ " + 联动
	return s

# 灵兽联动：基于灵兽「随机天赋」的关联（灵根/职业）与弟子匹配，不再依赖灵兽适配职业
func 灵兽联动(兽: Beast) -> String:
	if 兽 == null or 兽.孵化中:
		return ""
	var 类型: String = 兽.天赋类型
	var 关联: String = 兽.天赋关联
	# 灵根契合
	if 类型 == "灵根" and 关联 == 灵根:
		return "【天赋共鸣】灵兽天赋契合%s灵根：%s" % [灵根, 兽.天赋]
	# 职业契合（含极品专属联动：弟子持有对应极品装备才触发）
	if 类型 == "职业" and 关联 == 职业 and 职业 != "":
		var 极品名: String = _持有极品名()
		if 极品名 == "万法可破":
			return "【万法可破】+道修灵兽天赋：对战法修额外获得短时法术无敌帧"
		if 极品名 == "金刚不坏":
			return "【金刚不坏】+体修灵兽天赋：锁血阈值由20%提升至25%"
		if 极品名 == "焚身灭甲":
			return "【焚身灭甲】+法修灵兽天赋：真实伤害小幅扩散溅射"
		return "【天赋共鸣】灵兽天赋契合%s：%s" % [职业, 兽.天赋]
	return ""

# 取弟子当前持有的某一极品装备中文名（用于灵兽极品联动判定）
func _持有极品名() -> String:
	for it in 背包:
		if it.极品属性 != null:
			return it.极品属性["名"]
	for it in 装备.values():
		if it.极品属性 != null:
			return it.极品属性["名"]
	return ""

# 职位文案（S0：仅根据堂口名显示"XX弟子"；S1 接入 Game.堂口列表 负责人检测后区分"XX主事"）
func _职位文案() -> String:
	if 堂口 == "":
		return "—"
	var 堂口名: String = Lore.取堂口(堂口).get("名称", 堂口)
	return "%s弟子" % 堂口名

# 效果查询（UI 点击查看详情用）
func 命格详情() -> String:
	var 命格数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	if 命格数据.is_empty():
		return "（无命格）"
	var 数值串: String = ""
	if 命格数据.get("维度", "") != "":
		数值串 = "（%s%+d%%）" % [命格数据["维度"], 命格数据["数值"]]
	return "%s[%s]%s：%s" % [命格数据.get("名称", ""), 命格数据.get("品级", ""), 数值串, 命格数据.get("描述", "")]
func 灵根详情() -> String:
	return Lore.灵根效果文(灵根)
func 性格详情() -> String:
	return Lore.性格效果文(性格)
func 职业详情() -> String:
	return Lore.职业效果文(职业) if 职业 != "" else "（尚未入门，筑基后由系统判定）"

# P0-BUILD-2：从 Game 单例实时读取「负责人全局微量 buff」；无负责人时全 0 → 各乘区=1.0 不改变数值。
# 用 is_instance_valid 兜底，避免任何 Game 未就绪的极端上下文直接崩。
func _取负责人全局buff() -> Dictionary:
	if not is_instance_valid(Game):
		return {}
	return Game.汇总负责人全局buff()

# ============ 战斗快照（ADR-003 D1：CombatantData 契约）============
# 返回 BattleCalculator / BattleManager 消费的战斗快照。全部取自本弟子最终属性接口，
# 禁止写死测试值。字段与 BattleCalculator.calc_hit_damage / 结算_1v1 消费口径一致：
#   战力 / 属性{攻防血速} / 职业 / 灵根{主,纯度} / 灵兽战力 / 极品特效 /
#   通用增益 / 道心增益 / 暴击率 / 闪避率 / 名称
func get_final_combat_attr() -> Dictionary:
	# 极品特效：遍历背包 + 已穿戴，取持有极品的中文名（钩子占位，P0 不实现效果）
	var 极品: Array = []
	for it in 背包:
		if it.极品属性 != null:
			极品.append(it.极品属性["名"])
	for it in 装备.values():
		if it.极品属性 != null:
			极品.append(it.极品属性["名"])
	# 主灵根 + 纯度推导（P0 单灵根模型：当前仅持有单一灵根字段，统一计「单」；
	#   双/三/四+ 多灵根档位数据模型到位后再按灵根组合推导）
	var 主灵根: String = 灵根
	var 纯度: String = _推导纯度()
	# 暴击率 / 闪避率：由属性 + 灵根真实推导（非硬编码测试值）
	var 暴击率: float = clamp(float(属性.get("速", 0)) * 0.004, 0.0, 1.0)
	if 灵根 in ["雷", "金"]:
		暴击率 += 0.05
	var 闪避率: float = clamp(float(属性.get("速", 0)) * 0.003, 0.0, 1.0)
	if 灵根 in ["风", "水"]:
		闪避率 += 0.05
	# S1 批6-B：法阵暴击/闪避等效（常驻；当前法阵 eff_dim 含 暴击/闪避 时累加 eff_val×匹配；[PLACEHOLDER] 真机校准）
	# 注：投稿部分阵以「提升暴击/闪避几率」命名但数据 eff_dim 实为 攻/速，本批严格按 eff_dim 含 暴击/闪避 判定
	if not 当前法阵.is_empty():
		var 阵cfg: Dictionary = Game.阵法配置表.get(当前法阵.get("array_id", ""), {})
		var 阵dim: String = 阵cfg.get("eff_dim", "")
		if "暴击" in 阵dim:
			var 暴eff: float = float(阵cfg.get("eff_val_base", "0")) * (1.0 + (int(当前法阵.get("等级", 1)) - 1) * float(阵cfg.get("level_growth_coef", "0")))
			if _灵根匹配法阵(阵cfg):
				暴eff *= 1.05
			暴击率 += clamp(暴eff, 0.0, 0.15)
		if "闪避" in 阵dim:
			var 闪eff: float = float(阵cfg.get("eff_val_base", "0")) * (1.0 + (int(当前法阵.get("等级", 1)) - 1) * float(阵cfg.get("level_growth_coef", "0")))
			if _灵根匹配法阵(阵cfg):
				闪eff *= 1.05
			闪避率 += clamp(闪eff, 0.0, 0.15)
	var 战斗属性: Dictionary = {"攻": int(属性.get("攻", 0)), "防": int(属性.get("防", 0)), "血": int(属性.get("血", 0)), "速": int(属性.get("速", 0))}
	# 战斗型命格常驻加成（攻防血速等比例乘性，低于装备贡献占比）
	# 装备加成映射到战斗属性（解决总战力与实战属性脱钩问题）
	# 每个穿戴位的装备基础战力按槽位类型折算为对应属性的flat加成
	var 槽位映射: Array = [
		{"攻": 0.50},                                    # 0 法兵：主加攻击
		{"防": 0.30, "血": 0.30},                      # 1 道冠：防御+气血
		{"防": 0.40, "血": 0.20},                      # 2 法袍：主防副血
		{"攻": 0.30, "防": 0.10},                      # 3 灵腕：攻击+少量防
		{"血": 0.50},                                    # 4 束灵带：主加气血
		{"防": 0.30, "速": 0.20},                      # 5 灵裤：防御+速度
		{"速": 0.50},                                    # 6 云靴：主加速度
		{"攻": 0.15, "防": 0.15, "血": 0.15, "速": 0.15},  # 7 灵饰：均衡小幅
		{"攻": 0.15, "防": 0.15, "血": 0.15, "速": 0.15},  # 8 本命法宝(S1占位)
	]
	var 槽位名列表: Array = ["法兵","道冠","法袍","灵腕","束灵带","灵裤","云靴","灵饰","本命法宝"]   # 与 Item.槽显示 value 逐字同步（P0 方案A）
	for 槽idx in range(9):
		var 槽名: String = 槽位名列表[槽idx]
		if not 装备.has(槽名):
			continue
		var it: Item = 装备[槽名]
		var pwr: int = it.装备基础战力()
		if pwr <= 0:
			continue
		var 映射: Dictionary = 槽位映射[槽idx]
		for stat in 映射.keys():
			战斗属性[stat] = int(战斗属性[stat] + pwr * 映射[stat])
	var 命格数据: Dictionary = DestinyDataLoader.get_destiny(destiny_id)
	if 命格数据.get("类型", "") == "战斗" and 命格数据.get("维度", "") in ["攻", "防", "血", "速"]:
		var 系数: float = 1.0 + float(命格数据.get("数值", 0)) / 100.0
		战斗属性[命格数据["维度"]] = int(战斗属性[命格数据["维度"]] * 系数)
	# 境界倍率：高境界四维碾压（解决练气弟子打不过练气怪的问题）
	var 境界倍: float = 境界战斗倍率.get(境界, 1.0)
	if 境界倍 > 1.0:
		for _st in ["攻","防","血","速"]:
			战斗属性[_st] = int(战斗属性[_st] * 境界倍)
	# ===== 未来战力来源统一映射入口（铁律见 MEMORY.md 战力映射铁律）=====
	# 任何加总战力的系统都必须在 _聚合未来战力来源() 返回 {攻,防,血,速} 增量并累加于此
	# 禁止只堆 总战力() 导致"虚高战力实战裸属性"脱钩（装备 Bug 教训 2026-07-20）
	var 外部加成: Dictionary = _聚合未来战力来源()
	for _st in 外部加成.keys():
		战斗属性[_st] = int(战斗属性[_st] + 外部加成[_st])
	# P0-BUILD-2：负责人全局微量 buff（攻/防/血/速 各乘 1+buff）；无负责人时 buff=0 → ×1.0 数值不变，
	# 与 总战力()/实时战力() 解耦，仅作用于实战属性（战斗结算口径）。
	var 全局buff: Dictionary = _取负责人全局buff()
	for _st in ["攻", "防", "血", "速"]:
		战斗属性[_st] = int(战斗属性[_st] * (1.0 + 全局buff.get(_st, 0.0)))
	return {
		"战力": 总战力(),
		"属性": 战斗属性,
		"职业": 职业,
		"灵根": {"主": 主灵根, "纯度": 纯度},
		"灵兽战力": 灵兽契约战力(),
		"灵兽": _灵兽出战快照(),
		"极品特效": 极品,
		"通用增益": 聚合通用增益(),
		"道心增益": 0.0,   # 当前无道心系统（ADR-001 §4.1 占位）
		"暴击率": 暴击率,
		"闪避率": 闪避率,
		"名称": 姓名,
		"技能": [],   # S1 批3：可释放技能列表（由 已修功法→skill.csv 解锁链接驱动，批4 unlock_skill 列就绪后填充；本批恒为 []）
		"功法被动": SkillCultivationLoader.功法被动加成(已修功法),   # S1 批3：功法被动四维增量（已修功法默认 [] → 全 0）
	}

# 纯度推导（P0 单灵根占位；多灵根档位预留）
func _推导纯度() -> String:
	return "单"

func to_dict() -> Dictionary:
	var 背包列表: Array = []
	for it in 背包:
		背包列表.append(it.to_dict())
	var 装备字典: Dictionary = {}
	for 槽 in 装备.keys():
		var it = 装备[槽]
		if it != null:
			装备字典[槽] = it.to_dict()
	return {
		"姓名": 姓名, "弟子ID": 弟子ID, "资质": 资质, "灵根": 灵根, "destiny_id": destiny_id, "性格": 性格,
		"境界": 境界, "寿元": 寿元, "基础修炼速度": 基础修炼速度, "修炼速度": 修炼速度, "战力": 战力, "备注": 备注,
		"职业": 职业, "堂口": 堂口, "修炼进度": 修炼进度, "年龄": 年龄, "瓶颈打磨值": 瓶颈打磨值, "稳固期剩余": 稳固期剩余, "丹毒": 丹毒,
		"灵根品阶": 灵根品阶, "身份": 身份, "来源": 来源,
		"阶位": 阶位, "考核冷却剩余": 考核冷却剩余, "考核心得": 考核心得,
		"层数": 层数, "突破冷却剩余": 突破冷却剩余,
		"属性": 属性, "背包": 背包列表, "装备": 装备字典, "履历": 履历, "已修功法": 已修功法, "当前法阵": 当前法阵,
		"辈分序": 辈分序, "道号": 道号,
		"主宠灵兽": (主宠灵兽.to_dict() if 主宠灵兽 != null else null),
		"副宠灵兽": (副宠灵兽.to_dict() if 副宠灵兽 != null else null)
	}

func from_dict(d: Dictionary):
	姓名 = d.get("姓名", "")
	# WAVE-B #2：恢复稳定ID（缺键→保留 _init 已分配的临时ID，旧档首次载入即获得唯一ID并随后续存档固化）
	弟子ID = int(d.get("弟子ID", 弟子ID))
	资质 = d.get("资质", "")
	灵根 = d.get("灵根", "")
	# 灵根品阶：新档直读；旧档按灵根类型推导（天灵根→天品 / 变异→极品 / 五行→上品）
	灵根品阶 = d.get("灵根品阶", "")
	if 灵根品阶 == "":
		if 灵根 == "天灵根":
			灵根品阶 = "天品"
		elif 灵根 in 灵根变异:
			灵根品阶 = "极品"
		else:
			灵根品阶 = "上品"
	var 原始身份: String = d.get("身份", "")
	var 旧命格名: String = d.get("命格", "")
	destiny_id = d.get("destiny_id", "")
	if destiny_id == "" and 旧命格名 != "":
		destiny_id = 旧命格映射.get(旧命格名, "")
	性格 = d.get("性格", "")
	境界 = d.get("境界", "练气")
	# 旧存档兼容：身份字段缺失时补默认（破格优先于境界晋升：天品必核心/极品必内门，否则按境界映射）
	if 原始身份 != "":
		身份 = 原始身份
	else:
		身份 = _默认身份(灵根品阶, 境界)
	来源 = d.get("来源", "")
	# S1 批1：阶位轴字段（旧档缺键 → 按身份推导 legacy 阶位，D1 豁免名额上限）
	阶位 = d.get("阶位", _默认阶位(身份))
	# === S1 批5-B：辈分礼制字段（旧档缺键 → 默认 0 / ""，零回归，照 L1056 .get 范式）===
	辈分序 = int(d.get("辈分序", 0))
	道号 = d.get("道号", "")
	考核冷却剩余 = int(d.get("考核冷却剩余", 0))
	考核心得 = bool(d.get("考核心得", false))
	寿元 = d.get("寿元", 80)
	基础修炼速度 = d.get("基础修炼速度", d.get("修炼速度", 1.0))
	修炼速度 = 基础修炼速度
	战力 = d.get("战力", 100)
	备注 = d.get("备注", "")
	职业 = d.get("职业", "")
	# @LEGACY-MIGRATION 存档兼容：旧档「剑修」职业迁移为「道修」（老大 2026-07-19 拍板，剑修后置为后续新增职业，不复用旧槽位）
	if 职业 == "剑修":  # @LEGACY-MIGRATION 旧档迁移兜底
		职业 = "道修"
	堂口 = d.get("堂口", "")
	修炼进度 = d.get("修炼进度", 0.0)
	# 10层体系：新档直读层数；旧档按旧修炼进度反推（伪层数→真层数，clamp 1-10）
	if d.has("层数"):
		层数 = int(d["层数"])
		层数 = clamp(层数, 1, 10)
	else:
		# 旧档兼容：原 修炼进度 0~1 对应伪层数 1-9 → 映射到真层数 1-9
		层数 = clamp(int(修炼进度 * 9) + 1, 1, 9)
	突破冷却剩余 = d.get("突破冷却剩余", 0.0)
	年龄 = d.get("年龄", 0.0)
	瓶颈打磨值 = d.get("瓶颈打磨值", 0.0)
	稳固期剩余 = d.get("稳固期剩余", 0.0)
	丹毒 = d.get("丹毒", 0.0)
	履历 = d.get("履历", [])
	属性 = d.get("属性", {})
	if typeof(属性) != TYPE_DICTIONARY:
		属性 = {}
	属性["攻"] = int(属性.get("攻", 0))
	属性["防"] = int(属性.get("防", 0))
	属性["血"] = int(属性.get("血", 0))
	属性["速"] = int(属性.get("速", 0))
	背包.clear()
	for itd in d.get("背包", d.get("物品", [])):
		var it: Item = Item.new()
		it.from_dict(itd)
		if it.类别 in ["dan_yao", "ling_cai"]:
			it.穿戴位 = ""
		背包.append(it)
	装备.clear()
	for 槽 in d.get("装备", {}).keys():
		var itd = d["装备"][槽]
		if typeof(itd) == TYPE_DICTIONARY:
			var it: Item = Item.new()
			it.from_dict(itd)
			if it.类别 in ["dan_yao", "ling_cai"]:
				it.穿戴位 = ""
			装备[槽] = it
	已修功法.clear()
	for gid in d.get("已修功法", []):
		if typeof(gid) == TYPE_STRING:
			已修功法.append(gid)
	# S1 批6-B：当前单人法阵（旧档缺键→默认空 Dict {}，零回归，照 L1062 .get 默认范式；不升 SAVE_VERSION）
	当前法阵 = d.get("当前法阵", {})
	_修复装备一致性()
	一键最优穿戴()        # 旧档迁移：背包物按 战力加成 贪心回填各槽（受 品阶≤境界 限制），使旧存档在新模型下战力不丢
	主宠灵兽 = null
	副宠灵兽 = null
	# 旧档兼容：原单 灵兽 字段迁移为主宠，副宠留空；新档直读双字段
	if d.has("灵兽") and d["灵兽"] != null:
		var b: Beast = Beast.new()
		b.from_dict(d["灵兽"])
		主宠灵兽 = b
	elif d.has("主宠灵兽") and d["主宠灵兽"] != null:
		var b: Beast = Beast.new()
		b.from_dict(d["主宠灵兽"])
		主宠灵兽 = b
	if d.has("副宠灵兽") and d["副宠灵兽"] != null:
		var b: Beast = Beast.new()
		b.from_dict(d["副宠灵兽"])
		副宠灵兽 = b
	_应用命格养成加成()   # 旧档/新档载入后，按 destiny_id 重算修行养成加成

# ===== 未来战力来源 → 真实属性增量聚合（铁律入口，禁止只改 总战力() 不映射）=====
func _聚合未来战力来源() -> Dictionary:
	var 聚合: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	# TODO(S1): 称号加成 = 称号表[当前称号].属性加成
	# TODO(S1): 丹药加成 = 激活丹药.属性buff(限时)
	# S1 批3：功法被动（复用 skill_cultivation.csv，经 SkillCultivationLoader 折算为 攻防血速 增量；
	#   已修功法默认 [] → 贡献 0，与 装备/灵兽 同链路、同战力映射铁律，现役战斗零变化）
	var 功法: Dictionary = SkillCultivationLoader.功法被动加成(已修功法)
	for _st in ["攻", "防", "血", "速"]:
		聚合[_st] += 功法.get(_st, 0)
	# S1 批6-B：法阵战斗属性聚合（铁律入口，零战斗触碰；与 功法/灵兽 同链路）
	# 宗门大阵防御类（批6-A 推迟接线，本批补）：当前主阵 eff_dim 含 防/血/速 → 等效进四维
	var 宗门主阵: String = Game.宗门大阵.get("当前主阵", "")
	if 宗门主阵 != "":
		var 宗门等级: int = int(Game.宗门大阵.get("等级", {}).get(宗门主阵, 1))
		var 增量甲: Dictionary = _法阵战斗增量(宗门主阵, 宗门等级, false)
		for _st in ["攻", "防", "血", "速"]:
			聚合[_st] += 增量甲.get(_st, 0)
	# 当前单人法阵常驻（含 灵根匹配 + 护盾→血 + 回蓝端口）
	if not 当前法阵.is_empty():
		var 阵id: String = 当前法阵.get("array_id", "")
		var 阵级: int = int(当前法阵.get("等级", 1))
		if 阵id != "":
			var 增量乙: Dictionary = _法阵战斗增量(阵id, 阵级, true)
			for _st in ["攻", "防", "血", "速"]:
				聚合[_st] += 增量乙.get(_st, 0)
			# 灵气上限+X%（D4 方案A，回蓝等效）：仅 eff_dim=灵气 时 增量乙 含 灵气 键（真实每回合回蓝回调 S2 [PLACEHOLDER]）
			var 灵气增量: int = 增量乙.get("灵气", 0)
			if 灵气增量 != 0:
				聚合["灵气"] = 聚合.get("灵气", 0) + 灵气增量
	# S1 战斗生效·优先级1：灵兽实战属性映射（与 灵兽契约战力() 共用同一因子，加法叠加进四维，不新增乘区）
	var 兽: Dictionary = 灵兽属性加成()
	for _st in ["攻", "防", "血", "速"]:
		聚合[_st] += 兽.get(_st, 0)
	# TODO(S1): 道心增益 = 道心等级.四维系数
	return 聚合

# ===== S1 批6-B：单人法阵（Layer2 常驻属性）辅助 =====
# 灵根匹配（D7）：match_element → 弟子灵根（单灵根模型）。
#   earth→土 / water→水 / metal→金 / wood→木 / fire→火；
#   fire_water→{火,水}；all_five→恒匹配；none→不判；
#   变异灵根（雷/冰/风/光/暗）无五行对应→不匹配（无惩罚）。
func _灵根匹配法阵(cfg_row: Dictionary) -> bool:
	var me: String = cfg_row.get("match_element", "none")
	if me == "none":
		return false
	if me == "all_five":
		return true
	if me == "fire_water":
		return 灵根 in ["火", "水"]
	var 元素表: Dictionary = {"earth": "土", "water": "水", "metal": "金", "wood": "木", "fire": "火"}
	var 元素: String = 元素表.get(me, "")
	return 元素 != "" and 灵根 == 元素

# 法阵战斗属性增量（攻防血速 + 护盾→血 + 灵气上限→灵气端口），零战斗触碰。
# 含匹配=true 时应用灵根匹配 ×1.05；单源子帽 ≤15%（[PLACEHOLDER] 真机校准）。
# 返回 {攻,防,血,速[,灵气]}；触发类·回血(post_battle & 血) 仅记录不实现回调（S2 端口）。
func _法阵战斗增量(array_id: String, 等级: int, 含匹配: bool) -> Dictionary:
	var r: Dictionary = {"攻": 0, "防": 0, "血": 0, "速": 0}
	var cfg_row: Dictionary = Game.阵法配置表.get(array_id, {})
	if cfg_row.is_empty():
		return r
	var eff_val: float = float(cfg_row.get("eff_val_base", "0")) * (1.0 + (等级 - 1) * float(cfg_row.get("level_growth_coef", "0")))
	if 含匹配 and _灵根匹配法阵(cfg_row):
		eff_val *= 1.05
	eff_val = clamp(eff_val, 0.0, 0.15)   # 单源子帽 ≤15%
	var core_eff: String = cfg_row.get("core_effect", "")
	var trigger: String = cfg_row.get("trigger", "")
	var dim: String = cfg_row.get("eff_dim", "")
	# 护盾（D4 属性等效）：最大生命+X% → 加 血（无护盾条视觉，R1）
	if "护盾" in core_eff:
		var 最大生命: int = int(属性.get("血", 0))
		r["血"] += int(最大生命 * eff_val)
		return r
	# 回蓝（D4 方案A 灵气上限+X% 端口）：eff_dim=灵气 → 灵气上限+X%（真实每回合回蓝 S2 [PLACEHOLDER]）
	if dim == "灵气":
		var 灵气底: int = int(Game.灵气)
		r["灵气"] = int(灵气底 * eff_val)
		return r
	# 触发类·回血（post_battle & 血）：仅记录，S2 结算后回调，本批不实现
	if trigger == "post_battle" and dim == "血":
		return r
	# 常驻攻防血速（百分比加成，基数为弟子自身基础属性）
	for _st in ["攻", "防", "血", "速"]:
		if dim.contains(_st):
			var base: int = int(属性.get(_st, 0))
			r[_st] += int(base * eff_val)
	return r

# ============ 实时战力度量（界面战力/推荐战力同口径，区别于 总战力() 乘性虚高值）============
# 用于弟子卡/出战列表显示，使玩家能用战力数字与关卡推荐战力直接对比（关卡设计对齐需求）。
func 实时战力() -> int:
	return BattleCalculator.战力度量(get_final_combat_attr())