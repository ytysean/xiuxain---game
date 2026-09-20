extends Node

## 用 Godot 自己的解析器全量 load 一遍 .gd，找 gdtoolkit 门抓不到的语法失败。
const LOG := "res://.workbuddy/_gd_load_scan.log"
var lines: Array = []

func _ready() -> void:
	var 全部: Array = []
	_走("res://", 全部)
	全部.sort()
	var bad: Array = []
	for p in 全部:
		var r = load(p)
		if r == null:
			bad.append(p)
	lines.append("扫描 .gd = %d 个，Godot 加载失败 = %d 个" % [全部.size(), bad.size()])
	for b in bad:
		lines.append("  FAIL " + b)
	var f: FileAccess = FileAccess.open(LOG, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
	get_tree().quit(0)

func _走(dir_path: String, out: Array) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		if n.begins_with("."):
			n = d.get_next()
			continue
		var full: String = dir_path.path_join(n)
		if d.current_is_dir():
			_走(full, out)
		elif n.ends_with(".gd"):
			out.append(full)
		n = d.get_next()
	d.list_dir_end()
