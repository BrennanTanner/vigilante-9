extends RigidBody3D

## Vehicle configuration parameters
@export_group("Vehicle Properties")
@export var wheel_base: float = 0.6  # Distance between front/rear axles
@export var steering_limit: float = 10.0  # Front wheel max turning angle (degrees)
@export var engine_power: float = 600.0
@export var turning_speed: float = 5.0
@export var brake_power: float = 50.0

@export_group("Drift Properties")
@export var drift_threshold: float = 15.0  # Speed at which drifting begins
@export var traction_slow: float = 0.75  # Traction coefficient at low speeds
@export var traction_fast: float = 0.02  # Traction coefficient at high speeds
@export var drift_traction_multiplier: float = 0.2  # How much traction is reduced while drifting

# Protected variables for child classes
var _input_vector: Vector2 = Vector2.ZERO
var _target_angle: float = 0.0
var _current_angle: float = 0.0
var _is_drifting: bool = false
var _steer_angle: float = 0.0

# Wheel node paths for easier reference
@onready var _front_right_wheel: Node3D = $"truck/wheel-front-right" if has_node("truck/wheel-front-right") else null
@onready var _front_left_wheel: Node3D = $"truck/wheel-front-left" if has_node("truck/wheel-front-left") else null

func _ready() -> void:
	_configure_physics()

func _physics_process(delta: float) -> void:
	get_input()  # Virtual method to be implemented by child classes
	_handle_steering(delta)
	_apply_movement_forces(delta)
	_update_wheel_visuals()

func _configure_physics() -> void:
	gravity_scale = 3.0
	angular_damp = 3.0

# Virtual method to be overridden by child classes
func get_input() -> void:
	pass

func _handle_steering(delta: float) -> void:
	if _input_vector.is_zero_approx():
		return
	
	_target_angle = rad_to_deg(atan2(_input_vector.x, _input_vector.y))
	_current_angle = rad_to_deg(rotation.y)
	
	var angle_difference = _clamp_angle(_target_angle - _current_angle)
	var turn_force = angle_difference / 180.0 * turning_speed
	
	# Only apply turning force if the vehicle is moving
	if linear_velocity.length() > 0.1:
		apply_torque(Vector3.UP * turn_force * engine_power * delta)

func _apply_movement_forces(delta: float) -> void:
	if _input_vector.is_zero_approx():
		_apply_friction()
		return
	
	var speed = linear_velocity.length()
	var forward_direction = -transform.basis.z
	var forward_force = forward_direction * engine_power * _input_vector.length()
	
	# Calculate traction based on speed
	var traction = _calculate_traction(speed)
	_is_drifting = speed > drift_threshold
	
	# Apply forward force with traction
	apply_force(forward_force * traction)
	
	# Apply lateral friction
	_apply_friction()

func _apply_friction() -> void:
	var right_velocity = transform.basis.x.dot(linear_velocity)
	var friction_multiplier = 1.0 if _is_drifting else 5.0
	var lateral_friction = -transform.basis.x * right_velocity * friction_multiplier
	apply_force(lateral_friction)

func _calculate_traction(speed: float) -> float:
	if speed <= drift_threshold:
		return traction_slow
	
	var t = (speed - drift_threshold) / 10.0
	return lerp(traction_slow, traction_fast, t)

func _update_wheel_visuals() -> void:
	if not _front_left_wheel or not _front_right_wheel:
		return
		
	_steer_angle = _input_vector.x * deg_to_rad(steering_limit)
	_front_right_wheel.rotation.y = _steer_angle
	_front_left_wheel.rotation.y = _steer_angle

func _clamp_angle(angle: float) -> float:
	return fmod(angle + 180.0, 360.0) - 180.0

func _lerp_angle(from: float, to: float, weight: float) -> float:
	return from + _clamp_angle(to - from) * weight

# Public getters
func get_current_angle() -> float:
	return _current_angle

func get_target_angle() -> float:
	return _target_angle

func get_steering_angle() -> float:
	return _steer_angle

func is_drifting() -> bool:
	return _is_drifting
