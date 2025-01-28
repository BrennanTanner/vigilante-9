extends RigidBody3D
class_name Car

@export var max_speed: float = 50.0
@export var acceleration: float = 10.0
@export var turn_speed: float = 7.0
@export var max_turn_velocity: float = 1.0
@export var angular_damping: float = 2.0
@export var linear_damping: float = 5.0
@export var car_entity: Node3D

var current_turn_speed: float = 0.0
var current_turn_direction: float = 0.0
var default_max_turn_velocity: float = 0.0
var speed_percentage: float = 0.0
var body: MeshInstance3D
var wheels: Array[Node]
var down_ray: RayCast3D
var dusts: Array[Node]

func _ready():
	if car_entity == null:
		push_error("car not found, must be set!")
	
	body = car_entity.get_node("body")
	wheels = car_entity.get_node("wheels").get_children()
	down_ray = car_entity.get_node("down_ray")
	dusts = car_entity.get_node("body/drift_smoke").get_children()
	default_max_turn_velocity = max_turn_velocity
	
	gravity_scale = linear_damping
	angular_damp = angular_damping
	linear_damp = linear_damping

func apply_movement(move_direction: Vector2, delta: float) -> void:
	var velocity = min(linear_velocity.length(), max_speed)
	
	if move_direction.length() > 0 and down_ray.is_colliding():
		var forward_vector = transform.basis.z
		var turn_velocity = min(velocity, max_turn_velocity)
		
		# Apply torque and force
		apply_torque(Vector3(0, current_turn_direction, 0))
		apply_force(forward_vector * (acceleration * 10) * (0.5 + (move_direction.length() * 0.5)))
	
	_update_physics(velocity)
	_update_visuals(delta)

func _update_physics(velocity: float, skip: bool = false) -> void:
	if !skip:
		speed_percentage = velocity / max_speed
		if velocity > 0 and down_ray.is_colliding():
			max_turn_velocity = default_max_turn_velocity + (2.5 - default_max_turn_velocity) * speed_percentage
			linear_damp = linear_damping + (1.0 - linear_damping) * speed_percentage
			gravity_scale = linear_damping
			car_entity.position.z = 0.9 - (2.2 * speed_percentage)
		else:
			linear_damp = 0.1
		
		current_turn_speed = lerpf(current_turn_speed, -current_turn_direction, 0.05)
		
		if abs(current_turn_speed) < 0.1:
			current_turn_speed = 0

func _update_visuals(delta: float) -> void:
	# Update chasis_entity orientation
	body.rotation_degrees.y = current_turn_speed * 2
	body.rotation_degrees.z = -current_turn_speed/2 
	
	# Update dust
	if down_ray.is_colliding():
		for cloud in dusts:
			cloud.process_material.set('scale_max', speed_percentage + .75)
			cloud.amount_ratio = speed_percentage
	else:
		for cloud in dusts:
			cloud.amount_ratio = 0
	
	# Update wheels
	for wheel in wheels:
		if (wheel.name.contains("f")):
			wheel.rotation_degrees = Vector3(0, current_turn_speed * -5.0, 0)
