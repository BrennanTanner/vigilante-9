extends RigidBody3D

@export var health: int = 100
@export var move_speed: float = 5.0
@export var righting_force: float = 5.0

@onready var ray_cast = $RayCast3D

var loot = load("res://collectible.tscn")
var player:  Node3D = null
var is_on_ground: bool = false
var up_direction: Vector3 = Vector3.UP
		
func _ready() -> void:
	# Get player reference - adjust path as needed
	player = get_tree().get_first_node_in_group("player")
	contact_monitor = true
	max_contacts_reported = 1
	
		
func _physics_process(delta: float) -> void:
	check_ground()
	right_self(delta)
	if is_on_ground:
		move_to_player(delta)
		face_player(delta)

func check_ground() -> void:
	is_on_ground = ray_cast.is_colliding()
	
func face_player(delta: float) -> void:
	if player:
		var direction = (player.global_position - global_position)
		direction.y = 0  # Keep on horizontal plane
		
		if direction.length() > 0.1:  # Only rotate if there's a meaningful direction
			# Calculate the target rotation
			var target_rotation = atan2(-direction.x, -direction.z)
			
			# Get current rotation angle around Y axis
			var current_rotation = rotation.y
			
			# Calculate the shortest rotation path
			var rotation_diff = fmod((target_rotation - current_rotation + PI), (2 * PI)) - PI
			
			# Apply torque in the correct direction
			apply_torque(Vector3(0, rotation_diff / 250, 0))
			
func move_to_player(delta: float) -> void:
	if player:
		var direction = (player.global_position - global_position).normalized()
		direction.y = 0  # Keep movement on horizontal plane
		apply_force(direction * move_speed)

func right_self(delta: float) -> void:
	var current_up = transform.basis.y
	var target_up = up_direction
	
	if current_up.dot(target_up) < 0.99:  # Not upright
		var right_rotation = current_up.cross(target_up).normalized()
		apply_torque(right_rotation * righting_force)

func _process(delta: float) -> void:
	if health <= 0:
		die()

func hit(damage) -> void:
	health -= damage
	
func die() -> void:
	var instance = loot.instantiate()
	instance.position = global_position
	instance.rotation = Vector3(0, rotation.y + get_parent().rotation.y + PI/2, 0)
	get_tree().root.add_child(instance)
	
	queue_free()
	
func _on_body_entered(body: Node) -> void:
	if body == player:
		pass
		#print(player.prevVelocity)
