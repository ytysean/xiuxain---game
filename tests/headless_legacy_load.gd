extends Node

# 旧档兼容加载自检：复现「缺 '灵兽管理系统' 等已拆分系统嵌套键的老档」加载路径。
# 背景：load_game 曾在该键缺失时用
#       `灵兽管理系统.灵兽库存 = data.get("灵兽库存") if ... else []`
#       直接重赋 Array[Beast]（typed array 拒绝原始 Array），运行期抛
#       "Invalid assignment of property or key ... on a base object of type 'BeastManagementSystem'"，
#       导致读档中止、进不去游戏。本 harness 专门覆盖该 else 分支。
# 运行：MSYS_NO_PATHCONV=1 <godot> --headless --path <proj> --scene res://tests/headless_legacy_load.tscn
# 判据：末行出现 >>>LEGACY_LOAD_ALL_DONE，且全程无 SCRIPT ERROR / FATAL；灵兽库存条数与剥离前 lingshou_kucun 一致。

const 新系统键: Array = [
	"灵兽管理系统", "成就系统", "藏书阁系统", "阵法管理系统", "坐骑系统",
	"碎片宝箱系统", "邮件系统", "宗门科技系统", "玄榜系统", "炼丹炼器系统",
	"功法管理系统", "傀儡系统", "弟子突破系统",
]

func _ready() -> void:
	prints("=== 旧档兼容加载自检启动 ===")
	if Game == null:
		printerr("FATAL: Game 单例缺失")
		get_tree().quit()
		return

	Game.当前账号id = "legacy_test"
	if Game.弟子列表.is_empty():
		Game.初始建宗()
	# 塞一只灵兽，验证旧键 lingshou_kucun 回填不丢兽
	var b := Beast.new()
	Game.灵兽管理系统.灵兽库存.append(b)
	prints(">>> 造档前 灵兽库存=", Game.灵兽管理系统.灵兽库存.size())
	Game.save_game()
	var p: String = Game.账号存档路径("legacy_test")
	prints(">>> 新档已写:", p, " exists=", FileAccess.file_exists(p))

	# 读回 JSON，剥离所有「已拆分系统」嵌套键，模拟老档（保留 lingshou_kucun 扁平键）
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		printerr(">>>FAIL 存档打不开")
		get_tree().quit()
		return
	var txt: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		printerr(">>>FAIL 存档解析失败")
		get_tree().quit()
		return
	var 剥离数: int = 0
	for k in 新系统键:
		if data.has(k):
			data.erase(k)
			剥离数 += 1
	var wk := FileAccess.open(p, FileAccess.WRITE)
	wk.store_string(JSON.stringify(data))
	wk.close()
	var 库里条数: int = (data.get("lingshou_kucun") if "lingshou_kucun" in data else []).size()
	prints(">>> 已剥离新系统嵌套键", 剥离数, "个（模拟老档）；lingshou_kucun 条数=", 库里条数)

	# 关键：加载。修复前此处会因 Array[Beast] 直接重赋而报错中止
	Game.load_game("legacy_test")
	prints(">>> 老档加载完成 灵兽库存=", Game.灵兽管理系统.灵兽库存.size(),
		" 兑换队列=", Game.灵兽管理系统.灵兽兑换队列.size())
	if Game.灵兽管理系统.灵兽库存.size() != 库里条数:
		printerr(">>>FAIL 灵兽库存回填条数不符：期望 ", 库里条数, " 实得 ",
			Game.灵兽管理系统.灵兽库存.size())
		get_tree().quit()
		return
	prints(">>>LEGACY_LOAD_ALL_DONE（如上方无 SCRIPT ERROR 则通过）")
	get_tree().quit()
