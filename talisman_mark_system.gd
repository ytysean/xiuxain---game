class_name TalismanMarkSystem extends RefCounted

# ===== 符纹系统状态变量 =====
var _符纹表缓存: Dictionary = {}   # config/talisman_mark_config.csv -> 品阶 -> 配置行
var _符纹分档缓存: Array = []      # config/talisman_mark_tier.csv（按 mark_min 升序）
var _符纹图谱档缓存: Array = []    # config/talisman_mark_codex.csv（按 need_score 升序）
var 符纹图谱: Dictionary = {}
var 符纹日志: Array = []             # 最近新纪录 [{符名,纹,日,分档}]，上限 符纹日志上限
var 符纹今日纪事: int = 0            # 现实日限流：防止批量绘符灌屏
var 符纹纪事日: int = 0

func _读表_符纹() -> Dictionary:
	if _符纹表缓存.has("mark"):
		return _符纹表缓存["mark"] as Dictionary
	var 表: Dictionary = {}
	var f = FileAccess.open("res://config/talisman_mark_config.csv", FileAccess.READ)
	if f == null:
		push_warning("talisman_mark_config.csv 缺失，符纹表为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 5:
			continue
		var 阶: String = p[0].strip_edges()
		if 阶.is_empty():
			continue
		表[阶] = {"grade": 阶, "base_rate": float(p[1]), "effect_per_mark": float(p[2]),
			"price_per_mark": float(p[3]), "max_mark": int(p[4])}
	_符纹表缓存["mark"] = 表
	return 表

func _读表_符纹分档() -> Array:
	if not _符纹分档缓存.is_empty():
		return _符纹分档缓存
	var 表: Array = []
	var f = FileAccess.open("res://config/talisman_mark_tier.csv", FileAccess.READ)
	if f == null:
		push_warning("talisman_mark_tier.csv 缺失，符纹分档为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 5:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表.append({"tier_id": id, "min": int(p[1]), "max": int(p[2]),
			"name": p[3].strip_edges(), "desc": p[4].strip_edges(),
			"omen": p[5].strip_edges() if p.size() > 5 else ""})
	表.sort_custom(func(a, b): return int(a["min"]) < int(b["min"]))
	_符纹分档缓存 = 表
	return 表

func _读表_符纹图谱档() -> Array:
	if not _符纹图谱档缓存.is_empty():
		return _符纹图谱档缓存
	var 表: Array = []
	var f = FileAccess.open("res://config/talisman_mark_codex.csv", FileAccess.READ)
	if f == null:
		push_warning("talisman_mark_codex.csv 缺失，符纹图谱档为空")
		return 表
	f.get_csv_line()
	while not f.eof_reached():
		var p = f.get_csv_line()
		if p.size() < 5:
			continue
		var id: String = p[0].strip_edges()
		if id.is_empty():
			continue
		表.append({"codex_id": id, "name": p[1].strip_edges(),
			"need": int(p[2]), "success": float(p[3]), "rate": float(p[4]),
			"desc": p[5].strip_edges() if p.size() > 5 else ""})
	表.sort_custom(func(a, b): return int(a["need"]) < int(b["need"]))
	_符纹图谱档缓存 = 表
	return 表

## 品阶归一：「凡品/灵品…」→「凡阶/灵阶…」（对齐 Item.品阶 词表）
func _符纹归一品阶(阶: String) -> String:
	var s: String = 阶.strip_edges()
	if s.ends_with("品"):
		s = s.substr(0, s.length() - 1) + "阶"
	return s

func _符纹配置(阶: String) -> Dictionary:
	var 表: Dictionary = _读表_符纹()
	var k: String = _符纹归一品阶(阶)
	if 表.has(k):
		return (表[k] as Dictionary).duplicate()
	return {"grade": k, "base_rate": 0.35, "effect_per_mark": 0.1, "price_per_mark": 0.15, "max_mark": 9}

func 符纹分档(纹: int) -> Dictionary:
	var 表: Array = _读表_符纹分档()
	for t in 表:
		var d: Dictionary = t as Dictionary
		if 纹 >= int(d["min"]) and 纹 <= int(d["max"]):
			return d
	return {"tier_id": "t0", "min": 0, "max": 0, "name": "无纹", "desc": "", "omen": ""}

func 符纹名(纹: int) -> String:
	if 纹 <= 0:
		return "无纹"
	return "%d纹·%s" % [纹, str(符纹分档(纹).get("name", ""))]

## 符纹上限 = 品阶上限 + 品级偏移（凡品3 → 道品9；极品+2、下品-1）
func 符纹上限(品阶: String, 品级: String) -> int:
	var c: Dictionary = _符纹配置(品阶)
	var base: int = int(c.get("max_mark", 9))
	var g: Dictionary = Game.符品级配置(品级)
	return clamp(base + int(g.get("mark_cap_delta", 0)), 0, 9)

