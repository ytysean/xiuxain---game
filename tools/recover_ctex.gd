# tools/recover_ctex.gd
# 从 .godot/imported 的 ctex 缓存恢复丢失的源 PNG。
# 背景：art/ui/buttons/ 目录丢失（git 里从未提交），但 Godot 导入缓存里仍保留压缩纹理。
# 用法（项目根目录执行，需要 Godot 4.3+）：
#   godot --headless --script tools/recover_ctex.gd
# 产物：_recovered/*.png，确认无误后手工拷回 art/ui/buttons/ 等目录。
@tool
extends SceneTree

# 需要恢复的 stem 列表（不含扩展名）。只恢复这些，避免把整个 imported 目录倒出来。
const TARGETS: Array[String] = [
	# 主/次/返回按钮
	"btn_primary_normal", "btn_primary_hover", "btn_primary_press",
	"btn_secondary_normal", "btn_secondary_hover", "btn_secondary_press",
	"btn_back_normal", "btn_back_press",
	# 确认框
	"confirm_ok", "confirm_cancel", "confirm_close", "confirm_danger",
	# 筛选 / 子标签
	"filter_normal", "filter_selected",
	"subtab_normal", "subtab_selected",
	# 弟子操作按钮
	"op_renming", "op_bamian", "op_tiaopei", "op_shenhe", "op_jilu", "op_auto",
	# 玩法按钮
	"play_lj", "play_lz", "play_tp", "play_zm",
	# 炼制按钮
	"refine_start", "refine_speed", "refine_recipe",
]

const SRC_DIR := "res://.godot/imported"
const OUT_DIR := "res://_recovered"


func _init() -> void:
	var d := DirAccess.open(SRC_DIR)
	if d == null:
		push_error("无法打开 %s（请确认在项目根目录执行）" % SRC_DIR)
		quit(1)
		return

	# 建索引：stem -> [ctex 文件名]，同一 stem 可能有多份（不同尺寸/变体），取体积最大的
	var all := d.get_files()
	var idx := {}
	for f in all:
		if not f.ends_with(".ctex"):
			continue
		var stem := f
		if stem.find(".png-") >= 0:
			stem = stem.split(".png-")[0]
		elif stem.find(".jpg-") >= 0:
			stem = stem.split(".jpg-")[0]
		else:
			continue
		var full: String = SRC_DIR
		full += "/" + f
		var sz := FileAccess.get_size(full)
		if not idx.has(stem):
			idx[stem] = []
		idx[stem].append({"path": full, "size": sz})

	var err := DirAccess.make_dir_recursive_absolute(OUT_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("无法创建输出目录 %s (err=%d)" % [OUT_DIR, err])
		quit(1)
		return

	var ok := 0
	var miss := []
	for t in TARGETS:
		if not idx.has(t):
			miss.append(t)
			continue
		var best := {}
		var best_size := -1
		for e in idx[t]:
			if int(e["size"]) > best_size:
				best_size = int(e["size"])
				best = e
		var tex = ResourceLoader.load(best["path"], "CompressedTexture2D")
		if tex == null:
			miss.append(t + "(load失败)")
			continue
		var img: Image = tex.get_image()
		if img == null:
			miss.append(t + "(get_image失败)")
			continue
		var out: String = OUT_DIR + "/" + t + ".png"
		var e2 := img.save_png(out)
		if e2 != OK:
			miss.append(t + "(save失败)")
			continue
		ok += 1
		print("OK  %-24s %dx%d  -> %s" % [t, img.get_width(), img.get_height(), out])

	print("")
	print("恢复成功 %d / %d" % [ok, TARGETS.size()])
	if miss.size() > 0:
		print("未恢复(%d)：%s" % [miss.size(), ", ".join(miss)])
	quit(0)
