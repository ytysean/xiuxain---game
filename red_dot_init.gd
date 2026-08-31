## 红点系统初始化模块
## 统一管理全游戏所有红点的注册、更新和层级关系
## 覆盖：任务、弟子突破、历练结算等核心功能

extends Node

const RedDotManager := preload("res://red_dot_manager.gd")

## 红点ID常量定义（全游戏统一）
const 红点ID := {
	# 底部Tab层级
	"TAB_宗门": "TAB_宗门",
	"TAB_弟子": "TAB_弟子",
	"TAB_历练": "TAB_历练",
	"TAB_坊市": "TAB_坊市",
	"TAB_更多": "TAB_更多",

	# 宗门首页
	"宗门_宗务": "宗门_宗务",
	"宗门_图录": "宗门_图录",
	"宗门_灵讯": "宗门_灵讯",

	# 任务系统
	"任务_日常": "任务_日常",
	"任务_周常": "任务_周常",
	"任务_成就": "任务_成就",

	# 弟子系统
	"弟子_突破": "弟子_突破",
	"弟子_装备": "弟子_装备",

	# 历练系统
	"历练_结算": "历练_结算",

	# 快捷栏系统
	"快捷_日供": "快捷_日供",
	"快捷_库藏": "快捷_库藏",

	# 殿阁系统
	"殿阁_升级": "殿阁_升级",

	# 纪事系统
	"纪事_未读": "纪事_未读",
}

var _管理器: RedDotManager = null

func _ready() -> void:
	初始化()

## 初始化红点系统
func 初始化() -> void:
	_管理器 = RedDotManager.new()
	add_child(_管理器)
	_注册层级关系()
	刷新所有红点()

## 获取红点管理器
func 获取管理器() -> RedDotManager:
	return _管理器

## 注册红点层级关系（父级聚合子级）
func _注册层级关系() -> void:
	# 底部Tab聚合
	_管理器.注册父子(红点ID.TAB_宗门, 红点ID.宗门_宗务)
	_管理器.注册父子(红点ID.TAB_宗门, 红点ID.宗门_图录)
	_管理器.注册父子(红点ID.TAB_宗门, 红点ID.宗门_灵讯)

	_管理器.注册父子(红点ID.TAB_弟子, 红点ID.弟子_突破)
	_管理器.注册父子(红点ID.TAB_弟子, 红点ID.弟子_装备)

	_管理器.注册父子(红点ID.TAB_历练, 红点ID.历练_结算)

	_管理器.注册父子(红点ID.TAB_更多, 红点ID.任务_日常)
	_管理器.注册父子(红点ID.TAB_更多, 红点ID.任务_周常)
	_管理器.注册父子(红点ID.TAB_更多, 红点ID.任务_成就)

## 刷新所有红点状态（数据变化时调用）
func 刷新所有红点() -> void:
	if _管理器 == null:
		return
	_刷新任务红点()
	_刷新弟子红点()
	_刷新历练红点()
	_刷新宗门红点()
	_刷新快捷栏红点()
	_管理器.刷新所有()

## 刷新任务红点
func _刷新任务红点() -> void:
	# 日常任务可领取
	var 日常可领取: int = 0
	if Game != null and "当前日常" in Game and "日常已领" in Game:
		var 当前日常 = Game.当前日常
		var 日常已领 = Game.日常已领
		if 当前日常 != null and 日常已领 != null:
			for i in range(min(当前日常.size(), 日常已领.size())):
				if not bool(日常已领[i]):
					日常可领取 += 1
	_管理器.设置红点数量(红点ID.任务_日常, 日常可领取)

	# 周常任务可领取
	var 周常可领取: int = 0
	if Game != null and "周常已领" in Game:
		if not bool(Game.周常已领):
			周常可领取 = 1
	_管理器.设置红点数量(红点ID.任务_周常, 周常可领取)

	# 成就已达成
	var 成就已达成: int = 0
	if Game != null and "成就_已达成" in Game:
		var 已达成 = Game.成就_已达成
		if 已达成 != null:
			成就已达成 = 已达成.size()
	_管理器.设置红点数量(红点ID.任务_成就, 成就已达成)

