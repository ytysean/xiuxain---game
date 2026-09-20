class_name FishingSystem
extends RefCounted

# 灵钓系统 - 休闲玩法 S46-P0（核心钓鱼闭环）
# 后端：纯产出型休闲，接主链（灵材->炼丹/炼器/符箓 sink），零触碰战斗核心
# 交互：单指 hold/release 张力模拟（触屏，禁 QTE）；UI 见 ui/page_fishing.gd
# 数值全部 [PLACEHOLDER·待实机调]，不升 SAVE_VERSION（旧档缺键默认初值）

const Item = preload("res://item.gd")

# ===== 灵渊（钓鱼点）内置定义 =====
# 四层对应钓具四阶解锁；P0 仅开放浅滩灵池，其余按钓道境界软门控
const 灵渊表: Array = [
	{"id": 0, "名": "浅滩灵池", "难度": 1.0, "需境界": 0},
	{"id": 1, "名": "灵渊中层", "难度": 1.4, "需境界": 1},
	{"id": 2, "名": "灵渊深处", "难度": 1.9, "需境界": 2},
	{"id": 3, "名": "虚空灵渊", "难度": 2.6, "需境界": 3},
]

# ===== 钓道境界表（独立成长线，修真化）=====
# 经验曲线优化：前期快速成长，中期稳步提升，后期长期追求
const 钓道境界表: Array = [
	{"名": "初窥", "经验": 0},
	{"名": "小成", "经验": 200},
	{"名": "大成", "经验": 600},
	{"名": "圆满", "经验": 1500},
	{"名": "通玄", "经验": 3500},
	{"名": "入圣", "经验": 7000},
]

# ===== 灵钓大赛规则（周轮换，奖励走威望·禁暴灵石）=====
const 大赛规则表: Array = [
	{"名称": "渔获计数", "描述": "一周内钓获总数登顶", "奖励威望": 15},
	{"名称": "重量榜", "描述": "钓得最重灵物", "奖励威望": 18},
	{"名称": "品类集齐", "描述": "集齐当周灵鱼品类", "奖励威望": 20},
	{"名称": "品阶之征", "描述": "钓得品阶≥宝之灵物", "奖励威望": 25},
	{"名称": "秘匣机缘", "描述": "开启灵渊秘匣", "奖励威望": 30},
	{"名称": "灵韵总积分", "描述": "灵韵累计积分登顶", "奖励威望": 22},
]

# ===== 灵鱼立绘（美术资产 art/characters/fish/）=====
# 名称 → 资产 stem；文件名规范 fish_{stem}_1024.png（stem = 拼音 + 品阶 fan/ling/bao/wang/sheng/xian）。
# 共 91 条，覆盖 config/fishing_catch.csv 全部「灵鱼」分层；浊物/奇巧/秘匣等非鱼获无立绘，UI 侧回落文字。
# 2026-09-16 补：原表仅 40 条，漏登记 51 条（资产早已在 fish/，纯缺映射 -> 钓到无立绘）。
# 注：「黑鳞鲫」资产 stem 为既有 heilini（历史命名），按品阶与语义就近归入。
const 灵鱼立绘表: Dictionary = {
	"青鳞鲤": "qinglinli_fan",
	"银须鲫": "yinxuji_fan",
	"碧眼鲢": "biyanlian_fan",
	"赤鳞鲤": "chilinli_ling",
	"黑鳞鲫": "heilini_fan",
	"金草鱼": "jincaoyu_fan",
	"土鲶鱼": "tunianyu_fan",
	"火鲈": "huolu_fan",
	"金鳜": "jingui_fan",
	"玄鲤": "xuanli_ling",
	"灵鳗": "lingman_ling",
	"灵鳝": "lingshan_ling",
	"灵鳅": "lingqiu_ling",
	"玉鳞鲤": "yulinli_ling",
	"龙鲤": "longli_bao",
	"凤鲤": "fengli_bao",
	"玄龟": "xuangui_bao",
	"灵鳖": "lingbie_bao",
	"金鳞龙鲤": "jinlinlongli_bao",
	"蛟龙幼崽": "jiaolong_wang",
	"鲲鹏幼崽": "kunpeng_wang",
	"鲛人": "jiaoren_wang",
	"玄龙幼崽": "xuanlong_wang",
	"灵鲲": "lingkun_wang",
	"真龙幼崽": "zhenlong_sheng",
	"神鲲": "shenkun_sheng",
	"天鲛": "tianjiao_sheng",
	"仙鲤": "xianli_xian",
	"天龙": "tianlong_xian",
	"应龙幼崽": "yinglong_sheng",
	"应龙": "yinglong_xian",
	"烛龙": "zhulong_xian",
	"凤凰鱼": "fenghuangyu_sheng",
	"麒麟鱼": "qilinyu_sheng",
	"玄武幼崽": "xuanwu_youzai_sheng",
	"白虎鱼": "baihuyu_sheng",
	"朱雀鱼": "zhuqueyu_sheng",
	"青龙鱼": "qinglongyu_sheng",
	"鲲鹏真身": "kunpeng_zhen_xian",
	"混沌灵鱼": "hundun_lingyu_xian",
	# ── 凡阶 ──
	"灵鲷": "lingdiao_fan",
	"银带鱼": "yindaiyu_fan",
	"青石斑": "qingshiban_fan",
	"金鲳鱼": "jinchangyu_fan",
	"墨乌贼": "mowuzei_fan",
	"海鳗": "haiman_fan",
	"比目鱼": "bimuyu_fan",
	"灵虾": "lingxia_fan",
	"青蟹": "qingxie_fan",
	"海马": "haima_fan",
	"海星": "haixing_fan",
	"海螺": "hailuo_fan",
	"扇贝": "shanbei_fan",
	"章鱼": "zhangyu_fan",
	# ── 灵阶 ──
	"龙纹斑": "longwenban_ling",
	"金焰鲷": "jinyandiao_ling",
	"深海鮟鱇": "shenhai_ankang_ling",
	"飞鱼": "feiyu_ling",
	"剑鱼": "jianyu_ling",
	"灵龙虾": "linglongxia_ling",
	"幻光水母": "huanguang_shuimu_ling",
	# ── 宝阶 ──
	"龙纹石斑王": "longwenshibanwang_bao",
	"金焰鲷王": "jinyandiaowang_bao",
	"深海皇带鱼": "shenhai_huangdaiyu_bao",
	"灵珊瑚": "lingshanhu_bao",
	"千年灵蚌": "qiannianlingbang_bao",
	"灵海龙": "linghailong_bao",
	"幻彩海兔": "huancai_haitu_bao",
	# ── 王阶 ──
	"龙纹石斑皇": "longwenshibanhuang_wang",
	"金焰鲷皇": "jinyandiaohuang_wang",
	"深海巨乌贼": "shenhai_juwuzei_wang",
	"灵珊瑚皇": "lingshanhuhuang_wang",
	"千年灵蚌王": "qiannianlingbangwang_wang",
	"海妖": "haiyao_wang",
	"剑鱼王": "jianyuwang_wang",
	# ── 圣阶 ──
	"龙纹石斑圣": "longwenshibansheng_sheng",
	"金焰鲷圣": "jinyandiaosheng_sheng",
	"深海巨乌贼圣": "shenhai_juwuzeisheng_sheng",
	"灵珊瑚圣": "lingshanhusheng_sheng",
	"千年灵蚌圣": "qiannianlingbangsheng_sheng",
	"海妖圣": "haiyaosheng_sheng",
	"剑鱼圣": "jianyusheng_sheng",
	"烛龙幼崽": "zhulong_youzai_sheng",
	# ── 仙阶 ──
	"天鲛皇": "tianjiaohuang_xian",
	"蓬莱仙鲤": "penglai_xianli_xian",
	"瑶池仙鱼": "yaochi_xianyu_xian",
	"北冥神鲲": "beiming_shenkun_xian",
	"东海龙王": "donghai_longwang_xian",
	"西海龙王": "xihai_longwang_xian",
	"南海龙王": "nanhai_longwang_xian",
	"北海龙王": "beihai_longwang_xian",
}

# ===== 神秘类生物立绘（特殊隐藏类别，大家都没见过的生物）=====
# 神秘类不是常规品阶，而是特殊隐藏生物，极其稀有
const 神秘类立绘表: Dictionary = {
	"时空游鱼": "shikong_youyu_shenmi",
	"混沌孑遗": "hundun_jieyi_shenmi",
	"虚空噬灵": "xukong_shiling_shenmi",
	"轮回之鱼": "lunhui_zhiyu_shenmi",
	"天道碎片": "tiandao_suipian_shenmi",
	"太初古灵": "taichu_guling_shenmi",
	"因果之灵": "yinguo_zhiling_shenmi",
	"梦境游鱼": "mengjing_youyu_shenmi",
}

# ===== 混沌孑遗多变体系统（每次遇到外观不同）=====
# 准备10个变体立绘，每次遇到随机选一个
const 混沌孑遗变体表: Array = [
	"hundun_jieyi_shenmi_v1",
	"hundun_jieyi_shenmi_v2",
	"hundun_jieyi_shenmi_v3",
	"hundun_jieyi_shenmi_v4",
	"hundun_jieyi_shenmi_v5",
	"hundun_jieyi_shenmi_v6",
	"hundun_jieyi_shenmi_v7",
	"hundun_jieyi_shenmi_v8",
	"hundun_jieyi_shenmi_v9",
	"hundun_jieyi_shenmi_v10",
]

# 混沌孑遗随机特征描述库
const 混沌特征_颜色: Array = ["赤金", "幽蓝", "墨紫", "莹白", "青碧", "殷红", "鎏金", "玄黑", "银灰", "琉璃"]
const 混沌特征_纹路: Array = ["纹路如火焰", "纹路如流水", "纹路如星辰", "纹路如雷电", "纹路如山川", "纹路如草木", "纹路如骨血", "纹路如符文", "纹路如漩涡", "纹路如裂隙"]
const 混沌特征_气质: Array = ["气息狂暴", "气息幽深", "气息圣洁", "气息诡异", "气息古朴", "气息灵动", "气息威严", "气息飘渺", "气息炽烈", "气息寒凉"]

# 混沌孑遗收录记录：key=玩家命名，value={变体ID, 颜色, 纹路, 气质, 收服日}
var 混沌孑遗记录: Dictionary = {}
# 本次遇到的混沌孑遗临时数据（等待玩家命名）
var 本次混沌孑遗: Dictionary = {}

# ===== 配置表（表格驱动零硬编码）=====
var 钓鱼产出表: Array = []
var 钓具表: Array = []
var 钓鱼灵饵表: Array = []
var 当前灵饵: String = "凡俗饵"

# ===== 状态变量 =====
var 钓道经验: int = 0
var 钓道境界: int = 0          # 索引到 钓道境界表
var 累计钓获次数: int = 0
var 钓具配置: Dictionary = {"阶": 0}   # 与 Game.钓具配置 同步；P1 扩杆/线/饵品阶
var 本周大赛参与: int = 0
var 上周大赛周序: int = -1
# 每日灵钓机缘次数（综合方案A+B：每日固定次数，超出后经验减半、鱼获品质降低）
var 今日灵钓次数: int = 0
var 今日灵钓日期: int = -1  # 记录上次重置的游戏日，用于每日重置
# 钓鱼记录：key=鱼名，value={首钓日, 最重, 最长, 总数}（钓鱼佬核心追求）
var 钓鱼记录: Dictionary = {}
# 神兽降服记录：key=鱼名，value={已发现, 已降服, 首次遭遇日, 首次降服日, 降服次数, 逃走次数}（王/圣阶专用）
var 神兽降服记录: Dictionary = {}
# 神兽逃走冷却：key=鱼名，value=冷却结束日（逃走后7游戏日内不再出现）
var 神兽逃走冷却: Dictionary = {}
# 连续钓鱼天数记录
var 上次钓鱼日: int = -1
var 连续钓鱼天数: int = 0
# ===== 时空回溯符（时空游鱼特殊机制）=====
# 钓到时空游鱼后获得回溯符，使用后可撤销上一次钓鱼结果重新钓一次
var 上次钓鱼结果: Dictionary = {}  # 保存上一次钓鱼结果
var 回溯符数量: int = 0  # 玩家拥有的回溯符数量
# ===== 神秘类生物触发机制 =====
# 神秘类不是常规品阶，是特殊隐藏生物，需要特定条件触发
# 触发条件：钓道境界≥大成(2) + 极低概率 + 特定灵渊深度

func _init() -> void:
	加载钓鱼配置()

func 加载钓鱼配置() -> void:
	if 钓鱼产出表.is_empty():
		钓鱼产出表 = DestinyDataLoader._read_csv("res://config/fishing_catch.csv")
	if 钓具表.is_empty():
		钓具表 = DestinyDataLoader._read_csv("res://config/fishing_tackle.csv")
	if 钓鱼灵饵表.is_empty():
		钓鱼灵饵表 = DestinyDataLoader._read_csv("res://config/fishing_bait.csv")

# ===== 灵渊 / 钓具 查询 =====
func 获取灵渊(灵渊id: int) -> Dictionary:
	for r in 灵渊表:
		if int(r.get("id")) == 灵渊id:
			return r
	return 灵渊表[0]

func 获取钓具(阶: int) -> Dictionary:
	for r in 钓具表:
		if int(r.get("阶", -1)) == 阶:
			return r
	return {}

