class_name FactionSystem extends RefCounted

# ===== 派系与权力斗争系统状态变量 =====
var 派系列表: Array = []                # 派系列表（{派系ID, 名称, 类型, 领袖ID, 成员列表, 影响力, 满意度, 团结度}）
var 派系关系表: Dictionary = {}          # 派系关系表（{派系ID1-派系ID2: 关系值-100到100}）
var 宗门派系政策: String = "平衡"       # 宗门派系政策：平衡/扶持/打压/分化
var 派系更新日: int = 0                  # 上次派系更新日
var 宗门政策记录: Dictionary = {}       # 宗门政策记录（{政策名: {生效日, 持续日, 影响派系}}）
var 派系联盟记录: Array = []              # 派系联盟记录（{联盟ID, 派系1, 派系2, 开始日, 状态}）
var 派系对抗记录: Array = []              # 派系对抗记录（{对抗ID, 派系1, 派系2, 开始日, 严重程度, 状态}）
var 派系分化记录: Array = []              # 派系分化记录（{分化ID, 目标派系, 手段, 开始日, 效果, 状态}）
var 派系事件记录: Array = []              # 派系事件记录（{事件ID, 类型, 严重程度, 涉及派系, 描述, 发生日, 状态, 后果}）
var 派系事件ID计数: int = 0                # 派系事件ID计数
var 派系斗争编年史: Array = []             # 宗门派系斗争编年史（重大事件记录）
var 炼丹派系争夺记录: Array = []        # 炼丹派系争夺记录（{争夺ID, 派系1, 派系2, 丹方/资源, 结果, 发生日}）
var 历练派系争夺记录: Array = []        # 历练派系争夺记录（{争夺ID, 派系1, 派系2, 历练地点, 结果, 发生日}）
var 家族派系联动记录: Array = []        # 家族派系联动记录（{联动ID, 家族, 派系, 类型, 效果, 发生日}）
var 拍卖行派系影响记录: Array = []      # 拍卖行派系影响记录（{影响ID, 派系, 类型, 物品, 价格, 发生日}）
var 派系争夺ID计数: int = 0              # 派系争夺ID计数
var 宗门种族政策: String = "融合"     # 宗门种族政策：隔离/融合/优待/歧视
var 种族政策效果: Dictionary = {}      # 种族政策效果配置

# ============================================================
# 阵营声望静态工具层（faction_reputation_system / game_state 以 FactionSystem.xxx 静态调用）
# 数值口径与 config/faction_base.csv、ui/page_faction.gd 对齐
# ============================================================
const REPUTATION_LEVELS: Array = ["冷淡", "中立", "友善", "尊敬", "崇敬"]
const REPUTATION_THRESHOLDS: Array = [0, 100, 500, 2000, 5000]
const _等级折扣: Array = [1.0, 1.0, 0.95, 0.90, 0.85]
const _等级加成: Array = [1.0, 1.0, 1.05, 1.10, 1.15]
const _阵营立场映射: Dictionary = {
	"正道宗门": "正道",
	"魔道邪宗": "魔道",
	"中立散修": "中立",
	"上古妖兽": "中立",
	"远古遗泽": "中立",
	"丹器师公会": "中立",
}
# 阵营中文名 → 阵营标签（zongmen_battle 正魔克制归一使用，口径同 faction_base.csv faction_tag）
const FACTION_TAG: Dictionary = {
	"正道宗门": "正道",
	"魔道邪宗": "魔道",
	"中立散修": "中立",
	"上古妖兽": "中立",
	"远古遗泽": "中立",
	"丹器师公会": "中立",
}
const _阵营描述: Dictionary = {
	"正道宗门": "以名门正派自居的正道联盟，崇尚清心寡欲、斩妖除魔。",
	"魔道邪宗": "行事不拘常理的魔道势力，讲究弱肉强食、逆天而行。",
	"中立散修": "游离于正魔之外的散修联盟，唯利是趋，消息灵通。",
	"上古妖兽": "自上古遗存的妖兽一族，凭血脉本能修行，凶悍无匹。",
	"远古遗泽": "承远古道统的遗泽势力，掌握失传的上古传承与素材。",
	"丹器师公会": "炼丹师与炼器师的行会组织，中立而精于百工之术。",
}

# 声望值 → 等级序号 0..4（与 page_faction._get_level_index 同口径）
static func _reputation_index(rep_value: int) -> int:
	var v: int = int(rep_value)
	for i in range(REPUTATION_THRESHOLDS.size()):
		if v < int(REPUTATION_THRESHOLDS[i]):
			return max(0, i - 1)
	return REPUTATION_LEVELS.size() - 1

# 声望值 → 等级名
static func get_reputation_level(rep_value: int) -> String:
	return str(REPUTATION_LEVELS[_reputation_index(rep_value)])

# 增减阵营声望（返回新字典；正魔对立，提升一方小幅削弱对立阵营）
static func add_faction_reputation(rep_dict: Dictionary, faction: String, amount: int) -> Dictionary:
	var d: Dictionary = rep_dict.duplicate(true)
	if not d.has(faction):
		d[faction] = 0
	d[faction] = max(0, int(d[faction]) + int(amount))
	var 对立: String = ""
	if faction == "正道宗门":
		对立 = "魔道邪宗"
	elif faction == "魔道邪宗":
		对立 = "正道宗门"
	if 对立 != "" and d.has(对立) and int(amount) > 0:
		d[对立] = max(0, int(d[对立]) - int(int(amount) * 0.5))
	return d

# 单个等级 → 权益字典
static func get_faction_benefits(level: String) -> Dictionary:
	var idx: int = REPUTATION_LEVELS.find(level)
	if idx < 0:
		idx = 0
	return {"商店折扣": float(_等级折扣[idx]), "任务加成": float(_等级加成[idx]), "特殊商品": idx >= 3, "专属任务": idx >= 4, "等级序号": idx}

# 所有阵营综合权益（取最优）
static func get_comprehensive_benefits(rep_dict: Dictionary) -> Dictionary:
	var 最佳折扣: float = 1.0
	var 最佳加成: float = 1.0
	var 特殊: bool = false
	var 专属: bool = false
	for 阵营 in rep_dict.keys():
		var idx: int = _reputation_index(int(rep_dict[阵营]))
		最佳折扣 = min(最佳折扣, float(_等级折扣[idx]))
		最佳加成 = max(最佳加成, float(_等级加成[idx]))
		if idx >= 3:
			特殊 = true
		if idx >= 4:
			专属 = true
	return {"商店折扣": 最佳折扣, "任务加成": 最佳加成, "特殊商品": 特殊, "专属任务": 专属}

# 玩法是否解锁（feature 为等级名时按等级比较；非等级名不做硬拦截）
static func is_feature_unlocked(_faction: String, rep_value: int, feature: String) -> bool:
	var 需要序号: int = REPUTATION_LEVELS.find(feature)
	if 需要序号 < 0:
		return true
	return _reputation_index(int(rep_value)) >= 需要序号

# 招贤阁按声望加权抽取阵营
static func weighted_recruit_faction(rep_dict: Dictionary, _personality: String = "") -> String:
	var 阵营们: Array = []
	var 权重: Array = []
	var 总权: float = 0.0
	for 阵营 in rep_dict.keys():
		var w: float = 1.0 + float(int(rep_dict[阵营])) / 1000.0
		阵营们.append(str(阵营))
		权重.append(w)
		总权 += w
	if 阵营们.is_empty() or 总权 <= 0.0:
		return "中立散修"
	var 掷: float = randf() * 总权
	var 累计: float = 0.0
	for i in range(阵营们.size()):
		累计 += float(权重[i])
		if 掷 <= 累计:
			return str(阵营们[i])
	return str(阵营们[阵营们.size() - 1])

# 阵营描述（UI Tooltip）
static func get_faction_description(faction: String) -> String:
	return str(_阵营描述.get(faction, "隐于世外的修行势力，渊源难考。"))

# 玩家战斗立场：比较正魔声望，差距不足100视为中立
static func get_player_stance(rep_dict: Dictionary) -> String:
	var 正: int = int(rep_dict.get("正道宗门", 0))
	var 魔: int = int(rep_dict.get("魔道邪宗", 0))
	var 差: int = 正 - 魔
	if 差 >= 100:
		return "正道"
	if 差 <= -100:
		return "魔道"
	return "中立"


