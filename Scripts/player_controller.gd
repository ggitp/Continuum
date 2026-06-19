extends CharacterBody2D
class_name PlayerController

signal movement_state_changed(previous_state, new_state)
signal action_state_changed(previous_state, new_state)


enum MovementState {
	GROUNDED,
	AIRBORNE,
	DASHING
}


enum ActionState {
	DEFAULT,
	
	ATTACK_1,
	ATTACK_3,
	
	AIRBORNE_ATTACK,
	AIRBORNE_ATTACK_UP,
	AIRBORNE_ATTACK_DOWN,
	
	DASHING_ATTACK,
	
	GOT_HIT,
	DEAD
}


@export_category("Movement")
@export var move_speed := 300.0
@export var ground_acceleration := 2200.0
@export var ground_deceleration := 3600.0
@export var air_acceleration := 10000.0
@export var jump_velocity := -600.0


@export_category("Dash")
@export var dash_speed := 750.0
@export var dash_duration := 0.16


@export_category("Combat")
@export_range(0.0, 1.0) var attack_movement_multiplier := 0.15
@export var hurt_deceleration := 900.0
@export var air_attack_limiter := 3


@export_category("Drop Through")
@export_range(1, 32, 1) var one_way_platform_layer := 3
@export var drop_through_duration := 0.15
@export var drop_through_velocity := 80.0


@export_category("References")
@export var camera: Camera2D


var movement_state: MovementState = MovementState.GROUNDED
var action_state: ActionState = ActionState.DEFAULT

var movement_state_time := 0.0
var action_state_time := 0.0
var airborne_gravity_time := 0.0

# Current horizontal input: -1.0, 0.0 or 1.0.
var move_input := 0.0

# Where the player is looking. This remains -1 or 1 while standing still.
var facing_direction := 1

var drop_through_time := 0.0



func _ready() -> void:
	_enter_movement_state(movement_state)
	_enter_action_state(action_state)




func _physics_process(delta: float) -> void:
	_update_drop_through(delta)
	_read_input()
	
	_update_action_state(delta)
	_update_movement_state(delta)
	
	_apply_gravity(delta)
	
	move_and_slide()
	
	_resolve_movement_state()




func _read_input() -> void:
	move_input = Input.get_axis("left", "right")
	
	if move_input != 0:
		facing_direction = int(sign(move_input))
	
	if action_state in [
		ActionState.GOT_HIT,
		ActionState.DEAD
	]:
		return
	
	if Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("down") and is_on_floor():
			_start_drop_through()
		elif _can_jump():
			_jump()
	
	if Input.is_action_just_pressed("dash"):
		_request_dash()
	
	if Input.is_action_just_pressed("attack"):
		_request_attack()


#
##				ACTION STATE
#


func _change_action_state(new_state: ActionState) -> void:
	if action_state == new_state:
		return
	
	if not _can_change_action_state(new_state):
		return
	
	var old_state := action_state
	
	_exit_action_state(old_state)
	
	action_state = new_state
	action_state_time = 0.0
	
	_enter_action_state(new_state)
	action_state_changed.emit(old_state, new_state)


func _enter_action_state(new_state: ActionState) -> void:
	match new_state:
		ActionState.DEFAULT:
			pass
		
		ActionState.ATTACK_1:
			action_state_time = 0.30
		
		ActionState.ATTACK_3:
			action_state_time = 0.42
		
		ActionState.AIRBORNE_ATTACK:
			action_state_time = 0.30
			airborne_gravity_time = 0.5
			air_attack_limiter -= 1
		
		ActionState.AIRBORNE_ATTACK_UP:
			action_state_time = 0.35
		
		ActionState.AIRBORNE_ATTACK_DOWN:
			action_state_time = 0.40
		
		ActionState.DASHING_ATTACK:
			action_state_time = 0.28
		
		ActionState.GOT_HIT:
			action_state_time = 0.25
		
		ActionState.DEAD:
			velocity = Vector2.ZERO



