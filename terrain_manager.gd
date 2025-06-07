extends Node3D

@export var chunk_size: float = 50.0
@export var view_distance: int = 2
@export var player: Node3D
@export var terrain_material: Material
# Dictionary to store active chunks
var active_chunks = {}

func _ready():
	if not player:
		# Try to find the player/camera
		player = get_tree().get_nodes_in_group("player")[0]
		if player:
			print("Found player node")
		else:
			push_warning("No player node assigned!")
	
	# Generate initial terrain
	if player:
		print("Generating initial terrain...")
		_update_terrain(player.position)

# Creates a single terrain chunk at the specified coordinates
func create_chunk(chunk_x: int, chunk_z: int) -> Node3D:
	var chunk = Node3D.new()
	chunk.name = "Chunk_%d_%d" % [chunk_x, chunk_z]
	
	# Create a flat mesh for the chunk
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(chunk_size, chunk_size)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(chunk_size, 0.1, chunk_size)  # Very thin box for collision
	collision_shape.shape = shape
	
	# Create visual mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = plane_mesh
	mesh_instance.material_override = terrain_material
	
	# Create static body for collision
	var static_body = StaticBody3D.new()
	static_body.add_child(collision_shape)
	static_body.set_collision_layer_value(3, true)
	# Add everything to the chunk
	chunk.add_child(mesh_instance)
	chunk.add_child(static_body)
	
	# Set the local position instead of global position
	chunk.position = Vector3(chunk_x * chunk_size, 0, chunk_z * chunk_size)
	
	return chunk

# Update terrain based on player position
func _update_terrain(player_pos: Vector3):
	var current_chunk_x = floor(player_pos.x / chunk_size)
	var current_chunk_z = floor(player_pos.z / chunk_size)
	
	# Keep track of chunks we want to keep
	var chunks_to_keep = {}
	
	# Generate/maintain chunks in view distance
	for x in range(current_chunk_x - view_distance, current_chunk_x + view_distance + 1):
		for z in range(current_chunk_z - view_distance, current_chunk_z + view_distance + 1):
			var chunk_key = "%d_%d" % [x, z]
			chunks_to_keep[chunk_key] = true
			
			if not active_chunks.has(chunk_key):
				var new_chunk = create_chunk(x, z)
				add_child(new_chunk)
				active_chunks[chunk_key] = new_chunk
	
	# Remove chunks that are out of range
	var chunks_to_remove = []
	for chunk_key in active_chunks:
		if not chunks_to_keep.has(chunk_key):
			chunks_to_remove.append(chunk_key)
	
	for chunk_key in chunks_to_remove:
		active_chunks[chunk_key].queue_free()
		active_chunks.erase(chunk_key)

func _process(_delta):
	if player:
		_update_terrain(player.position)