## 派系识别算法（基于好感度网络自动识别派系）
func _识别派系() -> void:
	派系列表.clear()
	派系关系表.clear()
	
	# 获取在宗弟子
	var 在宗弟子: Array = []
	for d in Game.弟子列表:
		if d != null and (d is Disciple) and d.状态 == "在宗" and d.境界 in ["筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘"]:
			在宗弟子.append(d)
	
	if 在宗弟子.size() < 3:
		return
	
	# 构建好感度矩阵，找出互相好感度>60的关系对
	var 已访问: Dictionary = {}
	var 派系ID计数: int = 0
	
	for d in 在宗弟子:
		if 已访问.has(d.弟子ID):
			continue
		# BFS找出派系
		var 派系成员: Array = []
		var 队列: Array = [d]
		已访问[d.弟子ID] = true
		while 队列.size() > 0:
			var 当前: Disciple = 队列.pop_front()
			派系成员.append(当前)
			# 找出与当前互相好感度>60的弟子
			for 其他 in 在宗弟子:
				if 已访问.has(其他.弟子ID):
					continue
				var 好感1: int = 当前.获取好感度(其他.弟子ID)
				var 好感2: int = 其他.获取好感度(当前.弟子ID)
				if 好感1 > 60 and 好感2 > 60:
					已访问[其他.弟子ID] = true
					队列.append(其他)
		
		# 派系成员>=3才形成派系
		if 派系成员.size() >= 3:
			派系ID计数 += 1
			var 派系ID: String = "faction_%d" % 派系ID计数
			# 找出派系领袖（声望最高的成员）
			var 领袖: Disciple = 派系成员[0]
			for m in 派系成员:
				if m.Game.声望 > 领袖.Game.声望:
					领袖 = m
			# 判断派系类型
			var 派系类型: String = _判断派系类型(派系成员)
			# 计算派系名称
			var 派系名称: String = _生成派系名称(派系类型, 领袖)
			# 计算团结度
			var 团结度: float = _计算派系团结度(派系成员)
			# 创建派系
			var 派系: Dictionary = {
				"派系ID": 派系ID,
				"名称": 派系名称,
				"类型": 派系类型,
				"领袖ID": 领袖.弟子ID,
				"领袖名": 领袖.姓名,
				"成员列表": [],
				"影响力": 0.0,
				"满意度": 60.0,
				"团结度": 团结度,
				"创建日": Game.累计游戏日
			}
			for m in 派系成员:
				派系["成员列表"].append(m.弟子ID)
			# 计算影响力
			派系["影响力"] = _计算派系影响力(派系)
			派系列表.append(派系)
	
	# 计算派系之间的关系
	_计算派系关系()

## 判断派系类型
func _判断派系类型(成员列表: Array) -> String:
	var 类型计数: Dictionary = {
		"修炼派": 0, "务实派": 0, "激进派": 0, "保守派": 0, "种族派": 0, "家族派": 0
	}
	for m in 成员列表:
		# 基于性格判断
		match m.性格:
			"勤奋": 类型计数["修炼派"] += 2
			"谨慎": 类型计数["保守派"] += 2
			"好斗": 类型计数["激进派"] += 2
			"社交": 类型计数["务实派"] += 1
			"开朗": 类型计数["务实派"] += 1
			"懒散": 类型计数["保守派"] += 1
			"孤僻": 类型计数["修炼派"] += 1
		# 基于司职判断
		if m.司职 in ["炼丹", "炼器", "阵法师"]:
			类型计数["修炼派"] += 1
		elif m.司职 in ["执法", "内务", "外务"]:
			类型计数["务实派"] += 1
		elif m.司职 in ["历练", "远征"]:
			类型计数["激进派"] += 1
	# 找出最高类型
	var 最高类型: String = "修炼派"
	var 最高计数: int = 0
	for t in 类型计数:
		if int(类型计数[t]) > 最高计数:
			最高计数 = int(类型计数[t])
			最高类型 = t
	return 最高类型

## 生成派系名称
func _生成派系名称(类型: String, 领袖: Disciple) -> String:
	match 类型:
		"修炼派": return "%s修炼会" % 领袖.姓名
		"务实派": return "%s务实派" % 领袖.姓名
		"激进派": return "%s激进盟" % 领袖.姓名
		"保守派": return "%s保守堂" % 领袖.姓名
		"种族派": return "%s族盟" % 领袖.种族
		"家族派": return "%s家族" % 领袖.家族名
	return "%s派" % 领袖.姓名

## 计算派系团结度
func _计算派系团结度(成员列表: Array) -> float:
	if 成员列表.size() < 2:
		return 100.0
	var 总好感: int = 0
	var 计数: int = 0
	for i in range(成员列表.size()):
		for j in range(i + 1, 成员列表.size()):
			var d1: Disciple = 成员列表[i]
			var d2: Disciple = 成员列表[j]
			总好感 += d1.获取好感度(str(d2.弟子ID))
			总好感 += d2.获取好感度(str(d1.弟子ID))
			计数 += 2
	if 计数 == 0:
		return 50.0
	return float(总好感) / float(计数)

## 计算派系影响力
func _计算派系影响力(派系: Dictionary) -> float:
	var 成员列表: Array = 派系.get("成员列表", [])
	var 影响力: float = 0.0
	# 成员数量（30%）
	影响力 += float(成员列表.size()) * 3.0
	# 成员职位（30%）
	for 成员ID in 成员列表:
		var d: Disciple = Game._按ID找弟子(str(成员ID))
		if d == null:
			continue
		match d.身份:
			"宗主": 影响力 += 30.0
			"长老": 影响力 += 20.0
			"堂主": 影响力 += 15.0
			"执事": 影响力 += 10.0
			_: 影响力 += 3.0
	# 成员实力（20%）
	for 成员ID in 成员列表:
		var d: Disciple = Game._按ID找弟子(str(成员ID))
		if d == null:
			continue
		var 境界权重: Dictionary = {"筑基": 1, "金丹": 3, "元婴": 6, "化神": 10, "炼虚": 15, "合体": 20, "大乘": 30}
		影响力 += float(境界权重.get(d.境界, 1)) * 1.0
	# 团结度（20%）
	影响力 += float(派系.get("团结度", 50)) * 0.2
	return 影响力

## 计算派系关系
func _计算派系关系() -> void:
	for i in range(派系列表.size()):
		for j in range(i + 1, 派系列表.size()):
			var 派系1: Dictionary = 派系列表[i]
			var 派系2: Dictionary = 派系列表[j]
			var 关系值: int = 0
			# 计算成员之间的平均好感度
			var 总好感: int = 0
			var 计数: int = 0
			for id1 in 派系1.get("成员列表", []):
				for id2 in 派系2.get("成员列表", []):
					var d1: Disciple = Game._按ID找弟子(str(id1))
					var d2: Disciple = Game._按ID找弟子(str(id2))
					if d1 != null and d2 != null:
						总好感 += d1.获取好感度(str(id2))
						总好感 += d2.获取好感度(str(id1))
						计数 += 2
			if 计数 > 0:
				关系值 = int(float(总好感) / float(计数)) - 50
			var key: String = "%s-%s" % [派系1.get("派系ID", ""), 派系2.get("派系ID", "")]
			派系关系表[key] = 关系值

## 计算派系满意度
func _计算派系满意度(派系: Dictionary) -> float:
	var 满意度: float = 60.0
	var 领袖ID: String = str(派系.get("领袖ID", ""))
	var 领袖: Disciple = Game._按ID找弟子(领袖ID)
	if 领袖 == null:
		return 满意度
	# 领袖职位影响
	match 领袖.身份:
		"宗主": 满意度 += 20
		"长老": 满意度 += 15
		"堂主": 满意度 += 10
		"执事": 满意度 += 5
		_: 满意度 -= 5
	# 派系影响力影响（影响力高但职位低会不满）
	var 影响力: float = float(派系.get("影响力", 0))
	if 影响力 > 100 and 领袖.身份 not in ["宗主", "长老"]:
		满意度 -= 10
	# 宗门派系政策影响
	match 宗门派系政策:
		"平衡": 满意度 += 0
		"扶持": 满意度 += 10
		"打压": 满意度 -= 15
		"分化": 满意度 -= 5
	return clamp(满意度, 0, 100)

## 月度派系更新
func _月度派系更新() -> void:
	# 每30天重新识别派系
	if Game.累计游戏日 - 派系更新日 >= 30:
		_识别派系()
		派系更新日 = Game.累计游戏日
	# 更新每个派系的影响力和满意度
	for 派系 in 派系列表:
		派系["影响力"] = _计算派系影响力(派系)
		派系["满意度"] = _计算派系满意度(派系)
	# 重新计算派系关系
	_计算派系关系()
	# 派系满意度低时触发警告
	for 派系 in 派系列表:
		var 满意度: float = float(派系.get("满意度", 60))
		if 满意度 < 30 and randf() < 0.1:
			Game._加推演条目("⚠ %s人心尽失（%.0f%%），恐生肘腋之变！" % [str(派系.get("名称", "")), 满意度], "宗门警讯", "高")

## 获取派系列表
func 获取派系列表() -> Array:
	return 派系列表

## 获取派系详情
func 获取派系详情(派系ID: String) -> Dictionary:
	for 派系 in 派系列表:
		if str(派系.get("派系ID", "")) == 派系ID:
			return 派系
	return {}

## 获取派系成员详情
func 获取派系成员详情(派系ID: String) -> Array:
	var 派系: Dictionary = 获取派系详情(派系ID)
	if 派系.is_empty():
		return []
	var 结果: Array = []
	for 成员ID in 派系.get("成员列表", []):
		var d: Disciple = Game._按ID找弟子(str(成员ID))
		if d != null:
			结果.append({
				"弟子ID": d.弟子ID,
				"姓名": d.姓名,
				"境界": d.境界,
				"身份": d.身份,
				"Game.声望": d.Game.声望,
				"是领袖": str(成员ID) == str(派系.get("领袖ID", ""))
			})
	return 结果

## 获取弟子所属派系
func 获取弟子所属派系(弟子ID: String) -> Dictionary:
	for 派系 in 派系列表:
		for 成员ID in 派系.get("成员列表", []):
			if str(成员ID) == 弟子ID:
				return 派系
	return {}
