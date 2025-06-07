extends Node3D
@export var sight = 10
@export var closestEnemy: EnemyPosition = EnemyPosition.new()
@export var fire_rate = 0.1
@export var rotation_speed = 5
var bullet = load("res://bullet.tscn")
var instance
var can_shoot = true
@onready var gun_barrel: Marker3D = $Barrel/Marker3D
@onready var barrel: Node3D = $Barrel

func find_closest_enemy():
	var closestDistance = 100
	var all_enemy = get_tree().get_nodes_in_group("enemy")
	
	if all_enemy.is_empty():
		closestEnemy = EnemyPosition.new()
	for enemy in all_enemy:
		var gun2enemy_distance = global_position.distance_to(enemy.global_position)
		if gun2enemy_distance < closestDistance:
			closestDistance = gun2enemy_distance
			closestEnemy.distance = gun2enemy_distance
			closestEnemy.position = enemy.global_position
		
func _process(delta):
	find_closest_enemy()
	
	if(closestEnemy and closestEnemy.distance < sight and closestEnemy.position != Vector3(0,0,0)):
		# Calculate direction to enemy in world space
		var direction = closestEnemy.position - global_position
		
		# Handle Y rotation for the base (horizontal aiming)
		var parent_forward = -get_parent().global_transform.basis.z
		var parent_angle = atan2(parent_forward.x, parent_forward.z)
		var target_angle = atan2(direction.x, direction.z)
		var relative_angle = target_angle - parent_angle - PI/2
		rotation.y = lerp_angle(rotation.y, relative_angle, rotation_speed * delta)
		
		# Calculate elevation angle for barrel (vertical aiming)
		# Convert world-space direction to local space
		var local_direction = global_transform.basis.inverse() * direction
		
		# Calculate the elevation angle needed
		var elevation_angle = atan2(-local_direction.y, sqrt(local_direction.x * local_direction.x + local_direction.z * local_direction.z))
		
		# Apply rotation to barrel (limit to reasonable range if needed)
		barrel.rotation.z = lerp_angle(barrel.rotation.z, elevation_angle, rotation_speed * delta)
		
		if can_shoot:
			instance = bullet.instantiate()
			instance.position = gun_barrel.global_position
			instance.rotation = gun_barrel.global_rotation 
			get_tree().current_scene.add_child(instance)
			can_shoot = false
			await get_tree().create_timer(fire_rate).timeout
			can_shoot = true