# 按钓道境界返回已解锁灵渊列表（软门控）
func 可钓灵渊() -> Array:
	var 可: Array = []
	for r in 灵渊表:
		if int(r.get("需境界")) <= 钓道境界:
			可.append(r)
	return 可

# ===== 开始灵钓：返回张力模拟参数供 UI =====
func 开始灵钓(灵渊id: int) -> Dictionary:
	var 渊: Dictionary = 获取灵渊(灵渊id)
	var 难度: float = float(渊.get("难度", 1.0))
	# P0联动：饵料消耗（sink闭环）
	if 当前灵饵 != "凡俗饵":
		var 饵配置: Dictionary = 获取灵饵(当前灵饵)
		var 灵材消耗: int = int(饵配置.get("灵材消耗", 0))
		if 灵材消耗 > 0:
			if Game.灵草 >= 灵材消耗:
				Game.灵草 -= 灵材消耗
			else:
				return {"成功": false, "原因": "灵草不足，无法配制%s（需灵草%d）" % [当前灵饵, 灵材消耗]}
	# 检查接近解锁的顶级鱼类，给出提示
	var 接近: Array = 获取接近解锁鱼类(灵渊id)
	var 提示: String = ""
	if not 接近.is_empty() and randf() < 0.3:  # 30%概率给出提示
		var 鱼: Dictionary = 接近[randi() % 接近.size()]
		var 鱼名: String = 鱼.get("名称", "神物")
		var 品阶: String = 鱼.get("品阶", "")
		提示 = "水中似有%s游动，若能提升钓道境界或配制%s，或可一窥真容。" % [品阶, 鱼.get("所需灵饵", "灵饵")]
		if Game != null:
			Game.添加纪事("灵钓异兆", "水中异兆", 提示, 0)
	# [PLACEHOLDER·待实机调] 张力参数初值
	var 超出次数: bool = _是否超出机缘次数()
	var 剩余次数: int = 获取剩余机缘次数()
	var 次数提示: String = ""
	if 超出次数:
		次数提示 = "今日灵钓机缘已尽，再钓则收获减半、灵物品质下降。"
	return {
		"灵渊名": 渊.get("名", "浅滩灵池"),
		"张力上限": 100.0,
		"绿区下": 42.0,
		"绿区上": 68.0,
		"升速": 9.0 * 难度,     # hold 收线时每秒张力增量
		"降速": 12.0 * 难度,    # release 放线时每秒张力减量
		"力竭周期秒": 6.0,       # 鱼力竭窗口出现周期 [PLACEHOLDER]
		"力竭时长秒": 1.6,       # 力竭窗口可安全拉近时长 [PLACEHOLDER]
		"异兆提示": 提示,
		"剩余机缘次数": 剩余次数,
		"今日总次数": 获取每日机缘次数(),
		"超出机缘次数": 超出次数,
		"次数提示": 次数提示,
	}

# ===== 结算钓获：张力表现(0~1, 越高越接近理想) -> 钓获结果 =====
func 结算钓获(张力表现: float, 灵渊id: int) -> Dictionary:
	var 渊: Dictionary = 获取灵渊(灵渊id)
	# 记录今日钓鱼次数
	_记录今日钓鱼次数()
	var 超出次数: bool = _是否超出机缘次数()
	# 仙阶机缘触发（钓鱼途中，收线完成后概率触发仙物现身）
	# 仙阶不是"钓"，是"遇"——垂钓时忽遇仙缘，水中仙物主动现身
	# 注意：超出机缘次数后，仙阶机缘概率减半（仍可触发，但更难）
	var 仙缘: Dictionary = 触发仙阶机缘(灵渊id, 超出次数)
	if bool(仙缘.get("成功", false)):
		# 记录钓鱼次数和经验（遭遇仙缘也算一次钓鱼经历）
		累计钓获次数 += 1
		var 增经验: int = 10 + int(品阶序位("仙阶")) * 2
		if 超出次数:
			增经验 = int(增经验 / 2)  # 超出次数经验减半
		var 突破: bool = 增加钓道经验(增经验)
		_更新连续钓鱼天数()
		return {
			"成功": true,
			"仙阶现身": true,
			"仙缘信息": 仙缘,
			"名称": 仙缘.get("名称", ""),
			"品阶": "仙阶",
			"分层": 仙缘.get("分层", "灵鱼"),
			"需要结缘": true,
			"获得经验": 增经验,
			"境界突破": 突破,
			"超出机缘次数": 超出次数,
			"灵渊名": 渊.get("名", "浅滩灵池"),
			"提示": 仙缘.get("提示", ""),
		}
	# ===== 神秘类生物触发（特殊隐藏生物，大家都没见过的）=====
	# 触发条件：钓道境界≥大成(2) + 极低概率 + 灵渊深度≥2
	var 神秘遇: Dictionary = 触发神秘类机缘(灵渊id, 超出次数)
	if bool(神秘遇.get("成功", false)):
		累计钓获次数 += 1
		var 增经验: int = 15 + int(品阶序位("仙阶")) * 2
		if 超出次数:
			增经验 = int(增经验 / 2)
		var 突破: bool = 增加钓道经验(增经验)
		_更新连续钓鱼天数()
		# 保存本次结果作为上次结果（用于回溯符）
		上次钓鱼结果 = {
			"成功": true,
			"名称": 神秘遇.get("名称", ""),
			"品阶": "神秘",
			"分层": "灵鱼",
		}
		# 混沌孑遗特殊处理：需要玩家命名
		if 神秘遇.get("名称", "") == "混沌孑遗":
			本次混沌孑遗 = 神秘遇.get("混沌数据", {})
			return {
				"成功": true,
				"神秘现身": true,
				"神秘信息": 神秘遇,
				"名称": "混沌孑遗",
				"品阶": "神秘",
				"分层": "灵鱼",
				"需要命名": true,
				"混沌变体ID": 神秘遇.get("变体ID", 0),
				"混沌特征": 神秘遇.get("特征描述", ""),
				"获得经验": 增经验,
				"境界突破": 突破,
				"灵渊名": 渊.get("名", "浅滩灵池"),
				"提示": "水中忽现混沌之气，一只无定形的神秘生物浮现！此乃混沌孑遗，可自行命名收录。",
			}
		# 时空游鱼特殊处理：获得回溯符
		if 神秘遇.get("名称", "") == "时空游鱼":
			回溯符数量 += 1
			return {
				"成功": true,
				"神秘现身": true,
				"神秘信息": 神秘遇,
				"名称": "时空游鱼",
				"品阶": "神秘",
				"分层": "灵鱼",
				"获得回溯符": true,
				"回溯符数量": 回溯符数量,
				"获得经验": 增经验,
				"境界突破": 突破,
				"灵渊名": 渊.get("名", "浅滩灵池"),
				"提示": "时空裂隙中游出一尾半透明的灵鱼，它赠予你一枚「时空回溯符」，可回溯一次钓鱼结果！",
			}
		# 其他神秘类生物
		return {
			"成功": true,
			"神秘现身": true,
			"神秘信息": 神秘遇,
			"名称": 神秘遇.get("名称", ""),
			"品阶": "神秘",
			"分层": "灵鱼",
			"获得经验": 增经验,
			"境界突破": 突破,
			"灵渊名": 渊.get("名", "浅滩灵池"),
			"提示": 神秘遇.get("提示", ""),
		}
	var pool: Array = []
	var 当前阶: int = int(钓具配置.get("阶", 0))
	for r in 钓鱼产出表:
		# 前置条件检查（钓具阶+钓道境界+灵渊+灵饵+累计钓获+特殊条件）
		if not _检查鱼获前置条件(r, 灵渊id):
			continue
		if int(r.get("最低钓具阶", 0)) <= 当前阶:
			# 超出机缘次数后，王阶及以上灵鱼不再上钩（品质降低）
			if 超出次数 and r.get("分层", "") == "灵鱼" and r.get("品阶", "") in ["王阶", "圣阶", "仙阶"]:
				continue
			pool.append(r)
	if pool.is_empty():
		return {"成功": false, "原因": "当前条件下无可钓灵物（提升钓道境界/更换灵渊/配制灵饵）"}
	# 灵饵加成（基础稀有加成 + 特定鱼类加成）
	var 饵加成: float = 0.0
	var 饵特定鱼: String = ""
	var 饵目标品阶: String = ""
	if 当前灵饵 != "凡俗饵":
		var 饵行: Dictionary = 获取灵饵(当前灵饵)
		if not 饵行.is_empty():
			饵加成 = float(饵行.get("稀有加成", 0.0))
			饵特定鱼 = 饵行.get("特定鱼类加成", "")
			饵目标品阶 = 饵行.get("目标品阶加成", "")
	# 功法加成（检查宗主是否学习灵钓辅助功法）
	var 功法加成: Dictionary = _获取灵钓功法加成()
	# 加权随机抽四分层（按灵饵+功法修正权重）
	var weights: Array = []
	var total: float = 0.0
	for r in pool:
		var w: float = float(r.get("掉落权重", 1.0))
		var 鱼名: String = r.get("名称", "")
		var 鱼品阶: String = r.get("品阶", "")
		var 鱼分层: String = r.get("分层", "灵鱼")
		# 基础稀有加成
		if 饵加成 != 0.0:
			if 鱼分层 == "奇巧" or 鱼分层 == "秘匣":
				w *= (1.0 + 饵加成)
			elif 鱼分层 == "浊物":
				w *= max(0.2, 1.0 - 饵加成 * 0.5)
		# 灵饵特定鱼类加成
		if 饵特定鱼 != "":
			if _匹配特定鱼类(鱼名, 饵特定鱼):
				w *= 2.5  # 特定鱼类权重×2.5
		# 灵饵目标品阶加成
		if 饵目标品阶 != "" and 鱼品阶 == 饵目标品阶:
			w *= 1.8
		# 功法加成
		if not 功法加成.is_empty():
			# 龙族鱼概率加成
			if 功法加成.has("龙族鱼概率") and _匹配特定鱼类(鱼名, "龙族"):
				w *= (1.0 + float(功法加成["龙族鱼概率"]))
			# 鲲类鱼概率加成
			if 功法加成.has("鲲类鱼概率") and _匹配特定鱼类(鱼名, "鲲类"):
				w *= (1.0 + float(功法加成["鲲类鱼概率"]))
			# 鲛人概率加成
			if 功法加成.has("鲛人概率") and _匹配特定鱼类(鱼名, "鲛人"):
				w *= (1.0 + float(功法加成["鲛人概率"]))
			# 稀有鱼概率加成
			if 功法加成.has("稀有鱼概率") and 鱼品阶 in ["宝阶", "王阶", "圣阶", "仙阶"]:
				w *= (1.0 + float(功法加成["稀有鱼概率"]))
			# 秘匣概率加成
			if 功法加成.has("秘匣概率") and 鱼分层 == "秘匣":
				w *= (1.0 + float(功法加成["秘匣概率"]))
			# 奇巧物概率加成
			if 功法加成.has("奇巧物概率") and 鱼分层 == "奇巧":
				w *= (1.0 + float(功法加成["奇巧物概率"]))
			# 仙阶鱼概率加成
			if 功法加成.has("仙阶鱼概率") and 鱼品阶 == "仙阶":
				w *= (1.0 + float(功法加成["仙阶鱼概率"]))
		# 超出机缘次数后的惩罚（防止无限刷宝箱）
		if 超出次数:
			if 鱼分层 == "秘匣":
				w *= 0.5  # 秘匣出现概率降低50%
			elif 鱼分层 == "奇巧":
				w *= 0.7  # 奇巧物出现概率降低30%
			elif 鱼分层 == "浊物":
				w *= 1.5  # 浊物概率增加（惩罚期更容易钓到垃圾）
		weights.append(w)
		total += w
	var roll: float = randf() * total
	var pick: Dictionary = pool[0]
	for i in range(pool.size()):
		roll -= weights[i]
		if roll <= 0.0:
			pick = pool[i]
			break
	var 名称: String = pick.get("名称", "未知灵物")
	var 分层: String = pick.get("分层", "灵鱼")
	var 品阶: String = pick.get("品阶", "凡阶")
	var 五行: String = pick.get("五行", "无")
	var 灵韵: int = int(pick.get("灵韵", 0))
	var 描述: String = pick.get("描述", "")
	var 用途: String = pick.get("用途", "")
	# 六维数值
	var 重量: float = randf_range(float(pick.get("重量区间_低", 0.0)), float(pick.get("重量区间_高", 1.0)))
	var 长度: float = randf_range(float(pick.get("长度区间_低", 0.0)), float(pick.get("长度区间_高", 1.0)))
	var 钓获难度: int = int(pick.get("钓获难度", 1))
	# ===== 品阶分层获取方式 =====
	# 王/圣阶：上钩后进入降服环节，不直接入库
	if 品阶 in ["王阶", "圣阶"] and 分层 == "灵鱼":
		# 记录已发现（上钩即收录）
		var 首次遭遇: bool = _记录神兽遭遇(名称, 品阶)
		# 经验与计数（遭遇也给少量经验）
		累计钓获次数 += 1
		var 增经验: int = 钓获难度 + int(品阶序位(品阶))
		if 超出次数:
			增经验 = int(增经验 / 2)  # 超出次数经验减半
		var 突破: bool = 增加钓道经验(增经验)
		_更新连续钓鱼天数()
		# 返回需要降服的状态
		return {
			"成功": true,
			"名称": 名称,
			"分层": 分层,
			"品阶": 品阶,
			"五行": 五行,
			"灵韵": 灵韵,
			"重量": 重量,
			"长度": 长度,
			"钓获难度": 钓获难度,
			"用途": 用途,
			"需要降服": true,
			"首次遭遇": 首次遭遇,
			"获得经验": 增经验,
			"境界突破": 突破,
			"灵渊名": 渊.get("名", "浅滩灵池"),
			"提示": "%s上钩！此等神兽非寻常钓获可致，需设法降服。" % 名称,
		}
	# 仙阶：不通过钓鱼上钩，理论上不应出现在池中（特殊机缘触发）
	if 品阶 == "仙阶" and 分层 == "灵鱼":
		# 记录已发现（机缘现身）
		var 首次遭遇: bool = _记录神兽遭遇(名称, 品阶)
		累计钓获次数 += 1
		var 增经验: int = 钓获难度 + int(品阶序位(品阶)) * 2
		var 突破: bool = 增加钓道经验(增经验)
		_更新连续钓鱼天数()
		return {
			"成功": true,
			"名称": 名称,
			"分层": 分层,
			"品阶": 品阶,
			"五行": 五行,
			"灵韵": 灵韵,
			"重量": 重量,
			"长度": 长度,
			"钓获难度": 钓获难度,
			"用途": 用途,
			"需要结缘": true,
			"首次遭遇": 首次遭遇,
			"获得经验": 增经验,
			"境界突破": 突破,
			"灵渊名": 渊.get("名", "浅滩灵池"),
			"提示": "%s现身！此等仙物非力可致，需以诚心结缘。" % 名称,
		}
	# 凡/灵/宝阶：正常钓获逻辑
	# 记录图录（匹配名须已注册到 收藏图录分类.csv）
	var 新收录: bool = false
	if Game != null:
		新收录 = Game._记录图录(名称, "灵钓")
	# 生成灵材入库（接主链 sink）
	var it: Item = Item.new()
	it.类别 = "ling_cai"
	it.品阶 = 品阶
	it.名称 = 名称
	it.描述 = "%s（%s·%s属·灵韵%d，重%.1f钧，长%.1f尺）" % [描述, 分层, 五行, 灵韵, 重量, 长度]
	it.功效 = 用途
	if Game != null:
		Game.宗门库房.append(it)
	# 经验与计数
	累计钓获次数 += 1
	var 增经验: int = 钓获难度 * 2 + int(品阶序位(品阶))
	if 超出次数:
		增经验 = int(增经验 / 2)  # 超出次数经验减半
	var 突破: bool = 增加钓道经验(增经验)
	# 更新钓鱼记录（钓鱼佬核心追求：首钓/最重/最长/总数）
	var 新纪录: bool = _更新钓鱼记录(名称, 重量, 长度)
	# 更新连续钓鱼天数
	_更新连续钓鱼天数()
	# 灵钓奇遇（受控通道，禁自建池）[PLACEHOLDER 触发率]
	if Game != null and Game.宗主 != null and (分层 == "秘匣" or randf() < 0.01):
		Game._尝试触发奇遇(Game.宗主, "灵钓")
	# ===== 灵钓功法感悟（钓到特定鱼类时概率感悟）=====
	if Game != null and Game.宗主 != null:
		_尝试灵钓功法感悟(名称, 品阶, 分层)
	# ===== 秘匣开出功法（钓到秘匣时概率开出功法）=====
	if 分层 == "秘匣" and Game != null and Game.宗主 != null:
		_尝试秘匣开出功法()
	# ===== 灵钓奇遇剧情（特殊触发剧情）=====
	if Game != null and Game.宗主 != null:
		_尝试触发灵钓奇遇(名称, 品阶, 分层, 灵渊id)
	# ===== 顶级鱼获特殊处置方式提示 =====
	var 可用处置: Array = []
	if 品阶序位(品阶) >= 品阶序位("宝阶") and 分层 == "灵鱼":
		可用处置 = 获取鱼获处置方式(名称, 品阶, 分层)
	return {
		"成功": true,
		"名称": 名称,
		"分层": 分层,
		"品阶": 品阶,
		"五行": 五行,
		"灵韵": 灵韵,
		"重量": 重量,
		"长度": 长度,
		"钓获难度": 钓获难度,
		"用途": 用途,
		"新收录": 新收录,
		"新纪录": 新纪录,
		"获得经验": 增经验,
		"境界突破": 突破,
		"灵渊名": 渊.get("名", "浅滩灵池"),
		"可用处置方式": 可用处置,
	}
	# 保存本次结果作为上次结果（用于回溯符）
	上次钓鱼结果 = {
		"成功": true,
		"名称": 名称,
		"品阶": 品阶,
		"分层": 分层,
	}

