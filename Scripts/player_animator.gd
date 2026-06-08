extends Node2D

@export var player_controller : PlayerController
@export var animation_player : AnimationPlayer
@export var sprite : Sprite2D

func _process(delta: float) -> void:
	#flips the character sprite based on direction
	if player_controller.direction == 1:
		sprite.flip_h = false
	elif player_controller.direction == -1:
		sprite.flip_h = true
	
	#plays running animation
	if abs(player_controller.velocity.x) > 0.0:
		animation_player.play("run")
	else:
		animation_player.play("idle")
	
	#plays jumping animation
	if player_controller.velocity.y < 0.0:
		animation_player.play("jump")
	elif player_controller.velocity.y > 0.0:
		animation_player.play("falling")
	
	
	
	
	
	