# ============ 派系与权力斗争系统 P1：权力斗争机制 ============
var 职位空缺记录: Array = []          # 职位空缺记录（{职位, 空缺日, 候选人列表}）
var 资源分配记录: Dictionary = {}       # 资源分配记录（{派系ID: 分配比例}）
var 宗门内斗记录: Array = []            # 宗门内斗记录（{冲突ID, 派系1, 派系2, 类型, 严重程度, 开始日, 状态}）
var 宗门内斗ID计数: int = 0             # 宗门内斗ID计数

## P1-1 职位争夺机制：检查职位空缺，派系推举候选人
func _检查职位空缺() -> void:
	# 重要职位列表
	var 重要职位: Array = ["长老", "堂主", "执事"]
	for 职位 in 重要职位:
		# 检查该职位是否有人担任
		var 担任者: Disciple = null
		for d in Game.弟子列表:
			if d != null and (d is Disciple) and d.状态 == "在宗" and d.身份 == 职位:
				担任者 = d
				break
		if 担任者 == null:
			# 职位空缺，检查是否已记录
			var 已记录: bool = false
			for 记录 in 职位空缺记录:
				if str(记录.get("职位", "")) == 职位:
					已记录 = true
					break
			if not 已记录:
				# 记录空缺，各派系推举候选人
				var 候选人: Array = []
				for 派系 in 派系列表:
					var 领袖ID: String = str(派系.get("领袖ID", ""))
					var 领袖: Disciple = Game._按ID找弟子(领袖ID)
					if 领袖 != null and 领袖.状态 == "在宗" and 领袖.身份 not in 重要职位:
						候选人.append({"弟子ID": 领袖ID, "姓名": 领袖.姓名, "派系ID": 派系.get("派系ID", ""), "派系名": 派系.get("名称", ""), "Game.声望": 领袖.Game.声望})
				职位空缺记录.append({"职位": 职位, "空缺日": Game.累计游戏日, "候选人列表": 候选人})
				var 候选姓名: Array = []
				for c in 候选人:
					候选姓名.append(str(c.get("姓名", "")))
				Game._加推演条目("◇ %s◇ 宗门要职空缺，各方势力蠢蠢欲动：%s" % [职位, ", ".join(候选姓名)], "要职空缺", "中")

## P1-1 ◇ 宗主钦命职位（玩家操作），影响派系满意度
func 宗主钦命职位(弟子ID: String, 职位: String) -> Dictionary:
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null:
		return {"成功": false, "因": "查无此人"}
	if d.状态 != "在宗":
		return {"成功": false, "因": "此人不在宗门"}
	
	# 查找该弟子所属派系
	var 所属派系: Dictionary = 获取弟子所属派系(弟子ID)
	var 原身份: String = d.身份
	d.身份 = 职位
	
	# 影响派系满意度
	if not 所属派系.is_empty():
		var 派系ID: String = str(所属派系.get("派系ID", ""))
		for 派系 in 派系列表:
			if str(派系.get("派系ID", "")) == 派系ID:
				# ◇ 宗主钦命该派系成员，提升该派系满意度
				var 提升: float = 10.0
				match 职位:
					"长老": 提升 = 15.0
					"堂主": 提升 = 10.0
					"执事": 提升 = 5.0
				派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 提升)
				# 其他派系满意度下降
			else:
				var 下降: float = 3.0
				match 职位:
					"长老": 下降 = 8.0
					"堂主": 下降 = 5.0
					"执事": 下降 = 2.0
				派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 下降)
	
	# 从空缺记录中移除
	for i in range(职位空缺记录.size()):
		if str(职位空缺记录[i].get("职位", "")) == 职位:
			职位空缺记录.remove_at(i)
			break
	
	Game._加推演条目("◇ ◇ 宗主钦命%s为%s（原：%s）" % [d.姓名, 职位, 原身份], "人事◇ 宗主钦命", "中")
	return {"成功": true, "消息": "已◇ 宗主钦命%s为%s" % [d.姓名, 职位]}

## P1-2 资源分配冲突：设置资源分配比例，影响派系满意度
func 设置资源分配(派系ID: String, 比例: float) -> Dictionary:
	if 比例 < 0 or 比例 > 100:
		return {"成功": false, "因": "比例须在0-100之间"}
	资源分配记录[派系ID] = 比例
	# 影响派系满意度
	for 派系 in 派系列表:
		if str(派系.get("派系ID", "")) == 派系ID:
			var 当前比例: float = float(资源分配记录.get(派系ID, 20))
			if 比例 > 当前比例:
				派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 5)
			elif 比例 < 当前比例:
				派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 8)
	return {"成功": true, "消息": "已设置%s资源分配比例为%.0f%%" % [派系ID, 比例]}

## P1-2 月度资源分配检查：分配不均引发冲突
func _月度资源分配检查() -> void:
	if 派系列表.size() < 2:
		return
	# 计算平均分配比例
	var 总比例: float = 0
	for 派系 in 派系列表:
		var 派系ID: String = str(派系.get("派系ID", ""))
		总比例 += float(资源分配记录.get(派系ID, 20))
	var 平均比例: float = 总比例 / float(派系列表.size())
	# 检查分配不均
	for 派系 in 派系列表:
		var 派系ID: String = str(派系.get("派系ID", ""))
		var 比例: float = float(资源分配记录.get(派系ID, 20))
		if 比例 < 平均比例 * 0.5:
			# 分配严重不均，满意度下降
			派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 3)
			if randf() < 0.1:
				Game._加推演条目("◇ %s供奉菲薄（%.0f%% vs 均值%.0f%%），门下弟子怨声载道" % [str(派系.get("名称","")), 比例, 平均比例], "供奉之争", "中")

## P1-3 政策影响：制定宗门政策，影响派系满意度
func 制定宗门政策(政策名: String, 持续日: int = 365) -> Dictionary:
	var 政策影响: Dictionary = {
		"对外扩张": {"激进派": 10, "保守派": -10},
		"闭关守成": {"保守派": 10, "激进派": -10},
		"重视修炼": {"修炼派": 10, "务实派": -5},
		"重视实务": {"务实派": 10, "修炼派": -5},
		"种族平等": {"种族派": -5},
		"家族优先": {"家族派": 10}
	}
	if not 政策影响.has(政策名):
		return {"成功": false, "因": "未知政令，可选：对外扩张/闭关守成/重视修炼/重视实务/种族平等/家族优先"}
	
	# 互斥政策检查
	var 互斥政策: Dictionary = {
		"对外扩张": "闭关守成",
		"闭关守成": "对外扩张",
		"重视修炼": "重视实务",
		"重视实务": "重视修炼"
	}
	if 互斥政策.has(政策名):
		var 冲突政策: String = str(互斥政策[政策名])
		if 宗门政策记录.has(冲突政策):
			# 自动取消冲突政策
			宗门政策记录.erase(冲突政策)
			Game._加推演条目("◇ 政令「%s」与「%s」相悖，已废「%s」" % [政策名, 冲突政策, 冲突政策], "政令相悖", "中")
	
	宗门政策记录[政策名] = {"生效日": Game.累计游戏日, "持续日": 持续日, "影响": 政策影响[政策名]}
	
	# 立即影响派系满意度
	var 影响: Dictionary = 政策影响[政策名]
	for 派系类型 in 影响:
		var 影响值: float = float(影响[派系类型])
		for 派系 in 派系列表:
			if str(派系.get("类型", "")) == 派系类型:
				派系["满意度"] = clamp(float(派系.get("满意度", 60)) + 影响值, 0, 100)
	
	# ★ 2026-09-16 修：原格式串「（为期一载，可随时废黜）」只有 1 个占位符却给了 2 个实参，
	#   本行即抛「not all arguments converted」并中断颁令；且写死的「一载」与 持续日 参数亦不符。
	Game._加推演条目("◇ 宗主颁令：%s（持续 %d 日，可随时废黜）" % [政策名, 持续日], "宗主颁令", "中")
	return {"成功": true, "消息": "已颁布政策：%s" % 政策名}

## P1-3 月度政策检查：政策到期、持续影响
func _月度政策检查() -> void:
	var 到期政策: Array = []
	for 政策名 in 宗门政策记录:
		var 政策: Dictionary = 宗门政策记录[政策名]
		var 生效日: int = int(政策.get("生效日", 0))
		var 持续日: int = int(政策.get("持续日", 90))
		if Game.累计游戏日 - 生效日 >= 持续日:
			到期政策.append(政策名)
	# 移除到期政策
	for 政策名 in 到期政策:
		宗门政策记录.erase(政策名)
		Game._加推演条目("◇ 政令「%s」期满" % 政策名, "政令期满", "低")

## P1-4 宗门内斗事件：满意度低时触发冲突
func _检查宗门内斗() -> void:
	for 派系 in 派系列表:
		var 满意度: float = float(派系.get("满意度", 60))
		var 派系ID: String = str(派系.get("派系ID", ""))
		var 派系名: String = str(派系.get("名称", ""))
		
		if 满意度 < 20:
			# 非常不满，可能发生严重冲突
			if randf() < 0.15:
				_触发宗门内斗(派系, "严重")
		elif 满意度 < 40:
			# 不满，可能发生中等冲突
			if randf() < 0.1:
				_触发宗门内斗(派系, "中等")
		elif 满意度 < 60:
			# 一般，可能发生轻微冲突
			if randf() < 0.05:
				_触发宗门内斗(派系, "轻微")