# ===== 鱼获前置条件检查 =====
func _检查鱼获前置条件(r: Dictionary, 灵渊id: int) -> bool:
	# 神兽逃走冷却检查（王/圣/仙阶灵鱼）
	var 鱼名: String = r.get("名称", "")
	var 鱼品阶: String = r.get("品阶", "")
	var 鱼分层: String = r.get("分层", "")
	if 鱼分层 == "灵鱼" and 鱼品阶 in ["王阶", "圣阶", "仙阶"]:
		if _检查神兽冷却(鱼名):
			return false
	# 仙阶生物不通过钓鱼上钩（特殊机缘触发）
	if 鱼分层 == "灵鱼" and 鱼品阶 == "仙阶":
		return false
	# 最低钓道境界
	var 需境界: int = int(r.get("最低钓道境界", 0))
	if 钓道境界 < 需境界:
		return false
	# 所需灵渊
	var 需灵渊: int = int(r.get("所需灵渊", 0))
	if 灵渊id < 需灵渊:
		return false
	# 所需灵饵
	var 需灵饵: String = r.get("所需灵饵", "凡俗饵")
	if 需灵饵 != "凡饵" and 当前灵饵 != 需灵饵:
		# 灵饵品阶检查（凡饵<灵饵<宝饵<仙饵）
		var 饵阶: Dictionary = {"凡饵": 0, "灵饵": 1, "宝饵": 2, "仙饵": 3}
		var 当前阶: int = 饵阶.get(当前灵饵, 0)
		var 需阶: int = 饵阶.get(需灵饵, 0)
		if 当前阶 < 需阶:
			return false
	# 累计钓获解锁
	var 需累计: int = int(r.get("累计钓获解锁", 0))
	if 累计钓获次数 < 需累计:
		return false
	# 特殊条件：连续钓鱼天数
	var 特殊: String = r.get("特殊条件", "")
	if 特殊.find("连续钓鱼") >= 0:
		# 解析"连续钓鱼N日"
		var 天数字符: String = 特殊.replace("连续钓鱼", "").replace("日", "").replace("+机缘", "").strip_edges()
		var 需天数: int = 0
		if 天数字符.is_valid_int():
			需天数 = int(天数字符)
		if 连续钓鱼天数 < 需天数:
			return false
	return true

# 获取可钓鱼类列表（用于UI显示和提示）
func 获取可钓鱼类(灵渊id: int) -> Array:
	var 可钓: Array = []
	var 当前阶: int = int(钓具配置.get("阶", 0))
	for r in 钓鱼产出表:
		if int(r.get("最低钓具阶", 0)) <= 当前阶 and _检查鱼获前置条件(r, 灵渊id):
			可钓.append(r)
	return 可钓

# 获取未解锁但接近解锁的鱼类（用于提示）
func 获取接近解锁鱼类(灵渊id: int) -> Array:
	var 接近: Array = []
	var 当前阶: int = int(钓具配置.get("阶", 0))
	for r in 钓鱼产出表:
		if int(r.get("最低钓具阶", 0)) > 当前阶:
			continue
		if _检查鱼获前置条件(r, 灵渊id):
			continue
		# 检查是否接近解锁（差一个条件）
		var 需境界: int = int(r.get("最低钓道境界", 0))
		var 需累计: int = int(r.get("累计钓获解锁", 0))
		if 钓道境界 == 需境界 - 1 or (需累计 > 0 and 累计钓获次数 >= 需累计 * 0.8):
			接近.append(r)
	return 接近

# 匹配特定鱼类类别（龙族/鲲类/鲛人/凤族/玄武/麒麟/四象/混沌）
func _匹配特定鱼类(鱼名: String, 类别: String) -> bool:
	var 关键词: Dictionary = {
		"龙族": ["龙", "蛟", "应龙", "烛龙"],
		"鲲类": ["鲲", "鹏"],
		"鲛人": ["鲛"],
		"凤族": ["凤", "朱雀"],
		"玄武": ["玄武", "龟", "鳖"],
		"麒麟": ["麒麟"],
		"四象": ["青龙", "白虎", "朱雀", "玄武"],
		"混沌": ["混沌"],
		"灵鱼": ["鲤", "鲫", "鲢", "鲈", "鳜", "鳗", "鳝", "鳅"],
		"奇巧": ["珠", "珊瑚", "石", "盏"],
		"秘匣": ["匣", "箱", "宝"],
	}
	if 类别 == "五行对应":
		return true  # 五行饵对所有五行鱼都有加成
	var 关键词列表: Array = 关键词.get(类别, [])
	for kw in 关键词列表:
		if 鱼名.find(kw) >= 0:
			return true
	return false

# 获取宗主学习的灵钓功法加成
func _获取灵钓功法加成() -> Dictionary:
	var 加成: Dictionary = {}
	if Game == null or Game.宗主 == null:
		return 加成
	# 检查宗主已学功法
	var 已学功法: Array = []
	if "已学功法" in Game.宗主:
		已学功法 = Game.宗主["已学功法"]
	var 灵钓功法ID: Array = ["taigong_diaoyu", "shuijing_guanyu", "longli_yinling", "chuidiao_xinjing", "yuqiao_wenda", "beiming_kuntun", "jiaoren_qizhu", "dinghai_shenzhen"]
	for 功法ID in 已学功法:
		if 功法ID in 灵钓功法ID:
			var 功法 = GongFaSystem.功法库.get(功法ID)
			if 功法 != null and 功法.has("灵钓效果"):
				var 效果: Dictionary = 功法["灵钓效果"]
				for k in 效果.keys():
					if typeof(效果[k]) == TYPE_FLOAT or typeof(效果[k]) == TYPE_INT:
						加成[k] = float(加成.get(k, 0.0)) + float(效果[k])
	return 加成

# ===== 灵钓功法获取方式 =====
# 1. 钓到特定鱼类时概率感悟功法
func _尝试灵钓功法感悟(鱼名: String, 品阶: String, 分层: String) -> void:
	if Game == null or Game.宗主 == null:
		return
	var 已学功法: Array = []
	if "已学功法" in Game.宗主:
		已学功法 = Game.宗主["已学功法"]
	# 感悟概率：品阶越高概率越大
	var 感悟概率: float = 0.0
	if 品阶 == "灵阶":
		感悟概率 = 0.02
	elif 品阶 == "宝阶":
		感悟概率 = 0.05
	elif 品阶 == "王阶":
		感悟概率 = 0.08
	elif 品阶 == "圣阶":
		感悟概率 = 0.12
	elif 品阶 == "仙阶":
		感悟概率 = 0.15
	if randf() > 感悟概率:
		return
	# 根据钓到的鱼决定感悟哪本功法
	var 可感悟功法: Array = []
	# 凡阶功法：钓到任何鱼都有小概率感悟
	if "taigong_diaoyu" not in 已学功法:
		可感悟功法.append("taigong_diaoyu")
	# 灵阶功法：钓到灵阶及以上鱼
	if 品阶序位(品阶) >= 品阶序位("灵阶"):
		if "shuijing_guanyu" not in 已学功法:
			可感悟功法.append("shuijing_guanyu")
		if "chuidiao_xinjing" not in 已学功法:
			可感悟功法.append("chuidiao_xinjing")
	# 宝阶功法：钓到龙族/凤族鱼
	if _匹配特定鱼类(鱼名, "龙族") and "longli_yinling" not in 已学功法:
		可感悟功法.append("longli_yinling")
	if _匹配特定鱼类(鱼名, "凤族") and "yuqiao_wenda" not in 已学功法:
		可感悟功法.append("yuqiao_wenda")
	# 王阶功法：钓到鲲类鱼
	if _匹配特定鱼类(鱼名, "鲲类") and "beiming_kuntun" not in 已学功法:
		可感悟功法.append("beiming_kuntun")
	# 圣阶功法：钓到鲛人
	if _匹配特定鱼类(鱼名, "鲛人") and "jiaoren_qizhu" not in 已学功法:
		可感悟功法.append("jiaoren_qizhu")
	# 仙阶功法：钓到仙阶鱼
	if 品阶 == "仙阶" and "dinghai_shenzhen" not in 已学功法:
		可感悟功法.append("dinghai_shenzhen")
	if 可感悟功法.is_empty():
		return
	# 随机感悟一本
	var 感悟功法ID: String = 可感悟功法[randi() % 可感悟功法.size()]
	var 功法 = GongFaSystem.功法库.get(感悟功法ID)
	if 功法 == null:
		return
	# 学习功法
	if "已学功法" not in Game.宗主:
		Game.宗主["已学功法"] = []
	Game.宗主["已学功法"].append(感悟功法ID)
	# 添加纪事通知
	var 功法名: String = 功法.get("名称", "未知功法")
	if Game != null:
		Game._加推演条目("【灵钓感悟】垂钓之时，于水中悟得《%s》，钓道精进！" % 功法名, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "垂钓悟法！习得《%s》" % 功法名, 2)

