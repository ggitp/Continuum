extends Area2D
class_name AreaExit

@onready var sprite := $Sprite2D
var is_open := false

func _ready():
	_close()

func _close():
	is_open = false
	sprite.region_rect.size = Vector2(15,15)

func _open():
	is_open = true
	sprite.region_rect.size = Vector2(31.963,32.693)

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController and is_open:
		GameManager._next_level()
