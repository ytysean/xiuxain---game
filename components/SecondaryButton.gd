extends Button
class_name SecondaryButton

# SecondaryButton — 次按钮组件（统一样式，杜绝逐页手写 apply_*）。
# 用法同 PrimaryButton；高度默认 48（BTN_H_SECONDARY）。

func _ready() -> void:
	UITheme.apply_secondary_button_style(self)
	# 次按钮默认高 48（BTN_H_SECONDARY）——仅当高度未显式设置时兜底，
	# 避免覆盖页面自定义高度（如顶栏图标 40px）。
	if custom_minimum_size.y <= 0:
		custom_minimum_size.y = UITheme.BTN_H_SECONDARY
	alignment = HORIZONTAL_ALIGNMENT_CENTER
