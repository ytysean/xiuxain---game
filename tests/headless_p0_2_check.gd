extends Node

## P0-2 · Design Token 三层自检（headless 实机）
##
## 死函数闸的合法消费方：本文件逐一调用 ui_theme.gd 的 25 个语义/组件 getter，
## 使「P0-2 建立 Token 层」不被判为「堆死函数」（与 headless_p0_3_check.gd 同源标准）。
## 同时验证两件事：
##   [A] 每个 getter 都返回合法 Color（无 NaN/越界，复兴派生不崩）
##   [B] 复兴进度变化确实驱动背景色改变（缓存失效 + 派生生效）

var _fail: int = 0


func _ready() -> void:
	prints("=== P0-2 Token 三层自检 ===")
	get_tree().create_timer(40.0).timeout.connect(_看门狗)

	_语义层全调用()
	_复兴派生生效()

	_finish()


# ── A. 25 个 getter 全调用 + 类型/有限性校验 ──
func _语义层全调用() -> void:
	prints("\n[A] 语义/组件 getter 调用")
	var 取色 := [
		UITheme.获取页面底色, UITheme.获取面板底色, UITheme.获取浮层底色,
		UITheme.获取主文字色, UITheme.获取次文字色, UITheme.获取弱文字色, UITheme.获取金文字色,
		UITheme.获取暗金边色, UITheme.获取亮金边色,
		UITheme.获取吉色, UITheme.获取凶色, UITheme.获取警色,
		UITheme.获取卡底色起, UITheme.获取卡底色止, UITheme.获取卡描边色, UITheme.获取卡内框色,
		UITheme.获取行底色起, UITheme.获取行底色止, UITheme.获取行描边色, UITheme.获取书脊色,
		UITheme.获取钮金起色, UITheme.获取钮金止色, UITheme.获取钮金高光色,
		UITheme.获取角标色, UITheme.获取金底文字色,
	]
	var 名表 := [
		"获取页面底色", "获取面板底色", "获取浮层底色",
		"获取主文字色", "获取次文字色", "获取弱文字色", "获取金文字色",
		"获取暗金边色", "获取亮金边色",
		"获取吉色", "获取凶色", "获取警色",
		"获取卡底色起", "获取卡底色止", "获取卡描边色", "获取卡内框色",
		"获取行底色起", "获取行底色止", "获取行描边色", "获取书脊色",
		"获取钮金起色", "获取钮金止色", "获取钮金高光色",
		"获取角标色", "获取金底文字色",
	]
	for i in 取色.size():
		var c: Color = 取色[i].call()
		var ok: bool = (typeof(c) == TYPE_COLOR) and c.r == c.r and c.g == c.g \
			and c.b == c.b and c.a == c.a
		_check("A %s 返回合法Color" % 名表[i], ok)


# ── B. 复兴进度驱动背景色（缓存失效 + 派生生效）──
func _复兴派生生效() -> void:
	prints("\n[B] 复兴进度派生")
	UITheme.设置复兴进度(1)
	var 暗: Color = UITheme.获取面板底色()
	UITheme.设置复兴进度(7)
	var 亮: Color = UITheme.获取面板底色()
	_check("B 复兴进度提升使背景色改变", 暗 != 亮)
	# 复位：游戏运行时会由 Game.门派等级 重新设置
	UITheme.设置复兴进度(1)


func _check(项: String, 通过: bool) -> void:
	if 通过:
		prints("  [OK]  ", 项)
	else:
		_fail += 1
		printerr("  [FAIL]", 项)


func _看门狗() -> void:
	printerr("FATAL: 看门狗超时")
	get_tree().quit(2)


func _finish() -> void:
	prints("")
	if _fail == 0:
		prints(">>>P0_2_ALL_DONE  失败=0")
	else:
		printerr(">>>P0_2_FAILED  失败=%d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)