## P1-4 触发宗门内斗
func _触发宗门内斗(派系: Dictionary, 严重程度: String) -> void:
	var 派系ID: String = str(派系.get("派系ID", ""))
	var 派系名: String = str(派系.get("名称", ""))
	宗门内斗ID计数 += 1
	var 冲突ID: String = "conflict_%d" % 宗门内斗ID计数
	
	var 冲突类型: String = ""
	var 冲突描述: String = ""
	match 严重程度:
		"轻微":
			var 类型列表: Array = ["消极怠工", "私下抱怨", "消极抵制"]
			冲突类型 = 类型列表[randi() % 类型列表.size()]
			冲突描述 = "%s成员开始%s，修炼效率下降" % [派系名, 冲突类型]
		"中等":
			var 类型列表: Array = ["公开反对", "集体请愿", "拒绝执行"]
			冲突类型 = 类型列表[randi() % 类型列表.size()]
			冲突描述 = "%s成员%s，宗门管理受阻" % [派系名, 冲突类型]
		"严重":
			var 类型列表: Array = ["→ 叛出宗门", "◆ 逼宫作乱", "武力对抗"]
			冲突类型 = 类型列表[randi() % 类型列表.size()]
			冲突描述 = "%s成员%s，宗门面临严重危机！" % [派系名, 冲突类型]
	
	var 冲突记录: Dictionary = {
		"冲突ID": 冲突ID,
		"派系ID": 派系ID,
		"派系名": 派系名,
		"类型": 冲突类型,
		"严重程度": 严重程度,
		"开始日": Game.累计游戏日,
		"状态": "进行中"
	}
	宗门内斗记录.append(冲突记录)
	
	# 冲突影响
	match 严重程度:
		"轻微":
			# 该派系修炼效率下降
			for 成员ID in 派系.get("成员列表", []):
				var d: Disciple = Game._按ID找弟子(str(成员ID))
				if d != null:
					d.心境 = max(0, d.心境 - 3)
		"中等":
			# 该派系满意度进一步下降
			派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 10)
			for 成员ID in 派系.get("成员列表", []):
				var d: Disciple = Game._按ID找弟子(str(成员ID))
				if d != null:
					d.心境 = max(0, d.心境 - 5)
		"严重":
			# 严重冲突，可能→ 叛出宗门
			派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 20)
			if randf() < 0.3:
				# 30%概率→ 叛出宗门
				for 成员ID in 派系.get("成员列表", []):
					var d: Disciple = Game._按ID找弟子(str(成员ID))
					if d != null and randf() < 0.5:
						d.状态 = "叛逃"
				冲突描述 += " 部分成员已叛逃！"
	
	Game._加推演条目("◆ %s" % 冲突描述, "◆ 宗门内斗", "高")

## P1-4 调解宗门内斗（玩家操作）
func 调解宗门内斗(冲突ID: String) -> Dictionary:
	for 冲突 in 宗门内斗记录:
		if str(冲突.get("冲突ID", "")) == 冲突ID and str(冲突.get("状态", "")) == "进行中":
			冲突["状态"] = "已调解"
			var 派系ID: String = str(冲突.get("派系ID", ""))
			for 派系 in 派系列表:
				if str(派系.get("派系ID", "")) == 派系ID:
					派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 10)
					break
			Game._加推演条目("◇ 宗主亲自斡旋，%s纷争平息" % str(冲突.get("派系名","")), "斡旋调停", "中")
			return {"成功": true, "消息": "冲突已调解"}
	return {"成功": false, "因": "此纷争已了或不存在"}

## P1-6 月度权力斗争推演
func _月度权力斗争推演() -> void:
	# 检查职位空缺
	_检查职位空缺()
	# 资源分配检查
	_月度资源分配检查()
	# 政策检查
	_月度政策检查()
	# 宗门内斗检查
	_检查宗门内斗()
	# 冲突自动平息（30天后自动平息）
	for i in range(宗门内斗记录.size() - 1, -1, -1):
		var 冲突: Dictionary = 宗门内斗记录[i]
		if str(冲突.get("状态", "")) == "进行中":
			var 开始日: int = int(冲突.get("开始日", 0))
			if Game.累计游戏日 - 开始日 > 30:
				冲突["状态"] = "自动平息"
				宗门内斗记录[i] = 冲突

## 获取职位空缺列表
func 获取职位空缺列表() -> Array:
	return 职位空缺记录

## 获取宗门内斗列表
func 获取宗门内斗列表() -> Array:
	return 宗门内斗记录

## 获取宗门政策列表
func 获取宗门政策列表() -> Dictionary:
	return 宗门政策记录

## 取消宗门政策（玩家操作）
func 取消宗门政策(政策名: String) -> Dictionary:
	if not 宗门政策记录.has(政策名):
		return {"成功": false, "因": "此政令已废或不存在"}
	# 恢复政策影响（反向调整满意度）
	var 政策: Dictionary = 宗门政策记录[政策名]
	var 影响: Dictionary = 政策.get("影响", {})
	for 派系类型 in 影响:
		var 影响值: float = float(影响[派系类型])
		for 派系 in 派系列表:
			if str(派系.get("类型", "")) == 派系类型:
				派系["满意度"] = clamp(float(派系.get("满意度", 60)) - 影响值, 0, 100)
	宗门政策记录.erase(政策名)
	Game._加推演条目("◇ 宗主废黜政令：%s" % 政策名, "废黜政令", "中")
	return {"成功": true, "消息": "已取消政策：%s" % 政策名}
# ============ 派系与权力斗争系统 P2：玩家管理操作深化 ============
var 心腹列表: Array = []                 # 宗主心腹列表（弟子ID）
var 人事调动记录: Array = []              # 人事调动记录（{弟子ID, 原职位, 新职位, 调动日, 类型}）
var 联盟ID计数: int = 0                   # 联盟ID计数
var 对抗ID计数: int = 0                   # 对抗ID计数
var 分化ID计数: int = 0                   # 分化ID计数

## P2-1 培养心腹：将弟子标记为心腹，提升忠诚度
func 培养心腹(弟子ID: String) -> Dictionary:
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null:
		return {"成功": false, "因": "查无此人"}
	if d.状态 != "在宗":
		return {"成功": false, "因": "此人不在宗门"}
	if d.是否心腹:
		return {"成功": false, "因": "此人已是心腹"}
	
	# 检查忠诚度是否达标（需要>=50才能培养）
	if d.对宗主忠诚度 < 50:
		return {"成功": false, "因": "忠心未孚（需>=50），当前%.0f" % d.对宗主忠诚度}
	
	d.是否心腹 = true
	d.心腹等级 = 1
	d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 20)
	心腹列表.append(弟子ID)
	
	# 影响派系满意度
	var 所属派系: Dictionary = 获取弟子所属派系(弟子ID)
	if not 所属派系.is_empty():
		var 派系ID: String = str(所属派系.get("派系ID", ""))
		for 派系 in 派系列表:
			if str(派系.get("派系ID", "")) == 派系ID:
				派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 5)
				break
	
	Game._加推演条目("◇ 宗主将%s引为心腹，誓死效忠" % d.姓名, "引为心腹", "中")
	return {"成功": true, "消息": "已将%s◇ 引为心腹" % d.姓名}

## P2-1 提升心腹等级
func 提升心腹等级(弟子ID: String) -> Dictionary:
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null or not d.是否心腹:
		return {"成功": false, "因": "该弟子不是心腹"}
	if d.心腹等级 >= 3:
		return {"成功": false, "因": "已至死忠之境"}
	
	d.心腹等级 += 1
	d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 15)
	
	var 等级名: String = ""
	match d.心腹等级:
		1: 等级名 = "信任"
		2: 等级名 = "核心"
		3: 等级名 = "死忠"
	
	Game._加推演条目("★ %s晋为「%s」" % [d.姓名, 等级名], "心腹晋阶", "中")
	return {"成功": true, "消息": "%s心腹品级擢升为「%s」" % [d.姓名, 等级名]}

## P2-1 月度心腹培养：心腹忠诚度自然增长，叛逃概率降低
func _月度心腹培养() -> void:
	for 弟子ID in 心腹列表:
		var d: Disciple = Game._按ID找弟子(str(弟子ID))
		if d != null and d.状态 == "在宗":
			# 心腹忠诚度自然增长
			d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 2)
			# 心腹等级越高，增长越快
			if d.心腹等级 >= 2:
				d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 1)
			if d.心腹等级 >= 3:
				d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 1)

