class_name MarriageSystem extends RefCounted

# ===== 通婚和子嗣系统状态变量 =====
var 子嗣列表: Array = []              # 子嗣列表（未加入宗门的幼年/少年子嗣）
var 通婚记录详细: Array = []          # 详细通婚记录
var 生育冷却记录: Dictionary = {}     # 生育冷却记录（{道侣组合ID: 冷却天数}）
var 子嗣ID计数: int = 0               # 子嗣ID计数器

func 检查通婚可行性(弟子1: Disciple, 弟子2: Disciple) -> Dictionary:
	if 弟子1 == null or 弟子2 == null:
		return {"可行": false, "因": "弟子为空"}
	if 弟子1.道侣 != "" or 弟子2.道侣 != "":
		return {"可行": false, "因": "已有道侣"}
	if 弟子1.境界 not in ["金丹", "元婴", "化神", "炼虚", "合体", "大乘"]:
		return {"可行": false, "因": "境界不足（需金丹以上）"}
	if 弟子2.境界 not in ["金丹", "元婴", "化神", "炼虚", "合体", "大乘"]:
		return {"可行": false, "因": "境界不足（需金丹以上）"}
	
	# 必须先成为道友（好感度>=80）
	if not 弟子1.是道友(str(弟子2.弟子ID)):
		var 好感度1: int = 弟子1.获取好感度(str(弟子2.弟子ID))
		var 好感度2: int = 弟子2.获取好感度(str(弟子1.弟子ID))
		if 好感度1 < 80 or 好感度2 < 80:
			return {"可行": false, "因": "好感度不足（需双方>=80先结为道友，当前%d/%d）" % [好感度1, 好感度2]}
	
	# 好感度>=90才能结成道侣
	var 好感度1: int = 弟子1.获取好感度(str(弟子2.弟子ID))
	var 好感度2: int = 弟子2.获取好感度(str(弟子1.弟子ID))
	if 好感度1 < 90 or 好感度2 < 90:
		return {"可行": false, "因": "好感度不足（需双方>=90才能结成道侣，当前%d/%d）" % [好感度1, 好感度2]}
	
	var key1: String = "%s-%s" % [弟子1.种族, 弟子2.种族]
	var key2: String = "%s-%s" % [弟子2.种族, 弟子1.种族]
	var 配置: Dictionary = {}
	if Game.通婚可行性.has(key1):
		配置 = Game.通婚可行性[key1]
	elif Game.通婚可行性.has(key2):
		配置 = Game.通婚可行性[key2]
	else:
		return {"可行": false, "因": "种族不可通婚"}
	
	if not bool(配置.get("可行", false)):
		return {"可行": false, "因": "种族不可通婚"}
	
	# 检查特殊条件
	var 条件: Dictionary = 配置.get("条件", {})
	if 条件.get("妖族需化形", false):
		var 妖族弟子: Disciple = 弟子1 if 弟子1.种族 == "妖族" else 弟子2
		if 妖族弟子.化形状态 != "已化形":
			return {"可行": false, "因": "妖族需先化形才能通婚"}
	
	return {"可行": true, "好感度": min(好感度1, 好感度2), "配置": 配置}

## 执行联姻（结为道侣，基于好感度）
func 执行通婚(弟子1: Disciple, 弟子2: Disciple) -> Dictionary:
	var 检查: Dictionary = 检查通婚可行性(弟子1, 弟子2)
	if not bool(检查.get("可行", false)):
		return {"成功": false, "因": str(检查.get("因", ""))}
	
	# 基于好感度判定通婚成功率（好感度越高成功率越高）
	var 好感度: int = int(检查.get("好感度", 90))
	var 成功率: float = 0.3 + (好感度 - 90) * 0.05  # 90好感=30%，100好感=80%
	成功率 = clamp(成功率, 0.3, 0.8)
	
	if randf() > 成功率:
		return {"成功": false, "因": "通婚失败，缘分未到（好感度%d，成功率%.0f%%）" % [好感度, 成功率 * 100]}
	
	# 通婚成功
	弟子1.道侣 = 弟子2.姓名
	弟子2.道侣 = 弟子1.姓名
	
	# 记录通婚
	var 通婚ID: String = "marry_%d" % randi()
	var 记录: Dictionary = {
		"通婚ID": 通婚ID,
		"父方ID": 弟子1.弟子ID,
		"母方ID": 弟子2.弟子ID,
		"父方名": 弟子1.姓名,
		"母方名": 弟子2.姓名,
		"父方种族": 弟子1.种族,
		"母方种族": 弟子2.种族,
		"好感度": 好感度,
		"时间": Game.累计游戏日,
		"子嗣数量": 0
	}
	通婚记录详细.append(记录)
	Game.种族系统.种族通婚记录.append(记录)
	
	# 通婚改善种族关系
	Game.种族系统.修改种族关系(弟子1.种族, 弟子2.种族, 10)
	# 通婚后好感度+5
	弟子1.增加好感度(str(弟子2.弟子ID), 5)
	弟子2.增加好感度(str(弟子1.弟子ID), 5)
	
	return {"成功": true, "消息": "%s与%s结为道侣！（好感度%d）" % [弟子1.姓名, 弟子2.姓名, 好感度], "记录": 记录}

