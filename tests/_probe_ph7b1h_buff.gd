extends Node
## PH7-BATCH1H-FIX2 · 族D（汇总负责人全局buff 键域污染）修复后只读断言（headless）
## 断言：
##   ① 汇总负责人全局buff() 返回 dict 的键 ⊆ {攻,防,血,速,修炼,产出,测灵}
##   ② 该 dict 不含污染键 "：" / "zh" / "职"
##   ③ 无任何负责人 ⇒ 除「防」外全 0；「防」=0.01（阵殿常驻防 +1%，作者 :22697 声明，与是否有负责人无关）
##   ④ 指定 qitang（器堂/器殿）负责人 ⇒ buff["攻"] > 0（证明「映射→buff」链路真通）
## 运行：<godot_console> --headless --path <proj> --scene res://tests/_probe_ph7b1h_buff.tscn
## 判据：末行 >>>PROBE_RESULT=PASS

const 合法键 := {"攻": true, "防": true, "血": true, "速": true, "修炼": true, "产出": true, "测灵": true}
const 污染键 := ["：", "zh", "职"]

var 失败: Array = []
var 断言: int = 0

func _ready() -> void:
	prints("=== 探针 PH7B1H 族D buff 键域 启动 ===")
	var 原司职: Dictionary = Game.司职列表

	# 构造「无负责人」副本（浅拷贝 + 置 负责人=null，不污染原始 dict）
	var 无负责: Dictionary = {}
	for k in Game.司职列表.keys():
		var v: Dictionary = Game.司职列表[k]
		var nv: Dictionary = v.duplicate()
		nv["负责人"] = null
		无负责[k] = nv
	Game.司职列表 = 无负责

	var b0: Dictionary = Game.汇总负责人全局buff()
	var 越界: Array = []
	var 污染: Array = []
	var 异常: Array = []
	for k in b0.keys():
		if not 合法键.has(k):
			越界.append(str(k))
		if 污染键.has(k):
			污染.append(str(k))
		var v: float = float(b0[k])
		if str(k) == "防":
			if absf(v - 0.01) > 0.0001:
				异常.append("防=%s（期望 0.01）" % str(v))
		elif absf(v) > 0.0001:
			异常.append("%s=%s（期望 0）" % [str(k), str(v)])
	_ok(越界.is_empty(), "① 键域 ⊆ {攻,防,血,速,修炼,产出,测灵}（越界键=%s）" % str(越界))
	_ok(污染.is_empty(), "② 不含污染键 冒号/zh/职（污染键=%s）" % str(污染))
	_ok(异常.is_empty(), "③ 无负责人 ⇒ 除「防」=0.01（阵殿常驻）外全 0（异常=%s）" % str(异常))

	# ④ 指定 qitang 负责人 ⇒ buff["攻"] > 0
	if Game.司职列表.has("qitang"):
		var d: Disciple = Disciple.new()
		Game.司职列表["qitang"]["负责人"] = d
		var b1: Dictionary = Game.汇总负责人全局buff()
		var 攻值: float = float(b1.get("攻", 0.0))
		_ok(攻值 > 0.0, "④ 指定 qitang 负责人 ⇒ buff[\"攻\"] > 0（实得 %s）" % str(攻值))
		_ok(b1.has("攻"), "④' 器堂 buff 落在合法维度「攻」（键存在=%s）" % str(b1.has("攻")))
	else:
		_ok(false, "④ 司职列表缺 qitang（无法验链路）")

	# 还原
	Game.司职列表 = 原司职
	_报告()

func _ok(条件: bool, 文: String) -> void:
	断言 += 1
	if 条件:
		prints(">>>  [OK] %s" % 文)
	else:
		失败.append(文)
		prints(">>>  [XX] %s" % 文)

func _报告() -> void:
	prints(">>> 断言 %d 条 / 失败 %d 条" % [断言, 失败.size()])
	prints(">>>PROBE_RESULT=%s" % ("PASS" if 失败.is_empty() else ("FAIL:" + ", ".join(失败))))
	get_tree().quit(0 if 失败.is_empty() else 1)
