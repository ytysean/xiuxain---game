extends Node
## PH6-G1 · B2 追证探针：pose_bao_男_battle 新路径取件是否受「旧路径墓碑」影响（headless 专用 · 验完即删）
##
## 目的：team-lead 要求确认 res://art/characters/disciples/弟子立绘/pose/pose_bao_男_battle.png
##       能正常 load()（.godot/imported 里同哈希的 *.md5….tmp 墓碑不得影响取件）。
## 铁律：仅 headless；非 headless 立即退出。

const OUT_PATH: String = "res://.workbuddy/tmp/_probe_pose_bao.txt"

const NEWP: String = "res://art/characters/disciples/弟子立绘/pose/pose_bao_男_battle.png"
const OLDP: String = "res://art/characters/disciples/pose_bao_男_battle.png"

var _f: FileAccess = null

func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

func _imp(path: String) -> void:
	var ip: String = path + ".import"
	if not FileAccess.file_exists(ip):
		_L("  .import        = (不存在)")
		return
	var fi: FileAccess = FileAccess.open(ip, FileAccess.READ)
	if fi == null:
		_L("  .import        = (打不开)")
		return
	while not fi.eof_reached():
		var ln: String = fi.get_line().strip_edges()
		if ln.begins_with("path") or ln.begins_with("metadata") or ln.begins_with("vram_texture") \
			or ln.begins_with("compress/mode=") or ln.begins_with("compress/high_quality=") \
			or ln.begins_with("process/size_limit=") or ln.begins_with("source_file=") \
			or ln.begins_with("dest_files="):
			_L("  .import> " + ln)
	fi.close()

func _probe(path: String, label: String) -> void:
	_L("--- %s" % label)
	_L("  path           = " + path)
	var ex: bool = ResourceLoader.exists(path)
	_L("  exists         = " + str(ex))
	if not ex:
		return
	var res: Resource = load(path)
	_L("  load()         = " + (str(res) if res != null else "null"))
	if res == null:
		return
	_L("  class          = " + res.get_class())
	var tex: Texture2D = res as Texture2D
	if tex == null:
		_L("  (非 Texture2D)")
		return
	var w: int = tex.get_width()
	var h: int = tex.get_height()
	_L("  get_size       = %d x %d" % [w, h])
	var img: Image = tex.get_image()
	if img != null:
		_L("  get_format     = %d" % img.get_format())
		_L("  data bytes     = %d" % img.get_data().size())
	_imp(path)

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("[pose_bao] 非 headless 运行，已中止")
		get_tree().quit()
		return
	_f = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	_L("=".repeat(70))
	_L("PH6-G1 B2 追证：pose_bao_男_battle 新/旧路径取件")
	_L("DisplayServer = " + DisplayServer.get_name())
	_L("=".repeat(70))
	_probe(NEWP, "新路径（应可取件，且尺寸/格式非 0）")
	_L("")
	_probe(OLDP, "旧路径（已迁移，预期 exists=false）")
	_L("")
	_L("PROBE_POSE_BAO_DONE")
	if _f != null:
		_f.close()
	get_tree().quit()
