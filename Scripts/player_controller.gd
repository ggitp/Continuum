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
	LAUNCH_ATTACK,
	
	AIRBORNE_ATTACK,
	AIRBORNE_ATTACK_UP,
	AIRBORNE_ATTACK_DOWN,
	
	DASHING_ATTACK,
	
	GOT_HIT,
	DEAD
}


#State durations :
const ATTACK_1_TIME := 0.35
const ATTACK_3_TIME := 0.55
const LAUNCH_ATTACK_TIME := 0.65
const AIRBORNE_ATTACK_TIME := 0.35
const AIRBORNE_ATTACK_UP_TIME := 0.35
const AIRBORNE_ATTACK_DOWN_TIME := 0.40
const DASHING_ATTACK_TIME := 0.28
const GOT_HIT_TIME := 0.25





@export_category("Movement")
@export var move_speed := 300.0
@export var ground_acceleration := 2200.0
@export var ground_deceleration := 4600.0
@export var air_acceleration := 1400.0
@export var air_deceleration := 1000
@export var jump_velocity := -330.0
#@export var test := 0.0


@export_category("Dash")
@export var dash_speed := 850.0
@export var dash_duration := 0.12


@export_category("Combat")
@export_range(0.0, 1.0) var attack_movement_multiplier := 0.15
@export var hurt_deceleration := 900.0
@export var air_attack_limiter := 3
@export var attacking_box_normal : CollisionShape2D
@export var attacking_box_3 : CollisionShape2D
#const ATTACK_BOX_NORMAL_X := 42.0
#const ATTACK_BOX_3_X := 
var combo_queued := false
var post_airborne_attack_turn_cd := 0.0
var post_airborne_flag := false

@export_category("Drop Through")
@export_range(1, 32, 1) var one_way_platform_layer := 3
@export var drop_through_duration := 0.15
@export var drop_through_velocity := 80.0


@export_category("References")
@export var camera: Camera2D


#Player Stats
var base_damage := 25
var damage_bonus_buff := 1.0
var damage_bonus_stats := 1.0
var attack_num_bonus := 1.0
var weapon_damage_bonus := 1.0


#Buffer next action
var buffered_action : StringName = &""
var buffer_time := 0.0
const INPUT_JUMP_BUFFER_DURATION := 0.17
const INPUT_LAUNCH_BUFFER_DURATION := 0.2


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
	attacking_box_normal.disabled = true
	attacking_box_3.disabled = true
	_enter_movement_state(movement_state)
	_enter_action_state(action_state)




func _physics_process(delta: float) -> void:
	
	_update_drop_through(delta)
	
	_update_action_state(delta)
	
	_update_input_buffer(delta)
	
	_read_input()
	
	_update_movement_state(delta)
	
	#print("vel y:", velocity.y, " pos:", global_position.y, " floor:", is_on_floor(), " action:", ActionState.keys()[action_state], " movement:", MovementState.keys()[movement_state])
	#print(" action:", ActionState.keys()[action_state])
	print("vel x:", velocity.x)
	
	_apply_gravity(delta)
	
	move_and_slide()
	
	_resolve_movement_state()




func _read_input() -> void:
	move_input = Input.get_axis("left", "right")
	
	if move_input != 0 and not _is_attack_state(action_state) and not post_airborne_flag:
		facing_direction = int(sign(move_input))
		$AttackingBox.scale.x = facing_direction
	
	
	if action_state in [
		ActionState.GOT_HIT,
		ActionState.DEAD
	]:
		return
	
	if _try_to_consume_action():
		return
	
	if Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("down") and is_on_floor():
			_start_drop_through()
		elif _can_jump():
			_jump()
		else:
			_buffer_action(&"jump")
	
	if Input.is_action_just_pressed("dash"):
		_request_dash()
	
	if Input.is_action_just_pressed("attack"):
		_request_attack(ActionState.ATTACK_1)
	
	if Input.is_action_just_pressed("launch"):
		_request_attack(ActionState.LAUNCH_ATTACK)




func _update_input_buffer(delta):
	
	if buffer_time <= 0:
		return
	
	buffer_time -= delta
	
	if buffer_time <= 0:
		buffered_action = &""


