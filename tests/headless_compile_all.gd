extends Node

## 全项目 GDScript 编译自检（Godot 原生解析器 —— 补 gdtoolkit 的解析盲区）
##
## ── 为什么需要它（2026-09-12 实证）──────────────────────────────────
## `gdtoolkit_check.py`（门1）用的是 **gdtoolkit 的 tree-sitter 语法**，与 Godot 原生
## GDScript 解析器**不等价**。实测：`fishing_system.gd` 里有 `There is already a variable
## named "增经验" declared in this scope`（同作用域重复声明）—— **gdtoolkit 判 PASS，
## Godot 判 Parse Error**。这类错误会让脚本加载失败 → 级联 game_state.gd 加载失败 →
## Game autoload 起不来 → **整个游戏白屏**。
##
## 而 `headless_ui_compile_all` 只扫 `res://ui/**`；`headless_smoke` 不 load 非 UI 脚本。
## ⇒ 根目录 / components / 各系统脚本的 Parse Error 以前无任何防线。
##
## ── 分工 ──────────────────────────────────────────────────────────
##   headless_ui_compile_all  res://ui/**（页面层，快）
##   本脚本（compile_all）     res://** 除 tests/ 外全部 .gd（含根目录系统脚本），唯一全量防线
##                            （跳过 addons/tests/.godot/.workbuddy/Godot/Lib/archive_legacy；
##                              实测 175 个；tests/ 由 gdtoolkit 门覆盖，且 harness 自身跑起来即自证）
##
## 运行：MSYS_NO_PATHCONV=1 <godot> --headless --path <proj> --scene res://tests/headless_compile_all.tscn
## 判据：末行出现「>>> 全项目 .gd N 个  编译失败 0」，且无 COMPILE FAIL。
##
## 注意 1：`load()` 对含 Parse Error 的脚本**不返回 null**（返回不可实例化的 GDScript），
##         故必须用 `(s as Script).can_instantiate()` 判定，不能只判 null。
## 注意 2：递归取子目录必须用 `DirAccess.get_directories()`。写成 Godot 3 的 `get_dirs()`
##         会 SCRIPT ERROR 且**递归静默中断**——只扫到根目录一层（曾误报「83 个全过」）。

const 跳过目录 := ["addons", "tests", ".godot", ".workbuddy", "Godot", "Lib", "archive_legacy"]


func _ready() -> void:
	prints("=== 全项目 GDScript 编译自检 ===")
	var 清单: Array[String] = []
	_收集("res://", 清单)
	清单.sort()

	var 失败: Array[String] = []
	for p in 清单:
		var s: Variant = load(p)
		var ok: bool = s != null and (s as Script).can_instantiate()
		if not ok:
			失败.append(p)
			printerr("COMPILE FAIL: " + p)

	prints(">>> 全项目 .gd %d 个  编译失败 %d" % [清单.size(), 失败.size()])
	if 失败.size() > 0:
		for p in 失败:
			prints("   FAIL ", p)
	# 退出码必须反映结果：否则 run_headless_chain.py（只看 exit code）会把「编译失败 N」
	# 误判为 exit=0 通过 —— 2026-09-14 实测 13 个 UI 页解析失败却全程「绿」。
	get_tree().quit(1 if 失败.size() > 0 else 0)


func _收集(目录: String, 结果: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(目录)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			结果.append(目录.path_join(f))
	for sub in d.get_directories():
		if 跳过目录.has(sub) or sub.begins_with("."):
			continue
		_收集(目录.path_join(sub), 结果)
