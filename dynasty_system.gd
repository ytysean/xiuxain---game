class_name DynastySystem extends RefCounted

# ===== 凡人王朝系统状态变量 =====
var 王朝: Dictionary = {}                # 王朝实体（GDD §4.1）
var 凡间差事榜: Dictionary = {}          # 差事ID → 差事字典
var 凡间差事进行中: Dictionary = {}      # 差事ID → 差事字典（已接取，按日倒计时到期结算）
var _王朝配置缓存: Array = []            # config/dynasty_config.csv 行缓存（懒加载，不入存档）
var _王朝阶段缓存: Array = []            # config/dynasty_phase_config.csv 行缓存（懒加载）
var _差事模板缓存: Array = []
var 郡县状态: Dictionary = {}            # city_id → 郡县运行时状态（忠顺/感恩/灾情）
var 郡信仰: Dictionary = {}
var 凡人城镇: Array = []
var 王朝奇观: Array = []          # 已建造的奇观列表
var 建造中奇观: Array = []
var 待决策办差奇遇: Array = []

func _读王朝配置() -> Array:
	if not _王朝配置缓存.is_empty():
		return _王朝配置缓存
	_王朝配置缓存 = Game._CSV去BOM("res://config/dynasty_config.csv")
	return _王朝配置缓存
func _读王朝阶段表() -> Array:
	if not _王朝阶段缓存.is_empty():
		return _王朝阶段缓存
	_王朝阶段缓存 = Game._CSV去BOM("res://config/dynasty_phase_config.csv")
	return _王朝阶段缓存
func _读差事模板表() -> Array:
	if not _差事模板缓存.is_empty():
		return _差事模板缓存
	_差事模板缓存 = Game._CSV去BOM("res://config/dynasty_decree_config.csv")
	return _差事模板缓存
# 按中文阶段名取阶段配置行（缺表兜底空字典，调用方须判空）
func _王朝阶段配置(阶段名: String) -> Dictionary:
	for r in _读王朝阶段表():
		if str((r as Dictionary).get("phase_name", "")) == 阶段名:
			return r as Dictionary
	return {}
# 按中文国策名取国策配置行（缺表兜底空字典，调用方须判空）
func _王朝国策配置(国策名: String) -> Dictionary:
	for r in _读王朝配置():
		if str((r as Dictionary).get("policy_name", "")) == 国策名:
			return r as Dictionary
	return {}
# 新王朝工厂：new_game 与改朝换代共用（朝代序累加不重置）
func _新王朝(朝代序: int) -> Dictionary:
	var 国策表: Array = _读王朝配置()
	var 国策: String = "崇道"
	if not 国策表.is_empty():
		var 首行: Dictionary = 国策表[randi() % 国策表.size()]
		国策 = str(首行.get("policy_name", "崇道"))
	var 姓: String = str(Game.王朝帝姓池[randi() % Game.王朝帝姓池.size()])
	var 名: String = str(Game.王朝帝名池[randi() % Game.王朝帝名池.size()])
	var 年龄: int = randi_range(28, 52)
	return {
		"国号": str(Game.王朝国号池[randi() % Game.王朝国号池.size()]),
		"朝代序": 朝代序,
		"开国年": Game.累计游戏日,
		"阶段": "开国",
		"阶段进度": 0,
		"在位月": 0,
		"国祚": 100,
		"民心": 60,
		"国策": 国策,
		"皇帝": {
			"名": 姓 + 名,
			"年龄": 年龄,
			"寿元": 年龄 + randi_range(12, 32),
			"性格": str(Game.王朝性格池[randi() % Game.王朝性格池.size()]),
			"对宗门": 20,
		},
		"对宗门关系": 50,
		"宗门爵位": "未册封",
		"受封月": 0,
		"上次扶持月": -99,
		"上次索要月": -99,
		# 荐举为「月度必做的主动决策」：受封后每月须荐举一次，逾期则朝廷不满
		"待荐举": false,
		"上次荐举月": -99,
		# 预期在位月：新帝能撑多久（随机 18~36 王朝月）。旧档缺键由 get 兜底 30，不升 SAVE_VERSION
		"预期在位月": randi_range(18, 36),
		"派系": _派系初值数组_S34(),
		"皇子": [],
		# 批次 3：爵位停权（关系跌破门槛则权利冻结）/ 待决反制（玩家可操作的诏令）
		"爵位停权": false,
		"待决反制": [],
		"待决委托": [],
		"委托冷却": {},
		"押注皇子ID": "",
		"上次反制月": -99,
	}

# 郡县运行时状态初始化（从 city_config.csv 读初始值模板；后续变化只写 郡县状态）
func _初始化郡县状态_S34() -> void:
	郡县状态.clear()
	for r in Game._CSV去BOM("res://config/city_config.csv"):
		var cid: String = str((r as Dictionary).get("city_id", ""))
		if cid == "":
			continue
		郡县状态[cid] = {
			# 郡ID 必须自存：供奉系数/苗子寻访拿到的是郡字典而非 key，
			# 断供与禁传道标记要靠它回查（原实现没有这个字段）
			"郡ID": cid,
			"名": str((r as Dictionary).get("city_name", "")),
			"等级": int((r as Dictionary).get("city_level", 1)),
			"人口": int((r as Dictionary).get("population", 0)),
			"兵力": int((r as Dictionary).get("garrison", 0)),
			"凡俗": int((r as Dictionary).get("is_mortal", 0)) == 1,
			"忠顺": int((r as Dictionary).get("loyalty", 0)),
			"感恩": int((r as Dictionary).get("gratitude", 0)),
			"灾情": int((r as Dictionary).get("disaster", 0)),
			"解锁条件": str((r as Dictionary).get("unlock_condition", "")),
		}
# 凡俗郡县数（王朝版图规模；紫府仙都/妖族领/秘境门户 非凡俗不计入）
func _凡俗郡县数_S34() -> int:
	var n: int = 0
	for k in 郡县状态.keys():
		if bool((郡县状态[k] as Dictionary).get("凡俗", false)):
			n += 1
	return n
# 新帝继位（先帝驾崩或禅让；新帝对宗门天然更疏远，逼玩家重新经营关系）
func _新帝继位_S34(驾崩: bool) -> void:
	# 有皇子候选时，新帝从皇子中按竞争力抽签产生 —— 玩家的押注才有博弈意义
	var 皇子表: Array = 王朝.get("皇子", []) if 王朝.get("皇子", null) != null else []
	var 继位ID: String = ""
	var 姓: String = str(Game.王朝帝姓池[randi() % Game.王朝帝姓池.size()])
	var 名: String = str(Game.王朝帝名池[randi() % Game.王朝帝名池.size()])
	var 年龄: int = randi_range(18, 45)
	# 皇子字段的消费：对宗门态度叠加到新帝、派系倾向抬该派系权重（与党争联动）。
	# 不消费的话这三个数字玩家看着有用、实际不影响任何事 —— 批次 2「爵位空气权利」的同类病。
	var 储对宗门: int = 0
	var 储派系: String = ""
	if not 皇子表.is_empty():
		var 储: Dictionary = _择储_S34(皇子表)
		继位ID = str(储.get("ID", ""))
		名 = str(储.get("名", 名))
		姓 = ""     # 皇子的名已含姓（生成时即为「姓+名」），再拼一次会变「李李玄」
		年龄 = int(储.get("年龄", 年龄))
		储对宗门 = int(储.get("对宗门", 0))
		储派系 = str(储.get("派系倾向", ""))
		_结算继承押注_S34(继位ID)
		if 储派系 != "" and 储派系 in 派系序:
			var 项: Dictionary = _取派系项_S34(储派系)
			if not 项.is_empty():
				项["权重"] = clamp(int(项.get("权重", 25)) + 皇子继位派系增益, 派系权重下限, 派系权重上限)
				Game.添加纪事("王朝", "储君登基", "新帝素与%s亲近，该党权重+%d" % [储派系, 皇子继位派系增益], 1)
	王朝["皇帝"] = {
		"名": 姓 + 名,
		"年龄": 年龄,
		"寿元": 年龄 + randi_range(12, 32),
		"性格": str(Game.王朝性格池[randi() % Game.王朝性格池.size()]),
		"对宗门": clamp(int(王朝.get("对宗门关系", 50)) - 30 + 储对宗门, -100, 100),
	}
	王朝["在位月"] = 0
	王朝["预期在位月"] = randi_range(18, 36)
	if 驾崩:
		王朝["国祚"] = clamp(int(王朝.get("国祚", 50)) - 5, 0, 100)
		王朝["民心"] = clamp(int(王朝.get("民心", 60)) - 5, 0, 100)
		var 帝名: String = str((王朝["皇帝"] as Dictionary).get("名", "?"))
		Game.添加纪事("王朝", "新帝继位", "先帝崩，新帝%s继位，国祚动荡" % 帝名, 2)
	# 新朝气象：新帝登基后重开皇子候选（中衰/乱世才有 —— 盛世储位未显）
	_生成皇子_S34()
# ============ S34 批次 3：皇子系统 + 继承人押注 ============
# GDD §4.1 早有「皇子」字段，批次 1 只建了空数组。此处兑现爵位表承诺的
# 「帝师可押注皇位继承人」—— 中衰期玩家焦点正是「站队、押注继承人」（§5）。
func _生成皇子_S34() -> void:
	if int(王朝.get("国祚", 100)) >= 皇子生成国祚线:
		return
	var 数: int = randi_range(皇子数下限, 皇子数上限)
	var 姓: String = str(Game.王朝帝姓池[randi() % Game.王朝帝姓池.size()])
	var 表: Array = []
	var 序: int = int(王朝.get("朝代序", 1))
	for i in range(数):
		var 资质: int = randi_range(1, 5)
		表.append({
			"ID": "prince_%d_%d" % [序, i],
			"名": 姓 + str(Game.王朝帝名池[randi() % Game.王朝帝名池.size()]),
			"年龄": randi_range(皇子年龄下限, 皇子年龄上限),
			"资质": 资质,
			"派系倾向": str(派系序[randi() % 派系序.size()]),
			"对宗门": randi_range(-50, 50),
			"竞争力": 30 + 资质 * 10 + randi_range(0, 20),
		})
	王朝["皇子"] = 表
# 择储：按竞争力权重抽签（玩家押注有真实概率成分，不是必中）
func _择储_S34(表: Array) -> Dictionary:
	if 表.is_empty():
		return {}
	var 总: int = 0
	for it in 表:
		总 += max(1, int((it as Dictionary).get("竞争力", 1)))
	var 抽: int = randi() % max(1, 总)
	var 累: int = 0
	for it in 表:
		累 += max(1, int((it as Dictionary).get("竞争力", 1)))
		if 抽 < 累:
			return it as Dictionary
	return 表[表.size() - 1] as Dictionary
# 玩家押注继承人（帝师及以上爵位方可；改押要付关系代价 —— 反复摇摆不被信任）
func 押注继承人_S34(皇子ID: String) -> Dictionary:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 not in 调停民变爵位序:
		return {"成功": false, "原因": "需帝师及以上爵位方可押注继承人"}
	if bool(王朝.get("爵位停权", false)):
		return {"成功": false, "原因": "爵位停权中，押注之权暂废"}
	var 表: Array = 王朝.get("皇子", []) if 王朝.get("皇子", null) != null else []
	if 表.is_empty():
		return {"成功": false, "原因": "朝中尚无皇子候选（须待国祚跌破%d）" % 皇子生成国祚线}
	var 命中: Dictionary = {}
	for it in 表:
		if str((it as Dictionary).get("ID", "")) == 皇子ID:
			命中 = it as Dictionary
			break
	if 命中.is_empty():
		return {"成功": false, "原因": "无此皇子"}
	var 旧押: String = str(王朝.get("押注皇子ID", ""))
	if 旧押 == 皇子ID:
		return {"成功": false, "原因": "已押注此人"}
	if 旧押 != "":
		var 关: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关 - float(改押关系罚), 0.0, 100.0)
		Game.添加纪事("王朝", "改易储君", "宗门更易押注之人，朝中侧目（关系-%d）" % 改押关系罚, 2)
	王朝["押注皇子ID"] = 皇子ID
	Game.添加纪事("王朝", "押注储君", "宗门押注%s（资质%d·倾向%s）" % [str(命中.get("名", "?")), int(命中.get("资质", 0)), str(命中.get("派系倾向", "?"))], 1)
	return {"成功": true, "皇子": str(命中.get("名", "?")), "竞争力": int(命中.get("竞争力", 0))}
# 押注结算：新帝继位时调用
func _结算继承押注_S34(继位ID: String) -> void:
	var 押: String = str(王朝.get("押注皇子ID", ""))
	if 押 == "" or 继位ID == "":
		return
	if 押 == 继位ID:
		var 关: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关 + float(押对关系增), 0.0, 100.0)
		Game.添加纪事("王朝", "押注得中", "押注之人登临大宝，新帝感念宗门（关系+%d）" % 押对关系增, 1)
		Game._加推演条目("★ 押注得中：新帝感念宗门，对宗门关系+%d" % 押对关系增, Game.ET_SECT, Game.PRIO_HIGH, {})
	else:
		var 关2: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关2 - float(押错关系罚), 0.0, 100.0)
		Game.添加纪事("王朝", "押注落空", "所押之人未得大位，新帝心生芥蒂（关系-%d）" % 押错关系罚, 2)
		Game._加推演条目("◇ 押注落空：新帝另立，对宗门关系-%d" % 押错关系罚, Game.ET_SECT, Game.PRIO_HIGH, {})
	王朝["押注皇子ID"] = ""
# 国师及以上可调停民变（兑现爵位表 right_desc「可调停民变」—— 批次 2 核查时的欠条）
func _可调停民变_S34() -> bool:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 not in 调停民变爵位序:
		return false
	return not bool(王朝.get("爵位停权", false))

# 改朝换代：国祚归零 → 新国号/新皇帝/新国策/版图重掷（内容刷新，零美术成本）
func _改朝换代_S34() -> void:
	var 旧国号: String = str(王朝.get("国号", "?"))
	var 旧朝序: int = int(王朝.get("朝代序", 1))
	# 爵位代价必须在换朝前捕获旧位阶：监国「宗门同受重伤」/ 摄政「翻车」
	var 旧位阶: String = str(王朝.get("宗门爵位", "未册封"))
	王朝 = _新王朝(旧朝序 + 1)
	_刷新郡县忠顺_S34()
	_改朝换代爵位后果_S34(旧位阶)
	var 新国号: String = str(王朝.get("国号", "?"))
	Game.添加纪事("王朝", "改朝换代", "%s覆灭，新朝%s立（第%d代）" % [旧国号, 新国号, 旧朝序 + 1], 2)
	Game._加推演条目("◆ %s覆灭，%s立国，天下版图重掷" % [旧国号, 新国号], Game.ET_SECT, Game.PRIO_HIGH, {})
# 版图忠顺度重掷（改朝换代专用：新朝对地方的掌控从头开始）
func _刷新郡县忠顺_S34() -> void:
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		郡["忠顺"] = randi_range(20, 70)
		郡["灾情"] = 0
# 阶段推进：国祚落入哪个区间就切到哪个阶段（区间唯一真源 dynasty_phase_config.csv）
func _推进王朝阶段_S34() -> void:
	var 国祚: int = int(王朝.get("国祚", 100))
	var 新阶段: String = "乱世"
	for 阶段名 in Game.王朝阶段序:
		var cfg: Dictionary = _王朝阶段配置(阶段名)
		if cfg.is_empty():
			continue
		if 国祚 >= int(cfg.get("dynasty_min", 0)) and 国祚 <= int(cfg.get("dynasty_max", 100)):
			新阶段 = 阶段名
			break
	var 旧阶段: String = str(王朝.get("阶段", "开国"))
	if 新阶段 != 旧阶段:
		王朝["阶段"] = 新阶段
		王朝["阶段进度"] = 0
		var 落差: int = Game.王朝阶段序.find(新阶段) - Game.王朝阶段序.find(旧阶段)
		var 国号: String = str(王朝.get("国号", "?"))
		if 落差 > 0:
			Game.添加纪事("王朝", "国势转衰", "%s由%s转入%s" % [国号, 旧阶段, 新阶段], 2)
		else:
			Game.添加纪事("王朝", "国势复振", "%s由%s回升至%s" % [国号, 旧阶段, 新阶段], 1)
	else:
		王朝["阶段进度"] = int(王朝.get("阶段进度", 0)) + 1
# 月度主结算：自演化引擎（P4）—— 玩家不管也会自己变，这是「有理由上线」的根
# ===================== S35-1 开国六问（三条掀桌路线 + 建制六问）=====================
# 设计：掀桌开国是王朝线的终极正回馈——门派等级 8 起够得着，三条路线互斥取向：
#   兵变夺都（力取：快而脏、业力重）/ 受禅称帝（名取：需先爬到监国摄政）/ 受命于天（德取：需长期经营香火）。
# 六问每一问都必须有真实消费方，禁止「只存不用」的风味配置：
#   国号=玩家自打（真自定义）｜国策=主+副双轨｜都城=供奉加成｜官制=苗子+战功｜律法=供奉+民心｜国教=供奉（S35-2 信仰起点）
const 开国都城供奉加成: float = 1.3
const 开国都城忠顺加成: int = 15
const 开国加成下限: float = 0.6
const 开国加成上限: float = 2.0
const 开国国号最长: int = 6
var 开国表缓存: Array = []

func _读开国表() -> Array:
	if not 开国表缓存.is_empty():
		return 开国表缓存
	开国表缓存 = Game._CSV去BOM("res://config/dynasty_found_config.csv")
	return 开国表缓存

func _开国配置(id: String) -> Dictionary:
	if id == "":
		return {}
	for r in _读开国表():
		var d: Dictionary = r
		if str(d.get("id", "")) == id:
			return d
	return {}

func _开国表(kind: String) -> Array:
	var out: Array = []
	for r in _读开国表():
		var d: Dictionary = r
		if str(d.get("kind", "")) == kind:
			out.append(d)
	return out

# 路线门槛校验：返回「缺失条件清单」（UI 直接展示，玩家知道还差什么，而不是盲猜）
func _开国路线缺口(配: Dictionary) -> Array:
	var 缺: Array = []
	var 需级: int = int(配.get("need_grade", 0))
	if Game.门派等级 < 需级:
		缺.append("宗门品级 %d" % 需级)
	var 需石: int = int(配.get("need_stone", 0))
	if 需石 > 0 and Game.灵石 < 需石:
		缺.append("Game.灵石 %d" % 需石)
	var 需香: int = int(配.get("need_incense", 0))
	if 需香 > 0 and Game.香火值 < 需香:
		缺.append("Game.香火值 %d" % 需香)
	var 需爵: String = str(配.get("need_title", ""))
	if 需爵 != "" and str(王朝.get("宗门爵位", "未册封")) != 需爵:
		缺.append("爵位「%s」" % 需爵)
	# 德望维度：感恩≥50 的凡俗郡数（香火日产约 280，单靠香火等于没有门槛）
	var 需恩: int = int(配.get("need_gratitude", 0))
	if 需恩 > 0:
		var 现恩: int = _感恩达标郡数_S34(50)
		if 现恩 < 需恩:
			缺.append("感恩郡 %d（现 %d）" % [需恩, 现恩])
	return 缺

func 开国路线状态_S34() -> Array:
	var out: Array = []
	for r in _开国表("route"):
		var d: Dictionary = r
		var 缺: Array = _开国路线缺口(d)
		out.append({
			"id": str(d.get("id", "")),
			"名": str(d.get("name", "")),
			"说明": str(d.get("desc", "")),
			"达成": 缺.is_empty(),
			"缺": 缺,
		})
	return out

# 六问候选清单：都城复用已解锁凡俗郡、国策复用 dynasty_config.csv —— 零新增数据源
func 开国选项_S34() -> Dictionary:
	var 都城: Array = []
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k]
		都城.append({"id": str(郡.get("郡ID", k)), "名": str(郡.get("名", k)), "等级": int(郡.get("等级", 1))})
	var 国策: Array = []
	for r in _读王朝配置():
		var 名: String = str((r as Dictionary).get("policy_name", ""))
		if 名 != "":
			国策.append(名)
	return {"路线": 开国路线状态_S34(), "官制": _开国表("system"), "律法": _开国表("law"), "国教": _开国表("faith"), "都城": 都城, "国策": 国策}

# 建立新朝：真扣灵石/Game.香火值 + 真建朝 + 真写纪事朝报（掀桌的全部代价在此一次性结清）
func 建立新朝_S34(答案: Dictionary) -> Dictionary:
	var 路线配: Dictionary = _开国配置(str(答案.get("路线", "")))
	if 路线配.is_empty() or str(路线配.get("kind", "")) != "route":
		return {"成功": false, "原因": "未选掀桌路线"}
	var 缺: Array = _开国路线缺口(路线配)
	if not 缺.is_empty():
		return {"成功": false, "原因": "门槛未达：" + "、".join(缺)}
	var 都城id: String = str(答案.get("都城", ""))
	if 都城id == "" or not 郡县状态.has(都城id):
		return {"成功": false, "原因": "都城未选或不存"}
	var 种类表: Dictionary = {"官制": "system", "律法": "law", "国教": "faith"}
	for 键 in 种类表.keys():
		var 目标: String = str(答案.get(键, ""))
		if 目标 == "":
			continue
		if str(_开国配置(目标).get("kind", "")) != str(种类表[键]):
			return {"成功": false, "原因": "%s非法" % 键}
	var 策池: Array = []
	for r in _读王朝配置():
		var 名2: String = str((r as Dictionary).get("policy_name", ""))
		if 名2 != "":
			策池.append(名2)
	var 主策: String = str(答案.get("主国策", ""))
	if not 策池.has(主策):
		主策 = "崇道"
	var 副策: String = str(答案.get("副国策", ""))
	if 副策 == 主策 or not 策池.has(副策):
		副策 = ""
	var 国号: String = str(答案.get("国号", "")).strip_edges()
	if 国号 == "":
		国号 = str(Game.王朝国号池[randi() % Game.王朝国号池.size()])
	if 国号.length() > 开国国号最长:
		国号 = 国号.substr(0, 开国国号最长)
	# 真扣：掀桌的代价必须落地（信 UI 就等于无限用，S32 铁律二）
	var 需石: int = int(路线配.get("need_stone", 0))
	var 需香: int = int(路线配.get("need_incense", 0))
	Game.灵石 -= 需石
	Game.香火值 = max(0, Game.香火值 - 需香)
	var 业: int = int(路线配.get("karma", 0))
	if 业 > 0:
		Game.业力 += 业
	var 旧国号: String = str(王朝.get("国号", "?"))
	var 旧朝序: int = int(王朝.get("朝代序", 1))
	王朝 = _新王朝(旧朝序 + 1)
	王朝["国号"] = 国号
	王朝["国策"] = 主策
	王朝["国策副"] = 副策
	王朝["都城"] = 都城id
	王朝["官制"] = str(答案.get("官制", ""))
	王朝["律法"] = str(答案.get("律法", ""))
	王朝["国教"] = str(答案.get("国教", ""))
	王朝["开国方式"] = str(路线配.get("name", ""))
	王朝["民心"] = clamp(int(路线配.get("init_morale", 60)), 0, 100)
	王朝["国祚"] = clamp(int(路线配.get("init_longevity", 100)), 0, 100)
	王朝["自立"] = true
	王朝["宗门爵位"] = "自立为王"
	王朝["对宗门关系"] = 100.0
	var 初忠: int = clamp(int(路线配.get("init_loyalty", 40)), 0, 100)
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		郡["忠顺"] = 初忠
		if k == 都城id:
			郡["忠顺"] = clamp(初忠 + 开国都城忠顺加成, 0, 100)
		郡["灾情"] = 0
		郡县状态[k] = 郡
	var 都名: String = str((郡县状态[都城id] as Dictionary).get("名", "?"))
	Game.添加纪事("王朝", "开国", "%s覆灭，%s以「%s」受命维新，定都%s" % [旧国号, 国号, str(路线配.get("name", "")), 都名], 2)
	_加朝报("王朝", "新朝开国：%s" % 国号, "%s覆灭。宗门以「%s」开国，定都%s，改元维新。官制「%s」、律法「%s」、国教「%s」。"
		% [旧国号, str(路线配.get("name", "")), 都名, str(答案.get("官制", "")), str(答案.get("律法", "")), str(答案.get("国教", ""))], 3)
	Game._加推演条目("★ 新朝%s开国（%s），定都%s" % [国号, str(路线配.get("name", "")), 都名], Game.ET_SECT, Game.PRIO_HIGH, {})
	return {"成功": true, "国号": 国号, "都城": 都名, "方式": str(路线配.get("name", ""))}

# —— 四个真实消费方（缺一个就是死配置）——
# ① 供奉：官制 × 律法 × 国教 × 都城 叠乘，钳制 [0.6, 2.0] 对齐运维封顶 318
func _开国建制系数_S34(郡: Dictionary) -> float:
	var 倍: float = 1.0
	for 键 in ["官制", "律法", "国教"]:
		var 配: Dictionary = _开国配置(str(王朝.get(键, "")))
		if 配.is_empty():
			continue
		倍 *= float(配.get("p_tribute", 1.0))
	var 都城: String = str(王朝.get("都城", ""))
	if 都城 != "" and str(郡.get("郡ID", "")) == 都城:
		倍 *= 开国都城供奉加成
	return clamp(倍, 开国加成下限, 开国加成上限)

# ② 苗子：官制决定灵根苗子质量取向
func _开国苗子系数_S34() -> float:
	var 配: Dictionary = _开国配置(str(王朝.get("官制", "")))
	if 配.is_empty():
		return 1.0
	return float(配.get("p_talent", 1.0))

# ③ 战功：官制/律法/国教共同决定军功爵赏之厚薄
func _开国战功系数_S34() -> float:
	var 倍: float = 1.0
	for 键 in ["官制", "律法", "国教"]:
		var 配: Dictionary = _开国配置(str(王朝.get(键, "")))
		if 配.is_empty():
			continue
		倍 *= float(配.get("p_merit", 1.0))
	return 倍

# ④ 民心：官制/律法/国教每月民心加值（可正可负）
func _开国民心月修正_S34() -> int:
	var 值: int = 0
	for 键 in ["官制", "律法", "国教"]:
		var 配: Dictionary = _开国配置(str(王朝.get(键, "")))
		if 配.is_empty():
			continue
		值 += int(配.get("p_morale", 0))
	return 值
# ===================== S34c 传送阵 引擎（§11.17 三）=====================
func _读传送阵表() -> Dictionary:
	if not Game.传送阵表缓存.is_empty():
		return Game.传送阵表缓存
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/teleport_array_config.csv", FileAccess.READ)
	if f == null:
		push_warning("teleport_array_config.csv 缺失，传送阵表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 14:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"tele_id": id,
			"array_name": p[1].strip_edges(),
			"level": int(p[2]),
			"unlock_sect_level": int(p[3]),
			"max_range": int(p[4]),
			"max_carry": int(p[5]),
			"daily_use_count": int(p[6]),
			"per_use_base_cost": int(p[7]),
			"per_weight_cost": float(p[8]),
			"daily_standby_cost": int(p[9]),
			"upgrade_lingstone": int(p[10]),
			"upgrade_material": p[11].strip_edges(),
			"upgrade_days": int(p[12]),
			"unlock_function": p[13].strip_edges(),
		}
	f.close()
	Game.传送阵表缓存 = 表
	return 表

# 城邦传送距离（按城邦等级折算；数值与 max_range 阶梯对齐，可调 [PLACEHOLDER]）
func _传送距离(城: Dictionary) -> int:
	return {1: 50, 2: 300, 3: 1500, 4: 8000}.get(int(城.get("city_level", 1)), 99999)

func _传送阵补缺() -> void:
	if not (Game.传送阵等级 is int):
		Game.传送阵等级 = 0
	if not (Game.传送阵建造中 is Dictionary):
		Game.传送阵建造中 = {}
	if not (Game.传送阵今日已用 is int):
		Game.传送阵今日已用 = 0
	if not (Game.传送阵待机欠费 is bool):
		Game.传送阵待机欠费 = false