# 2. 秘匣开出功法
func _尝试秘匣开出功法() -> void:
	if Game == null or Game.宗主 == null:
		return
	var 已学功法: Array = []
	if "已学功法" in Game.宗主:
		已学功法 = Game.宗主["已学功法"]
	# 秘匣开出功法概率：15%
	if randf() > 0.15:
		return
	# 可开出的功法（根据当前境界决定）
	var 可开出功法: Array = []
	var 灵钓功法ID: Array = ["taigong_diaoyu", "shuijing_guanyu", "longli_yinling", "chuidiao_xinjing", "yuqiao_wenda", "beiming_kuntun", "jiaoren_qizhu", "dinghai_shenzhen"]
	for 功法ID in 灵钓功法ID:
		if 功法ID not in 已学功法:
			var 功法 = GongFaSystem.功法库.get(功法ID)
			if 功法 != null:
				可开出功法.append(功法ID)
	if 可开出功法.is_empty():
		return
	# 随机开出一本（低品阶概率更高）
	var 权重: Array = []
	var total: float = 0.0
	for 功法ID in 可开出功法:
		var 功法 = GongFaSystem.功法库.get(功法ID)
		var 品阶: String = 功法.get("品阶", "凡阶")
		var w: float = 1.0
		if 品阶 == "凡阶":
			w = 4.0
		elif 品阶 == "灵阶":
			w = 3.0
		elif 品阶 == "宝阶":
			w = 2.0
		elif 品阶 == "王阶":
			w = 1.0
		elif 品阶 == "圣阶":
			w = 0.5
		elif 品阶 == "仙阶":
			w = 0.2
		权重.append(w)
		total += w
	var roll: float = randf() * total
	var 开出功法ID: String = 可开出功法[0]
	for i in range(可开出功法.size()):
		roll -= 权重[i]
		if roll <= 0.0:
			开出功法ID = 可开出功法[i]
			break
	# 学习功法
	if "已学功法" not in Game.宗主:
		Game.宗主["已学功法"] = []
	Game.宗主["已学功法"].append(开出功法ID)
	# 添加纪事通知
	var 功法 = GongFaSystem.功法库.get(开出功法ID)
	var 功法名: String = 功法.get("名称", "未知功法") if 功法 != null else "未知功法"
	if Game != null:
		Game._加推演条目("【秘匣遗珍】开启水中秘匣，得前人遗著《%s》！" % 功法名, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "秘匣遗珍！获得《%s》" % 功法名, 2)

# ===== 顶级鱼获特殊处置系统 =====
# 修真世界观：顶级灵鱼有灵，不可如凡鱼般烹食，需特殊处置

# ===== 灵钓奇遇剧情系统 =====
# 修真小说常见桥段：钓鱼时有概率触发特殊奇遇剧情
# 记录已放生的鲛人/龙族（用于报恩剧情）
var 已放生鲛人: bool = false
var 已放生龙族: int = 0

# 灵钓奇遇主入口（每次钓鱼结束后调用）
func _尝试触发灵钓奇遇(鱼名: String, 品阶: String, 分层: String, 灵渊id: int) -> void:
	if Game == null or Game.宗主 == null:
		return
	# 1. 水中传音（宝阶及以上鱼5%概率）
	if 品阶序位(品阶) >= 品阶序位("宝阶") and randf() < 0.05:
		_奇遇_水中传音(品阶)
		return
	# 2. 鱼跃龙门（钓到龙鲤时10%概率）
	if 鱼名.find("龙鲤") >= 0 and randf() < 0.10:
		_奇遇_鱼跃龙门(鱼名)
		return
	# 3. 鲛人报恩（之前放生过鲛人后，3%概率）
	if 已放生鲛人 and randf() < 0.03:
		_奇遇_鲛人报恩()
		return
	# 4. 上古遗物（钓到秘匣时20%概率，超出次数后5%概率）
	# 补：本函数作用域内原无 超出次数（其他函数中的同名局部变量不跨作用域），致编译失败
	var 超出次数: bool = _是否超出机缘次数()
	var 遗物概率: float = 0.05 if 超出次数 else 0.20
	if 分层 == "秘匣" and randf() < 遗物概率:
		_奇遇_上古遗物(超出次数)
		return
	# 5. 水府奇遇（灵渊深处3%概率）
	if 灵渊id >= 2 and randf() < 0.03:
		_奇遇_水府奇遇(灵渊id)
		return
	# 6. 垂钓悟道（连续钓鱼7天以上5%概率）
	if 连续钓鱼天数 >= 7 and randf() < 0.05:
		_奇遇_垂钓悟道()
		return
	# 7. 龙王赠宝（之前放生过龙族后，5%概率）
	if 已放生龙族 >= 1 and randf() < 0.05:
		_奇遇_龙王赠宝()
		return
	# 8. 定海神针传承（使用定海神针诀+仙阶鱼，3%概率）
	var 功法加成: Dictionary = _获取灵钓功法加成()
	if 功法加成.has("定海神针专属") and 品阶 == "仙阶" and randf() < 0.03:
		_奇遇_定海神针传承()
		return
	# 9. 姜太公遇文王（钓道境界通玄，2%概率）
	if 钓道境界 >= 4 and randf() < 0.02:
		_奇遇_姜太公遇文王()
		return
	# 10. 水中捞月（月满之夜特殊天气，暂用随机5%模拟）
	if randf() < 0.02:
		_奇遇_水中捞月()
		return

# 奇遇1：水中传音
func _奇遇_水中传音(品阶: String) -> void:
	var 感悟值: int = 20 * 品阶序位(品阶)
	Game.悟道点 += 感悟值
	var 文案: String = "【水中传音】垂钓之时，忽闻水中有仙人传音：「钓者，心也。水中自有乾坤。」宗主凝神静听，悟得大道至理，悟道点+%d！" % 感悟值
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "水中传音！悟道点+%d" % 感悟值, 2)

# 奇遇2：鱼跃龙门
func _奇遇_鱼跃龙门(鱼名: String) -> void:
	# 龙鲤跃龙门，化为蛟龙
	var 新名: String = "金睛蛟龙"
	var 兽: Beast = Beast.new()
	兽.种类名 = 新名
	兽.品阶 = "王阶"
	兽.等级 = 1
	兽.孵化中 = false
	Game.灵兽管理系统.灵兽库存.append(兽)
	var 文案: String = "【鱼跃龙门】所钓 %s 忽得机缘，纵身跃出水面，天地间灵气汇聚，竟化为一条 %s！此龙感恩宗主成全，自愿契约为灵兽。" % [鱼名, 新名]
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "鱼跃龙门！获得灵兽 %s" % 新名, 2)

# 奇遇3：鲛人报恩
func _奇遇_鲛人报恩() -> void:
	var 回报类型: int = randi() % 3
	var 文案: String = ""
	if 回报类型 == 0:
		# 鲛人泪珍珠
		var it: Item = Item.new()
		it.名称 = "鲛人泣泪珠"
		it.类别 = "ling_cai"
		it.品阶 = "圣阶"
		it.描述 = "鲛人感恩所赠，泣泪成珠，蕴含深海灵气。"
		Game.宗门库房.append(it)
		文案 = "【鲛人报恩】昔日放生之鲛人今日归来，泣泪成珠，献上一枚「鲛人泣泪珠」（圣阶），以报宗主恩德。"
	elif 回报类型 == 1:
		# 鲛绡
		var it: Item = Item.new()
		it.名称 = "鲛绡"
		it.类别 = "ling_cai"
		it.品阶 = "圣阶"
		it.描述 = "鲛人所织轻纱，入水不濡，入火不焦，为炼器至宝。"
		Game.宗门库房.append(it)
		文案 = "【鲛人报恩】昔日放生之鲛人今日归来，献上所织「鲛绡」（圣阶），此纱入水不濡，入火不焦。"
	else:
		# 功法感悟
		var 感悟值: int = 100
		Game.悟道点 += 感悟值
		文案 = "【鲛人报恩】昔日放生之鲛人今日归来，为宗主吟唱深海古歌，宗主闻之悟道，悟道点+%d！" % 感悟值
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "鲛人报恩！", 2)

# 奇遇4：上古遗物（超出次数后品质降低）
func _奇遇_上古遗物(超出次数: bool = false) -> void:
	var 遗物类型: int = randi() % 3
	var 文案: String = ""
	if 遗物类型 == 0:
		# 上古法宝碎片
		var it: Item = Item.new()
		it.名称 = "上古法宝碎片" if not 超出次数 else "古宝残片"
		it.类别 = "ling_cai"
		it.品阶 = "仙阶" if not 超出次数 else "宝阶"
		it.描述 = "上古仙人所用法宝碎片，虽已残破，仍蕴含磅礴灵力。" if not 超出次数 else "古时修士所用法宝残片，灵力微弱，聊胜于无。"
		Game.宗门库房.append(it)
		文案 = "【上古遗物】开启秘匣，其中并非凡物，而是一块「上古法宝碎片」（仙阶）！此宝虽残，灵力犹存。" if not 超出次数 else "【古宝残片】开启秘匣，其中是一块「古宝残片」（宝阶），灵力微弱，想来是机缘已尽之时所得。"
	elif 遗物类型 == 1:
		# 上古功法残卷
		var it: Item = Item.new()
		it.名称 = "上古功法残卷" if not 超出次数 else "古修功法残页"
		it.类别 = "gongfa_book"
		it.品阶 = "仙阶" if not 超出次数 else "宝阶"
		it.描述 = "上古功法残卷，字迹斑驳，隐约可见大道至理。" if not 超出次数 else "古修功法残页，字迹模糊，仅余只言片语。"
		it.功效 = "灵钓功法：dinghai_shenzhen" if not 超出次数 else "灵钓功法：普通"
		Game.宗门库房.append(it)
		文案 = "【上古遗物】开启秘匣，其中竟是一卷「上古功法残卷」（仙阶）！隐约可见《定海神针诀》五字。" if not 超出次数 else "【古修残页】开启秘匣，其中是一卷「古修功法残页」（宝阶），字迹模糊，难辨全貌。"
	else:
		# 上古储物袋
		var 灵石数: int = (1000 + randi() % 2000) if not 超出次数 else (200 + randi() % 300)
		Game.灵石 += 灵石数
		文案 = "【上古遗物】开启秘匣，其中是一个上古修士的储物袋，内有 %d 灵石！" % 灵石数 if not 超出次数 else "【古修储物袋】开启秘匣，其中是一个古修储物袋，内有 %d 灵石，所获寥寥。" % 灵石数
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "上古遗物！" if not 超出次数 else "古宝残片", 2)

# 奇遇5：水府奇遇
func _奇遇_水府奇遇(灵渊id: int) -> void:
	var 文案: String = "【水府奇遇】垂钓之时，忽觉水下有异，凝神望去，竟见一座水下洞府！府门半开，隐约可见灵气四溢。宗主潜入一探，获得大量灵材！"
	# 获得随机灵材
	for i in range(3):
		var it: Item = Item.new()
		it.随机生成()
		it.品阶 = ["宝阶", "王阶", "圣阶"][randi() % 3]
		it.滚词缀()
		Game.宗门库房.append(it)
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "水府奇遇！获得3件灵材", 2)

# 奇遇6：垂钓悟道
func _奇遇_垂钓悟道() -> void:
	var 感悟值: int = 200
	Game.悟道点 += 感悟值
	# 有概率直接突破一个小境界
	var 突破概率: float = 0.1
	var 文案: String = "【垂钓悟道】连续垂钓七日，宗主于水边静思，忽觉天地与我合一，钓道即是道。悟道点+%d！" % 感悟值
	if randf() < 突破概率 and Game.宗主 != null:
		# 尝试突破（简化处理，增加修炼进度）
		文案 += "\n宗主心境突破，修炼进度大增！"
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "垂钓悟道！悟道点+%d" % 感悟值, 2)

# 奇遇7：龙王赠宝
func _奇遇_龙王赠宝() -> void:
	var 宝物类型: int = randi() % 3
	var 文案: String = ""
	if 宝物类型 == 0:
		# 龙珠
		var it: Item = Item.new()
		it.名称 = "龙珠"
		it.类别 = "ling_cai"
		it.品阶 = "仙阶"
		it.描述 = "龙王所赠龙珠，蕴含龙族本源之力，为炼丹炼器至宝。"
		Game.宗门库房.append(it)
		文案 = "【龙王赠宝】昔日放生龙族之举感动东海龙王，龙王遣使赠上一枚「龙珠」（仙阶），以表谢意。"
	elif 宝物类型 == 1:
		# 龙族功法
		var it: Item = Item.new()
		it.名称 = "龙族秘典"
		it.类别 = "gongfa_book"
		it.品阶 = "圣阶"
		it.描述 = "龙族秘传功法，修炼可化龙之形。"
		it.功效 = "灵钓功法：longli_yinling"
		Game.宗门库房.append(it)
		文案 = "【龙王赠宝】昔日放生龙族之举感动东海龙王，龙王遣使赠上一部「龙族秘典」（圣阶）！"
	else:
		# 大量灵石
		var 灵石数: int = 3000 + randi() % 3000
		Game.灵石 += 灵石数
		文案 = "【龙王赠宝】昔日放生龙族之举感动东海龙王，龙王遣使赠上海族珍藏 %d 灵石！" % 灵石数
	已放生龙族 = 0  # 重置，避免重复触发
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "龙王赠宝！", 2)

