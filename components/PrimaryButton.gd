extends Button
class_name PrimaryButton

# PrimaryButton — 主按钮组件（统一样式，杜绝逐页手写 apply_*）。
# 用法：场景里放一个 Button，把本脚本挂上即可；代码创建时 new 后 set_script(load(...))。
# 红线：只做样式自应用，不触碰玩法/数值；取色字号由 ui_theme.gd(UITheme Autoload) 提供。

func _ready() -> void:
	UITheme.apply_primary_button_style(self)
	# 主按钮默认高 64（BTN_H_PRIMARY）——仅当高度未显式设置时兜底，
	# 避免覆盖页面自定义高度（如 SIZE_SM=48 或顶栏图标 40px），保证迁移行为一致。
	if custom_minimum_size.y <= 0:
		custom_minimum_size.y = UITheme.BTN_H_PRIMARY
	# 文本居中（主题未强制时兜底）
	alignment = HORIZONTAL_ALIGNMENT_CENTER
