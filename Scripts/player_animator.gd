extends Node2D

@export var player : PlayerController
@export var sprite : AnimatedSprite2D


var current_animation: StringName = &""


func _process(_delta: float) -> void:
	_update_facing()
	
	var desired_animation := _get_desired_animation()
	
	if desired_animation != current_animation:
		_play_animation(desired_animation)
	
	
	


func _update_facing() -> void:
	sprite.flip_h = player.facing_direction < 0



func _get_desired_animation() -> StringName:
	# Action animations have priority over movement animations.
	match player.action_state:
		PlayerController.ActionState.ATTACK_1:
			return &"attack_1"
		
		PlayerController.ActionState.ATTACK_3:
			return &"attack_3"
		
		PlayerController.ActionState.AIRBORNE_ATTACK:
			return &"air_attack"
		
		PlayerController.ActionState.AIRBORNE_ATTACK_UP:
			return &"jump_up_attack"
		
		PlayerController.ActionState.AIRBORNE_ATTACK_DOWN:
			return &"jump_down_attack"
		
		PlayerController.ActionState.DASHING_ATTACK:
			return &"dash_attack"
		
		PlayerController.ActionState.GOT_HIT:
			return &"hurt"
		
		PlayerController.ActionState.DEAD:
			return &"dead"
		
	match player.movement_state:
		PlayerController.MovementState.DASHING:
			return &"dash"
		
		PlayerController.MovementState.AIRBORNE:
			if player.velocity.y < 0:
				return &"jump"
			else:
				return &"fall"
		
		PlayerController.MovementState.GROUNDED:
			if abs(player.velocity.x) > 1.0:
				return &"run"
			else:
				return &"idle"

	return &"idle"


func _play_animation(animation_name: StringName) -> void:
	current_animation = animation_name
	
	sprite.offset = _get_animation_offset(animation_name)
	sprite.play(animation_name)


func _get_animation_offset(animation_name: StringName) -> Vector2:
	match animation_name:
		&"jump":
			return Vector2(0, -6)
		
		&"attack_1":
			return Vector2(0.185, 2.52)
		
		&"air_attack_up":
			return Vector2(0, -10)
		
		&"air_attack_down":
			return Vector2(0, -4)
		
		&"idle":
			return Vector2(0.185, 2.52)
		
		&"run":
			return Vector2(0.185, 2.52)
		
		_:
			return Vector2.ZERO












#END