func 已建传送阵() -> bool:
	return Game.传送阵等级 > 0

func 传送阵当前档() -> Dictionary:
	if Game.传送阵等级 <= 0:
		return {}
	return _读传送阵表().get("ta%02d" % Game.传送阵等级, {})

# 当前等级可瞬时抵达的城邦列表（距离 ≤ max_range）
func 传送阵可达城邦() -> Array:
	var 出: Array = []
	if Game.传送阵等级 <= 0:
		return 出
	var 档 = _读传送阵表().get("ta%02d" % Game.传送阵等级, null)
	if 档 == null:
		return 出
	var 范围 = int(档.get("max_range", 0))
	for 城 in Game.商队系统.商队城市表.values():
		if _传送距离(城) <= 范围:
			出.append(城)
	return 出


func 传送阵建造信息() -> Dictionary:
	if not Game.传送阵建造中.is_empty():
		return {"可建": false, "建造中": true, "目标档": int(Game.传送阵建造中.get("目标档", 0)), "完成日": int(Game.传送阵建造中.get("完成日", 0))}
	var 目标 = Game.传送阵等级 + 1
	if 目标 > 4:
		return {"可建": false, "已满": true}
	var 档 = _读传送阵表().get("ta%02d" % 目标, null)
	if 档 == null:
		return {"可建": false}
	var 清单 = Game._解析材料清单(档.get("upgrade_material", ""))
	for m in 清单:
		m["有"] = Game._库房灵材数量(m["名"])
	return {"可建": true, "等级": 目标, "名称": str(档.get("array_name", "")),
		"需门派等级": int(档.get("unlock_sect_level", 99)), "工费": int(档.get("upgrade_lingstone", 0)),
		"时日": int(档.get("upgrade_days", 0)), "材料": 清单,
		"max_range": int(档.get("max_range", 0)), "max_carry": int(档.get("max_carry", 0)),
		"daily_use_count": int(档.get("daily_use_count", 0)), "per_use_base_cost": int(档.get("per_use_base_cost", 0)),
		"per_weight_cost": float(档.get("per_weight_cost", 0.0)), "daily_standby_cost": int(档.get("daily_standby_cost", 0)),
		"unlock_function": str(档.get("unlock_function", ""))}

func 建造传送阵() -> Dictionary:
	if not Game.传送阵建造中.is_empty():
		return {"成功": false, "消息": "传送阵正在建造中，不可重复开工"}
	var 信息 = 传送阵建造信息()
	if not 信息.get("可建", false):
		if 信息.get("已满", false):
			return {"成功": false, "消息": "传送阵已达当前可建最高品级（跨界传送阵需灵界通道开启）"}
		return {"成功": false, "消息": "传送阵配置缺失"}
	if Game.门派等级 < int(信息.get("需门派等级", 99)):
		return {"成功": false, "消息": "宗门品级不足（需%d品）" % int(信息.get("需门派等级", 99))}
	var 费 = int(信息.get("工费", 0))
	if Game.灵石 < 费:
		return {"成功": false, "消息": "祭炼灵石不足（需%d）" % 费}
	var 扣 = Game._扣灵材(信息.get("材料", []))
	if not 扣.get("成功", false):
		return {"成功": false, "消息": "灵材不足：" + "、".join(扣.get("缺", []))}
	Game.灵石 -= 费
	var 目标档 = int(信息.get("等级", 1))
	Game.传送阵建造中 = {"目标档": 目标档, "完成日": Game.累计游戏日 + int(信息.get("时日", 0))}
	Game.添加纪事("庶务", "传送阵", "历时%d日，动工兴建%s（%d品）" % [int(信息.get("时日", 0)), str(信息.get("名称", "")), 目标档], 1)
	return {"成功": true, "消息": "传送阵（%s）动工，预计%d日完工" % [str(信息.get("名称", "")), int(信息.get("时日", 0))], "等级": 目标档, "完成日": Game.传送阵建造中["完成日"]}

func _推进传送阵建造() -> void:
	if not Game.传送阵建造中.is_empty():
		if Game.累计游戏日 >= int(Game.传送阵建造中.get("完成日", 0)):
			var 目标档 = int(Game.传送阵建造中.get("目标档", 1))
			var 档 = _读传送阵表().get("ta%02d" % 目标档, null)
			Game.传送阵等级 = 目标档
			Game.传送阵建造中 = {}
			if 档 != null:
				Game.添加纪事("庶务", "传送阵", "历时%d日，%s（%d品）建成，自此可瞬时传送货物至城邦" % [int(档.get("upgrade_days", 0)), str(档.get("array_name", "")), Game.传送阵等级], 1)

# 每日：重置使用计数 + 扣待机成本（真 sink）；灵石不足则置欠费停用
func _推进传送阵待机_S34(天: int) -> void:
	Game.传送阵今日已用 = 0
	if Game.传送阵等级 <= 0 or not Game.传送阵建造中.is_empty():
		return
	var 档 = _读传送阵表().get("ta%02d" % Game.传送阵等级, null)
	if 档 == null:
		return
	var 待机 = int(档.get("daily_standby_cost", 0))
	if 待机 <= 0:
		Game.传送阵待机欠费 = false
		return
	if Game.灵石 < 待机:
		Game.传送阵待机欠费 = true
		Game.添加纪事("庶务", "传送阵", "传送阵待机灵石不足（需%d/日），暂停运转" % 待机, 1)
	else:
		Game.灵石 -= 待机
		Game.传送阵待机欠费 = false

func _物品传送重量(it) -> int:
	var 品阶 = ""
	if it is Item:
		品阶 = str(it.品阶)
	else:
		品阶 = str(it.get("品阶", "凡阶"))
	return 1 + Item.品阶序.find(品阶)

func _物品传送价值(it) -> int:
	var 品阶 = ""
	if it is Item:
		品阶 = str(it.品阶)
	else:
		品阶 = str(it.get("品阶", "凡阶"))
	return _拍卖品阶基准(品阶)

# 传送调度：将宗门库房货物瞬时传送至目标城邦并就地售卖，得灵石+商队系统.商路声望
func 传送调度(城市ID: String, 货物索引: Array) -> Dictionary:
	if not Game.enable_teleport_system:
		return {"成功": false, "消息": "传送阵系统已关闭"}
	if Game.传送阵等级 <= 0:
		return {"成功": false, "消息": "尚未建造传送阵"}
	if not Game.传送阵建造中.is_empty():
		return {"成功": false, "消息": "传送阵建造中"}
	if Game.传送阵待机欠费:
		return {"成功": false, "消息": "传送阵待机欠费，已暂停运转（补足待机灵石后自动恢复）"}
	var 城 = Game.商队系统.商队城市表.get(str(城市ID), null)
	if 城 == null:
		return {"成功": false, "消息": "未知城邦"}
	var 档 = _读传送阵表().get("ta%02d" % Game.传送阵等级, null)
	if 档 == null:
		return {"成功": false, "消息": "传送阵配置缺失"}
	if int(档.get("max_range", 0)) < _传送距离(城):
		return {"成功": false, "消息": "超出传送阵覆盖距离（需升级）"}
	var 日限 = int(档.get("daily_use_count", 0))
	if Game.传送阵今日已用 >= 日限:
		return {"成功": false, "消息": "今日传送次数已用尽（%d次）" % 日限}
	var 最大载重 = int(档.get("max_carry", 0))
	var 总重: int = 0
	var 选中: Array = []
	for idx in 货物索引:
		var i = int(idx)
		if i < 0 or i >= Game.宗门库房.size():
			return {"成功": false, "消息": "货物索引越界"}
		var it = Game.宗门库房[i]
		if it == null:
			return {"成功": false, "消息": "货物为空"}
		总重 += _物品传送重量(it)
		if 总重 > 最大载重:
			return {"成功": false, "消息": "超出传送阵载重（%d/%d）" % [总重, 最大载重]}
		选中.append(i)
	var 成本: int = int(档.get("per_use_base_cost", 0)) + int(float(总重) * float(档.get("per_weight_cost", 0.0)))
	if Game.灵石 < 成本:
		return {"成功": false, "消息": "宗门灵石不足（传送费需%d）" % 成本}
	var 货值: int = 0
	for i in 选中:
		var it = Game.宗门库房[i]
		货值 += _物品传送价值(it)
	选中.sort()
	选中.reverse()
	for i in 选中:
		Game.宗门库房.remove_at(i)
	var 城率: float = float(城.get("base_price_rate", 1.0))
	var 收益: int = int(float(货值) * 城率)
	Game.灵石 += 收益
	Game.灵石 -= 成本
	Game.传送阵今日已用 += 1
	var cid = str(城.get("city_id", 城市ID))
	Game.商队系统.商路声望[cid] = int(Game.商队系统.商路声望.get(cid, 0)) + 选中.size()
	Game.添加纪事("贸易", "传送调度", "传送阵将%d件货物瞬抵%s，售得%d灵石（传送费%d），商队系统.商路声望+%d" % [选中.size(), str(城.get("city_name", "")), 收益, 成本, 选中.size()], 1)
	return {"成功": true, "收益": 收益, "成本": 成本, "货值": 货值, "Game.声望": 选中.size(), "城市": str(城.get("city_name", ""))}

# ——— S35-0 王朝邸报层：数据层 ———
# 现实日序号（UTC 天）：朝奏按它刷新，保证「一个现实日 = 一道朝奏」，与离线推演天数解耦
func _今日序号() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _加朝报(类型: String, 标题: String, 正文: String = "", 重要度: int = 1) -> void:
	var 记录: Dictionary = {
		"类型": 类型,          # 喜讯 / 警讯 / 待办 / 寻常
		"标题": 标题,
		"正文": 正文,
		"重要度": 重要度,      # 1-寻常 2-重要 3-重大
		"游戏日": Game.累计游戏日,
		"王朝月": int(王朝.get("在位月", 0)),
		"已读": false,
	}
	Game.朝报.insert(0, 记录)
	Game.朝报未读 += 1
	if Game.朝报.size() > Game.朝报上限:
		# 淘汰策略：优先丢弃「已读的寻常条目」（离线归来时保留重大条目不被冲掉）
		for i in range(Game.朝报.size() - 1, -1, -1):
			var 旧: Dictionary = Game.朝报[i]
			if bool(旧.get("已读", false)) and int(旧.get("重要度", 1)) <= 1:
				Game.朝报.remove_at(i)
				break
		if Game.朝报.size() > Game.朝报上限:
			# 兜底裁剪：被砍掉的若是未读条目，未读计数必须同步递减。
			# 否则玩家看到「邸报(237)」实际只有 200 条（S35-0 仿真实测虚高 37）。
			var 溢出: int = Game.朝报.size() - Game.朝报上限
			for i in range(Game.朝报.size() - 溢出, Game.朝报.size()):
				if not bool((Game.朝报[i] as Dictionary).get("已读", false)):
					Game.朝报未读 = max(0, Game.朝报未读 - 1)
			Game.朝报.resize(Game.朝报上限)

func 标记朝报已读() -> void:
	for r in Game.朝报:
		(r as Dictionary)["已读"] = true
	Game.朝报未读 = 0

func _读祥瑞表() -> Array:
	return Game._CSV去BOM("res://config/dynasty_omen_config.csv")

func _读朝奏表() -> Array:
	return Game._CSV去BOM("res://config/dynasty_memorial_config.csv")

func _随机凡俗郡() -> String:
	var 候选: Array = _已解锁凡俗郡_S34()
	if 候选.is_empty():
		return ""
	return str(候选[randi() % 候选.size()])

func _祥瑞文(模板: String, 郡id: String) -> String:
	var 郡名: String = "某地"
	if 郡id != "" and 郡县状态.has(郡id):
		郡名 = str((郡县状态[郡id] as Dictionary).get("名", "某地"))
	return 模板.replace("{郡}", 郡名)

# 郡县三键映射：CSV 用英文键，郡县状态字典用中文键（唯一真源在 _初始化郡县状态_S34）
func _郡键(英文: String) -> String:
	if 英文 == "disaster":
		return "灾情"
	if 英文 == "loyalty":
		return "忠顺"
	return "感恩"

# ——— S35-0 祥瑞/异象：日频概率触发，零货币产出 ———
func _推进祥瑞_S34() -> void:
	if not Game.enable_dynasty_gazette or 王朝.is_empty():
		return
	var 今日: int = _今日序号()
	if 今日 != Game.上次祥瑞日序号:
		Game.上次祥瑞日序号 = 今日
		Game.今日祥瑞数 = 0
	# 现实日限流：离线 1 天 = 360 游戏日，不限流会灌入约 65 条祥瑞，把朝奏/危机全冲成噪音
	if Game.今日祥瑞数 >= Game.祥瑞每日上限:
		return
	var 必降: bool = Game.下次必降祥瑞
	if not 必降:
		if Game.累计游戏日 - Game.上次祥瑞日 < Game.祥瑞最小间隔日:
			return
		if randf() > Game.祥瑞日概率:
			return
	var 表: Array = _读祥瑞表()
	if 表.is_empty():
		return
	var 总权: float = 0.0
	for r in 表:
		总权 += float((r as Dictionary).get("weight", 1))
	if 总权 <= 0.0:
		return
	var 抽: float = randf() * 总权
	var 选中: Dictionary = {}
	for r in 表:
		var d: Dictionary = r as Dictionary
		抽 -= float(d.get("weight", 1))
		if 抽 <= 0.0:
			选中 = d
			break
	if 选中.is_empty():
		选中 = (表[表.size() - 1] as Dictionary)
	var 郡id: String = _随机凡俗郡()
	if str(选中.get("scope", "")) == "single_county" and 郡id == "":
		return
	Game.下次必降祥瑞 = false
	Game.上次祥瑞日 = Game.累计游戏日
	var 结果: String = _施加祥瑞效果(选中, 郡id)
	var 类: String = str(选中.get("omen_type", "neutral"))
	var 邸类: String = "寻常"
	var 重要: int = 1
	if 类 == "auspicious":
		邸类 = "喜讯"
		重要 = 2
	elif 类 == "ominous":
		邸类 = "警讯"
		重要 = 2
	Game.今日祥瑞数 += 1
	_加朝报(邸类, str(选中.get("omen_name", "异象")),
		_祥瑞文(str(选中.get("text", "")), 郡id) + ("（%s）" % 结果 if 结果 != "" else ""), 重要)

# 施加祥瑞效果：返回值用于邸报展示「实打实的变化」，玩家看得到数字才信
func _施加祥瑞效果(配: Dictionary, 郡id: String) -> String:
	var 类型: String = str(配.get("effect_type", ""))
	var 值: int = int(配.get("effect_value", 0))
	if 类型 == "county_gratitude" or 类型 == "county_disaster" or 类型 == "county_loyalty":
		if 郡id == "" or not 郡县状态.has(郡id):
			return ""
		var 键: String = _郡键(类型.replace("county_", ""))
		var 郡: Dictionary = 郡县状态[郡id]
		var 旧: int = int(郡.get(键, 0))
		郡[键] = clamp(旧 + 值, 0, 100)
		郡县状态[郡id] = 郡
		return "%s%s %d→%d" % [str(郡.get("名", "")), 键, 旧, int(郡.get(键, 0))]
	elif 类型 == "talent_hunt":
		if 郡id != "" and 郡县状态.has(郡id):
			_寻访灵根得苗子_S34(郡id)
			return "遣人往%s寻访灵根" % str((郡县状态[郡id] as Dictionary).get("名", "该郡"))
		return ""
	elif 类型 == "dynasty_morale":
		var 旧民: int = int(王朝.get("民心", 60))
		王朝["民心"] = clamp(旧民 + 值, 0, 100)
		return "民心 %d→%d" % [旧民, int(王朝.get("民心", 60))]
	elif 类型 == "dynasty_longevity":
		var 旧祚: int = int(王朝.get("国祚", 100))
		王朝["国祚"] = clamp(旧祚 + 值, 0, 100)
		return "国祚 %d→%d" % [旧祚, int(王朝.get("国祚", 100))]
	elif 类型 == "dynasty_relation":
		var 旧关: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(旧关 + float(值), 0.0, 100.0)
		return "对宗门关系 %.0f→%.0f" % [旧关, float(王朝.get("对宗门关系", 50.0))]
	elif 类型 == "sect_repute":
		if Game.商队系统.商路声望.is_empty():
			return ""
		var 城: Array = Game.商队系统.商路声望.keys()
		var 城键: String = str(城[randi() % 城.size()])
		Game.商队系统.商路声望[城键] = int(Game.商队系统.商路声望.get(城键, 0)) + 值
		return "商队系统.商路声望%+d" % 值
	elif 类型 == "sect_incense":
		Game.香火值 = max(0, Game.香火值 + 值)
		return "Game.香火值%+d" % 值
	elif 类型 == "sect_merit":
		Game.愿力 = max(0, Game.愿力 + 值)
		return "愿力%+d" % 值
	return ""

# ——— S35-0 朝奏：每日一道，三选一，玩家主动决策 ———
func _生成朝奏_S34() -> void:
	var 表: Array = _读朝奏表()
	if 表.is_empty():
		return
	var 总权: float = 0.0
	for r in 表:
		总权 += float((r as Dictionary).get("weight", 1))
	var 抽: float = randf() * max(总权, 1.0)
	var 选中: Dictionary = {}
	for r in 表:
		var d: Dictionary = r as Dictionary
		抽 -= float(d.get("weight", 1))
		if 抽 <= 0.0:
			选中 = d
			break
	if 选中.is_empty():
		选中 = (表[表.size() - 1] as Dictionary)
	var 郡id: String = _随机凡俗郡()
	var 选项: Array = []
	for i in range(1, 4):
		var 文: String = str(选中.get("opt%d_text" % i, ""))
		if 文 == "":
			continue
		选项.append({"文": 文, "效": str(选中.get("opt%d_effect" % i, ""))})
	var 正文: String = _祥瑞文(str(选中.get("text", "")), 郡id)
	Game.朝奏 = {
		"奏ID": str(选中.get("memorial_id", "")),
		"名": str(选中.get("memorial_name", "奏疏")),
		"类": str(选中.get("category", "庶务")),
		"正文": 正文,
		"郡ID": 郡id,
		"选项": 选项,
		"生成日": Game.累计游戏日,
	}
	_加朝报("待办", "待批：" + str(选中.get("memorial_name", "奏疏")), 正文, 2)

func _推进朝奏_S34() -> void:
	if not Game.enable_dynasty_gazette or 王朝.is_empty():
		return
	var 今日: int = _今日序号()
	# ① 待决朝奏跨日 → 只记「搁置」，不惩罚（离线惩罚是留存杀手）
	if not Game.朝奏.is_empty() and 今日 != Game.上次朝奏日:
		_加朝报("寻常", "奏疏搁置", str(Game.朝奏.get("名", "一道奏疏")) + "久未批复，此事不了了之。", 1)
		Game.朝奏 = {}
	# ② 每日限一道：离线批量推演时 今日序号不变 → 只在首轮生成，天然防堆积
	if Game.上次朝奏日 == 今日:
		return
	if not Game.朝奏.is_empty():
		return
	Game.上次朝奏日 = 今日
	_生成朝奏_S34()

func 应对朝奏_S34(索引: int) -> Dictionary:
	if Game.朝奏.is_empty():
		return {"成功": false, "因": "无待批奏疏"}
	var 选项: Array = Game.朝奏.get("选项", [])
	if 索引 < 0 or 索引 >= 选项.size():
		return {"成功": false, "因": "选项无效"}
	var 选: Dictionary = 选项[索引]
	var 摘要: Array = _施加朝奏效果(str(选.get("效", "")), str(Game.朝奏.get("郡ID", "")))
	var 名: String = str(Game.朝奏.get("名", "奏疏"))
	var 摘文: String = ""
	for s in 摘要:
		if 摘文 != "":
			摘文 += "；"
		摘文 += str(s)
	Game.朝奏 = {}
	_加朝报("寻常", "已批：" + 名, "择「%s」。%s" % [str(选.get("文", "")), 摘文], 2)
	return {"成功": true, "摘要": 摘要}

# 朝奏效果编码：key:value 分号分隔（key 白名单由 validate_all.py 校验）
func _施加朝奏效果(编码: String, 郡id: String) -> Array:
	var 摘要: Array = []
	if 编码 == "":
		return 摘要
	for 段 in 编码.split(";"):
		var s: String = str(段).strip_edges()
		if s == "":
			continue
		var 对: Array = s.split(":")
		if 对.size() < 2:
			continue
		var 键: String = str(对[0]).strip_edges()
		var 值: int = int(str(对[1]).strip_edges())
		if 键 == "lingshi":
			Game.灵石 = max(0, Game.灵石 + 值)
			摘要.append("Game.灵石%+d" % 值)
		elif 键 == "incense":
			Game.香火值 = max(0, Game.香火值 + 值)
			摘要.append("Game.香火值%+d" % 值)
		elif 键 == "merit":
			Game.愿力 = max(0, Game.愿力 + 值)
			摘要.append("愿力%+d" % 值)
		elif 键 == "gratitude" or 键 == "loyalty" or 键 == "disaster":
			if 郡id == "" or not 郡县状态.has(郡id):
				continue
			var 中文: String = _郡键(键)
			var 郡: Dictionary = 郡县状态[郡id]
			var 旧: int = int(郡.get(中文, 0))
			郡[中文] = clamp(旧 + 值, 0, 100)
			郡县状态[郡id] = 郡
			摘要.append("%s%s %d→%d" % [str(郡.get("名", "")), 中文, 旧, int(郡.get(中文, 0))])
		elif 键 == "morale":
			var 旧民: int = int(王朝.get("民心", 60))
			王朝["民心"] = clamp(旧民 + 值, 0, 100)
			摘要.append("民心%d→%d" % [旧民, int(王朝.get("民心", 60))])
		elif 键 == "longevity":
			var 旧祚: int = int(王朝.get("国祚", 100))
			王朝["国祚"] = clamp(旧祚 + 值, 0, 100)
			摘要.append("国祚%d→%d" % [旧祚, int(王朝.get("国祚", 100))])
		elif 键 == "relation":
			var 旧关: float = float(王朝.get("对宗门关系", 50.0))
			王朝["对宗门关系"] = clamp(旧关 + float(值), 0.0, 100.0)
			摘要.append("对宗门关系%.0f→%.0f" % [旧关, float(王朝.get("对宗门关系", 50.0))])
		elif 键 == "repute":
			if Game.商队系统.商路声望.is_empty():
				continue
			var 城: Array = Game.商队系统.商路声望.keys()
			var 城键: String = str(城[randi() % 城.size()])
			Game.商队系统.商路声望[城键] = int(Game.商队系统.商路声望.get(城键, 0)) + 值
			摘要.append("商队系统.商路声望%+d" % 值)
		elif 键 == "talent":
			if 郡id != "" and 郡县状态.has(郡id):
				_寻访灵根得苗子_S34(郡id)
				摘要.append("遣人寻访灵根")
		elif 键 == "omen_next":
			Game.下次必降祥瑞 = true
			摘要.append("次日必有祥瑞")
	return 摘要

# ——— S35-0 月度保底邸报：本月零邸报则从郡县动态提炼，杜绝连续数月哑火 ———
func _保底邸报_S34() -> void:
	if not Game.enable_dynasty_gazette or 王朝.is_empty():
		return
	var 本月: int = int(王朝.get("在位月", 0))
	for r in Game.朝报:
		if int((r as Dictionary).get("王朝月", -1)) == 本月:
			return
	var 灾郡: String = ""
	var 灾值: int = 0
	var 恩郡: String = ""
	var 恩值: int = -1
	for k in 郡县状态.keys():
		var d: Dictionary = 郡县状态[k]
		if not bool(d.get("凡俗", false)):
			continue
		var 灾: int = int(d.get("灾情", 0))
		if 灾 > 灾值:
			灾值 = 灾
			灾郡 = str(d.get("名", ""))
		var 恩: int = int(d.get("感恩", 0))
		if 恩 > 恩值:
			恩值 = 恩
			恩郡 = str(d.get("名", ""))
	if 灾郡 != "" and 灾值 >= 2:
		_加朝报("警讯", "%s告急" % 灾郡, "%s灾情已达%d，民不聊生，宜速赈济。" % [灾郡, 灾值], 2)
	elif 恩郡 != "" and 恩值 >= 60:
		_加朝报("喜讯", "%s归心" % 恩郡, "%s感恩已达%d，境内安定，供奉无缺。" % [恩郡, 恩值], 1)
	else:
		var 民心: int = int(王朝.get("民心", 60))
		var 国祚: int = int(王朝.get("国祚", 100))
		_加朝报("寻常", "朝局平录", "本月无大事：民心%d、国祚%d，%s治下尚称安定。" % [民心, 国祚, str(王朝.get("国号", "?"))], 1)
# ——— 异闻层：宗门因果征兆进邸报（月度至多 1 条）———
# 定位：弟子业力/功德跨阈值时，由「世界」替玩家说出来，而不是弹数值提示。
#       玩家读到的是「某某洞府传来厉啸」，不是「业力 +20」——因果永远不给数字。
# 防刷屏：靠扫描 Game.朝报 判重（零新增持久字段，免去存档三处改动）。
# 依赖：Karma 为全局类，卦象/气象词表唯一真源。
func _邸报异闻_S34() -> void:
	if not Game.enable_dynasty_gazette or 王朝.is_empty():
		return
	var 本月: int = int(王朝.get("在位月", 0))
	for r in Game.朝报:
		var 记: Dictionary = r as Dictionary
		if int(记.get("王朝月", -1)) == 本月 and str(记.get("类型", "")) == "异闻":
			return
	var 闻: Array = Karma.宗门异闻(Game.弟子列表)
	if 闻.is_empty():
		return
	var 首: Dictionary = 闻[0] as Dictionary
	var 文本: String = str(首.get("文本", ""))
	var d = 首.get("弟子", null)
	if 文本 == "" or d == null:
		return
	var 名前: String = str(d.姓名)
	if 名前 == "":
		名前 = "某弟子"
	_加朝报("异闻", "%s洞府有异" % 名前, 文本, 2)

# ==================== S35-2 国教信仰网络 ====================
# 定位：香火庙「独立自建」（不碰 §14 硬编码建筑系统），按郡建造 → 辐射覆盖人口
#       → 本宗信仰度 → 供奉/苗子/Game.香火值/愿力 四条真实产出；
#       未覆盖的人口被异端（佛门/魔门/淫祀）争夺，超标 → 供奉折损 + 民心罚 + 邸报警讯。
# 防通胀：Game.香火值/愿力产出受「覆盖人口」与 clamp 双重约束；香火庙维护「真扣香火」。
# 数值：满覆盖约 3 现实日饱和（1 现实天 = 360 游戏日），每日登录可见明显进展。
const 信仰转化基率: float = 0.25
const 异端蔓延基率: float = 0.20
const 信仰供奉增益: float = 0.40      # 本宗满 → 供奉 ×1.40
const 异端供奉折损: float = 0.50      # 异端满 → 供奉 ×0.50
const 信仰苗子增益: float = 0.25
# 口径按「按需配庙净收益为正」反推：全境覆盖 143.6 万 / 20000 ≈ 68 → 钳到上限 60
#   （旧值 50000 实测净 -22/日，玩家一算账就不会建，S34 血泪铁律）
const 信仰香火人口基数: float = 20000.0
const 信仰香火每日上限: int = 60
const 信仰愿力人口基数: float = 100000.0
const 信仰愿力每月上限: int = 30
const 信仰异端民心权重: float = 8.0
const 信仰系数下限: float = 0.50
const 信仰系数上限: float = 1.60
const 建造香火庙工期: int = 3

