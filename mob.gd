extends RigidBody2D

func _ready():
	var colors = [
		Color(0.9, 0.3, 0.3),
		Color(0.3, 0.5, 0.9),
		Color(0.9, 0.8, 0.3),
		Color(0.6, 0.9, 0.4),
	]
	$Polygon2D.color = colors[randi() % colors.size()]
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_screen_exited)

func _on_screen_exited():
	queue_free()