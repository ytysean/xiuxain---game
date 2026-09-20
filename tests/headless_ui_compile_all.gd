extends Node

## UI 全量编译自检（补「四道门 + headless_smoke」的盲区）
##
## 为什么需要它：门1 是 gdtoolkit **parser**（只查语法，不查标识符/函数存在性）；
## headless_smoke 不加载 ui/*.gd；gate_all 其余门也不 load UI 脚本。
## 于是「脚本内静态调用/参数个数错误」这一类 Parse Error 能全门禁 PASS 却让页面空白。
##
## 已捕获的两类真实 bug（2026-09-12）：
##   1. const UITheme = preload("res://ui_theme.gd") 遮蔽同名 autoload 单例
##      → UITheme.<非静态方法>() 被判「对脚本类静态调用」→ 整脚本加载失败（8 文件）
##   2. Container.add_spacer() 缺参（Godot 4 需 begin: bool）→ Parse Error（6 文件 16 处）
##
## 用法：<godot> --headless --path <proj> --scene res://tests/headless_ui_compile_all.tscn
## 判据：末行输出「扫描 ui/*.gd N 个  编译失败 0」，且全程无 Parse Error / Failed to load script。
## 注意：一个脚本报出第一个 Parse Error 后不再报后续错误 → 修完一类必须重跑，迭代到 0 失败。

func _ready() -> void:
	var dir: DirAccess = DirAccess.open("res://ui")
	if dir == null:
		printerr("无法打开 res://ui")
		get_tree().quit()
		return
	var n: int = 0
	var fail: int = 0
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		n += 1
		var s: Variant = load("res://ui/" + f)
		var ok: bool = s != null and (s as Script).can_instantiate()
		if not ok:
			fail += 1
			printerr("COMPILE FAIL: res://ui/" + f)
	prints(">>> 扫描 ui/*.gd %d 个  编译失败 %d" % [n, fail])
	# 退出码必须反映结果：run_headless_chain.py 只看 exit code，
	# 恒 quit() 会让「编译失败 N」被判为通过（2026-09-14 实测 13 页解析失败仍全绿）。
	get_tree().quit(1 if fail > 0 else 0)
