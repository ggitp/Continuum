extends CharacterBody2D
class_name EnemyController

enum EnemyState {
	IDLE,
	PATROL,
	ATTACK,
	HIT,
	DEAD
}

@export var enemy_animations : AnimatedSprite2D
@export var enemy_ground_check : RayCast2D
@export var enemy_wall_check : RayCast2D
@export var enemy_player_chase : RayCast2D
@export var enemy_player_back_check : RayCast2D
@export var enemy_attacking_box : CollisionShape2D
@export var speed := 3.0

var enemy_state : EnemyState = EnemyState.PATROL
var direction := 1
var speed_multiplier := 30.0

func _ready() -> void:
	change_state(enemy_state)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if enemy_state == EnemyState.PATROL:
		_enemy_patrol()
	
	
	move_and_slide()

func change_state(new_state: EnemyState):
	if enemy_state == new_state:
		print("state didnt change, do nothing")
		return

	enemy_state = new_state

	match enemy_state:
		EnemyState.IDLE:
			_enemy_idle()
		EnemyState.PATROL:
			_enemy_patrol()
		EnemyState.ATTACK:
			_attack()
		EnemyState.HIT:
			enemy_animations.play("hurt")
		EnemyState.DEAD:
			enemy_animations.play("dead")


	# Patrol
	#if enemy_state == EnemyState.PATROL:
		#enemy_patrol()
	
	

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("ui_left", "ui_right")
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)


#Idle
func _enemy_idle():
	print("initiated idling")
	enemy_animations.play("idle")
	velocity.x = 0
	enemy_attacking_box.disabled = true
	enemy_attacking_box.disabled = false
	await _transition(0.5)
	
	if (enemy_state == EnemyState.IDLE):
		change_state(EnemyState.PATROL)

#Transition between states:
func _transition(x : float):
	await get_tree().create_timer(x).timeout

#Patrol
func _enemy_patrol():
	print("enemy patroling")
	velocity.x = direction * speed * speed_multiplier
	if enemy_animations.animation != "run":
		enemy_animations.play("run")
		
	if not enemy_ground_check.is_colliding() or enemy_wall_check.is_colliding():
		print(str(enemy_ground_check.is_colliding()) + str(enemy_wall_check.is_colliding()))
		_flip_enemy()


# Flip sprite + check arrows
func _flip_enemy():
	direction *= -1
	enemy_animations.flip_h = direction < 0
	#if direction > 0:
		#enemy_animations.flip_h = false
	#else:
		#enemy_animations.flip_h = true
	
	enemy_ground_check.position.x *= -1
	_flip_raycast(enemy_wall_check)
	_flip_raycast(enemy_player_chase)
	_flip_raycast(enemy_player_back_check)
	enemy_attacking_box.position.x *= -1

func _flip_raycast(ray : RayCast2D):
	ray.target_position.x *= -1
	ray.position.x *= -1

#Chase
#Attack
func _attack():
	print("attacking initiated")
	velocity.x = 0
	enemy_animations.play("idle")
	await _transition(0.5)

	print("playing attack")
	enemy_animations.play("attack")

	await enemy_animations.animation_finished

	print("attack finished")
	if enemy_state == EnemyState.ATTACK:
		change_state(EnemyState.IDLE)

#Hit
#Dead


func _on_hit_box_body_entered(body: Node2D) -> void:
	if body is PlayerController and enemy_state != EnemyState.ATTACK:
		print("player entered attacking zone")
		change_state(EnemyState.ATTACK)
