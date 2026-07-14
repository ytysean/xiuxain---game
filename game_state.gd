# game_state.gd —— 宗门全局状态（Autoload 单例，名称设为 "Game"）
# 负责：灵石 / 贡献点、弟子列表、招收、结算、历练奇遇、交宗抉择、存档/读档
# 对应策划案：M1 框架 + 奇遇/物品系统（无上下限仅概率、极品交宗或自留、低阶携宝越阶）
extends Node

var 灵石 := 1000
var 贡献点 := 0
var 弟子列表: Array[Disciple] = []   # 强类型数组（需 disciple.gd 已注册 class_name）

# 御兽堂：孵化中的灵兽蛋 + 已孵化待绑定的灵兽库存
var 灵兽蛋列表: Array[Beast] = []
var 灵兽库存: Array[Beast] = []

# 待抉择队列：弟子获得的极品/特殊道具，等待玩家决定“交宗换贡献”或“弟子自留”
# 元素结构：{"弟子": Disciple, "物品": Item, "文本": String}
var 待抉择: Array[Dictionary] = []

signal 弟子变动()
signal 战报更新(文本: String)

func _ready():
	load_game()

# 育英堂·招收一名弟子
func 招收弟子() -> Disciple:
	var d := Disciple.new()
	弟子列表.append(d)
	弟子变动.emit()
	return d

# 结算一日（M1 占位：灵田/矿脉产出；同时推进御兽堂孵化，M2 细化）
func 结算一日():
	灵石 += 50
	推进孵化(1)
	弟子变动.emit()

# ============ 历练 / 奇遇 ============
# 全员派遣历练：各自独立判定奇遇与掉落，返回合并战报
func 历练全员() -> String:
	if 弟子列表.is_empty():
		return "门下无弟子可派遣。"
	var 报 := []
	for d in 弟子列表:
		报.append(历练一人(d))
	弟子变动.emit()
	var 文本 := "\n".join(报)
	战报更新.emit(文本)
	return 文本

# 单个弟子历练：奇遇概率、物品掉落（无上下限仅概率）、灵兽蛋、越阶反杀剧情
func 历练一人(d: Disciple) -> String:
	# 奇遇基础概率 30%，寻宝/福星命格额外加成
	var 概率 := 0.30
	if d.命格 == "寻宝":
		概率 += 0.20
	elif d.命格 == "福星":
		概率 += 0.15
	var 文本 := "【%s】出门历练……" % d.姓名
	if randf() < 概率:
		var it := Item.new()   # Item._init 内部随机生成（阶越高概率越低）
		d.物品.append(it)
		文本 += " 触发奇遇，得【%s】！" % it.简介()
		# 越阶反杀：低阶弟子凭携宝反克高阶敌人（纯剧情文本，体现随机性）
		if randf() < 0.45:
			文本 += " 途中遭高阶修士狙杀，凭%s之威越阶反杀，全身而退！" % it.名称
		else:
			文本 += " 携宝而归。"
		# 极品 / 特殊 → 入待抉择队列，等玩家选择交宗或自留
		if it.极品 or it.特殊:
			待抉择.append({"弟子": d, "物品": it, "文本": 文本})
	else:
		文本 += " 平安归来，无所获。"
	# 灵兽蛋：15% 概率寻得一枚（交御兽堂孵化，品质孵化时随机）
	if randf() < 0.15:
		var 蛋 := Beast.new()   # 随机成蛋（仅显示种类名）
		灵兽蛋列表.append(蛋)
		文本 += " 于秘境寻得灵兽蛋一枚：【%s的蛋】。" % 蛋.种类名
	return 文本

# 御兽堂·推进孵化（日数；现实半天~1天 ≈ 游戏半年~1年）
func 推进孵化(日数: int):
	var 已孵 := []
	for e in 灵兽蛋列表:
		e.剩余天数 -= 日数
		if e.剩余天数 <= 0:
			e.孵化()
			已孵.append(e)
	for e in 已孵:
		灵兽蛋列表.erase(e)
		灵兽库存.append(e)
	if 已孵.size() > 0:
		战报更新.emit("御兽堂有 %d 枚灵兽蛋孵化完成，可前往绑定！" % 已孵.size())

# 御兽堂·将灵兽绑定给首只符合条件的空闲弟子
# 规则：一人一兽；凡俗/平庸低资质仅可携凡/灵阶；灵兽境界跟随宿主
func 绑定灵兽给首只合格(灵兽: Beast) -> String:
	for d in 弟子列表:
		if d.灵兽 != null:
			continue
		if (d.资质 == "fan_su" or d.资质 == "pingyong") and not (灵兽.品阶 in ["fan_jie", "ling_jie"]):
			continue
		d.灵兽 = 灵兽
		灵兽库存.erase(灵兽)
		弟子变动.emit()
		return "【%s】已绑定灵兽【%s】。" % [d.姓名, 灵兽.种类名]
	return "无符合条件的空闲弟子可绑定（低资质仅能携凡/灵阶灵兽）。"

# 玩家选择：交宗换贡献（按七品阶给贡献点，移除弟子身上该物品）
func 交宗(条目: Dictionary):
	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	if 弟子.物品.has(物品):
		弟子.物品.erase(物品)
		var 贡献: int = {"fan_jie": 10, "ling_jie": 20, "bao_jie": 40, "wang_jie": 80, "sheng_jie": 150, "xian_jie": 300, "dujie_jie": 600}.get(物品.品阶, 10)
		贡献点 += 贡献
	移除待抉择(条目)
	弟子变动.emit()
	战报更新.emit("【%s】将【%s】交予宗门，换得贡献点 +%d。" % [弟子.姓名, 物品.名称, 贡献])

# 玩家选择：弟子自留（物品已在其身上，仅移除待抉择）
func 自留(条目: Dictionary):
	var 弟子: Disciple = 条目["弟子"]
	var 物品: Item = 条目["物品"]
	移除待抉择(条目)
	弟子变动.emit()
	战报更新.emit("【%s】将【%s】收入囊中，自行留用。" % [弟子.姓名, 物品.名称])

func 移除待抉择(条目: Dictionary):
	for i in range(待抉择.size()):
		if 待抉择[i] == 条目:
			待抉择.remove_at(i)
			return

# ============ 存档 / 读档 ============
func save_game():
	var data := {"lingshi": 灵石, "gongxian": 贡献点, "dizi": [], "lingshou_dan": [], "lingshou_kucun": []}
	for d in 弟子列表:
		data["dizi"].append(d.to_dict())
	for e in 灵兽蛋列表:
		data["lingshou_dan"].append(e.to_dict())
	for b in 灵兽库存:
		data["lingshou_kucun"].append(b.to_dict())
	var f := FileAccess.open("user://save.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game():
	if not FileAccess.file_exists("user://save.json"):
		return
	var f := FileAccess.open("user://save.json", FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return
	灵石 = data.get("lingshi", 0)
	贡献点 = data.get("gongxian", 0)
	弟子列表.clear()
	待抉择.clear()
	灵兽蛋列表.clear()
	灵兽库存.clear()
	for dd in data.get("dizi", []):
		var d := Disciple.new()
		d.from_dict(dd)
		弟子列表.append(d)
	for ed in data.get("lingshou_dan", []):
		var e := Beast.new()
		e.from_dict(ed)
		灵兽蛋列表.append(e)
	for bd in data.get("lingshou_kucun", []):
		var b := Beast.new()
		b.from_dict(bd)
		灵兽库存.append(b)
	弟子变动.emit()
