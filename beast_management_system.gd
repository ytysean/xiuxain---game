class_name BeastManagementSystem extends RefCounted

# ===== 灵兽管理系统状态变量 =====
var 灵兽库存: Array[Beast] = []
var 灵兽兑换队列: Array[Dictionary] = []

# 灵兽技能配置
const 灵兽技能配置: Dictionary = {
	"攻击": [
		{"技能名": "撕咬", "描述": "对敌人造成150%攻击伤害", "解锁等级": 1},
		{"技能名": "猛扑", "描述": "对敌人造成200%攻击伤害，有30%概率眩晕", "解锁等级": 5},
		{"技能名": "狂暴", "描述": "进入狂暴状态，攻击力提升50%，持续3回合", "解锁等级": 10},
	],
	"防御": [
		{"技能名": "硬壳", "描述": "受到的伤害减少20%", "解锁等级": 1},
		{"技能名": "反击", "描述": "受到攻击时有30%概率反击", "解锁等级": 5},
		{"技能名": "铁壁", "描述": "进入防御姿态，受到的伤害减少50%，持续2回合", "解锁等级": 10},
	],
	"辅助": [
		{"技能名": "治愈", "描述": "恢复主人10%生命值", "解锁等级": 1},
		{"技能名": "净化", "描述": "清除主人身上的负面状态", "解锁等级": 5},
		{"技能名": "祝福", "描述": "提升主人全属性10%，持续3回合", "解锁等级": 10},
	],
}

# ===== 灵兽兑换 =====

func 灵兽兑换_新增(偏好: Dictionary, 经费: int) -> String:
	if 经费 <= 0:
		return "引育计划拨付经费须为正数"
	灵兽兑换队列.append({"偏好": 偏好.duplicate(true), "cost": 经费, "启用": true})
	return "已添加引育计划（单次拨付 %d 灵石）" % [经费]

func 灵兽兑换_启停(序号: int) -> String:
	if 序号 < 0 or 序号 >= 灵兽兑换队列.size():
		return "引育计划序号越界，操作已忽略"
	var 条目: Dictionary = 灵兽兑换队列[序号]
	var 新增: bool = not bool(条目.get("启用", false))
	条目["启用"] = 新增
	return "引育计划%s" % ("启用" if 新增 else "停用")

func 灵兽兑换_删除(序号: int) -> String:
	if 序号 < 0 or 序号 >= 灵兽兑换队列.size():
		return "引育计划序号越界，操作已忽略"
	灵兽兑换队列.remove_at(序号)
	return "已删除该引育计划"

# ===== 灵兽查询 =====

func 获取所有灵兽列表() -> Array:
	var 灵兽列表 = []
	for 兽 in 灵兽库存:
		if 兽 != null and not 兽.孵化中:
			灵兽列表.append({
				"种类名": 兽.种类名, "品阶": 兽.品阶, "类型": 兽.类型,
				"等级": 兽.等级, "等级上限": 兽.等级上限, "忠诚": 兽.忠诚,
				"状态": "库存", "战力": 兽.战力,
			})
	for d in Game.弟子列表:
		if d != null:
			if d.主宠灵兽 != null and not d.主宠灵兽.孵化中:
				灵兽列表.append({
					"种类名": d.主宠灵兽.种类名, "品阶": d.主宠灵兽.品阶, "类型": d.主宠灵兽.类型,
					"等级": d.主宠灵兽.等级, "等级上限": d.主宠灵兽.等级上限, "忠诚": d.主宠灵兽.忠诚,
					"状态": "主宠（%s）" % d.姓名, "战力": d.主宠灵兽.战力,
				})
			if d.副宠灵兽 != null and not d.副宠灵兽.孵化中:
				灵兽列表.append({
					"种类名": d.副宠灵兽.种类名, "品阶": d.副宠灵兽.品阶, "类型": d.副宠灵兽.类型,
					"等级": d.副宠灵兽.等级, "等级上限": d.副宠灵兽.等级上限, "忠诚": d.副宠灵兽.忠诚,
					"状态": "副宠（%s）" % d.姓名, "战力": d.副宠灵兽.战力,
				})
	return 灵兽列表

