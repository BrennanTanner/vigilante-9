extends Camera3D

@export var target: Node3D

var offset: Vector3
var follow_body: Node3D
var speed: float = 0.1

func look_follow(state: PhysicsDirectBodyState3D, current_transform: Transform3D, target_position: Vector3) -> void:
	var forward_local_axis: Vector3 = Vector3(1, 0, 0)
	var forward_dir: Vector3 = (current_transform.basis * forward_local_axis).normalized()
	var target_dir: Vector3 = (target_position - current_transform.origin).normalized()
	var local_speed: float = clampf(speed, 0, acos(forward_dir.dot(target_dir)))
	print(local_speed)
	if forward_dir.dot(target_dir) > 1e-4:
		state.angular_velocity = local_speed * forward_dir.cross(target_dir) / state.step

func _integrate_forces(state):
	print(state)
	var target_position = target.global_transform.origin
	look_follow(state, global_transform, target_position)
	
func _ready():
	# Calculate the initial offset between the camera and the target
	follow_body = target.get_node('car/body')
	offset = global_position - follow_body.global_position

func _process(delta: float):
	
	# Update camera position to follow the target with the initial offset
	global_position = follow_body.global_position + offset
	
