# main.gd —— 主界面（里程碑1 + 奇遇/物品系统）
# 用代码生成全部 UI，初学者无需手动摆节点：
# 新建 Control 节点作为根 -> 挂本脚本 -> 设为启动场景即可运行
extends Control

const Disciple = preload("res://disciple.gd")
const Item = preload("res://item.gd")
const Beast = preload("res://beast.gd")

var 灵石标签: Label
var 列表: VBoxContainer
var 抉择区: VBoxContainer
var 御兽区: VBoxContainer
var 战报: Label
var 详情: Label

func _ready():
	# 根纵向布局
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)

	灵石标签 = Label.new()
	v.add_child(灵石标签)

	var 行 := HBoxContainer.new()
	v.add_child(行)
	var 招收 := Button.new(); 招收.text = "育英堂·招收弟子"; 行.add_child(招收); 招收.pressed.connect(_on_招收)
	var 结算 := Button.new(); 结算.text = "结算一日"; 行.add_child(结算); 结算.pressed.connect(_on_结算)

	var 行2 := HBoxContainer.new()
	v.add_child(行2)
	var 存 := Button.new(); 存.text = "存档"; 行2.add_child(存); 存.pressed.connect(_on_存档)
	var 读 := Button.new(); 读.text = "读档"; 行2.add_child(读); 读.pressed.connect(_on_读档)
	var 历练 := Button.new(); 历练.text = "派遣历练（全员）"; 行2.add_child(历练); 历练.pressed.connect(_on_历练)
	var 快进 := Button.new(); 快进.text = "御兽堂·快进(测试)"; 行2.add_child(快进); 快进.pressed.connect(_on_快进)

	# 弟子列表
	var 滚动 := ScrollContainer.new()
	滚动.custom_minimum_size = Vector2(0, 220)
	v.add_child(滚动)
	列表 = VBoxContainer.new()
	滚动.add_child(列表)

	# 抉择区（极品/特殊道具交宗或自留）
	抉择区 = VBoxContainer.new()
	抉择区.add_theme_constant_override("separation", 6)
	v.add_child(抉择区)

	# 御兽堂（灵兽蛋孵化进度 + 已孵化绑定）
	御兽区 = VBoxContainer.new()
	御兽区.add_theme_constant_override("separation", 4)
	v.add_child(御兽区)

	战报 = Label.new()
	战报.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(战报)

	详情 = Label.new()
	v.add_child(详情)

	Game.弟子变动.connect(刷新)
	Game.战报更新.connect(_on_战报)
	刷新()
	刷新抉择()
	刷新御兽()

func _on_招收():
	Game.招收弟子()

func _on_结算():
	Game.结算一日()
	详情.text = "已结算一日，灵石 +50"

func _on_历练():
	战报.text = Game.历练全员()
	详情.text = "历练完毕，查看战报与下方抉择。"

func _on_快进():
	Game.推进孵化(30)
	详情.text = "（测试）御兽堂快进30日，查看孵化进度。"

func _on_存档():
	Game.save_game()
	详情.text = "已存档（user://save.json）"

func _on_读档():
	Game.load_game()
	详情.text = "已读档"

func _on_战报(文本: String):
	战报.text = 文本

func 刷新():
	灵石标签.text = "灵石：%d    贡献点：%d    弟子数：%d" % [Game.灵石, Game.贡献点, Game.弟子列表.size()]
	for c in 列表.get_children():
		c.queue_free()
	for d in Game.弟子列表:
		var lab := Label.new()
		lab.text = d.简介()
		lab.custom_minimum_size = Vector2(0, 150)
		列表.add_child(lab)
	刷新抉择()
	刷新御兽()

# 重建“交宗 / 自留”抉择界面
func 刷新抉择():
	for c in 抉择区.get_children():
		c.queue_free()
	if Game.待抉择.is_empty():
		return
	var 标题 := Label.new()
	标题.text = "—— 极品/特殊道具抉择 ——"
	抉择区.add_child(标题)
	for 条目 in Game.待抉择:
		var 弟子: Disciple = 条目["弟子"]
		var 物品: Item = 条目["物品"]
		var 块 := VBoxContainer.new()
		块.add_theme_constant_override("separation", 2)
		var 信息 := Label.new()
		信息.text = "【%s】获【%s】" % [弟子.姓名, 物品.简介()]
		块.add_child(信息)
		var 行 := HBoxContainer.new()
		var 交 := Button.new(); 交.text = "交宗换贡献"
		交.pressed.connect(_on_交宗.bind(条目))
		var 留 := Button.new(); 留.text = "弟子自留"
		留.pressed.connect(_on_自留.bind(条目))
		行.add_child(交); 行.add_child(留)
		块.add_child(行)
		抉择区.add_child(块)

func _on_交宗(条目: Dictionary):
	Game.交宗(条目)
	详情.text = "已交宗。"

func _on_自留(条目: Dictionary):
	Game.自留(条目)
	详情.text = "弟子已自留。"

# 重建御兽堂界面：孵化中蛋进度 + 已孵化灵兽的绑定按钮
func 刷新御兽():
	for c in 御兽区.get_children():
		c.queue_free()
	if Game.灵兽蛋列表.is_empty() and Game.灵兽库存.is_empty():
		return
	var 标题 := Label.new()
	标题.text = "—— 御兽堂 ——"
	御兽区.add_child(标题)
	# 孵化中
	for 蛋 in Game.灵兽蛋列表:
		var lab := Label.new()
		lab.text = 蛋.简介()
		御兽区.add_child(lab)
	# 已孵化待绑定
	for 灵兽 in Game.灵兽库存:
		var 块 := VBoxContainer.new()
		块.add_theme_constant_override("separation", 2)
		var 信息 := Label.new()
		信息.text = 灵兽.简介(100)
		块.add_child(信息)
		var 绑 := Button.new()
		绑.text = "绑定给空闲弟子"
		绑.pressed.connect(_on_绑定.bind(灵兽))
		块.add_child(绑)
		御兽区.add_child(块)

func _on_绑定(灵兽: Beast):
	详情.text = Game.绑定灵兽给首只合格(灵兽)