# ——— 读表（带缓存，避免每日 FileAccess 反复读盘）———
func _读表_香火庙() -> Dictionary:
	if Game.信仰表缓存.has("temple"):
		return Game.信仰表缓存["temple"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/dynasty_temple_config.csv", FileAccess.READ)
	if f == null:
		push_warning("dynasty_temple_config.csv 缺失，香火庙表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 11:
			continue
		var id = p[0].strip_edges()
		if id.is_empty():
			continue
		表[id] = {
			"temple_id": id,
			"level": int(p[1]),
			"name": p[2].strip_edges(),
			"desc": p[3].strip_edges(),
			"unlock_sect_level": int(p[4]),
			"build_stone": int(p[5]),
			"upgrade_material": p[6].strip_edges(),
			"cover_pop": int(p[7]),
			"convert_rate": float(p[8]),
			"heresy_resist": int(p[9]),
			"daily_incense_cost": int(p[10]),
		}
	Game.信仰表缓存["temple"] = 表
	return 表

func _读表_异端() -> Dictionary:
	if Game.信仰表缓存.has("heresy"):
		return Game.信仰表缓存["heresy"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/dynasty_heresy_config.csv", FileAccess.READ)
	if f == null:
		push_warning("dynasty_heresy_config.csv 缺失，异端表为空")
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
				"heresy_id": id,
				"name": p[1].strip_edges(),
				"desc": p[2].strip_edges(),
				"spread_rate": float(p[3]),
				"threshold": float(p[4]),
				"tribute_penalty": float(p[5]),
				"morale_penalty": float(p[6]),
				"convert_drag": float(p[7]),
			}
	Game.信仰表缓存["heresy"] = 表
	return 表

func _读表_国教() -> Dictionary:
	if Game.信仰表缓存.has("faith"):
		return Game.信仰表缓存["faith"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/dynasty_faith_config.csv", FileAccess.READ)
	if f == null:
		push_warning("dynasty_faith_config.csv 缺失，国教表为空")
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
				"faith_id": id,
				"name": p[1].strip_edges(),
				"desc": p[2].strip_edges(),
				"convert_mult": float(p[3]),
				"heresy_mult": float(p[4]),
				"tribute_mult": float(p[5]),
				"talent_mult": float(p[6]),
				"incense_mult": float(p[7]),
			}
	Game.信仰表缓存["faith"] = 表
	return 表

func _香火庙档(等级: int) -> Dictionary:
	if 等级 <= 0:
		return {}
	var 表: Dictionary = _读表_香火庙()
	for k in 表.keys():
		var d: Dictionary = 表[k] as Dictionary
		if int(d.get("level", 0)) == 等级:
			return d
	return {}

# 国教配置：未开国/未选国教 → 全 1.0（零回归）
func _国教配置() -> Dictionary:
	var id: String = str(王朝.get("国教", ""))
	if id == "":
		return {}
	return _读表_国教().get(id, {}) as Dictionary

func _异端配置(id: String) -> Dictionary:
	if id == "":
		return {}
	return _读表_异端().get(id, {}) as Dictionary

func _香火庙信息(郡id: String) -> Dictionary:
	if not Game.香火庙.has(郡id):
		Game.香火庙[郡id] = {"等级": 0, "建造中": false, "完成日": 0, "欠费": false}
	return Game.香火庙[郡id] as Dictionary

func _郡信仰取(郡id: String) -> Dictionary:
	if not 郡信仰.has(郡id):
		郡信仰[郡id] = {"本宗": 0.0, "异端": 0.0, "异端主": "", "已报警": false}
	return 郡信仰[郡id] as Dictionary

func 香火庙等级(郡id: String) -> int:
	if not Game.香火庙.has(郡id):
		return 0
	return int((Game.香火庙[郡id] as Dictionary).get("等级", 0))

# 覆盖人口：欠费或建造中 → 0（维护是真成本，不是白拿的加成）
func _香火庙覆盖人口(郡id: String) -> int:
	var 庙: Dictionary = _香火庙信息(郡id)
	var 等级: int = int(庙.get("等级", 0))
	if 等级 <= 0 or bool(庙.get("建造中", false)) or bool(庙.get("欠费", false)):
		return 0
	var 档: Dictionary = _香火庙档(等级)
	var 人口: int = int((郡县状态.get(郡id, {}) as Dictionary).get("人口", 0))
	return min(人口, int(档.get("cover_pop", 0)))

func 香火庙建造信息(郡id: String) -> Dictionary:
	var 现: int = 香火庙等级(郡id)
	var 郡名: String = str((郡县状态.get(郡id, {}) as Dictionary).get("名", "该郡"))
	var 庙: Dictionary = _香火庙信息(郡id)
	if bool(庙.get("建造中", false)):
		return {"可建": false, "已满": false, "等级": 现, "郡名": 郡名, "原因": "正在建造中"}
	var 档: Dictionary = _香火庙档(现 + 1)
	if 档.is_empty():
		return {"可建": false, "已满": true, "等级": 现, "郡名": 郡名, "原因": "已至极品"}
	return {
		"可建": true, "已满": false,
		"郡名": 郡名,
		"等级": int(档.get("level", 现 + 1)),
		"现等级": 现,
		"名称": str(档.get("name", "")),
		"描述": str(档.get("desc", "")),
		"需门派等级": int(档.get("unlock_sect_level", 99)),
		"工费": int(档.get("build_stone", 0)),
		"材料": Game._解析材料清单(str(档.get("upgrade_material", ""))),
		"时日": 建造香火庙工期,
		"覆盖人口": int(档.get("cover_pop", 0)),
		"转化速率": float(档.get("convert_rate", 1.0)),
		"抗异端": int(档.get("heresy_resist", 0)),
		"日耗香火": int(档.get("daily_incense_cost", 0)),
	}

# 建造/升级香火庙：真扣灵石 + 真扣灵材（不扣就是假系统）
func 建造香火庙(郡id: String) -> Dictionary:
	if not Game.enable_faith_system:
		return {"成功": false, "消息": "信仰系统未开启"}
	if 郡id == "" or not 郡县状态.has(郡id):
		return {"成功": false, "消息": "该郡不存在"}
	if not bool((郡县状态[郡id] as Dictionary).get("凡俗", false)):
		return {"成功": false, "消息": "仙都妖域非凡俗之地，不宜设香火庙"}
	var 信息: Dictionary = 香火庙建造信息(郡id)
	if not bool(信息.get("可建", false)):
		if bool(信息.get("已满", false)):
			return {"成功": false, "消息": "此郡香火庙已至极品，无可再升"}
		return {"成功": false, "消息": str(信息.get("原因", "不可建造"))}
	if Game.门派等级 < int(信息.get("需门派等级", 99)):
		return {"成功": false, "消息": "宗门品级不足（需%d品）" % int(信息.get("需门派等级", 99))}
	var 费: int = int(信息.get("工费", 0))
	if Game.灵石 < 费:
		return {"成功": false, "消息": "营建灵石不足（需%d）" % 费}
	var 扣: Dictionary = Game._扣灵材(信息.get("材料", []))
	if not bool(扣.get("成功", false)):
		return {"成功": false, "消息": "灵材不足：" + "、".join(扣.get("缺", []))}
	Game.灵石 -= 费
	var 目标: int = int(信息.get("等级", 1))
	var 庙: Dictionary = _香火庙信息(郡id)
	庙["目标等级"] = 目标
	庙["建造中"] = true
	庙["完成日"] = Game.累计游戏日 + int(信息.get("时日", 0))
	庙["欠费"] = false
	Game.香火庙[郡id] = 庙
	Game.添加纪事("王朝", "兴建香火庙", "于%s动工兴建%s（第%d级），预计%d日完工"
		% [str(信息.get("郡名", "")), str(信息.get("名称", "")), 目标, int(信息.get("时日", 0))], 1)
	return {"成功": true, "消息": "%s动工，预计%d日完工" % [str(信息.get("名称", "")), int(信息.get("时日", 0))], "等级": 目标}

func _推进香火庙建造() -> void:
	if Game.香火庙.is_empty():
		return
	for cid in Game.香火庙.keys():
		var 庙: Dictionary = Game.香火庙[cid] as Dictionary
		if not bool(庙.get("建造中", false)):
			continue
		if Game.累计游戏日 < int(庙.get("完成日", 0)):
			continue
		庙["等级"] = int(庙.get("目标等级", int(庙.get("等级", 0)) + 1))
		庙["建造中"] = false
		庙["欠费"] = false
		庙.erase("目标等级")
		Game.香火庙[cid] = 庙
		var 郡名: String = str((郡县状态.get(cid, {}) as Dictionary).get("名", "该郡"))
		Game.添加纪事("王朝", "香火庙落成", "%s之%s落成，覆民%d"
			% [郡名, str(_香火庙档(int(庙.get("等级", 0))).get("name", "香火庙")), _香火庙覆盖人口(cid)], 1)
		_加朝报("喜讯", "%s香火庙落成" % 郡名, "自此可庇佑一方生灵，本宗信仰渐兴。", 1)

func _香火庙维护总额_S34() -> int:
	var 总: int = 0
	for cid in Game.香火庙.keys():
		var 庙: Dictionary = Game.香火庙[cid] as Dictionary
		if bool(庙.get("建造中", false)):
			continue
		总 += int(_香火庙档(int(庙.get("等级", 0))).get("daily_incense_cost", 0))
	return 总

func _抽异端主() -> String:
	var ids: Array = _读表_异端().keys()
	if ids.is_empty():
		return ""
	return str(ids[randi() % ids.size()])

# 每日推进：维护真扣 → 本宗转化 → 异端争夺 → 邸报警讯
func _推进信仰_S34() -> void:
	if not Game.enable_faith_system:
		return
	if 王朝.is_empty() or 郡县状态.is_empty():
		return
	_推进香火庙建造()
	# ① 维护香火「真扣」：不足则全线停摆（不贡献覆盖、也不抗异端）
	var 维护: int = _香火庙维护总额_S34()
	if 维护 > 0:
		var 足: bool = Game.香火值 >= 维护
		if 足:
			Game.香火值 = max(0, Game.香火值 - 维护)
		for cid in Game.香火庙.keys():
			var 庙0: Dictionary = Game.香火庙[cid] as Dictionary
			if bool(庙0.get("建造中", false)):
				continue
			庙0["欠费"] = not 足
			Game.香火庙[cid] = 庙0
	# ② 逐郡推进信仰与异端
	var 国教: Dictionary = _国教配置()
	var 转化倍: float = float(国教.get("convert_mult", 1.0))
	var 异端倍: float = float(国教.get("heresy_mult", 1.0))
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k] as Dictionary
		var 人口: int = int(郡.get("人口", 0))
		if 人口 <= 0:
			continue
		var 覆盖: int = _香火庙覆盖人口(k)
		var 覆盖率: float = clamp(float(覆盖) / float(人口), 0.0, 1.0)
		var 信: Dictionary = _郡信仰取(k)
		var 本宗: float = float(信.get("本宗", 0.0))
		var 异端: float = float(信.get("异端", 0.0))
		var 庙档: Dictionary = _香火庙档(香火庙等级(k))
		var 庙转化: float = float(庙档.get("convert_rate", 1.0))
		var 抗异端: float = float(庙档.get("heresy_resist", 0)) / 100.0
		# 本宗只长在【覆盖人口】上，饱和递减（避免线性灌满）
		本宗 += 信仰转化基率 * 覆盖率 * 庙转化 * 转化倍 * (100.0 - 本宗) / 100.0
		# 异端只长在【未覆盖人口】上
		var 主: String = str(信.get("异端主", ""))
		var 蔓延: float = 1.0
		if 主 != "":
			蔓延 = float(_异端配置(主).get("spread_rate", 1.0))
		异端 += 异端蔓延基率 * (1.0 - 覆盖率) * 蔓延 * 异端倍 * max(0.0, 100.0 - 本宗 - 异端) / 100.0
		异端 = max(0.0, 异端 - 抗异端)
		本宗 = clamp(本宗, 0.0, 100.0)
		异端 = clamp(异端, 0.0, 100.0 - 本宗)
		if 异端 >= 5.0 and 主 == "":
			主 = _抽异端主()
		# 邸报警讯：跨阈值只报一次（离线归来不会刷屏）
		var 阈: float = 20.0
		if 主 != "":
			阈 = float(_异端配置(主).get("threshold", 20.0))
		if 异端 >= 阈 and not bool(信.get("已报警", false)):
			信["已报警"] = true
			_加朝报("警讯", "%s异端炽盛" % str(郡.get("名", "某郡")),
				"%s之徒已聚众 %d%%——未建香火庙处，民心渐失。"
				% [str(_异端配置(主).get("name", "异端")), int(异端)], 2)
		elif 异端 < 阈 - 8.0 and bool(信.get("已报警", false)):
			信["已报警"] = false
		信["本宗"] = 本宗
		信["异端"] = 异端
		信["异端主"] = 主
		郡信仰[k] = 信

# —— 四消费点（缺一个就是死配置）——
# ① 供奉：本宗信仰 ↑ 供奉 ↑；异端超标再打折
func _信仰供奉系数_S34(郡: Dictionary) -> float:
	if not Game.enable_faith_system:
		return 1.0
	var cid: String = str(郡.get("郡ID", ""))
	if cid == "" or not 郡信仰.has(cid):
		return 1.0
	var 信: Dictionary = 郡信仰[cid] as Dictionary
	var 本宗: float = float(信.get("本宗", 0.0))
	var 异端: float = float(信.get("异端", 0.0))
	var 倍: float = 1.0 + 本宗 / 100.0 * 信仰供奉增益 - 异端 / 100.0 * 异端供奉折损
	var 主: String = str(信.get("异端主", ""))
	if 主 != "":
		var 异配: Dictionary = _异端配置(主)
		if 异端 >= float(异配.get("threshold", 20.0)):
			倍 *= float(异配.get("tribute_penalty", 1.0))
	倍 *= float(_国教配置().get("tribute_mult", 1.0))
	return clamp(倍, 信仰系数下限, 信仰系数上限)

# ② 苗子：信众基数大 → 灵根苗子更优
func _信仰苗子系数_S34(郡id: String) -> float:
	if not Game.enable_faith_system:
		return 1.0
	if 郡id == "" or not 郡信仰.has(郡id):
		return 1.0
	var 信: Dictionary = 郡信仰[郡id] as Dictionary
	var 倍: float = 1.0 + float(信.get("本宗", 0.0)) / 100.0 * 信仰苗子增益
	倍 *= float(_国教配置().get("talent_mult", 1.0))
	return clamp(倍, 0.6, 1.5)

# ③ 香火日产（受覆盖人口与上限双重约束，对齐运维封顶 318）
func _信仰香火日产_S34() -> int:
	if not Game.enable_faith_system or 郡县状态.is_empty():
		return 0
	var 总: float = 0.0
	for k in _已解锁凡俗郡_S34():
		if not 郡信仰.has(k):
			continue
		var 信: Dictionary = 郡信仰[k] as Dictionary
		总 += float(信.get("本宗", 0.0)) / 100.0 * (float(_香火庙覆盖人口(k)) / 信仰香火人口基数)
	return int(min(float(信仰香火每日上限), 总 * float(_国教配置().get("incense_mult", 1.0))))

# ④ 愿力月产（愿力已有两处真实消费：香火化愿力 / 愿力升华修为）
func _信仰愿力月产_S34() -> int:
	if not Game.enable_faith_system or 郡县状态.is_empty():
		return 0
	var 总: float = 0.0
	for k in _已解锁凡俗郡_S34():
		if not 郡信仰.has(k):
			continue
		var 信: Dictionary = 郡信仰[k] as Dictionary
		总 += float(信.get("本宗", 0.0)) / 100.0 * (float(_香火庙覆盖人口(k)) / 信仰愿力人口基数)
	return int(min(float(信仰愿力每月上限), 总 * float(_国教配置().get("incense_mult", 1.0))))

# 异端民心惩罚（月度）：按异端人口占比加权
func _信仰民心月修正_S34() -> int:
	if not Game.enable_faith_system or 郡县状态.is_empty():
		return 0
	var 总人口: int = 0
	var 异端口: float = 0.0
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k] as Dictionary
		var p: int = int(郡.get("人口", 0))
		总人口 += p
		if 郡信仰.has(k):
			var 信: Dictionary = 郡信仰[k] as Dictionary
			异端口 += float(p) * float(信.get("异端", 0.0)) / 100.0
	if 总人口 <= 0:
		return 0
	var 罚: float = 异端口 / float(总人口) * 信仰异端民心权重
	for k in _已解锁凡俗郡_S34():
		var 信2: Dictionary = _郡信仰取(k)
		var 主: String = str(信2.get("异端主", ""))
		if 主 == "":
			continue
		if float(信2.get("异端", 0.0)) >= float(_异端配置(主).get("threshold", 20.0)):
			罚 += -float(_异端配置(主).get("morale_penalty", 0.0))
	return -int(max(0.0, 罚))

func 信仰总览_S34() -> Dictionary:
	var 信众: int = 0
	var 覆盖: int = 0
	var 人口总: int = 0
	var 异端总: float = 0.0
	var 郡表: Array = []
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k] as Dictionary
		var p: int = int(郡.get("人口", 0))
		人口总 += p
		var cov: int = _香火庙覆盖人口(k)
		覆盖 += cov
		var 信: Dictionary = _郡信仰取(k)
		信众 += int(float(p) * float(信.get("本宗", 0.0)) / 100.0)
		异端总 += float(p) * float(信.get("异端", 0.0)) / 100.0
		var 庙: Dictionary = _香火庙信息(k)
		郡表.append({
			"郡ID": k,
			"名": str(郡.get("名", "")),
			"人口": p,
			"覆盖": cov,
			"本宗": int(信.get("本宗", 0.0)),
			"异端": int(信.get("异端", 0.0)),
			"异端主": str(信.get("异端主", "")),
			"异端主名": str(_异端配置(str(信.get("异端主", ""))).get("name", "")),
			"庙等级": int(庙.get("等级", 0)),
			"庙名": str(_香火庙档(int(庙.get("等级", 0))).get("name", "无")),
			"建造中": bool(庙.get("建造中", false)),
			"欠费": bool(庙.get("欠费", false)),
		})
	return {
		"总人口": 人口总,
		"总信众": 信众,
		"总覆盖": 覆盖,
		"异端人口": int(异端总),
		"香火日产": _信仰香火日产_S34(),
		"愿力月产": _信仰愿力月产_S34(),
		"民心月修正": _信仰民心月修正_S34(),
		"维护香火": _香火庙维护总额_S34(),
		"国教": str(王朝.get("国教", "")),
		"国教名": str((_读表_国教().get(str(王朝.get("国教", "")), {}) as Dictionary).get("name", "")),
		"郡表": 郡表,
	}

func _信仰补缺() -> void:
	if not (Game.香火庙 is Dictionary):
		Game.香火庙 = {}
	if not (郡信仰 is Dictionary):
		郡信仰 = {}
	if not (Game.信仰表缓存 is Dictionary):
		Game.信仰表缓存 = {}
	if not (Game.enable_faith_system is bool):
		Game.enable_faith_system = true
	for cid in Game.香火庙.keys():
		var 庙: Dictionary = Game.香火庙[cid] as Dictionary
		if not 庙.has("等级"):
			庙["等级"] = 0
		if not 庙.has("建造中"):
			庙["建造中"] = false
		if not 庙.has("完成日"):
			庙["完成日"] = 0
		if not 庙.has("欠费"):
			庙["欠费"] = false
		Game.香火庙[cid] = 庙
	for cid in 郡信仰.keys():
		var 信: Dictionary = 郡信仰[cid] as Dictionary
		if not 信.has("本宗"):
			信["本宗"] = 0.0
		if not 信.has("异端"):
			信["异端"] = 0.0
		if not 信.has("异端主"):
			信["异端主"] = ""
		if not 信.has("已报警"):
			信["已报警"] = false
		郡信仰[cid] = 信

func _结算王朝_S34() -> void:
	if 王朝.is_empty():
		王朝 = _新王朝(1)
	if 郡县状态.is_empty():
		_初始化郡县状态_S34()
	# ① 凡间差事按「游戏日」推进（推演一月 每次只推进 1 游戏日，差事时长以天计，先于月度闸门）
	_推进凡间差事_S34(1)
	_推进委托_S34(1)
	_推进拍卖会_S34(1)   # S34b 通用拍卖会：刷新/大拍触发/到期结算
	_推进传送阵待机_S34(1)   # S34c 传送阵：每日重置次数 + 扣待机成本 + 建造完工
	_推进祥瑞_S34()   # S35-0 祥瑞/异象：日频概率触发（零货币产出）
	_推进朝奏_S34()   # S35-0 朝奏：每现实日一道，三选一待批
	_推进信仰_S34()   # S35-2 国教信仰网络：维护真扣 + 本宗转化 + 异端争夺
	Game._推进誓约_S36()   # S36 心魔誓：现实日推进（心魔日增 / 到期判定 / 请誓生成）
	# 爵位停权考核必须先于供奉计算：停权即刻收回爵位加成，本月供奉就按停权口径结算
	_结算爵位停权_S34()
	# ② 凡间供奉灵石【日频】：每次推演(1累计游戏日)全额加，对齐 S32 领地/运维封顶 318 口径
	var 供奉灵石: int = _郡县供奉灵石_S34()
	if 供奉灵石 > 0:
		Game.灵石 += 供奉灵石
	# ③ 月度闸门：国祚 / 供奉 / 阶段 一律按 30 Game.累计游戏日 = 1 王朝月 结算
	var 日计数: int = int(王朝.get("日计数", 0)) + 1
	王朝["日计数"] = 日计数
	if 日计数 < 王朝月长:
		return
	王朝["日计数"] = 0
	# 朝堂派系月度结算：党争周期 / 掌权更替清算 / 爵位义务 / 外戚索要（S34 批次 2）
	_结算派系_S34()
	_刷新凡间差事榜_S34()
	var 阶配: Dictionary = _王朝阶段配置(str(王朝.get("阶段", "开国")))
	var 国策配: Dictionary = _王朝国策配置(str(王朝.get("国策", "崇道")))
	var 民心: int = int(王朝.get("民心", 60))
	var 国祚: int = int(王朝.get("国祚", 100))
	var drift: int = int(阶配.get("monthly_drift", 0)) if not 阶配.is_empty() else 0
	var 灾郡: int = 0
	for k in 郡县状态.keys():
		if int((郡县状态[k] as Dictionary).get("灾情", 0)) > 0:
			灾郡 += 1
	# ④ 国祚 = 阶段漂移 + 民心修正(±2) - 灾情拖累 - 朝纲腐化 + 皇帝性格
	#    朝纲腐化：不可逆熵增（在位每 24 王朝月 +1）。无此项时「民心拉满」可让国祚永驻盛世，
	#              王朝永不更替 → 改朝换代带来的内容刷新永不发生（S34 防腻机制之一失效）。
	var 腐化: int = int(float(int(王朝.get("在位月", 0))) / 24.0)
	var 变化: int = drift + clamp(int(float(民心 - 50) / 25.0), -2, 2) - 灾郡 - 腐化
	var 帝: Dictionary = 王朝.get("皇帝", {})
	var 性格: String = str(帝.get("性格", "守成"))
	if 性格 == "昏聩":
		变化 -= 2
	elif 性格 == "仁厚" or 性格 == "雄才":
		变化 += 1
	国祚 = clamp(国祚 + 变化, 0, 100)
	王朝["国祚"] = 国祚
	# ⑤ 对宗门关系自然衰减（国策 attitude_decay 驱动；崇道慢、灭法快）
	var 衰减: float = float(国策配.get("attitude_decay", 1.0)) if not 国策配.is_empty() else 1.0
	var 关系: float = float(王朝.get("对宗门关系", 50))
	王朝["对宗门关系"] = clamp(关系 - 王朝关系衰减基数 * 衰减, 0.0, 100.0)
	# ⑥ 民心向中值回归（放任不管既不会永远盛世，也不会立刻崩）
	# 批次 3：断供郡数拖累民心（每郡 -1）。
	#   原实现民心只受灾情影响，而灾情依赖奇遇随机 → 民变触发全看脸，
	#   实测 240 月 0 次触发，违反「条件可预期」原则。改由断供驱动后，
	#   链条变成「感恩崩 → 断供 → 民生凋敝 → 民变 → 国祚跌」，每步玩家都可控可修。
	民心 = clamp(int(lerp(float(民心), 55.0, 0.1)) - 灾郡 - _断供郡数_S34() * 断供民心拖累, 0, 100)
	# 开国建制（官制/律法/国教）月度民心修正：可正可负，玩家选了就要承受
	民心 = clamp(民心 + _开国民心月修正_S34(), 0, 100)
	王朝["民心"] = 民心
	# S35-2 国教信仰网络：异端炽盛拖累民心（月度；不挂这条信仰网络就是纯装饰）
	var 信仰民心: int = _信仰民心月修正_S34()
	if 信仰民心 != 0:
		民心 = clamp(民心 + 信仰民心, 0, 100)
		王朝["民心"] = 民心
	# 愿力月产：信仰度 → 愿力（愿力已有两处真实消费：香火化愿力 / 愿力升华修为）
	var 愿力月产: int = _信仰愿力月产_S34()
	if 愿力月产 > 0:
		Game.愿力 += 愿力月产
		Game.添加纪事("王朝", "信仰愿力", "信众祈愿凝聚，本月愿力+%d（累计%d）" % [愿力月产, Game.愿力], 0)
	# ⑦ 皇帝在位：达预期在位月则驾崩、新帝继位（新帝对宗门更疏远，逼玩家重新经营关系）
	#    原「每12王朝月+1岁、到寿元驾崩」速率远慢于王朝寿命（~40月），继位永不触发，故改为直接判定
	var 在位月: int = int(王朝.get("在位月", 0)) + 1
	王朝["在位月"] = 在位月
	if 在位月 % 12 == 0:
		帝["年龄"] = int(帝.get("年龄", 40)) + 1
		王朝["皇帝"] = 帝
	if 在位月 >= int(王朝.get("预期在位月", 30)):
		_新帝继位_S34(true)
	# ⑧ 王朝事件池（按阶段危机权重 roll，命中则复用奇遇全套机制）
	_尝试王朝事件_S34()
	# ⑧-2 王朝反制：预警 → 生成待决 → 逾期结算（有牙齿的反制）
	_结算王朝反制_S34()
	_结算王朝委托_S34()
	# ⑨ 阶段推进 → 改朝换代
	_保底邸报_S34()   # S35-0 月度保底：本月零邸报则提炼一条
	_邸报异闻_S34()   # 宗门因果征兆：月度至多 1 条异闻
	_推进王朝阶段_S34()
	if int(王朝.get("国祚", 100)) <= 0:
		_改朝换代_S34()
		return
	if 在位月 % 12 == 0:
		Game.添加纪事("王朝", "%s纪年" % str(王朝.get("国号", "?")),
			"在位第%d年：国祚%d 民心%d 关系%d（%s）"
			% [在位月 / 12, int(王朝.get("国祚", 0)), 民心, int(王朝.get("对宗门关系", 0)), str(王朝.get("阶段", "?"))], 0)

# ——— 凡间差事（S34 批次1 主内容）：抄 expedition 双 Dictionary 范式 ———
# 按弟子ID取弟子（game_state 内无同名函数；expedition.gd 的 _获取弟子 不跨文件复用）
# 修（S34批次2）：d.弟子ID 为 int，原 `d.弟子ID == 弟子ID`(String) 恒 false，
#   导致接取/结算凡间差事永远取不到弟子对象（UI 一接即空指针）。现转发既有 int 版 _取弟子。
func _取弟子_S34(弟子ID: String):
	if 弟子ID == "":
		return null
	return Game._取弟子(int(弟子ID))

