extends RigidBody3D

@export var max_speed: float = 25.0
@export var speed: float = 10.0
@export var turn_speed: float = 5.0  # Increased for more responsive turning
@export var max_turn_velocity: float = 1.0
@export var angular_damping: float = 1.0
@export var chase_entity: Node3D
@export var wheels: Array[Node3D] = []

var current_turn_speed: float = 0.0
var current_turn_direction: float = 0.0
var target_angle: float = 0.0
var joystick_force: float = 0.0
var joystick_dead: bool = true

func _ready():
	if chase_entity == null:
		push_error("chase_entity not found, must be set!")
	gravity_scale = 2.0
	angular_damp = angular_damping
	

func shortest_rotation_direction(current: float, target: float) -> float:
	# Normalize angles to be between -180 and 180
	var angle_diff = target - current
	
	# Find the shortest rotation direction
	if angle_diff > 180:
		angle_diff -= 360
	elif angle_diff < -180:
		angle_diff += 360
	
	return sign(angle_diff)

func _physics_process(delta: float):
	# Simulating joystick input (replace with your actual input system)
	var joystick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var angle_in_radians = atan2(joystick.x, joystick.y)
	var angle_in_degrees = rad_to_deg(angle_in_radians)
	
	if joystick.x == 0 and joystick.y == 0:
		joystick_dead = true
		current_turn_direction = 0.0
		joystick_force = 0.0
	elif angle_in_degrees >= 0:
		joystick_dead = false
		target_angle = angle_in_degrees - 360.0
	else:
		joystick_dead = false
		target_angle = angle_in_degrees + 360.0
	
	joystick_force = sqrt(joystick.y * joystick.y + joystick.x * joystick.x)
	
	if !joystick_dead:
		var forward_vector = transform.basis.z
		var backward_vector = -transform.basis.z
		
		var velocity = linear_velocity.length()
		var turn_velocity = min(velocity, max_turn_velocity)
		
		var cur_ang_vec = get_global_rotation_degrees().y
		var angle_dif = target_angle - cur_ang_vec
		
		# Normalize angle difference
		while angle_dif > 180:
			angle_dif -= 360
		while angle_dif < -180:
			angle_dif += 360
		
		current_turn_direction = turn_speed * turn_velocity * (angle_dif / 180.0)
		
		# Apply torque and force
		apply_torque(Vector3(0, current_turn_direction, 0))
		apply_force(backward_vector * speed * joystick_force)
	
	# Update turn speed with interpolation
	current_turn_speed = lerp(
		current_turn_speed,
		-current_turn_direction / 3.0,
		0.05
	)
	
	if abs(current_turn_speed) < 0.1:
		current_turn_speed = 0

func _process(delta: float):
	# Update chase_entity orientation
	#if chase_entity:
		#chase_entity.rotation_degrees = Vector3(0, 0, current_turn_speed * 5.0)
		#var t = -current_turn_direction * linear_velocity.length() / 20
		#chase_entity.rotation.z = lerp(chase_entity.rotation.z, t, 10 * delta)
	
	# Update wheels
	for wheel in wheels:
		wheel.rotation.y = current_turn_direction