## P2-2 派系分化：拉拢派系成员，分化大派系
func 拉拢派系成员(弟子ID: String) -> Dictionary:
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null or d.状态 != "在宗":
		return {"成功": false, "因": "弟子不存在或不在宗"}
	
	var 所属派系: Dictionary = 获取弟子所属派系(弟子ID)
	if 所属派系.is_empty():
		return {"成功": false, "因": "此人无门无派"}
	
	# 提升该弟子对宗主的忠诚度
	d.对宗主忠诚度 = min(100, d.对宗主忠诚度 + 10)
	# 降低该弟子对派系的归属感（通过降低与派系其他成员的好感度）
	var 派系ID: String = str(所属派系.get("派系ID", ""))
	for 派系 in 派系列表:
		if str(派系.get("派系ID", "")) == 派系ID:
			for 成员ID in 派系.get("成员列表", []):
				if str(成员ID) != 弟子ID:
					var 其他: Disciple = Game._按ID找弟子(str(成员ID))
					if 其他 != null:
						# 降低双方好感度
						if d.好感度缓存.has(str(成员ID)):
							d.好感度缓存[str(成员ID)] = max(0, float(d.好感度缓存[str(成员ID)]) - 5)
						if 其他.好感度缓存.has(弟子ID):
							其他.好感度缓存[弟子ID] = max(0, float(其他.好感度缓存[弟子ID]) - 5)
			break
	
	分化ID计数 += 1
	派系分化记录.append({"分化ID": "div_%d" % 分化ID计数, "目标派系": 派系ID, "手段": "拉拢", "目标弟子": 弟子ID, "开始日": Game.累计游戏日, "效果": 10, "状态": "进行中"})
	
	Game._加推演条目("◇ 宗主暗中笼络%s，派系人心离散" % d.姓名, "分化瓦解", "中")
	return {"成功": true, "消息": "已拉拢%s，派系凝聚力下降" % d.姓名}

## P2-2 离间派系成员：制造派系内部矛盾
func 离间派系成员(弟子ID1: String, 弟子ID2: String) -> Dictionary:
	var d1: Disciple = Game._按ID找弟子(弟子ID1)
	var d2: Disciple = Game._按ID找弟子(弟子ID2)
	if d1 == null or d2 == null:
		return {"成功": false, "因": "查无此人"}
	
	var 派系1: Dictionary = 获取弟子所属派系(弟子ID1)
	var 派系2: Dictionary = 获取弟子所属派系(弟子ID2)
	if 派系1.is_empty() or 派系2.is_empty():
		return {"成功": false, "因": "弟子不属于任何派系"}
	if str(派系1.get("派系ID", "")) != str(派系2.get("派系ID", "")):
		return {"成功": false, "因": "二人非同派弟子"}
	
	# 大幅降低双方好感度
	if d1.好感度缓存.has(弟子ID2):
		d1.好感度缓存[弟子ID2] = max(0, float(d1.好感度缓存[弟子ID2]) - 20)
	if d2.好感度缓存.has(弟子ID1):
		d2.好感度缓存[弟子ID1] = max(0, float(d2.好感度缓存[弟子ID1]) - 20)
	
	# 添加负面记忆
	d1.添加记忆(弟子ID2, d2.姓名, "负面", "因宗主离间而产生矛盾", -10)
	d2.添加记忆(弟子ID1, d1.姓名, "负面", "因宗主离间而产生矛盾", -10)
	
	分化ID计数 += 1
	派系分化记录.append({"分化ID": "div_%d" % 分化ID计数, "目标派系": 派系1.get("派系ID", ""), "手段": "离间", "目标弟子1": 弟子ID1, "目标弟子2": 弟子ID2, "开始日": Game.累计游戏日, "效果": 20, "状态": "进行中"})
	
	Game._加推演条目("◆ 宗主施离间计，%s与%s反目，派系内乱" % [d1.姓名, d2.姓名], "分化瓦解", "高")
	return {"成功": true, "消息": "已离间%s与%s" % [d1.姓名, d2.姓名]}

## P2-3 人事调动：调任/降职/外派/冷藏
func 人事调动(弟子ID: String, 调动类型: String, 新职位: String = "") -> Dictionary:
	var d: Disciple = Game._按ID找弟子(弟子ID)
	if d == null or d.状态 != "在宗":
		return {"成功": false, "因": "弟子不存在或不在宗"}
	
	var 原职位: String = d.身份
	var 调动描述: String = ""
	
	match 调动类型:
		"调任":
			if 新职位 == "":
				return {"成功": false, "因": "调任需指明新任"}
			d.身份 = 新职位
			调动描述 = "调任"
		"降职":
			var 职位顺序: Array = ["宗主", "长老", "堂主", "执事", "内门", "外门"]
			var 当前索引: int = 职位顺序.find(原职位)
			if 当前索引 > 0 and 当前索引 < 职位顺序.size() - 1:
				d.身份 = str(职位顺序[当前索引 + 1])
				调动描述 = "降职为%s" % d.身份
			else:
				return {"成功": false, "因": "已是最低品阶"}
		"外派":
			d.状态 = "外派"
			调动描述 = "外派历练"
		"冷藏":
			d.身份 = "外门"
			d.对宗主忠诚度 = max(0, d.对宗主忠诚度 - 15)
			调动描述 = "冷藏（贬为外门）"
		_:
			return {"成功": false, "因": "未知调遣之法，可选：调任/降职/外派/冷藏"}
	
	人事调动记录.append({"弟子ID": 弟子ID, "姓名": d.姓名, "原职位": 原职位, "新职位": d.身份, "调动日": Game.累计游戏日, "类型": 调动类型})
	
	# 影响派系满意度
	var 所属派系: Dictionary = 获取弟子所属派系(弟子ID)
	if not 所属派系.is_empty():
		var 派系ID: String = str(所属派系.get("派系ID", ""))
		for 派系 in 派系列表:
			if str(派系.get("派系ID", "")) == 派系ID:
				match 调动类型:
					"调任": 派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 3)
					"降职": 派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 10)
					"外派": 派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 5)
					"冷藏": 派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 15)
				break
	
	Game._加推演条目("◇ %s：%s（原：%s）" % [调动描述, d.姓名, 原职位], "人事变动", "中")
	return {"成功": true, "消息": "%s：%s" % [调动描述, d.姓名]}

## P2-4 促成派系联盟
func 促成派系联盟(派系ID1: String, 派系ID2: String) -> Dictionary:
	if 派系ID1 == 派系ID2:
		return {"成功": false, "因": "不可与己结盟"}
	
	# 检查是否已结盟
	for 联盟 in 派系联盟记录:
		if str(联盟.get("状态", "")) == "进行中":
			if (str(联盟.get("派系1", "")) == 派系ID1 and str(联盟.get("派系2", "")) == 派系ID2) or \
			   (str(联盟.get("派系1", "")) == 派系ID2 and str(联盟.get("派系2", "")) == 派系ID1):
				return {"成功": false, "因": "两派已有盟约"}
	
	联盟ID计数 += 1
	var 联盟ID: String = "ally_%d" % 联盟ID计数
	派系联盟记录.append({"联盟ID": 联盟ID, "派系1": 派系ID1, "派系2": 派系ID2, "开始日": Game.累计游戏日, "状态": "进行中"})
	
	# 提升两派满意度
	for 派系 in 派系列表:
		if str(派系.get("派系ID", "")) == 派系ID1 or str(派系.get("派系ID", "")) == 派系ID2:
			派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 8)
	
	Game._加推演条目("◇ 宗主促成两派结盟，同气连枝" , "两派结盟", "中")
	return {"成功": true, "消息": "已促成派系联盟", "联盟ID": 联盟ID}

## P2-4 挑起派系对抗
func 挑起派系对抗(派系ID1: String, 派系ID2: String) -> Dictionary:
	if 派系ID1 == 派系ID2:
		return {"成功": false, "因": "不可与己相斗"}
	
	对抗ID计数 += 1
	var 对抗ID: String = "rival_%d" % 对抗ID计数
	派系对抗记录.append({"对抗ID": 对抗ID, "派系1": 派系ID1, "派系2": 派系ID2, "开始日": Game.累计游戏日, "严重程度": "中等", "状态": "进行中"})
	
	# 降低两派满意度，提升对抗意识
	for 派系 in 派系列表:
		if str(派系.get("派系ID", "")) == 派系ID1 or str(派系.get("派系ID", "")) == 派系ID2:
			派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 5)
	
	Game._加推演条目("◆ 宗主暗中挑动两派相斗，鹬蚌相争" , "挑动相斗", "高")
	return {"成功": true, "消息": "已挑起派系对抗", "对抗ID": 对抗ID}

## P2-6 月度玩家管理操作推演
func _月度玩家管理推演() -> void:
	# 月度心腹培养
	_月度心腹培养()
	# 派系联盟/对抗自动演变（180天后自动结束）
	for i in range(派系联盟记录.size() - 1, -1, -1):
		var 联盟: Dictionary = 派系联盟记录[i]
		if str(联盟.get("状态", "")) == "进行中":
			if Game.累计游戏日 - int(联盟.get("开始日", 0)) > 180:
				联盟["状态"] = "自然结束"
				派系联盟记录[i] = 联盟
	for i in range(派系对抗记录.size() - 1, -1, -1):
		var 对抗: Dictionary = 派系对抗记录[i]
		if str(对抗.get("状态", "")) == "进行中":
			if Game.累计游戏日 - int(对抗.get("开始日", 0)) > 180:
				对抗["状态"] = "自然平息"
				派系对抗记录[i] = 对抗

## 获取心腹列表
func 获取心腹列表() -> Array:
	return 心腹列表

