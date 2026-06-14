extends CharacterBody2D
class_name EnemyController


#Blindly written just for fun, 0 tests.


enum EnemyState {
	
	IDLE,
	PATROL,
	CHASE,
	SEARCH,
	ALERT,
	
	ATTACK_WINDUP,
	ATTACK,
	ATTACK_COOLDOWN,
	
	
	GOT_HIT,
	KNOCK_BACK,
	
	
	LAUNCHED,
	STANDING_UP,
	
	DEATH
	
}


#For Standing up
var standing_tween : Tween


#Death emitter
signal enemy_dead
var death_finished := false

#Variables for LAUNCHED state
@export var launch_x := 250.0
@export var launch_y := -450.0

@export var normal_gravity_mult := 1.0
@export var float_gravity_mult := 0.45
@export var smash_gravity_mult := 2.2

var launch_start_y := 0.0
var launch_peak_y := 0.0



@export var enemy_animations : AnimatedSprite2D
@export var enemy_ground_check : RayCast2D
@export var enemy_wall_check : RayCast2D
@export var enemy_player_chase : RayCast2D
@export var enemy_player_back_check : RayCast2D
@export var enemy_detection_box : CollisionShape2D
@export var enemy_damage_box : CollisionObject2D
@export var enemy_hurt_box : Area2D
@export var speed := 3.0



var previous_state : EnemyState
var enemy_state : EnemyState = EnemyState.PATROL
var direction := 1
var desired_direction
var speed_multiplier := 30.0

var state_time := 0.0



#For patroling timeout
@export var patrol_timeout : Timer
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var time_to_patrol : int
var time_to_idle : float




#For enemy remembering player
@export var enemy_memory_timer : Timer
@onready var target : PlayerController = get_tree().get_first_node_in_group("player")
var target_position : Vector2
var avoiding_obstacle := false
var avoiding_obstacle_timer : Timer


func _ready() -> void:
	
	#Patrol timer set up
	time_to_patrol = rng.randi_range(5,12)
	patrol_timeout.start(float(time_to_patrol))
	patrol_timeout.timeout.connect(_on_patrol_rest_timeout)
	#Change state to patroling
	_change_state(enemy_state)



func _physics_process(delta : float):
	# Add the gravity.
	if not is_on_floor() and enemy_state != EnemyState.LAUNCHED:
		velocity += get_gravity() * delta
	
	
	#Some of the states dont really need delta but might be useful later on, if not, will be removed.
	match enemy_state:
		
		EnemyState.PATROL:
			_update_patrol(delta)
		
		EnemyState.IDLE:
			_update_idle(delta)
		
		EnemyState.ALERT:
			_update_alert(delta)
		
		EnemyState.CHASE:
			_update_chase(delta)
		
		EnemyState.ATTACK_WINDUP:
			_update_attack_windup(delta)
		
		EnemyState.ATTACK:
			_update_attack(delta)
		
		EnemyState.ATTACK_COOLDOWN:
			_update_attack_cooldown(delta)
		
		EnemyState.GOT_HIT:
			_update_got_hit(delta)
		
		EnemyState.LAUNCHED:
			_update_launched(delta)
		
		EnemyState.STANDING_UP:
			_update_standing_up(delta)
		
		EnemyState.DEATH:
			_update_death(delta)
	
	
	if enemy_player_chase.get_collider() is PlayerController or enemy_player_back_check.get_collider() is PlayerController:
		patrol_timeout.stop()
		_change_state(EnemyState.ALERT)
	
	
	move_and_slide()