# P1-4 弟子-凡间情感绑定：为新弟子随机分配故乡郡
func _分配弟子故乡郡(弟子: Disciple) -> void:
	if 弟子 == null:
		return
	# 收集所有凡俗郡
	var 凡俗郡列表: Array = []
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if bool(郡.get("凡俗", false)):
			凡俗郡列表.append({"id": k, "名": str(郡.get("名", "?"))})
	if 凡俗郡列表.is_empty():
		return
	# 随机分配一个故乡郡
	var 选: Dictionary = 凡俗郡列表[randi() % 凡俗郡列表.size()]
	弟子.故乡郡 = str(选.get("id", ""))
	弟子.故乡郡名 = str(选.get("名", ""))
	# 随机分配家人情况
	var 家人池: Array = ["父母健在", "父亲早逝", "母亲早逝", "父母双亡", "有一弟", "有一妹", "有弟妹", "孤儿", "家中独子", "有祖父母"]
	弟子.家人 = 家人池[randi() % 家人池.size()]

# P1-1 办差奇遇决策：玩家选择后继续结算
func 决策办差奇遇(索引: int, 选项索引: int) -> Dictionary:
	if 索引 < 0 or 索引 >= 待决策办差奇遇.size():
		return {"成功": false, "因": "无效的奇遇索引"}
	var 待决: Dictionary = 待决策办差奇遇[索引]
	var 奇遇: Dictionary = 待决.get("奇遇", {})
	var 选项: Array = 奇遇.get("选项", [])
	if 选项索引 < 0 or 选项索引 >= 选项.size():
		return {"成功": false, "因": "无效的选项索引"}

	var 选: Dictionary = 选项[选项索引]
	var 差: Dictionary = 待决.get("差", {})
	var d = _取弟子_S34(str(待决.get("弟子ID", "")))
	var 郡id: String = str(待决.get("郡ID", ""))
	var 有郡: bool = 郡县状态.has(郡id)

	# 应用奇遇选项的修正
	var 基础成功率: float = 0.5
	if d != null:
		var 要求: int = max(1, int(差.get("要求战力", 1)))
		var 比值: float = clamp(float(d.总战力()) / float(要求), 0.0, 2.0)
		基础成功率 = clamp(0.35 + 比值 * 0.3, 0.35, 0.95)
	var 成功率: float = clamp(基础成功率 + float(选.get("成功率", 0)), 0.05, 0.98)
	var 成功: bool = randf() < 成功率

	var 弟子名: String = str(差.get("接取弟子名", "?"))
	var 差名: String = str(差.get("名", "?"))
	var 郡名: String = str(差.get("郡名", "?"))
	var 奇遇名: String = str(奇遇.get("名", ""))

	if 成功:
		if 有郡:
			var 郡: Dictionary = 郡县状态[郡id]
			var 奖励感恩: int = int(差.get("奖励感恩", 0)) + int(选.get("感恩", 0))
			郡["感恩"] = clamp(int(郡.get("感恩", 0)) + 奖励感恩, 0, 100)
			if str(差.get("类型", "")) == "relief":
				郡["灾情"] = 0
			郡县状态[郡id] = 郡
		Game.灵石 += int(差.get("奖励灵石", 0))
		if int(差.get("奖励战功", 0)) > 0:
			Game.加战功(int(float(差.get("奖励战功", 0)) * _派系战功系数_S34() * _开国战功系数_S34()))
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(差.get("奖励感恩", 0)) / 4.0 + float(选.get("关系", 0)), 0.0, 100.0)
		if d != null:
			d.忠诚 = clamp(d.忠诚 + int(选.get("忠诚", 0)), 0, 100)
		Game.添加纪事("王朝", "办差奇遇·成", "%s 在「%s」遇「%s」，选择「%s」，差事告成，%s感恩+%d"
			% [弟子名, 差名, 奇遇名, str(选.get("文", "")), 郡名, int(差.get("奖励感恩", 0)) + int(选.get("感恩", 0))], 1)
		if str(差.get("类型", "")) == "scout":
			_寻访灵根得苗子_S34(郡id)
	else:
		if 有郡:
			var 郡2: Dictionary = 郡县状态[郡id]
			郡2["感恩"] = clamp(int(郡2.get("感恩", 0)) + int(差.get("惩罚感恩", 0)) + int(选.get("感恩", 0)) / 2, 0, 100)
			郡县状态[郡id] = 郡2
		if d != null:
			d.忠诚 = clamp(d.忠诚 + int(差.get("惩罚忠诚", 0)) + int(选.get("忠诚", 0)), 0, 100)
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(差.get("惩罚感恩", 0)) / 4.0 + float(选.get("关系", 0)), 0.0, 100.0)
		_反制_办差失利_S34(郡id)
		Game.添加纪事("王朝", "办差奇遇·败", "%s 在「%s」遇「%s」，选择「%s」，差事失利"
			% [弟子名, 差名, 奇遇名, str(选.get("文", ""))], 2)

	待决策办差奇遇.remove_at(索引)
	return {"成功": true, "摘要": "已决策：%s" % str(选.get("文", "")), "差事成功": 成功}

# P1-4 弟子-凡间情感绑定：检查弟子是否在故乡郡办差
func _弟子在故乡办差(弟子: Disciple, 郡id: String) -> bool:
	if 弟子 == null or 弟子.故乡郡 == "" or 郡id == "":
		return false
	return 弟子.故乡郡 == 郡id
# 刷新差事榜：从 dynasty_decree_config.csv 模板抽 N 条挂榜（每月一刷，过期未接自动下榜）
func _刷新凡间差事榜_S34() -> void:
	var 模板表: Array = _读差事模板表()
	var 候选郡: Array = _已解锁凡俗郡_S34()
	if 模板表.is_empty() or 候选郡.is_empty():
		return
	凡间差事榜.clear()
	var 已选: Array = []
	var 尝试: int = 0
	while 凡间差事榜.size() < _爵位差事榜上限_S34() and 尝试 < 40:
		尝试 += 1
		var 模板: Dictionary = 模板表[randi() % 模板表.size()]
		var tid: String = str(模板.get("decree_id", ""))
		if tid == "" or 已选.has(tid):
			continue
		已选.append(tid)
		var 郡id: String = str(候选郡[randi() % 候选郡.size()])
		凡间差事榜[tid] = {
			"差事ID": tid,
			"名": str(模板.get("decree_name", "")),
			"类型": str(模板.get("decree_type", "")),
			"难度": int(模板.get("difficulty", 1)),
			"要求境界": str(模板.get("require_realm", "练气")),
			"要求战力": int(模板.get("require_power", 0)),
			"耗时天": int(模板.get("duration_days", 3)),
			"郡ID": 郡id,
			"郡名": str((郡县状态[郡id] as Dictionary).get("名", "")),
			"奖励感恩": int(模板.get("reward_gratitude", 0)),
			"奖励灵石": int(模板.get("reward_lingshi", 0)),
			"奖励战功": int(模板.get("reward_merit", 0)),
			"惩罚感恩": int(模板.get("penalty_gratitude", 0)),
			"惩罚忠诚": int(模板.get("penalty_loyalty", 0)),
			"发布方": "朝廷",
			"状态": "招募中",
			"接取弟子ID": "",
			"接取弟子名": "",
			"到期日": 0,
		}
# 接取差事：校验境界（Disciple.境界序 唯一真源）/ 战力 / 状态，移入进行中并记到期日
func 接取凡间差事_S34(差事ID: String, 弟子ID: String) -> Dictionary:
	if not 凡间差事榜.has(差事ID):
		return {"成功": false, "原因": "该差事已下榜"}
	var d = _取弟子_S34(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	if _弟子被扣押中_S34(弟子ID):
		return {"成功": false, "原因": "该弟子遭郡守羁押，无法领命"}
	var 差: Dictionary = 凡间差事榜[差事ID]
	var 需境: String = str(差.get("要求境界", "练气"))
	var 需序: int = Disciple.境界序.find(需境)
	var 实序: int = Disciple.境界序.find(d.境界)
	if 需序 >= 0 and 实序 < 需序:
		return {"成功": false, "原因": "%s 修为不足（需%s）" % [d.姓名, 需境]}
	var 需战力: int = int(差.get("要求战力", 0))
	if d.总战力() < 需战力:
		return {"成功": false, "原因": "%s 道行不足（需%d）" % [d.姓名, 需战力]}
	if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
		return {"成功": false, "原因": "%s 无法出行" % d.姓名}
	for k in 凡间差事进行中.keys():
		if str((凡间差事进行中[k] as Dictionary).get("接取弟子ID", "")) == 弟子ID:
			return {"成功": false, "原因": "%s 已有差事在身" % d.姓名}
	差["状态"] = "执行中"
	差["接取弟子ID"] = 弟子ID
	差["接取弟子名"] = d.姓名
	差["到期日"] = Game.累计游戏日 + int(差.get("耗时天", 3))
	凡间差事进行中[差事ID] = 差
	凡间差事榜.erase(差事ID)
	Game.添加纪事("王朝", "奉差出行", "%s 领命前往%s办理「%s」，约%d日"
		% [d.姓名, str(差.get("郡名", "")), str(差.get("名", "")), int(差.get("耗时天", 3))], 1)
	return {"成功": true, "消息": "%s 已领差事「%s」" % [d.姓名, str(差.get("名", ""))]}
# 按「游戏日」推进差事（挂 _结算王朝_S34 开头，先于月度闸门；到期即结算）
func _推进凡间差事_S34(天: int) -> void:
	if 凡间差事进行中.is_empty():
		return
	var 到期的: Array = []
	for k in 凡间差事进行中.keys():
		var 差: Dictionary = 凡间差事进行中[k]
		if Game.累计游戏日 >= int(差.get("到期日", 0)):
			到期的.append(k)
	for k in 到期的:
		_结算凡间差事_S34(str(k))
# 差事结算：成功率 = 0.35 + 战力/要求战力 × 0.3（封顶 0.95），失败照罚且留痕
# P1-2 王朝奇观系统：玩家可以推动王朝建造奇观，获得永久加成
var _王朝奇观配置: Array = [
	{
		"id": "tongtian_ta",
		"名": "通天塔",
		"描述": "沟通天地的通天高塔，建成后宗门修炼速度+10%",
		"成本灵石": 5000,
		"成本香火": 1000,
		"建造月数": 12,
		"效果": "修炼+10%",
		"门槛爵位": "国师"
	},
	{
		"id": "zhenduo_ding",
		"名": "镇国鼎",
		"描述": "镇压王朝气运的九鼎之一，建成后王朝国祚+20，供奉+15%",
		"成本灵石": 8000,
		"成本香火": 2000,
		"建造月数": 18,
		"效果": "国祚+20，供奉+15%",
		"门槛爵位": "国师"
	},
	{
		"id": "longmai_altar",
		"名": "龙脉祭坛",
		"描述": "祭祀王朝龙脉的祭坛，建成后灵根苗子资质+1档概率",
		"成本灵石": 10000,
		"成本香火": 3000,
		"建造月数": 24,
		"效果": "苗子资质+",
		"门槛爵位": "帝师"
	},
	{
		"id": "fengchan_terrace",
		"名": "封禅台",
		"描述": "祭天封禅的神圣高台，建成后宗门气运+20，功德获取+20%",
		"成本灵石": 15000,
		"成本香火": 5000,
		"建造月数": 36,
		"效果": "气运+20，功德+20%",
		"门槛爵位": "监国"
	}
]

# P1-2 建造中的奇观

# ============ P1-2 王朝奇观建造系统 ============

## 获取所有奇观列表（含建造状态）
func 获取所有奇观列表() -> Array:
	var 结果: Array = []
	for cfg in _王朝奇观配置:
		var 奇观ID: String = str(cfg.get("id", ""))
		var 已建造: bool = false
		var 建造中: bool = false
		var 已建月: int = 0
		var 总月数: int = int(cfg.get("建造月数", 12))
		# 检查是否已建造
		for w in 王朝奇观:
			if str(w.get("id", "")) == 奇观ID:
				已建造 = true
				break
		# 检查是否建造中
		for w in 建造中奇观:
			if str(w.get("id", "")) == 奇观ID:
				建造中 = true
				已建月 = int(w.get("已建月", 0))
				break
		# 检查门槛
		var 当前爵位: String = str(王朝.get("宗门爵位", "未册封"))
		var 门槛爵位: String = str(cfg.get("门槛爵位", "国师"))
		var 爵位序: Array = ["未册封", "国师", "帝师", "监国", "摄政王"]
		var 当前序: int = 爵位序.find(当前爵位)
		var 门槛序: int = 爵位序.find(门槛爵位)
		var 可建造: bool = (当前序 >= 门槛序) and (not 已建造) and (not 建造中)
		结果.append({
			"id": 奇观ID,
			"名": str(cfg.get("名", "")),
			"描述": str(cfg.get("描述", "")),
			"成本灵石": int(cfg.get("成本灵石", 0)),
			"成本香火": int(cfg.get("成本香火", 0)),
			"建造月数": 总月数,
			"效果": str(cfg.get("效果", "")),
			"门槛爵位": 门槛爵位,
			"已建造": 已建造,
			"建造中": 建造中,
			"已建月": 已建月,
			"进度": float(已建月) / float(总月数) if 总月数 > 0 else 0.0,
			"可建造": 可建造
		})
	return 结果


## 开始建造奇观
func 开始建造奇观(奇观ID: String) -> Dictionary:
	# 查找配置
	var 配置: Dictionary = {}
	for cfg in _王朝奇观配置:
		if str(cfg.get("id", "")) == 奇观ID:
			配置 = cfg
			break
	if 配置.is_empty():
		return {"成功": false, "原因": "未找到该奇观配置"}
	# 检查是否已建造
	for w in 王朝奇观:
		if str(w.get("id", "")) == 奇观ID:
			return {"成功": false, "原因": "该奇观已建造"}
	# 检查是否建造中
	for w in 建造中奇观:
		if str(w.get("id", "")) == 奇观ID:
			return {"成功": false, "原因": "该奇观正在建造中"}
	# 检查爵位门槛
	var 当前爵位: String = str(王朝.get("宗门爵位", "未册封"))
	var 门槛爵位: String = str(配置.get("门槛爵位", "国师"))
	var 爵位序: Array = ["未册封", "国师", "帝师", "监国", "摄政王"]
	var 当前序: int = 爵位序.find(当前爵位)
	var 门槛序: int = 爵位序.find(门槛爵位)
	if 当前序 < 门槛序:
		return {"成功": false, "原因": "爵位不足，需要%s及以上爵位" % 门槛爵位}
	# 检查资源
	var 成本灵石: int = int(配置.get("成本灵石", 0))
	var 成本香火: int = int(配置.get("成本香火", 0))
	if Game.灵石 < 成本灵石:
		return {"成功": false, "原因": "灵石不足，需要%d灵石" % 成本灵石}
	# 扣除资源（香火可能为0，不强制检查）
	Game.灵石 -= 成本灵石
	# 开始建造
	建造中奇观.append({
		"id": 奇观ID,
		"名": str(配置.get("名", "")),
		"已建月": 0,
		"总月数": int(配置.get("建造月数", 12)),
		"开始日": Game.累计游戏日
	})
	return {"成功": true, "原因": "「%s」已开工，预计%d个月后建成" % [str(配置.get("名", "")), int(配置.get("建造月数", 12))]}


## 推进奇观建造（月度推演调用）
func 推进奇观建造_S34(月数: int) -> void:
	if 建造中奇观.is_empty():
		return
	var 完成列表: Array = []
	for i in range(建造中奇观.size() - 1, -1, -1):
		var w: Dictionary = 建造中奇观[i]
		var 已建月: int = int(w.get("已建月", 0)) + 月数
		var 总月数: int = int(w.get("总月数", 12))
		if 已建月 >= 总月数:
			# 建造完成
			var 奇观ID: String = str(w.get("id", ""))
			王朝奇观.append({
				"id": 奇观ID,
				"名": str(w.get("名", "")),
				"完成日": Game.累计游戏日
			})
			完成列表.append(str(w.get("名", "")))
			建造中奇观.remove_at(i)
			# 触发里程碑
			_检查奇观里程碑(奇观ID)
		else:
			w["已建月"] = 已建月
			建造中奇观[i] = w
	# 记录通知
	if not 完成列表.is_empty():
		for 名 in 完成列表:
			_添加结算通知_S34({"类型": "奇观", "名称": str(名), "价": 0, "文本": "奇观「%s」建成，效果已生效" % 名, "日": Game.累计游戏日})


## 检查奇观里程碑
func _检查奇观里程碑(奇观ID: String) -> void:
	# 首座奇观建成
	if 王朝奇观.size() == 1:
		for i in range(_王朝里程碑.size()):
			var m: Dictionary = _王朝里程碑[i]
			if str(m.get("id", "")) == "first_wonder" and not bool(m.get("已触发", false)):
				_王朝里程碑[i]["已触发"] = true
				Game.灵石 += int(m.get("奖励灵石", 0))
				_添加结算通知_S34({"类型": "里程碑", "名称": str(m.get("名", "")), "价": int(m.get("奖励灵石", 0)), "文本": "里程碑「%s」达成，奖励%d灵石" % [str(m.get("名", "")), int(m.get("奖励灵石", 0))], "日": Game.累计游戏日})
				break


## 获取奇观总效果
func 获取奇观总效果() -> Dictionary:
	var 效果: Dictionary = {
		"修炼加成": 0.0,
		"供奉加成": 0.0,
		"国祚加成": 0,
		"气运加成": 0,
		"功德加成": 0.0,
		"苗子资质加成": 0.0
	}
	for w in 王朝奇观:
		var 奇观ID: String = str(w.get("id", ""))
		match 奇观ID:
			"tongtian_ta":
				效果["修炼加成"] += 0.10
			"zhenduo_ding":
				效果["国祚加成"] += 20
				效果["供奉加成"] += 0.15
			"longmai_altar":
				效果["苗子资质加成"] += 0.10
			"fengchan_terrace":
				效果["气运加成"] += 20
				效果["功德加成"] += 0.20
	return 效果

# P1-2 王朝里程碑事件：达成特定条件时触发特殊事件
var _王朝里程碑: Array = [
	{
		"id": "first_title",
		"名": "初受册封",
		"描述": "宗门首次受封王朝爵位，正统性确立",
		"条件": "首次受封爵位",
		"奖励灵石": 1000,
		"奖励声望": 50,
		"已触发": false
	},
	{
		"id": "ten_disciples",
		"名": "弟子满门",
		"描述": "宗门弟子达到10人，香火鼎盛",
		"条件": "弟子数≥10",
		"奖励灵石": 500,
		"奖励香火": 200,
		"已触发": false
	},
	{
		"id": "first_wonder",
		"名": "奇观初成",
		"描述": "王朝第一座奇观建成，气运昌隆",
		"条件": "首座奇观建成",
		"奖励灵石": 2000,
		"奖励声望": 100,
		"已触发": false
	},
	{
		"id": "dynasty_change",
		"名": "改朝换代",
		"描述": "经历第一次改朝换代，宗门存续",
		"条件": "经历改朝换代",
		"奖励灵石": 3000,
		"奖励声望": 200,
		"已触发": false
	},
	{
		"id": "all_counties",
		"名": "天下归心",
		"描述": "所有凡俗郡感恩度≥80，宗门威望达顶峰",
		"条件": "全郡感恩≥80",
		"奖励灵石": 5000,
		"奖励声望": 500,
		"已触发": false
	}
]

# P1-2 检查并触发王朝里程碑
func _检查王朝里程碑() -> void:
	for i in range(_王朝里程碑.size()):
		var 里程碑: Dictionary = _王朝里程碑[i]
		if bool(里程碑.get("已触发", false)):
			continue
		var 触发: bool = false
		match str(里程碑.get("id", "")):
			"first_title":
				触发 = str(王朝.get("宗门爵位", "未册封")) != "未册封"
			"ten_disciples":
				触发 = Game.弟子列表.size() >= 10
			"first_wonder":
				触发 = 王朝奇观.size() >= 1
			"dynasty_change":
				触发 = int(王朝.get("朝代序", 1)) >= 2
			"all_counties":
				var 全高: bool = true
				for k in 郡县状态.keys():
					var 郡: Dictionary = 郡县状态[k]
					if bool(郡.get("凡俗", false)) and int(郡.get("感恩", 0)) < 80:
						全高 = false
						break
				触发 = 全高
		if 触发:
			里程碑["已触发"] = true
			_王朝里程碑[i] = 里程碑
			Game.灵石 += int(里程碑.get("奖励灵石", 0))
			Game._加声望(int(里程碑.get("奖励声望", 0)))
			Game.添加纪事("王朝", "里程碑", "达成「%s」：%s，奖励灵石%d、Game.声望%d"
				% [str(里程碑.get("名", "")), str(里程碑.get("描述", "")), int(里程碑.get("奖励灵石", 0)), int(里程碑.get("奖励声望", 0))], 1)

# P1-1 办差奇遇池：弟子办差时可能遇到的突发事件，玩家远程决策
var _办差奇遇池: Array = [
	{
		"名": "豪强囤粮",
		"描述": "当地豪强趁灾囤粮，哄抬粮价，弟子请命如何处置？",
		"选项": [
			{"文": "强征开仓", "成功率": -0.1, "感恩": 15, "忠诚": -5, "关系": -5, "描述": "强行开仓放粮，百姓感恩但豪强怨恨"},
			{"文": "协商平价", "成功率": 0.05, "感恩": 8, "忠诚": 0, "关系": 0, "描述": "与豪强协商，平价售粮，皆大欢喜"},
			{"文": "上报朝廷", "成功率": 0.1, "感恩": -5, "忠诚": 5, "关系": 10, "描述": "上报朝廷处理，朝廷满意但百姓失望"}
		]
	},
	{
		"名": "妖兽袭村",
		"描述": "妖兽趁夜袭击村落，弟子请命如何应对？",
		"选项": [
			{"文": "亲自斩杀", "成功率": -0.15, "感恩": 20, "忠诚": 10, "关系": 0, "描述": "弟子亲自出战斩杀妖兽，百姓感恩戴德但有风险"},
			{"文": "设阵围困", "成功率": 0.05, "感恩": 10, "忠诚": 0, "关系": 5, "描述": "设阵法围困妖兽，稳妥但耗时"},
			{"文": "疏散百姓", "成功率": 0.1, "感恩": 5, "忠诚": -5, "关系": 0, "描述": "先疏散百姓，妖兽自行离去，安全但无建树"}
		]
	},
	{
		"名": "贪官索贿",
		"描述": "当地贪官向弟子索贿，否则暗中使绊，弟子请命如何应对？",
		"选项": [
			{"文": "严词拒绝", "成功率": -0.1, "感恩": 10, "忠诚": 10, "关系": -10, "描述": "严词拒绝贪官，百姓称赞但关系恶化"},
			{"文": "虚与委蛇", "成功率": 0.05, "感恩": 0, "忠诚": -5, "关系": 5, "描述": "表面应付，暗中收集证据，稳妥但弟子不齿"},
			{"文": "举报弹劾", "成功率": -0.05, "感恩": 15, "忠诚": 5, "关系": -5, "描述": "收集证据举报弹劾，风险大但收益高"}
		]
	},
	{
		"名": "灵童现世",
		"描述": "当地发现一名天赋异禀的孩童，弟子请命如何处置？",
		"选项": [
			{"文": "带回宗门", "成功率": 0.1, "感恩": -10, "忠诚": 5, "关系": 0, "描述": "将灵童带回宗门培养，宗门得才但百姓失望"},
			{"文": "当地培养", "成功率": 0.05, "感恩": 15, "忠诚": 0, "关系": 5, "描述": "留在当地培养，定期指导，百姓感恩"},
			{"文": "上报朝廷", "成功率": 0.0, "感恩": 5, "忠诚": -5, "关系": 10, "描述": "上报朝廷，由朝廷处置，朝廷满意但弟子不甘"}
		]
	},
	{
		"名": "瘟疫蔓延",
		"描述": "当地突发瘟疫，弟子请命如何应对？",
		"选项": [
			{"文": "施药救治", "成功率": -0.1, "感恩": 25, "忠诚": 5, "关系": 0, "描述": "宗门丹药救治百姓，消耗大但感恩戴德"},
			{"文": "隔离防控", "成功率": 0.05, "感恩": 10, "忠诚": 0, "关系": 5, "描述": "隔离疫区，防控蔓延，稳妥但见效慢"},
			{"文": "封锁逃离", "成功率": 0.1, "感恩": -15, "忠诚": -10, "关系": 5, "描述": "封锁疫区撤离，保全弟子但百姓遭殃"}
		]
	}
]

# P1-1 待决策办差奇遇列表

func _结算凡间差事_S34(差事ID: String) -> void:
	if not 凡间差事进行中.has(差事ID):
		return
	var 差: Dictionary = 凡间差事进行中[差事ID]
	凡间差事进行中.erase(差事ID)
	var d = _取弟子_S34(str(差.get("接取弟子ID", "")))
	var 郡id: String = str(差.get("郡ID", ""))
	var 有郡: bool = 郡县状态.has(郡id)

	# P1-1 办差奇遇：30%概率触发，触发后暂停结算等待玩家决策
	if randf() < 0.3 and d != null:
		var 奇遇: Dictionary = _办差奇遇池[randi() % _办差奇遇池.size()]
		var 待决: Dictionary = {
			"差事ID": 差事ID,
			"差": 差,
			"弟子ID": str(差.get("接取弟子ID", "")),
			"郡ID": 郡id,
			"奇遇": 奇遇,
			"已选择": -1
		}
		待决策办差奇遇.append(待决)
		Game.添加纪事("王朝", "办差奇遇", "%s 在「%s」遇到「%s」，等待宗主决策"
			% [str(差.get("接取弟子名", "?")), str(差.get("名", "?")), str(奇遇.get("名", ""))], 1)
		return
	var 成功率: float = 0.5
	var 故乡加成: bool = false
	if d != null:
		var 要求: int = max(1, int(差.get("要求战力", 1)))
		var 比值: float = clamp(float(d.总战力()) / float(要求), 0.0, 2.0)
		成功率 = clamp(0.35 + 比值 * 0.3, 0.35, 0.95)
		# P1-4 弟子-凡间情感绑定：派回故乡办差有成功率+20%、感恩+50%加成
		if _弟子在故乡办差(d, 郡id):
			故乡加成 = true
			成功率 = clamp(成功率 + 0.2, 0.0, 0.98)
	var 成功: bool = randf() < 成功率
	var 弟子名: String = str(差.get("接取弟子名", "?"))
	var 差名: String = str(差.get("名", "?"))
	var 郡名: String = str(差.get("郡名", "?"))
	if 成功:
		if 有郡:
			var 郡: Dictionary = 郡县状态[郡id]
			var 奖励感恩: int = int(差.get("奖励感恩", 0))
			# P1-4 故乡加成：感恩+50%
			if 故乡加成:
				奖励感恩 = int(奖励感恩 * 1.5)
			郡["感恩"] = clamp(int(郡.get("感恩", 0)) + 奖励感恩, 0, 100)
			if str(差.get("类型", "")) == "relief":
				郡["灾情"] = 0
			郡县状态[郡id] = 郡
		Game.灵石 += int(差.get("奖励灵石", 0))
		if int(差.get("奖励战功", 0)) > 0:
			# 派系掌权后果：边将 1.60（战功机会大增）、宦官 0.85（S34 批次 2）
			Game.加战功(int(float(差.get("奖励战功", 0)) * _派系战功系数_S34() * _开国战功系数_S34()))
		# 对宗门关系回升（替朝廷办差 → 朝廷对宗门好感上升；唯一回升通道）
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(差.get("奖励感恩", 0)) / 4.0, 0.0, 100.0)
		# P1-4 故乡加成纪事
		var 故乡标记: String = "（衣锦还乡）" if 故乡加成 else ""
		var 实际感恩: int = int(差.get("奖励感恩", 0))
		if 故乡加成:
			实际感恩 = int(实际感恩 * 1.5)
		Game.添加纪事("王朝", "差事告成", "%s 办成「%s」%s，%s感恩+%d"
			% [弟子名, 差名, 故乡标记, 郡名, 实际感恩], 1)
		if str(差.get("类型", "")) == "scout":
			_寻访灵根得苗子_S34(郡id)
	else:
		if 有郡:
			var 郡2: Dictionary = 郡县状态[郡id]
			郡2["感恩"] = clamp(int(郡2.get("感恩", 0)) + int(差.get("惩罚感恩", 0)), 0, 100)
			郡县状态[郡id] = 郡2
		if d != null:
			d.忠诚 = clamp(d.忠诚 + int(差.get("惩罚忠诚", 0)), 0, 100)
		# 办砸差事 → 朝堂迁怒宗门（惩罚感恩为负值）
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(差.get("惩罚感恩", 0)) / 4.0, 0.0, 100.0)
		# 批次 3：办差失利埋点 —— 郡守是否借机扣人取决于该郡感恩（玩家可预防，非纯随机）
		_反制_办差失利_S34(郡id)
		Game.添加纪事("王朝", "差事失利", "%s 未能办成「%s」，%s感恩%d"
			% [弟子名, 差名, 郡名, int(差.get("惩罚感恩", 0))], 2)
