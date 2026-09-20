## 统一红点管理器（大厂手游标准）
## 功能：
## 1. 统一红点数据管理：所有红点状态集中管理
## 2. 红点层级聚合：父级红点自动聚合所有子级红点状态
## 3. 红点自动更新：数据变化时自动刷新所有相关红点
## 4. 支持数字红点：显示未读数量（如消息、任务）
## 5. 支持圆点红点：仅显示有无（如可领取、可突破）

extends Node

signal 红点更新(红点ID: String)

var _红点状态: Dictionary = {}  # 红点ID -> {visible: bool, count: int, children: Array}
var _红点节点: Dictionary = {}  # 红点ID -> Array[Control]  注册的红点控件

## 注册红点节点
func 注册红点(红点ID: String, 节点: Control) -> void:
	if 节点 == null or not is_instance_valid(节点):
		return
	if not _红点节点.has(红点ID):
		_红点节点[红点ID] = []
	if _红点节点[红点ID].has(节点):
		return   # 去重：页面重建后旧节点已失效，同一 ID 反复注册会让数组膨胀并重复刷显示
	_红点节点[红点ID].append(节点)
	_刷新节点显示(红点ID)

## 注销红点节点
func 注销红点(红点ID: String, 节点: Control) -> void:
	if _红点节点.has(红点ID):
		_红点节点[红点ID].erase(节点)

## 设置红点状态（圆点红点）
func 设置红点(红点ID: String, 显示: bool) -> void:
	if not _红点状态.has(红点ID):
		_红点状态[红点ID] = {"visible": false, "count": 0, "children": []}
	_红点状态[红点ID]["visible"] = 显示
	_通知父级更新(红点ID)
	_刷新节点显示(红点ID)
	红点更新.emit(红点ID)

## 设置红点数量（数字红点，count>0时显示）
func 设置红点数量(红点ID: String, 数量: int) -> void:
	if not _红点状态.has(红点ID):
		_红点状态[红点ID] = {"visible": false, "count": 0, "children": []}
	_红点状态[红点ID]["count"] = 数量
	_红点状态[红点ID]["visible"] = 数量 > 0
	_通知父级更新(红点ID)
	_刷新节点显示(红点ID)
	红点更新.emit(红点ID)

## 注册父子关系（父级红点自动聚合子级）。
## 「参与计数 = false」⇒ 该子级只贡献「有无」，不参与父级数字汇总。
##   适用场景：子级有 count 但**不宜求和**（弱信号）。当前生产代码无此用法 ——
##   唯一实例 `弟子_装备`（按「装备槽 < 9」逐弟子计一次）已按「弟子 AI 内驱」铁则整条删除，
##   保留本参数是为将来真出现弱信号时不必再改聚合口径。
##   反例代价（实证）：9 名弟子全空装 ⇒ Tab 显示 9，而真实待办为 0 ⇒ 玩家点进去无事可做，
##   红点立刻失去可信度（"点不掉的红点"）。**弱信号宁可不挂红点，也别灌进数字。**
func 注册父子(父ID: String, 子ID: String, 参与计数: bool = true) -> void:
	if not _红点状态.has(父ID):
		_红点状态[父ID] = {"visible": false, "count": 0, "children": [], "count_children": []}
	var 状: Dictionary = _红点状态[父ID]
	if not 状.has("count_children"):
		状["count_children"] = []
	if not 状["children"].has(子ID):
		状["children"].append(子ID)
	if 参与计数 and not 状["count_children"].has(子ID):
		状["count_children"].append(子ID)

## 获取红点是否显示
func 是否显示(红点ID: String) -> bool:
	if not _红点状态.has(红点ID):
		return false
	var 状态 = _红点状态[红点ID]
	if 状态["visible"]:
		return true
	# 检查子级红点
	for 子ID in 状态["children"]:
		if 是否显示(子ID):
			return true
	return false

## 获取红点数量。
## ★ 必须与 是否显示 对称：父级自身 count 为 0 时**向上汇总子级数量**。
##   根因：Tab 级父节点从不直接设 count，只靠「注册父子」聚合 —— 若这里不汇总，
##   父级 count 恒为 0 ⇒ Tab 角标永远走圆点分支，数字角标沦为死代码（实机截图实证）。
##   叶子节点无 children ⇒ 汇总结果 0，行为与旧版逐字一致（不影响顶栏 / 首页调用点）。
func 获取数量(红点ID: String) -> int:
	if not _红点状态.has(红点ID):
		return 0
	var 自身: int = int(_红点状态[红点ID]["count"])
	if 自身 > 0:
		return 自身
	var 总: int = 0
	# 只遍历「参与计数」的子级：纯状态子级（如 宗门_宗务 走 设置红点(bool)、count 恒 0）
	#   只影响 是否显示，不影响数量。
	#   用 get 兜底：早于 注册父子 建立的状态字典没有这个键（避免 KeyError 语义的静默中断）。
	for 子ID in _红点状态[红点ID].get("count_children", []):
		总 += 获取数量(子ID)
	return 总

## 刷新所有红点（数据大变化时调用）
func 刷新所有() -> void:
	for 红点ID in _红点状态.keys():
		_刷新节点显示(红点ID)

## 内部：刷新节点显示
func _刷新节点显示(红点ID: String) -> void:
	if not _红点节点.has(红点ID):
		return
	var 显示: bool = 是否显示(红点ID)
	var 数量: int = 获取数量(红点ID)
	var 存活: Array = []
	for 节点 in _红点节点[红点ID]:
		if not is_instance_valid(节点):
			continue   # 页面销毁：本轮顺手剔除，否则数组随每次切页无限增长
		存活.append(节点)
		节点.visible = 显示
		if 节点.has_method("设置数量"):
			节点.设置数量(数量)
		elif 节点.get_node_or_null("Num") != null:
			# 数字红点走这支：UITheme 工厂产出的是**裸 Panel**，本身没有「设置数量」方法，
			# 旧版只用 has_method 探测 ⇒ 永远探测失败 ⇒ 角标数字从创建那一刻起再不更新，
			# 数字红点退化成纯装饰（静默失效，无任何报错）。必须由管理器直改子 Label 文本与胶囊宽度。
			UITheme.设置红点数量(节点, 数量)
	_红点节点[红点ID] = 存活

## 内部：通知父级更新
func _通知父级更新(子ID: String) -> void:
	for 父ID in _红点状态.keys():
		var 状态 = _红点状态[父ID]
		if 状态["children"].has(子ID):
			_刷新节点显示(父ID)
			红点更新.emit(父ID)
