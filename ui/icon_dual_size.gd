extends Control

# 双尺寸图标组件（零代码切换方案）。
# 同一个图标位置挂两个 TextureRect：
#   - icon_normal：28px/36px/20px 常规版，默认显示
#   - icon_hd：48px 高清版，默认隐藏
# 在不同界面（主城 / 二级界面）直接在编辑器 Inspector 勾选 show_hd 即可切换，无需改脚本。
# HD 资源约定：优先加载 art/icons/hd48/{stem}.png；不存在时回落到 art/icons/hd/{stem}.png。

@export var texture_normal: Texture2D:
	set(v):
		texture_normal = v
		_update_textures()

@export var texture_hd: Texture2D:
	set(v):
		texture_hd = v
		_update_textures()

@export var show_hd: bool = false:
	set(v):
		show_hd = v
		_update_visibility()

var _icon_normal: TextureRect
var _icon_hd: TextureRect

func _ready() -> void:
	_icon_normal = $icon_normal as TextureRect
	_icon_hd = $icon_hd as TextureRect
	_update_textures()
	_update_visibility()

func _update_textures() -> void:
	# 01 屏入口图标源为 art/icons/hd/ 下 ~1200px 金边高清图，实机仅显示 ~67px（约 18 倍缩小）。
	# 缩小场景下 NEAREST 会产生严重锯齿，改用 LINEAR 让金边平滑；放大场景（如二级页高清态）
	# 仍由 STRETCH_KEEP_ASPECT_CENTERED 等比适配，保持清晰不糊。
	if _icon_normal != null:
		_icon_normal.texture = texture_normal
		_icon_normal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _icon_hd != null:
		_icon_hd.texture = texture_hd
		_icon_hd.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _update_visibility() -> void:
	if _icon_normal != null:
		_icon_normal.visible = not show_hd
	if _icon_hd != null:
		_icon_hd.visible = show_hd
