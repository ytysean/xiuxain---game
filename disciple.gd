# disciple.gd —— 弟子数据类
class_name Disciple
extends RefCounted

const 资质表 := {
	"fan_su": {"上限": "练气", "速度": 1.0},
	"pingyong": {"上限": "筑基", "速度": 1.4},
	"youliang": {"上限": "金丹", "速度": 1.8},
	"tiancai": {"上限": "元婴", "速度": 2.5},
	"yaonie": {"上限": "化神", "速度": 3.5},
	"kuangshi": {"上限": "渡劫", "速度": 4.8},
}
const 资质权重 := {"fan_su": 50.0, "pingyong": 30.0, "youliang": 14.0, "tiancai": 5.0, "yaonie": 0.9, "kuangshi": 0.1}

const 灵根五行 := ["金", "木", "水", "火", "土"]
const 灵根变异 := ["雷", "冰", "风", "光", "暗"]
const 命格表 := ["战狂","剑痴","战体","武曲","将星","福星","寻宝","商道","聚灵","丹心",
				"匠心","书香","阵道","符道","御兽","长生","桃花","衰星","孤煞","血光"]

const 姓库 := ["云","玄","青","墨","尘","凌","苏","叶","林","楚","姬","慕容","南宫","东方"]
const 名库 := ["霄","霜","青","渊","岚","芷","瑶","尘","逸","寒","羽","冥","玄","翰"]

var 姓名 := ""
var 资质 := ""
var 灵根 := ""
var 命格 := ""
var 境界 := "练气"
var 寿元 := 80
var 修炼速度 := 1.0
var 战力 := 100
var 备注 := ""
var 职业 := "剑修"
var 物品: Array[Item] = []
var 灵兽: Beast = null

func _init():
	随机生成()

func 总战力() -> int:
	var s := 战力
	for it in 物品:
		s += it.战力加成
	if 灵兽 != null and not 灵兽.孵化中:
		s += 灵兽.战力贡献(战力)
	return s

func 加权随机(权重: Dictionary) -> String:
	var 总 := 0.0
	for k in 权重:
		总 += 权重[k]
	var 抽 := randf() * 总
	for k in 权重:
		抽 -= 权重[k]
		if 抽 <= 0:
			return k
	return 权重.keys()[0]

func 随机生成():
	资质 = 加权随机(资质权重)
	修炼速度 = 资质表[资质]["速度"]
	var r := randf()
	if r < 0.02:
		灵根 = "天灵根"
	elif r < 0.20:
		灵根 = 灵根变异.pick_random()
	else:
		灵根 = 灵根五行.pick_random()
	if randf() < 0.01:
		命格 = "天命"
	else:
		命格 = 命格表.pick_random()
	职业 = ["剑修", "体修", "法修"].pick_random()
	姓名 = 姓库.pick_random() + 名库.pick_random()
	寿元 = 80
	战力 = 100

func 简介() -> String:
	var 显示名 := 姓名
	if 备注 != "":
		显示名 = "%s（%s）" % [姓名, 备注]
	var s := "%s\n资质:%s  灵根:%s  命格:%s  职业:%s\n境界:%s  寿元:%d  战力:%d(总%d)  修炼x%.1f" % \
		[显示名, 资质, 灵根, 命格, 职业, 境界, 寿元, 战力, 总战力(), 修炼速度]
	if 物品.size() > 0:
		s += "\n  持有："
		for it in 物品:
			s += "\n    · " + it.简介()
	if 灵兽 != null:
		s += "\n  灵兽：" + 灵兽.简介(战力)
		var 联动 := 灵兽联动()
		if 联动 != "":
			s += "\n    ☆ " + 联动
	return s

func 灵兽联动() -> String:
	if 灵兽 == null or 灵兽.孵化中:
		return ""
	for it in 物品:
		if it.极品属性 == null:
			continue
		var n := it.极品属性["名"]
		if n == "万法可破" and 灵兽.适配职业 == "剑修":
			return "【万法可破】+破法灵兽：对战法修额外获得短时法术无敌帧"
		if n == "金刚不坏" and 灵兽.适配职业 == "体修":
			return "【金刚不坏】+固防灵兽：锁血阈值由20%提升至25%"
		if n == "焚身灭甲" and 灵兽.适配职业 == "法修":
			return "【焚身灭甲】+火灵灵兽：真实伤害小幅扩散溅射"
	return ""

func to_dict() -> Dictionary:
	var 物品列表 := []
	for it in 物品:
		物品列表.append(it.to_dict())
	return {
		"姓名": 姓名, "资质": 资质, "灵根": 灵根, "命格": 命格,
		"境界": 境界, "寿元": 寿元, "修炼速度": 修炼速度, "战力": 战力, "备注": 备注,
		"职业": 职业, "物品": 物品列表,
		"灵兽": (灵兽.to_dict() if 灵兽 != null else null)
	}

func from_dict(d: Dictionary):
	姓名 = d.get("姓名", "")
	资质 = d.get("资质", "")
	灵根 = d.get("灵根", "")
	命格 = d.get("命格", "")
	境界 = d.get("境界", "练气")
	寿元 = d.get("寿元", 80)
	修炼速度 = d.get("修炼速度", 1.0)
	战力 = d.get("战力", 100)
	备注 = d.get("备注", "")
	职业 = d.get("职业", "剑修")
	物品.clear()
	for itd in d.get("物品", []):
		var it := Item.new()
		it.from_dict(itd)
		物品.append(it)
	灵兽 = null
	if d.has("灵兽") and d["灵兽"] != null:
		var b := Beast.new()
		b.from_dict(d["灵兽"])
		灵兽 = b
