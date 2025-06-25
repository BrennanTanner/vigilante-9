extends Node3D
## Controls any [Vehicle] node using custom-defined input maps.
class_name VehicleController

## The [Vehicle] that this vehicle controller will send
## input values to. Required for the vehicle controller to work properly.
@export var vehicle_node : Vehicle

# Rotation and angle tracking
var target_rotation_y: float = 0.0
var prev_target_rotation_y: float = 0.0
var target_angle_reached: bool = false
var angle_difference: float = 0.0

@onready var joy: VirtualJoystick = $"Virtual joystick"

func _physics_process(_delta):
	handle_steering(_delta)
	calculate_engine_force()

func handle_steering(delta):
	var input_direction = Vector3(-joy.output.x, 0, joy.output.y)
	
	# Store previous target rotation for comparison
	prev_target_rotation_y = target_rotation_y
	
	if input_direction.length() > 0.01:
		input_direction = input_direction.normalized()
		
		# Calculate target rotation and angle difference
		target_rotation_y = atan2(input_direction.x, -input_direction.z)
		angle_difference = wrapf(target_rotation_y - vehicle_node.global_rotation.y, -PI, PI)

		# Apply steering - ensure symmetrical behavior for left and right
		var steeringvalue = clamp(angle_difference, -PI/4, PI/4)
		vehicle_node.steering_input = steeringvalue
			
	else:
		vehicle_node.steering_input = lerp(vehicle_node.steering_input, 0.0, delta * 5.0)
		target_angle_reached = false

func calculate_engine_force():	
	vehicle_node.throttle_input = joy.output.length() 
