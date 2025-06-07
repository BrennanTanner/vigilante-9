# HexTileManager.gd
extends Node3D

# Hex grid constants - your tile is 115.4 wide on each side
const HEX_SIZE = 115.4
const SQRT_3 = sqrt(3.0)

# Distance between hex centers (flat-top hexagons)
const HEX_WIDTH = HEX_SIZE * 2.0
const HEX_HEIGHT = HEX_SIZE * SQRT_3

# Tile scene
@export var tile_scene_path: String = "res://tile.tscn"
var tile_scene: PackedScene

# Player reference
@export var player: Node3D

# Generation settings
@export var generation_radius: int = 2
@export var unload_distance: int = 4  # Tiles further than this get hidden/paused

# Hex coordinate system (using axial coordinates)
class HexCoord:
	var q: int
	var r: int
	
	func _init(q_val: int, r_val: int):
		q = q_val
		r = r_val
	
	func equals(other: HexCoord) -> bool:
		return q == other.q and r == other.r
	
	func get_string() -> String:
		return "(%d, %d)" % [q, r]
	
	func hash() -> int:
		return q * 10000 + r  # Increased multiplier for larger coordinate range

# Tile data structure
class HexTile:
	var coord: HexCoord
	var scene_instance: Node3D
	var is_active: bool = true
	var generation_seed: int  # Store seed for consistent regeneration if needed
	
	func _init(hex_coord: HexCoord):
		coord = hex_coord
		generation_seed = coord.hash()  # Use coordinate as seed

# Storage for all tiles (active and inactive)
var tiles: Dictionary = {}  # HexCoord hash -> HexTile
var current_player_hex: HexCoord
var active_tiles: Array[HexCoord] = []

func _ready():
	# Load the tile scene
	tile_scene = load(tile_scene_path)
	if not tile_scene:
		push_error("Could not load tile scene at: " + tile_scene_path)
		return
	
	# Initialize starting position
	if player:
		current_player_hex = world_to_hex(player.global_position)
	else:
		current_player_hex = HexCoord.new(0, 0)
	
	# Generate initial tiles
	generate_tiles_around_player()

func _process(_delta):
	if not player:
		return
		
	# Check if player moved to a different hex
	var new_hex = world_to_hex(player.global_position)
	if not new_hex.equals(current_player_hex):
		current_player_hex = new_hex
		update_tile_visibility()
		generate_tiles_around_player()

func world_to_hex(world_pos: Vector3) -> HexCoord:
	# Convert 3D world position to hex coordinates (using X and Z axes)
	# Flat-top hexagon conversion
	var x = world_pos.x
	var z = world_pos.z
	
	var q = (2.0/3.0 * x) / HEX_SIZE
	var r = (-1.0/3.0 * x + SQRT_3/3.0 * z) / HEX_SIZE
	
	return hex_round(q, r)

func hex_round(q: float, r: float) -> HexCoord:
	# Round fractional hex coordinates to nearest hex
	var s = -q - r
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	
	var q_diff = abs(rq - q)
	var r_diff = abs(rr - r)
	var s_diff = abs(rs - s)
	
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	
	return HexCoord.new(int(rq), int(rr))

func hex_to_world(hex_coord: HexCoord) -> Vector3:
	# Convert hex coordinates to 3D world position (flat-top)
	var x = HEX_SIZE * (3.0/2.0 * hex_coord.q)
	var z = HEX_SIZE * (SQRT_3/2.0 * hex_coord.q + SQRT_3 * hex_coord.r)
	return Vector3(x, 0, z)  # Y=0, adjust if your tiles have different height

func hex_distance(a: HexCoord, b: HexCoord) -> int:
	return (abs(a.q - b.q) + abs(a.q + a.r - b.q - b.r) + abs(a.r - b.r)) / 2

