extends Node

## 定向微探针：宗门战页的「队签 / 类型卡」点击到底有没有生效。
## 用法：python .workbuddy/_run_probe.py "res://tests/_probe_battle_switch.tscn" "_probe_bs.txt"
## 意义：死键扫描把 TeamTab_0/1/2 与 Type_* ×4 全判成 DEAD，需判定是
##   「探针指纹采不到」还是「信号真没接通」——直接读页面内部状态变量，不看指纹。

func _ready() -> void:
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	var main: Node = ps.instantiate()
	add_child(main)
	await _s(6)
	main._登录_进入({"id": "acc_full"})
	await _s(16)
	var ui: Node = main.get("新UI")
	ui._show_sub_page("宗门战", ui.ENTRY_SUB_PAGES["宗门战"])
	await _s(14)
	var page = ui.get("_current_sub")
	if page == null or not is_instance_valid(page):
		prints(">>>BS_PAGE_NULL")
		get_tree().quit()
		return
	prints(">>>BS_PAGE=", page.name)
	prints(">>>BS_BEFORE 队伍索引=", page.get("_当前队伍索引"),
		" 战斗类型=", page.get("_当前战斗类型"))

	var t1 = page.find_child("TeamTab_1", true, false)
	if t1 == null:
		prints(">>>BS_TEAMTAB1_NOT_FOUND")
	else:
		prints(">>>BS_TEAMTAB1 disabled=", t1.disabled, " toggle=", t1.toggle_mode,
			" visible=", t1.is_visible_in_tree())
		var 前 = str(page.get("_当前队伍索引"))
		t1.pressed.emit()
		await _s(8)
		prints(">>>BS_TEAMTAB1 索引 ", 前, " -> ", str(page.get("_当前队伍索引")),
			"  生效=", 前 != str(page.get("_当前队伍索引")))

	var c2 = page.find_child("Type_秘境争夺战", true, false)
	if c2 == null:
		prints(">>>BS_TYPE_NOT_FOUND")
	else:
		prints(">>>BS_TYPE disabled=", c2.disabled, " toggle=", c2.toggle_mode,
			" visible=", c2.is_visible_in_tree())
		var 前T = str(page.get("_当前战斗类型"))
		c2.pressed.emit()
		await _s(8)
		prints(">>>BS_TYPE 类型 ", 前T, " -> ", str(page.get("_当前战斗类型")),
			"  生效=", 前T != str(page.get("_当前战斗类型")))

	# 顺带看一眼槽位文本（切换队伍后应变化）
	var s0 = page.find_child("Slot_0", true, false)
	if s0 != null:
		prints(">>>BS_SLOT0 text=", s0.text.replace("\n", "/"))
	prints(">>>BS_DONE")
	get_tree().quit()


func _s(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
