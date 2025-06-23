extends VehicleBody3D
class_name Car

# Configuration parameters
@export var max_steering_angle: float = 0.75  # Maximum steering range at low speeds
@export var base_engine_power: float = 300
@export var base_friction_slip: float = 0.75
@export var min_friction_slip: float = 0.2
@export var high_friction_slip: float = 0.8  # Higher friction when target angle is reached
@export var body_tilt_factor: float = 0.01  # How much the car body tilts during turns
@export var angle_change_threshold: float = 0.1  # Threshold to detect significant angle changes
@export var health: int = 100
@export var starting_gun: PackedScene

# Debug visualization parameters
@export var debug_enabled: bool = true
@export var debug_line_length: float = 2.0
@export var debug_text_offset: Vector3 = Vector3(0, 1, 0)

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

# Debug arrays to store wheel references and debug info
var wheels: Array[VehicleWheel3D] = []
var debug_labels: Array[Label3D] = []

func _ready():
	if starting_gun != null:
		swap_gun(starting_gun)
	
	# Collect all wheel references and setup debug
	setup_wheel_debug()

func setup_wheel_debug():
	# Find all VehicleWheel3D children
	for child in get_children():
		if child is VehicleWheel3D:
			wheels.append(child)
			
			# Create debug label for each wheel
			if debug_enabled:
				var label = Label3D.new()
				label.text = "Wheel " + str(wheels.size() - 1)
				label.position = child.position + debug_text_offset
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.font_size = 30
				add_child(label)
				debug_labels.append(label)

func _process(delta):
	var label: Label = get_node("../Label")
	label.text = str(int(linear_velocity.length())) + " MPH"
	
	# Handle visual body tilt based on steering angle and speed
	var desired_tilt = clampf(steering * body_tilt_factor * linear_velocity.length(), -0.4, 0.4)
	body_mesh.rotation.z = lerp(body_mesh.rotation.z, desired_tilt, delta * 10)
	
	# Update debug information
	if debug_enabled:
		update_wheel_debug()

func update_wheel_debug():
	for i in range(wheels.size()):
		var wheel = wheels[i]
		var label = debug_labels[i]
		
		# Get wheel data
		var rpm = wheel.get_rpm()
		var skid_info = wheel.get_skidinfo()
		var is_contact = wheel.is_in_contact()
		var contact_point = wheel.get_contact_point() if is_contact else Vector3.ZERO
		var contact_normal = wheel.get_contact_normal() if is_contact else Vector3.ZERO
		
		# Calculate wheel speed in world units
		var wheel_speed = abs(rpm) * wheel.wheel_radius * PI / 30.0  # Convert RPM to linear speed
		
		# Update label text with comprehensive wheel info
		var debug_text = "Wheel %d\n" % i
		debug_text += "RPM: %.1f\n" % rpm
		debug_text += "Speed: %.1f\n" % wheel_speed
		debug_text += "Skid: %.2f\n" % skid_info
		debug_text += "Contact: %s\n" % ("Yes" if is_contact else "No")
		debug_text += "Steering: %.2f\n" % wheel.steering
		debug_text += "Engine: %.1f\n" % wheel.engine_force
		debug_text += "Brake: %.1f\n" % wheel.brake
		debug_text += "Friction: %.2f" % wheel.wheel_friction_slip
		
		label.text = debug_text

func _physics_process(delta):
	handle_steering(delta)
	calculate_engine_force()
	
	# Draw debug lines in physics process for accuracy
	if debug_enabled:
		draw_wheel_debug_lines()

func draw_wheel_debug_lines():
	# Clear previous debug draws
	for i in range(wheels.size()):
		var wheel = wheels[i]
		var wheel_pos = wheel.global_position
		
		# Get wheel direction (forward direction of the wheel)
		var wheel_transform = wheel.global_transform
		var wheel_forward = -wheel_transform.basis.z  # Forward direction
		var wheel_right = wheel_transform.basis.x     # Right direction (for steering visualization)
		
		# Calculate actual wheel velocity
		var rpm = wheel.get_rpm()
		var wheel_speed = abs(rpm) * wheel.wheel_radius * PI / 30.0
		
		# Color coding for different states
		var speed_color = Color.GREEN if wheel_speed > 1.0 else Color.YELLOW
		var contact_color = Color.BLUE if wheel.is_in_contact() else Color.RED
		var steering_color = Color.MAGENTA if abs(wheel.steering) > 0.1 else Color.WHITE
		
		# Draw speed vector (forward direction, length based on speed)
		var speed_end = wheel_pos + wheel_forward * min(wheel_speed * 0.1, debug_line_length)
		DebugDraw3D.draw_line(wheel_pos, speed_end, speed_color)
		
		# Draw steering direction (perpendicular to forward, shows steering angle)

		var steering_end = wheel_pos + wheel_right
		DebugDraw3D.draw_line(wheel_pos, steering_end, steering_color)
		
		# Draw contact point and normal if in contact
		if wheel.is_in_contact():
			var contact_point = wheel.get_contact_point()
			var contact_normal = wheel.get_contact_normal()
			
			# Draw contact point
			DebugDraw3D.draw_sphere(contact_point, 0.1, contact_color)
			
			# Draw contact normal
			var normal_end = contact_point + contact_normal * debug_line_length * 0.5
			DebugDraw3D.draw_line(contact_point, normal_end, contact_color)
		
		# Draw wheel center for reference
		DebugDraw3D.draw_sphere(wheel_pos, 0.05, Color.WHITE)
		
		# Draw suspension compression visualization
		var suspension_compression = 1.0 - (wheel.wheel_rest_length / wheel.suspension_travel)
		var compression_color = Color.GREEN.lerp(Color.RED, suspension_compression)
		var suspension_end = wheel_pos + Vector3.DOWN * suspension_compression * debug_line_length * 0.3
		DebugDraw3D.draw_line(wheel_pos, suspension_end, compression_color)

func handle_steering(delta):
	var input_direction = Vector3(joy.output.x, 0, -joy.output.y)
	
	# Store previous target rotation for comparison
	prev_target_rotation_y = target_rotation_y
	
	if input_direction.length() > 0.01:
		input_direction = input_direction.normalized()
		
		# Calculate target rotation and angle difference
		target_rotation_y = atan2(input_direction.x, -input_direction.z)
		angle_difference = wrapf(target_rotation_y - global_rotation.y, -PI, PI)
		# Apply steering - ensure symmetrical behavior for left and right
		var steeringvalue = clamp(angle_difference, -PI/4, PI/4)
		steering = steeringvalue
			
	else:
		steering = lerp(steering, 0.0, delta * 5.0)
		target_angle_reached = false

func calculate_engine_force():	
	engine_force = joy.output.length() * base_engine_power 

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

# Debug control functions
func toggle_debug():
	debug_enabled = !debug_enabled
	for label in debug_labels:
		label.visible = debug_enabled

func set_debug_line_length(length: float):
	debug_line_length = length
