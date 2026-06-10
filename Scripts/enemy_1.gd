extends CharacterBody2D
class_name EnemyController



enum EnemyState {
	IDLE,
	PATROL,
	ATTACK,
	HIT,
	DEAD,
	CHASE
}



@export var enemy_animations : AnimatedSprite2D
@export var enemy_ground_check : RayCast2D
@export var enemy_wall_check : RayCast2D
@export var enemy_player_chase : RayCast2D
@export var enemy_player_back_check : RayCast2D
@export var enemy_attacking_box : CollisionShape2D
@export var speed := 3.0



var previous_state : EnemyState
var enemy_state : EnemyState = EnemyState.PATROL
var direction := 1
var speed_multiplier := 30.0



#For patroling timeout
@export var patrol_timeout : Timer
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var time_to_patrol : int
var time_to_rest : float



#For enemy remembering player
@export var enemy_memory_timer : Timer
var target : PlayerController
var target_position : Vector2
var avoiding_obstacle := false


func _ready() -> void:
	#Patrol timer set up
	time_to_patrol = rng.randi_range(5,10)
	patrol_timeout.start(float(time_to_patrol))
	patrol_timeout.timeout.connect(_on_patrol_rest_timeout)
	#Change state to patroling
	change_state(enemy_state)



func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	#Refactor this : not good, the animation is initiated every process frame, the only thing you need to do is check for walls etc. 
	if enemy_state == EnemyState.PATROL:
		_enemy_patrol()
	
	#Detect if the ray collides with player or a wall first (front vision)
	if enemy_player_chase.get_collider() is PlayerController or enemy_player_back_check.get_collider() is PlayerController:
		if !(enemy_state == EnemyState.ATTACK):
			var seen_player = enemy_player_chase.get_collider()
			if seen_player == null:
				seen_player = enemy_player_back_check.get_collider()
			target = seen_player
			enemy_memory_timer.start(10.0)
			change_state(EnemyState.CHASE)
	
	#Remember the player and get his position constantly
	if enemy_state == EnemyState.CHASE:
		target_position = target.global_position
		_chase_player()
	
	move_and_slide()



#Changing state of the enemy
func change_state(new_state: EnemyState):
	if enemy_state == new_state:
		
		return

	enemy_state = new_state

	match enemy_state:
		EnemyState.CHASE:
			print("matched chase")
			_chase_player()
		EnemyState.IDLE:
			print("matched idle")
			_enemy_idle()
		EnemyState.PATROL:
			print("matched patrol")
			_enemy_patrol()
		EnemyState.ATTACK:
			print("matched attack")
			_attack()
		EnemyState.HIT:
			enemy_animations.play("hurt")
		EnemyState.DEAD:
			enemy_animations.play("dead")



#Chase the player
func _chase_player():
	
	if target == null : 
		print("chase canceled")
		return
	
	patrol_timeout.stop()
	
	if avoiding_obstacle:
		return
	
	if _checking_walls_and_falls():
		await _avoiding_obstacle()
		return
	
	print("chasing the player")
	#Basic Chase (update later, change facing direction based on where its chasing, upgrade the chasing logic)
	direction = sign(target.global_position.x - global_position.x)
	if (direction < 0 and enemy_animations.flip_h == false) or (direction > 0 and enemy_animations.flip_h == true):
		_flip_enemy_sprite_rays()
	velocity.x = direction * speed * speed_multiplier



func _avoiding_obstacle():
	avoiding_obstacle = true
	
	direction *= -1
	velocity.x = direction * speed * speed_multiplier
	_flip_enemy_sprite_rays()
	
	await _transition_between_states(0.8)
	
	avoiding_obstacle = false


#Memory of remembering the player
func _on_enemy_memory_timeout() -> void:
	change_state(EnemyState.IDLE)


#Player enters attack zone
func _on_hit_box_body_entered(body: Node2D) -> void:
	if body is PlayerController and enemy_state != EnemyState.ATTACK:
		print("player entered attacking zone")
		change_state(EnemyState.ATTACK)



#Attack
func _attack():
	#Prepare
	velocity.x = 0
	enemy_animations.play("idle")
	await _transition_between_states(0.5)
	
	#Action
	enemy_animations.play("attack")
	await enemy_animations.animation_finished

	#Next move
	
	
	if enemy_state == EnemyState.ATTACK:
		change_state(EnemyState.IDLE)



#Idle (refactor later, attacking collision reset shouldnt be inside idle)
func _enemy_idle():
	#Prepare for idle
	enemy_animations.play("idle")
	velocity.x = 0
	
	await _enemy_attacking_box_reset_transition(0.5)
	
	if (enemy_state == EnemyState.IDLE):
		change_state(EnemyState.PATROL)

func _enemy_attacking_box_reset_transition(n : float):
	enemy_attacking_box.disabled = true
	await _transition_between_states(n)
	enemy_attacking_box.disabled = false



#Idle for patrol (refactor later)
func _patrol_idle():
	#Prepare
	velocity.x = 0
	enemy_animations.play("idle")
	enemy_state = EnemyState.IDLE
	
	#Action + Reset
	await _enemy_resting_in_patrol()
	_reset_patrol_rest()
	
	#Next move
	if enemy_state != EnemyState.IDLE:
		return
	change_state(EnemyState.PATROL)


func _enemy_resting_in_patrol():
	time_to_rest = rng.randf_range(1,3)
	await get_tree().create_timer(time_to_rest).timeout


func _reset_patrol_rest():
	time_to_patrol = rng.randi_range(5,10)
	print(str(time_to_patrol) + " time to patrol")
	patrol_timeout.start(float(time_to_patrol))


#Transition between states:
func _transition_between_states(x : float):
	await get_tree().create_timer(x).timeout



#Patrol
func _enemy_patrol():
	#Prepare
	velocity.x = direction * speed * speed_multiplier
	if enemy_animations.animation != "run":
		enemy_animations.play("run")
	
	#Checking walls and falls + flipping
	if _checking_walls_and_falls():
		direction *= -1
		_flip_enemy_sprite_rays()


#Checking walls and falls
func _checking_walls_and_falls() -> bool :
	if not enemy_ground_check.is_colliding() or enemy_wall_check.is_colliding():
		return true
	else: return false


func _on_patrol_rest_timeout() -> void:
	_patrol_idle()


# Flip sprite + rays + collisions
func _flip_enemy_sprite_rays():
	enemy_animations.flip_h = direction < 0
	
	enemy_ground_check.position.x *= -1
	_flip_raycast(enemy_player_chase)
	_flip_raycast(enemy_wall_check)
	_flip_raycast(enemy_player_back_check)
	enemy_attacking_box.position.x *= -1


#Flipping rays
func _flip_raycast(ray : RayCast2D):
	ray.target_position.x *= -1
	ray.position.x *= -1




#Hit


#Dead