func _exit_action_state(old_state: ActionState) -> void:
	match old_state:
		ActionState.ATTACK_1, \
		ActionState.ATTACK_3, \
		ActionState.AIRBORNE_ATTACK, \
		ActionState.AIRBORNE_ATTACK_UP, \
		ActionState.AIRBORNE_ATTACK_DOWN, \
		ActionState.DASHING_ATTACK:
			# Disable attack hitboxes here later.
			pass


func _can_change_action_state(new_state: ActionState) -> bool:
	if action_state == ActionState.DEAD:
		return false
	
	if new_state == ActionState.DEAD:
		return true
	
	if new_state == ActionState.AIRBORNE_ATTACK and air_attack_limiter < 0:
		return false
	
	if new_state == ActionState.GOT_HIT:
		return true
	
	if action_state == ActionState.GOT_HIT:
		return false
	
	if action_state == ActionState.DEFAULT:
		return true
	
	# Ordinary attacks currently finish before another action starts.
	return new_state == ActionState.DEFAULT


func _get_action_movement_multiplier() -> float:
	if _is_attack_state(action_state):
		return attack_movement_multiplier
	
	return 1.0


func _is_attack_state(state: ActionState) -> bool:
	return state in [
		ActionState.ATTACK_1,
		ActionState.ATTACK_3,
		ActionState.AIRBORNE_ATTACK,
		ActionState.AIRBORNE_ATTACK_UP,
		ActionState.AIRBORNE_ATTACK_DOWN,
		ActionState.DASHING_ATTACK
	]


func _update_action_state(delta: float) -> void:
	match action_state:
		ActionState.DEFAULT:
			pass
		
		ActionState.ATTACK_1, \
		ActionState.ATTACK_3, \
		ActionState.AIRBORNE_ATTACK, \
		ActionState.AIRBORNE_ATTACK_UP, \
		ActionState.AIRBORNE_ATTACK_DOWN, \
		ActionState.DASHING_ATTACK:
			_update_attack_action(delta)
		
		ActionState.GOT_HIT:
			_update_got_hit(delta)
		
		ActionState.DEAD:
			_update_dead()


#
##				ACTION STATE END
#


#
##				MOVEMENT SPEED STATE
#


func _change_movement_state(new_state: MovementState) -> void:
	if movement_state == new_state:
		return
	
	var old_state := movement_state
	
	_exit_movement_state(old_state)
	
	movement_state = new_state
	movement_state_time = 0.0
	
	_enter_movement_state(new_state)
	movement_state_changed.emit(old_state, new_state)


func _resolve_movement_state() -> void:
	if movement_state == MovementState.DASHING:
		return
	
	if is_on_floor():
		_change_movement_state(MovementState.GROUNDED)
	else:
		_change_movement_state(MovementState.AIRBORNE)


func _enter_movement_state(new_state: MovementState) -> void:
	match new_state:
		MovementState.GROUNDED:
			pass
		
		MovementState.AIRBORNE:
			air_attack_limiter = 3
		
		MovementState.DASHING:
			movement_state_time = dash_duration
			velocity.y = 0


func _exit_movement_state(old_state: MovementState) -> void:
	match old_state:
		MovementState.DASHING:
			pass


func _update_movement_state(delta: float) -> void:
	# Hurt and death control their own velocity.
	if action_state in [
		ActionState.GOT_HIT,
		ActionState.DEAD
	]:
		return

	match movement_state:
		MovementState.GROUNDED:
			_update_horizontal_movement(
				delta,
				ground_acceleration,
				ground_deceleration
			)
		
		MovementState.AIRBORNE:
			_update_horizontal_movement(
				delta,
				air_acceleration,
				air_acceleration
			)
		
		MovementState.DASHING:
			_update_dash(delta)


#
##				MOVEMENT SPEED STATE END
#

#
##				DROP THROUGH ONE WAY PLATFORM
#


#Start dropping through one way platform
func _start_drop_through() -> void:
	if drop_through_time > 0:
		return
	
	drop_through_time = drop_through_duration
	
	set_collision_mask_value(one_way_platform_layer, false)
	
	velocity.y = max(velocity.y, drop_through_velocity)
	_change_movement_state(MovementState.AIRBORNE)