## 获取派系联盟列表
func 获取派系联盟列表() -> Array:
	return 派系联盟记录

## 获取派系对抗列表
func 获取派系对抗列表() -> Array:
	return 派系对抗记录

## 获取人事调动记录
func 获取人事调动记录() -> Array:
	return 人事调动记录
# ============ 派系与权力斗争系统 P3：事件系统深化 ============
var 事件冷却记录: Dictionary = {}           # 事件冷却记录（{事件类型: 最后发生日}）

## P3-1 阴谋事件：派系政变
func _触发派系政变(派系: Dictionary) -> void:
	var 派系ID: String = str(派系.get("派系ID", ""))
	var 派系名: String = str(派系.get("名称", ""))
	var 领袖ID: String = str(派系.get("领袖ID", ""))
	var 领袖: Disciple = Game._按ID找弟子(领袖ID)
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 事件描述: String = ""
	var 后果: Dictionary = {}
	
	# 政变成功率基于派系影响力和满意度
	var 政变成功率: float = 0.3
	if float(派系.get("影响力", 0)) > 80:
		政变成功率 += 0.2
	if float(派系.get("满意度", 60)) < 20:
		政变成功率 += 0.2
	
	if randf() < 政变成功率:
		# 政变成功
		事件描述 = "%s◆ 逼宫作乱成功！宗主被迫让步，%s获得更多权力" % [派系名, 派系名]
		后果 = {"类型": "政变成功", "派系满意度": 20, "宗主权威": -10}
		# 派系满意度大幅提升
		派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 20)
		# 领袖获得职位提升
		if 领袖 != null and 领袖.身份 != "长老":
			领袖.身份 = "长老"
	else:
		# 政变失败
		事件描述 = "%s◆ 逼宫作乱失败！宗主镇压叛乱，%s势力大减" % [派系名, 派系名]
		后果 = {"类型": "政变失败", "派系满意度": -30, "宗主权威": 5}
		# 派系满意度大幅下降
		派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 30)
		# 领袖被降职或外派
		if 领袖 != null:
			if randf() < 0.5:
				领袖.身份 = "外门"
			else:
				领袖.状态 = "外派"
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "阴谋-政变",
		"严重程度": "严重",
		"涉及派系": 派系ID,
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	派系斗争编年史.append(事件记录)
	事件冷却记录["阴谋-政变"] = Game.累计游戏日
	
	Game._加推演条目("◆ %s" % 事件描述, "逼宫之乱", "高")

## P3-1 阴谋事件：暗杀
func _触发暗杀事件(派系: Dictionary) -> void:
	var 派系ID: String = str(派系.get("派系ID", ""))
	var 派系名: String = str(派系.get("名称", ""))
	
	# 暗杀目标：其他派系的领袖或心腹
	var 目标列表: Array = []
	for 其他派系 in 派系列表:
		if str(其他派系.get("派系ID", "")) != 派系ID:
			var 其他领袖ID: String = str(其他派系.get("领袖ID", ""))
			var 其他领袖: Disciple = Game._按ID找弟子(其他领袖ID)
			if 其他领袖 != null and 其他领袖.状态 == "在宗":
				目标列表.append(其他领袖ID)
	
	if 目标列表.is_empty():
		return
	
	var 目标ID: String = str(目标列表[randi() % 目标列表.size()])
	var 目标: Disciple = Game._按ID找弟子(目标ID)
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 事件描述: String = ""
	var 后果: Dictionary = {}
	
	# 暗杀成功率
	var 暗杀成功率: float = 0.2
	if randf() < 暗杀成功率:
		# 暗杀成功
		事件描述 = "%s暗中暗杀%s成功！%s身受重伤，修为大跌" % [派系名, 目标.姓名, 目标.姓名]
		后果 = {"类型": "暗杀成功", "目标": 目标ID, "目标修为": -1, "目标心境": -20}
		目标.心境 = max(0, 目标.心境 - 20)
		# 目标修为下降
		if 目标.境界 != "炼气":
			目标.修炼速度 = max(0.1, 目标.修炼速度 - 0.5)
	else:
		# 暗杀失败，被发现
		事件描述 = "%s暗中暗杀%s失败！事情败露，两派关系恶化" % [派系名, 目标.姓名]
		后果 = {"类型": "暗杀失败", "派系关系": -20}
		# 两派关系恶化
		派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 10)
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "阴谋-暗杀",
		"严重程度": "严重",
		"涉及派系": 派系ID,
		"目标": 目标ID,
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	派系斗争编年史.append(事件记录)
	事件冷却记录["阴谋-暗杀"] = Game.累计游戏日
	
	Game._加推演条目("◆ %s" % 事件描述, "刺客惊魂", "高")

## P3-1 阴谋事件：→ 叛出宗门
func _触发叛出宗门(派系: Dictionary) -> void:
	var 派系ID: String = str(派系.get("派系ID", ""))
	var 派系名: String = str(派系.get("名称", ""))
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 叛逃人数: int = 0
	var 叛逃名单: Array = []
	for 成员ID in 派系.get("成员列表", []):
		var d: Disciple = Game._按ID找弟子(str(成员ID))
		if d != null and d.状态 == "在宗" and not d.是否心腹:
			# 非心腹弟子有50%概率叛逃
			if randf() < 0.5:
				d.状态 = "叛逃"
				叛逃人数 += 1
				叛逃名单.append(d.姓名)
	
	var 事件描述: String = "%s→ 叛出宗门！共有%d名弟子离开宗门：%s" % [派系名, 叛逃人数, ", ".join(叛逃名单)]
	var 后果: Dictionary = {"类型": "→ 叛出宗门", "叛逃人数": 叛逃人数, "宗门实力": -叛逃人数 * 10}
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "阴谋-叛逃",
		"严重程度": "严重",
		"涉及派系": 派系ID,
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	派系斗争编年史.append(事件记录)
	事件冷却记录["阴谋-叛逃"] = Game.累计游戏日
	
	Game._加推演条目("→ %s" % 事件描述, "→ 叛出宗门", "高")

## P3-2 合作事件：派系合作
func _触发派系合作(派系1: Dictionary, 派系2: Dictionary) -> void:
	var 派系ID1: String = str(派系1.get("派系ID", ""))
	var 派系ID2: String = str(派系2.get("派系ID", ""))
	var 派系名1: String = str(派系1.get("名称", ""))
	var 派系名2: String = str(派系2.get("名称", ""))
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 合作类型: Array = ["共同历练", "资源共享", "功法交流", "联合炼丹"]
	var 类型: String = str(合作类型[randi() % 合作类型.size()])
	
	var 事件描述: String = "%s与%s达成%s合作，两派关系缓和" % [派系名1, 派系名2, 类型]
	var 后果: Dictionary = {"类型": "两派修好", "合作类型": 类型, "派系1满意度": 5, "派系2满意度": 5}
	
	# 两派满意度提升
	派系1["满意度"] = min(100, float(派系1.get("满意度", 60)) + 5)
	派系2["满意度"] = min(100, float(派系2.get("满意度", 60)) + 5)
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "合作-%s" % 类型,
		"严重程度": "轻微",
		"涉及派系": "%s,%s" % [派系ID1, 派系ID2],
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	事件冷却记录["合作"] = Game.累计游戏日
	
	Game._加推演条目("◇ %s" % 事件描述, "两派修好", "低")

## P3-3 突发事件：弟子冲突
func _触发弟子冲突() -> void:
	# 随机选择两个不同派系的弟子
	var 派系弟子: Dictionary = {}
	for 派系 in 派系列表:
		var 派系ID: String = str(派系.get("派系ID", ""))
		派系弟子[派系ID] = 派系.get("成员列表", [])
	
	if 派系弟子.size() < 2:
		return
	
	var 派系ID列表: Array = []
	for k in 派系弟子:
		派系ID列表.append(k)
	
	var 派系1ID: String = str(派系ID列表[randi() % 派系ID列表.size()])
	var 派系2ID: String = str(派系ID列表[randi() % 派系ID列表.size()])
	if 派系1ID == 派系2ID:
		return
	
	var 成员1列表: Array = 派系弟子[派系1ID]
	var 成员2列表: Array = 派系弟子[派系2ID]
	if 成员1列表.is_empty() or 成员2列表.is_empty():
		return
	
	var 弟子1: Disciple = Game._按ID找弟子(str(成员1列表[randi() % 成员1列表.size()]))
	var 弟子2: Disciple = Game._按ID找弟子(str(成员2列表[randi() % 成员2列表.size()]))
	if 弟子1 == null or 弟子2 == null:
		return
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 冲突类型: Array = ["言语冲突", "切磋受伤", "资源争夺", "功法之争"]
	var 类型: String = str(冲突类型[randi() % 冲突类型.size()])
	
	var 事件描述: String = "%s与%s发生%s，两派关系紧张" % [弟子1.姓名, 弟子2.姓名, 类型]
	var 后果: Dictionary = {"类型": "门下争执", "冲突类型": 类型, "弟子1心境": -5, "弟子2心境": -5}
	
	弟子1.心境 = max(0, 弟子1.心境 - 5)
	弟子2.心境 = max(0, 弟子2.心境 - 5)
	# 降低双方好感度
	if 弟子1.好感度缓存.has(弟子2.弟子ID):
		弟子1.好感度缓存[str(弟子2.弟子ID)] = max(0, float(弟子1.好感度缓存[str(弟子2.弟子ID)]) - 10)
	if 弟子2.好感度缓存.has(弟子1.弟子ID):
		弟子2.好感度缓存[str(弟子1.弟子ID)] = max(0, float(弟子2.好感度缓存[str(弟子1.弟子ID)]) - 10)
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "突发-%s" % 类型,
		"严重程度": "中等",
		"涉及弟子": "%s,%s" % [弟子1.弟子ID, 弟子2.弟子ID],
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	
	Game._加推演条目("◆ %s" % 事件描述, "门下争执", "中")

