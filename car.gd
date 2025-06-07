extends RigidBody3D

@export var acceleration : float = 35.0
@export var steering : float = 19.0
@export var turn_speed : float= 0.3
@export var turn_stop_limit : float = 0.75
@export var body_tilt : int = 35
@export var health : int = 100
@export var starting_gun : PackedScene
@export var air_rotation_speed : float = 2.0  # Speed for rotating in air
var sphere_offset = Vector3.DOWN
var exp = 0
var speed_input = 0
var turn_input = 0
var gun : Node3D
@onready var gun_mount = $"CarMesh/GunMount"
@onready var car_mesh : MeshInstance3D = $"CarMesh"
@onready var front_ray = $"CarMesh/RayFront"
@onready var back_ray = $"CarMesh/RayBack"

#@onready var car_mesh = $CarMesh
#@onready var body_mesh = $CarMesh/Drift
#@onready var front_ray = $CarMesh/RayFront
#@onready var back_ray = $CarMesh/RayBack
#@onready var right_wheel = $CarMesh/suv2/wheel_frontRight
#@onready var left_wheel = $CarMesh/suv2/wheel_frontLeft
#@onready var gun_mount = $CarMesh/GunMount

func _ready():
	if starting_gun != null:
		swap_gun(starting_gun)
	
func swap_gun(new_gun : PackedScene):
	if gun == null:
		gun = new_gun.instantiate()
		gun.position = gun_mount.position
		#body_mesh.add_child(gun)
	else:
		gun.queue_free()
		gun = new_gun.instantiate()
		gun.position = gun_mount.position
		#body_mesh.add_child(gun)
	
func _physics_process(delta):
	# Get joystick input (assuming joy.output is normalized)
	var joy: VirtualJoystick = get_node("../../Virtual joystick")
	var input_direction = Vector3(joy.output.x, 0, -joy.output.y)
	var joy_intensity = joy.output.length()  # Force intensity (between 0 and 1)

	# Check if joystick input is significant enough
	if input_direction.length() > 0.01:  # To avoid unnecessary rotation when input is near zero
		# Normalize the input direction
		input_direction = input_direction.normalized()

		# Calculate the target Y rotation angle based on the joystick direction
		var target_rotation_y = atan2(input_direction.x, -input_direction.z)  # Note the negative Z for the forward axis

		# Smoothly rotate the car_mesh to face the target direction
		car_mesh.rotation.y = lerp_angle(car_mesh.rotation.y, target_rotation_y, turn_speed * delta)  # turn_speed controls the rotation speed
			# Get the forward direction from the car_mesh's global transform
		var forward_direction = car_mesh.global_transform.basis.z  # Negative Z is forward in Godot

		apply_central_force(forward_direction * joy_intensity * acceleration)
func _process(delta):
	if not front_ray.is_colliding() or not back_ray.is_colliding():
		# Car is in the air - lerp to face downward
		var down_direction = Vector3.UP
		var down_transform = align_with_y(car_mesh.global_transform, down_direction)
		
		car_mesh.global_transform = car_mesh.global_transform.interpolate_with(down_transform, air_rotation_speed * delta)
		car_mesh.global_transform = car_mesh.global_transform.orthonormalized()
		return
		
	speed_input = Input.get_axis("brake", "accelerate") * acceleration
	turn_input = Input.get_axis("steer_right", "steer_left") * deg_to_rad(steering)
	#right_wheel.rotation.y = turn_input
	#left_wheel.rotation.y = turn_input
	
	var current_speed = linear_velocity.length()
	var mph: Label = get_node("../Label")
	mph.text = str(current_speed) + " MPH"
	if current_speed > turn_stop_limit:
		var current_turn_speed = current_speed * turn_speed # Adjust 0.1 to tune turn radius
		var new_basis = car_mesh.global_transform.basis.rotated(car_mesh.global_transform.basis.y, turn_input)
		car_mesh.global_transform.basis = car_mesh.global_transform.basis.slerp(new_basis, current_turn_speed * delta)
		car_mesh.global_transform = car_mesh.global_transform.orthonormalized()
		var t = -turn_input * linear_velocity.length() / body_tilt
		#body_mesh.rotation.z = lerp(body_mesh.rotation.z, t, 5.0 * delta)
		if front_ray.is_colliding():
			var n = front_ray.get_collision_normal()
			var xform = align_with_y(car_mesh.global_transform, n)
			car_mesh.global_transform = car_mesh.global_transform.interpolate_with(xform, 10.0 * delta)

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	return xform.orthonormalized()

func hit(damage):
	health -= damage
	
func expGain(gain):
	exp += gain
	print(exp)
