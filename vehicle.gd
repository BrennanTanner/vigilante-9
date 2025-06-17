extends VehicleBody3D
class_name Car

# Configuration parameters
@export var max_steering_angle: float = 0.75  # Maximum steering range at low speeds
@export var base_engine_power: float = 500
@export var base_friction_slip: float = 0.75
@export var min_friction_slip: float = 0.2
@export var high_friction_slip: float = 0.8  # Higher friction when target angle is reached
@export var body_tilt_factor: float = 0.01  # How much the car body tilts during turns
@export var angle_change_threshold: float = 0.1  # Threshold to detect significant angle changes
@export var health: int = 100
@export var starting_gun: PackedScene

# Rotation and angle tracking
var target_rotation_y: float = 0.0
var prev_target_rotation_y: float = 0.0
var target_angle_reached: bool = false
var angle_difference: float = 0.0

# References
var gun: Node3D
@onready var gun_mount: Marker3D = $"CarMesh/GunMount"
@onready var body_mesh: MeshInstance3D = $"CarMesh"
@onready var joy: VirtualJoystick = $"Virtual joystick"

func _ready():
	if starting_gun != null:
		swap_gun(starting_gun)

func _process(delta):
	var label: Label = get_node("../Label")
	label.text = str(int(linear_velocity.length())) + " MPH"
	# Handle visual body tilt based on steering angle and speed
	var desired_tilt = clampf(steering * body_tilt_factor * linear_velocity.length(), -0.4, 0.4)
	body_mesh.rotation.z = lerp(body_mesh.rotation.z, desired_tilt, delta * 10)

func _physics_process(delta):
	handle_steering(delta)
	apply_wheel_friction()
	calculate_engine_force()

func handle_steering(delta):
	var input_direction = Vector3(joy.output.x, 0, -joy.output.y)
	
	# Store previous target rotation for comparison
	prev_target_rotation_y = target_rotation_y
	
	if input_direction.length() > 0.01:
		input_direction = input_direction.normalized()
		
		# Calculate target rotation and angle difference
		target_rotation_y = atan2(input_direction.x, -input_direction.z)
		angle_difference = wrapf(target_rotation_y - global_rotation.y, -PI, PI)
		
		# Check if target angle has changed significantly
		var target_angle_change = absf(wrapf(target_rotation_y - prev_target_rotation_y, -PI, PI))
		if target_angle_change > angle_change_threshold:
			target_angle_reached = false  # Reset as we have a new target
		
		# Apply steering - ensure symmetrical behavior for left and right
		var steeringvalue = clamp(angle_difference, -max_steering_angle, max_steering_angle)
		

		steering = steeringvalue
		# Check if we've reached the target angle
		if abs(angle_difference) < angle_change_threshold:
			target_angle_reached = true
	else:
		steering = lerp(steering, 0.0, delta * 5.0)
		target_angle_reached = false

func apply_wheel_friction():
	var friction_slip: float
	#var front_slip: float = 
	var front_slip = 1.1 - (linear_velocity.length() / 100.0) * 0.3

	if target_angle_reached:
		# Higher friction to prevent overcorrection when target is reached
		friction_slip = high_friction_slip
	else:
		# Gradually reduce friction as angle difference increases (for better turning)
		# This ensures symmetrical behavior for both left and right turns
		var angle_diff_factor = abs(angle_difference) / PI
		friction_slip = base_friction_slip - angle_diff_factor * (base_friction_slip - min_friction_slip)
	# Apply friction to drive wheels - ensure all wheels get updated properly
	for wheel in get_children():
		if wheel is VehicleWheel3D and not wheel.use_as_steering:
			wheel.wheel_friction_slip = friction_slip
		elif wheel is VehicleWheel3D and wheel.use_as_steering:
			pass#wheel.wheel_friction_slip = front_slip

func calculate_engine_force():
	var steering_factor = abs(steering) / max_steering_angle  # 0 to 1 based on steering intensity
	var power_boost = base_engine_power * steering_factor
	engine_force = joy.output.length() * (base_engine_power + power_boost)

func swap_gun(new_gun: PackedScene):
	if gun != null:
		gun.queue_free()
	
	gun = new_gun.instantiate()
	gun.position = gun_mount.position
	add_child(gun)

func hit(damage):
	health -= damage
	if health <= 0:
		handle_destruction()

func handle_destruction():
	# Implement car destruction logic here
	print("Car destroyed!")

# Experience system - placeholder for future implementation
func expGain(amount):
	# Implement experience system here
	print("Gained " + str(amount) + " experience")
