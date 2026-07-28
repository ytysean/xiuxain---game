extends "res://components/BasePanel.gd"

# ConfirmDialog — 确认弹窗（继承 BasePanel，复用标题栏/内容区结构）。
# content_area 内放 Label(content_label) + HBox[取消 Button / 确认 Button]。
# 红线：只做结构与交互，不触碰玩法/数值。

signal confirmed
signal cancelled

@onready var _content_label: Label = $VBox/ContentArea/dialog_vbox/content_label
@onready var _cancel_button: Button = $VBox/ContentArea/dialog_vbox/button_row/cancel_button
@onready var _confirm_button: Button = $VBox/ContentArea/dialog_vbox/button_row/confirm_button

func _ready() -> void:
	super._ready()
	_content_label.text = ""
	_cancel_button.text = "取消"
	_confirm_button.text = "确认"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_confirm_button.pressed.connect(_on_confirm_pressed)

func show_dialog(title: String, content: String, confirm_text: String = "确认", cancel_text: String = "取消") -> void:
	set_title(title)
	_content_label.text = content
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	open_panel()

func _on_confirm_pressed() -> void:
	confirmed.emit()
	close()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	close()
