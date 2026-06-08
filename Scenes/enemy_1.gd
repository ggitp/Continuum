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

var enemy_state : EnemyState = EnemyState.IDLE


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

func _ready() -> void:
	enemy_state = EnemyState.PATROL

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	
	
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

	move_and_slide()

#Idle
func _enemy_idle():
	enemy_animations.play("idle")
	await get_tree().create_timer(1.0).timeout

#Patrol
#func _enemy_patrol():
	
	

#Chase
#Attack
#Hit
#Dead


func _on_hit_box_body_entered(body: Node2D) -> void:
	enemy_state = EnemyState.HIT
	await get_tree().create_timer(1.0).timeout
	enemy_animations.play("attack")
	await enemy_animations.animation_finished
	enemy_state = EnemyState.IDLE
	_enemy_idle()