func get_hex_neighbors(hex_coord: HexCoord) -> Array[HexCoord]:
	# Get all 6 neighboring hex coordinates
	var neighbors: Array[HexCoord] = []
	var directions = [
		[1, 0],   # RIGHT
		[1, -1],  # UP_RIGHT
		[0, -1],  # UP_LEFT
		[-1, 0],  # LEFT
		[-1, 1],  # DOWN_LEFT
		[0, 1]    # DOWN_RIGHT
	]
	
	for dir in directions:
		neighbors.append(HexCoord.new(hex_coord.q + dir[0], hex_coord.r + dir[1]))
	
	return neighbors

func has_tile(coord: HexCoord) -> bool:
	return tiles.has(coord.hash())

func get_tile(coord: HexCoord) -> HexTile:
	return tiles.get(coord.hash())

func generate_tiles_around_player():
	# Generate tiles in a radius around the player using proper hex distance
	var tiles_to_generate: Array[HexCoord] = []
	
	print(get_current_tile_info())
	
	# Use proper hexagonal generation pattern
	for q in range(current_player_hex.q - generation_radius, current_player_hex.q + generation_radius + 1):
		for r in range(current_player_hex.r - generation_radius, current_player_hex.r + generation_radius + 1):
			var coord = HexCoord.new(q, r)
			# Use hex_distance instead of the s coordinate check
			if hex_distance(coord, current_player_hex) <= generation_radius:
				if not has_tile(coord):
					tiles_to_generate.append(coord)
	
	# Generate new tiles
	for coord in tiles_to_generate:
		generate_tile_at(coord)

func generate_tile_at(coord: HexCoord):
	var tile = HexTile.new(coord)
	
	# Create the tile instance
	var instance = tile_scene.instantiate()
	tile.scene_instance = instance
	
	# Position the tile in 3D space
	instance.global_position = hex_to_world(coord)
	
	# Add to scene
	add_child(instance)
	
	# Store the tile
	tiles[coord.hash()] = tile
	
	# Configure the tile (if your tile scene has setup methods)
	configure_tile(tile)
	
	print("Generated tile at ", coord.get_string())

func configure_tile(tile: HexTile):
	# Set up the tile with its coordinate-based seed for consistent generation
	var instance = tile.scene_instance
	
	# Set up unique color for this tile
	setup_tile_color(tile)
	
	# If your tile scene has methods to configure itself, call them here
	if instance.has_method("set_hex_coordinate"):
		instance.set_hex_coordinate(tile.coord.q, tile.coord.r)
	
	if instance.has_method("set_generation_seed"):
		instance.set_generation_seed(tile.generation_seed)
	
	# You can add more configuration here based on coordinate, distance from origin, etc.
	var distance_from_origin = hex_distance(tile.coord, HexCoord.new(0, 0))
	if instance.has_method("set_distance_from_origin"):
		instance.set_distance_from_origin(distance_from_origin)

func setup_tile_color(tile: HexTile):
	var instance = tile.scene_instance
	var mesh: MeshInstance3D = instance.get_node("collision/mesh")
	
	
	# Create a unique material for this tile (duplicate the original)
	var original_material: ShaderMaterial = mesh.get_active_material(0)
	var unique_material: ShaderMaterial = original_material.duplicate()
	
	# Use tile coordinates as seed for consistent colors
	var tile_seed = tile.coord.hash()
	var rng = RandomNumberGenerator.new()
	rng.seed = tile_seed
	
	## Generate a nice color using HSV for better color distribution
	#var hue = rng.randf()  # Random hue (0-1)
	#var saturation = rng.randf_range(0.6, 0.9)  # High saturation for vibrant colors
	#var value = rng.randf_range(0.7, 0.95)  # High value for bright colors
	#
	## Convert HSV to RGB
	#var color = Color.from_hsv(hue, saturation, value)
	#
	## Apply the unique color to the unique material
	#unique_material.albedo_color = color
	#
	## Set the unique material on the mesh
	#mesh.set_surface_override_material(0, unique_material)