func 获取灵兽统计() -> Dictionary:
	var 库存数 = 灵兽库存.size()
	var 孵化中数 = Game.灵兽蛋列表.size()
	var 出战数 = 0
	var 总战力 = 0
	var 等级总和 = 0
	var 最高等级 = 0
	var 最高战力 = 0
	var 神兽血脉数 = 0
	var 品阶分布: Dictionary = {"fan_jie": 0, "ling_jie": 0, "bao_jie": 0, "wang_jie": 0, "sheng_jie": 0, "xian_jie": 0, "dao_jie": 0, "hun_jie": 0}
	var 类型分布: Dictionary = {"attack": 0, "defense": 0, "support": 0}
	var 所有灵兽: Array = []
	for 兽 in 灵兽库存:
		if 兽 != null:
			所有灵兽.append(兽)
	for d in Game.弟子列表:
		if d != null:
			if d.主宠灵兽 != null:
				所有灵兽.append(d.主宠灵兽)
			if d.副宠灵兽 != null:
				所有灵兽.append(d.副宠灵兽)
	for 兽 in 所有灵兽:
		if 兽 == null or 兽.孵化中:
			continue
		if 兽.is_main_pet or 兽.is_deputy_pet:
			出战数 += 1
		总战力 += 兽.本体战力()
		等级总和 += 兽.等级
		if 兽.等级 > 最高等级:
			最高等级 = 兽.等级
		if 兽.本体战力() > 最高战力:
			最高战力 = 兽.本体战力()
		if 兽.神兽血脉:
			神兽血脉数 += 1
		var 品阶: String = str(兽.品阶)
		if 品阶分布.has(品阶):
			品阶分布[品阶] = int(品阶分布[品阶]) + 1
		var 类型: String = str(兽.beast_type)
		if 类型分布.has(类型):
			类型分布[类型] = int(类型分布[类型]) + 1
	var 总数 = 所有灵兽.size()
	var 平均等级 = int(等级总和 / 总数) if 总数 > 0 else 0
	return {
		"库存数": 库存数, "孵化中数": 孵化中数, "出战数": 出战数, "总数": 总数,
		"总战力": 总战力, "平均等级": 平均等级, "最高等级": 最高等级, "最高战力": 最高战力,
		"神兽血脉数": 神兽血脉数, "品阶分布": 品阶分布, "类型分布": 类型分布,
	}

# ===== 灵兽培养与进化 =====

# ===== §4.12 灵兽培养方针（宗主定方针 → 门下按月自动培养，不逐只点）=====
# 铁则 X10「减操作不减决策」：消掉的是「逐只点培养」的劳作，
# 保留的是「投入强度 / 保谁弃谁」的宗主决策。
const 培养方针可选: Array = ["节俭", "均衡", "精进"]

## 当前培养方针（读 Game；缺省「均衡」）
func 获取培养方针() -> String:
	if not is_instance_valid(Game) or "灵兽培养方针" not in Game:
		return "均衡"
	return String(Game.灵兽培养方针)

## 设置培养方针（UI 调用；写在 Game 上，随存档持久化）
func 设置培养方针(方针: String) -> Dictionary:
	if 方针 not in 培养方针可选:
		return {"成功": false, "原因": "未知培养方针（节俭/均衡/精进）"}
	if not is_instance_valid(Game):
		return {"成功": false, "原因": "宗门天机未定，稍后再观"}
	Game.灵兽培养方针 = 方针
	Game.添加纪事("御兽", "培养方针", "宗主定下灵兽培养方针为【%s】，门下将按月照此培养。" % 方针, 1)
	return {"成功": true, "方针": 方针, "消息": "培养方针已设为【%s】" % 方针}

## 各方针的执行参数：每兽月升几级 / 宗门灵石留存线 / 覆盖比例（<1＝只养强者）
static func _培养方针参数(方针: String) -> Dictionary:
	match 方针:
		"节俭":
			return {"每兽级数": 1, "灵石留存": 3000, "覆盖比例": 1.0}
		"精进":
			return {"每兽级数": 2, "灵石留存": 0, "覆盖比例": 0.5}
		_:
			return {"每兽级数": 1, "灵石留存": 0, "覆盖比例": 1.0}

## 按当前方针培养一次（「催办」＝一键执行已定方针，§2.0 唯一合法的一键形态）
func 按方针培养灵兽() -> Dictionary:
	var 方针: String = 获取培养方针()
	var 参数: Dictionary = _培养方针参数(方针)
	var 每兽级数: int = int(参数["每兽级数"])
	var 留存: int = int(参数["灵石留存"])
	var 覆盖比例: float = float(参数["覆盖比例"])

	var 候选: Array = []
	for 兽 in 灵兽库存:
		if 兽 != null and not 兽.孵化中 and 兽.等级 < 兽.等级上限:
			候选.append(兽)
	# 精进：只养战力较高的一半（强者优先，体现宗主取舍）
	if 覆盖比例 < 1.0 and 候选.size() > 1:
		候选.sort_custom(func(a, b): return int(a.本体战力()) > int(b.本体战力()))
		候选 = 候选.slice(0, max(1, int(ceil(候选.size() * 覆盖比例))))

	var 培养数量: int = 0
	var 消耗灵石: int = 0
	for 兽 in 候选:
		for _i in range(每兽级数):
			if 兽.等级 >= 兽.等级上限:
				break
			var 消耗: int = 100 * 兽.等级
			if Game.灵石 - 留存 < 消耗:
				break
			Game.灵石 -= 消耗
			兽.等级 = min(兽.等级 + 1, 兽.等级上限)
			兽.忠诚 = min(兽.忠诚 + 5, 100)
			消耗灵石 += 消耗
		培养数量 += 1
	return {"成功": 培养数量 > 0, "培养数量": 培养数量, "消耗灵石": 消耗灵石, "方针": 方针,
		"消息": "依【%s】方针培养灵兽%d只，耗灵石%d" % [方针, 培养数量, 消耗灵石]}