## 检查是否可添丁
func 检查生育可行性(父方: Disciple, 母方: Disciple) -> Dictionary:
	if 父方 == null or 母方 == null:
		return {"可行": false, "因": "弟子为空"}
	if 父方.道侣 != 母方.姓名 or 母方.道侣 != 父方.姓名:
		return {"可行": false, "因": "不是道侣"}
	
	# 检查子嗣数量
	var 道侣组合ID: String = "%s_%s" % [父方.弟子ID, 母方.弟子ID]
	var 已有子嗣: int = 0
	for 子嗣 in 子嗣列表:
		if str(子嗣.get("父方ID", "")) == str(父方.弟子ID) and str(子嗣.get("母方ID", "")) == str(母方.弟子ID):
			已有子嗣 += 1
	if 已有子嗣 >= 3:
		return {"可行": false, "因": "已达子嗣上限（3个）"}
	
	# 检查生育冷却
	if 生育冷却记录.has(道侣组合ID):
		if float(生育冷却记录[道侣组合ID]) > 0:
			return {"可行": false, "因": "生育冷却中（%.0f天）" % float(生育冷却记录[道侣组合ID])}
	
	# 高龄生育惩罚
	var 生育概率: float = 0.15
	if 母方.年龄 > 100:
		生育概率 *= 0.5
	# 龙族/鬼族生育概率更低
	if 母方.种族 == "龙族" or 母方.种族 == "鬼族":
		生育概率 *= 0.5
	
	return {"可行": true, "概率": 生育概率, "道侣组合ID": 道侣组合ID}

## 生成子嗣
func 生成子嗣(父方: Disciple, 母方: Disciple) -> Dictionary:
	var 检查: Dictionary = 检查生育可行性(父方, 母方)
	if not bool(检查.get("可行", false)):
		return {"成功": false, "因": str(检查.get("因", ""))}
	
	if randf() > float(检查.get("概率", 0.15)):
		return {"成功": false, "因": "未能成功受孕"}
	
	# 生成子嗣ID
	子嗣ID计数 += 1
	var 子嗣ID: String = "child_%d" % 子嗣ID计数
	
	# 判定子嗣种族
	var 子嗣种族: String = _判定子嗣种族(父方, 母方)
	# 判定子嗣血脉
	var 子嗣血脉: Dictionary = _判定子嗣血脉(父方, 母方, 子嗣种族)
	# 判定子嗣品质
	var 品质: String = _判定子嗣品质(父方, 母方)
	# 继承天赋
	var 天赋列表: Array = _继承天赋(父方, 母方, 子嗣种族)
	
	# 生成子嗣名字（简化）
	var 名字列表: Array = ["玄", "清", "灵", "天", "道", "剑", "丹", "阵", "符", "宝"]
	var 子嗣名: String = 名字列表[randi() % 名字列表.size()] + 名字列表[randi() % 名字列表.size()]
	
	# 继承属性
	var 灵根品阶: String = _继承灵根品阶(父方, 母方, 品质)
	var 资质: String = _继承资质(父方, 母方, 品质)
	
	var 子嗣: Dictionary = {
		"子嗣ID": 子嗣ID,
		"姓名": 子嗣名,
		"种族": 子嗣种族,
		"血脉类型": str(子嗣血脉.get("血脉类型", "凡人血脉")),
		"混血": bool(子嗣血脉.get("混血", false)),
		"返祖": bool(子嗣血脉.get("返祖", false)),
		"血脉冲突": bool(子嗣血脉.get("血脉冲突", false)),
		"品质": 品质,
		"父方ID": 父方.弟子ID,
		"母方ID": 母方.弟子ID,
		"父方名": 父方.姓名,
		"母方名": 母方.姓名,
		"年龄": 0,
		"成长阶段": "幼年",
		"天赋列表": 天赋列表,
		"灵根品阶": 灵根品阶,
		"资质": 资质,
		"特殊特征": str(子嗣血脉.get("特殊特征", "")),
		"出生时间": Game.累计游戏日
	}
	
	子嗣列表.append(子嗣)
	
	# 设置生育冷却（2年=730天）
	var 道侣组合ID: String = str(检查.get("道侣组合ID", ""))
	生育冷却记录[道侣组合ID] = 730.0
	
	# 更新通婚记录子嗣数量
	for 记录 in 通婚记录详细:
		if (str(记录.get("父方ID", "")) == str(父方.弟子ID) and str(记录.get("母方ID", "")) == str(母方.弟子ID)) or \
		   (str(记录.get("父方ID", "")) == str(母方.弟子ID) and str(记录.get("母方ID", "")) == str(父方.弟子ID)):
			记录["子嗣数量"] = int(记录.get("子嗣数量", 0)) + 1
			break
	
	var 消息: String = "%s与%s诞下一子：%s（%s，%s）！" % [父方.姓名, 母方.姓名, 子嗣名, 子嗣种族, 品质]
	if bool(子嗣血脉.get("返祖", false)):
		消息 += " ★返祖现象！"
	elif bool(子嗣血脉.get("混血", false)):
		消息 += " 混血子嗣！"
	
	return {"成功": true, "消息": 消息, "子嗣": 子嗣}

