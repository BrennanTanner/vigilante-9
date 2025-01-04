extends RigidBody3D

@export var max_speed: float = 50.0
@export var acceleration: float = 10.0
@export var turn_speed: float = 7.0  # Increased for more responsive turning
@export var max_turn_velocity: float = 1.0
@export var angular_damping: float = 2.0
@export var linear_damping: float = 5.0
@export var body_entity: Node3D
@export var chasis_entity: Node3D
@export var ray_cast: RayCast3D
@export var wheels: Array[Node3D] = []


var current_turn_speed: float = 0.0
var current_turn_direction: float = 0.0
var default_max_turn_velocity: float = max_turn_velocity
var target_angle: float = 0.0
var joystick_force: float = 0.0
var joystick_dead: bool = true

func _ready():
	if chasis_entity == null:
		push_error("chase_entity not found, must be set!")
	gravity_scale = linear_damping
	angular_damp = angular_damping
	linear_damp = linear_damping

func _physics_process(delta: float):
	# Simulating joystick input (replace with your actual input system)
	var joystick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var angle_in_radians = atan2(-joystick.x, -joystick.y)
	var angle_in_degrees = rad_to_deg(angle_in_radians)
	var velocity = min(linear_velocity.length(), max_speed)
	
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

	if !joystick_dead and ray_cast.is_colliding():
		var forward_vector = transform.basis.z
		var backward_vector = -transform.basis.z
	
		var turn_velocity = min(velocity, max_turn_velocity)
		
		var cur_angle = get_global_rotation_degrees().y
		var angle_dif = target_angle - cur_angle
		
		# Normalize angle difference
		while angle_dif > 180:
			angle_dif -= 360
		while angle_dif < -180:
			angle_dif += 360
		
		current_turn_direction = (turn_speed * turn_velocity * (angle_dif / 180))
		
		# Apply torque and force
		apply_torque(Vector3(0, current_turn_direction, 0))
		apply_force(forward_vector * (acceleration * 10) * (0.5 + (joystick_force * 0.5)))
	
		# Adjust attributes based on speed percentage
	var speed_percentage = velocity / max_speed
	if velocity > 0 and ray_cast.is_colliding():
		max_turn_velocity = default_max_turn_velocity + (2.5 - default_max_turn_velocity) * speed_percentage
		linear_damp = linear_damping + (1.0 - linear_damping) * speed_percentage
		gravity_scale = linear_damping
		body_entity.position.z = 0.9 - (2.2 * speed_percentage)
	else:
		linear_damp = 0.1
		
	current_turn_speed = lerpf(current_turn_speed, -current_turn_direction, 0.05)
	
	if abs(current_turn_speed) < 0.1:
		current_turn_speed = 0

func _process(delta: float):
	# Update chasis_entity orientation
	if chasis_entity:
		chasis_entity.rotation_degrees = Vector3(0, 0, current_turn_speed*2)
		#var t = -current_turn_direction * linear_velocity.length() / 20
		#chasis_entity.rotation.z = lerp(chasis_entity.rotation.z, t, 10 * delta)
	
	# Update wheels
	for wheel in wheels:
		wheel.rotation_degrees =  Vector3(0, current_turn_speed * -5.0, 0)