#Changing state of the enemy
func _change_state(new_state : EnemyState):
	
	if enemy_state == new_state:
		print("state didnt change, dont do anything")
		return
	
	var clean_up_state = enemy_state
	
	if _can_change_state_to(new_state):
		enemy_state = new_state
	else : return
	
	if clean_up_state == EnemyState.PATROL:
		patrol_timeout.stop()
	
	if clean_up_state == EnemyState.CHASE:
		enemy_memory_timer.stop()
	
	if enemy_state == EnemyState.ATTACK:
		enemy_damage_box.disabled = true
	
	match enemy_state:
		
		EnemyState.PATROL:
			_init_patrol()
		
		EnemyState.IDLE:
			_init_idle()
		
		EnemyState.ALERT:
			_init_alert()
		
		EnemyState.CHASE:
			_init_chase()
		
		EnemyState.ATTACK_WINDUP:
			_init_attack_windup()
		
		EnemyState.ATTACK:
			_init_attack()
		
		EnemyState.ATTACK_COOLDOWN:
			_init_attack_cooldown()
		
		EnemyState.GOT_HIT:
			_init_got_hit()
		
		EnemyState.LAUNCHED:
			_init_launched()
		
		EnemyState.STANDING_UP:
			_init_standing_up()
		
		EnemyState.DEATH:
			_init_death()