## 月度自动培养（由 game_state 月度钩子 _月度自动培养灵兽 调用）
func 月度自动培养灵兽() -> Dictionary:
	return 按方针培养灵兽()

## 兼容旧入口：语义已改为「按当前方针催办一次」，不再是无策略的一键
func 一键培养灵兽() -> Dictionary:
	return 按方针培养灵兽()

func 获取灵兽技能列表(灵兽类型: String, 灵兽等级: int) -> Array:
	var 技能列表 = []
	var 类型映射 = {"attack": "攻击", "defense": "防御", "support": "辅助"}
	var 配置类型 = 类型映射.get(灵兽类型, 灵兽类型)
	var 类型技能 = 灵兽技能配置.get(配置类型, [])
	for 技能 in 类型技能:
		if 灵兽等级 >= int(技能.get("解锁等级", 1)):
			技能列表.append({"技能名": 技能.get("技能名", ""), "描述": 技能.get("描述", ""), "解锁等级": 技能.get("解锁等级", 1), "已解锁": true})
		else:
			技能列表.append({"技能名": 技能.get("技能名", ""), "描述": 技能.get("描述", ""), "解锁等级": 技能.get("解锁等级", 1), "已解锁": false})
	return 技能列表

func 灵兽进化(灵兽索引: int) -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {"成功": false, "原因": "灵兽不存在"}
	var 兽 = 灵兽库存[灵兽索引]
	if 兽 == null or 兽.孵化中:
		return {"成功": false, "原因": "灵兽未孵化"}
	var 品阶列表 = ["fan_jie", "ling_jie", "bao_jie", "wang_jie", "sheng_jie", "xian_jie", "dao_jie", "hun_jie"]
	var 品阶显示 = {"fan_jie": "凡阶", "ling_jie": "灵阶", "bao_jie": "宝阶", "wang_jie": "王阶", "sheng_jie": "圣阶", "xian_jie": "仙阶", "dao_jie": "道阶", "hun_jie": "混沌阶"}
	var 当前品阶索引 = 品阶列表.find(兽.品阶)
	if 当前品阶索引 < 0 or 当前品阶索引 >= 品阶列表.size() - 1:
		return {"成功": false, "原因": "灵兽已达最高品阶"}
	if 兽.等级 < 兽.等级上限:
		return {"成功": false, "原因": "灵兽品级未达上限（需%d品）" % 兽.等级上限}
	var 消耗灵石 = 5000 * (当前品阶索引 + 1)
	var 消耗灵草 = 100 * (当前品阶索引 + 1)
	if Game.灵石 < 消耗灵石:
		return {"成功": false, "原因": "灵石不足（需%d灵石）" % 消耗灵石}
	if Game.灵草 < 消耗灵草:
		return {"成功": false, "原因": "灵草不足（需%d灵草）" % 消耗灵草}
	Game.灵石 -= 消耗灵石
	Game.灵草 -= 消耗灵草
	var 新品阶 = 品阶列表[当前品阶索引 + 1]
	var 新品阶显示 = 品阶显示.get(新品阶, 新品阶)
	兽.品阶 = 新品阶
	var 新品阶上限 = {"fan_jie": 10, "ling_jie": 20, "bao_jie": 30, "wang_jie": 40, "sheng_jie": 50, "xian_jie": 60, "dao_jie": 80, "hun_jie": 100}
	兽.等级上限 = 新品阶上限.get(新品阶, 兽.等级上限 + 10)
	兽.等级 = 1
	兽._滚技能()
	Game.添加纪事("庶务", "灵兽进化", "%s进化为%s，品级上限提升至%d" % [兽.种类名, 新品阶显示, 兽.等级上限], 1)
	return {"成功": true, "灵兽": 兽, "新品阶": 新品阶, "新品阶显示": 新品阶显示, "消耗灵石": 消耗灵石, "消耗灵草": 消耗灵草, "消息": "%s进化为%s成功" % [兽.种类名, 新品阶显示]}