## 判定子嗣种族
func _判定子嗣种族(父方: Disciple, 母方: Disciple) -> String:
	# 同族通婚：100%为该种族
	if 父方.种族 == 母方.种族:
		return 父方.种族
	
	# 特殊组合判定
	if (父方.种族 == "人族" and 母方.种族 == "龙族") or (父方.种族 == "龙族" and 母方.种族 == "人族"):
		return "龙族" if randf() < 0.2 else "人族"
	if (父方.种族 == "人族" and 母方.种族 == "妖族") or (父方.种族 == "妖族" and 母方.种族 == "人族"):
		return "妖族" if randf() < 0.3 else "人族"
	if (父方.种族 == "魔族" and 母方.种族 == "鬼族") or (父方.种族 == "鬼族" and 母方.种族 == "魔族"):
		return "魔族" if randf() < 0.5 else "鬼族"
	
	# 通用：60%父方，40%母方
	return 父方.种族 if randf() < 0.6 else 母方.种族

## 判定子嗣血脉（纯血/混血/返祖/血脉冲突）
func _判定子嗣血脉(父方: Disciple, 母方: Disciple, 子嗣种族: String) -> Dictionary:
	var 结果: Dictionary = {"血脉类型": "凡人血脉", "混血": false, "返祖": false, "血脉冲突": false, "特殊特征": ""}
	
	# 同族通婚：纯血
	if 父方.种族 == 母方.种族:
		结果["血脉类型"] = 父方.血脉类型 if 父方.血脉类型 != "凡人血脉" else 母方.血脉类型
		return 结果
	
	# 异族通婚：血脉判定
	var rand: float = randf()
	if rand < 0.005:
		# 血脉冲突（0.5%）
		结果["血脉冲突"] = true
		结果["特殊特征"] = "血脉冲突：修炼速度-30%，突破成功率+20%"
	elif rand < 0.02:
		# 返祖（1.5%）
		结果["返祖"] = true
		结果["血脉类型"] = "太古血脉"
		结果["特殊特征"] = "返祖：全属性+15%"
	elif rand < 0.10:
		# 深混血（8%）
		结果["混血"] = true
		结果["血脉类型"] = 母方.血脉类型 if 子嗣种族 == 父方.种族 else 父方.血脉类型
		结果["特殊特征"] = "深混血：获得2个异族天赋，修炼速度-10%，道行+10%"
	elif rand < 0.30:
		# 浅混血（20%）
		结果["混血"] = true
		结果["血脉类型"] = 母方.血脉类型 if 子嗣种族 == 父方.种族 else 父方.血脉类型
		结果["特殊特征"] = "浅混血：获得1个异族天赋，修炼速度-5%"
	else:
		# 纯血（70%）
		结果["血脉类型"] = 父方.血脉类型 if 子嗣种族 == 父方.种族 else 母方.血脉类型
	
	# 特殊种族特征
	if 子嗣种族 == "人族" and (父方.种族 == "魔族" or 母方.种族 == "魔族"):
		if randf() < 0.5:
			结果["特殊特征"] += " 有魔性：修炼速度+10%，心魔值+20，走火入魔概率+5%"
	if 子嗣种族 == "人族" and (父方.种族 == "鬼族" or 母方.种族 == "鬼族"):
		结果["特殊特征"] += " 半阴之体：物理免疫20%，怕雷系+30%，阴气修炼+15%"
	if 子嗣种族 == "人族" and (父方.种族 == "妖族" or 母方.种族 == "妖族"):
		结果["特殊特征"] += " 妖族特征：保留部分妖族特征（狐耳/龙角等）"
	
	return 结果

