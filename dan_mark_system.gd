class_name DanMarkSystem extends RefCounted

# ===== 丹纹系统状态变量 =====
var 丹纹图谱: Dictionary = {}       # 丹药名 -> 该丹历史最高纹数（0 不入谱）
var 丹纹日志: Array = []            # 最近新纪录 [{丹名,纹,日,分档}]，上限 Game.丹纹日志上限
var 丹纹表缓存: Dictionary = {}     # 品阶 -> 配置行
var 丹纹分档缓存: Array = []        # 分档表（按 mark_min 升序）
var 丹纹图谱档缓存: Array = []      # 图谱里程碑表（按 need_score 升序）
var 丹纹今日纪事: int = 0           # 现实日限流：防止批量炼制灌屏
var 丹纹纪事日: int = 0


## 图谱总分 = 各丹最高纹之和（满分 = 丹方数 × 9）
func 丹纹图谱总分() -> int:
	var 总: int = 0
	for k in 丹纹图谱.keys():
		总 += int(丹纹图谱[k])
	return 总

## 已达成的最后一个里程碑（表按 need 升序）
func 丹纹图谱加成() -> Dictionary:
	var 分: int = 丹纹图谱总分()
	var 档: Array = Game._读表_丹纹图谱档()
	var 结果: Dictionary = {"success": 0.0, "rate": 0.0, "name": "", "next": null}
	for t in 档:
		var d: Dictionary = t as Dictionary
		if 分 >= int(d["need"]):
			结果["success"] = float(d["success"])
			结果["rate"] = float(d["rate"])
			结果["name"] = str(d["name"])
			结果["codex_id"] = str(d["codex_id"])
		else:
			if 结果["next"] == null:
				结果["next"] = d
			break
	return 结果

## 炼丹成功率加成（供执行炼丹传给 AlchemySystem）
func 丹纹图谱成功率加成() -> float:
	return float(丹纹图谱加成().get("success", 0.0)) / 100.0

## 产出丹药时赋予丹纹：记图谱、刷纪录、限流纪事。返回纹数
func 赋予丹纹(丹药, 阶: String, 丹堂等级: int = 1) -> int:
	if 丹药 == null:
		return 0
	var 纹: int = Game.掷丹纹(阶, 丹堂等级)
	丹药.丹纹 = 纹
	if 纹 <= 0:
		return 0
	var 丹名: String = str(丹药.名称)
	var 旧: int = int(丹纹图谱.get(丹名, 0))
	if 纹 > 旧:
		丹纹图谱[丹名] = 纹
		丹纹日志.push_front({"丹名": 丹名, "纹": 纹, "日": Game._今日序号(), "阶": Game._丹纹归一品阶(阶), "分档": str(Game.丹纹分档(纹).get("name", ""))})
		while 丹纹日志.size() > Game.丹纹日志上限:
			丹纹日志.pop_back()
		_丹纹纪事(丹名, 纹, 阶, true)
	return 纹

func _丹纹纪事(丹名: String, 纹: int, 阶: String, 新纪录: bool) -> void:
	var 今日: int = Game._今日序号()
	if 丹纹纪事日 != 今日:
		丹纹纪事日 = 今日
		丹纹今日纪事 = 0
	if 丹纹今日纪事 >= Game.丹纹每日纪事上限:
		return
	var 档: Dictionary = Game.丹纹分档(纹)
	var 异象: String = str(档.get("omen", ""))
	if 纹 < 4 and not 新纪录:
		return
	丹纹今日纪事 += 1
	var 文: String = "%s（%s）成%s" % [丹名, Game._丹纹归一品阶(阶), Game.丹纹名(纹)]
	if 新纪录:
		文 += "，刷新图谱纪录"
	if not 异象.is_empty():
		文 += "：" + 异象
	Game.添加纪事("庶务", "丹纹天成", 文, 2 if 纹 >= 7 else 1)

