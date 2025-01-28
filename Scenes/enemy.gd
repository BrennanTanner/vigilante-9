extends RigidBody3D

@export var max_speed: int = 10
@export var rotation_speed: float = 5.0
@export var target_node: Node3D

var down_ray: RayCast3D
var body: Node3D
var target_position: Vector3

func _ready() -> void:
	down_ray = get_node("down_ray")
	body = get_node("body")
	
	lock_rotation = true
	if !target_node:
		target_position = position 
		

func set_target_position(new_target: Vector3) -> void:
	if target_node:
		target_node = null
	target_position = new_target
	
func set_target(new_target: Node3D) -> void:
	target_node = new_target

func get_direction_to_target() -> Vector3:
	return (target_position - position).normalized()

func _process(delta: float) -> void:
	if target_node:
		target_position = target_node.position 
		
func _physics_process(delta: float) -> void:
	if down_ray.is_colliding():
		# Get direction to target
		var direction = get_direction_to_target()
		direction.y = 0  # Keep movement on horizontal plane
		
		# Calculate target velocity
		var target_velocity = direction * max_speed
		
		# Calculate velocity error and correction
		var velocity_error = target_velocity - linear_velocity
		var correction_impulse = velocity_error
		
		# Rotate body towards target
		var target_angle = rad_to_deg(atan2(direction.x, direction.z))
		var current_angle = rad_to_deg(body.rotation.y)
		var angle_diff = fmod((target_angle - current_angle + 180), 360) - 180
		#body.rotation.y = lerp_angle(body.rotation.y, deg_to_rad(target_angle), delta * rotation_speed)
		body.rotation.y = deg_to_rad(target_angle)
		# Apply movement
		apply_central_impulse(correction_impulse)