## 判定子嗣品质（凡品/良品/上品/极品/天品）
func _判定子嗣品质(父方: Disciple, 母方: Disciple) -> String:
	var rand: float = randf()
	# 父母品质加成（简化：境界越高，高品质概率越高）
	var 品质加成: float = 0.0
	if 父方.境界 in ["化神", "炼虚", "合体", "大乘"]:
		品质加成 += 0.05
	if 母方.境界 in ["化神", "炼虚", "合体", "大乘"]:
		品质加成 += 0.05
	
	if rand < 0.01 + 品质加成 * 0.5:
		return "天品"
	elif rand < 0.05 + 品质加成:
		return "极品"
	elif rand < 0.20 + 品质加成 * 0.5:
		return "上品"
	elif rand < 0.50:
		return "良品"
	else:
		return "凡品"

## 继承天赋（父方40%+母方40%+随机20%）
func _继承天赋(父方: Disciple, 母方: Disciple, 子嗣种族: String) -> Array:
	var 天赋列表: Array = []
	# 最多继承3个天赋
	var 继承数量: int = randi_range(1, 3)
	
	for i in range(继承数量):
		var rand: float = randf()
		if rand < 0.4 and 父方.种族天赋.size() > 0:
			# 继承父方天赋
			var 天赋: Dictionary = 父方.种族天赋[randi() % 父方.种族天赋.size()]
			if not 天赋列表.has(天赋):
				天赋列表.append(天赋)
		elif rand < 0.8 and 母方.种族天赋.size() > 0:
			# 继承母方天赋
			var 天赋: Dictionary = 母方.种族天赋[randi() % 母方.种族天赋.size()]
			if not 天赋列表.has(天赋):
				天赋列表.append(天赋)
		else:
			# 随机天赋
			var 种族天赋: Dictionary = Game.种族系统.获取种族天赋配置(子嗣种族, "")
			if 种族天赋.size() > 0:
				天赋列表.append(种族天赋)
	
	return 天赋列表

## 继承灵根品阶
func _继承灵根品阶(父方: Disciple, 母方: Disciple, 品质: String) -> String:
	var 品阶列表: Array = ["凡品", "良品", "上品", "极品", "天品"]
	var 父方索引: int = 品阶列表.find(父方.灵根品阶) if 品阶列表.has(父方.灵根品阶) else 0
	var 母方索引: int = 品阶列表.find(母方.灵根品阶) if 品阶列表.has(母方.灵根品阶) else 0
	var 较高索引: int = max(父方索引, 母方索引)
	
	# 10%概率提升1阶，5%概率降低1阶
	var 偏移: int = 0
	var rand: float = randf()
	if rand < 0.10:
		偏移 = 1
	elif rand < 0.15:
		偏移 = -1
	
	# 品质加成
	match 品质:
		"天品": 偏移 += 2
		"极品": 偏移 += 1
		"上品": 偏移 += 0
	
	var 最终索引: int = clamp(较高索引 + 偏移, 0, 品阶列表.size() - 1)
	return str(品阶列表[最终索引])

## 继承资质
func _继承资质(父方: Disciple, 母方: Disciple, 品质: String) -> String:
	var 资质列表: Array = ["fan_su", "pingyong", "youliang", "tiancai", "yaonie", "kuangshi"]
	# 简化：取父母平均值±20%随机波动
	var 父方索引: int = 资质列表.find(父方.资质) if 资质列表.has(父方.资质) else 1
	var 母方索引: int = 资质列表.find(母方.资质) if 资质列表.has(母方.资质) else 1
	var 平均索引: int = int((父方索引 + 母方索引) / 2)
	var 偏移: int = randi_range(-1, 1)
	
	# 品质加成
	match 品质:
		"天品": 偏移 += 2
		"极品": 偏移 += 1
		"上品": 偏移 += 0
	
	var 最终索引: int = clamp(平均索引 + 偏移, 0, 资质列表.size() - 1)
	return str(资质列表[最终索引])