## 刷新弟子红点
func _刷新弟子红点() -> void:
	var 可突破数: int = 0
	var 空装备槽数: int = 0
	if Game != null and "弟子列表" in Game:
		var 弟子列表 = Game.弟子列表
		if 弟子列表 != null:
			for d in 弟子列表:
				if d == null:
					continue
				# 检查可突破
				var 进度: float = float(d.修炼进度) if "修炼进度" in d else 0.0
				var 层数: int = int(d.层数) if "层数" in d else 0
				var 打磨: float = float(d.瓶颈打磨值) if "瓶颈打磨值" in d else 0.0
				var 冷却: float = float(d.突破冷却剩余) if "突破冷却剩余" in d else 0.0
				if (进度 >= 1.0 and 层数 < 10) or (层数 >= 10 and 打磨 >= 1.0 and 冷却 <= 0.0):
					可突破数 += 1
				# 检查空装备槽
				var 装备 = d.装备 if "装备" in d else {}
				if 装备 is Dictionary and 装备.size() < 9:
					空装备槽数 += 1
	_管理器.设置红点数量(红点ID.弟子_突破, 可突破数)
	_管理器.设置红点数量(红点ID.弟子_装备, 空装备槽数)

## 刷新历练红点
func _刷新历练红点() -> void:
	var 可领取数: int = 0
	if ExpeditionSystem != null:
		var 进行中 = ExpeditionSystem.获取进行中历练()
		if 进行中 != null:
			var 当前日: int = 0
			if Game != null and "累计游戏日" in Game:
				当前日 = int(Game.累计游戏日)
			for 实例ID in 进行中.keys():
				var 实例 = 进行中[实例ID]
				if 实例.has("预计结束游戏日") and 当前日 >= int(实例["预计结束游戏日"]):
					可领取数 += 1
	_管理器.设置红点数量(红点ID.历练_结算, 可领取数)

## 刷新宗门首页红点
func _刷新宗门红点() -> void:
	# 宗务红点（新手目标）
	var 宗务红点: bool = false
	if Game != null and Game.has_method("新手_有红点"):
		宗务红点 = bool(Game.新手_有红点())
	_管理器.设置红点(红点ID.宗门_宗务, 宗务红点)

	# 灵讯红点（未读邮件）
	var 未读邮件数: int = 0
	if Game != null and "邮件列表" in Game:
		var 邮件列表 = Game.邮件列表
		if 邮件列表 != null:
			for 邮件 in 邮件列表:
				if 邮件 != null and 邮件.has("未读") and bool(邮件["未读"]):
					未读邮件数 += 1
	_管理器.设置红点数量(红点ID.宗门_灵讯, 未读邮件数)

	# 图录红点（新解锁，暂时设为false）
	_管理器.设置红点(红点ID.宗门_图录, false)

## 刷新快捷栏红点
func _刷新快捷栏红点() -> void:
	# 日供红点：今日可领取时显示
	var 日供可领: bool = false
	if Game != null and Game.has_method("日供_今日可领"):
		日供可领 = bool(Game.日供_今日可领())
	_管理器.设置红点(红点ID.快捷_日供, 日供可领)

	# 库藏红点：暂时设为false，等确认有新物品的判断条件后再添加
	_管理器.设置红点(红点ID.快捷_库藏, false)

	# 殿阁升级红点：有可升级的殿阁时显示
	var 殿阁可升级: bool = false
	if Game != null and Game.has_method("有可升级殿阁"):
		殿阁可升级 = bool(Game.有可升级殿阁())
	_管理器.设置红点(红点ID.殿阁_升级, 殿阁可升级)

	# 纪事未读红点：有未读纪事时显示
	var 纪事未读: bool = false
	if Game != null and Game.has_method("有未读纪事"):
		纪事未读 = bool(Game.有未读纪事())
	_管理器.设置红点(红点ID.纪事_未读, 纪事未读)