## 掷符纹：逐纹递进，每道纹以 p 通过，失败即止（0=无纹）
## 级系数 = 品级 mark_rate_scale（上品更易出纹）；上限 = 符纹上限（品级 mark_cap_delta）
func 掷符纹(阶: String, 符堂等级: int = 1, 额外出纹: float = 0.0, 级系数: float = 1.0, 上限: int = -1) -> int:
	var c: Dictionary = _符纹配置(阶)
	var p: float = float(c.get("base_rate", 0.35)) * 级系数
	p += float(max(0, 符堂等级 - 1)) * Game.符纹每级符堂加成 + 符纹图谱出纹加成() + 额外出纹
	p = clamp(p, 0.02, 0.95)
	var 顶: int = 上限 if 上限 >= 0 else int(c.get("max_mark", 9))
	var 纹: int = 0
	while 纹 < 顶:
		if randf() > p:
			break
		纹 += 1
	return 纹

func 符纹效力倍率(阶: String, 纹: int) -> float:
	if 纹 <= 0:
		return 1.0
	var c: Dictionary = _符纹配置(阶)
	return 1.0 + float(纹) * float(c.get("effect_per_mark", 0.1))

func 符纹售价倍率(阶: String, 纹: int) -> float:
	if 纹 <= 0:
		return 1.0
	var c: Dictionary = _符纹配置(阶)
	return clamp(1.0 + float(纹) * float(c.get("price_per_mark", 0.15)), 1.0, Game.符纹售价上限倍率)

## 图谱总分 = 各符最高纹之和
func 符纹图谱总分() -> int:
	var 总: int = 0
	for k in 符纹图谱.keys():
		总 += int(符纹图谱[k])
	return 总

## 已达成的最后一个里程碑（表按 need 升序）
func 符纹图谱加成() -> Dictionary:
	var 分: int = 符纹图谱总分()
	var 档: Array = _读表_符纹图谱档()
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

## 绘符成功率加成（百分点→分数：2.0 → +0.02）
func 符纹图谱成功率加成() -> float:
	return float(符纹图谱加成().get("success", 0.0)) / 100.0

## 出纹率加成（0.05 = +5%）
func 符纹图谱出纹加成() -> float:
	return float(符纹图谱加成().get("rate", 0.0))

## 符纹入谱（按「品阶+符名」记录，避免同名不同阶混淆）
func 符纹图谱入谱(符箓, 纹: int, 阶: String) -> void:
	if 符箓 == null or 纹 <= 0:
		return
	var 符名: String = str(符箓.名称)
	var 键: String = "%s·%s" % [_符纹归一品阶(阶), 符名]
	var 旧: int = int(符纹图谱.get(键, 0))
	if 纹 > 旧:
		符纹图谱[键] = 纹
		符纹日志.push_front({"符名": 符名, "纹": 纹, "日": Game._今日序号(), "阶": _符纹归一品阶(阶),
			"分档": str(符纹分档(纹).get("name", "")), "品级": str(符箓.品级)})
		while 符纹日志.size() > Game.符纹日志上限:
			符纹日志.pop_back()

func 符纹总览() -> Dictionary:
	var 加成: Dictionary = 符纹图谱加成()
	return {"总分": 符纹图谱总分(), "种数": 符纹图谱.size(), "里程碑": str(加成.get("name", "")),
		"成功率加成": float(加成.get("success", 0.0)), "出纹加成": float(加成.get("rate", 0.0)),
		"下一档": 加成.get("next", null)}

## 读档类型守卫（旧档缺字段/类型异常时复位，零回归）
func 符纹校验() -> void:
	if not (符纹图谱 is Dictionary):
		符纹图谱 = {}
	if not (符纹日志 is Array):
		符纹日志 = []
	符纹今日纪事 = int(符纹今日纪事)
	符纹纪事日 = int(符纹纪事日)
	if not (_符纹分档缓存 is Array):
		_符纹分档缓存 = []
	if not (_符纹图谱档缓存 is Array):
		_符纹图谱档缓存 = []


# ===== 序列化/反序列化（用于存档）=====
func to_dict() -> Dictionary:
	var data: Dictionary = {}
	data["_符纹表缓存"] = _符纹表缓存
	data["_符纹分档缓存"] = _符纹分档缓存
	data["_符纹图谱档缓存"] = _符纹图谱档缓存
	data["符纹图谱"] = 符纹图谱
	data["符纹日志"] = 符纹日志
	data["符纹今日纪事"] = 符纹今日纪事
	data["符纹纪事日"] = 符纹纪事日
	return data

func from_dict(data: Dictionary) -> void:
	if "_符纹表缓存" in data: _符纹表缓存 = data["_符纹表缓存"]
	if "_符纹分档缓存" in data: _符纹分档缓存 = data["_符纹分档缓存"]
	if "_符纹图谱档缓存" in data: _符纹图谱档缓存 = data["_符纹图谱档缓存"]
	if "符纹图谱" in data: 符纹图谱 = data["符纹图谱"]
	if "符纹日志" in data: 符纹日志 = data["符纹日志"]
	if "符纹今日纪事" in data: 符纹今日纪事 = data["符纹今日纪事"]
	if "符纹纪事日" in data: 符纹纪事日 = data["符纹纪事日"]
