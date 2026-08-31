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
	if not _红点节点.has(红点ID):
		_红点节点[红点ID] = []
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

## 注册父子关系（父级红点自动聚合子级）
func 注册父子(父ID: String, 子ID: String) -> void:
	if not _红点状态.has(父ID):
		_红点状态[父ID] = {"visible": false, "count": 0, "children": []}
	if not _红点状态[父ID]["children"].has(子ID):
		_红点状态[父ID]["children"].append(子ID)

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

## 获取红点数量
func 获取数量(红点ID: String) -> int:
	if not _红点状态.has(红点ID):
		return 0
	return int(_红点状态[红点ID]["count"])

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
	for 节点 in _红点节点[红点ID]:
		if not is_instance_valid(节点):
			continue
		节点.visible = 显示
		# 如果节点有设置数量的方法，调用它
		if 节点.has_method("设置数量"):
			节点.设置数量(数量)

## 内部：通知父级更新
func _通知父级更新(子ID: String) -> void:
	for 父ID in _红点状态.keys():
		var 状态 = _红点状态[父ID]
		if 状态["children"].has(子ID):
			_刷新节点显示(父ID)
			红点更新.emit(父ID)
