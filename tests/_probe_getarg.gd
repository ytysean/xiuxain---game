extends Node
## 最小复现：Godot 4.7 下 Object.get() 只接受 1 个参数。
##   · 接收者【静态类型化】为 Item → 编译期 Parse Error（“Too many arguments for get()”）。
##   · 接收者【Variant/未标注】(如 game_state.gd 符箓取器 `var it = _取护身符(...)`) → 运行期 SCRIPT ERROR。
## 结论：Dictionary.get(k,default) 合法；Object.get(k,default) 非法。
## 目的：证明 game_state.gd:8383/8390/8397 的 it.get("符词条", []) 是【既有】缺陷，与 PH6-C1 无关。
## 注：运行期 Invalid-call 会中止【当前函数】（返回 null），调用者继续 → 故把风险调用隔离在子函数里。

func _ready() -> void:
	_尝试2参()
	var d: Dictionary = {"k": 1}
	print("D Dict 2-arg .get(\"k\", 0) =", d.get("k", 0))
	print(">>>GETARG_DONE")
	get_tree().quit()


func _尝试2参() -> void:
	var i: Variant = Item.new()
	i.名称 = "探针符"
	print("A 1-arg .get(\"名称\") =", i.get("名称"))
	print("B 2-arg .get(\"名称\", \"\") =", i.get("名称", ""))     # ← 本行运行期 SCRIPT ERROR，_尝试2参 就此中止
	print("C 2-arg .get(\"符词条\", []) =", i.get("符词条", []))   # ← 永不执行（证明中止）