# 灵根寻访产出苗子：资质按当前王朝阶段权重 roll（乱世出英杰 —— 核心两难的另一半）
func _寻访灵根得苗子_S34(郡id: String) -> void:
	# 禁传道标记：该郡不再供给灵根苗子（反制的实质后果，不接就是空气）
	if _郡有标记_S34(郡id, "禁传道"):
		Game.添加纪事("王朝", "禁绝传道", "%s禁绝传道，寻访灵根无果" % str((郡县状态[郡id] as Dictionary).get("名", "该郡")), 1)
		return
	var 阶配: Dictionary = _王朝阶段配置(str(王朝.get("阶段", "开国")))
	var 权重: Dictionary = {
		"fan_su": float(阶配.get("t_w_fan_su", 50.0)),
		"pingyong": float(阶配.get("t_w_pingyong", 30.0)),
		"youliang": float(阶配.get("t_w_youliang", 14.0)),
		"tiancai": float(阶配.get("t_w_tiancai", 5.0)),
		"yaonie": float(阶配.get("t_w_yaonie", 0.9)),
		"kuangshi": float(阶配.get("t_w_kuangshi", 0.1)),
	}
	# 派系掌权后果：士族 1.30（苗子质量显著提升）、宦官 0.85
	# 高资质权重 ×系数、凡俗权重 ÷系数 —— 单系数即可让整条分布整体平移
	var 苗子系数: float = _派系苗子系数_S34() * _开国苗子系数_S34() * _信仰苗子系数_S34(郡id)
	if 苗子系数 != 1.0:
		权重["tiancai"] = float(权重.get("tiancai", 5.0)) * 苗子系数
		权重["yaonie"] = float(权重.get("yaonie", 0.9)) * 苗子系数
		权重["kuangshi"] = float(权重.get("kuangshi", 0.1)) * 苗子系数
		权重["fan_su"] = float(权重.get("fan_su", 50.0)) / 苗子系数
	var 新徒: Disciple = Game.招收弟子()
	新徒.资质 = 新徒.加权随机(权重)
	新徒.战力 = 新徒.计算战力()
	Game.添加纪事("王朝", "寻得灵根", "于%s寻得灵根孩童%s（资质：%s），已收入门下"
		% [str((郡县状态[郡id] as Dictionary).get("名", "?")), 新徒.姓名, str(Disciple.资质显示.get(新徒.资质, "?"))], 1)

# 王朝事件池：按阶段危机权重 roll，命中则复用奇遇全套机制（选项 / 冷却 / 纪事 / 信号）
# 载体：奇遇机制以弟子为主体，故取「在宗弟子中境界最高者」为经手人
#       （Quest._抽csv事件 按 unlock_realm ≤ 弟子境界 过滤，选最高境界方可解锁金丹/元婴级事件）
# 频率：月度结算调用一次；基数 0.55 × 阶段危机权重（开国0.50/盛世0.55/中衰0.66/乱世0.83）
func _尝试王朝事件_S34() -> void:
	var 阶配: Dictionary = _王朝阶段配置(str(王朝.get("阶段", "开国")))
	var 危机权重: float = float(阶配.get("crisis_weight", 1.0)) if not 阶配.is_empty() else 1.0
	# 派系掌权后果：边将 1.35（兵祸频发）、士族 0.90 —— 危机频率随掌权派系波动（批次 2）
	var 派系危机: float = _派系危机系数_S34()
	var 概率: float = clamp(0.55 * 危机权重 * 派系危机, 0.15, 0.85)
	if randf() > 概率:
		return
	var 经手: Disciple = null
	var 最高序: int = -1
	for d in Game.弟子列表:
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		var 序: int = Disciple.境界序.find(d.境界)
		if 序 > 最高序:
			最高序 = 序
			经手 = d
	if 经手 == null:
		return
	Game._尝试触发奇遇(经手, "凡人王朝")

# 王朝字典补缺：批次 3 新增字段（爵位停权/待决反制/押注皇子ID/上次反制月）在旧档里不存在，
# 统一在此补齐，避免散落各处的 get 兜底写得参差不齐（S31 血泪：漏一处就串档）。
# new_game 路径由 _新王朝() 工厂直接带上，改朝换代复用同一工厂 → 两条路径都覆盖。
func _王朝补缺_S34() -> void:
	if 王朝.get("爵位停权", null) == null:
		王朝["爵位停权"] = false
	if 王朝.get("待决反制", null) == null:
		王朝["待决反制"] = []
	if 王朝.get("待决委托", null) == null:
		王朝["待决委托"] = []
	if 王朝.get("委托冷却", null) == null:
		王朝["委托冷却"] = {}
	if 王朝.get("押注皇子ID", null) == null:
		王朝["押注皇子ID"] = ""
	if 王朝.get("上次反制月", null) == null:
		王朝["上次反制月"] = -99
	if 王朝.get("皇子", null) == null:
		王朝["皇子"] = []
	if 王朝.get("上次扶持月", null) == null:
		王朝["上次扶持月"] = -99
	if 王朝.get("上次索要月", null) == null:
		王朝["上次索要月"] = -99
	if 王朝.get("上次荐举月", null) == null:
		王朝["上次荐举月"] = -99
	if 王朝.get("预期在位月", null) == null:
		王朝["预期在位月"] = 30
	if 王朝.get("反制冷却", null) == null:
		王朝["反制冷却"] = {}
	if 王朝.get("被扣押弟子", null) == null:
		王朝["被扣押弟子"] = []
	# 旧档郡县状态缺 郡ID / 标记，按 key 补齐（不升 SAVE_VERSION）
	for _k in 郡县状态.keys():
		var _郡: Dictionary = 郡县状态[_k]
		if _郡.get("郡ID", null) == null:
			_郡["郡ID"] = str(_k)
		if _郡.get("标记", null) == null:
			_郡["标记"] = []
		郡县状态[_k] = _郡

# ============ S34 批次 2：朝堂派系（党争周期）+ 册封位阶（契约） ============
# ============ S34 批次 3：王朝反制（有牙齿） ============
# P3 原则：条件可预期（每条都有 warn_value 预警级）、手段可对冲（每条都有 opt_label）、
#          绝不做纯随机掉血（触发条件全是玩家可观测可预防的状态量）。
# 老大拍板「可转化为机会」：应对得当有 convert_effect 正收益 —— 拒强征反而收买民心、
# 催化乱世，把「缺天才弟子时主动推动乱世」从一句设计意图变成玩家手里的开关。
func _读反制配置() -> Array:
	return Game._CSV去BOM("res://config/dynasty_counter_config.csv")
func _反制配置(反制ID: String) -> Dictionary:
	for r in _读反制配置():
		if str((r as Dictionary).get("counter_id", "")) == 反制ID:
			return r as Dictionary
	return {}
# 供奉月收入（反制成本按 cost_rate 比例取，随版图规模自动缩放，不写死绝对值）
func _供奉月收入_S34() -> int:
	return int(float(_郡县供奉灵石_S34()) * float(王朝月长))
func _反制成本_S34(配: Dictionary) -> int:
	var 率: float = float(配.get("cost_rate", 0.0))
	var 低: int = int(配.get("cost_min", 0))
	var 高: int = int(配.get("cost_max", 0))
	if 率 <= 0.0:
		return 低
	var 额: int = int(float(_供奉月收入_S34()) * 率)
	return clamp(额, 低, 高)
# 转化效果解析：CSV 写 "gratitude+8|mind+5|dynasty-3"，全数据驱动，不把魔法数字埋进代码
func _解析转化效果_S34(文本: String) -> Array:
	var 出: Array = []
	var 原: String = 文本.strip_edges()
	if 原 == "" or 原 == "none":
		return 出
	for 段 in 原.split("|"):
		var 项: String = str(段).strip_edges()
		if 项 == "":
			continue
		var 符: int = 项.find("+")
		var 方向: int = 1
		if 符 < 0:
			符 = 项.find("-")
			方向 = -1
		if 符 <= 0:
			continue
		var 键: String = 项.substr(0, 符).strip_edges()
		var 值: int = int(项.substr(符 + 1).strip_edges()) * 方向
		出.append({"键": 键, "值": 值})
	return 出
# 施加转化效果（键：mind 民心 / dynasty 国祚 / gratitude 该郡感恩 / relation 关系）
func _施加转化效果_S34(效: Array, 郡id: String) -> void:
	for e in 效:
		var 键: String = str((e as Dictionary).get("键", ""))
		var 值: int = int((e as Dictionary).get("值", 0))
		if 键 == "mind":
			王朝["民心"] = clamp(int(王朝.get("民心", 60)) + 值, 0, 100)
		elif 键 == "dynasty":
			王朝["国祚"] = clamp(int(王朝.get("国祚", 100)) + 值, 0, 100)
		elif 键 == "relation":
			var 关: float = float(王朝.get("对宗门关系", 50.0))
			王朝["对宗门关系"] = clamp(关 + float(值), 0.0, 100.0)
		elif 键 == "gratitude" and 郡id != "" and 郡县状态.has(郡id):
			var 郡: Dictionary = 郡县状态[郡id]
			郡["感恩"] = clamp(int(郡.get("感恩", 0)) + 值, 0, 100)
			郡县状态[郡id] = 郡
# 触发判定：全部基于玩家可观测的状态量，无一处纯随机
func _反制触发判定_S34(配: Dictionary, 郡id: String) -> bool:
	var 种类: String = str(配.get("trigger_kind", ""))
	var 阈: int = int(配.get("trigger_value", 0))
	var 关系: float = float(王朝.get("对宗门关系", 50.0))
	if 种类 == "dynasty_low":
		return int(王朝.get("国祚", 100)) < 阈 and 关系 >= 60.0
	if 种类 == "relation_low":
		return 关系 < float(阈)
	if 种类 == "mind_low":
		return int(王朝.get("民心", 60)) < 阈
	if 种类 == "policy_miefa":
		return str(王朝.get("国策", "崇道")) == "灭法" and 关系 < float(阈)
	if 种类 == "composite":
		if 关系 >= float(阈):
			return false
		return int(王朝.get("国祚", 100)) < 灭法令国祚线 or Game.业力 >= 灭法令业力线
	if 种类 == "gratitude_low" or 种类 == "decree_fail":
		if 郡id == "" or not 郡县状态.has(郡id):
			return false
		var 郡: Dictionary = 郡县状态[郡id]
		return int(郡.get("感恩", 100)) < 阈
	return false
# 预警：触及 warn_value 先告警，不生成待决 —— 给玩家时间补救（P3「条件可预期」）
func _反制预警判定_S34(配: Dictionary, 郡id: String) -> bool:
	var 种类: String = str(配.get("trigger_kind", ""))
	var 警: int = int(配.get("warn_value", 0))
	if 警 <= 0:
		return false
	var 关系: float = float(王朝.get("对宗门关系", 50.0))
	if 种类 == "dynasty_low":
		return int(王朝.get("国祚", 100)) < 警
	if 种类 == "relation_low" or 种类 == "composite" or 种类 == "policy_miefa":
		return 关系 < float(警)
	if 种类 == "mind_low":
		return int(王朝.get("民心", 60)) < 警
	if 种类 == "gratitude_low" or 种类 == "decree_fail":
		if 郡id == "" or not 郡县状态.has(郡id):
			return false
		return int((郡县状态[郡id] as Dictionary).get("感恩", 100)) < 警
	return false
# 月度反制结算：预警 → 触发 → 逾期结算（挂 _结算王朝_S34）
# ============ S34 批次3收尾：朝廷委托（护国宗不可拒征调） ============
# 与反制对称：王朝主动点名宗门、强制接的差事。仅护国宗收（精准闭环遗留）；
# 自立为王豁免。护国宗界面只有「应征/拖延」无拒绝按钮。
# 拖延逾期按最严档结算：关系暴跌（= |penalty_gratitude|），埋下后续反制隐患。

func _读委托模板表() -> Array:
	if not Game._委托模板缓存.is_empty():
		return Game._委托模板缓存
	Game._委托模板缓存 = Game._CSV去BOM("res://config/dynasty_commission_config.csv")
	return Game._委托模板缓存

# 当前是否须应朝廷征调：仅护国宗；自立为王等豁免
func _须应征调_S34() -> bool:
	var 名: String = str(王朝.get("宗门爵位", "未册封"))
	if 名 == "自立为王":
		return false
	return 名 == "护国宗"

# 月度委托结算：逾期处理 → 生成新委托（仅护国宗）
func _结算王朝委托_S34() -> void:
	_王朝补缺_S34()
	var 今月: int = int(王朝.get("在位月", 0))
	var 冷却表: Dictionary = 王朝.get("委托冷却", {}) if 王朝.get("委托冷却", null) != null else {}
	var 待决: Array = 王朝.get("待决委托", []) if 王朝.get("待决委托", null) != null else []
	# ① 待决逾期未应征 → 自动按拖延（最严档）结算
	var 留存: Array = []
	for it in 待决:
		var 项: Dictionary = it as Dictionary
		if str(项.get("状态", "")) == "待决" and 今月 - int(项.get("生成月", 0)) >= 委托决策窗口:
			_结算委托后果_S34(项, "delay")
		else:
			留存.append(项)
	待决 = 留存
	# ② 仅护国宗收强制委托；有未决委托或冷却未过则不生成
	if not _须应征调_S34():
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 有待决: bool = false
	for it in 待决:
		if str((it as Dictionary).get("状态", "")) == "待决":
			有待决 = true
			break
	if 有待决:
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 上次: int = int(冷却表.get("commission", -99))
	if 今月 - 上次 < 委托生成间隔:
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 模板表: Array = _读委托模板表()
	if 模板表.is_empty():
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 模板: Dictionary = 模板表[randi() % 模板表.size()]
	var cid: String = str(模板.get("commission_id", ""))
	if cid == "":
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 候选郡: Array = _已解锁凡俗郡_S34()
	if 候选郡.is_empty():
		王朝["待决委托"] = 待决
		王朝["委托冷却"] = 冷却表
		return
	var 郡id: String = str(候选郡[randi() % 候选郡.size()])
	var 郡名: String = str((郡县状态[郡id] as Dictionary).get("名", "")) if 郡县状态.has(郡id) else ""
	var 实例: Dictionary = {
		"实例ID": "cc_%d_%s" % [今月, cid],
		"委托ID": cid, "名": str(模板.get("commission_name", "?")),
		"类型": str(模板.get("commission_type", "")),
		"难度": int(模板.get("difficulty", 1)),
		"要求境界": str(模板.get("require_realm", "练气")),
		"要求战力": int(模板.get("require_power", 0)),
		"耗时天": int(模板.get("duration_days", 5)),
		"成本灵石": int(模板.get("cost_lingshi", 0)),
		"奖励感恩": int(模板.get("reward_gratitude", 0)),
		"奖励灵石": int(模板.get("reward_lingshi", 0)),
		"奖励战功": int(模板.get("reward_merit", 0)),
		"惩罚感恩": int(模板.get("penalty_gratitude", 0)),
		"惩罚忠诚": int(模板.get("penalty_loyalty", 0)),
		"郡ID": 郡id, "郡名": 郡名,
		"生成月": 今月, "状态": "待决",
		"接取弟子ID": "", "接取弟子名": "", "到期日": 0,
	}
	待决.append(实例)
	冷却表["commission"] = 今月
	Game.添加纪事("王朝", "朝廷委托", "朝廷下诏：%s（%s）" % [str(模板.get("commission_name", "?")), 郡名], 2)
	Game._加推演条目("◇ 朝廷委托：%s%s" % [str(模板.get("commission_name", "?")), ("·" + 郡名) if 郡名 != "" else ""], Game.ET_SECT, Game.PRIO_HIGH, {})
	王朝["待决委托"] = 待决
	王朝["委托冷却"] = 冷却表

# 按游戏日推进委托（执行中到期即结算，挂 _结算王朝_S34 开头，先于月度闸门）
func _推进委托_S34(天: int) -> void:
	var 待决: Array = 王朝.get("待决委托", []) if 王朝.get("待决委托", null) != null else []
	if 待决.is_empty():
		return
	var 到期: Array = []
	for it in 待决:
		var 项: Dictionary = it as Dictionary
		if str(项.get("状态", "")) == "执行中" and Game.累计游戏日 >= int(项.get("到期日", 0)):
			到期.append(项)
	for 项 in 到期:
		_结算委托后果_S34(项, "complete")

# 玩家应对入口：应征(accept) / 拖延(delay)。护国宗无拒绝按钮（不可拒朝廷征调）。
func 应对王朝委托_S34(实例ID: String, 选择: String, 弟子ID: String = "") -> Dictionary:
	var 待决: Array = 王朝.get("待决委托", []) if 王朝.get("待决委托", null) != null else []
	var 命中: Dictionary = {}
	for it in 待决:
		if str((it as Dictionary).get("实例ID", "")) == 实例ID:
			命中 = it as Dictionary
			break
	if 命中.is_empty():
		return {"成功": false, "原因": "无此委托"}
	if 选择 == "delay":
		return {"成功": true, "委托": str(命中.get("名", "?")), "选择": "delay", "说明": "已暂缓应对，逾期将按最严档结算"}
	if 选择 != "accept":
		return {"成功": false, "原因": "未知选择"}
	var 成本: int = int(命中.get("成本灵石", 0))
	if 成本 > 0:
		if Game.灵石 < 成本:
			return {"成功": false, "原因": "灵石不足（需%d，现有%d）" % [成本, Game.灵石]}
		Game.灵石 -= 成本
	if 弟子ID == "":
		return {"成功": false, "原因": "须指定执行弟子"}
	var d = _取弟子_S34(弟子ID)
	if d == null:
		return {"成功": false, "原因": "弟子不存在"}
	if _弟子被扣押中_S34(弟子ID):
		return {"成功": false, "原因": "该弟子遭郡守羁押，无法领命"}
	var 需境: String = str(命中.get("要求境界", "练气"))
	var 需序: int = Disciple.境界序.find(需境)
	var 实序: int = Disciple.境界序.find(d.境界)
	if 需序 >= 0 and 实序 < 需序:
		return {"成功": false, "原因": "%s 修为不足（需%s）" % [d.姓名, 需境]}
	var 需战力: int = int(命中.get("要求战力", 0))
	if d.总战力() < 需战力:
		return {"成功": false, "原因": "%s 道行不足（需%d）" % [d.姓名, 需战力]}
	if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
		return {"成功": false, "原因": "%s 无法出行" % d.姓名}
	for k in 凡间差事进行中.keys():
		if str((凡间差事进行中[k] as Dictionary).get("接取弟子ID", "")) == 弟子ID:
			return {"成功": false, "原因": "%s 已有差事在身" % d.姓名}
	命中["状态"] = "执行中"
	命中["接取弟子ID"] = 弟子ID
	命中["接取弟子名"] = d.姓名
	命中["到期日"] = Game.累计游戏日 + int(命中.get("耗时天", 5))
	待决.erase(命中)
	待决.append(命中)
	王朝["待决委托"] = 待决
	Game.添加纪事("王朝", "奉诏领命", "%s 领受朝廷委托「%s」" % [d.姓名, str(命中.get("名", "?"))], 1)
	return {"成功": true, "委托": str(命中.get("名", "?")), "选择": "accept", "耗灵石": 成本, "弟子": d.姓名}

# 委托后果：delay=拖延最严档（关系暴跌）；complete=执行中到期按战力结算成败
func _结算委托后果_S34(项: Dictionary, 模式: String) -> void:
	var 郡id: String = str(项.get("郡ID", ""))
	var 有郡: bool = 郡县状态.has(郡id)
	if 模式 == "delay":
		var 跌: int = abs(int(项.get("惩罚感恩", 0)))
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) - float(跌), 0.0, 100.0)
		Game.添加纪事("王朝", "拖延征调", "宗门拖延朝廷征调「%s」，朝廷不悦（关系-%d），恐生后续问责" % [str(项.get("名", "?")), 跌], 2)
		_移除委托(项)
		return
	var d = _取弟子_S34(str(项.get("接取弟子ID", "")))
	var 成功率: float = 0.5
	if d != null:
		var 要求: int = max(1, int(项.get("要求战力", 1)))
		var 比值: float = clamp(float(d.总战力()) / float(要求), 0.0, 2.0)
		成功率 = clamp(0.35 + 比值 * 0.3, 0.35, 0.95)
	var 成功: bool = randf() < 成功率
	var 弟子名: String = str(项.get("接取弟子名", "?"))
	var 委托名: String = str(项.get("名", "?"))
	var 郡名: String = str(项.get("郡名", "?"))
	if 成功:
		if 有郡:
			var 郡: Dictionary = 郡县状态[郡id]
			郡["感恩"] = clamp(int(郡.get("感恩", 0)) + int(项.get("奖励感恩", 0)), 0, 100)
			郡县状态[郡id] = 郡
		Game.灵石 += int(项.get("奖励灵石", 0))
		if int(项.get("奖励战功", 0)) > 0:
			Game.加战功(int(float(项.get("奖励战功", 0)) * _派系战功系数_S34()))
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(项.get("奖励感恩", 0)) / 4.0, 0.0, 100.0)
		# P1联动：王朝委托完成 → 宗门声望+资源奖励（爵位加成）
		var 基础奖励: Dictionary = {
			"声望": int(项.get("奖励感恩", 0)) * 10,
			"灵石": int(项.get("奖励灵石", 0)),
			"灵气": int(项.get("奖励感恩", 0)) * 5,
		}
		Game.王朝委托完成奖励(委托名, 基础奖励)
		Game.添加纪事("王朝", "奉诏有成", "%s 办成朝廷委托「%s」，%s感恩+%d" % [弟子名, 委托名, 郡名, int(项.get("奖励感恩", 0))], 1)
	else:
		if 有郡:
			var 郡2: Dictionary = 郡县状态[郡id]
			郡2["感恩"] = clamp(int(郡2.get("感恩", 0)) + int(项.get("惩罚感恩", 0)), 0, 100)
			郡县状态[郡id] = 郡2
		if d != null:
			d.忠诚 = clamp(d.忠诚 + int(项.get("惩罚忠诚", 0)), 0, 100)
		王朝["对宗门关系"] = clamp(float(王朝.get("对宗门关系", 50.0)) + float(项.get("惩罚感恩", 0)) / 4.0, 0.0, 100.0)
		Game.添加纪事("王朝", "奉诏失利", "%s 未能办成朝廷委托「%s」，%s感恩%d" % [弟子名, 委托名, 郡名, int(项.get("惩罚感恩", 0))], 2)
	_移除委托(项)

func _移除委托(项: Dictionary) -> void:
	var 待决: Array = 王朝.get("待决委托", []) if 王朝.get("待决委托", null) != null else []
	var 留存: Array = []
	for it in 待决:
		if str((it as Dictionary).get("实例ID", "")) != str(项.get("实例ID", "")):
			留存.append(it)
	王朝["待决委托"] = 留存


# ===== 拍卖行系统（已拆分到auction_system.gd，此处为转发函数）=====
func _读拍卖配置表():
	return Game.拍卖行系统._读拍卖配置表()
func _拍卖配置浮(param: String, 默认: float):
	return Game.拍卖行系统._拍卖配置浮(param, 默认)
func _读拍卖AI表():
	return Game.拍卖行系统._读拍卖AI表()
func _拍卖当前等级():
	return Game.拍卖行系统._拍卖当前等级()
func _拍卖当前佣金率():
	return Game.拍卖行系统._拍卖当前佣金率()
func _拍卖增加声望(金额: int):
	Game.拍卖行系统._拍卖增加声望(金额)
func _拍卖等级名称(等级: int):
	return Game.拍卖行系统._拍卖等级名称(等级)
func _新拍卖会():
	return Game.拍卖行系统._新拍卖会()
func _拍卖会补缺():
	Game.拍卖行系统._拍卖会补缺()
func _拍卖品阶基准(品阶: String):
	return Game.拍卖行系统._拍卖品阶基准(品阶)
func _基准估值(it):
	return Game.拍卖行系统._基准估值(it)
func _造拍卖物品(目标品阶集: Array):
	return Game.拍卖行系统._造拍卖物品(目标品阶集)
func _生成单个拍品_S34(场次: String):
	return Game.拍卖行系统._生成单个拍品_S34(场次)
func _生成常驻拍品_S34():
	Game.拍卖行系统._生成常驻拍品_S34()
func _生成大拍拍品_S34():
	Game.拍卖行系统._生成大拍拍品_S34()
func _推进拍卖会_S34(天: int):
	Game.拍卖行系统._推进拍卖会_S34(天)
func 拍卖会确保就绪_S34():
	Game.拍卖行系统.拍卖会确保就绪_S34()
func 设置拍卖交付_S34(交付: Dictionary):
	Game.拍卖行系统.设置拍卖交付_S34(交付)
func 玩家竞拍出价_S34(lot_id: String, 出价: int, 交付: Dictionary, 货币: String = "灵石"):
	# ★ 2026-09-16（ECON-03 P1）：双币链路三层转发（UI → Game → 王朝系统 → 拍卖行系统），
	#   每层都要显式透传，否则第 4 个实参会因「参数过多」直接抛错。
	return Game.拍卖行系统.玩家竞拍出价_S34(lot_id, 出价, 交付, 货币)
func _AI应价_S34(lot: Dictionary):
	Game.拍卖行系统._AI应价_S34(lot)
func _结算单个拍品_S34(lot: Dictionary):
	Game.拍卖行系统._结算单个拍品_S34(lot)
func 设置委托竞拍_S34(lot_id: String, 委托价: int):
	return Game.拍卖行系统.设置委托竞拍_S34(lot_id, 委托价)
func 取消委托竞拍_S34(lot_id: String):
	return Game.拍卖行系统.取消委托竞拍_S34(lot_id)
func _取消委托竞拍内部_S34(lot_id: String):
	return Game.拍卖行系统._取消委托竞拍内部_S34(lot_id)
func _处理委托出价_S34(lot: Dictionary):
	Game.拍卖行系统._处理委托出价_S34(lot)
func _查找拍品_S34(lot_id: String):
	return Game.拍卖行系统._查找拍品_S34(lot_id)
func _延时结算检查_S34(lot: Dictionary):
	Game.拍卖行系统._延时结算检查_S34(lot)
func _添加结算通知_S34(通知: Dictionary):
	Game.拍卖行系统._添加结算通知_S34(通知)
func 获取结算通知_S34():
	return Game.拍卖行系统.获取结算通知_S34()
func 清除结算通知_S34():
	Game.拍卖行系统.清除结算通知_S34()
func _发放弟子月例_S34(d: Disciple):
	Game.拍卖行系统._发放弟子月例_S34(d)
func _弟子AI竞拍决策_S34(d: Disciple):
	Game.拍卖行系统._弟子AI竞拍决策_S34(d)
func _计算弟子拍品兴趣_S34(d: Disciple, lot: Dictionary):
	return Game.拍卖行系统._计算弟子拍品兴趣_S34(d, lot)
func _设置弟子委托_S34(d: Disciple, lot: Dictionary, 兴趣值: int):
	Game.拍卖行系统._设置弟子委托_S34(d, lot, 兴趣值)
func _弟子委托拍卖_S34(d: Disciple):
	Game.拍卖行系统._弟子委托拍卖_S34(d)