func _update_drop_through(delta: float) -> void:
	if drop_through_time <= 0:
		return
	
	drop_through_time -= delta
	
	if drop_through_time <= 0:
		set_collision_mask_value(one_way_platform_layer, true)

#
##				DROP THROUGH ONE WAY PLATFORM END
#

#
##				JUMP
#


func _can_jump() -> bool:
	return (
		is_on_floor()
		and movement_state != MovementState.DASHING
		and action_state == ActionState.DEFAULT
	)

func _jump() -> void:
	velocity.y = jump_velocity
	_change_movement_state(MovementState.AIRBORNE)


#
##				JUMP END
#


#
##				DASH
#



func _request_dash() -> void:
	if movement_state == MovementState.DASHING:
		return
	
	if action_state != ActionState.DEFAULT:
		return
	
	_change_movement_state(MovementState.DASHING)



func _update_dash(delta: float) -> void:
	movement_state_time -= delta
	velocity.x = facing_direction * dash_speed
	
	if movement_state_time <= 0:
		if is_on_floor():
			_change_movement_state(MovementState.GROUNDED)
		else:
			_change_movement_state(MovementState.AIRBORNE)


#
##				DASH END
#


#
##				GRAVITY APPLICATION
#


func _apply_gravity(delta: float) -> void:
	
	if movement_state == MovementState.DASHING:
		return
	
	airborne_gravity_time -= delta
	
	if velocity.y < 0 and action_state == ActionState.AIRBORNE_ATTACK:
		velocity.y = 0
	
	if action_state == ActionState.AIRBORNE_ATTACK and airborne_gravity_time > 0:
		velocity.y += 0 * delta
		print(velocity.y)
		return
	
	if not is_on_floor() and airborne_gravity_time <= 0:
		velocity += (get_gravity() - Vector2(0,130)) * delta


#
##				GRAVITY APPLICATION END
#

#
##				ATTACK
#

func _request_attack() -> void:
	if action_state != ActionState.DEFAULT:
		return
	
	if movement_state == MovementState.DASHING:
		_change_action_state(ActionState.DASHING_ATTACK)
		return
	
	if movement_state == MovementState.AIRBORNE:
		if Input.is_action_pressed("up"):
			_change_action_state(ActionState.AIRBORNE_ATTACK_UP)
		elif Input.is_action_pressed("down"):
			_change_action_state(ActionState.AIRBORNE_ATTACK_DOWN)
		else:
			_change_action_state(ActionState.AIRBORNE_ATTACK)
		
		return
	
	_change_action_state(ActionState.ATTACK_1)



func _update_attack_action(delta: float) -> void:
	action_state_time -= delta
	
	if action_state_time <= 0:
		_change_action_state(ActionState.DEFAULT)


#
##				ATTACK END
#


#
##				HORIZONTAL MOVEMENT APPLICATION
#



func _update_horizontal_movement(
	delta: float,
	acceleration: float,
	deceleration: float
) -> void:
	var movement_multiplier := _get_action_movement_multiplier()
	var target_speed := move_input * move_speed * movement_multiplier
	
	
	if move_input != 0:
		velocity.x = move_toward(
			velocity.x,
			target_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)


#
##				HORIZONTAL MOVEMENT APPLICATION END
#


#
##				GOT HIT
#


func _update_got_hit(delta: float) -> void:
	action_state_time -= delta
	
	velocity.x = move_toward(
		velocity.x,
		0.0,
		hurt_deceleration * delta
	)
	
	if action_state_time <= 0:
		_change_action_state(ActionState.DEFAULT)


#
##				GOT HIT END
#


func _update_dead() -> void:
	velocity.x = 0




#
##				TELEPORTATION TO LOCATION
#


func _teleport_to_location(new_location: Vector2) -> void:
	camera.position_smoothing_enabled = false
	global_position = new_location
	
	await get_tree().physics_frame
	
	camera.position_smoothing_enabled = true


#
##				TELEPORTATION TO LOCATION END
#

























#END
