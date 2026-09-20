extends Node
## 图标族「真实画布显示尺寸」全页面扫描探针（纯数值，headless 可用）
##
## 目的：量出 art/icons/ 下每一族图标在**真实 1080 画布**上的最大显示边长，
##       用于反推 process/size_limit（判据：纹理长边 ≈ 最大显示边长 × 2）。
##       运行时读 node.size ⇒ 天然规避「480 设计单位 × UI_SCALE=2.25」的量纲坑。
##
## 用法：
##   godot --headless --path E:/Xiuxian/taixuanzongmenlu res://tests/_probe_iconsize.tscn
## 产物：.scratch_backup/_probe_iconsize.txt

const OUT_PATH: String = "res://.scratch_backup/_probe_iconsize.txt"
const PROBE_ACCOUNT: String = "__probe_iconsize__"
const SETTLE_MAIN: int = 24
const SETTLE_PAGE: int = 10

var _f: FileAccess = null
var _main: Node = null
var _ui: Node = null
var _agg: Dictionary = {}
var _np: Dictionary = {}
var _pages_done: int = 0
var _pages_fail: int = 0

func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _fam_of(res_path: String) -> String:
	var p1: String = "res://art/icons/"
	if res_path.begins_with(p1):
		var rest: String = res_path.substr(p1.length())
		var i1: int = rest.find("/")
		if i1 < 0:
			return "(icons-root)"
		return rest.left(i1)
	var p2: String = "res://art/"
	if res_path.begins_with(p2):
		var r2: String = res_path.substr(p2.length())
		var i2: int = r2.find("/")
		if i2 < 0:
			return "(art-root)"
		var dir1: String = r2.left(i2)
		var r3: String = r2.substr(i2 + 1)
		var i3: int = r3.find("/")
		var dir2: String = r3
		if i3 >= 0:
			dir2 = r3.left(i3)
		return dir1 + "/" + dir2
	return ""

func _walk(root: Node, tag: String) -> void:
	var rows: Array = []
	var hit: int = 0
	for n in root.find_children("*", "TextureRect", true, false):
		var tr: TextureRect = n as TextureRect
		if tr == null:
			continue
		if tr.texture == null:
			continue
		var res_path: String = tr.texture.resource_path
		var fam: String = _fam_of(res_path)
		if fam == "":
			# 无 resource_path（emoji 等运行时 ImageTexture）：按节点名前缀归并
			var key: String = tr.name
			var us: int = key.find("_")
			if us > 0:
				key = key.left(us)
			var de: Dictionary = _np.get(key, {"max": 0.0, "tex": 0.0, "n": 0})
			var dd: float = tr.size.x
			if tr.size.y > dd:
				dd = tr.size.y
			var tts: Vector2 = tr.texture.get_size()
			if dd > float(de["max"]):
				de["max"] = dd
			if tts.x > float(de["tex"]):
				de["tex"] = tts.x
			de["n"] = int(de["n"]) + 1
			_np[key] = de
			continue
		var disp: float = tr.size.x
		if tr.size.y > disp:
			disp = tr.size.y
		if disp <= 0.0:
			disp = tr.custom_minimum_size.x
			if tr.custom_minimum_size.y > disp:
				disp = tr.custom_minimum_size.y
		var ts: Vector2 = tr.texture.get_size()
		var tex_max: float = ts.x
		if ts.y > tex_max:
			tex_max = ts.y
		hit += 1
		var e: Dictionary = _agg.get(fam, {"max": 0.0, "tex": 0.0, "n": 0})
		if disp > float(e["max"]):
			e["max"] = disp
		if tex_max > float(e["tex"]):
			e["tex"] = tex_max
		e["n"] = int(e["n"]) + 1
		_agg[fam] = e
		var ratio: float = -1.0
		if disp > 0.0:
			ratio = tex_max / disp
		var line: String = "    %-10s 显示=%.1f  纹理=%.0f  比值=%.2f  %s" % [fam, disp, tex_max, ratio, res_path.get_file()]
		rows.append(line)
	rows.sort()
	for r in rows:
		_L(r)
	_L("  -- %s: 命中 %d 个带图标 TextureRect" % [tag, hit])