func 设置弟子拍卖权限_S34(弟子ID: int, 允许: bool):
	return Game.拍卖行系统.设置弟子拍卖权限_S34(弟子ID, 允许)
func 设置弟子拍卖预算_S34(弟子ID: int, 预算: int):
	return Game.拍卖行系统.设置弟子拍卖预算_S34(弟子ID, 预算)
func 玩家寄售物品_S34(物品索引: int, 起拍价: int, 时长类型: String = "7日"):
	return Game.拍卖行系统.玩家寄售物品_S34(物品索引, 起拍价, 时长类型)
func 获取拍卖行回放_S34():
	return Game.拍卖行系统.获取拍卖行回放_S34()
func 发布求购_S34(物品类别: String, 品阶: String, 最高出价: int):
	return Game.拍卖行系统.发布求购_S34(物品类别, 品阶, 最高出价)
func 取消求购_S34(求购ID: String):
	return Game.拍卖行系统.取消求购_S34(求购ID)
func 关注拍品_S34(拍品ID: String):
	return Game.拍卖行系统.关注拍品_S34(拍品ID)
func 取消关注_S34(拍品ID: String):
	return Game.拍卖行系统.取消关注_S34(拍品ID)
func _检查关注提醒_S34():
	Game.拍卖行系统._检查关注提醒_S34()
func _获取当前拍卖师_S34(大拍: bool):
	return Game.拍卖行系统._获取当前拍卖师_S34(大拍)
func _拍卖师话术_S34(拍卖师: Dictionary):
	return Game.拍卖行系统._拍卖师话术_S34(拍卖师)
func 创建暗拍拍品_S34(物品: Item, 起拍价: int, 时长日: int):
	return Game.拍卖行系统.创建暗拍拍品_S34(物品, 起拍价, 时长日)
func 暗拍出价_S34(拍品ID: String, 出价: int):
	return Game.拍卖行系统.暗拍出价_S34(拍品ID, 出价)
func _暗拍结算_S34(lot: Dictionary):
	Game.拍卖行系统._暗拍结算_S34(lot)
func 创建未知拍品_S34(基础品阶: String, 鉴定费: int):
	return Game.拍卖行系统.创建未知拍品_S34(基础品阶, 鉴定费)
func 鉴定拍品_S34(拍品ID: String):
	return Game.拍卖行系统.鉴定拍品_S34(拍品ID)


func _检查特殊事件_S34() -> void:
	return Game.拍卖行系统._检查特殊事件_S34()

func _推进特殊事件_S34() -> void:
	return Game.拍卖行系统._推进特殊事件_S34()

func 获取当前特殊事件_S34() -> Dictionary:
	return Game.拍卖行系统.获取当前特殊事件_S34()

func _结算王朝反制_S34() -> void:
	_王朝补缺_S34()
	_推进被扣押弟子_S34()
	var 今月: int = int(王朝.get("在位月", 0))
	var 冷却表: Dictionary = 王朝.get("反制冷却", {}) if 王朝.get("反制冷却", null) != null else {}
	var 待决: Array = 王朝.get("待决反制", []) if 王朝.get("待决反制", null) != null else []
	# ① 逾期未决 → 自动按最坏结果执行
	var 留存: Array = []
	for it in 待决:
		var 项: Dictionary = it as Dictionary
		if 今月 - int(项.get("生成月", 0)) >= 反制决策窗口:
			_执行反制后果_S34(项, "default")
		else:
			留存.append(项)
	待决 = 留存
	# ② 扫配置：预警 / 触发
	var 郡表: Array = _已解锁凡俗郡_S34()
	for r in _读反制配置():
		var 配: Dictionary = r as Dictionary
		var id: String = str(配.get("counter_id", ""))
		if id == "":
			continue
		var 上次: int = int(冷却表.get(id, -99))
		if 今月 - 上次 < int(配.get("cooldown_month", 3)):
			continue
		var 种类: String = str(配.get("trigger_kind", ""))
		var 逐郡: bool = 种类 == "gratitude_low" or 种类 == "decree_fail"
		var 扫描: Array = 郡表 if 逐郡 else [""]
		for 郡id in 扫描:
			var cid: String = str(郡id)
			# 预警键按 反制ID+郡ID 区分（逐郡类每郡各记一次，互不覆盖）
			var 警键: String = "预警_" + id + cid
			if _反制触发判定_S34(配, cid):
				var 名: String = str(配.get("counter_name", "?"))
				var 郡名: String = str((郡县状态[cid] as Dictionary).get("名", "")) if 郡县状态.has(cid) else ""
				var 实例: Dictionary = {
					"实例ID": "%s_%d_%s" % [id, 今月, cid],
					"反制ID": id, "名": 名, "郡ID": cid, "郡名": 郡名,
					"生成月": 今月, "成本": _反制成本_S34(配),
					"选项": str(配.get("opt_label", "应对")),
					"说明": str(配.get("penalty_desc", "")),
				}
				待决.append(实例)
				冷却表[id] = 今月
				Game.添加纪事("王朝", "朝廷诏令", "%s：%s" % [名, str(配.get("penalty_desc", ""))], 2)
				Game._加推演条目("◇ %s%s" % [名, ("·" + 郡名) if 郡名 != "" else ""], Game.ET_SECT, Game.PRIO_HIGH, {})
				王朝[警键] = false
				# 只扫一个空元素的非逐郡类，break 无副作用；逐郡类继续扫其余郡
				if not 逐郡:
					break
			elif _反制预警判定_S34(配, cid):
				if not bool(王朝.get(警键, false)):
					王朝[警键] = true
					Game._加推演条目("⚠ %s之兆已现，宜早为之计" % str(配.get("counter_name", "?")), Game.ET_SECT, Game.PRIO_NORMAL, {})
			else:
				if bool(王朝.get(警键, false)):
					王朝[警键] = false
	王朝["待决反制"] = 待决
	王朝["反制冷却"] = 冷却表
# 办差失败埋点：郡守借机扣人（感恩低才有借口 —— 玩家可通过维持感恩预防，非纯随机）
func _反制_办差失利_S34(郡id: String) -> void:
	if 郡id == "" or not 郡县状态.has(郡id):
		return
	var 配: Dictionary = _反制配置("dc_kouya")
	if 配.is_empty():
		return
	if _反制触发判定_S34(配, 郡id):
		var 今月: int = int(王朝.get("在位月", 0))
		var 待决: Array = 王朝.get("待决反制", []) if 王朝.get("待决反制", null) != null else []
		待决.append({
			"实例ID": "dc_kouya_%d_%s" % [今月, 郡id],
			"反制ID": "dc_kouya", "名": str(配.get("counter_name", "扣押弟子")),
			"郡ID": 郡id, "郡名": str((郡县状态[郡id] as Dictionary).get("名", "")),
			"生成月": 今月, "成本": _反制成本_S34(配),
			"选项": str(配.get("opt_label", "赎回弟子")),
			"说明": str(配.get("penalty_desc", "")),
		})
		王朝["待决反制"] = 待决
		Game.添加纪事("王朝", "弟子被扣", "于%s办差失利，弟子遭郡守羁押" % str((郡县状态[郡id] as Dictionary).get("名", "?")), 2)
# 玩家应对入口：选择 = pay 缴纳 / refuse 拒绝 / ransom 赎回 / rescue 营救 / wait 拖延 /
#                     repair 安抚 / mediate 调停 / defend 迎战 / migrate 迁宗 / rebel 扶持叛军
func 应对王朝反制_S34(实例ID: String, 选择: String) -> Dictionary:
	var 待决: Array = 王朝.get("待决反制", []) if 王朝.get("待决反制", null) != null else []
	var 命中: Dictionary = {}
	for it in 待决:
		if str((it as Dictionary).get("实例ID", "")) == 实例ID:
			命中 = it as Dictionary
			break
	if 命中.is_empty():
		return {"成功": false, "原因": "无此诏令"}
	var 反制ID: String = str(命中.get("反制ID", ""))
	var 配: Dictionary = _反制配置(反制ID)
	if 配.is_empty():
		return {"成功": false, "原因": "配置缺失"}
	var 成本: int = int(命中.get("成本", 0))
	# 国师及以上调停民变零成本（爵位特权 —— 兑现爵位表 right_desc 的承诺）
	if 反制ID == "dc_minbian" and 选择 == "mediate" and _可调停民变_S34():
		成本 = 0
	# 需付费的应对：灵石不足则无法执行（不是扣成负数）
	if 选择 in ["pay", "ransom", "repair", "mediate"] and 成本 > 0:
		if Game.灵石 < 成本:
			return {"成功": false, "原因": "灵石不足（需%d，现有%d）" % [成本, Game.灵石]}
		Game.灵石 -= 成本
	待决.erase(命中)
	王朝["待决反制"] = 待决
	_执行反制后果_S34(命中, 选择)
	return {"成功": true, "反制": str(配.get("counter_name", "?")), "选择": 选择, "耗灵石": 成本}
# 后果执行：选择决定正负走向 —— 应对得当有转化收益，不应对则吃满惩罚
func _执行反制后果_S34(项: Dictionary, 选择: String) -> void:
	var 反制ID: String = str(项.get("反制ID", ""))
	var 配: Dictionary = _反制配置(反制ID)
	if 配.is_empty():
		return
	var 郡id: String = str(项.get("郡ID", ""))
	var 郡名: String = str(项.get("郡名", ""))
	var 效: Array = _解析转化效果_S34(str(配.get("convert_effect", "")))
	var 用了转化: bool = false
	# —— 缴纳 / 拒绝：缴纳花灵石保关系；拒绝省灵石掉关系，却收买民心、催化乱世 ——
	if 反制ID == "dc_qiangzheng":
		if 选择 == "pay":
			# 纳贡应命：灵石已在应对时扣除，换来朝廷满意但民间怨怼
			_施加转化效果_S34(_解析转化效果_S34("mind-3"), 郡id)
			Game.添加纪事("王朝", "纳贡应命", "宗门如数缴纳强征，朝廷满意而民间怨怼（民心-3）", 1)
		else:
			# 拒缴 或 逾期（逾期视同抗命，只吃惩罚、拿不到转化收益）
			var 关: float = float(王朝.get("对宗门关系", 50.0))
			王朝["对宗门关系"] = clamp(关 - 15.0, 0.0, 100.0)
			if 选择 == "refuse":
				_施加转化效果_S34(效, 郡id)
				Game.业力 += 反制抗命业力
				用了转化 = true
				Game.添加纪事("王朝", "抗命不缴", "宗门拒纳强征，朝廷不悦（关系-15）；然百姓感念，民心+5、国祚-3", 2)
			else:
				Game.添加纪事("王朝", "抗命逾期", "强征逾期未缴，朝廷震怒（关系-15）", 2)
	# —— 扣押弟子：赎回花灵石 / 营救遣弟子（胜则感恩大涨）/ 拖延则忠诚受损 ——
	elif 反制ID == "dc_kouya":
		if 选择 == "rescue":
			var 胜: bool = _营救判定_S34(郡id)
			if 胜:
				_施加转化效果_S34(效, 郡id)
				用了转化 = true
				Game.添加纪事("王朝", "营救得手", "弟子自%s脱身，宗门声威大振（该郡感恩+25）" % 郡名, 1)
			else:
				_施加转化效果_S34(_解析转化效果_S34("gratitude-5"), 郡id)
				Game.添加纪事("王朝", "营救失利", "营救未成，反落口实（该郡感恩-5）", 2)
		elif 选择 == "ransom":
			# 赎回：灵石已在应对时扣除
			_施加转化效果_S34(_解析转化效果_S34("gratitude+3"), 郡id)
			Game.添加纪事("王朝", "赎回弟子", "耗灵石赎回归宗门弟子，该郡感恩+3", 1)
		else:
			# 拖延 或 逾期：弟子羁押数月，忠诚受损（逾期无转化收益）
			var 押: Array = 王朝.get("被扣押弟子", []) if 王朝.get("被扣押弟子", null) != null else []
			押.append({"弟子ID": str(项.get("弟子ID", "")), "剩余月": 反制等待月数})
			王朝["被扣押弟子"] = 押
			Game.添加纪事("王朝", "隐忍不发", "宗门隐忍，弟子羁押待归（忠诚将损）", 2)
	# —— 断供：不归零而降至三成，安抚可全额恢复 ——
	elif 反制ID == "dc_duanguan":
		if 选择 == "repair":
			_施加转化效果_S34(效, 郡id)
			_移除郡标记_S34(郡id, "断供")
			Game.添加纪事("王朝", "安抚复供", "遣使安抚%s，供奉恢复如初" % 郡名, 1)
		else:
			_打郡标记_S34(郡id, "断供")
			Game.添加纪事("王朝", "郡县断供", "%s供奉降至30%" % 郡名, 2)
	# —— 禁传道 ——
	elif 反制ID == "dc_jinchuan":
		if 选择 == "mediate":
			_施加转化效果_S34(效, 郡id)
			_移除郡标记_S34(郡id, "禁传道")
			Game.添加纪事("王朝", "解除禁令", "疏通关节，%s复许传道" % 郡名, 1)
		else:
			_打郡标记_S34(郡id, "禁传道")
			Game.添加纪事("王朝", "禁绝传道", "%s不再供给灵根苗子" % 郡名, 2)
	# —— 民变：国师免费调停（爵位特权兑现） ——
	elif 反制ID == "dc_minbian":
		if 选择 == "mediate":
			_施加转化效果_S34(效, 郡id)
			用了转化 = true
			Game.添加纪事("王朝", "民变平息", "民变得平，民心+15", 1)
		else:
			_施加转化效果_S34(_解析转化效果_S34("mind-10|dynasty-5"), 郡id)
			Game.添加纪事("王朝", "民变蔓延", "民变未平，民心-10、国祚-5", 2)
	# —— 灭法诏：上书自辩争取时间，根除须改国策 ——
	elif 反制ID == "dc_miefazhao":
		if 选择 == "mediate":
			_施加转化效果_S34(效, 郡id)
			Game.添加纪事("王朝", "上书自辩", "宗门上书自辩，暂缓灭法之诏（关系+6）", 1)
		else:
			_施加转化效果_S34(_解析转化效果_S34("relation-10"), 郡id)
			Game.添加纪事("王朝", "灭法诏下", "灭法诏行，供奉与苗子俱绝（关系-10）", 2)
	# —— 灭法令：三选一，条条走得通 ——
	elif 反制ID == "dc_miefaling":
		if 选择 == "rebel":
			Game.业力 += 反制扶持叛军业力
			_施加转化效果_S34(_解析转化效果_S34("dynasty-15|mind+8"), 郡id)
			Game.添加纪事("王朝", "扶持叛军", "宗门暗中扶持叛军，国祚-15、民心+8（业力+%d）" % 反制扶持叛军业力, 2)
		elif 选择 == "migrate":
			_施加转化效果_S34(_解析转化效果_S34("relation-30"), 郡id)
			Game.添加纪事("王朝", "迁宗避祸", "宗门弃地迁宗，与王朝再无瓜葛（关系-30，领地尽失）", 2)
		else:
			Game.业力 += 反制迎战得胜业力
			_施加转化效果_S34(效, 郡id)
			Game.添加纪事("王朝", "迎战禁军", "宗门正面迎战王朝禁军，声威震天", 1)
	if 用了转化:
		Game._加推演条目("⇒ 诏令转化：%s → %s" % [str(配.get("counter_name", "?")), str(配.get("convert_desc", ""))], Game.ET_SECT, Game.PRIO_NORMAL, {})
# 营救判定：按宗门最高战力 vs 该郡兵力（× 换算系数），不触碰 BattleCalculator 72 条红线
func _营救判定_S34(郡id: String) -> bool:
	var 最高: int = 0
	for d in Game.弟子列表:
		if d.状态 == "陨落" or d.状态 == "叛出":
			continue
		最高 = max(最高, int(d.总战力()))
	var 兵力: int = 0
	if 郡县状态.has(郡id):
		兵力 = int((郡县状态[郡id] as Dictionary).get("兵力", 0))
	var 比: float = clamp(float(最高) / max(1.0, float(兵力) * 禁军战力换算), 0.0, 2.0)
	return randf() < clamp(反制营救成功率基 + 比 * 反制营救成功率权, 0.05, 0.95)
func _打郡标记_S34(郡id: String, 标记: String) -> void:
	if 郡id == "" or not 郡县状态.has(郡id):
		return
	var 郡: Dictionary = 郡县状态[郡id]
	var 集: Array = 郡.get("标记", []) if 郡.get("标记", null) != null else []
	if 标记 not in 集:
		集.append(标记)
	郡["标记"] = 集
	郡县状态[郡id] = 郡
func _移除郡标记_S34(郡id: String, 标记: String) -> void:
	if 郡id == "" or not 郡县状态.has(郡id):
		return
	var 郡: Dictionary = 郡县状态[郡id]
	var 集: Array = 郡.get("标记", []) if 郡.get("标记", null) != null else []
	集.erase(标记)
	郡["标记"] = 集
	郡县状态[郡id] = 郡
func _郡有标记_S34(郡id: String, 标记: String) -> bool:
	if 郡id == "" or not 郡县状态.has(郡id):
		return false
	var 集: Array = (郡县状态[郡id] as Dictionary).get("标记", []) if (郡县状态[郡id] as Dictionary).get("标记", null) != null else []
	return 标记 in 集
# 断供郡数（驱动民心下滑 → 民变；玩家可观测可修复，非随机掉血）
func _断供郡数_S34() -> int:
	var n: int = 0
	for k in 郡县状态.keys():
		if _郡有标记_S34(str(k), "断供"):
			n += 1
	return n
# 弟子是否被羁押（被扣押期间不得领差事）
func _弟子被扣押中_S34(弟子ID: String) -> bool:
	var 押: Array = 王朝.get("被扣押弟子", []) if 王朝.get("被扣押弟子", null) != null else []
	for it in 押:
		if str((it as Dictionary).get("弟子ID", "")) == 弟子ID:
			return true
	return false
# 月度推进被扣押弟子：期满归宗，忠诚受损（拖延的代价在时间里慢慢付）
func _推进被扣押弟子_S34() -> void:
	var 押: Array = 王朝.get("被扣押弟子", []) if 王朝.get("被扣押弟子", null) != null else []
	if 押.is_empty():
		return
	var 留存: Array = []
	for it in 押:
		var 项: Dictionary = it as Dictionary
		var 余: int = int(项.get("剩余月", 0)) - 1
		if 余 > 0:
			项["剩余月"] = 余
			留存.append(项)
			continue
		var d = _取弟子_S34(str(项.get("弟子ID", "")))
		if d != null:
			d.忠诚 = clamp(d.忠诚 - 反制等待忠诚罚, 0, 100)
			Game.添加纪事("王朝", "弟子归宗", "%s羁押期满归宗，忠诚-%d" % [str(d.名字), 反制等待忠诚罚], 2)
	留存 = 留存
	王朝["被扣押弟子"] = 留存

# ============ S34 批次 3：爵位停权考核 ============
# 原实现爵位只增不减（全代码仅主动辞位才降级）→ 关系是「达标即永久」的一次性门票，
# 玩家拿到帝师后无需再维护关系。停权考核让爵位变成【需要持续经营的身份】，
# 关系才真正拥有持续价值，反制的「扣关系」代价才成立。
func _爵位门槛_S34() -> int:
	var 配: Dictionary = _爵位配置(str(王朝.get("宗门爵位", "未册封")))
	if 配.is_empty():
		return 0
	return int(配.get("need_relation", 0))
# 爵位权利是否生效（停权 → 差事榜容量/供奉加成/荐举权全部失效）
func _爵位生效中_S34() -> bool:
	if str(王朝.get("宗门爵位", "未册封")) == "未册封":
		return false
	return not bool(王朝.get("爵位停权", false))
# 月度考核：关系跌破门槛 → 停权；回升至门槛 → 自动复权（均记纪事，玩家看得见因果）
func _结算爵位停权_S34() -> void:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 == "未册封":
		if bool(王朝.get("爵位停权", false)):
			王朝["爵位停权"] = false
		return
	var 门槛: int = _爵位门槛_S34()
	var 关系: float = float(王朝.get("对宗门关系", 50.0))
	var 停权: bool = bool(王朝.get("爵位停权", false))
	if not 停权 and 关系 < float(门槛):
		王朝["爵位停权"] = true
		Game.添加纪事("王朝", "爵位停权", "%s位停权：对宗门关系%.0f跌破门槛%d，爵位权利冻结" % [位阶, 关系, 门槛], 2)
		Game._加推演条目("⚠ %s位停权：关系%.0f < %d，权利冻结（差事榜/供奉加成/荐举权暂废）" % [位阶, 关系, 门槛], Game.ET_SECT, Game.PRIO_HIGH, {})
	elif 停权 and 关系 >= float(门槛):
		王朝["爵位停权"] = false
		Game.添加纪事("王朝", "爵位复权", "对宗门关系回升至%.0f，%s位权利恢复" % [关系, 位阶], 1)
		Game._加推演条目("✓ %s位复权：关系回升至%.0f，爵位权利恢复" % [位阶, 关系], Game.ET_SECT, Game.PRIO_NORMAL, {})

# 老大裁定「要好玩」的三处设计优化，全部落在本区块：
#   A 党争周期 —— 掌权派系每月流失势能(ruling_decay)，在野派系每月积蓄(wild_gain)。
#     权重最高者掌权，故「掌权者必然被推翻」，玩家必须在押注时机上做决策：
#     早押冷门（成本低、掌权期长）vs 晚押热门（见效快、但掌权期已被消耗）。
#   B 站队有记忆 —— 每次扶持给目标记「恩遇」、给其余三派各记「宿怨」。
#     掌权更替时按 (恩遇 − 宿怨 × grudge_coef) 清算关系：梭哈单派系者，
#     在其倒台后会遭新掌权派清算，逼玩家分散押注或精准择时。
#   C 位阶是契约 —— 升位阶须主动「受封」，解锁权利的同时背上义务（国师月度荐举耗灵石、
#     帝师须押注继承人、护国宗不可拒朝廷征调）。可辞位，但掉王朝关系。
#     位阶因此是「我现在扛不扛得住」的节奏决策，而非达标自动升的进度条。
const 派系序: Array = ["士族", "边将", "宦官", "外戚"]
const 爵位序: Array = ["未册封", "护国宗", "国师", "帝师", "监国", "摄政", "自立为王"]
# 批次 2 只落地前四级；监国/摄政/自立为王 属批次 4 正邪终局，门槛已在 CSV 填好待接
const 爵位本期开放: Array = ["未册封", "护国宗", "国师", "帝师", "监国", "摄政", "自立为王"]
const 派系权重初值: int = 25          # 四派系均分 100
const 扶持权重增益: int = 12          # 扶持一次的权重增幅（须显著大于月流失，否则扶持无感）
const 扶持恩遇增: int = 2             # 扶持目标：恩遇 +2（兑现 ×2 = +4，略高于三派宿怨记恨 ≈3）
const 新朝气象加成: int = 18          # 易主时新掌权者的正统性一次性加成（÷3 从在野三派扣除，零和守恒）
#                                      原为 +1（兑现 +2 < 记恨 ≈3）→ 扶持在关系上系统性净负，
#                                      玩家算完账就不会想扶；扶持的代价本就该是资源而非关系。
const 扶持宿怨增: int = 1             # 其余三派：宿怨各 +1
const 扶持冷却月: int = 6             # 扶持冷却：两次扶持至少隔 6 王朝月（重锤而非滴灌，否则扶持均摊压过净流失 → 锁权）
const 恩遇累积上限: int = 12          # 恩遇累积封顶：防「梭哈单派系反复上台套现」刷关系
const 派系权重上限: int = 97          # 权重天花板（留 3 给其余三派保底，保证零和守恒不被截断）
const 派系权重下限: int = 1           # 权重地板（永不为 0，保证零和守恒不被底部吃掉）
const 清算关系系数: float = 1.0       # 宿怨杀伤：关系点 / (宿怨点 × grudge_coef)
const 恩遇兑现关系: float = 2.0       # 恩遇兑现：关系点 / 恩遇点
const 恩遇兑现上限: float = 20.0      # 恩遇兑现单次封顶，防无限刷关系
const 辞位关系罚: int = 12            # 辞去爵位：王朝关系 -12
# —— 荐举（国师月度行动）——
# 原设计把荐举做成「每月无条件扣 200 Game.灵石」，而满版图供奉仅 117/推演月 ——
# 玩家受封国师即净亏 83/推演月，且扣了钱什么也没得到（CSV 承诺的「左右派系权重」未实现）。
# 现改为：荐举 = 花钱向朝中安插自己人（权重+恩遇），且是每月一次的真决策；
# 只有「到月末仍未荐举」才罚，「不做才罚」比「无条件扣费」更像玩法。
const 荐举权重增益: int = 4            # 荐举一次的权重增幅（扶持 12 的 1/3，但每月可做）
const 荐举恩遇增: int = 1              # 荐举目标：恩遇 +1
const 荐举宿怨增: int = 1              # 荐举非掌权派系 → 掌权者察觉结党，宿怨 +1
const 帝师荐举倍率: float = 2.0        # 帝师位高权重，荐举效果翻倍
const 荐举失期关系罚: int = 5
# —— 批次 4 正邪终局（监国 / 摄政 / 自立为王）惩罚常量 ——
const 摄政民心月损: int = 3            # 摄政义务：民心每月持续下滑（兑现 CSV duty_desc「民心持续下滑」）
const 监国覆灭灵石率: float = 0.15     # 监国：宗门气运与国祚绑定，王朝覆灭则宗门同受重伤
const 监国覆灭香火罚: int = 200
const 监国覆灭忠诚罚: int = 10
const 摄政翻车灵石率: float = 0.30     # 摄政：改朝换代即翻车，折损较监国加倍
const 摄政翻车香火罚: int = 400
const 摄政翻车忠诚罚: int = 20
const 废立皇帝民心罚: int = 8          # 监国权利：废立皇帝（不可逆大事件），动摇国本
const 废立皇帝国祚罚: int = 10
const 操控国策民心罚: int = 2          # 摄政权利：操控国策的民心代价          # 到月末仍未荐举：朝廷不满（爵位不革除，给补救窗口）
const 外戚索要周期月: int = 6         # 外戚掌权时，每 6 王朝月索要一次弟子
const 外戚拒索关系罚: int = 15        # 拒绝外戚索要：王朝关系 -15
const 外戚拒索权重增: int = 8         # 拒绝外戚索要：外戚记恨，权重 +8
const 外戚应允关系增: int = 10        # 答应外戚索要：王朝关系 +10
const 外戚应允权重增: int = 10        # 答应外戚索要：外戚权重 +10
const 入赘同门忠诚罚: int = 2         # 送走弟子：全体在宗弟子忠诚 -2（人心浮动）
const 入赘至亲忠诚罚: int = 8         # 送走弟子：其师父/徒弟/道侣额外忠诚 -8
const 入赘供奉加成: float = 0.06      # 朝中有人：每名入赘弟子在外戚掌权时 +6% 供奉
const 入赘供奉加成上限: float = 0.6   # 加成封顶 +60%（10 人封顶，防无限送人刷供奉）
const 外戚掌权关系修: float = 0.1     # 外戚掌权期间每月自然修复关系（姻亲好说话）—— 兑现 CSV 承诺
#                                      0.3 太强：实测把零干预基线从 50 抬到 67，
#                                      所有策略的关系水位一起涨，反而稀释了策略差异。
#                                      「掌权则关系易修」原只在描述里，代码未实现；外戚因此付出最贵
#                                      （弟子是宗门命脉）却回报最平庸，实测断供最早（65 月）、无人问津。

var _派系配置缓存: Array = []
var _爵位配置缓存: Array = []
# 被外戚索走的弟子档案：仅留档展示，不参与推演（弟子本体已从 Game.弟子列表 移除）
var 入赘名录: Array = []
# 外戚索要待决：非空时 UI 须优先弹出抉择（答应 = 真送走弟子，拒绝 = 关系与权重双罚）
var 外戚索要待决: Dictionary = {}