func _try_to_consume_action():
	
	match buffered_action:
		
		&"jump":
			if _can_jump():
				_clear_input_buffer()
				_jump()
				return true
		
		&"launch":
			if (
			_can_change_action_state(ActionState.LAUNCH_ATTACK)
			and action_state != ActionState.LAUNCH_ATTACK
			and is_on_floor()):
				_clear_input_buffer()
				_change_action_state(ActionState.LAUNCH_ATTACK)
				return true
	return false



func _buffer_action(action: StringName):
	
	buffered_action = action
	
	match action:
		&"jump":
			buffer_time = INPUT_JUMP_BUFFER_DURATION
		
		&"launch":
			buffer_time = INPUT_LAUNCH_BUFFER_DURATION


func _clear_input_buffer() -> void:
	buffered_action = &""
	buffer_time = 0.0


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
			action_state_time = ATTACK_1_TIME
		
		ActionState.ATTACK_3:
			action_state_time = ATTACK_3_TIME
		
		ActionState.LAUNCH_ATTACK:
			action_state_time = LAUNCH_ATTACK_TIME
		
		ActionState.AIRBORNE_ATTACK:
			action_state_time = AIRBORNE_ATTACK_TIME
			airborne_gravity_time = 0.5
			air_attack_limiter -= 1
		
		ActionState.AIRBORNE_ATTACK_UP:
			action_state_time = AIRBORNE_ATTACK_UP_TIME
		
		ActionState.AIRBORNE_ATTACK_DOWN:
			action_state_time = AIRBORNE_ATTACK_DOWN_TIME
		
		ActionState.DASHING_ATTACK:
			action_state_time = DASHING_ATTACK_TIME
		
		ActionState.GOT_HIT:
			action_state_time = GOT_HIT_TIME
		
		ActionState.DEAD:
			velocity = Vector2.ZERO



func _exit_action_state(old_state: ActionState) -> void:
	match old_state:
		ActionState.ATTACK_1, \
		ActionState.ATTACK_3, \
		ActionState.AIRBORNE_ATTACK_UP, \
		ActionState.AIRBORNE_ATTACK_DOWN, \
		ActionState.DASHING_ATTACK, \
		ActionState.LAUNCH_ATTACK:
			pass
		
		ActionState.AIRBORNE_ATTACK:
			post_airborne_attack_turn_cd = 0.15
			post_airborne_flag = true


func _can_change_action_state(new_state: ActionState) -> bool:
	if action_state == ActionState.DEAD:
		return false
	
	if new_state == ActionState.DEAD:
		return true
	
	if new_state == ActionState.AIRBORNE_ATTACK and air_attack_limiter <= 0:
		return false
	
	if new_state == ActionState.GOT_HIT:
		return true
	
	if action_state == ActionState.GOT_HIT:
		return false
	
	if _get_next_combo_attack(action_state) == new_state:
		return true
	
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
		ActionState.DASHING_ATTACK,
		ActionState.LAUNCH_ATTACK
	]


func _update_action_state(delta: float) -> void:
	match action_state:
		ActionState.DEFAULT:
			_update_default(delta)
		
		ActionState.ATTACK_1, \
		ActionState.ATTACK_3, \
		ActionState.AIRBORNE_ATTACK, \
		ActionState.AIRBORNE_ATTACK_UP, \
		ActionState.AIRBORNE_ATTACK_DOWN, \
		ActionState.DASHING_ATTACK, \
		ActionState.LAUNCH_ATTACK:
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
			air_attack_limiter = 3
		
		MovementState.AIRBORNE:
			pass
		
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
				air_deceleration
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
	airborne_gravity_time = 0.0
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
	
	if velocity.y > 0 and action_state == ActionState.AIRBORNE_ATTACK:
		velocity.y -= velocity.y/10
	
	if action_state == ActionState.AIRBORNE_ATTACK and airborne_gravity_time > 0:
		velocity.y += 0
		return
	
	if not is_on_floor() and airborne_gravity_time <= 0:
		velocity += (get_gravity() - Vector2(0,130)) * delta


#
##				GRAVITY APPLICATION END
#


#
##				DEFAULT STATE
#


func _update_default(delta):
	if post_airborne_attack_turn_cd <= 0:
		return
	
	post_airborne_attack_turn_cd -= delta
	
	if post_airborne_attack_turn_cd <= 0:
		post_airborne_flag = false


#
##				DEFAULT STATE END
#


#
##				ATTACK
#