## 服用结算：药效 ×倍率，丹毒按纹增减（返回摘要文本追加到既有摘要后）
func 丹纹服用摘要(阶: String, 纹: int) -> String:
	if 纹 <= 0:
		return ""
	var 毒: float = Game.丹纹丹毒变化(阶, 纹)
	var 段: String = "丹纹×%.2f药效" % Game.丹纹药效倍率(阶, 纹)
	if 毒 < -0.05:
		段 += "、丹毒%.1f" % 毒
	return 段

## UI：图谱总览（丹名/最高纹/分档）
func 丹纹图谱总览() -> Array:
	var 表: Array = []
	for k in 丹纹图谱.keys():
		var 纹: int = int(丹纹图谱[k])
		表.append({"丹名": str(k), "纹": 纹, "分档": str(Game.丹纹分档(纹).get("name", "无纹"))})
	表.sort_custom(func(a, b): return int(a["纹"]) > int(b["纹"]))
	return 表

func 丹纹总览() -> Dictionary:
	var 加成: Dictionary = 丹纹图谱加成()
	var 下一: Dictionary = 加成.get("next", {}) as Dictionary
	return {"总分": 丹纹图谱总分(), "种数": 丹纹图谱.size(), "里程碑": str(加成.get("name", "")),
		"成功率加成": float(加成.get("success", 0.0)), "出纹加成": float(加成.get("rate", 0.0)),
		"下一档": 下一, "日志": 丹纹日志}

func _丹纹补缺() -> void:
	if not (丹纹图谱 is Dictionary):
		丹纹图谱 = {}
	if not (丹纹日志 is Array):
		丹纹日志 = []
	if not (丹纹表缓存 is Dictionary):
		丹纹表缓存 = {}
	if not (丹纹分档缓存 is Array):
		丹纹分档缓存 = []
	if not (丹纹图谱档缓存 is Array):
		丹纹图谱档缓存 = []
	丹纹今日纪事 = int(丹纹今日纪事)
	丹纹纪事日 = int(丹纹纪事日)

# ==================== S45 符箓因子网络（人/器/法/势 四源决定成率与符纹，镜像 S38/S42 范式） ====================
# 设计：炼符产出由 多维度因子 决定 成功率 与 符纹率，
#   人：符师灵根品阶/灵根类型/道途（档位）+ 心境/心魔/忠诚/境界序/政绩（连续）
#   器/法/势：符纸（符堂等级·成率）/朱砂（符堂等级·出纹）/符师在编/符箓图谱/宗门气运
# 杜绝假系统：CSV 为唯一真源，炼符成功率/符纹率真消费，符堂 UI 真展示。
var 符箓因子档缓存: Array = []
var 符箓因子线缓存: Array = []
var 符箓来源缓存: Dictionary = {}
var 符箓表缓存: Dictionary = {}   # config/item_talisman.csv -> {talisman_id: cfg}（懒加载，不入库）
var _符品级缓存: Array = []       # config/talisman_grade_config.csv（懒加载，不入库）
var _符产量缓存: Dictionary = {}   # config/talisman_yield_config.csv（懒加载，不入库）
var _符纸表缓存: Dictionary = {}   # config/talisman_paper_config.csv（懒加载，不入库）
# S45-4 符纹三表缓存（镜像丹纹 S37，懒加载，不入库）
var _符纹表缓存: Dictionary = {}   # config/talisman_mark_config.csv -> 品阶 -> 配置行
var _符纹分档缓存: Array = []      # config/talisman_mark_tier.csv（按 mark_min 升序）
var _符纹图谱档缓存: Array = []    # config/talisman_mark_codex.csv（按 need_score 升序）
var _符等级缓存: Array = []       # S45-6 config/talisman_level_config.csv（按 level 升序，懒加载）
const 符箓个人封顶成率: float = 0.18
const 符箓个人封顶出纹: float = 0.18
const 符纹每级符堂加成: float = 0.03   # 符堂每级 +3% 逐纹概率（镜像 丹纹每级丹堂加成）
const 符纹售价上限倍率: float = 2.0    # 符纹售价加价封顶（镜像 Game.丹纹售价上限倍率）
const 符纹日志上限: int = 20


# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["丹纹图谱"] = 丹纹图谱
	data["丹纹日志"] = 丹纹日志
	data["丹纹表缓存"] = 丹纹表缓存
	data["丹纹分档缓存"] = 丹纹分档缓存
	data["丹纹图谱档缓存"] = 丹纹图谱档缓存
	data["丹纹今日纪事"] = 丹纹今日纪事
	data["丹纹纪事日"] = 丹纹纪事日
	return data

func from_dict(data: Dictionary) -> void:
	if "丹纹图谱" in data: 丹纹图谱 = data["丹纹图谱"]
	if "丹纹日志" in data: 丹纹日志 = data["丹纹日志"]
	if "丹纹表缓存" in data: 丹纹表缓存 = data["丹纹表缓存"]
	if "丹纹分档缓存" in data: 丹纹分档缓存 = data["丹纹分档缓存"]
	if "丹纹图谱档缓存" in data: 丹纹图谱档缓存 = data["丹纹图谱档缓存"]
	if "丹纹今日纪事" in data: 丹纹今日纪事 = data["丹纹今日纪事"]
	if "丹纹纪事日" in data: 丹纹纪事日 = data["丹纹纪事日"]


# ===== 以下由 game_state.gd 迁入（子系统拆分 S45 批次）=====
func _读表_丹纹() -> Dictionary:
	if self.丹纹表缓存.has("mark"):
		return self.丹纹表缓存["mark"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/pill_mark_config.csv", FileAccess.READ)
	if f == null:
		push_warning("pill_mark_config.csv 缺失，丹纹表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 7:
			continue
		var 阶: String = p[0].strip_edges()
		if 阶.is_empty():
			continue
		表[阶] = {
			"grade": 阶,
			"base_rate": float(p[1]),
			"base_toxin": float(p[2]),
			"effect_per_mark": float(p[3]),
			"price_per_mark": float(p[4]),
			"detox_per_mark": float(p[5]),
			"max_mark": int(p[6]),
		}
	self.丹纹表缓存["mark"] = 表
	return 表


func _读表_丹纹分档() -> Array:
	if not self.丹纹分档缓存.is_empty():
		return self.丹纹分档缓存
	var 表: Array = []
	var f = FileAccess.open("res://config/pill_mark_tier.csv", FileAccess.READ)
	if f == null:
		push_warning("pill_mark_tier.csv 缺失，丹纹分档为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 5:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表.append({
			"tier_id": id,
			"min": int(p[1]), "max": int(p[2]),
			"name": p[3].strip_edges(),
			"desc": p[4].strip_edges(),
			"omen": p[5].strip_edges() if p.size() > 5 else "",
		})
	表.sort_custom(func(a, b): return int(a["min"]) < int(b["min"]))
	self.丹纹分档缓存 = 表
	return 表


func _读表_丹纹图谱档() -> Array:
	if not self.丹纹图谱档缓存.is_empty():
		return self.丹纹图谱档缓存
	var 表: Array = []
	var f = FileAccess.open("res://config/pill_mark_codex.csv", FileAccess.READ)
	if f == null:
		push_warning("pill_mark_codex.csv 缺失，丹纹图谱档为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 5:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表.append({
				"codex_id": id, "name": p[1].strip_edges(),
				"need": int(p[2]), "success": float(p[3]), "rate": float(p[4]),
				"desc": p[5].strip_edges() if p.size() > 5 else "",
			})
	表.sort_custom(func(a, b): return int(a["need"]) < int(b["need"]))
	self.丹纹图谱档缓存 = 表
	return 表

## 品阶归一：既有「凡阶/灵阶…」（Item.品阶序）也有「凡品/灵品…」（解锁丹方体系），统一到「X阶」

func _丹纹归一品阶(阶: String) -> String:
	var s: String = 阶.strip_edges()
	if s.ends_with("品"):
		s = s.substr(0, s.length() - 1) + "阶"
	return s


