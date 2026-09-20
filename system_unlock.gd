class_name SystemUnlock
extends RefCounted

## P0-1 洋葱式系统解锁引擎（表驱动，单一来源）
##
## 设计意图：新玩家前 30 分钟只应看到 3 个核心系统，其余随宗门壮大逐步显现，
##           避免一上来被 76 个 UI 入口+29 个系统淹没（评测 P0-1）。
##
## 单一来源：config/unlock_order.csv（禁止在 UI/其它 .gd 里再硬编码解锁条件）。
## 分层纪律：本引擎只做「查询」，UI 只读调用；绝不写玩法/存档。
## fail-open：任何「无配置 / 条件类型不认识 / 取不到 Game」的查询一律返回 true，
##            宁可多显示一个入口，也绝不错藏一个功能。
##
## 条件类型（表内「解锁条件类型」列）：
##   开局        —— 建宗即有（恒真）
##   门派等级 N  —— Game.门派等级 >= N
##   首次突破后  —— Game.累计弟子突破次数 >= 1
##   第二世代开始—— Game.当前辈分序 >= 2（实测语义：1 = 第一代开山辈，2 = 第二代；每 100 游戏年晋一代）

const 表路径: String = "res://config/unlock_order.csv"

const 条件_开局: String = "开局"
const 条件_门派等级: String = "门派等级"
const 条件_首次突破后: String = "首次突破后"
const 条件_第二世代: String = "第二世代开始"

## 调试 / 回退开关：true 则一切系统与入口视为已解锁（出问题时一键回到全可见）
var 强制全解锁: bool = false

var _系统表: Dictionary = {}   # 系统key -> {名称, 条件类型, 条件参数, 页面, 入口, 阶段}
var _被锁定入口: Dictionary = {}  # 入口id -> true（仅收录「被至少一个系统引用」的入口）
var _已加载: bool = false


func _init() -> void:
	加载表()


## 重新读取配置表（热重载 / 测试用）
func 加载表() -> void:
	_系统表.clear()
	_被锁定入口.clear()
	var f: FileAccess = FileAccess.open(表路径, FileAccess.READ)
	if f == null:
		push_warning("[系统解锁] 未找到配置表 %s —— 按 fail-open 处理（全部可见）" % 表路径)
		_已加载 = true
		return
	var 表头: PackedStringArray = f.get_csv_line()
	var 列: Dictionary = {}
	for i in range(表头.size()):
		列[_净(表头[i])] = i
	while not f.eof_reached():
		var 行: PackedStringArray = f.get_csv_line()
		if 行.size() < 4:
			continue
		var key: String = _取(行, 列, "系统key")
		if key == "":
			continue
		var 入口: String = _取(行, 列, "首页入口id")
		_系统表[key] = {
			"名称": _取(行, 列, "系统名"),
			"条件类型": _取(行, 列, "解锁条件类型"),
			"条件参数": _取(行, 列, "解锁条件参数"),
			"页面": _取(行, 列, "UI入口"),
			"入口": 入口,
			"阶段": _取(行, 列, "阶段"),
		}
		if 入口 != "":
			_被锁定入口[入口] = true
	f.close()
	_已加载 = true


func _净(s: String) -> String:
	return s.strip_edges().lstrip("\ufeff")


func _取(行: PackedStringArray, 列: Dictionary, 名: String) -> String:
	var i: int = int(列.get(名, -1))
	if i < 0 or i >= 行.size():
		return ""
	return _净(行[i])


# ────────────────── 对外查询（UI 只读调用）──────────────────

## 某系统是否已解锁。无配置 → true（fail-open，不参与 gating）
func 已解锁(系统key: String) -> bool:
	if 强制全解锁:
		return true
	var cfg: Dictionary = _系统表.get(系统key, {})
	if cfg.is_empty():
		return true
	return _判条件(String(cfg.get("条件类型", "")), String(cfg.get("条件参数", "")))


## UI 侧统一安全查询（静态，供各 UI 文件直接调用，免去各自重复写 fail-open 包装）。
## 无引擎 / Game 未就绪 / 查询异常 → 一律 true（fail-open：宁可多显示，不可误锁玩家入口）。
## 说明：与实例方法 入口已解锁 逻辑等价，仅额外兜住「引擎本身取不到」的情形；
##       把 fail-open 策略收敛到此处，UI 侧不要再各写一份 null 判断。
static func 入口可显示(入口id: String) -> bool:
	var 引擎: SystemUnlock = null
	if is_instance_valid(Game) and Game.系统解锁 != null:
		引擎 = Game.系统解锁
	if 引擎 == null:
		return true
	return bool(引擎.入口已解锁(入口id))