func 获取灵兽进化消耗(灵兽索引: int) -> Dictionary:
	if 灵兽索引 < 0 or 灵兽索引 >= 灵兽库存.size():
		return {}
	var 兽 = 灵兽库存[灵兽索引]
	if 兽 == null:
		return {}
	var 品阶列表 = ["fan_jie", "ling_jie", "bao_jie", "wang_jie", "sheng_jie", "xian_jie", "dao_jie", "hun_jie"]
	var 品阶显示 = {"fan_jie": "凡阶", "ling_jie": "灵阶", "bao_jie": "宝阶", "wang_jie": "王阶", "sheng_jie": "圣阶", "xian_jie": "仙阶", "dao_jie": "道阶", "hun_jie": "混沌阶"}
	var 新品阶上限 = {"fan_jie": 10, "ling_jie": 20, "bao_jie": 30, "wang_jie": 40, "sheng_jie": 50, "xian_jie": 60, "dao_jie": 80, "hun_jie": 100}
	var 当前品阶索引 = 品阶列表.find(兽.品阶)
	var 新品阶 = 品阶列表[当前品阶索引 + 1] if 当前品阶索引 >= 0 and 当前品阶索引 < 品阶列表.size() - 1 else ""
	return {
		"当前品阶": 兽.品阶, "当前品阶显示": 品阶显示.get(兽.品阶, 兽.品阶),
		"当前等级": 兽.等级, "等级上限": 兽.等级上限,
		"是否可进化": 兽.等级 >= 兽.等级上限 and 当前品阶索引 >= 0 and 当前品阶索引 < 品阶列表.size() - 1,
		"进化消耗灵石": 5000 * (当前品阶索引 + 1) if 当前品阶索引 >= 0 else 0,
		"进化消耗灵草": 100 * (当前品阶索引 + 1) if 当前品阶索引 >= 0 else 0,
		"进化后品阶": 新品阶, "进化后品阶显示": 品阶显示.get(新品阶, "最高品阶"),
		"进化后等级上限": 新品阶上限.get(新品阶, 兽.等级上限 + 10),
	}

# ===== 灵兽出战绑定 =====

func 出战灵兽月度养成():
	for d in Game.弟子列表:
		for 兽 in [d.主宠灵兽, d.副宠灵兽]:
			if 兽 == null or 兽.孵化中:
				continue
			兽.等级 = min(兽.等级 + 1, 兽.等级上限)
			兽.忠诚 = min(兽.忠诚 + 2, 100)
	for 兽 in 灵兽库存:
		if 兽.孵化中:
			continue
		兽.忠诚 = max(兽.忠诚 - 1, 0)

func 绑定灵兽给首只合体(灵兽: Beast) -> String:
	for d in Game.弟子列表:
		if d.主宠灵兽 != null:
			continue
		if (d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
			continue
		return 绑定灵兽给指定弟子(灵兽, d)
	return Game.文案表["beast_no_bindable"]

func 绑定灵兽给指定弟子(灵兽: Beast, 弟子: Disciple, 槽位: String = "主宠") -> String:
	if 槽位 == "副宠" and 弟子.副宠灵兽 != null:
		return "%s】已绑定副宠灵兽" % [弟子.姓名]
	if 槽位 != "副宠" and 弟子.主宠灵兽 != null:
		return "%s】已绑定主宠灵兽" % [弟子.姓名]
	if (弟子.资质 == "fan_su" or 弟子.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
		return "%s】资质过低，仅能携带灵阶灵兽" % [弟子.姓名]
	if 槽位 == "副宠":
		弟子.副宠灵兽 = 灵兽
		灵兽.设为副宠()
	else:
		弟子.主宠灵兽 = 灵兽
		灵兽.设为主宠()
	灵兽库存.erase(灵兽)
	Game.弟子变动.emit()
	return "%s】已绑定灵兽%s】（%s）" % [弟子.姓名, 灵兽.种类名, Beast.类型中文.get(灵兽.beast_type, "")]

func 解绑灵兽(弟子: Disciple, 槽位: String) -> String:
	var 兽: Beast = null
	if 槽位 == "副宠":
		兽 = 弟子.副宠灵兽
		弟子.副宠灵兽 = null
	else:
		兽 = 弟子.主宠灵兽
		弟子.主宠灵兽 = null
	if 兽 != null:
		兽.取消出战()
		if not 灵兽库存.has(兽):
			灵兽库存.append(兽)
	Game.弟子变动.emit()
	return Game.文案表["beast_contract_released"] % [弟子.姓名, ("副宠" if 槽位 == "副宠" else "主宠")]

# 序列化
func to_dict() -> Dictionary:
	return {
		"灵兽库存": 灵兽库存,
		"灵兽兑换队列": 灵兽兑换队列,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	# typed array 不可被 data.get() 的 Variant 直接重赋（运行期类型不匹配）→ clear + 循环 append
	灵兽库存.clear()
	for it in data.get("灵兽库存", []):
		if it is Beast:
			灵兽库存.append(it)
	灵兽兑换队列.clear()
	for it2 in data.get("灵兽兑换队列", []):
		if it2 is Dictionary:
			灵兽兑换队列.append(it2)
