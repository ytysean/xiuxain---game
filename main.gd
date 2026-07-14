extends Node2D

@export var mob_scene: PackedScene   

@onready var player = $Player
@onready var hud = $HUD
@onready var mob_timer = $MobTimer
@onready var score_timer = $ScoreTimer
@onready var start_timer = $StartTimer

var score

func _ready():
	player.hit.connect(game_over)
	hud.start_game.connect(new_game)
	mob_timer.timeout.connect(_on_mob_timer_timeout)
	score_timer.timeout.connect(_on_score_timer_timeout)
	start_timer.timeout.connect(_on_start_timer_timeout)

func game_over():
	score_timer.stop()
	mob_timer.stop()
	hud.show_game_over()

func new_game():
	score = 0
	player.start(Vector2(240, 640))   
	start_timer.start()               
	hud.update_score(score)
	hud.show_message("准备!")
	get_tree().call_group("mobs", "queue_free")  

func _on_mob_timer_timeout():
	var mob = mob_scene.instantiate()
	mob.position = Vector2(randf_range(40, 440), -20)
	var angle = randf_range(PI / 8, 7 * PI / 8)         
	var velocity = Vector2(randf_range(120, 220), 0).rotated(angle)
	mob.linear_velocity = velocity
	mob.rotation = velocity.angle()
	add_child(mob)

func _on_score_timer_timeout():
	score += 1
	hud.update_score(score)

func _on_start_timer_timeout():
	mob_timer.start()
	score_timer.start()