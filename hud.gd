extends CanvasLayer

signal start_game   

func show_message(text):
	$MessageLabel.text = text
	$MessageLabel.show()
	$MessageTimer.start()

func show_game_over():
	show_message("游戏结束")
	await $MessageTimer.timeout
	$StartButton.show()
	$MessageLabel.text = "Dodge the Creeps!\n点开始重生"
	$MessageLabel.show()

func update_score(value):
	$ScoreLabel.text = str(value)

func _on_start_button_pressed():
	$StartButton.hide()
	$MessageLabel.hide()
	start_game.emit()

func _on_message_timer_timeout():
	$MessageLabel.hide()