func _ready() -> void:
	_f = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	_L("=".repeat(78))
	_L("图标族真实画布显示尺寸扫描")
	_L("=".repeat(78))
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)

	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(PROBE_ACCOUNT)
	_main._登录_进入({"id": PROBE_ACCOUNT})
	await _settle(SETTLE_MAIN)
	_ui = _main.get("新UI")
	if _ui == null:
		_L(">>>FAIL 新UI 为空，扫描中止")
		_L("PROBE_ICONSIZE_DONE")
		if _f != null:
			_f.close()
		get_tree().quit()
		return

	_L("")
	_L("========== ① 主场景（首页 / 底栏 / 顶栏）==========")
	_walk(get_tree().root, "main")

	_L("")
	_L("========== ② 逐个二级页（按真实入口 id 走路由）==========")
	var scr: Script = _ui.get_script()
	var consts: Dictionary = scr.get_script_constant_map()
	var subs: Dictionary = consts.get("ENTRY_SUB_PAGES", {})
	var ids: Array = subs.keys()
	ids.sort()
	_L("  ENTRY_SUB_PAGES 入口 %d 个" % ids.size())
	for id in ids:
		var ps: PackedScene = subs[id]
		if ps == null:
			_pages_fail += 1
			_L("  [跳过] scene 为空 %s" % str(id))
			continue
		_ui.call("_show_sub_page", str(id), ps)
		await _settle(SETTLE_PAGE)
		_L("  --- %s ---" % str(id))
		_walk(get_tree().root, str(id))
		_ui.call("_close_sub_page")
		await _settle(2)
		_pages_done += 1

	_L("")
	_L("========== ②b 补充：其余 ui/page_*.tscn（占位 id）==========")
	var names: Array = []
	var files: PackedStringArray = DirAccess.get_files_at("res://ui")
	for fn in files:
		if not fn.ends_with(".tscn"):
			continue
		var take: bool = fn.begins_with("page_")
		if fn == "disciple_detail_page.tscn" or fn == "master_detail_page.tscn":
			take = true
		if take:
			names.append(fn)
	names.sort()
	for fn in names:
		var stem: String = fn.get_basename()
		var ps2: PackedScene = load("res://ui/" + fn)
		if ps2 == null:
			_pages_fail += 1
			continue
		_ui.call("_show_sub_page", stem, ps2)
		await _settle(SETTLE_PAGE)
		_L("  --- %s ---" % stem)
		_walk(get_tree().root, stem)
		_ui.call("_close_sub_page")
		await _settle(2)
		_pages_done += 1

	_L("")
	_L("========== ②c 无 resource_path 的贴图（emoji 等运行时栅格化）==========")
	_L("  见 ③ 汇总后的『无路径贴图』表（在遍历时累积）")

	_L("")
	_L("========== ③ 汇总：每族最大显示边长 ==========")
	_L("  %-10s %10s %10s %8s %6s %14s" % ["族", "最大显示", "最大纹理", "比值", "样本", "建议size_limit"])
	var fams: Array = _agg.keys()
	fams.sort()
	for fam in fams:
		var e: Dictionary = _agg[fam]
		var mx: float = float(e["max"])
		var tx: float = float(e["tex"])
		var ratio: float = -1.0
		if mx > 0.0:
			ratio = tx / mx
		var suggest: int = 0
		if mx > 0.0:
			suggest = int(ceil(mx * 2.0))
		_L("  %-10s %10.1f %10.0f %8.2f %6d %14d" % [fam, mx, tx, ratio, int(e["n"]), suggest])
	_L("")
	_L("  ── 无路径贴图（按节点名前缀，最大显示 ≥16 才列出）──")
	_L("  %-16s %10s %10s %8s %6s" % ["节点前缀", "最大显示", "最大纹理", "比值", "样本"])
	var nks: Array = _np.keys()
	nks.sort()
	for k in nks:
		var e2: Dictionary = _np[k]
		var m2: float = float(e2["max"])
		if m2 < 16.0:
			continue
		var t3: float = float(e2["tex"])
		var r2: float = -1.0
		if m2 > 0.0:
			r2 = t3 / m2
		_L("  %-16s %10.1f %10.0f %8.2f %6d" % [str(k), m2, t3, r2, int(e2["n"])])
	_L("")
	_L("  说明：'最大显示' 为真实 1080 画布边长（node.size），已含 UI_SCALE=2.25 折算。")
	_L("        建议 size_limit = 2 × 最大显示边长。")
	_L("        扫描页数 = %d，失败 = %d" % [_pages_done, _pages_fail])
	_L("PROBE_ICONSIZE_DONE")
	if _f != null:
		_f.close()
	get_tree().quit()
