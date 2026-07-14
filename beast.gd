# beast.gd —— 灵兽 / 灵兽蛋系统
class_name Beast
extends RefCounted

const 品阶序 := ["凡阶", "灵阶", "宝阶", "王阶", "圣阶", "仙阶", "渡劫阶"]
const 品阶权重 := {"fan_jie": 50.0, "ling_jie": 28.0, "bao_jie": 14.0, "wang_jie": 6.0, "sheng_jie": 2.5, "xian_jie": 1.0, "dujie_jie": 0.3}

const 灵兽种类 := [
	{"名": "食铁兽", "适配": "tixiu"}, {"名": "玄龟", "适配": "tixiu"},
	{"名": "墨玉蟾", "适配": "tixiu"}, {"名": "当康", "适配": "tixiu"},
	{"名": "白虎", "适配": "jianxiu"}, {"名": "剑齿影狼", "适配": "jianxiu"},
	{"名": "雷殛鹰", "适配": "jianxiu"}, {"名": "金羽鸾", "适配": "jianxiu"},
	{"名": "紫电貂", "适配": "jianxiu"}, {"名": "火麒麟", "适配": "faxiu"},
	{"名": "青龙", "适配": "faxiu"}, {"名": "朱雀", "适配": "faxiu"},
	{"名": "冰鸾", "适配": "faxiu"}, {"名": "赤焰兽", "适配": "faxiu"},
	{"名": "鲲鹏", "适配": "faxiu"}, {"名": "白泽", "适配": "tongyong"},
	{"名": "貔貅", "适配": "tongyong"}, {"名": "谛听", "适配": "tongyong"},
]

const 主动技能 := {
	"jianxiu": ["法术抵消", "瞬身规避", "残血保命"],
	"tixiu": ["锁敌禁锢", "减远程伤害", "持续回血"],
	"faxiu": ["破防增伤", "解除禁制", "护盾保命"],
	"tongyong": ["灵气护体", "百草回春", "祥瑞加持"],
}
const 被动词条 := {
	"jianxiu": ["破法护身", "近身兜底", "剑意共鸣"],
	"tixiu": ["反制突进", "肉身续航", "镇岳守护"],
	"faxiu": ["增伤破甲", "解控自保", "法界增幅"],
	"tongyong": ["灵韵加护", "气运庇护", "万物亲和"],
}
const 羁绊技能 := {
	"jianxiu": "万剑归宗·灵契（对战法修额外破法）",
	"tixiu": "镇狱·灵契（近战锁敌强化）",
	"faxiu": "周天·灵契（术法范围联动）",
	"tongyong": "天地灵契（全属性微幅增幅）",
}

var 种类名 := ""
var 适配职业 := ""
var 品阶 := ""
var 神兽血脉 := false
var 孵化中 := true
var 剩余天数 := 0
var 战力比例 := 0.12
var 主动 := ""
var 被动 := ""
var 羁绊 := ""

func _init():
	随机成蛋()

func 随机成蛋():
	var s := 灵兽种类.pick_random()
	种类名 = s["名"]
	适配职业 = s["适配"]
	孵化中 = true
	剩余天数 = randi_range(180, 360)
	品阶 = ""; 神兽血脉 = false; 主动 = ""; 被动 = ""; 羁绊 = ""
	战力比例 = 0.12

func 孵化():
	品阶 = 加权抽(品阶权重)
	if 品阶 == "dujie_jie":
		神兽血脉 = randf() < 0.05
	elif 品阶 == "xian_jie":
		神兽血脉 = randf() < 0.01
	战力比例 = randf_range(0.12, 0.20)
	_滚技能()
	孵化中 = false
	剩余天数 = 0

func _滚技能():
	主动 = ""; 被动 = ""; 羁绊 = ""
	if 品阶 in ["bao_jie", "wang_jie"]:
		主动 = 主动技能[适配职业].pick_random()
	elif 品阶 in ["sheng_jie", "xian_jie"]:
		主动 = 主动技能[适配职业].pick_random()
		被动 = 被动词条[适配职业].pick_random()
	elif 品阶 == "dujie_jie":
		主动 = 主动技能[适配职业].pick_random()
		被动 = 被动词条[适配职业].pick_random()
		羁绊 = 羁绊技能[适配职业]

func 加权抽(权重: Dictionary) -> String:
	var 总 := 0.0
	for k in 权重:
		总 += 权重[k]
	var 抽 := randf() * 总
	for k in 权重:
		抽 -= 权重[k]
		if 抽 <= 0:
			return k
	return 权重.keys()[0]

func 战力贡献(本体战力: int) -> int:
	return int(本体战力 * 战力比例)

func 简介(本体战力 := 0) -> String:
	if 孵化中:
		return "%s的蛋（御兽堂孵化中，剩余 %d 日）" % [种类名, 剩余天数]
	var s := "%s" % 种类名
	if 神兽血脉:
		s += "·神兽血脉"
	s += " [%s灵兽·%s] 战力+%d（本体%d×%.0f%%）" % \
		[适配职业 if 适配职业 != "通用" else "通用", 品阶, 战力贡献(本体战力), 本体战力, 战力比例 * 100]
	if 主动 != "":
		s += "\n  主动：%s" % 主动
	if 被动 != "":
		s += "\n  被动：%s" % 被动
	if 羁绊 != "":
		s += "\n  羁绊：%s" % 羁绊
	return s

func to_dict() -> Dictionary:
	return {
		"种类名": 种类名, "适配职业": 适配职业, "品阶": 品阶, "神兽血脉": 神兽血脉,
		"孵化中": 孵化中, "剩余天数": 剩余天数, "战力比例": 战力比例,
		"主动": 主动, "被动": 被动, "羁绊": 羁绊,
	}

func from_dict(d: Dictionary):
	种类名 = d.get("种类名", "")
	适配职业 = d.get("适配职业", "")
	品阶 = d.get("品阶", "")
	神兽血脉 = d.get("神兽血脉", false)
	孵化中 = d.get("孵化中", true)
	剩余天数 = d.get("剩余天数", 0)
	战力比例 = d.get("战力比例", 0.12)
	主动 = d.get("主动", "")
	被动 = d.get("被动", "")
	羁绊 = d.get("羁绊", "")