func _丹纹配置(阶: String) -> Dictionary:
	var 表: Dictionary = _读表_丹纹()
	var k: String = _丹纹归一品阶(阶)
	if 表.has(k):
		return (表[k] as Dictionary).duplicate()
	return {"grade": k, "base_rate": 0.35, "base_toxin": 1.0, "effect_per_mark": 0.1,
		"price_per_mark": 0.15, "detox_per_mark": 0.6, "max_mark": 9}


func 丹纹分档(纹: int) -> Dictionary:
	var 表: Array = _读表_丹纹分档()
	for t in 表:
		var d: Dictionary = t as Dictionary
		if 纹 >= int(d["min"]) and 纹 <= int(d["max"]):
			return d
	return {"tier_id": "t0", "min": 0, "max": 0, "name": "无纹", "desc": "", "omen": ""}


func 丹纹名(纹: int) -> String:
	if 纹 <= 0:
		return "无纹"
	return "%d纹·%s" % [纹, str(丹纹分档(纹).get("name", ""))]

## 掷纹：逐纹递进，每道纹以 p 通过，失败即止（0=无纹）

func 掷丹纹(阶: String, 丹堂等级: int = 1) -> int:
	var c: Dictionary = _丹纹配置(阶)
	var p: float = float(c.get("base_rate", 0.35))
	p += Game.炼丹出纹加成(丹堂等级)
	p = clamp(p, 0.02, 0.95)
	var 上限: int = int(c.get("max_mark", 9))
	var 纹: int = 0
	while 纹 < 上限:
		if randf() > p:
			break
		纹 += 1
	return 纹


func 丹纹药效倍率(阶: String, 纹: int) -> float:
	if 纹 <= 0:
		return 1.0
	var c: Dictionary = _丹纹配置(阶)
	return 1.0 + float(纹) * float(c.get("effect_per_mark", 0.1))


func 丹纹售价倍率(纹: int) -> float:
	if 纹 <= 0:
		return 1.0
	return clamp(1.0 + float(纹) * 0.15, 1.0, Game.丹纹售价上限倍率)

## 丹毒变化：正=涨毒，负=清毒（激活 disciple.丹毒 死轴）

func 丹纹丹毒变化(阶: String, 纹: int) -> float:
	var c: Dictionary = _丹纹配置(阶)
	var 毒: float = float(c.get("base_toxin", 1.0)) - float(纹) * float(c.get("detox_per_mark", 0.6))
	return 毒

## 图谱总分 = 各丹最高纹之和（满分 = 丹方数 × 9）

# ===== 丹纹系统（已拆分到dan_mark_system.gd，此处为转发函数）=====

func 丹纹上限(品阶: String, 品级: String) -> int:
	var c: Dictionary = _丹纹配置(品阶)
	var base: int = int(c.get("max_mark", 9))
	var g: Dictionary = Game.丹品级配置(品级)
	return clamp(base + int(g.get("mark_cap_delta", 0)), 0, 9)

## 一炉成丹数量：品阶基准 + 压制 + 熟练 + 丹炉，再乘品级数量系数

func 丹纹图谱入谱(丹药, 纹: int, 阶: String) -> void:
	if 丹药 == null or 纹 <= 0:
		return
	var 丹名: String = str(丹药.名称)
	var 键: String = "%s·%s" % [_丹纹归一品阶(阶), 丹名]
	var 旧: int = int(self.丹纹图谱.get(键, 0))
	if 纹 > 旧:
		self.丹纹图谱[键] = 纹
		self.丹纹日志.push_front({"丹名": 丹名, "纹": 纹, "日": Game._今日序号(), "阶": _丹纹归一品阶(阶),
			"分档": str(丹纹分档(纹).get("name", "")), "品级": str(丹药.品级)})
		while self.丹纹日志.size() > Game.丹纹日志上限:
			self.丹纹日志.pop_back()
		_丹纹纪事(丹名, 纹, 阶, true)

## 购置丹炉