## 子嗣成长推进（月度）
func _子嗣成长推进() -> void:
	var 成年子嗣: Array = []
	for 子嗣 in 子嗣列表:
		子嗣["年龄"] = int(子嗣.get("年龄", 0)) + 1
		var 年龄: int = int(子嗣.get("年龄", 0))
		
		# 成长阶段判定
		if 年龄 >= 15 and str(子嗣.get("成长阶段", "")) != "成年":
			子嗣["成长阶段"] = "成年"
			成年子嗣.append(子嗣)
		elif 年龄 >= 10 and str(子嗣.get("成长阶段", "")) == "幼年":
			子嗣["成长阶段"] = "少年"
	
	# 成年子嗣自动加入宗门
	for 子嗣 in 成年子嗣:
		var 结果: Dictionary = _子嗣加入宗门(子嗣)
		if bool(结果.get("成功", false)):
			Game._加推演条目("◆ %s成年，加入宗门成为%s！" % [str(子嗣.get("姓名", "")), str(结果.get("身份", "外门弟子"))], "子嗣成年", "高")
			子嗣列表.erase(子嗣)

## 子嗣加入宗门
func _子嗣加入宗门(子嗣: Dictionary) -> Dictionary:
	# 创建新弟子
	var 新弟子: Disciple = Disciple.new()
	新弟子.姓名 = str(子嗣.get("姓名", ""))
	新弟子.种族 = str(子嗣.get("种族", "人族"))
	新弟子.血脉类型 = str(子嗣.get("血脉类型", "凡人血脉"))
	新弟子.灵根品阶 = str(子嗣.get("灵根品阶", "凡品"))
	新弟子.资质 = str(子嗣.get("资质", "pingyong"))
	新弟子.种族天赋 = 子嗣.get("天赋列表", [])
	新弟子.年龄 = 15
	
	# 根据品质决定初始身份
	var 身份: String = "外门弟子"
	match str(子嗣.get("品质", "凡品")):
		"上品": 身份 = "内门弟子"
		"极品": 身份 = "核心弟子"
		"天品": 身份 = "亲传弟子"
	新弟子.身份 = 身份
	
	# 初始化
	新弟子.基础修炼速度 = 新弟子._基础修炼速度值()
	新弟子.修炼速度 = 新弟子.基础修炼速度 * 新弟子.总修炼速度倍率()
	新弟子.战力 = 新弟子.计算战力()
	
	Game.弟子列表.append(新弟子)
	Game.累计招募弟子数 += 1
	Game.弟子变动.emit()
	
	return {"成功": true, "弟子": 新弟子, "身份": 身份}

## 月度好感度增长（门下弟子自然增进情谊）
func _月度好感度增长() -> void:
	var 在宗弟子: Array = []
	for d in Game.弟子列表:
		if d != null and (d is Disciple) and d.状态 == "在宗":
			在宗弟子.append(d)
	
	# 每对弟子之间自然增长好感度
	for i in range(在宗弟子.size()):
		for j in range(i + 1, 在宗弟子.size()):
			var d1: Disciple = 在宗弟子[i]
			var d2: Disciple = 在宗弟子[j]
			
			# 计算好感度增长速率
			var 速率: float = d1.获取好感度增长速率(d2)
			
			# 已经是道侣的增长更快
			if d1.道侣 == d2.姓名:
				速率 *= 2.0
			# 已经是道友的增长稍快
			elif d1.是道友(str(d2.弟子ID)):
				速率 *= 1.5
			
			# 好感度越高增长越慢（边际递减）
			var 当前好感度: int = d1.获取好感度(str(d2.弟子ID))
			if 当前好感度 > 80:
				速率 *= 0.5
			elif 当前好感度 > 60:
				速率 *= 0.8
			
			# 增长好感度（双向）
			var 增量: int = int(速率)
			if 增量 > 0:
				d1.增加好感度(str(d2.弟子ID), 增量)
				d2.增加好感度(str(d1.弟子ID), 增量)

