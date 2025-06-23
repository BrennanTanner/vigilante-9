extends RigidBody3D

const MOVE_SPEED = 30.0
const MIN_DISTANCE = 1.0  # Distance of maximum magnetic force
const MAX_DISTANCE = 10.0 # Distance where magnetic force starts

var player: Node3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	contact_monitor = true
	max_contacts_reported = 1
	linear_damp = 1.0
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player:
		var distance = global_position.distance_to(player.global_position)
		if distance <= MAX_DISTANCE:
			var direction = (player.global_position - global_position).normalized()
			
			# Calculate force multiplier based on distance
			var force_multiplier = 1.0 - clamp(distance - MIN_DISTANCE, 0, MAX_DISTANCE - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE)
			apply_central_force(direction * MOVE_SPEED * force_multiplier)
			
func die()-> void:
	queue_free()
	
func _on_body_entered(body: Node) -> void:
	if body == player:
		player.expGain(1)
		die()
