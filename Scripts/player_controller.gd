extends CharacterBody2D
class_name PlayerController

@export var speed := 10.0
@export var jump_power := 10.0
@export var camera : Camera2D

var speed_multiplier := 30.0
var movement_while_attacking_multiplier := 0.0
var movement_while_not_attacking_multiplier := 30.0
var is_attacking := false
var jump_multiplier := -30.0
var direction := 0
var speed_tween : Tween

#character sheet slice 128 down, 240 side
#const SPEED = 300.0
#const JUMP_VELOCITY = -400.0


#func _ready() -> void:
	




func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	
	# Handle down jump from 1 way platform
	if Input.is_action_pressed("down") and Input.is_action_just_pressed("jump"):
		_drop_through_platform()

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	direction = int(Input.get_axis("left", "right"))
	if direction:
		velocity.x = direction * speed * speed_multiplier
	else:
		velocity.x = move_toward(velocity.x, 0, speed * speed_multiplier)

	move_and_slide()



func _input(event: InputEvent) -> void:
	# Handle jump.
	if event.is_action_pressed("jump") and is_on_floor() and is_attacking == false:
		velocity.y = jump_power * jump_multiplier
	
	# Handle attack
	if event.is_action_pressed("attack") and not is_attacking:
		_start_attack()
	
	if event.is_action_released("attack"):
		_stop_attack()


func _start_attack():
	is_attacking = true
	
	if speed_tween:
		speed_tween.kill()
	
	speed_tween = create_tween()
	speed_tween.tween_property(self, "speed_multiplier", movement_while_attacking_multiplier, 0.25)

func _stop_attack():
	is_attacking = false
	
	if speed_tween:
		speed_tween.kill()
	
	speed_tween = create_tween()
	speed_tween.tween_property(self, "speed_multiplier", movement_while_not_attacking_multiplier, 0.15)



func _drop_through_platform():
	pass

func _teleport_to_location(new_location):
	camera.position_smoothing_enabled = false
	position = new_location
	await get_tree().physics_frame
	camera.position_smoothing_enabled = true
