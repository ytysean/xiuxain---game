extends Area2D

signal hit

@export var speed = 400          
var screen_size                  

func _ready():
	screen_size = get_viewport_rect().size
	hide()

func start(pos):
	position = pos
	show()
	$CollisionShape2D.disabled = false

func _process(delta):
	var velocity = Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		velocity.x += 1
	if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A):
		velocity.x -= 1
	if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S):
		velocity.y += 1
	if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W):
		velocity.y -= 1

	if velocity.length() > 0:
		velocity = velocity.normalized() * speed   

	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)  

func _on_body_entered(_body):
	hide()
	hit.emit()
	$CollisionShape2D.set_deferred("disabled", true)