## P3-3 突发事件：领袖更替
func _触发领袖更替(派系: Dictionary) -> void:
	var 派系ID: String = str(派系.get("派系ID", ""))
	var 派系名: String = str(派系.get("名称", ""))
	var 旧领袖ID: String = str(派系.get("领袖ID", ""))
	var 旧领袖: Disciple = Game._按ID找弟子(旧领袖ID)
	
	# 选择新领袖（派系中声望第二高的成员）
	var 新领袖ID: String = ""
	var 最高声望: int = 0
	for 成员ID in 派系.get("成员列表", []):
		if str(成员ID) != 旧领袖ID:
			var d: Disciple = Game._按ID找弟子(str(成员ID))
			if d != null and d.状态 == "在宗" and d.Game.声望 > 最高声望:
				最高声望 = d.Game.声望
				新领袖ID = str(成员ID)
	
	if 新领袖ID == "":
		return
	
	var 新领袖: Disciple = Game._按ID找弟子(新领袖ID)
	
	派系事件ID计数 += 1
	var 事件ID: String = "evt_%d" % 派系事件ID计数
	
	var 事件描述: String = "%s领袖更替！%s退位，%s接任新领袖" % [派系名, 旧领袖.姓名 if 旧领袖 != null else "未知", 新领袖.姓名]
	var 后果: Dictionary = {"类型": "派系易主", "旧领袖": 旧领袖ID, "新领袖": 新领袖ID, "派系满意度": -5}
	
	# 更新派系领袖
	派系["领袖ID"] = 新领袖ID
	派系["满意度"] = max(0, float(派系.get("满意度", 60)) - 5)
	
	var 事件记录: Dictionary = {
		"事件ID": 事件ID,
		"类型": "突发-领袖更替",
		"严重程度": "中等",
		"涉及派系": 派系ID,
		"描述": 事件描述,
		"发生日": Game.累计游戏日,
		"状态": "已发生",
		"后果": 后果
	}
	派系事件记录.append(事件记录)
	派系斗争编年史.append(事件记录)
	
	Game._加推演条目("★ %s" % 事件描述, "派系易主", "中")

## P3-5 月度派系事件触发
func _月度派系事件触发() -> void:
	# 事件冷却（每种事件至少间隔90天）
	var 冷却期: int = 90
	
	for 派系 in 派系列表:
		var 满意度: float = float(派系.get("满意度", 60))
		var 影响力: float = float(派系.get("影响力", 0))
		
		# 阴谋事件：满意度低且影响力高时触发
		if 满意度 < 30 and 影响力 > 50:
			# 政变
			if not 事件冷却记录.has("阴谋-政变") or Game.累计游戏日 - int(事件冷却记录["阴谋-政变"]) > 冷却期:
				if randf() < 0.05:
					_触发派系政变(派系)
					continue
			# 暗杀
			if not 事件冷却记录.has("阴谋-暗杀") or Game.累计游戏日 - int(事件冷却记录["阴谋-暗杀"]) > 冷却期:
				if randf() < 0.05:
					_触发暗杀事件(派系)
					continue
			# → 叛出宗门
			if not 事件冷却记录.has("阴谋-叛逃") or Game.累计游戏日 - int(事件冷却记录["阴谋-叛逃"]) > 冷却期:
				if randf() < 0.05:
					_触发叛出宗门(派系)
					continue
		
		# 突发事件：弟子冲突
		if randf() < 0.1:
			_触发弟子冲突()
		
		# 突发事件：领袖更替（领袖不在宗或满意度极低时）
		var 领袖ID: String = str(派系.get("领袖ID", ""))
		var 领袖: Disciple = Game._按ID找弟子(领袖ID)
		if 领袖 != null and (领袖.状态 != "在宗" or 满意度 < 20):
			if randf() < 0.1:
				_触发领袖更替(派系)
	
	# 合作事件：两派满意度都较高时触发
	if 派系列表.size() >= 2:
		for i in range(派系列表.size()):
			for j in range(i + 1, 派系列表.size()):
				var 派系1: Dictionary = 派系列表[i]
				var 派系2: Dictionary = 派系列表[j]
				if float(派系1.get("满意度", 60)) > 60 and float(派系2.get("满意度", 60)) > 60:
					if not 事件冷却记录.has("合作") or Game.累计游戏日 - int(事件冷却记录["合作"]) > 冷却期:
						if randf() < 0.05:
							_触发派系合作(派系1, 派系2)

## 获取派系事件记录
func 获取派系事件记录(类型: String = "", 限制: int = 20) -> Array:
	var 结果: Array = []
	for i in range(派系事件记录.size() - 1, -1, -1):
		var 事件: Dictionary = 派系事件记录[i]
		if 类型 == "" or str(事件.get("类型", "")).begins_with(类型):
			结果.append(事件)
			if 结果.size() >= 限制:
				break
	return 结果

## 获取派系斗争编年史
func 获取派系斗争编年史() -> Array:
	return 派系斗争编年史
# ============ 派系与权力斗争系统 P4：融入其他系统 ============

## P4-1 炼丹炼器派系争夺：派系争夺炼丹炼器资源和名额
func _月度炼丹派系争夺() -> void:
	if 派系列表.size() < 2:
		return
	# 每季度（90天）触发一次炼丹争夺
	if Game.累计游戏日 % 90 != 0:
		return
	
	# 随机选择两个派系争夺珍贵丹方
	var 派系1: Dictionary = 派系列表[randi() % 派系列表.size()]
	var 派系2: Dictionary = 派系列表[randi() % 派系列表.size()]
	if str(派系1.get("派系ID", "")) == str(派系2.get("派系ID", "")):
		return
	
	派系争夺ID计数 += 1
	var 争夺ID: String = "alch_%d" % 派系争夺ID计数
	
	# 争夺结果基于派系影响力和满意度
	var 派系1胜率: float = 0.5 + (float(派系1.get("影响力", 0)) - float(派系2.get("影响力", 0))) / 200
	var 胜者: Dictionary = 派系1
	var 败者: Dictionary = 派系2
	if randf() > 派系1胜率:
		胜者 = 派系2
		败者 = 派系1
	
	# 胜者获得炼丹资源加成，败者满意度下降
	胜者["满意度"] = min(100, float(胜者.get("满意度", 60)) + 5)
	败者["满意度"] = max(0, float(败者.get("满意度", 60)) - 8)
	
	var 争夺记录: Dictionary = {
		"争夺ID": 争夺ID,
		"类型": "丹方之争",
		"派系1": str(派系1.get("名称", "")),
		"派系2": str(派系2.get("名称", "")),
		"胜者": str(胜者.get("名称", "")),
		"奖品": "上古丹方",
		"发生日": Game.累计游戏日
	}
	炼丹派系争夺记录.append(争夺记录)
	
	Game._加推演条目("◇ %s与%s争夺上古丹方，%s技高一筹！" % [str(派系1.get("名称","")), str(派系2.get("名称","")), str(胜者.get("名称",""))], "丹方之争", "中")

## P4-2 历练远征派系争夺：派系争夺历练名额和战利品
func _月度历练派系争夺() -> void:
	if 派系列表.size() < 2:
		return
	# 每半年（180天）触发一次历练争夺
	if Game.累计游戏日 % 180 != 0:
		return
	
	# 随机选择两个派系◇ 争夺秘境入口
	var 派系1: Dictionary = 派系列表[randi() % 派系列表.size()]
	var 派系2: Dictionary = 派系列表[randi() % 派系列表.size()]
	if str(派系1.get("派系ID", "")) == str(派系2.get("派系ID", "")):
		return
	
	派系争夺ID计数 += 1
	var 争夺ID: String = "exp_%d" % 派系争夺ID计数
	
	# 争夺结果基于派系成员实力
	var 派系1胜率: float = 0.5
	var 胜者: Dictionary = 派系1
	var 败者: Dictionary = 派系2
	if randf() > 派系1胜率:
		胜者 = 派系2
		败者 = 派系1
	
	# 胜者获得历练优先权，败者满意度下降
	胜者["满意度"] = min(100, float(胜者.get("满意度", 60)) + 8)
	败者["满意度"] = max(0, float(败者.get("满意度", 60)) - 10)
	
	var 争夺记录: Dictionary = {
		"争夺ID": 争夺ID,
		"类型": "秘境之争",
		"派系1": str(派系1.get("名称", "")),
		"派系2": str(派系2.get("名称", "")),
		"胜者": str(胜者.get("名称", "")),
		"奖品": "秘境入口",
		"发生日": Game.累计游戏日
	}
	历练派系争夺记录.append(争夺记录)
	
	Game._加推演条目("◇ %s与%s争夺秘境入口，%s占得先机！" % [str(派系1.get("名称","")), str(派系2.get("名称","")), str(胜者.get("名称",""))], "秘境之争", "中")