func _读派系配置() -> Array:
	if not _派系配置缓存.is_empty():
		return _派系配置缓存
	_派系配置缓存 = Game._CSV去BOM("res://config/dynasty_faction_config.csv")
	return _派系配置缓存
func _读爵位配置() -> Array:
	if not _爵位配置缓存.is_empty():
		return _爵位配置缓存
	_爵位配置缓存 = Game._CSV去BOM("res://config/dynasty_title_config.csv")
	return _爵位配置缓存
func _派系配置(派系名: String) -> Dictionary:
	for r in _读派系配置():
		if str((r as Dictionary).get("faction_name", "")) == 派系名:
			return r as Dictionary
	return {}
func _爵位配置(位阶: String) -> Dictionary:
	for r in _读爵位配置():
		if str((r as Dictionary).get("title_name", "")) == 位阶:
			return r as Dictionary
	return {}
# 派系初值：四派系权重带随机扰动（18~32），故新朝掌权派系是随机的而非恒为士族。
# 供 _新王朝() 内联调用（纯函数，不读写全局 王朝，可在返回体里直接用）。
func _派系初值数组_S34() -> Array:
	# 先随机扰动（randi_range(18,32)），再归一化到总和恒为 100。
	# 原实现四次独立随机后总和漂移到 96~104（实测 20 次采样均值 99.8），
	# 而后续所有零和运算都以「总和 100」为前提 —— 基数错了，守恒形同虚设。
	var 初值: Array = []
	var 总和: int = 0
	for _i in range(派系序.size()):
		var v: int = randi_range(18, 32)
		初值.append(v)
		总和 += v
	if 总和 <= 0:
		总和 = 派系序.size() * 派系权重初值
	var 归一: Array = []
	var 累计: int = 0
	for k in range(初值.size()):
		var 权: int = int(float(初值[k]) * 100.0 / float(总和))
		权 = clamp(权, 派系权重下限, 派系权重上限)
		归一.append(权)
		累计 += 权
	# 余数补给权重最高者，保证总和精确为 100
	var 余: int = 100 - 累计
	if 余 != 0:
		var 最大位: int = 0
		for k in range(归一.size()):
			if 归一[k] > 归一[最大位]:
				最大位 = k
		归一[最大位] = clamp(归一[最大位] + 余, 派系权重下限, 派系权重上限)
	var 派系: Array = []
	for k in range(派系序.size()):
		派系.append({
			"名": 派系序[k],
			"权重": 归一[k] if k < 归一.size() else 派系权重初值,
			"恩遇": 0,
			"宿怨": 0,
			"掌权": false,
			"掌权月": 0,
		})
	return 派系
# 派系初始化：四派系均分权重，恩遇/宿怨归零；改朝换代与新档共用
func _初始化派系_S34() -> void:
	王朝["派系"] = _派系初值数组_S34()
	_刷新掌权派系_S34(true)
func _取派系项_S34(派系名: String) -> Dictionary:
	var 派系: Array = 王朝.get("派系", [])
	for it in 派系:
		if str((it as Dictionary).get("名", "")) == 派系名:
			return it as Dictionary
	return {}
func _权重最高派系_S34() -> String:
	var 派系: Array = 王朝.get("派系", [])
	var 最高: String = ""
	var 最高权: int = -1
	for it in 派系:
		var 权: int = int((it as Dictionary).get("权重", 0))
		if 权 > 最高权:
			最高权 = 权
			最高 = str((it as Dictionary).get("名", ""))
	return 最高
# 掌权者重算：权重最高者掌权；发生更替则做恩遇/宿怨清算（B 站队有记忆的核心兑现点）
func _刷新掌权派系_S34(静默: bool) -> void:
	var 派系: Array = 王朝.get("派系", [])
	if 派系.is_empty():
		return
	var 新掌权: String = _权重最高派系_S34()
	var 旧掌权: String = _掌权派系_S34()
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i]
		项["掌权"] = (str(项.get("名", "")) == 新掌权)
		if str(项.get("名", "")) == 新掌权:
			项["掌权月"] = int(项.get("掌权月", 0)) + 1
		else:
			项["掌权月"] = 0
		派系[i] = 项
	王朝["派系"] = 派系
	if 新掌权 != 旧掌权 and not 静默:
		_新朝气象_S34(新掌权)
		_派系清算_S34(新掌权, 旧掌权)
# 新朝气象：易主时新掌权者凭正统性获得一次性权重加成（从在野三派各扣 1/3，零和守恒）。
# 无此项时权臣上台领先幅度为 0，而每月流失 3 点、最弱在野反弹 2 点 → 一个月即被翻盘
# （仿真实测零干预 240 月易主 241 次、平均在位 1.0 月，沦为轮值表）。
# 加成给出 24 点起步领先，新朝可维持 4~6 月；叠加扶持可达 8~10 月，仍会被递增压力压垮。
func _新朝气象_S34(新掌权: String) -> void:
	var 派系: Array = 王朝.get("派系", [])
	if 派系.is_empty() or 新掌权 == "":
		return
	var 在野最低: int = 派系权重上限
	for it in 派系:
		if str((it as Dictionary).get("名", "")) != 新掌权:
			在野最低 = min(在野最低, int((it as Dictionary).get("权重", 派系权重初值)))
	var 抽: int = min(int(新朝气象加成 / 3), max(0, 在野最低 - 派系权重下限))
	if 抽 <= 0:
		return
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i] as Dictionary
		var 权: int = int(项.get("权重", 派系权重初值))
		if str(项.get("名", "")) == 新掌权:
			权 = clamp(权 + 抽 * 3, 派系权重下限, 派系权重上限)
		else:
			权 = clamp(权 - 抽, 派系权重下限, 派系权重上限)
		派系[i]["权重"] = 权
	王朝["派系"] = 派系
func _掌权派系_S34() -> String:
	for it in 王朝.get("派系", []):
		if bool((it as Dictionary).get("掌权", false)):
			return str((it as Dictionary).get("名", ""))
	return ""
# 掌权更替清算（A+B 的交汇点）：新掌权派系按 恩遇 − 宿怨×记仇系数 修正对宗门关系。
# 梭哈单派系的玩家，在其倒台后会因宿怨被扣关系；分散押注者则损失较小。
func _派系清算_S34(新掌权: String, 旧掌权: String) -> void:
	if 新掌权 == "":
		return
	var 项: Dictionary = _取派系项_S34(新掌权)
	var 恩遇: int = int(项.get("恩遇", 0))
	var 宿怨: int = int(项.get("宿怨", 0))
	var 配: Dictionary = _派系配置(新掌权)
	var 记仇: float = float(配.get("grudge_coef", 1.0)) if not 配.is_empty() else 1.0
	var 兑现: float = clamp(float(恩遇) * 恩遇兑现关系, 0.0, 恩遇兑现上限)
	var 记恨: float = float(宿怨) * 清算关系系数 * 记仇
	var 关系: float = float(王朝.get("对宗门关系", 50.0))
	王朝["对宗门关系"] = clamp(关系 + 兑现 - 记恨, 0.0, 100.0)
	# 恩遇兑现后清零（同一笔恩遇不可重复兑现）；宿怨亦清零 —— 新朝清算旧账，翻篇即了结。
	# 原「宿怨减半」会累积成山：分散押注实测 240 月内清算 54 次，关系被反复扣穿至 0。
	项["恩遇"] = 0
	项["宿怨"] = 0
	var 旧名: String = 旧掌权 if 旧掌权 != "" else "（无人）"
	Game.添加纪事("王朝", "朝堂易势", "%s失势，%s上位；念旧恩%s、记宿怨%s，对宗门关系%+.0f"
		% [旧名, 新掌权, 恩遇, 宿怨, 兑现 - 记恨], 2)
	Game._加推演条目("◇ 朝堂易势：%s取代%s掌权（对宗门关系%+.0f）" % [新掌权, 旧名, 兑现 - 记恨], Game.ET_SECT, Game.PRIO_NORMAL, {})
# 权力再分配（零和）：掌权者所失 = 在野三派所得，四派系总和恒为 100（实测守恒，无漏损）。
# 党争动力学的三条支柱（顺序即演化史，每次都是仿真实测逼出来的）：
#   ① 零和 —— 在野派系不能无上限自行积蓄（原模型 120 月后四派系全饱和到 92~100，
#      权重差异消失、掌权沦为随机抖动，实测 120 月易主 138 次，押注毫无意义）。
#   ② 双机制 —— 掌权者同时受【权柄红利 ruling_power】（凭权位从在野抽血）与
#      【反对派压力 ruling_decay】（流失，每在朝 growth 个月再 +3）两股力。
#      纯「掌权者流失均分三派」在数学上必然退化为轮值表：保住第一需 W > 25 + D，
#      初始 W=25 则首月必下台 —— 网格搜索 16 组参数，零干预易主恒 121/120 月。
#      铁律：power ≤ decay（权柄红利永不压过反对派压力），掌权只能续命不能永久；
#      派系续航差异改由 growth 拉开（外戚 8 最粘 / 士族 4 / 边将 3 / 宦官 3）。
#   ③ 抑强扶弱 —— 在野三派按权重升序依次得 (步长+1)/(步长)/(步长-1) 份。
#      纯均分时玩家梭哈单派系可将其顶到 76/100 并锁死另外两派的内容（实测外戚掌权
#      230/240 月、覆盖仅剩 2 派系）；逆序分配让被压制最狠者反弹最猛，杜绝一家独大。
func _结算派系零和_S34() -> void:
	var 派系: Array = 王朝.get("派系", [])
	if 派系.is_empty():
		return
	var 掌权名: String = _掌权派系_S34()
	if 掌权名 == "":
		return
	var 配: Dictionary = _派系配置(掌权名)
	if 配.is_empty():
		return
	var 在朝: int = 0
	var 掌权权: int = 派系权重初值
	var 在野最低: int = 派系权重上限
	for it in 派系:
		var 项: Dictionary = it as Dictionary
		if str(项.get("名", "")) == 掌权名:
			在朝 = int(项.get("掌权月", 0))
			掌权权 = int(项.get("权重", 派系权重初值))
		else:
			在野最低 = min(在野最低, int(项.get("权重", 派系权重初值)))
	# 权柄红利：掌权者凭权位从在野三派抽血；反对派压力：随在朝月数递增的流失
	var 红利: int = int(配.get("ruling_power", 3))
	var 递增: int = int(配.get("ruling_decay_growth", 6))
	var 流失: int = int(配.get("ruling_decay", 6))
	# 递增项作用在【步长】上，不再加进流失量后被 /3 截断吃掉 ——
	# 派系在位常仅 2~4 月，原写法下「每在朝 N 月」门槛永远够不着（实测 growth 全档无效）。
	var 步长: int = int((流失 - 红利) / 3)
	if 递增 > 0:
		步长 += int(在朝 / 递增)
	# 安全钳制：不触碰上下限，保证零和严格守恒（截断会漏损，实测曾漏到总和 24）
	if 步长 > 0:
		步长 = min(步长, 掌权权 - 派系权重下限)
		# 份额最高者拿 2 份，须为其预留 2×步长 的上升空间，否则 clamp 截断破坏守恒
		步长 = min(步长, int((派系权重上限 - 在野最低) / 2))
	elif 步长 < 0:
		步长 = -min(-步长, 在野最低 - 派系权重下限)
	if 步长 == 0:
		return
	# 抑强扶弱：在野三派按权重升序依次得 2/1/0 份（总量 3 份 = 掌权者所失，仍严格守恒）
	# 用意：被压制最狠者反弹最猛，杜绝玩家靠持续扶持一家独大、锁死另外两派的内容
	var 在野序: Array = []
	for j in range(派系.size()):
		if str((派系[j] as Dictionary).get("名", "")) != 掌权名:
			在野序.append(j)
	在野序.sort_custom(func(a, b): return int((派系[a] as Dictionary).get("权重", 0)) < int((派系[b] as Dictionary).get("权重", 0)))
	var 份额: Array = [2, 1, 0]
	for i in range(派系.size()):
		var 项2: Dictionary = 派系[i] as Dictionary
		var 权: int = int(项2.get("权重", 派系权重初值))
		if str(项2.get("名", "")) == 掌权名:
			权 = clamp(权 - 步长 * 3, 派系权重下限, 派系权重上限)
		else:
			var 序位: int = 在野序.find(i)
			var 得: int = 步长 * int(份额[序位]) if 序位 >= 0 and 序位 < 份额.size() else 0
			权 = clamp(权 + 得, 派系权重下限, 派系权重上限)
		派系[i]["权重"] = 权
	王朝["派系"] = 派系

# 月度派系结算（挂 _结算王朝_S34）：势能漂移 → 掌权重算 → 掌权后果 → 外戚索要检查
func _结算派系_S34() -> void:
	if 王朝.get("派系", []).is_empty():
		_初始化派系_S34()
	var 派系: Array = 王朝.get("派系", [])
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i]
		var 名: String = str(项.get("名", ""))
		var 配: Dictionary = _派系配置(名)
		if 配.is_empty():
			continue
		派系[i]["权重"] = clamp(int(项.get("权重", 派系权重初值)), 0, 100)
	_结算派系零和_S34()
	_刷新掌权派系_S34(false)
	# 掌权后果：宦官掌权埋民变雷（民心持续下滑），边将掌权兵祸（危机权重上升）
	var 掌权: String = _掌权派系_S34()
	if 掌权 == "外戚":
		# 姻亲之谊：外戚掌权期间关系逐月自然修复（兑现 CSV「掌权则关系易修」）
		var 关: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关 + 外戚掌权关系修, 0.0, 100.0)
	if 掌权 == "宦官":
		王朝["民心"] = clamp(int(王朝.get("民心", 60)) - 2, 0, 100)
	elif 掌权 == "士族":
		王朝["民心"] = clamp(int(王朝.get("民心", 60)) + 1, 0, 100)
	_外戚索弟子_S34()
	_结算爵位义务_S34()
# 掌权后果系数（供供奉/苗子/危机/战功四处乘算；无掌权者时恒 1.0）
func _派系系数_S34(列名: String) -> float:
	var 掌权: String = _掌权派系_S34()
	if 掌权 == "":
		return 1.0
	var 配: Dictionary = _派系配置(掌权)
	if 配.is_empty():
		return 1.0
	return float(配.get(列名, 1.0))
func _派系供奉系数_S34() -> float:
	var 系数: float = _派系系数_S34("tribute_rate")
	# 朝中有人：外戚掌权时，入赘名录里的弟子在朝中为官，反哺宗门供奉。
	# 没有这条，外戚是四派系里唯一「纯亏」的选择 —— 付出最痛的代价（弟子，宗门命脉）
	# 却全线平庸，实测关系与供奉双垫底、断供最早（65 月）。送弟子因此沦为单向惩罚。
	# 有了这条：送 5 人 → 外戚 1.1 × 1.30 = 1.43，反超宦官 1.3；10 人封顶 1.76。
	# 前期割肉、后期反超，但弟子有限 —— 送太多宗门就空了。这才是有风险的取舍。
	if _掌权派系_S34() == "外戚" and not 入赘名录.is_empty():
		var 加成: float = min(float(入赘名录.size()) * 入赘供奉加成, 入赘供奉加成上限)
		系数 *= 1.0 + 加成
	return 系数
func _派系苗子系数_S34() -> float:
	return _派系系数_S34("talent_rate")
func _派系危机系数_S34() -> float:
	return _派系系数_S34("crisis_rate")
func _派系战功系数_S34() -> float:
	return _派系系数_S34("merit_rate")
# —— 爵位增益：爵位不该是成就徽章，应当是【解锁玩法层】——
# 原实现里爵位只加义务不加收益，护国宗的「可接朝廷委托」甚至是空气（凡间差事无门槛）。
# 现落到两处玩家能直接感知的地方：差事榜容量（更多选择）+ 供奉系数（物质回报）。
func _爵位差事榜上限_S34() -> int:
	# 停权期间爵位权利冻结（关系跌破门槛 —— 见 _结算爵位停权_S34）
	if bool(王朝.get("爵位停权", false)):
		return 王朝差事榜上限
	var 配: Dictionary = _爵位配置(str(王朝.get("宗门爵位", "未册封")))
	if 配.is_empty():
		return 王朝差事榜上限
	return 王朝差事榜上限 + int(配.get("decree_slots", 0))
func _爵位供奉加成_S34() -> float:
	# 停权期间供奉加成同样冻结（爵位不再是拿完就躺的铁饭碗）
	if bool(王朝.get("爵位停权", false)):
		return 1.0
	var 配: Dictionary = _爵位配置(str(王朝.get("宗门爵位", "未册封")))
	if 配.is_empty():
		return 1.0
	return 1.0 + float(配.get("tribute_bonus", 0.0))
# 国师月度荐举：花灵石向朝中安插自己人 —— 兑现 CSV「荐举对象即为其押注的派系」。
# 与扶持的区别：扶持是重锤（+12 权重、冷却 6 月），荐举是滴灌（+4、每月一次）。
# 荐举非掌权派系会被掌权者记恨（宿怨+1），所以「押冷门」有真实代价。
func 荐举派系_S34(派系名: String) -> Dictionary:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 == "未册封":
		return {"成功": false, "原因": "未有爵位，无资格荐举"}
	var 配: Dictionary = _爵位配置(位阶)
	if str(配.get("duty_type", "none")) != "recommend":
		return {"成功": false, "原因": "%s 无荐举之权" % 位阶}
	if bool(王朝.get("爵位停权", false)):
		return {"成功": false, "原因": "%s位停权中，荐举之权暂废（关系需回升至%d）" % [位阶, _爵位门槛_S34()]}
	if 派系名 not in 派系序:
		return {"成功": false, "原因": "无此派系"}
	var 今月: int = int(王朝.get("在位月", 0))
	if 今月 - int(王朝.get("上次荐举月", -99)) < 1:
		return {"成功": false, "原因": "本月已荐举过，下月再议"}
	var 费: int = int(配.get("duty_cost", 0))
	if Game.灵石 < 费:
		return {"成功": false, "原因": "灵石不足（需%d）" % 费}
	var 派系: Array = 王朝.get("派系", [])
	if 派系.is_empty():
		_初始化派系_S34()
		派系 = 王朝.get("派系", [])
	var 在野最低: int = 派系权重上限
	for 项0 in 派系:
		if str((项0 as Dictionary).get("名", "")) != 派系名:
			在野最低 = min(在野最低, int((项0 as Dictionary).get("权重", 派系权重初值)))
	var 增: int = int(float(荐举权重增益) * (帝师荐举倍率 if 位阶 == "帝师" else 1.0))
	var 扣量: int = min(max(1, int(增 / 3)), max(0, 在野最低 - 派系权重下限))
	if 扣量 <= 0:
		return {"成功": false, "原因": "其余三派已无油水可榨，暂难再动"}
	Game.灵石 -= 费
	var 掌权: String = _掌权派系_S34()
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i]
		var 名: String = str(项.get("名", ""))
		if 名 == 派系名:
			项["权重"] = clamp(int(项.get("权重", 0)) + 扣量 * 3, 派系权重下限, 派系权重上限)
			项["恩遇"] = min(int(项.get("恩遇", 0)) + 荐举恩遇增, 恩遇累积上限)
		else:
			项["权重"] = clamp(int(项.get("权重", 0)) - 扣量, 派系权重下限, 派系权重上限)
			if 名 == 掌权:
				项["宿怨"] = int(项.get("宿怨", 0)) + 荐举宿怨增
	王朝["上次荐举月"] = 今月
	王朝["待荐举"] = false
	Game.添加纪事("王朝", "荐举官员", "以%s之位荐举%s党人，耗灵石%d（权重+%d、恩遇+%d）"
		% [位阶, 派系名, 费, 扣量 * 3, 荐举恩遇增], 0)
	return {"成功": true, "消息": "已荐举%s：权重+%d、恩遇+%d" % [派系名, 扣量 * 3, 荐举恩遇增]}
# 扶持派系（玩家主操作）：按派系各取所需 —— 士族要贡献点、边将要丹药、宦官要灵石、
# 外戚要弟子。四种资源对应宗门四条产线，扶持谁就消耗哪条线，逼玩家算账。
func 扶持派系_S34(派系名: String) -> Dictionary:
	if 派系名 not in 派系序:
		return {"成功": false, "原因": "无此派系"}
	# 冷却闸门：无冷却时每月扶持与掌权流失恰好抵消，权重死锁、掌权沦为抖动（仿真实测 120 月易主 241 次）
	var 今月: int = int(王朝.get("在位月", 0))
	var 上次: int = int(王朝.get("上次扶持月", -99))
	if 今月 - 上次 < 扶持冷却月:
		return {"成功": false, "原因": "朝中耳目未消，需再候 %d 月方可动作" % (扶持冷却月 - (今月 - 上次))}
	var 派系: Array = 王朝.get("派系", [])
	if 派系.is_empty():
		_初始化派系_S34()
		派系 = 王朝.get("派系", [])
	var 查: Dictionary = _扶持资源足够_S34(派系名)
	if not bool(查.get("够", false)):
		return {"成功": false, "原因": str(查.get("原因", "资源不足"))}
	# 零和钳制：在野三派不得扣穿权重下限，否则 clamp 截断会漏损（实测曾飘到总和 101）
	var 在野最低: int = 派系权重上限
	for 项0 in 派系:
		if str((项0 as Dictionary).get("名", "")) != 派系名:
			在野最低 = min(在野最低, int((项0 as Dictionary).get("权重", 派系权重初值)))
	var 扣量: int = min(max(1, int(扶持权重增益 / 3)), max(0, 在野最低 - 派系权重下限))
	if 扣量 <= 0:
		return {"成功": false, "原因": "其余三派已无油水可榨，暂难再动"}
	_扣除扶持资源_S34(派系名)
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i]
		var 名: String = str(项.get("名", ""))
		if 名 == 派系名:
			项["权重"] = clamp(int(项.get("权重", 0)) + 扣量 * 3, 派系权重下限, 派系权重上限)
			项["恩遇"] = min(int(项.get("恩遇", 0)) + 扶持恩遇增, 恩遇累积上限)
		else:
			# 扶持即夺权：增益从其余三派各扣（零和，实增 = 扣量 × 3，总和恒定）
			项["权重"] = clamp(int(项.get("权重", 0)) - 扣量, 派系权重下限, 派系权重上限)
			项["宿怨"] = int(项.get("宿怨", 0)) + 扶持宿怨增
		派系[i] = 项
	王朝["派系"] = 派系
	王朝["上次扶持月"] = 今月
	# 不即时刷新掌权：扶持是暗中运作，掌权更替统一在月度结算判定（否则扶持/月度来回抖动）
	Game.添加纪事("王朝", "扶持派系", "倾%s之资扶持%s（%s）" % [str(查.get("类型", "?")), 派系名, str(查.get("量", 0))], 1)
	return {"成功": true, "消息": "已暗中扶持%s：权重+%d、恩遇+%d，其余三派宿怨+%d；次月朝堂见分晓"
		% [派系名, 扣量 * 3, 扶持恩遇增, 扶持宿怨增]}
func _扶持资源足够_S34(派系名: String) -> Dictionary:
	var 配: Dictionary = _派系配置(派系名)
	if 配.is_empty():
		return {"够": false, "原因": "派系配置缺失"}
	var 类型: String = str(配.get("desire_type", ""))
	var 量: int = int(配.get("desire_cost", 0))
	if 类型 == "contribution":
		if Game.贡献点 < 量:
			return {"够": false, "原因": "Game.贡献点不足（需%d，现有%d）" % [量, Game.贡献点]}
	elif 类型 == "pill":
		if _库房丹药数_S34() < 量:
			return {"够": false, "原因": "库房丹药不足（需%d，现有%d）" % [量, _库房丹药数_S34()]}
	elif 类型 == "lingshi":
		if Game.灵石 < 量:
			return {"够": false, "原因": "灵石不足（需%d，现有%d）" % [量, Game.灵石]}
	elif 类型 == "disciple":
		if _可送走弟子_S34().size() < 量:
			return {"够": false, "原因": "无弟子可送入赘（在宗弟子不足）"}
	else:
		return {"够": false, "原因": "未知诉求类型"}
	return {"够": true, "类型": _扶持类型中文(类型), "量": 量}
func _扶持类型中文(类型: String) -> String:
	if 类型 == "contribution":
		return "贡献点"
	if 类型 == "pill":
		return "丹药"
	if 类型 == "lingshi":
		return "Game.灵石"
	if 类型 == "disciple":
		return "弟子"
	return "未知"
func _扣除扶持资源_S34(派系名: String) -> void:
	var 配: Dictionary = _派系配置(派系名)
	var 类型: String = str(配.get("desire_type", ""))
	var 量: int = int(配.get("desire_cost", 0))
	if 类型 == "contribution":
		Game.贡献点 -= 量
	elif 类型 == "pill":
		_消耗库房丹药_S34(量)
	elif 类型 == "lingshi":
		Game.灵石 -= 量
	elif 类型 == "disciple":
		# 外戚扶持即「送弟子入赘」：走待决流程，由玩家点名弟子后扣人
		_外戚索弟子_S34(true)
# 库房丹药计数（Item.类别 混存中英文 → 先归一到中文名再比对，见 S31 踩坑）
func _库房丹药数_S34() -> int:
	var n: int = 0
	for it in Game.宗门库房:
		var 类别: String = str((it as Dictionary).get("类别", ""))
		if Item.类别中文名.get(类别, 类别) == "丹药":
			n += 1
	return n
func _消耗库房丹药_S34(数量: int) -> bool:
	var 剩: int = 数量
	var i: int = 0
	while i < Game.宗门库房.size() and 剩 > 0:
		var 类别: String = str((Game.宗门库房[i] as Dictionary).get("类别", ""))
		if Item.类别中文名.get(类别, 类别) == "丹药":
			Game.宗门库房.remove_at(i)
			剩 -= 1
		else:
			i += 1
	return 剩 == 0
# ——— 册封位阶（C 位阶是契约）———
func _感恩达标郡数_S34(门槛: int) -> int:
	var n: int = 0
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		if int(郡.get("感恩", 0)) >= 门槛:
			n += 1
	return n
func _爵位门槛达成_S34(位阶: String) -> bool:
	var 配: Dictionary = _爵位配置(位阶)
	if 配.is_empty():
		return false
	var 关系: int = int(float(王朝.get("对宗门关系", 0.0)))
	if 关系 < int(配.get("need_relation", 0)):
		return false
	if _感恩达标郡数_S34(50) < int(配.get("need_gratitude_count", 0)):
		return false
	if Game.门派等级 < int(配.get("need_grade", 1)):
		return false
	var 功过类型: String = str(配.get("merit_kind", "none"))
	var 需功过: int = int(配.get("need_merit", 0))
	if 功过类型 == "merit" and Game.功德 < 需功过:
		return false
	if 功过类型 == "karma" and Game.业力 < 需功过:
		return false
	return true
# 当前可受封的位阶（达门槛且高于现位阶；批次 2 只开放前四级）
func 可受封爵位_S34() -> Array:
	var 当前: String = str(王朝.get("宗门爵位", "未册封"))
	var 当前序: int = 爵位序.find(当前)
	var 出: Array = []
	for 位阶 in 爵位本期开放:
		if 爵位序.find(位阶) <= 当前序:
			continue
		if _爵位门槛达成_S34(位阶):
			出.append(位阶)
	return 出
