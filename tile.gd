extends StaticBody3D
class_name Tile

# Tile information set by the manager
var hex_q: int = 0
var hex_r: int = 0
var generation_seed: int = 0
var distance_from_origin: int = 0

# Called by HexTileManager when tile is created
func set_hex_coordinate(q: int, r: int):
	hex_q = q
	hex_r = r
	
	# You can use coordinates for tile-specific logic
	setup_tile_based_on_coordinates()

func set_generation_seed(gSeed: int):
	generation_seed = gSeed
	# Use this seed for consistent random generation within this tile

func set_distance_from_origin(distance: int):
	distance_from_origin = distance
	# You could use this to change tile properties based on distance

# Called when tile becomes active (player approaches)
func on_tile_activated():
	print("Tile (%d, %d) activated" % [hex_q, hex_r])
	# Resume any animations, sounds, or processes
	# Enable any gameplay elements

# Called when tile becomes inactive (player moves away)
func on_tile_deactivated():
	print("Tile (%d, %d) deactivated" % [hex_q, hex_r])
	# Pause animations, sounds, or processes to save performance
	# Disable gameplay elements but preserve state

func setup_tile_based_on_coordinates():
	# Example: Use coordinates to determine tile variation
	var tile_variant = (abs(hex_q) + abs(hex_r)) % 3
	
	# You could change materials, spawn different objects, etc.
	match tile_variant:
		0:
			setup_grass_tile()
		1:
			setup_forest_tile()
		2:
			setup_mountain_tile()

func setup_grass_tile():
	# Configure this tile as grassland
	pass

func setup_forest_tile():
	# Configure this tile as forest
	pass

func setup_mountain_tile():
	# Configure this tile as mountain
	pass

# Get the world position of this tile's center
func get_tile_center() -> Vector3:
	return global_position

# Check if a world position is within this tile's bounds
func contains_point(point: Vector3) -> bool:
	var local_point = to_local(point)
	# Simple circular check - adjust based on your tile shape
	var distance = Vector2(local_point.x, local_point.z).length()
	return distance <= 115.4  # Your hex size

# Get hex coordinate as string for debugging
func get_hex_string() -> String:
	return "(%d, %d)" % [hex_q, hex_r]