func _request_attack(requested_state : ActionState) -> void:
	
	if action_state != ActionState.DEFAULT:
		if requested_state == ActionState.ATTACK_1:
			_try_queue_combo()
		return
	
	if movement_state == MovementState.DASHING:
		_change_action_state(ActionState.DASHING_ATTACK)
		return
	
	if movement_state == MovementState.AIRBORNE:
		if requested_state == ActionState.LAUNCH_ATTACK:
			_buffer_action(&"launch")
			return
		
		_change_action_state(_get_air_attack_state())
		return
	
	#attacking_box_normal.disabled = false
	_change_action_state(requested_state)


func _get_air_attack_state():
	
	if Input.is_action_pressed("up"):
		return ActionState.AIRBORNE_ATTACK_UP
	if Input.is_action_pressed("down"):
		return ActionState.AIRBORNE_ATTACK_DOWN
	
	return ActionState.AIRBORNE_ATTACK


func _try_queue_combo() -> void:
	if _get_next_combo_attack(action_state) == ActionState.DEFAULT:
		return
	
	if not _is_combo_input_window_open():
		return
	
	combo_queued = true


func _get_next_combo_attack(state: ActionState) -> ActionState:
	match state:
		ActionState.ATTACK_1:
			return ActionState.ATTACK_3
	
	return ActionState.DEFAULT


func _is_combo_input_window_open() -> bool:
	match action_state:
		ActionState.ATTACK_1:
			return action_state_time <= ATTACK_1_TIME - 0.07 and action_state_time > 0.01
	
	return false


#const ATTACK_1_TIME := 0.35
#const ATTACK_3_TIME := 0.55
#const LAUNCH_ATTACK_TIME := 0.65
#const AIRBORNE_ATTACK_TIME := 0.35
#const AIRBORNE_ATTACK_UP_TIME := 0.35
#const AIRBORNE_ATTACK_DOWN_TIME := 0.40
#const DASHING_ATTACK_TIME := 0.28
#const GOT_HIT_TIME := 0.25

func _update_attack_action(delta: float) -> void:
	action_state_time -= delta
	
	if action_state in [
		ActionState.ATTACK_1,
		ActionState.LAUNCH_ATTACK,
		ActionState.AIRBORNE_ATTACK
	]:
		if action_state_time < ATTACK_1_TIME and action_state_time > ATTACK_1_TIME/2:
			attacking_box_normal.disabled = false
		else:
			attacking_box_normal.disabled = true
	
	if action_state == ActionState.ATTACK_3:
		if action_state_time < ATTACK_3_TIME - 0.13 and action_state_time > ATTACK_3_TIME/3:
			attacking_box_3.disabled = false
		else:
			attacking_box_3.disabled = true
	
	if action_state_time <= 0.0:
		attacking_box_normal.disabled = true
		attacking_box_3.disabled = true
		
		var next_attack := _get_next_combo_attack(action_state)
		
		if combo_queued and next_attack != ActionState.DEFAULT:
			combo_queued = false
			_change_action_state(next_attack)
			return
		
		combo_queued = false
		_change_action_state(ActionState.DEFAULT)
	
	#if action_state_time <= 0: #or (is_on_floor() and action_state == ActionState.AIRBORNE_ATTACK):
		#attacking_box_normal.disabled = true
		#_change_action_state(ActionState.DEFAULT)


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
	#var movement_multiplier := _get_action_movement_multiplier()
	var target_speed := move_input * move_speed# * movement_multiplier
	
	var progress := 1.0 - action_state_time
	var test := deceleration * pow(1.0 - progress, 1.8)
	
	
	if _is_attack_state(action_state) and is_on_floor() and move_input != 0:
		if facing_direction != move_input:
			velocity.x = move_toward(
				velocity.x,
				1 * move_input,
				deceleration * delta
			)
			return
		else:
			velocity.x = move_toward(
				velocity.x,
				15 * move_input,
				test * delta
			)
			return
	
	
	
	if move_input != 0 and airborne_gravity_time > 0:
		velocity.x = move_toward(
			velocity.x,
			target_speed/7,
			acceleration * delta
		)
		return
	
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



func _on_attacking_box_body_entered(body: Node2D) -> void:
	if body is EnemyController:
		var hit_data := {
			"damage" : _calculate_damage(),
			"launch" : action_state == ActionState.LAUNCH_ATTACK,
		}
		body._recieve_hit(hit_data)


func _calculate_damage():
	return roundi(base_damage * damage_bonus_buff * damage_bonus_stats * attack_num_bonus * weapon_damage_bonus)


















#END