# 受封：解锁权利同时背上义务；爵位只升不降（辞位走 辞去爵位_S34）
func 受封爵位_S34(位阶: String) -> Dictionary:
	if 位阶 not in 爵位本期开放:
		return {"成功": false, "原因": "%s 尚未开放" % 位阶}
	var 当前: String = str(王朝.get("宗门爵位", "未册封"))
	if 爵位序.find(位阶) <= 爵位序.find(当前):
		return {"成功": false, "原因": "%s 不高于现爵位%s" % [位阶, 当前]}
	if not _爵位门槛达成_S34(位阶):
		return {"成功": false, "原因": "未达%s门槛" % 位阶}
	# 自立为王是不可逆的掀桌之举，走专用入口（含郡县重置/清空委托等副作用）
	if 位阶 == "自立为王":
		return 自立为王_S34()
	王朝["宗门爵位"] = 位阶
	王朝["受封月"] = int(王朝.get("在位月", 0))
	# 受封当月不罚，自次月起每月须荐举一次（见 _结算爵位义务_S34）
	王朝["待荐举"] = false
	var 配: Dictionary = _爵位配置(位阶)
	Game.添加纪事("王朝", "受封", "宗门受封为%s：%s。义务——%s"
		% [位阶, str(配.get("right_desc", "")), str(配.get("duty_desc", ""))], 1)
	Game._加推演条目("◇ 宗门受封为%s" % 位阶, Game.ET_SECT, Game.PRIO_HIGH, {})
	return {"成功": true, "消息": "已受封为%s。权利：%s；义务：%s"
		% [位阶, str(配.get("right_desc", "")), str(配.get("duty_desc", ""))]}
func 辞去爵位_S34() -> Dictionary:
	var 当前: String = str(王朝.get("宗门爵位", "未册封"))
	if 当前 == "未册封":
		return {"成功": false, "原因": "本无爵位可辞"}
	王朝["宗门爵位"] = "未册封"
	var 关系: float = float(王朝.get("对宗门关系", 50.0))
	王朝["对宗门关系"] = clamp(关系 - float(辞位关系罚), 0.0, 100.0)
	Game.添加纪事("王朝", "辞爵", "宗门辞去%s，朝廷不悦（关系-%d）" % [当前, 辞位关系罚], 2)
	return {"成功": true, "消息": "已辞去%s，王朝关系-%d" % [当前, 辞位关系罚]}
# 爵位义务月度结算：权利越大，每月要交的「租金」越实（国师荐举耗灵石即在此扣）
func _结算爵位义务_S34() -> void:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 == "未册封":
		return
	var 配: Dictionary = _爵位配置(位阶)
	if 配.is_empty():
		return
	var 义务: String = str(配.get("duty_type", "none"))
	if 义务 == "regent":
		_结算监国摄政义务_S34(位阶)
		return
	if 义务 != "recommend":
		return
	# 荐举是「月度必做的主动决策」，不是被动扣费：到月末仍未荐举才罚。
	# 原实现每月无条件扣 duty_cost（国师 200），而满版图供奉仅 117/推演月 ——
	# 玩家受封国师即净亏 83/推演月，且扣完什么也没得到（左右派系权重未实现）。
	var 费: int = int(配.get("duty_cost", 0))
	if bool(王朝.get("待荐举", false)):
		var 关系: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关系 - float(荐举失期关系罚), 0.0, 100.0)
		Game.添加纪事("王朝", "荐举失期", "%s 逾期未荐举朝臣（应耗灵石%d），朝廷颇有微词" % [位阶, 费], 2)
	王朝["待荐举"] = true

# ——— 批次 4 正邪终局：监国 / 摄政 / 自立为王 ———
# 摄政义务：民心每月持续下滑（摄政＝以民心换供奉的高危位阶；监国无月度义务，代价在改朝换代时结算）
func _结算监国摄政义务_S34(位阶: String) -> void:
	if 位阶 != "摄政":
		return
	var 民心: int = int(王朝.get("民心", 60))
	王朝["民心"] = clamp(民心 - 摄政民心月损, 0, 100)
	Game.添加纪事("王朝", "摄政施政", "摄政擅权，民心持续下滑（民心-%d，现%d）" % [摄政民心月损, int(王朝.get("民心", 0))], 1)

# 监国权利：废立皇帝（不可逆大事件；动摇国本，民心/国祚双跌且业力加身）
func 废立皇帝_S34(新帝名: String = "") -> Dictionary:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 != "监国":
		return {"成功": false, "原因": "非监国无废立之权"}
	if not _爵位生效中_S34():
		return {"成功": false, "原因": "爵位停权中，权利冻结"}
	var 旧帝: Dictionary = 王朝.get("皇帝", {}) if 王朝.get("皇帝", null) != null else {}
	var 旧名: String = str(旧帝.get("名", "?"))
	var 姓: String = str(Game.王朝帝姓池[randi() % Game.王朝帝姓池.size()])
	var 帝名: String = 新帝名 if 新帝名 != "" else str(Game.王朝帝名池[randi() % Game.王朝帝名池.size()])
	var 年龄: int = randi_range(16, 45)
	王朝["皇帝"] = {
		"名": 姓 + 帝名,
		"年龄": 年龄,
		"寿元": 年龄 + randi_range(12, 32),
		"性格": str(Game.王朝性格池[randi() % Game.王朝性格池.size()]),
		"对宗门": 20,
	}
	var 民心: int = int(王朝.get("民心", 60))
	王朝["民心"] = clamp(民心 - 废立皇帝民心罚, 0, 100)
	var 国祚: int = int(王朝.get("国祚", 100))
	王朝["国祚"] = clamp(国祚 - 废立皇帝国祚罚, 0, 100)
	Game.业力 += 10
	王朝["押注皇子ID"] = ""
	var 新名: String = str(王朝["皇帝"].get("名", ""))
	Game.添加纪事("王朝", "废立皇帝", "监国行伊霍之事，废%s、立%s（民心-%d、国祚-%d，不可逆）"
		% [旧名, 新名, 废立皇帝民心罚, 废立皇帝国祚罚], 2)
	return {"成功": true, "消息": "已废%s、立%s。民心-%d、国祚-%d"
		% [旧名, 新名, 废立皇帝民心罚, 废立皇帝国祚罚]}

# 摄政权利：操控国策（国策真实作用于供奉/反制/关系三处，非风味配置）
func 操控国策_S34(国策名: String) -> Dictionary:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 != "摄政":
		return {"成功": false, "原因": "非摄政无改易国策之权"}
	if not _爵位生效中_S34():
		return {"成功": false, "原因": "爵位停权中，权利冻结"}
	var 合法: bool = false
	for 行 in _读王朝配置():
		if str((行 as Dictionary).get("policy_name", "")) == 国策名:
			合法 = true
			break
	if not 合法:
		return {"成功": false, "原因": "无此国策：%s" % 国策名}
	var 旧策: String = str(王朝.get("国策", "崇道"))
	王朝["国策"] = 国策名
	var 民心: int = int(王朝.get("民心", 60))
	王朝["民心"] = clamp(民心 - 操控国策民心罚, 0, 100)
	Game.添加纪事("王朝", "更易国策", "摄政更易国策：%s → %s（民心-%d）" % [旧策, 国策名, 操控国策民心罚], 1)
	return {"成功": true, "消息": "国策已改为%s（原%s），民心-%d" % [国策名, 旧策, 操控国策民心罚]}

# 自立为王：脱离王朝、与旧朝永久敌对；再无朝廷委托，郡县关系全部重置
func 自立为王_S34() -> Dictionary:
	var 位阶: String = str(王朝.get("宗门爵位", "未册封"))
	if 位阶 == "自立为王":
		return {"成功": false, "原因": "本已自立，无需再举"}
	if not _爵位门槛达成_S34("自立为王"):
		return {"成功": false, "原因": "未达自立门槛（需宗门品级%d）" % int(_爵位配置("自立为王").get("need_grade", 8))}
	var 旧国号: String = str(王朝.get("国号", "?"))
	王朝["宗门爵位"] = "自立为王"
	王朝["自立"] = true
	王朝["对宗门关系"] = 0.0
	王朝["待决委托"] = []
	王朝["待决反制"] = []
	王朝["押注皇子ID"] = ""
	# 郡县关系全部重置：自立即与旧朝切割，地方态度重来
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		郡["忠顺"] = 20
		郡["感恩"] = 0
	Game.添加纪事("王朝", "自立为王", "宗门脱离%s自立为王，与旧朝永久敌对；再无朝廷委托，郡县关系全部重置" % 旧国号, 2)
	Game._加推演条目("★ 宗门自立为王，与%s永久敌对" % 旧国号, Game.ET_SECT, Game.PRIO_HIGH, {})
	return {"成功": true, "消息": "已脱离%s自立为王。代价：再无朝廷委托、郡县关系重置、与旧朝永久敌对" % 旧国号}

# 改朝换代时的爵位代价：监国「宗门同受重伤」/ 摄政「翻车」
func _改朝换代爵位后果_S34(旧位阶: String) -> void:
	if 旧位阶 == "监国":
		Game.灵石 -= int(float(Game.灵石) * 监国覆灭灵石率)
		Game.香火值 = max(0, Game.香火值 - 监国覆灭香火罚)
		for d in Game.弟子列表:
			d.忠诚 = clampi(int(d.忠诚) - 监国覆灭忠诚罚, 0, 100)
		Game.添加纪事("王朝", "监国之祸", "旧朝覆灭，监国与国祚绑定，宗门同受重伤（Game.灵石-%d%%、Game.香火值-%d、全宗忠诚-%d）"
			% [int(监国覆灭灵石率 * 100), 监国覆灭香火罚, 监国覆灭忠诚罚], 2)
	elif 旧位阶 == "摄政":
		Game.灵石 -= int(float(Game.灵石) * 摄政翻车灵石率)
		Game.香火值 = max(0, Game.香火值 - 摄政翻车香火罚)
		for d in Game.弟子列表:
			d.忠诚 = clampi(int(d.忠诚) - 摄政翻车忠诚罚, 0, 100)
		Game.添加纪事("王朝", "摄政翻车", "改朝换代，摄政一朝倾覆（Game.灵石-%d%%、Game.香火值-%d、全宗忠诚-%d）"
			% [int(摄政翻车灵石率 * 100), 摄政翻车香火罚, 摄政翻车忠诚罚], 2)

# ——— 外戚索弟子（D 真实牺牲）———
func _可送走弟子_S34() -> Array:
	var 出: Array = []
	for d in Game.弟子列表:
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		出.append(d)
	return 出
# 外戚掌权时点名索要弟子：挑在宗弟子中资质最优者（专挑玩家最舍不得的那个）
func _外戚索弟子_S34(强制: bool = false) -> void:
	if not 外戚索要待决.is_empty():
		return
	if _掌权派系_S34() != "外戚" and not 强制:
		return
	var 上月: int = int(王朝.get("上次索要月", -99))
	var 今月: int = int(王朝.get("在位月", 0))
	if not 强制 and 今月 - 上月 < 外戚索要周期月:
		return
	var 候选: Array = _可送走弟子_S34()
	if 候选.is_empty():
		# 无可遣之人 = 无力应命，视同拂其意（半额拒索罚）。
		# 不处理的话，玩家只要维持「宗中没有合适弟子」就能白嫖外戚的长期掌权。
		if 强制:
			return
		var 罚: float = float(外戚拒索关系罚) * 0.5
		var 关: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关 - 罚, 0.0, 100.0)
		王朝["上次索要月"] = 今月
		Game.添加纪事("王朝", "外戚索要",
			"外戚点名索要弟子，宗中无可遣之人，拂其意（关系-%.0f）" % 罚, 2)
		return
	# 挑资质最优者：Disciple.资质权重 值越小越稀有（即越优），现读真源不手抄资质序
	var 目标 = null
	var 最优权: float = 1.0e9
	for d in 候选:
		var 权: float = float(Disciple.资质权重.get(d.资质, 50.0))
		if 权 < 最优权:
			最优权 = 权
			目标 = d
	if 目标 == null:
		return
	王朝["上次索要月"] = 今月
	外戚索要待决 = {
		"弟子ID": int(目标.弟子ID),
		"弟子名": str(目标.姓名),
		"境界": str(目标.境界),
		"资质": str(Disciple.资质显示.get(目标.资质, "?")),
	}
	Game.添加纪事("王朝", "外戚索人", "外戚掌权，点名索要%s（%s·%s）入赘。应允则关系+%d，拒绝则关系-%d"
		% [str(目标.姓名), str(目标.境界), str(Disciple.资质显示.get(目标.资质, "?")),
		外戚应允关系增, 外戚拒索关系罚], 2)
# 玩家抉择：答应 = 真送走弟子（触发情感连锁）；拒绝 = 关系与外戚权重双罚
func 应对外戚索要_S34(答应: bool) -> Dictionary:
	if 外戚索要待决.is_empty():
		return {"成功": false, "原因": "当前无外戚索要"}
	var 弟子ID: int = int(外戚索要待决.get("弟子ID", -1))
	var 弟子名: String = str(外戚索要待决.get("弟子名", "?"))
	外戚索要待决 = {}
	if 答应:
		var 果: Dictionary = _送弟子入赘_S34(弟子ID)
		if not bool(果.get("成功", false)):
			return 果
		var 关系: float = float(王朝.get("对宗门关系", 50.0))
		王朝["对宗门关系"] = clamp(关系 + float(外戚应允关系增), 0.0, 100.0)
		_加派系权重_S34("外戚", 外戚应允权重增)
		return {"成功": true, "消息": "%s 已入赘外戚家，王朝关系+%d、外戚权重+%d"
			% [弟子名, 外戚应允关系增, 外戚应允权重增]}
	var 关系2: float = float(王朝.get("对宗门关系", 50.0))
	王朝["对宗门关系"] = clamp(关系2 - float(外戚拒索关系罚), 0.0, 100.0)
	_加派系权重_S34("外戚", 外戚拒索权重增)
	Game.添加纪事("王朝", "拒婚", "宗门回绝外戚索要，外戚记恨（关系-%d、外戚权重+%d）"
		% [外戚拒索关系罚, 外戚拒索权重增], 2)
	return {"成功": true, "消息": "已回绝外戚，王朝关系-%d、外戚权重+%d" % [外戚拒索关系罚, 外戚拒索权重增]}
func _加派系权重_S34(派系名: String, 增量: int) -> void:
	var 派系: Array = 王朝.get("派系", [])
	for i in range(派系.size()):
		var 项: Dictionary = 派系[i]
		if str(项.get("名", "")) == 派系名:
			项["权重"] = clamp(int(项.get("权重", 0)) + 增量, 0, 100)
			派系[i] = 项
	王朝["派系"] = 派系
	_刷新掌权派系_S34(false)
# 送弟子入赘：抄 处理坐化 的离宗范式（先清退资产与司职、再断链、最后从 Game.弟子列表 移除），
# 立刻触发师父断链 / 道侣断链 / 同门忠诚波动 —— 打在玩家已有情感投入的对象上。
func _送弟子入赘_S34(弟子ID: int) -> Dictionary:
	var 目标 = null
	for d in Game.弟子列表:
		if int(d.弟子ID) == 弟子ID:
			目标 = d
			break
	if 目标 == null:
		return {"成功": false, "原因": "该弟子已不在宗"}
	# ① 资产归还宗门（抄 处理坐化：灵兽归栏、装备背包入库房）
	if 目标.主宠灵兽 != null:
		var 兽: Beast = 目标.主宠灵兽
		目标.主宠灵兽 = null
		兽.取消出战()
		if not Game.灵兽库存.has(兽):
			Game.灵兽库存.append(兽)
	if 目标.副宠灵兽 != null:
		var 兽2: Beast = 目标.副宠灵兽
		目标.副宠灵兽 = null
		兽2.取消出战()
		if not Game.灵兽库存.has(兽2):
			Game.灵兽库存.append(兽2)
	for it in 目标.装备.values():
		Game.宗门库房.append(it)
	目标.装备.clear()
	for it in 目标.背包:
		Game.宗门库房.append(it)
	目标.背包.clear()
	# ② 同门人心浮动（先记名，再断链，避免目标自身被误伤）
	var 至亲: Array = []
	for d in Game.弟子列表:
		if int(d.弟子ID) == 弟子ID:
			continue
		if d.状态 == "失踪" or d.状态 == "陨落" or d.状态 == "叛出":
			continue
		var 至: bool = false
		if int(d.师父ID) == 弟子ID or int(目标.师父ID) == int(d.弟子ID):
			至 = true
		if int(d.道侣ID) == 弟子ID:
			至 = true
		if 至:
			至亲.append(d)
			d.忠诚 = clamp(int(d.忠诚) - 入赘至亲忠诚罚, 0, 100)
		else:
			d.忠诚 = clamp(int(d.忠诚) - 入赘同门忠诚罚, 0, 100)
	# ③ 清退司职 + 断道侣 + 断师徒链（复用 S29 既有断链，保证不残留悬挂引用）
	Game._叛离清退司职(目标)
	if int(目标.道侣ID) >= 0:
		var 伴侣 = _取弟子_S34(str(目标.道侣ID))
		if 伴侣 != null and int(伴侣.道侣ID) == 弟子ID:
			伴侣.道侣ID = -1
			伴侣.道侣 = ""
	目标.道侣ID = -1
	目标.道侣 = ""
	Game._断链_师父离场(弟子ID)
	# ④ 留档 + 移出弟子列表
	var 姓名: String = str(目标.姓名)
	var 资质: String = str(Disciple.资质显示.get(目标.资质, "?"))
	var 境界: String = str(目标.境界)
	入赘名录.append({
		"名": 姓名,
		"资质": 资质,
		"境界": 境界,
		"去向": "外戚府",
		"日": Game.累计游戏日,
	})
	目标.状态 = "入赘"
	Game.弟子列表.erase(目标)
	Game.添加纪事("王朝", "弟子入赘", "%s（%s·%s）应外戚之请入赘，脱离宗门。至亲%d人心绪不宁"
		% [姓名, 境界, 资质, 至亲.size()], 2)
	Game._加推演条目("◇ %s 入赘外戚府，自此脱离宗门" % 姓名, Game.ET_SECT, Game.PRIO_HIGH, {"弟子": 姓名})
	return {"成功": true, "消息": "%s 已入赘外戚府，%d 名至亲忠诚下滑" % [姓名, 至亲.size()]}

# 郡县月香火 / 月灵石基准（按城邦等级；对齐 GDD §4.3 等级表）
# 凡间郡县供奉基准【日频实加】—— 项目「月产」命名全部误导，实为每次推演(1累计游戏日)全额加
# 满版图(9凡俗城)盛世×崇道 ≈ 2700/30 日均89；配基础香火190 → 合计279 ≈ 设计锚点280
# （280×2 = 560 = 气运香火速率软上限，刚好卡住不满溢）
const 郡县月香火: Dictionary = {1: 130, 2: 220, 3: 350, 4: 530}
const 王朝月长: int = 30              # 1 王朝月 = 30 游戏日（推演一月 每次推进 1 游戏日）
const 王朝差事榜上限: int = 4         # 凡间差事榜同时悬挂条数
# 凡间郡县供奉灵石基准【日频实加】，对齐 S32 领地月灵石 与 运维封顶 318 的同口径
# 满版图盛世×崇道 ≈ 79（运维封顶318 的 24.5%，落在 S32 的 11%~28% 区间内）
# 乱世×崇道 ≈ 12、灭法国策 = 0 —— 供奉随王朝阶段断崖，玩家才有理由经营王朝
const 郡县月灵石: Dictionary = {1: 4, 2: 7, 3: 11, 4: 14}
# 感恩系数：感恩0 → 0.4 倍，感恩100 → 1.0 倍（双轴设计：感恩度决定供奉意愿，忠顺度决定叛乱）
const 郡县供奉感恩下限: float = 0.4
const 郡县供奉感恩权重: float = 0.6
# S34 批次 3 地基：对宗门关系进入供奉公式。
#   原实现供奉 = 感恩 × 阶段 × 国策 × 派系 × 爵位，唯独不含关系；而爵位只增不减
#   → 关系是「达标即永久」的一次性门票。五种反制有三种靠「扣关系」做代价，
#     玩家拿到帝师后拒绝任何反制都是零代价，两难根本不成立（实测结论，非推测）。
#   关系 0 → ×0.6、50 → ×1.0（不赚不赔中枢）、100 → ×1.4
const 王朝关系供奉下限: float = 0.6
const 王朝关系供奉权重: float = 0.8
# ============ S34 批次 3：王朝反制（有牙齿） ============
# 反制决策窗口：生成待决后有 N 个王朝月可决策，逾期自动按最坏结果结算
const 反制决策窗口: int = 2
# 业力来源拓宽（原实现只有「择九幽邪道」一处 +10，灭法令需 200 → 永远触发不了）
const 反制抗命业力: int = 5
const 反制扶持叛军业力: int = 15
const 反制迎战得胜业力: int = 10
# 扣押弟子的三条路：赎回（Game.灵石）/ 营救（遣弟子，胜则感恩大涨）/ 拖延（忠诚罚、数月后放回）
const 反制等待忠诚罚: int = 20
const 反制等待月数: int = 6
const 反制营救成功率基: float = 0.35
const 反制营救成功率权: float = 0.30
# 郡县兵力 → 战力换算（GDD §4.3：L1 200 / L2 800 / L3 3000 / L4 12000 兵力；
# 练气弟子战力基准 100 → 换算 0.1 后 L1 需 20 战力、L4 需 1200 战力，梯度合理）
const 禁军战力换算: float = 0.10
# 断供不归零：降至三成，留修复余地（原设计归零 → 玩家更没资源修复 → 死亡螺旋）
const 断供供奉折损: float = 0.30
# 每座断供郡每月拖累民心（常量化，便于校验器与仿真现读）。
#   取 3 而非 1：民心向中值 55 回归的速率在民心 30 时为 +2.5/月，
#   单郡 -1/月 压不过回归 → 实测 240 月民变 0 次触发（死代码）。
const 断供民心拖累: int = 3
# 灭法令二级条件的国祚线 / 邪道业力线
const 灭法令国祚线: int = 30
const 灭法令业力线: int = 100
# ============ S34 批次3收尾：朝廷委托（护国宗不可拒征调） ============
# 与反制对称：王朝主动点名宗门、强制接的差事。仅护国宗收，自立为王豁免。
const 委托决策窗口: int = 3          # 生成待决后有 N 个王朝月可应征，逾期按拖延最严档结算
const 委托生成间隔: int = 6           # 两条强制委托之间至少隔 N 个王朝月
# 皇子系统（GDD §5：中衰期玩家焦点 = 站队、押注继承人）
const 皇子数下限: int = 2
const 皇子数上限: int = 4
const 皇子生成国祚线: int = 55      # 国祚低于此值（中衰/乱世）才生皇子
const 皇子年龄下限: int = 16
const 皇子年龄上限: int = 40
const 押对关系增: int = 40
const 押对恩遇增: int = 2
const 押错关系罚: int = 40
const 改押关系罚: int = 5
# 可调停民变的最低爵位（国师及以上 —— 兑现爵位表 right_desc 的承诺）
const 调停民变爵位序: Array = ["国师", "帝师", "监国", "摄政"]
# 皇子登基时其所属派系获得的权重增益（让押注与党争两套系统咬合）
const 皇子继位派系增益: int = 10
# 对宗门关系每月自然衰减基数（× 国策 attitude_decay 0.7~2.5）
# 基准 2.0 → 崇道1.4/月（约36月见底）、重文2.0、尚武2.6、猜忌4.0、灭法5.0（约10月见底）
# 回升通道：凡间差事成/败按 reward_gratitude / 4 折算（见 _结算凡间差事_S34）
# TODO(S34批次3)：反制机制接入后，按「关系阈值触发朝廷打压」的实际手感回调此值
const 王朝关系衰减基数: float = 2.0
# 已解锁的凡俗郡县 key 列表（未解锁城市不产供奉，避免新档白拿满版图收益）
func _已解锁凡俗郡_S34() -> Array:
	var out: Array = []
	for k in 郡县状态.keys():
		var 郡: Dictionary = 郡县状态[k]
		if not bool(郡.get("凡俗", false)):
			continue
		if not Game.检查商路城市解锁(str(郡.get("解锁条件", "")), str(k)):
			continue
		out.append(k)
	return out
# 郡县供奉系数：感恩 × 阶段 × 国策（灾情郡自顾不暇，折半）
func _郡县供奉系数_S34(郡: Dictionary) -> float:
	var 阶配: Dictionary = _王朝阶段配置(str(王朝.get("阶段", "开国")))
	var 国策配: Dictionary = _王朝国策配置(str(王朝.get("国策", "崇道")))
	var 阶段系数: float = float(阶配.get("tribute_rate", 1.0)) if not 阶配.is_empty() else 1.0
	var 国策系数: float = float(国策配.get("tribute_rate", 1.0)) if not 国策配.is_empty() else 1.0
	var 感恩: int = clamp(int(郡.get("感恩", 0)), 0, 100)
	var 感恩系数: float = 郡县供奉感恩下限 + float(感恩) / 100.0 * 郡县供奉感恩权重
	if int(郡.get("灾情", 0)) > 0:
		感恩系数 *= 0.5
	# 派系掌权后果：士族 1.00 持平、边将 0.90、宦官 1.30、外戚 1.10（S34 批次 2）
	# 爵位供奉加成：爵位爬升的物质回报（原实现爵位只加义务不加收益，
	# 受封国师在经济上净亏，玩家没有理由爬）
	# 对宗门关系系数（批次 3 地基）：朝廷待宗门厚薄，直接影响各郡供奉多寡
	var 关系: float = clamp(float(王朝.get("对宗门关系", 50.0)), 0.0, 100.0)
	var 关系系数: float = 王朝关系供奉下限 + 关系 / 100.0 * 王朝关系供奉权重
	# 断供标记：该郡供奉降至三成（不归零，留修复余地，杜绝死亡螺旋）
	var 断供系数: float = 断供供奉折损 if _郡有标记_S34(str(郡.get("郡ID", "")), "断供") else 1.0
	return 感恩系数 * 阶段系数 * 国策系数 * _派系供奉系数_S34() * _爵位供奉加成_S34() * 关系系数 * 断供系数 * _开国建制系数_S34(郡) * _信仰供奉系数_S34(郡)
# 凡间供奉香火（S34 核心：香火与凡人世界挂钩，玩家才有理由经营王朝）
func _郡县供奉香火_S34() -> int:
	if 王朝.is_empty() or 郡县状态.is_empty():
		return 0
	var 总: float = 0.0
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k]
		var 基准: float = float(郡县月香火.get(int(郡.get("等级", 1)), 0))
		总 += 基准 * _郡县供奉系数_S34(郡)
	return int(总)
# 凡间供奉灵石（凡间版图的直接经济回报；满版图约 117/月 = 运维封顶 318 的 37%）
func _郡县供奉灵石_S34() -> int:
	if 王朝.is_empty() or 郡县状态.is_empty():
		return 0
	var 总: float = 0.0
	for k in _已解锁凡俗郡_S34():
		var 郡: Dictionary = 郡县状态[k]
		var 基准: float = float(郡县月灵石.get(int(郡.get("等级", 1)), 0))
		总 += 基准 * _郡县供奉系数_S34(郡)
	return int(总)


# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["王朝"] = 王朝
	data["凡间差事榜"] = 凡间差事榜
	data["凡间差事进行中"] = 凡间差事进行中
	data["郡县状态"] = 郡县状态
	data["郡信仰"] = 郡信仰
	data["凡人城镇"] = 凡人城镇
	data["王朝奇观"] = 王朝奇观
	data["建造中奇观"] = 建造中奇观
	data["待决策办差奇遇"] = 待决策办差奇遇
	return data

func from_dict(data: Dictionary) -> void:
	if "王朝" in data: 王朝 = data["王朝"]
	if "凡间差事榜" in data: 凡间差事榜 = data["凡间差事榜"]
	if "凡间差事进行中" in data: 凡间差事进行中 = data["凡间差事进行中"]
	if "郡县状态" in data: 郡县状态 = data["郡县状态"]
	if "郡信仰" in data: 郡信仰 = data["郡信仰"]
	if "凡人城镇" in data: 凡人城镇 = data["凡人城镇"]
	if "王朝奇观" in data: 王朝奇观 = data["王朝奇观"]
	if "建造中奇观" in data: 建造中奇观 = data["建造中奇观"]
	if "待决策办差奇遇" in data: 待决策办差奇遇 = data["待决策办差奇遇"]
