extends Node
## 弟子立绘三维回归验证（无头）
## 覆盖：①气质↔底模映射表同序 ②随机生成后 变体==灵根序、年龄段==真实年龄 ③旧档脏值自愈
## 用法：godot --headless --path <proj> --scene res://tests/_t_face_probe.tscn

const DiscipleData := preload("res://disciple.gd")
const OUT := "res://.workbuddy/_face_probe.log"

var _buf: Array = []
var _fail: int = 0

func _log(s: String) -> void:
	_buf.append(s)

func _ck(条件: bool, 描述: String) -> void:
	if 条件:
		_log("  [OK] " + 描述)
	else:
		_fail += 1
		_log("  [FAIL] " + 描述)

func _ready() -> void:
	_run()
	_log("")
	_log("RESULT: %s（失败 %d）" % ["PASS" if _fail == 0 else "FAIL", _fail])
	_dump()
	get_tree().quit(1 if _fail > 0 else 0)

func _dump() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_buf))
		f.close()

func _run() -> void:
	_log("=== 弟子立绘三维回归（2026-09-14）===")
	_log("气质列表   = " + str(DiscipleData.气质列表))
	_log("气质底模列表 = " + str(DiscipleData.气质底模列表))
	_ck(DiscipleData.气质底模列表.size() == DiscipleData.气质列表.size(),
		"气质底模列表 与 气质列表 长度一致（%d）" % DiscipleData.气质列表.size())
	_log("")

	_log("--- A. 12 性格 → 气质 → 底模（唯一映射，须与美术代号语义一致）---")
	var 期望: Dictionary = {
		"沉稳守道": "chen", "守礼尊师": "chen", "谨慎多疑": "chen",
		"锐意争先": "huo2", "豪迈仗义": "huo2",
		"桀骜不羁": "gu", "狂傲绝世": "gu", "孤僻清修": "gu",
		"杀伐果断": "bao",
		"仁心济世": "wen", "恬淡悟道": "wen",
		"贪心逐缘": "jiao",
	}
	for 性 in DiscipleData.性格表:
		var d = DiscipleData.new()
		d.性格 = 性
		var 模: String = str(d.获取立绘底模())
		var 名: String = str(d.获取气质())
		var 期: String = str(期望.get(性, "?"))
		_ck(模 == 期, "性格=%-5s → 气质=%-3s → 底模=%-5s（期望 %s）" % [性, 名, 模, 期])
	_log("")

	_log("--- B. new()/随机生成 后 立绘三维自洽 ×12 ---")
	for i in range(12):
		var d = DiscipleData.new()      # _init() 内部已调 随机生成()
		_log("  [%02d] 性格=%-5s 气质=%-3s 底模=%-5s 立绘类型=%-5s | 灵根=%-4s 灵根序=%d 立绘变体=%d | 年龄=%-4s 年龄段=%s" % [
			i, str(d.性格), str(d.获取气质()), str(d.获取立绘底模()), str(d.立绘类型),
			str(d.灵根), d.获取灵根序(), int(d.立绘变体), str(d.年龄), str(d.年龄段)])
		if str(d.立绘类型) != str(d.获取立绘底模()):
			_fail += 1
			_log("      [FAIL] 立绘类型 ≠ 获取立绘底模()")
		if int(d.立绘变体) != d.获取灵根序():
			_fail += 1
			_log("      [FAIL] 立绘变体 ≠ 灵根序")
		var 期段: String = "少年" if float(d.年龄) < 18.0 else "青年"
		if str(d.年龄段) != 期段:
			_fail += 1
			_log("      [FAIL] 年龄段=%s 期望 %s" % [str(d.年龄段), 期段])
	_log("  （上面无 [FAIL] 即 A/B 全通）")
	_log("")

	_log("--- C. 旧档脏值自愈（模拟实测存档：立绘类型=huo2 / 立绘变体=0）---")
	var 事: Array = [
		["慕容霜", "豪迈仗义", "木"], ["玄青", "守礼尊师", "火"],
		["青渊", "锐意争先", "水"], ["南宫玄", "桀骜不羁", "水"],
		["墨霜", "守礼尊师", "土"],
	]
	var 见底模: Dictionary = {}
	for 条 in 事:
		var d = DiscipleData.new()
		d.姓名 = str(条[0])
		d.性格 = str(条[1])
		d.灵根 = str(条[2])
		# 灌入实测的脏值
		d.立绘类型 = "huo2"
		d.立绘变体 = 0
		# 过一遍存档往返
		d.from_dict(d.to_dict())
		见底模[str(d.立绘类型)] = true
		_log("  %s 性格=%-5s 灵根=%-2s ⇒ 立绘类型=%-5s 立绘变体=%d  头像=%s" % [
			str(d.姓名), str(d.性格), str(d.灵根), str(d.立绘类型), int(d.立绘变体), d.取头像路径()])
		_ck(str(d.立绘类型) == str(d.获取立绘底模()), "%s 立绘类型已按性格重算" % str(d.姓名))
		_ck(int(d.立绘变体) == d.获取灵根序(), "%s 立绘变体已按灵根重算（=%d）" % [str(d.姓名), d.获取灵根序()])
	_ck(见底模.size() >= 3, "5 名弟子治好后底模不再同一张（实际 %d 种）" % 见底模.size())
	_log("")

	_log("--- D. 六底模「男/青年/普通档」头像与立绘均取到真实文件 ---")
	for 模 in DiscipleData.气质底模列表:
		var d3 = DiscipleData.new()
		d3.立绘类型 = str(模)
		d3.性别 = "男"
		d3.年龄段 = "青年"
		d3.立绘变体 = 0
		d3.资质 = "fan_su"
		var 头: String = d3.取头像路径()
		var 立: String = d3.取立绘路径("stand")
		_ck(DiscipleData._立绘文件存在(头) and DiscipleData._立绘文件存在(立),
			"底模=%-5s 头像+立绘均可加载" % str(模))
	_log("")
	_log("--- E. 灵根 → 变体槽位 ---")
	for 根 in ["金", "木", "水", "火", "土", "天灵根"]:
		var d4 = DiscipleData.new()
		d4.灵根 = 根
		_log("  灵根=%-4s → 灵根序=%d" % [根, d4.获取灵根序()])