## 某入口「尚未开启」的可读条件文案（供置灰 Tab / 未开启入口提示用）。
## 已解锁 / 无配置 / 引擎不可用 → 返回空串（调用方回退到通用文案）。
static func 入口解锁提示(入口id: String) -> String:
	var 引擎: SystemUnlock = null
	if is_instance_valid(Game) and Game.系统解锁 != null:
		引擎 = Game.系统解锁
	if 引擎 == null:
		return ""
	return 引擎.解锁提示(入口id)


## 某首页入口是否显示。
## 规则：该入口若被任一系统引用，则「最先可解锁的那个」已解锁即显示；未被任何系统引用 → 显示。
func 入口已解锁(入口id: String) -> bool:
	if 强制全解锁:
		return true
	if not _被锁定入口.has(入口id):
		return true   # 没有系统 gating 它 → 照常显示
	for key in _系统表:
		if String(_系统表[key].get("入口", "")) == 入口id and 已解锁(key):
			return true
	return false


## 未开启原因的可读文案（取该入口「最先可解锁」那个系统的条件）。
## 已解锁 / 无引用 → 空串；未知条件 → 回退通用语。
func 解锁提示(入口id: String) -> String:
	if 入口已解锁(入口id):
		return ""
	var 最优等级: int = 999
	var 类型: String = ""
	var 参数: String = ""
	for key in _系统表:
		if String(_系统表[key].get("入口", "")) != 入口id:
			continue
		var t: String = String(_系统表[key].get("条件类型", ""))
		var p: String = String(_系统表[key].get("条件参数", ""))
		if t == 条件_门派等级:
			var n: int = int(p)
			if n < 最优等级:
				最优等级 = n
				类型 = t
				参数 = p
		elif 类型 == "":
			类型 = t
			参数 = p
	match 类型:
		条件_门派等级:
			return "宗门品级达 %d 品后可入" % int(参数)
		条件_首次突破后:
			return "门下弟子首次突破后可入"
		条件_第二世代:
			return "第二世代开启后可入"
		_:
			return "随宗门壮大自会显现"


## 某页面（page 文件名，如 page_auction）是否可进入。未被任何系统引用 → 可进入。
func 页面已解锁(页面名: String) -> bool:
	if 强制全解锁:
		return true
	var 有引用: bool = false
	for key in _系统表:
		var p: String = String(_系统表[key].get("页面", ""))
		if p != "" and (p == 页面名 or p.get_basename() == 页面名 or p == 页面名 + ".tscn"):
			有引用 = true
			if 已解锁(key):
				return true
	return not 有引用   # 无引用 → fail-open


## 当前已解锁系统 key 列表（调试/验收用）
func 已解锁系统列表() -> Array:
	var r: Array = []
	for key in _系统表:
		if 已解锁(key):
			r.append(key)
	return r


## 诊断快照
func 调试快照() -> Dictionary:
	return {
		"已加载": _已加载,
		"系统数": _系统表.size(),
		"被锁定入口数": _被锁定入口.size(),
		"强制全解锁": 强制全解锁,
	}


# ────────────────── 条件判定 ──────────────────

func _判条件(类型: String, 参数: String) -> bool:
	match 类型:
		条件_开局:
			return true
		条件_门派等级:
			return _门派等级() >= int(参数)
		条件_首次突破后:
			return _累计突破次数() >= 1
		条件_第二世代:
			# 辈分序实际语义：1 = 第一代（开山辈，初值），2 = 第二代；每 100 游戏年（36000 日）晋升一代
			return _辈分序() >= 2
		_:
			return true   # 未知条件 → fail-open


func _门派等级() -> int:
	if not is_instance_valid(Game):
		return 999
	return int(Game.门派等级)


func _累计突破次数() -> int:
	if not is_instance_valid(Game):
		return 999
	return int(Game.累计弟子突破次数)


func _辈分序() -> int:
	if not is_instance_valid(Game):
		return 999
	return int(Game.当前辈分序)