# 奇遇8：定海神针传承
func _奇遇_定海神针传承() -> void:
	var 文案: String = "【定海神针传承】宗主以《定海神针诀》垂钓，忽感水中有物呼应。凝神望去，竟是一根神针虚影！此为大禹治水时所留定海神针之传承碎片。"
	# 获得定海神针碎片
	var it: Item = Item.new()
	it.名称 = "定海神针碎片"
	it.类别 = "ling_cai"
	it.品阶 = "道阶"
	it.描述 = "大禹治水时所留定海神针之碎片，蕴含镇压水脉之无上神力。"
	Game.宗门库房.append(it)
	# 大幅增加钓道经验
	增加钓道经验(500)
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "定海神针传承！获得道阶灵材", 2)

# 奇遇9：姜太公遇文王
func _奇遇_姜太公遇文王() -> void:
	var 文案: String = "【姜太公遇文王】宗主钓道已至通玄之境，垂钓之时，忽有一位气度不凡之人前来攀谈。此人自称游历四方，与宗主论道三日，受益匪浅。"
	# 获得大量悟道点和声望
	Game.悟道点 += 500
	if "声望" in Game:
		Game.声望 += 100
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "姜太公遇文王！悟道点+500，声望+100", 2)

# 奇遇10：水中捞月
func _奇遇_水中捞月() -> void:
	var 文案: String = "【水中捞月】夜半月圆，宗主垂钓之时，忽见水中月影晃动。伸手捞去，竟捞起一枚「月魄精华」！此乃月亮精华所凝，世间罕见。"
	# 获得月魄精华
	var it: Item = Item.new()
	it.名称 = "月魄精华"
	it.类别 = "ling_cai"
	it.品阶 = "仙阶"
	it.描述 = "月亮精华所凝，至阴至柔，为炼丹圣品，可炼九转金丹。"
	Game.宗门库房.append(it)
	Game._加推演条目(文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game != null:
		Game.添加纪事("异闻", "灵钓奇遇", "水中捞月！获得月魄精华", 2)
# 获取鱼获可用的处置方式
func 获取鱼获处置方式(鱼名: String, 品阶: String, 分层: String) -> Array:
	var 方式: Array = ["收入库藏"]  # 默认所有鱼都可以收入库藏
	# 宝阶及以上有灵性的鱼可以放生积德
	if 品阶序位(品阶) >= 品阶序位("宝阶") and 分层 == "灵鱼":
		方式.append("放生积德")
	# 特定种类可以契约为灵兽
	var 可契约种类: Array = ["蛟龙", "应龙", "烛龙", "鲲", "鹏", "玄武", "龟", "麒麟", "鲛人", "真龙"]
	for 种类 in 可契约种类:
		if 鱼名.find(种类) >= 0:
			方式.append("契约灵兽")
			break
	# 王阶及以上可以抽取精血炼丹
	if 品阶序位(品阶) >= 品阶序位("王阶") and 分层 == "灵鱼":
		方式.append("抽取精血")
	# 圣阶及以上可以献予宗门（增加声望）
	if 品阶序位(品阶) >= 品阶序位("圣阶") and 分层 == "灵鱼":
		方式.append("献予宗门")
	return 方式

# 处置鱼获（返回处置结果）
func 处置鱼获(鱼名: String, 品阶: String, 分层: String, 处置方式: String) -> Dictionary:
	match 处置方式:
		"收入库藏":
			return _处置_收入库藏(鱼名, 品阶, 分层)
		"放生积德":
			return _处置_放生积德(鱼名, 品阶)
		"契约灵兽":
			return _处置_契约灵兽(鱼名, 品阶)
		"抽取精血":
			return _处置_抽取精血(鱼名, 品阶)
		"献予宗门":
			return _处置_献予宗门(鱼名, 品阶)
		_:
			return {"成功": false, "原因": "未知处置方式"}

# 处置1：收入库藏（作为灵材保存）
func _处置_收入库藏(鱼名: String, 品阶: String, 分层: String) -> Dictionary:
	# 从库房中找到这条鱼并保留（默认行为，不需要额外操作）
	return {"成功": true, "原因": "%s 已收入库藏，可用于炼丹炼器。" % 鱼名}

# 处置2：放生积德（增加气运，有概率获得龙族/海族回报）
func _处置_放生积德(鱼名: String, 品阶: String) -> Dictionary:
	if Game == null:
		return {"成功": false, "原因": "游戏状态异常"}
	# 记录放生的鲛人和龙族（用于报恩剧情）
	if 鱼名.find("鲛") >= 0:
		已放生鲛人 = true
	if 鱼名.find("龙") >= 0 or 鱼名.find("蛟") >= 0:
		已放生龙族 += 1
	# 从库房移除这条鱼
	var 移除索引: int = -1
	for i in range(Game.宗门库房.size()):
		var it = Game.宗门库房[i]
		if it.名称 == 鱼名 and it.品阶 == 品阶:
			移除索引 = i
			break
	if 移除索引 >= 0:
		Game.宗门库房.remove_at(移除索引)
	# 增加气运
	var 气运加成: float = 0.0
	if 品阶 == "宝阶":
		气运加成 = 0.01
	elif 品阶 == "王阶":
		气运加成 = 0.02
	elif 品阶 == "圣阶":
		气运加成 = 0.03
	elif 品阶 == "仙阶":
		气运加成 = 0.05
	Game.设置气运buff(气运加成, 气运加成 * 0.5, 30)
	# 有概率获得龙族/海族回报
	var 回报概率: float = 0.1
	if 品阶 == "仙阶":
		回报概率 = 0.3
	var 回报文案: String = ""
	if randf() < 回报概率:
		var 回报类型: int = randi() % 3
		if 回报类型 == 0:
			# 获得灵石
			var 灵石数: int = 100 * 品阶序位(品阶)
			Game.灵石 += 灵石数
			回报文案 = "海族感其恩德，献上海族珍藏 %d 灵石！" % 灵石数
		elif 回报类型 == 1:
			# 获得灵材
			var 灵材名: String = "深海灵珠"
			var it: Item = Item.new()
			it.名称 = 灵材名
			it.类别 = "ling_cai"
			it.品阶 = 品阶
			it.描述 = "海族感恩所赠，蕴含深海灵气。"
			Game.宗门库房.append(it)
			回报文案 = "海族感其恩德，献上一枚 %s！" % 灵材名
		else:
			# 获得功法感悟
			回报文案 = "放生之时，于水中悟得垂钓至理，钓道修为大进！"
			增加钓道经验(50 * 品阶序位(品阶))
	var 结果文案: String = "将 %s 放归灵渊，此物有灵，叩头三响而去。宗门气运提升 %.0f%%（30日）。" % [鱼名, 气运加成 * 100]
	if 回报文案 != "":
		结果文案 += "\n" + 回报文案
	if Game != null:
		Game._加推演条目("【放生积德】%s" % 结果文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	return {"成功": true, "原因": 结果文案, "气运加成": 气运加成}

# 处置3：契约灵兽（转化为灵兽）
func _处置_契约灵兽(鱼名: String, 品阶: String) -> Dictionary:
	if Game == null or Game.灵兽管理系统 == null:
		return {"成功": false, "原因": "灵兽系统未就绪"}
	# 从库房移除这条鱼
	var 移除索引: int = -1
	for i in range(Game.宗门库房.size()):
		var it = Game.宗门库房[i]
		if it.名称 == 鱼名 and it.品阶 == 品阶:
			移除索引 = i
			break
	if 移除索引 >= 0:
		Game.宗门库房.remove_at(移除索引)
	# 映射鱼名到灵兽种类
	var 灵兽映射: Dictionary = {
		"蛟龙": "金睛蛟龙",
		"应龙": "金睛蛟龙",
		"烛龙": "八荒火龙",
		"真龙": "祖龙",
		"鲲": "金翅大鹏",
		"鹏": "金翅大鹏",
		"玄武": "北冥玄龟",
		"龟": "北冥玄龟",
		"麒麟": "赤焰麒麟幼崽",
		"鲛人": "九尾天狐",  # 鲛人特殊，暂用九尾天狐替代
	}
	var 灵兽名: String = ""
	for 关键词 in 灵兽映射.keys():
		if 鱼名.find(关键词) >= 0:
			灵兽名 = 灵兽映射[关键词]
			break
	if 灵兽名 == "":
		return {"成功": false, "原因": "%s 无法契约为灵兽。" % 鱼名}
	# 创建灵兽
	var 兽: Beast = Beast.new()
	兽.种类名 = 灵兽名
	兽.品阶 = 品阶
	兽.等级 = 1
	兽.孵化中 = false
	Game.灵兽管理系统.灵兽库存.append(兽)
	var 结果文案: String = "以灵力契约 %s，化为灵兽「%s」，归入御兽阁。" % [鱼名, 灵兽名]
	if Game != null:
		Game._加推演条目("【契约灵兽】%s" % 结果文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	return {"成功": true, "原因": 结果文案, "灵兽名": 灵兽名}

# 处置4：抽取精血（获得高阶炼丹材料）
func _处置_抽取精血(鱼名: String, 品阶: String) -> Dictionary:
	if Game == null:
		return {"成功": false, "原因": "游戏状态异常"}
	# 从库房移除这条鱼
	var 移除索引: int = -1
	for i in range(Game.宗门库房.size()):
		var it = Game.宗门库房[i]
		if it.名称 == 鱼名 and it.品阶 == 品阶:
			移除索引 = i
			break
	if 移除索引 >= 0:
		Game.宗门库房.remove_at(移除索引)
	# 生成炼丹材料
	var 材料列表: Array = []
	# 精血
	var 精血名: String = "%s精血" % 鱼名.replace("幼崽", "").replace("之灵", "")
	var it1: Item = Item.new()
	it1.名称 = 精血名
	it1.类别 = "ling_cai"
	it1.品阶 = 品阶
	it1.描述 = "自 %s 体内抽取的本源精血，蕴含磅礴灵气，为炼丹圣品。" % 鱼名
	Game.宗门库房.append(it1)
	材料列表.append(精血名)
	# 内丹（王阶及以上有概率）
	if 品阶序位(品阶) >= 品阶序位("王阶") and randf() < 0.5:
		var 内丹名: String = "%s内丹" % 鱼名.replace("幼崽", "").replace("之灵", "")
		var it2: Item = Item.new()
		it2.名称 = 内丹名
		it2.类别 = "ling_cai"
		it2.品阶 = 品阶
		it2.描述 = " %s 修炼百年所结内丹，灵气充盈，可炼上品丹药。" % 鱼名
		Game.宗门库房.append(it2)
		材料列表.append(内丹名)
	# 鳞片/甲壳（防御类材料）
	if 鱼名.find("龙") >= 0 or 鱼名.find("蛟") >= 0:
		var 鳞名: String = "%s逆鳞" % 鱼名.replace("幼崽", "").replace("之灵", "")
		var it3: Item = Item.new()
		it3.名称 = 鳞名
		it3.类别 = "ling_cai"
		it3.品阶 = 品阶
		it3.描述 = " %s 项下逆鳞，坚硬无比，为炼器至宝。" % 鱼名
		Game.宗门库房.append(it3)
		材料列表.append(鳞名)
	var 结果文案: String = "以秘法抽取 %s 本源，获得：%s。" % [鱼名, "、".join(材料列表)]
	if Game != null:
		Game._加推演条目("【抽取精血】%s" % 结果文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	return {"成功": true, "原因": 结果文案, "材料": 材料列表}

# 处置5：献予宗门（增加宗门声望/贡献）
func _处置_献予宗门(鱼名: String, 品阶: String) -> Dictionary:
	if Game == null:
		return {"成功": false, "原因": "游戏状态异常"}
	# 从库房移除这条鱼
	var 移除索引: int = -1
	for i in range(Game.宗门库房.size()):
		var it = Game.宗门库房[i]
		if it.名称 == 鱼名 and it.品阶 == 品阶:
			移除索引 = i
			break
	if 移除索引 >= 0:
		Game.宗门库房.remove_at(移除索引)
	# 增加宗门声望
	var 声望加成: int = 0
	if 品阶 == "圣阶":
		声望加成 = 50
	elif 品阶 == "仙阶":
		声望加成 = 100
	if "声望" in Game:
		Game.声望 += 声望加成
	# 增加贡献点
	var 贡献加成: int = 100 * 品阶序位(品阶)
	if "宗门贡献" in Game:
		Game.宗门贡献 += 贡献加成
	# 全宗弟子忠诚提升
	for d in Game.弟子列表:
		d.忠诚 = min(100, d.忠诚 + 1)
	var 结果文案: String = "将 %s 献予宗门，供奉于祖师堂。宗门声望+%d，贡献+%d，全宗弟子忠诚+1。" % [鱼名, 声望加成, 贡献加成]
	if Game != null:
		Game._加推演条目("【献予宗门】%s" % 结果文案, Game.ET_INFO, Game.PRIO_NORMAL, {})
	if Game.添加宗门典籍 != null:
		Game.添加宗门典籍("宗门大事记", "珍兽献宗", "宗主将垂钓所得 %s 献予宗门，供奉于祖师堂，全宗皆感宗主恩德，宗门声望日隆。" % 鱼名, 2)
	return {"成功": true, "原因": 结果文案, "声望加成": 声望加成, "贡献加成": 贡献加成}

# ===== 顶级鱼获告知系统 =====
# 获取当前灵渊的传说鱼类（用于UI显示，让玩家知道有哪些顶级鱼可以追求）
func 获取灵渊传说鱼类(灵渊id: int) -> Array:
	var 传说: Array = []
	var 灵渊名: String = 获取灵渊(灵渊id).get("名", "浅滩灵池")
	for r in 钓鱼产出表:
		var 品阶: String = r.get("品阶", "凡阶")
		var 所需灵渊: int = int(r.get("所需灵渊", 0))
		# 只显示该灵渊可能出现的宝阶及以上鱼类
		if 品阶 in ["宝阶", "王阶", "圣阶", "仙阶"] and 所需灵渊 <= 灵渊id:
			var 鱼名: String = r.get("名称", "???")
			var 已解锁: bool = _检查鱼获前置条件(r, 灵渊id)
			var 已收录: bool = 钓鱼记录.has(鱼名)
			传说.append({
				"名称": 鱼名 if 已解锁 or 已收录 else "???",
				"品阶": 品阶,
				"已解锁": 已解锁,
				"已收录": 已收录,
				"描述": r.get("描述", ""),
				"特殊条件": r.get("特殊条件", ""),
			})
	# 按品阶排序
	var 品阶序: Array = ["仙阶", "圣阶", "王阶", "宝阶"]
	传说.sort_custom(func(a, b): return 品阶序.find(a["品阶"]) < 品阶序.find(b["品阶"]))
	return 传说

# 获取钓鱼进度总览（用于UI显示）
# 取灵鱼立绘；无对应资产返回 null（UI 侧回落占位，禁崩）。
# 资产缺失不报错：调用方按 null 走文字/占位分支即可。
# 用抠底=true 时优先读 art/characters/fish_cut/（真透明底版，供收杆结算弹窗等叠加场景）；
#   该目录缺资产时**自动回退原图目录**，保证抠底资产未到位时行为与旧版完全一致（不白屏）。
func 获取灵鱼立绘(名称: String, 变体ID: int = -1, 用抠底: bool = false) -> Texture2D:
	# 混沌孑遗特殊处理：使用变体立绘，不存在则回退到主立绘
	if 名称 == "混沌孑遗":
		if 变体ID >= 0 and 变体ID < 混沌孑遗变体表.size():
			var 变体图: Texture2D = _载立绘(String(混沌孑遗变体表[变体ID]), 用抠底)
			if 变体图 != null:
				return 变体图
		# 回退到主立绘
		var main_stem: String = String(神秘类立绘表.get("混沌孑遗", ""))
		if main_stem != "":
			return _载立绘(main_stem, 用抠底)
		return null
	# 神秘类生物立绘
	if 神秘类立绘表.has(名称):
		return _载立绘(String(神秘类立绘表[名称]), 用抠底)
	# 常规灵鱼立绘
	var stem: String = String(灵鱼立绘表.get(名称, ""))
	if stem == "":
		return null
	return _载立绘(stem, 用抠底)

# 立绘装载：优先抠底目录（真透明底），缺资产回退原图目录；两者皆缺则 null（UI 侧走占位）。
func _载立绘(stem: String, 用抠底: bool) -> Texture2D:
	if stem == "":
		return null
	if 用抠底:
		var 抠底路径: String = "res://art/characters/fish_cut/fish_%s_1024.png" % stem
		if ResourceLoader.exists(抠底路径):
			return load(抠底路径) as Texture2D
	var 原路径: String = "res://art/characters/fish/fish_%s_1024.png" % stem
	if not ResourceLoader.exists(原路径):
		return null
	return load(原路径) as Texture2D

func 获取钓鱼总览() -> Dictionary:
	var 品阶统计: Dictionary = {"凡阶": 0, "灵阶": 0, "宝阶": 0, "王阶": 0, "圣阶": 0, "仙阶": 0}
	var 收录统计: Dictionary = {"凡阶": 0, "灵阶": 0, "宝阶": 0, "王阶": 0, "圣阶": 0, "仙阶": 0}
	for r in 钓鱼产出表:
		if r.get("分层") != "灵鱼":
			continue
		var 品阶: String = r.get("品阶", "凡阶")
		品阶统计[品阶] = int(品阶统计.get(品阶, 0)) + 1
		if 钓鱼记录.has(r.get("名称", "")):
			收录统计[品阶] = int(收录统计.get(品阶, 0)) + 1
	return {
		"总鱼类": 品阶统计,
		"已收录": 收录统计,
		"累计钓获": 累计钓获次数,
		"钓道境界": 钓道境界名(),
		"连续钓鱼天数": 连续钓鱼天数,
		"收录种类": 钓鱼记录.size(),
	}

# 品阶->序号（凡0..仙6），用于经验增量
func 品阶序位(品阶: String) -> int:
	var 序: Array = ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "神秘", "道阶"]
	return 序.find(品阶) if 序.has(品阶) else 0

# ===== 钓鱼记录（钓鱼佬核心追求）=====
# 返回：本次是否刷新该鱼的最重/最长纪录（首钓不计入"新纪录"，首钓另有「新收录」标记）。
func _更新钓鱼记录(名称: String, 重量: float, 长度: float) -> bool:
	var 今日: int = 0
	if Game != null:
		今日 = Game.累计游戏日
	if not 钓鱼记录.has(名称):
		# 首钓记录
		钓鱼记录[名称] = {
			"首钓日": 今日,
			"最重": 重量,
			"最长": 长度,
			"总数": 1,
		}
		if Game != null:
			Game.添加纪事("灵钓首获", "首钓", "首次钓获【%s】，已录入灵钓图录。" % 名称, 1)
		return false
	var  rec: Dictionary = 钓鱼记录[名称]
	rec["总数"] = int(rec.get("总数", 0)) + 1
	var 破纪录: bool = false
	if 重量 > float(rec.get("最重", 0)):
		rec["最重"] = 重量
		破纪录 = true
		if Game != null:
			Game.添加纪事("灵钓纪录", "新纪录", "钓获【%s】新纪录：重%.1f钧，长%.1f尺！" % [名称, 重量, 长度], 2)
	if 长度 > float(rec.get("最长", 0)):
		rec["最长"] = 长度
		破纪录 = true
	钓鱼记录[名称] = rec
	return 破纪录

func 获取钓鱼记录(名称: String) -> Dictionary:
	return 钓鱼记录.get(名称, {})

func 获取钓鱼记录总数() -> int:
	return 钓鱼记录.size()

# ===== 神兽降服系统（王/圣阶专用）=====
# 记录神兽遭遇（上钩即收录为"已发现"）
func _记录神兽遭遇(名称: String, 品阶: String) -> bool:
	var 今日: int = 0
	if Game != null:
		今日 = Game.累计游戏日
	var 首次: bool = false
	if not 神兽降服记录.has(名称):
		首次 = true
		神兽降服记录[名称] = {
			"已发现": true,
			"已降服": false,
			"首次遭遇日": 今日,
			"首次降服日": -1,
			"降服次数": 0,
			"逃走次数": 0,
			"品阶": 品阶,
		}
		if Game != null:
			Game.添加纪事("灵钓异遇", "首次遭遇", "首次遭遇【%s】，虽未降服，但其形已入见闻。" % 名称, 2)
			Game._记录图录(名称, "灵钓")
	else:
		var rec: Dictionary = 神兽降服记录[名称]
		rec["已发现"] = true
		神兽降服记录[名称] = rec
	return 首次

# 开始降服（返回降服难度和可选方式及成功率）
func 开始降服(名称: String) -> Dictionary:
	if not 神兽降服记录.has(名称):
		return {"成功": false, "原因": "尚未遭遇此神兽"}
	var rec: Dictionary = 神兽降服记录[名称]
	if bool(rec.get("已降服", false)):
		return {"成功": false, "原因": "此神兽已降服"}
	# 检查冷却
	if 神兽逃走冷却.has(名称):
		var 今日: int = Game.累计游戏日 if Game != null else 0
		if 今日 < int(神兽逃走冷却[名称]):
			return {"成功": false, "原因": "此神兽受惊遁走，需%d日后再试" % (int(神兽逃走冷却[名称]) - 今日)}
	# 从产出表查钓获难度
	var 难度: int = 5
	var 品阶: String = "王阶"
	for r in 钓鱼产出表:
		if r.get("名称", "") == 名称:
			难度 = int(r.get("钓获难度", 5))
			品阶 = r.get("品阶", "王阶")
			break
	# 已遭遇过的神兽，降服难度略降（"已有一面之缘"）
	var 逃走次数: int = int(rec.get("逃走次数", 0))
	if 逃走次数 > 0:
		难度 = max(2, 难度 - 1)
	# 基础成功率（难度越高成功率越低）
	var 基础成功率: float = max(0.1, 1.0 - float(难度) / 20.0)
	# 宗主属性加成
	var 战力加成: float = 0.0
	var 道心加成: float = 0.0
	var 声望加成: float = 0.0
	if Game != null and Game.宗主 != null:
		# 宗主战力加成（每1000战力+1%，最高+20%）
		战力加成 = min(0.2, float(Game.宗主.战力) / 100000.0)
		# 宗主道心加成（每100道心+2%，最高+20%）
		道心加成 = min(0.2, float(Game.宗主.道心) / 5000.0)
		# 宗门声望加成（每1000声望+1%，最高+10%）
		声望加成 = min(0.1, float(Game.声望) / 100000.0)
	# 灵饵品阶加成（喂食专用）
	var 灵饵加成: float = 0.0
	if 当前灵饵 != "凡俗饵":
		var 饵阶: Dictionary = {"凡饵": 0.05, "灵饵": 0.1, "宝饵": 0.15, "仙饵": 0.25}
		灵饵加成 = 饵阶.get(当前灵饵, 0.05)
	# 已有一面之缘加成（+10%）
	var 一面之缘加成: float = 0.1 if 逃走次数 > 0 else 0.0
	# 逃走次数惩罚（每次-5%）
	var 逃走惩罚: float = float(逃走次数) * 0.05
	# 三种降服方式的成功率
	var 战斗成功率: float = min(0.95, 基础成功率 + 战力加成 + 一面之缘加成 - 逃走惩罚)
	var 感化成功率: float = min(0.95, 基础成功率 + 道心加成 + 声望加成 + 一面之缘加成 - 逃走惩罚)
	var 喂食成功率: float = min(0.95, 基础成功率 + 灵饵加成 + 一面之缘加成 - 逃走惩罚)
	# 降服方式：战斗/感化/喂食
	return {
		"成功": true,
		"名称": 名称,
		"品阶": 品阶,
		"降服难度": 难度,
		"降服方式": [
			{"方式": "战斗", "成功率": 战斗成功率, "说明": "以力服之，受宗主道行影响"},
			{"方式": "感化", "成功率": 感化成功率, "说明": "以德化之，受宗主道心和声望影响"},
			{"方式": "喂食", "成功率": 喂食成功率, "说明": "以食诱之，受当前灵饵品阶影响"},
		],
		"已逃走次数": 逃走次数,
		"提示": "%s已上钩，可择一法降服：以力服之、以德化之、以食诱之。" % 名称,
	}

# 降服结果处理（根据方式和成功率自动判定）
func 降服结果(名称: String, 方式: String) -> Dictionary:
	if not 神兽降服记录.has(名称):
		return {"成功": false, "原因": "尚未遭遇此神兽"}
	var rec: Dictionary = 神兽降服记录[名称]
	var 今日: int = Game.累计游戏日 if Game != null else 0
	# 计算该方式的成功率
	var 降服信息: Dictionary = 开始降服(名称)
	var 成功率: float = 0.3
	if bool(降服信息.get("成功", false)):
		for m in 降服信息.get("降服方式", []):
			if m.get("方式", "") == 方式:
				成功率 = float(m.get("成功率", 0.3))
				break
	# 随机判定
	var 成功: bool = randf() < 成功率
	if 成功:
		# 降服成功
		rec["已降服"] = true
		rec["首次降服日"] = 今日
		rec["降服次数"] = int(rec.get("降服次数", 0)) + 1
		神兽降服记录[名称] = rec
		# 从产出表获取信息并入库
		for r in 钓鱼产出表:
			if r.get("名称", "") == 名称:
				var it: Item = Item.new()
				it.类别 = "ling_cai"
				it.品阶 = r.get("品阶", "王阶")
				it.名称 = 名称
				it.描述 = "%s（%s·%s属·灵韵%d，已降服）" % [r.get("描述", ""), r.get("分层", ""), r.get("五行", ""), int(r.get("灵韵", 0))]
				it.功效 = r.get("用途", "")
				if Game != null:
					Game.宗门库房.append(it)
				break
		if Game != null:
			Game.添加纪事("灵钓降服", "降服成功", "历经%s，【%s】心悦诚服，愿随你修行。" % [方式, 名称], 3)
		# 清除冷却
		if 神兽逃走冷却.has(名称):
			神兽逃走冷却.erase(名称)
		return {
			"成功": true,
			"名称": 名称,
			"方式": 方式,
			"成功率": 成功率,
			"首次降服": int(rec.get("降服次数", 0)) == 1,
			"提示": "%s成功！【%s】已降服。" % [方式, 名称],
		}
	else:
		# 降服失败，神兽逃走
		rec["逃走次数"] = int(rec.get("逃走次数", 0)) + 1
		神兽降服记录[名称] = rec
		# 设置14游戏日冷却（约56分钟现实时间，增加稀缺感）
		神兽逃走冷却[名称] = 今日 + 14
		if Game != null:
			Game.添加纪事("灵钓失手", "神兽遁走", "【%s】挣脱鱼钩，遁入深水。虽未降服，但其形已入你见闻。" % 名称, 1)
		return {
			"成功": false,
			"名称": 名称,
			"方式": 方式,
			"成功率": 成功率,
			"冷却日": 14,
			"提示": "降服失败！【%s】挣脱遁走，14游戏日内不再现身。" % 名称,
		}

# 获取神兽降服记录
func 获取神兽降服记录(名称: String) -> Dictionary:
	return 神兽降服记录.get(名称, {})

# 获取神兽降服统计
func 获取神兽降服统计() -> Dictionary:
	var 统计: Dictionary = {"王阶": {"总数": 0, "已发现": 0, "已降服": 0}, "圣阶": {"总数": 0, "已发现": 0, "已降服": 0}, "仙阶": {"总数": 0, "已发现": 0, "已降服": 0}}
	for r in 钓鱼产出表:
		if r.get("分层", "") != "灵鱼":
			continue
		var 品阶: String = r.get("品阶", "")
		if 品阶 in ["王阶", "圣阶", "仙阶"]:
			统计[品阶]["总数"] += 1
			var 名: String = r.get("名称", "")
			if 神兽降服记录.has(名):
				if bool(神兽降服记录[名].get("已发现", false)):
					统计[品阶]["已发现"] += 1
				if bool(神兽降服记录[名].get("已降服", false)):
					统计[品阶]["已降服"] += 1
	return 统计

# 获取鱼获分类统计（鱼获图鉴/神兽图鉴/仙缘图鉴）
func 获取鱼获分类统计() -> Dictionary:
	var 统计: Dictionary = {
		"鱼获图鉴": {"总数": 0, "已收录": 0, "品阶": ["凡阶", "灵阶", "宝阶"]},
		"神兽图鉴": {"总数": 0, "已发现": 0, "已降服": 0, "品阶": ["王阶", "圣阶"]},
		"仙缘图鉴": {"总数": 0, "已发现": 0, "已结缘": 0, "品阶": ["仙阶"]},
	}
	for r in 钓鱼产出表:
		if r.get("分层", "") != "灵鱼":
			continue
		var 品阶: String = r.get("品阶", "")
		var 名: String = r.get("名称", "")
		if 品阶 in ["凡阶", "灵阶", "宝阶"]:
			统计["鱼获图鉴"]["总数"] += 1
			if 钓鱼记录.has(名):
				统计["鱼获图鉴"]["已收录"] += 1
		elif 品阶 in ["王阶", "圣阶"]:
			统计["神兽图鉴"]["总数"] += 1
			if 神兽降服记录.has(名):
				if bool(神兽降服记录[名].get("已发现", false)):
					统计["神兽图鉴"]["已发现"] += 1
				if bool(神兽降服记录[名].get("已降服", false)):
					统计["神兽图鉴"]["已降服"] += 1
		elif 品阶 == "仙阶":
			统计["仙缘图鉴"]["总数"] += 1
			if 神兽降服记录.has(名):
				if bool(神兽降服记录[名].get("已发现", false)):
					统计["仙缘图鉴"]["已发现"] += 1
				if bool(神兽降服记录[名].get("已降服", false)):
					统计["仙缘图鉴"]["已结缘"] += 1
	return 统计

# 检查神兽是否在冷却中
func _检查神兽冷却(名称: String) -> bool:
	if not 神兽逃走冷却.has(名称):
		return false
	var 今日: int = Game.累计游戏日 if Game != null else 0
	return 今日 < int(神兽逃走冷却[名称])

# ===== 仙阶机缘系统（仙阶不是"钓"，是"遇"）=====
# 仙阶生物不会上钩，而是在特定条件下主动现身
# 触发条件：连续钓鱼30日+机缘、九九重阳、北冥极寒、东海龙宫开启等
func 触发仙阶机缘(灵渊id: int, 超出次数: bool = false) -> Dictionary:
	# 检查触发条件
	var 今日: int = Game.累计游戏日 if Game != null else 0
	# 连续钓鱼天数要求（降低门槛：从30日降到15日）
	if 连续钓鱼天数 < 15:
		return {"成功": false, "原因": "连续钓鱼不足15日，仙物不现"}
	# 机缘概率（基础2%，钓道境界每级+1%，灵渊深度每级+1%）
	# 最高：2% + 5*1% + 3*1% = 10%
	var 机缘概率: float = 0.02 + float(钓道境界) * 0.01
	# 灵渊越深，概率越高
	机缘概率 += float(灵渊id) * 0.01
	# 连续钓鱼天数加成（每多10天+0.5%，最高+2%）
	机缘概率 += min(2.0, float(连续钓鱼天数 - 15) * 0.0005)
	# 超出机缘次数后，仙阶机缘概率减半
	if 超出次数:
		机缘概率 *= 0.5
	if randf() > 机缘概率:
		return {"成功": false, "原因": "机缘未至"}
	# 从仙阶鱼获中随机选择一只（排除已结缘的）
	var 候选: Array = []
	for r in 钓鱼产出表:
		if r.get("品阶", "") != "仙阶" or r.get("分层", "") != "灵鱼":
			continue
		var 名: String = r.get("名称", "")
		if 神兽降服记录.has(名) and bool(神兽降服记录[名].get("已降服", false)):
			continue
		# 检查特殊条件
		var 特殊条件: String = r.get("特殊条件", "")
		if 特殊条件 != "" and not _检查仙阶特殊条件(特殊条件):
			continue
		候选.append(r)
	if 候选.is_empty():
		return {"成功": false, "原因": "仙物皆已结缘"}
	var 选: Dictionary = 候选[randi() % 候选.size()]
	var 名称: String = 选.get("名称", "")
	# 记录已发现
	_记录神兽遭遇(名称, "仙阶")
	# 返回仙阶现身信息
	return {
		"成功": true,
		"名称": 名称,
		"品阶": "仙阶",
		"分层": 选.get("分层", "灵鱼"),
		"描述": 选.get("描述", ""),
		"用途": 选.get("用途", ""),
		"灵韵": int(选.get("灵韵", 0)),
		"需要结缘": true,
		"提示": "%s现身！此等仙物非力可致，需以诚心结缘。" % 名称,
	}

# ===== 神秘类机缘触发（特殊隐藏生物，大家都没见过的）=====
func 触发神秘类机缘(灵渊id: int, 超出次数: bool = false) -> Dictionary:
	# 触发条件：钓道境界≥大成(2) + 灵渊深度≥2 + 极低概率
	if 钓道境界 < 2:
		return {"成功": false, "原因": "钓道境界不足，神秘不现"}
	if 灵渊id < 2:
		return {"成功": false, "原因": "灵渊太浅，神秘不现"}
	# 基础概率0.5%，钓道境界每级+0.2%，灵渊深度每级+0.3%
	var 机缘概率: float = 0.005 + float(钓道境界 - 2) * 0.002 + float(灵渊id - 2) * 0.003
	# 连续钓鱼天数加成（每多10天+0.1%，最高+0.5%）
	机缘概率 += min(0.005, float(max(0, 连续钓鱼天数 - 10)) * 0.0001)
	# 超出机缘次数后概率减半
	if 超出次数:
		机缘概率 *= 0.5
	if randf() > 机缘概率:
		return {"成功": false, "原因": "神秘未至"}
	# 从神秘类生物中随机选择一只
	var 神秘类列表: Array = ["时空游鱼", "混沌孑遗", "虚空噬灵", "轮回之鱼", "天道碎片", "太初古灵", "因果之灵", "梦境游鱼"]
	var 名称: String = 神秘类列表[randi() % 神秘类列表.size()]
	# 混沌孑遗特殊处理：随机选择变体和特征
	if 名称 == "混沌孑遗":
		var 变体ID: int = randi() % 混沌孑遗变体表.size()
		var 颜色: String = 混沌特征_颜色[randi() % 混沌特征_颜色.size()]
		var 纹路: String = 混沌特征_纹路[randi() % 混沌特征_纹路.size()]
		var 气质: String = 混沌特征_气质[randi() % 混沌特征_气质.size()]
		var 特征描述: String = "%s·%s·%s" % [颜色, 纹路, 气质]
		return {
			"成功": true,
			"名称": "混沌孑遗",
			"品阶": "神秘",
			"分层": "灵鱼",
			"变体ID": 变体ID,
			"颜色": 颜色,
			"纹路": 纹路,
			"气质": 气质,
			"特征描述": 特征描述,
			"混沌数据": {"变体ID": 变体ID, "颜色": 颜色, "纹路": 纹路, "气质": 气质, "特征描述": 特征描述},
			"提示": "水中忽现混沌之气，一只无定形的神秘生物浮现！",
		}
	return {
		"成功": true,
		"名称": 名称,
		"品阶": "神秘",
		"分层": "灵鱼",
		"提示": "忽觉水中有异，一只从未见过的神秘生物现身！",
	}

# ===== 混沌孑遗命名功能 =====
func 命名混沌孑遗(玩家命名: String) -> Dictionary:
	if 本次混沌孑遗.is_empty():
		return {"成功": false, "原因": "当前没有待命名的混沌孑遗"}
	if 玩家命名.strip_edges() == "":
		return {"成功": false, "原因": "名字不能为空"}
	# 检查是否重名
	if 混沌孑遗记录.has(玩家命名):
		return {"成功": false, "原因": "此名已被使用，请换一个名字"}
	var 今日: int = Game.累计游戏日 if Game != null else 0
	var 数据: Dictionary = 本次混沌孑遗.duplicate()
	数据["收服日"] = 今日
	数据["玩家命名"] = 玩家命名
	混沌孑遗记录[玩家命名] = 数据
	# 记录图录
	if Game != null:
		Game._记录图录(玩家命名, "灵钓")
		Game.添加纪事("混沌收录", "命名收录", "混沌孑遗显形，宗主将其命名为「%s」，已收录入混沌图鉴。" % 玩家命名, 3)
	# 清空临时数据
	本次混沌孑遗 = {}
	return {
		"成功": true,
		"玩家命名": 玩家命名,
		"变体ID": 数据.get("变体ID", 0),
		"特征描述": 数据.get("特征描述", ""),
		"提示": "混沌孑遗「%s」已收录！" % 玩家命名,
	}

# 获取混沌孑遗图鉴列表
func 获取混沌孑遗图鉴() -> Array:
	var 列表: Array = []
	for 名 in 混沌孑遗记录.keys():
		var 数据: Dictionary = 混沌孑遗记录[名]
		列表.append({
			"名称": 名,
			"变体ID": 数据.get("变体ID", 0),
			"特征描述": 数据.get("特征描述", ""),
			"收服日": 数据.get("收服日", 0),
		})
	return 列表

# ===== 时空回溯符功能 =====
func 使用回溯符() -> Dictionary:
	if 回溯符数量 <= 0:
		return {"成功": false, "原因": "没有时空回溯符"}
	if 上次钓鱼结果.is_empty():
		return {"成功": false, "原因": "没有可回溯的钓鱼结果"}
	回溯符数量 -= 1
	var 回溯结果: Dictionary = 上次钓鱼结果.duplicate()
	上次钓鱼结果 = {}
	if Game != null:
		Game.添加纪事("时空回溯", "回溯钓鱼", "使用时空回溯符，时光倒流，上一次钓鱼结果被撤销，可重新垂钓。", 2)
	return {
		"成功": true,
		"回溯结果": 回溯结果,
		"剩余回溯符": 回溯符数量,
		"提示": "时空回溯！上一次钓鱼结果已撤销，可重新垂钓。",
	}

# 获取回溯符数量
func 获取回溯符数量() -> int:
	return 回溯符数量

# 检查仙阶特殊条件
func _检查仙阶特殊条件(条件: String) -> bool:
	if 条件 == "":
		return true
	# 九九重阳（农历九月初九，简化为游戏日%365==252）
	if "九九重阳" in 条件:
		var 今日: int = Game.累计游戏日 if Game != null else 0
		return 今日 % 365 == 252
	# 北冥极寒（灵渊id>=3）
	if "北冥" in 条件 or "极寒" in 条件:
		return true  # 灵渊已过滤
	# 东海龙宫开启（简化为钓道境界>=4）
	if "龙宫" in 条件:
		return 钓道境界 >= 4
	# 连续钓鱼30日+机缘（已在触发函数检查）
	if "连续钓鱼" in 条件:
		return 连续钓鱼天数 >= 30
	# 其他条件默认通过
	return true

# 结缘结果处理（仙阶专用，自动判定成功率）
func 结缘结果(名称: String) -> Dictionary:
	if not 神兽降服记录.has(名称):
		return {"成功": false, "原因": "尚未遭遇此仙物"}
	var rec: Dictionary = 神兽降服记录[名称]
	if bool(rec.get("已降服", false)):
		return {"成功": false, "原因": "此仙物已结缘"}
	var 今日: int = Game.累计游戏日 if Game != null else 0
	# 计算结缘成功率（仙阶以诚心感之，基础成功率较高）
	var 成功率: float = 0.5  # 基础50%
	# 宗主道心加成（每100道心+2%，最高+30%）
	if Game != null and Game.宗主 != null:
		成功率 += min(0.3, float(Game.宗主.道心) / 5000.0)
		# 宗门声望加成（每1000声望+1%，最高+15%）
		成功率 += min(0.15, float(Game.声望) / 100000.0)
	# 连续钓鱼天数加成（每多10天+2%，最高+20%）
	成功率 += min(0.2, float(连续钓鱼天数 - 15) * 0.002)
	# 已逃走次数惩罚（每次-5%）
	成功率 -= float(rec.get("逃走次数", 0)) * 0.05
	成功率 = max(0.1, min(0.95, 成功率))
	# 随机判定
	var 成功: bool = randf() < 成功率
	if 成功:
		# 结缘成功
		rec["已降服"] = true
		rec["首次降服日"] = 今日
		rec["降服次数"] = int(rec.get("降服次数", 0)) + 1
		神兽降服记录[名称] = rec
		# 获得仙物信物/分身（不是本体）
		for r in 钓鱼产出表:
			if r.get("名称", "") == 名称:
				var it: Item = Item.new()
				it.类别 = "ling_cai"
				it.品阶 = "仙阶"
				it.名称 = "%s·信物" % 名称
				it.描述 = "%s的信物，仙物分身寄宿其中，可召唤其助力。" % r.get("描述", "")
				it.功效 = "仙物信物：可召唤%s分身助力" % 名称
				if Game != null:
					Game.宗门库房.append(it)
				break
		if Game != null:
			Game.添加纪事("灵钓仙缘", "结缘成功", "以诚心感天动地，【%s】愿以分身相随。" % 名称, 4)
		return {
			"成功": true,
			"名称": 名称,
			"成功率": 成功率,
			"首次结缘": int(rec.get("降服次数", 0)) == 1,
			"获得": "%s·信物" % 名称,
			"提示": "结缘成功！获得【%s·信物】，可召唤仙物分身助力。" % 名称,
		}
	else:
		# 结缘失败，仙物离去（设置7游戏日冷却，仙物可再次现身但需等待）
		rec["逃走次数"] = int(rec.get("逃走次数", 0)) + 1
		神兽降服记录[名称] = rec
		# 仙阶冷却7游戏日（约28分钟现实时间）
		神兽逃走冷却[名称] = 今日 + 7
		if Game != null:
			Game.添加纪事("灵钓仙缘", "仙物离去", "【%s】微微颔首，化作流光远去。仙缘尚浅，静待来日。" % 名称, 2)
		return {
			"成功": false,
			"名称": 名称,
			"成功率": 成功率,
			"冷却日": 7,
			"提示": "结缘失败！【%s】化作流光远去，7游戏日内不再现身。" % 名称,
		}

func 获取品阶集齐数(品阶: String) -> int:
	var 数: int = 0
	for 名 in 钓鱼记录.keys():
		# 从钓鱼产出表查品阶
		for r in 钓鱼产出表:
			if r.get("名称") == 名 and r.get("品阶") == 品阶:
				数 += 1
				break
	return 数

# ===== 连续钓鱼天数 =====
func _更新连续钓鱼天数() -> void:
	if Game == null:
		return
	var 今日: int = Game.累计游戏日
	if 上次钓鱼日 == -1:
		连续钓鱼天数 = 1
	elif 今日 == 上次钓鱼日 + 1:
		连续钓鱼天数 += 1
	elif 今日 > 上次钓鱼日 + 1:
		连续钓鱼天数 = 1
	上次钓鱼日 = 今日

func 获取连续钓鱼天数() -> int:
	return 连续钓鱼天数

# ===== 每日灵钓机缘次数（综合方案A+B）=====
# 基础10次/日，VIP每级+1次（VIP12=22次/日）
# 次数内：正常经验和鱼获品质
# 超出次数：经验减半，鱼获品质降低一阶（宝阶→灵阶，灵阶→凡阶）
# 灵饵品阶仍限制可钓鱼池（方案B）

func 获取每日机缘次数() -> int:
	var 基础次数: int = 10
	var vip: int = 0
	if Game != null:
		vip = Game.当前VIP等级()
	# VIP每级+1次
	return 基础次数 + vip

func 获取剩余机缘次数() -> int:
	_检查每日重置()
	return max(0, 获取每日机缘次数() - 今日灵钓次数)

func _检查每日重置() -> void:
	var 今日: int = Game.累计游戏日 if Game != null else 0
	if 今日 != 今日灵钓日期:
		今日灵钓次数 = 0
		今日灵钓日期 = 今日

func _是否超出机缘次数() -> bool:
	_检查每日重置()
	return 今日灵钓次数 >= 获取每日机缘次数()

func _记录今日钓鱼次数() -> void:
	_检查每日重置()
	今日灵钓次数 += 1
func 增加钓道经验(量: int) -> bool:
	钓道经验 += 量
	var 旧境界: int = 钓道境界
	var 新境界: int = 0
	for i in range(钓道境界表.size()):
		if 钓道经验 >= int(钓道境界表[i].get("经验", 0)):
			新境界 = i
	if 新境界 > 旧境界:
		钓道境界 = 新境界
		if Game != null:
			Game.添加纪事("钓道突破", "钓道精进", "钓道修为精进至【%s】，可探更深灵渊。" % 钓道境界表[新境界].get("名", ""), 1)
			# 检查新解锁的鱼类
			var 新解锁: Array = []
			for r in 钓鱼产出表:
				if int(r.get("最低钓道境界", 0)) == 新境界 and r.get("分层") == "灵鱼":
					新解锁.append(r.get("名称", ""))
			if not 新解锁.is_empty():
				var 提示: String = "钓道精进，水中灵物渐显。传闻可钓获：%s" % "、".join(新解锁.slice(0, 3))
				if 新解锁.size() > 3:
					提示 += "等神物"
				Game.添加纪事("钓道突破", "新灵物现", 提示, 2)
		return true
	return false

func 钓道境界名() -> String:
	if 钓道境界 >= 0 and 钓道境界 < 钓道境界表.size():
		return 钓道境界表[钓道境界].get("名", "初窥")
	return "初窥"

func 钓道境界进度() -> Dictionary:
	var 当前: int = int(钓道境界表[钓道境界].get("经验", 0))
	var 下一: int = 钓道境界表[钓道境界 + 1].get("经验", 当前) if 钓道境界 + 1 < 钓道境界表.size() else 当前
	var 需: int = 下一 - 当前
	var 有: int = 钓道经验 - 当前
	return {"当前名": 钓道境界名(), "已得": 有, "需": 需, "满": 钓道境界 + 1 >= 钓道境界表.size()}

# ===== 钓具晋升（sink 闭环：消耗库房灵材升阶，受钓道境界软门控）=====
func 晋升钓具() -> Dictionary:
	var 当前阶: int = int(钓具配置.get("阶", 0))
	if 当前阶 + 1 >= 钓具表.size():
		return {"成功": false, "原因": "钓具已臻至高阶（太虚竿）"}
	var 下一: Dictionary = 钓具表[当前阶 + 1]
	var 需境: int = int(下一.get("钓道门槛", 0))
	if 钓道境界 < 需境:
		return {"成功": false, "原因": "钓道境界不足，需【%s】方可晋阶" % 钓道境界表[需境].get("名", "")}
	var 需材: int = (当前阶 + 1) * 5
	if not _扣库房灵材(需材):
		return {"成功": false, "原因": "灵材不足（需 %d 份灵材）" % 需材}
	钓具配置["阶"] = 当前阶 + 1
	if Game != null:
		Game.添加纪事("钓具晋升", "钓具精进", "以灵材淬炼，钓具晋至【%s·%s·%s】。" % [下一.get("灵杆", ""), 下一.get("灵线", ""), 下一.get("灵饵", "")], 1)
	return {"成功": true, "新阶": 当前阶 + 1, "灵杆": 下一.get("灵杆"), "灵线": 下一.get("灵线"), "灵饵": 下一.get("灵饵")}

func _扣库房灵材(数: int) -> bool:
	if Game == null:
		return true
	var 余: int = 数
	for i in range(Game.宗门库房.size() - 1, -1, -1):
		var it = Game.宗门库房[i]
		if 余 <= 0:
			break
		if it is Item and it.类别 == "ling_cai":
			Game.宗门库房.remove_at(i)
			余 -= 1
	return 余 <= 0

# ===== 灵饵（消耗品 sink，[PLACEHOLDER] 数值待实机调）=====
func 获取灵饵(名: String) -> Dictionary:
	for r in 钓鱼灵饵表:
		if r.get("名称") == 名:
			return r
	return {}

func 配制灵饵(名: String) -> Dictionary:
	if 名 == "凡饵":
		当前灵饵 = "凡饵"
		return {"成功": true, "名称": "凡饵"}
	var 行: Dictionary = 获取灵饵(名)
	if 行.is_empty():
		return {"成功": false, "原因": "无此灵饵"}
	var 耗: int = int(行.get("灵材消耗", 0))
	if not _扣库房灵材(耗):
		return {"成功": false, "原因": "灵材不足（需 %d 份）" % 耗}
	当前灵饵 = 名
	if Game != null:
		Game.添加纪事("灵饵配制", "灵饵", "以灵材炼制【%s】，垂钓时引聚灵物。" % 名, 0)
	return {"成功": true, "名称": 名}

# ===== 灵钓大赛（周常留存钩子，奖励走威望·禁暴灵石）=====
func 大赛周序() -> int:
	if Game == null:
		return 0
	return int(Game.累计游戏日 / 7) % 大赛规则表.size()   # [PLACEHOLDER 周序口径]

func 获取本周大赛() -> Dictionary:
	return 大赛规则表[大赛周序()]

func 参与大赛() -> Dictionary:
	var 周: int = 大赛周序()
	if 周 != 上周大赛周序:
		上周大赛周序 = 周
		本周大赛参与 = 0
	if 本周大赛参与 >= 3:   # 每周参赛上限 [PLACEHOLDER·节流防通胀]
		return {"成功": false, "原因": "本周参赛已达上限"}
	var 规: Dictionary = 获取本周大赛()
	var 威望: int = int(规.get("奖励威望", 10))
	if Game != null:
		Game.宗主威望 += 威望
	本周大赛参与 += 1
	if Game != null:
		Game.添加纪事("灵钓大赛", "周赛", "参与本周灵钓大赛【%s】，获宗主威望 %d。" % [规.get("名称", ""), 威望], 1)
	return {"成功": true, "规则": 规.get("名称"), "威望": 威望}

# ===== 存档（不升 SAVE_VERSION，from_dict 旧档缺键默认初值）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["钓道经验"] = 钓道经验
	data["钓道境界"] = 钓道境界
	data["累计钓获次数"] = 累计钓获次数
	data["钓具配置"] = 钓具配置
	data["当前灵饵"] = 当前灵饵
	data["本周大赛参与"] = 本周大赛参与
	data["上周大赛周序"] = 上周大赛周序
	data["钓鱼记录"] = 钓鱼记录
	data["神兽降服记录"] = 神兽降服记录
	data["神兽逃走冷却"] = 神兽逃走冷却
	data["上次钓鱼日"] = 上次钓鱼日
	data["连续钓鱼天数"] = 连续钓鱼天数
	data["已放生鲛人"] = 已放生鲛人
	data["已放生龙族"] = 已放生龙族
	data["今日灵钓次数"] = 今日灵钓次数
	data["今日灵钓日期"] = 今日灵钓日期
	data["混沌孑遗记录"] = 混沌孑遗记录
	data["回溯符数量"] = 回溯符数量
	return data

func from_dict(data: Dictionary) -> void:
	if data.is_empty():
		return
	钓道经验 = int(data.get("钓道经验", 0))
	钓道境界 = int(data.get("钓道境界", 0))
	累计钓获次数 = int(data.get("累计钓获次数", 0))
	钓具配置 = data.get("钓具配置", {"阶": 0})
	当前灵饵 = data.get("当前灵饵", "凡俗饵")
	本周大赛参与 = int(data.get("本周大赛参与", 0))
	上周大赛周序 = int(data.get("上周大赛周序", -1))
	钓鱼记录 = data.get("钓鱼记录", {}) if typeof(data.get("钓鱼记录", {})) == TYPE_DICTIONARY else {}
	神兽降服记录 = data.get("神兽降服记录", {}) if typeof(data.get("神兽降服记录", {})) == TYPE_DICTIONARY else {}
	神兽逃走冷却 = data.get("神兽逃走冷却", {}) if typeof(data.get("神兽逃走冷却", {})) == TYPE_DICTIONARY else {}
	上次钓鱼日 = int(data.get("上次钓鱼日", -1))
	连续钓鱼天数 = int(data.get("连续钓鱼天数", 0))
	已放生鲛人 = bool(data.get("已放生鲛人", false))
	已放生龙族 = int(data.get("已放生龙族", 0))
	今日灵钓次数 = int(data.get("今日灵钓次数", 0))
	今日灵钓日期 = int(data.get("今日灵钓日期", -1))
	混沌孑遗记录 = data.get("混沌孑遗记录", {}) if typeof(data.get("混沌孑遗记录", {})) == TYPE_DICTIONARY else {}
	回溯符数量 = int(data.get("回溯符数量", 0))
