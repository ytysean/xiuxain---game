extends Node

## headless 逻辑探针：社交卡 / 储物袋 / 履历格式化 / 修真味互动（2026-09-15 本轮新增）
##
## 运行：MSYS_NO_PATHCONV=1 <godot> --headless --path <proj> --scene res://tests/_probe_social_bag.tscn
## 判据：末行出现 >>>SOCIAL_BAG_ALL_DONE 且 FAIL=0、全程无 SCRIPT ERROR。
##
## 为什么不截图：headless 走 dummy 渲染器，get_texture() 取空（引擎限制），
##   且真实渲染会弹窗打扰（验收铁律禁止）⇒ 本探针只做运行时断言。
##   编译期查不出「属性名写错 / 字典键不存在」这类错，运行时断言是唯一防线。

const 探针账号 := "acc_probe_social_bag"

var _fail: int = 0

func _ok(条件: bool, 名: String) -> void:
	if 条件:
		prints("  PASS  ", 名)
	else:
		_fail += 1
		printerr("  FAIL  ", 名)

func _ready() -> void:
	prints("=== 社交卡 / 储物袋 / 履历 / 互动 探针 ===")
	if Game == null:
		printerr("FATAL Game 单例缺失")
		get_tree().quit()
		return
	var ps: PackedScene = load("res://main.tscn") as PackedScene
	if ps == null:
		printerr("FATAL main.tscn 加载失败")
		get_tree().quit()
		return
	var main: Node = ps.instantiate()
	add_child(main)
	main._登录_进入({"id": 探针账号})
	var ui: Node = main.get("新UI")
	if ui == null:
		printerr("FATAL 新UI 为空")
		get_tree().quit()
		return
	if Game.弟子列表.is_empty():
		printerr("FATAL 本档无弟子")
		get_tree().quit()
		return

	# ---------- A. 储物袋 API ----------
	var d = Game.弟子列表[0]
	_ok(d.has_method("储物袋容量"), "A1 储物袋容量() 存在")
	_ok(d.储物袋容量() >= 3, "A2 容量下限（练气3）实得 %d" % d.储物袋容量())
	var 首批: Array = Game.获取所有普通法宝配置().keys()
	_ok(首批.size() > 0, "A3 普通法宝配置非空（%d 件）" % 首批.size())
	if 首批.is_empty():
		_finish()
		return
	var t1: String = str(首批[0])
	_ok(d.收入储物袋(t1), "A4 收入首件成功")
	_ok(not d.收入储物袋(t1), "A5 重复收入被拒")
	_ok(d.获取储物袋法宝().has(t1), "A6 获取列表含该件")
	var i: int = 1
	while d.储物袋法宝.size() < d.储物袋容量() and i < 首批.size():
		d.收入储物袋(str(首批[i]))
		i += 1
	_ok(d.储物袋法宝.size() <= d.储物袋容量(),
		"A7 不超容量（%d/%d）" % [d.储物袋法宝.size(), d.储物袋容量()])
	_ok(not d.收入储物袋("__no_such_treasure__"), "A8 非法 id 被拒")
	_ok(d.取出储物袋(t1), "A9 取出成功")
	_ok(not d.取出储物袋(t1), "A10 重复取出被拒")

	# ---------- B. 择宝为纯函数（热路径上不得写状态）----------
	var 前: String = str(d._普通法宝ID)
	var 择: String = str(d.选择出战法宝("强攻"))
	_ok(str(d._普通法宝ID) == 前, "B1 选择出战法宝 无副作用")
	_ok(择 == "" or d.获取储物袋法宝().has(择), "B2 择宝结果取自袋内：%s" % 择)
	_ok(str(d.推断战况()) in ["危急", "固守", "常规"], "B3 推断战况 合法：%s" % d.推断战况())

	# ---------- C. 履历格式化 + 社交卡按钮 ----------
	ui._open_disciple_detail(d)
	var 详情: Node = ui.get("_current_sub")
	_ok(详情 != null, "C0 弟子详情页已创建")
	if 详情 != null:
		var f1 = str(详情.call("_格式化履历", {"日": 12, "事件": "突破筑基", "详情": "耗灵石300"}))
		_ok(f1.contains("第12日") and f1.contains("突破筑基") and f1.contains("耗灵石300"), "C1 {日,事件,详情} → %s" % f1)
		var f2 = str(详情.call("_格式化履历", {"时间": 30, "事件": "泄露功法", "类型": "惩罚"}))
		_ok(f2.contains("第30日") and f2.contains("惩罚"), "C2 {时间,事件,类型} → %s" % f2)
		var f3 = str(详情.call("_格式化履历", "历练·落霞谷 胜"))
		_ok(f3 == "历练·落霞谷 胜", "C3 纯串原样 → %s" % f3)
		var f4 = str(详情.call("_格式化履历", {"日": 0, "事件": "入宗"}))
		_ok(f4 == "入宗", "C4 无日号不加前缀 → %s" % f4)
		详情.call("_on_tab_pressed", "详情")
		var 按钮数: int = _数节点(详情, "SocialBtn")
		_ok(按钮数 >= 1, "C5 社交卡可点按钮数=%d" % 按钮数)
		详情.call("_open_储物袋面板")
		_ok(true, "C6 储物袋面板可打开（无脚本错即通过）")

	# ---------- D. 七种修真味互动运行时可执行 ----------
	var a = Game.弟子列表[0]
	var b = Game.弟子列表[1] if Game.弟子列表.size() > 1 else Game.弟子列表[0]
	for 类型 in ["传功授法", "共参道藏", "护法守关", "斗法印证", "心魔互诉", "义结金兰", "同祭祖师"]:
		var r: Dictionary = Game._执行弟子互动(a, b, str(类型))
		_ok(bool(r.get("成功", false)) and str(r.get("类型", "")) == str(类型),
			"D 互动「%s」→ %s" % [str(类型), str(r.get("消息", r.get("因", "")))])

	# ---------- E. 决策链可跑通 ----------
	_ok(str(Game._决定互动类型(a, b)) != "", "E1 互动类型可决策")

	_finish()

## 递归计数同名节点（社交卡按钮挂在卡片容器下，非详情页直接子节点）
func _数节点(根: Node, 名称: String) -> int:
	var n: int = 0
	for c in 根.get_children():
		if str(c.name) == 名称:
			n += 1
		n += _数节点(c, 名称)
	return n

func _finish() -> void:
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	if _fail == 0:
		prints(">>>SOCIAL_BAG_ALL_DONE  FAIL=0")
	else:
		printerr(">>>SOCIAL_BAG_HAS_FAIL  FAIL=%d" % _fail)
	get_tree().quit()
