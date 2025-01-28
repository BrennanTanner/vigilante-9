extends Car
class_name PlayerCar

@export var horse: Node3D
@export var horse_max_speed: int = 12
@export var car: Node3D

var horse_animation: AnimationPlayer
var anim_idle: Animation
var anim_walk: Animation
var anim_run: Animation
var anim_lie: Animation
var target_angle: float = 0.0
var joystick_force: float = 0.0
var joystick_dead: bool = true
var in_car: bool = false

func _ready():
	if car_entity == null:
		push_error("car not found, must be set!")
	
	body = car_entity.get_node("body")
	wheels = car_entity.get_node("wheels").get_children()
	down_ray = car_entity.get_node("down_ray")
	dusts = car_entity.get_node("body/drift_smoke").get_children()
	default_max_turn_velocity = max_turn_velocity

func _physics_process(delta: float):

	var joystick = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var angle_in_radians = atan2(-joystick.x, -joystick.y)
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
		var cur_angle = get_global_rotation_degrees().y
		var angle_dif = target_angle - cur_angle
		
		# Normalize angle difference
		while angle_dif > 180:
			angle_dif -= 360
		while angle_dif < -180:
			angle_dif += 360
		
		current_turn_direction = (turn_speed * min(linear_velocity.length(), max_turn_velocity) * (angle_dif / 180))
	
	if in_car:
		apply_movement(Vector2(joystick.x, joystick.y), delta)
	else: 
		if down_ray.is_colliding():
			var direction = Vector3(
				Input.get_action_strength ("ui_left") - Input.get_action_strength("ui_right"),
 				0.0,
				Input.get_action_strength ("ui_up") - Input.get_action_strength ("ui_down")).normalized()
			var target_velocity = direction * horse_max_speed * joystick_force
			var velocity_error = target_velocity - linear_velocity
			var correction_impulse = velocity_error 
			horse.rotation.y = deg_to_rad(target_angle)
			apply_central_impulse (correction_impulse)
		
	update_horse()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		print("fire")
		
func update_horse() -> void:
	if in_car && horse.visible:
		horse.visible = false
		car.visible = true
		self.lock_rotation = false
		
	if !in_car && car.visible:
		car.visible = false
		horse.visible = true
		self.lock_rotation = true
		
