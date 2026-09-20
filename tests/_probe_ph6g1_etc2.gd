extends Node
## PH6-G1 · B2 引擎侧「真读」纹理探针 v2（headless 专用 · 临时文件，验完即删）
##
## 目的：
##   1) project.godot 开启 textures/vram_compression/import_etc2_astc=true 后，
##      全量重导的纹理仍能被引擎真实加载，且 get_width()/get_height() 正确；
##   2) ★新增：对「四个显示档」各取一张，逐张实测 格式(get_format) + 显存字节，
##      以钉死 Android 实际加载哪个变体、格式为何、显存多少。
##   本探针只认引擎返回值，不采信任何脚本自报尺寸。
##
## 铁律：只在 headless 下运行；若检测到非 headless，立即退出，绝不弹可见窗口。
## 用法：godot --headless --path E:/Xiuxian/taixuanzongmenlu res://tests/_probe_ph6g1_etc2.tscn
## 产物：res://.workbuddy/tmp/_b2_etc2.txt（同时 print 到 stdout）

const OUT_PATH: String = "res://.workbuddy/tmp/_b2_etc2.txt"

# 前 4 项 = 四个显示档（显存实测重点）；其余为原回归样本，保持存在性校验（原 8 项一个不删，仅换死路径）。
const SAMPLES: Array = [
	# —— 显示档 1/4：36px 图标 ——
	"res://art/icons/disciple/xingge_kuangao_36.png",
	# —— 显示档 2/4：512px 图标 ——
	"res://art/icons/equipment/slot_yipao_dao_512.png",
	# —— 显示档 3/4：全屏背景（原 SAMPLES[1] 保留） ——
	"res://art/backgrounds/home_bg_season_autumn.png",
	# —— 显示档 4/4：立绘 stand ——
	"res://art/characters/disciples/弟子立绘/depth/depth_bao_男_stand.png",
	# —— 以下为原回归样本（保留） ——
	"res://art/avatar_frames/lv1_素铜.png",
	"res://art/characters/auctioneer/auctioneer_jin_1024.png",
	"res://art/icons/array/array_hushan_36.png",
	"res://art/scene_anim/danfang_sheet.png",
	"res://art/splash/boot_splash.png",
	"res://art/ui/entry_fragment_chest_36.png",
	# 不再枚举 .gdignore 子树取样：旧值 res://art/_archive_avatar_legacy_20260916/depth_avatar/depth_bao_女_battle_avatar_128.png
	# 已随归档落入 .gdignore ⇒ ResourceLoader.exists()=false，会误报 FAIL。改用 live 路径（_probe_avatar_ab.gd 同款）。
	"res://art/characters/disciples/弟子立绘/depth/depth_bao_男_halfbody.png",
]

# 格式名（只用稳定的 FORMAT_* 常量，杜绝 keys() 兼容性风险；未知回退 #n）
const FMT_NAMES: Dictionary = {
	Image.FORMAT_L8: "FORMAT_L8", Image.FORMAT_LA8: "FORMAT_LA8",
	Image.FORMAT_R8: "FORMAT_R8", Image.FORMAT_RG8: "FORMAT_RG8",
	Image.FORMAT_RGB8: "FORMAT_RGB8", Image.FORMAT_RGBA8: "FORMAT_RGBA8",
	Image.FORMAT_RGBA4444: "FORMAT_RGBA4444", Image.FORMAT_RGB565: "FORMAT_RGB565",
	Image.FORMAT_RF: "FORMAT_RF", Image.FORMAT_RGF: "FORMAT_RGF",
	Image.FORMAT_RGBF: "FORMAT_RGBF", Image.FORMAT_RGBAF: "FORMAT_RGBAF",
	Image.FORMAT_RH: "FORMAT_RH", Image.FORMAT_RGH: "FORMAT_RGH",
	Image.FORMAT_RGBH: "FORMAT_RGBH", Image.FORMAT_RGBAH: "FORMAT_RGBAH",
	Image.FORMAT_RGBE9995: "FORMAT_RGBE9995",
	Image.FORMAT_DXT1: "FORMAT_DXT1(BC1)", Image.FORMAT_DXT3: "FORMAT_DXT3(BC2)",
	Image.FORMAT_DXT5: "FORMAT_DXT5(BC3)",
	Image.FORMAT_RGTC_R: "FORMAT_RGTC_R", Image.FORMAT_RGTC_RG: "FORMAT_RGTC_RG",
	Image.FORMAT_BPTC_RGBA: "FORMAT_BPTC_RGBA(BC7)",
	Image.FORMAT_BPTC_RGBF: "FORMAT_BPTC_RGBF", Image.FORMAT_BPTC_RGBFU: "FORMAT_BPTC_RGBFU",
	Image.FORMAT_ETC: "FORMAT_ETC",
	Image.FORMAT_ETC2_R11: "FORMAT_ETC2_R11", Image.FORMAT_ETC2_R11S: "FORMAT_ETC2_R11S",
	Image.FORMAT_ETC2_RG11: "FORMAT_ETC2_RG11", Image.FORMAT_ETC2_RG11S: "FORMAT_ETC2_RG11S",
	Image.FORMAT_ETC2_RGB8: "FORMAT_ETC2_RGB8", Image.FORMAT_ETC2_RGBA8: "FORMAT_ETC2_RGBA8",
	Image.FORMAT_ETC2_RGB8A1: "FORMAT_ETC2_RGB8A1",
	Image.FORMAT_ASTC_4x4: "FORMAT_ASTC_4x4", Image.FORMAT_ASTC_4x4_HDR: "FORMAT_ASTC_4x4_HDR",
	Image.FORMAT_ASTC_8x8: "FORMAT_ASTC_8x8", Image.FORMAT_ASTC_8x8_HDR: "FORMAT_ASTC_8x8_HDR",
}

