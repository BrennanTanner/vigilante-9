extends CharacterBody3D

@export var health: int = 100
@export var move_speed: float = 5.0

var player: Car = null
var gravity: float = -9.8

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Simple movement towards player
	var direction = (player.global_position - global_position).normalized()
	direction.y = 0
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	
	move_and_slide()

func hit(damage: int) -> void:
	health -= damage
	if health <= 0:
		queue_free()
