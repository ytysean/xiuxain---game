class_name EconomyBalance
extends RefCounted

# ============================================================================
# F2 全局调节阀门（ECON-02 跨功能强约束 · 《太玄宗门录》S1-P0）
# ----------------------------------------------------------------------------
# 纯计算外挂中间层：对「结算最终输出节点」的原始数值做
#   ① 全局系数纠偏（总产出 / 总消耗，分别 ±15% 硬范围）
#   ② 单模块独立管控（坊市 trade_profit_rate / 运维 global_cost_rate / 负面影响 event_damage_rate）
#   ③ 极端阈值熔断（单周期最终产耗波动 > ±15% 时拉回基准 / 原始值）
# 再输出最终值。
#
# 设计铁律（IMPL-ENG-01）：
#   - 不持有任何游戏状态、不读 game_state、无副作用；所有参数来自 CSV（config/经济阀门.csv）。
#   - 唯一接线点：仅由 period_settlement.gd 结算最终输出节点调用一次（零侵入核心结算）。
#   - D 类具体功能逻辑（坊市 / 运维 / 负面影响）不在本模块实现；本模块仅提供旋钮与熔断。
#   - 红线 ±15% 严守（ECON-01 红线源 §4.8）：系数越界配置直接报错，绝不放行危险值。
# ============================================================================

const 红线: float = 0.15                 # ±15% 硬红线
const 配置路径: String = "res://config/经济阀门.csv"

# ---- ① 全局纠偏系数（对应 §4.8 global_income_rate / global_cost_rate）----
var 全局产出系数: float = 1.0      # global_income_rate
var 全局消耗系数: float = 1.0      # global_cost_rate（全局消耗侧）
# ---- ② 三模块独立管控 ----
var 坊市开关: bool = false
var 坊市系数: float = 1.0          # trade_profit_rate
var 运维开关: bool = false
var 运维系数: float = 1.0          # global_cost_rate（运维模块；与全局消耗系数同源）
var 负面开关: bool = false
var 负面系数: float = 1.0          # event_damage_rate
# ---- ③ 熔断 ----
var 熔断阈值: float = 红线         # 默认 ±15%
var 基准值: float = 366.0          # 标准局月产（ECON-01 §三，供参考 / 测试）

var _已加载: bool = false
var global_enable: bool = true    # R6：全局总开关（ECON-02）；false 时 平衡() 直接放行原始值，无发版秒级回滚


func _init(路径: String = ""):
	_加载配置(路径 if 路径 != "" else 配置路径)


# 从 CSV 载入全部旋钮；系数越界（超 ±15%）直接 push_error（不静默、不回退到危险值）。
func _加载配置(路径: String) -> void:
	if not FileAccess.file_exists(路径):
		# 配置文件缺失：保留全部默认 1.0 / 关，等价于「未接线」，安全 No-op。
		_已加载 = true
		return
	var f: FileAccess = FileAccess.open(路径, FileAccess.READ)
	if f == null:
		_已加载 = true
		return
	f.get_line()                      # 跳过表头
	while not f.eof_reached():
		var 行: String = f.get_line().strip_edges()
		if 行 == "":
			continue
		var 列: PackedStringArray = 行.split(",")
		if 列.size() < 3:
			continue
		var 键: String = 列[0].strip_edges()
		var 值: String = 列[1].strip_edges()
		var 开关: String = 列[2].strip_edges()
		_设值(键, 值, 开关)
	f.close()
	_已加载 = true


func _设值(键: String, 值: String, 开关: String) -> void:
	match 键:
		"global_income_rate":
			全局产出系数 = _取系数(键, 值)
		"global_cost_rate":
			全局消耗系数 = _取系数(键, 值)
			运维系数 = 全局消耗系数
			运维开关 = (开关 in ["1", "true", "TRUE", "是"])
		"trade_profit_rate":
			坊市系数 = _取系数(键, 值)
			坊市开关 = (开关 in ["1", "true", "TRUE", "是"])
		"event_damage_rate":
			负面系数 = _取系数(键, 值)
			负面开关 = (开关 in ["1", "true", "TRUE", "是"])
		"熔断阈值":
			熔断阈值 = clamp(float(值), 0.0, 1.0)
		"基准值":
			基准值 = float(值)
		_:
			pass


# 读取系数并强制 ±15% 硬范围；越界 push_error（"超范围配置直接报错"）。
func _取系数(键: String, 值: String) -> float:
	var v: float = float(值)
	if v < (1.0 - 红线) or v > (1.0 + 红线):
		push_error("F2 阀门 %s=%.4f 超出 ±15%% 硬范围，已拒绝（应保持 [%.2f, %.2f]）"
					% [键, v, 1.0 - 红线, 1.0 + 红线])
		return clamp(v, 1.0 - 红线, 1.0 + 红线)
	return v


# ----------------------------------------------------------------------------
# 主入口：传入结算最终输出节点的原始数值（如 灵石增量），返回
# 系数修正 + 熔断后的最终值。其余结算逻辑不变。
#   raw>=0 视为产出（应用 global_income_rate + 坊市 / 负面影响 输出侧）
#   raw<0  视为消耗（应用 global_cost_rate + 负面影响 消耗侧；运维阀门同源）
# 熔断基准 = 原始值 raw（本周期基准），保证默认配置零跳变；
# 单周期阀门总效应 > ±15% 时强制拉回 raw（杜绝单周期 >±15% 跳变）。
# ----------------------------------------------------------------------------
func 平衡(原始值: float) -> float:
	if not global_enable:
		return 原始值   # R6：全局开关关闭时直接放行（秒级回滚，不施加任何阀门）
	if not _已加载:
		_加载配置(配置路径)
	var 基准: float = 原始值                     # 本周期基准 = 原始值（零跳变保证）
	var 结果: float = 原始值

	if 原始值 >= 0.0:
		# 产出侧：全局产出纠偏 + 坊市(boost) + 负面影响(reduce)
		结果 = 原始值 * 全局产出系数
		if 坊市开关:
			结果 *= 坊市系数
		if 负面开关:
			结果 *= 负面系数
	else:
		# 消耗侧：全局消耗纠偏 + 负面影响(增耗)；运维阀门 = global_cost_rate 同源
		结果 = 原始值 * 全局消耗系数
		if 负面开关:
			结果 *= 负面系数

	# ③ 极端阈值熔断：单周期阀门总效应 > ±15% 即拉回基准（本周期原始值）
	var 振幅: float = 0.0
	if abs(基准) > 1e-9:
		振幅 = abs(结果 - 基准) / abs(基准)
	else:
		振幅 = 0.0
	if 振幅 > 熔断阈值:
		结果 = 基准
	return 结果


# 纯函数式合规探针（供测试 / 闸门静态校验参考）：当前是否所有系数均在 ±15% 内。
func 系数合规() -> bool:
	for c in [全局产出系数, 全局消耗系数, 坊市系数, 运维系数, 负面系数]:
		if c < (1.0 - 红线) or c > (1.0 + 红线):
			return false
	return true