func update_tile_visibility():
	# Hide/pause tiles that are too far, show/unpause nearby tiles
	var new_active_tiles: Array[HexCoord] = []
	
	# Check all existing tiles
	for coord_hash in tiles.keys():
		var tile = tiles[coord_hash]
		var distance = hex_distance(tile.coord, current_player_hex)
		
		if distance <= generation_radius:
			# Tile should be active
			if not tile.is_active:
				activate_tile(tile)
			new_active_tiles.append(tile.coord)
		elif distance <= unload_distance:
			# Tile should be inactive but kept in memory
			if tile.is_active:
				deactivate_tile(tile)
		else:
			# Tile is too far - could unload completely if needed
			if tile.is_active:
				deactivate_tile(tile)
			# Optionally unload completely:
			# unload_tile(tile)
	
	active_tiles = new_active_tiles

func activate_tile(tile: HexTile):
	# Make tile visible and active
	if tile.scene_instance:
		tile.scene_instance.visible = true
		tile.scene_instance.process_mode = Node.PROCESS_MODE_INHERIT
		
		# If your tile has custom activation logic
		if tile.scene_instance.has_method("on_tile_activated"):
			tile.scene_instance.on_tile_activated()
	
	tile.is_active = true
	print("Activated tile at ", tile.coord.get_string())

func deactivate_tile(tile: HexTile):
	# Hide and pause tile but keep in memory
	if tile.scene_instance:
		tile.scene_instance.visible = false
		tile.scene_instance.process_mode = Node.PROCESS_MODE_DISABLED
		
		# If your tile has custom deactivation logic
		if tile.scene_instance.has_method("on_tile_deactivated"):
			tile.scene_instance.on_tile_deactivated()
	
	tile.is_active = false
	print("Deactivated tile at ", tile.coord.get_string())

func unload_tile(tile: HexTile):
	# Completely remove tile from memory (optional - use if memory is a concern)
	if tile.scene_instance:
		tile.scene_instance.queue_free()
	
	tiles.erase(tile.coord.hash())
	print("Unloaded tile at ", tile.coord.get_string())

# Debug function to get current tile info
func get_current_tile_info() -> String:
	var info = "Player at hex: " + current_player_hex.get_string() + "\n"
	info += "Active tiles: " + str(active_tiles.size()) + "\n"
	info += "Total tiles in memory: " + str(tiles.size())
	return info

# Function to force regeneration around current position (for testing)
func force_regenerate_area():
	generate_tiles_around_player()
	update_tile_visibility()

# Alternative generation method using ring-based approach (more efficient for large radii)
func generate_tiles_around_player_rings():
	# Generate tiles using ring-by-ring approach (more efficient)
	var tiles_to_generate: Array[HexCoord] = []
	
	print(get_current_tile_info())
	
	# Generate center tile
	if not has_tile(current_player_hex):
		tiles_to_generate.append(current_player_hex)
	
	# Generate rings from 1 to generation_radius
	for ring in range(1, generation_radius + 1):
		var ring_coords = get_hex_ring(current_player_hex, ring)
		for coord in ring_coords:
			if not has_tile(coord):
				tiles_to_generate.append(coord)
	
	# Generate new tiles
	for coord in tiles_to_generate:
		generate_tile_at(coord)

func get_hex_ring(center: HexCoord, radius: int) -> Array[HexCoord]:
	# Get all hexes in a ring at the specified radius from center
	var results: Array[HexCoord] = []
	
	if radius == 0:
		results.append(center)
		return results
	
	# Start at the "bottom-left" hex of the ring
	var hex = HexCoord.new(center.q - radius, center.r + radius)
	
	# The six directions for moving around the ring
	var directions = [
		[1, -1],  # UP_RIGHT
		[0, -1],  # UP_LEFT  
		[-1, 0],  # LEFT
		[-1, 1],  # DOWN_LEFT
		[0, 1],   # DOWN_RIGHT
		[1, 0]    # RIGHT
	]
	
	# Walk around the ring
	for direction in directions:
		for i in range(radius):
			results.append(hex)
			hex = HexCoord.new(hex.q + direction[0], hex.r + direction[1])
	
	return results
