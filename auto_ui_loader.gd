# =============================================================================
# auto_ui_loader.gd —— 自动管线产物加载器
# -----------------------------------------------------------------------------
# 由 tools/auto_ui/auto_asset_pipeline.py 生成的资源/场景/清单，可用本脚本直接
# 接入游戏运行态，实现「art → 0 干预 → 游戏界面/内容」闭环。
#
# 用法（在 main.gd 或任意脚本）：
#   const AutoUI = preload("res://auto_ui_loader.gd")
#   var manifest = AutoUI.load_manifest()
#   var menu = AutoUI.instance_scene(manifest["scenes"]["main_menu"])
#   if menu: add_child(menu)
#
# 注意：运行时用 load() + ResourceLoader.exists() 守卫，不会在解析期预加载缺失资源，
# 因此即便 auto_ui 产物尚未生成也不会导致游戏启动失败。
# =============================================================================

class_name AutoUI


static func manifest_path() -> String:
	return "res://config/auto_ui_manifest.json"


# 读取自动化管线生成的清单；失败返回 {}（不抛错）。
static func load_manifest() -> Dictionary:
	var p: String = manifest_path()
	if not FileAccess.file_exists(p):
		push_error("AutoUI: 清单不存在 %s（请先运行 tools/auto_ui/auto_asset_pipeline.py）" % p)
		return {}
	var txt: String = FileAccess.get_file_as_string(p)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("AutoUI: 清单 JSON 解析失败 %s" % p)
		return {}
	return parsed


# 按 res:// 路径实例化一个场景；资源缺失或不存在时返回 null（不抛错）。
static func instance_scene(scene_res: String) -> Node:
	if scene_res == "" or not ResourceLoader.exists(scene_res):
		push_error("AutoUI: 场景不存在 %s" % scene_res)
		return null
	var scn = load(scene_res)
	if scn == null:
		return null
	return scn.instantiate()


# 取某角色分类下的第一张可用资源（如 background / portrait / button …）。
static func first_asset(manifest: Dictionary, role: String) -> String:
	var arr: Array = manifest.get("assets", {}).get(role, [])
	if arr.size() > 0:
		return str(arr[0])
	return ""


# 把自动管线生成的场景作为「覆盖层」实例化并显示（首屏验证 / 弹窗式 UI 用）。
# parent 必须是已在场景树中的 Node（通常是 main.gd 自身）；返回 CanvasLayer，失败返回 null。
# 设计画布会等比缩放并居中到当前视口（分辨率无关；480×854 与 1080×1920 均正确）。
static func show_as_overlay(scene_res: String, parent: Node) -> CanvasLayer:
	if scene_res == "" or not ResourceLoader.exists(scene_res):
		push_error("AutoUI: 场景不存在 %s" % scene_res)
		return null
	var scn = load(scene_res)
	if scn == null:
		return null
	var root: Control = scn.instantiate()          # 设计画布（768×1344，来自 .tscn offset）
	var wrap: Control = Control.new()               # 空包装：承载缩放/居中，避免改动场景根的锚点布局
	wrap.add_child(root)
	var layer := CanvasLayer.new()
	layer.layer = 100                              # 置于游戏 UI 与 FTUE 标题之上
	layer.add_child(wrap)
	parent.add_child(layer)                        # 必须先入树，root.get_viewport() 才可用
	_fit_to_viewport(wrap, root)
	return layer


# 设计画布等比缩放并居中到视口（作用在 wrap 包装层；场景根保持锚点布局不动）。
static func _fit_to_viewport(wrap: Control, root: Control) -> void:
	var vp: Viewport = root.get_viewport()
	if vp == null:
		return
	var vsize: Vector2 = vp.size                   # 实际视口尺寸（受 stretch/窗口影响）
	var dsize: Vector2 = root.size                 # 设计画布尺寸（来自 .tscn 的 offset 宽高）
	if dsize.x <= 0 or dsize.y <= 0:
		return
	var s: float = min(vsize.x / dsize.x, vsize.y / dsize.y)
	wrap.scale = Vector2(s, s)
	wrap.position = Vector2((vsize.x - dsize.x * s) * 0.5, (vsize.y - dsize.y * s) * 0.5)