# RECHECK THAT LATER IF I DIDNT BAMBOOZLE MYSELF
# Certain states have to be locked so they wont get interrupted
func _can_change_state_to(new_state: EnemyState) -> bool:
	if enemy_state == new_state:
		return false
	
	if enemy_state == EnemyState.DEATH:
		return false
	
	if new_state == EnemyState.DEATH:
		return true
	
	if enemy_state in [
		EnemyState.IDLE,
		EnemyState.PATROL,
		EnemyState.CHASE,
		EnemyState.SEARCH
	] and new_state in [
		EnemyState.ATTACK,
		EnemyState.ATTACK_COOLDOWN
	]:
		return false
	
	if enemy_state == EnemyState.ALERT:
		return new_state in [
			EnemyState.CHASE,
			EnemyState.ATTACK_WINDUP,
			EnemyState.GOT_HIT,
			EnemyState.LAUNCHED,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.ATTACK_WINDUP:
		return new_state in [
			EnemyState.ATTACK,
			EnemyState.GOT_HIT,
			EnemyState.LAUNCHED,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.ATTACK:
		return new_state in [
			EnemyState.ATTACK_COOLDOWN,
			EnemyState.GOT_HIT,
			EnemyState.LAUNCHED,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.ATTACK_COOLDOWN:
		return new_state in [
			EnemyState.CHASE,
			EnemyState.GOT_HIT,
			EnemyState.LAUNCHED,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.GOT_HIT:
		return new_state in [
			EnemyState.CHASE,
			EnemyState.ATTACK_WINDUP,
			EnemyState.LAUNCHED,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.LAUNCHED:
		return new_state in [
			EnemyState.STANDING_UP,
			EnemyState.DEATH
		]
	
	if enemy_state == EnemyState.STANDING_UP:
		return new_state in [
			EnemyState.CHASE,
			EnemyState.PATROL,
			EnemyState.GOT_HIT,
			EnemyState.DEATH
		]
	
	return true



#
###
#####					PATROL
###
#

#Patrol initialization : set up animation 
func _init_patrol():
	
	enemy_state = EnemyState.PATROL
	time_to_patrol = rng.randi_range(5,12)
	patrol_timeout.start(time_to_patrol)
	
	if enemy_animations.animation != "run":
		enemy_animations.play("run")


#Patroling for process frame
func _update_patrol(_delta):
	#Maintaining speed every process frame
	velocity.x = direction * speed * speed_multiplier
	
	#Checking for walls and edges
	if _checking_walls_and_falls():
		direction *= -1
		_flip_enemy_sprite_rays()


#Patrol timer, when over, rest.
func _on_patrol_rest_timeout() -> void:
	previous_state = EnemyState.PATROL
	time_to_idle = rng.randf_range(3.0,6.0)
	state_time = time_to_idle
	_change_state(EnemyState.IDLE)

#
###
#####					PATROL END
###
#



#
###
#####					IDLE
###
#

#Set up the idle anim
func _init_idle():
	
	velocity.x = 0
	if enemy_animations.animation != "idle":
		enemy_animations.play("idle")


func _update_idle(delta):
	
	state_time -= delta
	velocity.x = 0
	
	if state_time < 0:
		_change_state(previous_state)



#
###
#####					IDLE END
###
#


#
###
#####					CHASE
###
#


func _init_chase():
	
	previous_state = EnemyState.CHASE
	enemy_memory_timer.start(10.0)
	
	if enemy_animations.animation != "run":
		enemy_animations.play("run")


func _update_chase(_delta):
	
	if target == null:
		return
	
	if avoiding_obstacle:
		_avoid_obstacles()
		return
	
	if _checking_walls_and_falls():
		avoiding_obstacle = true
		direction *= -1
		_flip_enemy_sprite_rays()
		avoiding_obstacle_timer.start(3.0)
		_avoid_obstacles()
		return
	
	desired_direction = sign(target.global_position.x - global_position.x)
	
	if desired_direction != 0:
		if (direction < 0 and enemy_animations.flip_h == false) or (direction > 0 and enemy_animations.flip_h == true):
			_flip_enemy_sprite_rays()
	velocity.x = direction * speed * speed_multiplier


func _avoid_obstacles():
	
	if avoiding_obstacle_timer.is_stopped():
		avoiding_obstacle = false
		return
	
	velocity.x = direction * speed * speed_multiplier


func _on_enemy_memory_timeout() -> void:
	previous_state = EnemyState.PATROL
	_change_state(EnemyState.IDLE)


#
###
#####					CHASE END
###
#


#
###
#####					 SEARCH
###
#


# Not to implement right now



#
###
#####					SEARCH END
###
#


#
###
#####					 ALERT
###
#


func _init_alert():
	
	desired_direction = sign(target.global_position.x - global_position.x)
	
	if desired_direction != 0:
		direction = desired_direction
		if ((direction < 0 and !enemy_animations.flip_h) or 
		(direction > 0 and enemy_animations.flip_h)):
			_flip_enemy_sprite_rays()
	
	velocity.x = 0
	
	if enemy_animations.animation != "idle":
		enemy_animations.play("idle")
	
	state_time = 0.2


func _update_alert(delta):
	
	velocity.x = 0
	state_time -= delta
	
	if state_time <= 0:
		_change_state(EnemyState.CHASE)


#
###
#####					ALERT END
###
#


#
###
#####					 ATTACK_WINDUP
###
#


func _init_attack_windup():
	
	velocity.x = 0
	
	if enemy_animations.animation != "idle":
		enemy_animations.play("idle")
	
	state_time = 0.2


func _update_attack_windup(delta):
	
	velocity.x = 0
	state_time -= delta
	
	if state_time <= 0:
		_change_state(EnemyState.ATTACK)


#
###
#####					 ATTACK_WINDUP END
###
#


#
###
#####					 ATTACK
###
#


func _init_attack():
	
	velocity.x = 0
	enemy_damage_box.disabled = true
	
	if enemy_animations.animation != "attack":
		enemy_animations.play("attack")



func _update_attack(_delta):
	
	velocity.x = 0
	
	var frame = enemy_animations.frame
	
	if frame == 6 or frame == 7:
		enemy_damage_box.disabled = false
	
	if frame >= 8:
		enemy_damage_box.disabled = true
	
	if frame >= enemy_animations.sprite_frames.get_frame_count("attack")-1:
		enemy_damage_box.disabled = true
		_change_state(EnemyState.ATTACK_COOLDOWN)
	



#
###
#####					 ATTACK END
###
#


#
###
#####					 ATTACK_COOLDOWN
###
#


func _init_attack_cooldown():
	
	velocity.x = 0
	state_time = 0.2
	
	if enemy_animations.animation != "idle":
		enemy_animations.play("idle")


func _update_attack_cooldown(delta):
	
	velocity.x = 0
	state_time -= delta
	
	if state_time <= 0:
		_change_state(EnemyState.CHASE)


#
###
#####					ATTACK_COOLDOWN END
###
#


#
###
#####					GOT_HIT
###
#


func _init_got_hit():
	
	state_time = 0.25
	if enemy_animations.animation != "hurt":
		enemy_animations.play("hurt")
	
	var knock_dir = target.direction
	if knock_dir == 0:
		knock_dir = direction
	
	velocity = Vector2(knock_dir * 350, -180)


func _update_got_hit(delta):
	
	state_time -= delta
	
	velocity.y += get_gravity().y * delta
	velocity.x = move_toward(velocity.x, 0, 900 * delta)
	
	if state_time <= 0:
		_change_state(EnemyState.CHASE)


#
###
#####					GOT_HIT END
###
#


#
###
#####					KNOCKBACK
###
#


# For future implementation


#
###
#####					KNOCKBACK END
###
#


#
###
#####					LAUNCHED
###
#



func _init_launched():
	
	if enemy_animations.animation != "launched":
		enemy_animations.play("launched")
	
	enemy_animations.rotation_degrees = -90 * direction
	
	launch_start_y = global_position.y
	launch_peak_y = global_position.y
	
	var knock_dir := -direction # or based on player side
	velocity = Vector2(knock_dir * launch_x, launch_y)


func _update_launched(delta):
	# remember highest point reached
	if global_position.y < launch_peak_y:
		launch_peak_y = global_position.y
	
	var gravity_mult := normal_gravity_mult
	
	# going up
	if velocity.y < 0:
		gravity_mult = float_gravity_mult
	
	# falling down
	else:
		var halfway_down = (launch_start_y + launch_peak_y) / 2.0
	
		if global_position.y < halfway_down:
			gravity_mult = float_gravity_mult
		else:
			gravity_mult = smash_gravity_mult
	
	velocity.y += get_gravity().y * gravity_mult * delta
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	
	if is_on_floor():
		enemy_animations.rotation_degrees = 0
		_change_state(EnemyState.STANDING_UP)


#
###
#####					LAUNCHED END
###
#


#
###
#####					STANDING_UP
###
#

func _init_standing_up():
	
	velocity.x = 0
	state_time = 0.35
	
	enemy_animations.scale.y = 0.6
	
	if standing_tween:
		standing_tween.kill()
	
	standing_tween = create_tween()
	standing_tween.tween_property(
		enemy_animations,
		"scale:y",
		1.225,
		0.35)


func _update_standing_up(delta):
	
	velocity.x = 0
	state_time -= delta
	
	if state_time <= 0:
		_change_state(EnemyState.CHASE)




#
###
#####					STANDING_UP END
###
#


#
###
#####					DEATH
###
#


func _init_death():
	
	velocity.x = 0
	enemy_hurt_box.collision_layer = 0
	
	if enemy_animations.animation != "dead":
		enemy_animations.play("dead")

func _update_death(_delta):
	
	if death_finished:
		return
	
	if enemy_animations.frame == enemy_animations.sprite_frames.get_frame_count("dead")-1:
		enemy_dead.emit()
		queue_free()



#
###
#####					DEATH END
###
#








#Player enters attack zone
func _on_hit_box_body_entered(body: Node2D) -> void:
	if body is PlayerController and enemy_state != EnemyState.ATTACK:
		print("player entered attacking zone")
		_change_state(EnemyState.ATTACK_WINDUP)



#
###
#####					HELP FUNCTIONS
###
#


#Checking walls and falls
func _checking_walls_and_falls() -> bool :
	return not enemy_ground_check.is_colliding() or enemy_wall_check.is_colliding()


# Flip sprite + rays + collisions
func _flip_enemy_sprite_rays():
	enemy_animations.flip_h = direction < 0
	
	enemy_ground_check.position.x *= -1
	_flip_raycast(enemy_player_chase)
	_flip_raycast(enemy_wall_check)
	_flip_raycast(enemy_player_back_check)
	enemy_detection_box.position.x *= -1


#Flipping rays
func _flip_raycast(ray : RayCast2D):
	ray.target_position.x *= -1
	ray.position.x *= -1


#
###
#####					HELP FUNCTIONS END
###
#