var _f: FileAccess = null

func _L(s: String) -> void:
	print(s)
	if _f != null:
		_f.store_line(s)
		_f.flush()

func _fmt_name(f: int) -> String:
	return str(FMT_NAMES.get(f, "FORMAT_#%d" % f))

# bits per pixel（按格式判定），用于 w*h*bits/8 模型值；未知返回 -1
func _bits(f: int) -> float:
	match f:
		Image.FORMAT_L8, Image.FORMAT_R8, Image.FORMAT_ETC2_R11, Image.FORMAT_ETC2_R11S, \
		Image.FORMAT_ETC2_RGB8, Image.FORMAT_ETC2_RGB8A1, Image.FORMAT_DXT1, Image.FORMAT_ETC, \
		Image.FORMAT_RGTC_R, Image.FORMAT_ASTC_8x8, Image.FORMAT_ASTC_8x8_HDR:
			return 4.0
		Image.FORMAT_LA8, Image.FORMAT_RG8, Image.FORMAT_RGBA4444, Image.FORMAT_RGB565, \
		Image.FORMAT_RH, Image.FORMAT_RGTC_RG, Image.FORMAT_DXT3, Image.FORMAT_DXT5, \
		Image.FORMAT_ETC2_RG11, Image.FORMAT_ETC2_RG11S, Image.FORMAT_ETC2_RGBA8, \
		Image.FORMAT_BPTC_RGBA, Image.FORMAT_BPTC_RGBF, Image.FORMAT_BPTC_RGBFU, \
		Image.FORMAT_ASTC_4x4, Image.FORMAT_ASTC_4x4_HDR:
			return 8.0
		Image.FORMAT_RGB8:
			return 24.0
		Image.FORMAT_RGBA8, Image.FORMAT_RF, Image.FORMAT_RGF, Image.FORMAT_RGBE9995:
			return 32.0
		Image.FORMAT_RGBF:
			return 96.0
		Image.FORMAT_RGBAF:
			return 128.0
		_:
			return -1.0

func _import_field(imp_path: String, key: String) -> String:
	var fi: FileAccess = FileAccess.open(imp_path, FileAccess.READ)
	if fi == null:
		return "(打不开)"
	var out: String = "(缺)"
	while not fi.eof_reached():
		var ln: String = fi.get_line()
		if ln.begins_with(key):
			out = ln.strip_edges()
			break
	fi.close()
	return out

func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("[B2] 非 headless 运行，已中止（绝不弹可见窗口）")
		get_tree().quit()
		return
	_f = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	_L("=".repeat(78))
	_L("PH6-G1 B2 引擎侧真读纹理探针 v2（含格式/显存实测）")
	_L("DisplayServer = " + DisplayServer.get_name())
	_L("=".repeat(78))
	var ok: int = 0
	var bad: int = 0
	var i: int = 0
	for p in SAMPLES:
		i += 1
		var path: String = str(p)
		_L("")
		_L("--- [%d] %s" % [i, path])
		if not ResourceLoader.exists(path):
			bad += 1
			_L("  >>>FAIL ResourceLoader.exists=false")
			continue
		var res: Resource = load(path)
		if res == null:
			bad += 1
			_L("  >>>FAIL load() 返回 null")
			continue
		var tex: Texture2D = res as Texture2D
		if tex == null:
			bad += 1
			_L("  >>>FAIL 不是 Texture2D，实际类=" + res.get_class())
			continue
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		_L("  class         = " + tex.get_class())
		_L("  get_size      = %d x %d" % [w, h])
		var img: Image = tex.get_image()
		if img != null:
			var f: int = img.get_format()
			var data_sz: int = img.get_data().size()
			var bpp: float = _bits(f)
			_L("  get_format    = %s" % _fmt_name(f))
			_L("  data bytes    = %d  （引擎实际驻留/压缩载荷）" % data_sz)
			if bpp > 0.0:
				_L("  VRAM(model)   = %d  （w*h*%.0fbpp/8）" % [int(w * h * bpp / 8.0), bpp])
			else:
				_L("  VRAM(model)   = (格式未知，仅看 data bytes)")
		else:
			_L("  get_image     = null")
		var raw_len: int = -1
		var fr: FileAccess = FileAccess.open(path, FileAccess.READ)
		if fr != null:
			raw_len = fr.get_length()
			fr.close()
		_L("  源文件字节     = %d" % raw_len)
		# 源图原始边长（离线解码，失败则 -）
		var src: Image = Image.new()
		if src.load(path) == OK:
			_L("  源图边长       = %d x %d" % [src.get_width(), src.get_height()])
		else:
			_L("  源图边长       = (load 失败)")
		var imp_path: String = path + ".import"
		if FileAccess.file_exists(imp_path):
			_L("  " + _import_field(imp_path, "compress/mode="))
			_L("  " + _import_field(imp_path, "compress/high_quality="))
			_L("  " + _import_field(imp_path, "process/size_limit="))
			_L("  " + _import_field(imp_path, "path.etc2="))
			_L("  " + _import_field(imp_path, "path.s3tc="))
		else:
			_L("  .import       = (文件不存在)")
		if w > 0 and h > 0:
			ok += 1
		else:
			bad += 1
			_L("  >>>FAIL 尺寸为 0")
	_L("")
	_L("=".repeat(78))
	_L("合计: %d 样本, ok=%d, bad=%d" % [SAMPLES.size(), ok, bad])
	_L("PROBE_PH6G1_ETC2_DONE")
	if _f != null:
		_f.close()
	get_tree().quit()