## P4-3 家族派系联动：家族与派系互相影响
func _月度家族派系联动() -> void:
	# 每季度（90天）检查一次家族派系联动
	if Game.累计游戏日 % 90 != 0:
		return
	
	for 派系 in 派系列表:
		var 派系ID: String = str(派系.get("派系ID", ""))
		var 派系名: String = str(派系.get("名称", ""))
		var 家族成员数: int = 0
		var 家族列表: Dictionary = {}
		
		# 统计派系中的家族成员
		for 成员ID in 派系.get("成员列表", []):
			var d: Disciple = Game._按ID找弟子(str(成员ID))
			if d != null and d.家族ID != "":
				家族成员数 += 1
				if not 家族列表.has(d.家族ID):
					家族列表[d.家族ID] = 0
				家族列表[d.家族ID] += 1
		
		# 如果某家族成员占比超过30%，形成家族派系联动
		for 家族ID in 家族列表:
			if float(家族列表[家族ID]) / float(派系.get("成员列表", []).size()) > 0.3:
				# 家族支持派系，派系影响力提升
				派系["影响力"] = float(派系.get("影响力", 0)) + 5
				派系["满意度"] = min(100, float(派系.get("满意度", 60)) + 3)
				
				派系争夺ID计数 += 1
				var 联动ID: String = "fam_%d" % 派系争夺ID计数
				var 联动记录: Dictionary = {
					"联动ID": 联动ID,
					"家族": 家族ID,
					"派系": 派系名,
					"类型": "家族支持",
					"效果": "影响力+5，满意度+3",
					"发生日": Game.累计游戏日
				}
				家族派系联动记录.append(联动记录)
				
				Game._加推演条目("◇ 世家大族力挺%s，派系声威大震！" % 派系名, "世家力挺", "低")
				break

## P4-4 拍卖行派系影响：派系竞拍和资源垄断
func _月度拍卖行派系影响() -> void:
	# 每月检查一次拍卖行派系影响
	for 派系 in 派系列表:
		var 派系ID: String = str(派系.get("派系ID", ""))
		var 派系名: String = str(派系.get("名称", ""))
		
		# 高影响力派系可能垄断拍卖行资源
		if float(派系.get("影响力", 0)) > 80:
			if randf() < 0.1:
				派系争夺ID计数 += 1
				var 影响ID: String = "auc_%d" % 派系争夺ID计数
				var 影响记录: Dictionary = {
					"影响ID": 影响ID,
					"派系": 派系名,
					"类型": "资源垄断",
					"物品": "珍稀灵材",
					"效果": "垄断拍卖行珍稀灵材，其他派系满意度下降",
					"发生日": Game.累计游戏日
				}
				拍卖行派系影响记录.append(影响记录)
				
				# 其他派系满意度下降
				for 其他派系 in 派系列表:
					if str(其他派系.get("派系ID", "")) != 派系ID:
						其他派系["满意度"] = max(0, float(其他派系.get("满意度", 60)) - 3)
				
				Game._加推演条目("◇ %s囤积居奇，垄断拍卖行珍稀灵材，他派敢怒不敢言！" % 派系名, "囤积居奇", "中")

## P4-5 月度派系系统融入推演
func _月度派系系统融入() -> void:
	# 炼丹派系争夺
	_月度炼丹派系争夺()
	# 历练派系争夺
	_月度历练派系争夺()
	# 家族派系联动
	_月度家族派系联动()
	# 拍卖行派系影响
	_月度拍卖行派系影响()

## 获取炼丹派系争夺记录
func 获取炼丹派系争夺记录() -> Array:
	return 炼丹派系争夺记录

## 获取历练派系争夺记录
func 获取历练派系争夺记录() -> Array:
	return 历练派系争夺记录

## 获取家族派系联动记录
func 获取家族派系联动记录() -> Array:
	return 家族派系联动记录

## 获取拍卖行派系影响记录
func 获取拍卖行派系影响记录() -> Array:
	return 拍卖行派系影响记录
func 设置种族政策(政策: String) -> Dictionary:
	if not 种族政策效果.has(政策):
		return {"成功": false, "因": "未知政策类型"}
	宗门种族政策 = 政策
	var 配置: Dictionary = 种族政策效果[政策]
	return {"成功": true, "消息": "宗门种族政策已改为「%s」：%s" % [政策, str(配置.get("描述", ""))]}

## 获取当前种族政策效果
func 获取种族政策效果() -> Dictionary:
	return 种族政策效果.get(宗门种族政策, {})

## 获取政策修炼加成
func 获取政策修炼加成() -> float:
	var 配置: Dictionary = 获取种族政策效果()
	return float(配置.get("修炼加成", 0.0))

## 获取政策招募概率修正
func 获取政策招募概率修正() -> float:
	var 配置: Dictionary = 获取种族政策效果()
	return float(配置.get("招募概率", 0.0))


func _检查种族冲突() -> Array:
	var 冲突事件: Array = []
	var 政策配置: Dictionary = 种族政策效果.get(宗门种族政策, {})
	var 冲突概率: float = float(政策配置.get("冲突概率", 0.05))
	
	# 统计宗门内各种族弟子数量
	var 种族数量: Dictionary = {}
	for d in Game.弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		种族数量[d.种族] = int(种族数量.get(d.种族, 0)) + 1
	
	# 检查每对种族是否冲突
	var 种族列表: Array = 种族数量.keys()
	for i in range(种族列表.size()):
		for j in range(i + 1, 种族列表.size()):
			var 种族1: String = str(种族列表[i])
			var 种族2: String = str(种族列表[j])
			var 关系: int = Game.种族系统.获取种族关系(种族1, 种族2)
			# 关系越差，冲突概率越高
			var 实际冲突概率: float = 冲突概率 + (50 - 关系) * 0.001
			# 两个种族都有弟子时才可能冲突
			if int(种族数量[种族1]) > 0 and int(种族数量[种族2]) > 0:
				if randf() < 实际冲突概率:
					var 事件: Dictionary = {
						"种族1": 种族1,
						"种族2": 种族2,
						"关系": 关系,
						"严重程度": randi_range(1, 3),
						"时间": Game.累计游戏日
					}
					冲突事件.append(事件)
					Game.种族系统.种族冲突事件记录.append(事件)
					# 冲突后关系恶化
					Game.种族系统.修改种族关系(种族1, 种族2, -5)
	return 冲突事件


# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["派系列表"] = 派系列表
	data["派系关系表"] = 派系关系表
	data["宗门派系政策"] = 宗门派系政策
	data["派系更新日"] = 派系更新日
	data["宗门政策记录"] = 宗门政策记录
	data["派系联盟记录"] = 派系联盟记录
	data["派系对抗记录"] = 派系对抗记录
	data["派系分化记录"] = 派系分化记录
	data["派系事件记录"] = 派系事件记录
	data["派系事件ID计数"] = 派系事件ID计数
	data["派系斗争编年史"] = 派系斗争编年史
	data["炼丹派系争夺记录"] = 炼丹派系争夺记录
	data["历练派系争夺记录"] = 历练派系争夺记录
	data["家族派系联动记录"] = 家族派系联动记录
	data["拍卖行派系影响记录"] = 拍卖行派系影响记录
	data["派系争夺ID计数"] = 派系争夺ID计数
	data["宗门种族政策"] = 宗门种族政策
	data["种族政策效果"] = 种族政策效果
	return data

func from_dict(data: Dictionary) -> void:
	if "派系列表" in data: 派系列表 = data["派系列表"]
	if "派系关系表" in data: 派系关系表 = data["派系关系表"]
	if "宗门派系政策" in data: 宗门派系政策 = data["宗门派系政策"]
	if "派系更新日" in data: 派系更新日 = data["派系更新日"]
	if "宗门政策记录" in data: 宗门政策记录 = data["宗门政策记录"]
	if "派系联盟记录" in data: 派系联盟记录 = data["派系联盟记录"]
	if "派系对抗记录" in data: 派系对抗记录 = data["派系对抗记录"]
	if "派系分化记录" in data: 派系分化记录 = data["派系分化记录"]
	if "派系事件记录" in data: 派系事件记录 = data["派系事件记录"]
	if "派系事件ID计数" in data: 派系事件ID计数 = data["派系事件ID计数"]
	if "派系斗争编年史" in data: 派系斗争编年史 = data["派系斗争编年史"]
	if "炼丹派系争夺记录" in data: 炼丹派系争夺记录 = data["炼丹派系争夺记录"]
	if "历练派系争夺记录" in data: 历练派系争夺记录 = data["历练派系争夺记录"]
	if "家族派系联动记录" in data: 家族派系联动记录 = data["家族派系联动记录"]
	if "拍卖行派系影响记录" in data: 拍卖行派系影响记录 = data["拍卖行派系影响记录"]
	if "派系争夺ID计数" in data: 派系争夺ID计数 = data["派系争夺ID计数"]
	if "宗门种族政策" in data: 宗门种族政策 = data["宗门种族政策"]
	if "种族政策效果" in data: 种族政策效果 = data["种族政策效果"]