## 月度检查义结金兰（好感度>=80自动结为道友）
func _月度检查结成道友() -> void:
	var 在宗弟子: Array = []
	for d in Game.弟子列表:
		if d != null and (d is Disciple) and d.状态 == "在宗":
			在宗弟子.append(d)
	
	for i in range(在宗弟子.size()):
		for j in range(i + 1, 在宗弟子.size()):
			var d1: Disciple = 在宗弟子[i]
			var d2: Disciple = 在宗弟子[j]
			
			# 检查是否可以结成道友
			if d1.可以结成道友(d2):
				# 20%概率结成道友（避免一次性全部结成）
				if randf() < 0.2:
					var 结果: Dictionary = d1.结成道友(d2)
					if bool(结果.get("成功", false)):
						Game._加推演条目("◇ " + str(结果.get("消息", "")), "义结金兰", "中")

## 月度联姻与添丁检查（基于好感度）
func _月度通婚生育检查() -> void:
	# 月度好感度增长
	_月度好感度增长()
	# 月度检查结成道友
	_月度检查结成道友()
	# 检查适婚弟子（好感度>=90且已是道友）
	var 适婚弟子: Array = []
	for d in Game.弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗":
			continue
		if d.境界 in ["金丹", "元婴", "化神", "炼虚", "合体", "大乘"] and d.道侣 == "":
			适婚弟子.append(d)
	# 检查道友之间是否可以结成道侣（好感度>=90）
	for i in range(适婚弟子.size()):
		for j in range(i + 1, 适婚弟子.size()):
			var d1: Disciple = 适婚弟子[i]
			var d2: Disciple = 适婚弟子[j]
			# 必须是道友且好感度>=90
			if not d1.是道友(str(d2.弟子ID)):
				continue
			var 好感度1: int = d1.获取好感度(str(d2.弟子ID))
			var 好感度2: int = d2.获取好感度(str(d1.弟子ID))
			if 好感度1 < 90 or 好感度2 < 90:
				continue
			# 检查通婚可行性
			var 检查: Dictionary = 检查通婚可行性(d1, d2)
			if not bool(检查.get("可行", false)):
				continue
			# 10%概率尝试通婚（基于好感度）
			if randf() < 0.1:
				var 结果: Dictionary = 执行通婚(d1, d2)
				if bool(结果.get("成功", false)):
					Game._加推演条目("★ " + str(结果.get("消息", "")), "缔结道侣", "高")
	# 检查已有道侣的生育
	for d in Game.弟子列表:
		if d == null or not (d is Disciple) or d.状态 != "在宗" or d.道侣 == "":
			continue
		# 找到道侣
		var 道侣: Disciple = null
		for d2 in Game.弟子列表:
			if d2 != null and (d2 is Disciple) and d2.姓名 == d.道侣:
				道侣 = d2
				break
		if 道侣 == null:
			continue
		# 每对道侣只检查一次（父方检查）
		if d.弟子ID > 道侣.弟子ID:
			continue
		# 生育概率基于好感度（好感度越高概率越高）
		var 好感度: int = d.获取好感度(str(道侣.弟子ID))
		var 生育概率: float = 0.03 + (好感度 - 90) * 0.005  # 90好感=3%，100好感=8%
		生育概率 = clamp(生育概率, 0.03, 0.1)
		if randf() < 生育概率:
			var 结果: Dictionary = 生成子嗣(d, 道侣)
			if bool(结果.get("成功", false)):
				Game._加推演条目("◇ " + str(结果.get("消息", "")), "添丁进口", "高")
	# 生育冷却递减
	for key in 生育冷却记录:
		生育冷却记录[key] = max(0, float(生育冷却记录[key]) - 30)
	# 子嗣成长推进
	_子嗣成长推进()

# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["子嗣列表"] = 子嗣列表
	data["通婚记录详细"] = 通婚记录详细
	data["生育冷却记录"] = 生育冷却记录
	data["子嗣ID计数"] = 子嗣ID计数
	return data

func from_dict(data: Dictionary) -> void:
	if "子嗣列表" in data: 子嗣列表 = data["子嗣列表"]
	if "通婚记录详细" in data: 通婚记录详细 = data["通婚记录详细"]
	if "生育冷却记录" in data: 生育冷却记录 = data["生育冷却记录"]
	if "子嗣ID计数" in data: 子嗣ID计数 = data["子嗣ID计数"]
