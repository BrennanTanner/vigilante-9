@tool
extends StaticBody3D
class_name InfiniteTerrain

@export var player: Node3D

@export_category("Terrain")
@export var generate_terrain := true
@export var use_terrain_noise := true
@export var terrain_noise: FastNoiseLite
@export var terrain_noise_large: FastNoiseLite
@export_enum("Add", "Sub", "Mult", "Pow") var terrain_large_function = 0
@export var terrain_chunk_size: float = 30.0
@export var chunk_radius: int = 20
@export var chunk_subdivisor: int = 12
@export var terrain_height_multiplier := 300.0
@export var two_colors := true
@export var terrain_color_steepness_curve: Curve
@export var terrain_level_color: Color = Color.DARK_OLIVE_GREEN
@export var terrain_cliff_color: Color = Color.DIM_GRAY
@export var mountain_mode := false
@export var mountain_strength: float = 0.01
@export var use_equation := false
@export var terrain_material: ShaderMaterial

@export_category("Path")
@export var use_paths := false
@export var path_noise: FastNoiseLite
@export var path_curve: Curve
@export var path_smooth_radius: float = 10.0
@export var path_color: Color = Color.TAN

@export_category("Path Generation")
@export var path_grid_resolution: float = 5.0  # Distance between path points
@export var height_weight_curve: Curve  # Curve to control height-based weighting
@export var min_weight: float = 1.0
@export var max_weight: float = 10.0

var current_player_chunk: Vector2i:
	set(value):
		if current_player_chunk:
			if current_player_chunk != value:
				_player_in_new_chunk()
		current_player_chunk = value
var mesh_dict: Dictionary = {}
var collider_dict: Dictionary = {}
var multimesh_dict: Dictionary = {}
var big_mesh: MeshInstance3D

var mutex: Mutex
var semaphore: Semaphore
var thread: Thread
var exit_thread := false
var queue_thread := false
var load_counter: int = 0

var astar: AStar3D
var current_path: PackedVector3Array
var path_line: Node3D
var chunk_astar_points: Dictionary = {}  # chunk -> array of point IDs
var astar_point_positions: Dictionary = {}  # point_id -> Vector3 position
var next_point_id: int = 0

func _enter_tree():
	# Initialization of the plugin goes here.
	pass


func _ready():
	if generate_terrain and not Engine.is_editor_hint():
		astar = AStar3D.new()
		mutex = Mutex.new()
		semaphore = Semaphore.new()
		exit_thread = true

		thread = Thread.new()
		thread.start(_thread_function, Thread.PRIORITY_HIGH)

		for x in range(-chunk_radius, chunk_radius + 1):
			for y in range(-chunk_radius, chunk_radius + 1):
				var newmesh_and_mm = generate_terrain_mesh(Vector2i(x, y))
				if newmesh_and_mm:
					var newmesh = newmesh_and_mm[0]
					newmesh.add_to_group("do_not_own")
					add_child(newmesh)
				var newcollider = generate_terrain_collision(Vector2i(x, y))
				if newcollider:
					newcollider.add_to_group("do_not_own")
					add_child(newcollider)
					newcollider.rotation.y = -PI / 2.0
					newcollider.global_position = Vector3(
						x * terrain_chunk_size, 0.0, y * terrain_chunk_size
					)
		generate_path_to_target(Vector3(20000, 0, -20000))
func _process(delta):
	if player and generate_terrain and not Engine.is_editor_hint():
		var player_pos_3d = (
			player.global_position.snapped(
				Vector3(terrain_chunk_size, terrain_chunk_size, terrain_chunk_size)
			)
			/ terrain_chunk_size
		)
		current_player_chunk = Vector2i(player_pos_3d.x, player_pos_3d.z)
		
		if queue_thread:
			if exit_thread:
				#print(current_car_chunk)
				exit_thread = false
				semaphore.post()
				queue_thread = false


func _physics_process(delta):
	pass


func get_terrain_height(pos_x: float, pos_z: float) -> float:
	var spawn_pos_xz = Vector2(pos_x, pos_z)
	var nval_spawn = sample_2dv(spawn_pos_xz)
	return nval_spawn * terrain_height_multiplier


func _player_in_new_chunk():
	generate_path_to_target(Vector3(20000, 0, -20000))
	if exit_thread:
		exit_thread = false
		semaphore.post()
	else:
		#print("thread busy")
		queue_thread = true


func _thread_function():
	## relevant data: mesh_dict, current_player_chunk, exit_thread
	while true:
		semaphore.wait()

		mutex.lock()
		var should_exit = exit_thread
		mutex.unlock()

		if should_exit:
			break

		mutex.lock()
		load_counter += 1

		var ccc = current_player_chunk

		if load_counter < 20:
			for ix in range(-chunk_radius, chunk_radius + 1):
				var x = ccc.x + ix
				for iy in range(-chunk_radius, chunk_radius + 1):
					var y = ccc.y + iy
					if use_terrain_noise:
						var newmesh_and_mm = generate_terrain_mesh(Vector2i(x, y))
						if newmesh_and_mm:
							var newmesh = newmesh_and_mm[0]
							newmesh.call_deferred("add_to_group", "do_not_own")
							call_deferred("add_child", newmesh)
						var newcollider = generate_terrain_collision(Vector2i(x, y))
						if newcollider:
							newcollider.call_deferred("add_to_group", "do_not_own")
							call_deferred("add_child", newcollider)
							newcollider.call_deferred("rotate_y", -PI / 2.0)
							newcollider.call_deferred(
								"set_global_position",
								Vector3(x * terrain_chunk_size, 0.0, y * terrain_chunk_size)
							)
		else:
			load_counter = 0

# remove distant meshes AND A* points
		for k: Vector2i in mesh_dict.keys():
			if absi(ccc.x - k.x) > chunk_radius or absi(ccc.y - k.y) > chunk_radius:
				var mesh_to_remove = mesh_dict[k]
				if use_terrain_noise and collider_dict.has(k):
					var col_to_remove = collider_dict[k]
					collider_dict.erase(k)
					col_to_remove.call_deferred("queue_free")
				
				# Remove A* points for this chunk
				call_deferred("remove_chunk_astar_points", k)
				
				mesh_dict.erase(k)
				mesh_to_remove.call_deferred("queue_free")

		mutex.unlock()

		mutex.lock()
		exit_thread = true
		mutex.unlock()


func generate_terrain_mesh(chunk: Vector2i):
	if not mesh_dict.has(chunk):
		# Your existing mesh generation code here...
		var new_mesh = MeshInstance3D.new()
		var chunkmesh = new_mesh
		mesh_dict[chunk] = chunkmesh

		# Generate A* points for this chunk
		generate_astar_points_for_chunk(chunk)

		# ... rest of your existing mesh generation code
		var multimesh_positions: PackedVector3Array = []

		var arrmesh = ArrayMesh.new()

		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)

		var verts: PackedVector3Array = []
		var uvs: PackedVector2Array = []
		var norms: PackedVector3Array = []
		var colors: PackedColorArray = []
		var indices: PackedInt32Array = []

		var chunk_x = float(chunk.x)
		var chunk_z = float(chunk.y)

		var chunk_center = Vector2(chunk_x * terrain_chunk_size, chunk_z * terrain_chunk_size)

		var start_x = chunk_center.x - (terrain_chunk_size * 0.5)
		var start_z = chunk_center.y - (terrain_chunk_size * 0.5)

		var end_x = chunk_center.x + (terrain_chunk_size * 0.5)
		var end_z = chunk_center.y + (terrain_chunk_size * 0.5)

		var four_counter: int = 0

		var chunk_subdivisions = int(terrain_chunk_size / chunk_subdivisor)

		for x_division in chunk_subdivisions:
			var progress_x = float(x_division) / float(chunk_subdivisions)
			var x_coord = lerp(start_x, end_x, progress_x)

			var progress_x_next = float(x_division + 1) / float(chunk_subdivisions)
			var x_coord_next = lerp(start_x, end_x, progress_x_next)
			for z_division in chunk_subdivisions:
				var progress_z = float(z_division) / float(chunk_subdivisions)
				var z_coord = lerp(start_z, end_z, progress_z)

				var progress_z_next = float(z_division + 1) / float(chunk_subdivisions)
				var z_coord_next = lerp(start_z, end_z, progress_z_next)

				var uv_scale = 500.0 / terrain_chunk_size

				var coord_2d = Vector2(x_coord, z_coord)
				var nval = sample_2dv(coord_2d)

				var coord_2d_next_x = Vector2(x_coord_next, z_coord)
				var nval_next_x = sample_2dv(coord_2d_next_x)

				var coord_2d_next_z = Vector2(x_coord, z_coord_next)
				var nval_next_z = sample_2dv(coord_2d_next_z)

				var coord_2d_next_xz = Vector2(x_coord_next, z_coord_next)
				var nval_next_xz = sample_2dv(coord_2d_next_xz)

				if mountain_mode:
					nval -= generate_mountain_y(coord_2d)
					nval_next_x -= generate_mountain_y(coord_2d_next_x)
					nval_next_z -= generate_mountain_y(coord_2d_next_z)
					nval_next_xz -= generate_mountain_y(coord_2d_next_xz)

				var coord_3d = Vector3(x_coord, nval * terrain_height_multiplier, z_coord)
				var norm1 = _generate_noise_normal(coord_2d)
				var uv1 = Vector2(progress_x, progress_z) / uv_scale

				var coord_3d_next_x = Vector3(
					x_coord_next, nval_next_x * terrain_height_multiplier, z_coord
				)
				var norm2 = _generate_noise_normal(coord_2d_next_x)
				var uv2 = Vector2(progress_x_next, progress_z) / uv_scale

				var coord_3d_next_z = Vector3(
					x_coord, nval_next_z * terrain_height_multiplier, z_coord_next
				)
				var norm3 = _generate_noise_normal(coord_2d_next_z)
				var uv3 = Vector2(progress_x, progress_z_next) / uv_scale

				var coord_3d_next_xz = Vector3(
					x_coord_next, nval_next_xz * terrain_height_multiplier, z_coord_next
				)
				var norm4 = _generate_noise_normal(coord_2d_next_xz)
				var uv4 = Vector2(progress_x_next, progress_z_next) / uv_scale

				var color1: Color
				var color2: Color
				var color3: Color
				var color4: Color

				if two_colors:
					var steepness1 = clampf(Vector3.UP.dot(norm1), 0.0, 1.0)
					steepness1 = terrain_color_steepness_curve.sample_baked(steepness1)

					var steepness2 = clampf(Vector3.UP.dot(norm2), 0.0, 1.0)
					steepness2 = terrain_color_steepness_curve.sample_baked(steepness2)

					var steepness3 = clampf(Vector3.UP.dot(norm3), 0.0, 1.0)
					steepness3 = terrain_color_steepness_curve.sample_baked(steepness3)

					var steepness4 = clampf(Vector3.UP.dot(norm4), 0.0, 1.0)
					steepness4 = terrain_color_steepness_curve.sample_baked(steepness4)

					color1 = terrain_cliff_color.lerp(terrain_level_color, steepness1)
					color2 = terrain_cliff_color.lerp(terrain_level_color, steepness2)
					color3 = terrain_cliff_color.lerp(terrain_level_color, steepness3)
					color4 = terrain_cliff_color.lerp(terrain_level_color, steepness4)
				else:
					color1 = terrain_level_color
					color2 = terrain_level_color
					color3 = terrain_level_color
					color4 = terrain_level_color

				if use_paths:
					color1 = color1.lerp(path_color, 1.0 - get_path_effect(coord_2d))
					color2 = color2.lerp(path_color, 1.0 - get_path_effect(coord_2d_next_x))
					color3 = color3.lerp(path_color, 1.0 - get_path_effect(coord_2d_next_z))
					color4 = color4.lerp(path_color, 1.0 - get_path_effect(coord_2d_next_xz))

				verts.append(coord_3d)
				norms.append(norm1)
				uvs.append(uv1)
				colors.append(color1)

				verts.append(coord_3d_next_x)
				norms.append(norm2)
				uvs.append(uv2)
				colors.append(color2)

				verts.append(coord_3d_next_z)
				norms.append(norm3)
				uvs.append(uv3)
				colors.append(color3)

				verts.append(coord_3d_next_xz)
				norms.append(norm4)
				uvs.append(uv4)
				colors.append(color4)

				indices.append_array(
					[
						four_counter + 0,
						four_counter + 1,
						four_counter + 3,
						four_counter + 3,
						four_counter + 2,
						four_counter + 0
					]
				)

				four_counter += 4

		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices

		arrmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		chunkmesh.mesh = arrmesh

		chunkmesh.set_surface_override_material(0, terrain_material)

		return [chunkmesh]
	else:
		return false

func generate_astar_points_for_chunk(chunk: Vector2i):
	"""Generate A* pathfinding points for a specific chunk"""
	if chunk_astar_points.has(chunk):
		return  # Points already generated for this chunk
	
	var chunk_points: Array[int] = []
	
	var chunk_x = float(chunk.x)
	var chunk_z = float(chunk.y)
	var chunk_center = Vector2(chunk_x * terrain_chunk_size, chunk_z * terrain_chunk_size)
	
	var start_x = chunk_center.x - (terrain_chunk_size * 0.5)
	var start_z = chunk_center.y - (terrain_chunk_size * 0.5)
	var end_x = chunk_center.x + (terrain_chunk_size * 0.5)
	var end_z = chunk_center.y + (terrain_chunk_size * 0.5)
	
	# Generate points within this chunk
	var points_per_chunk = int(terrain_chunk_size / path_grid_resolution)
	
	for x in range(points_per_chunk + 1):
		for z in range(points_per_chunk + 1):
			var progress_x = float(x) / float(points_per_chunk)
			var progress_z = float(z) / float(points_per_chunk)
			
			var world_x = lerp(start_x, end_x, progress_x)
			var world_z = lerp(start_z, end_z, progress_z)
			var world_y = get_terrain_height(world_x, world_z)
			
			var point_pos = Vector3(world_x, world_y, world_z)
			var weight = calculate_height_weight(world_y)
			
			var point_id = next_point_id
			next_point_id += 1
			
			astar.add_point(point_id, point_pos, weight)
			astar_point_positions[point_id] = point_pos
			chunk_points.append(point_id)
	
	chunk_astar_points[chunk] = chunk_points
	
	# Connect points within this chunk and to neighboring chunks
	connect_chunk_points(chunk)

func connect_chunk_points(chunk: Vector2i):
	"""Connect A* points within a chunk and to neighboring chunks"""
	if not chunk_astar_points.has(chunk):
		return
	
	var points_per_chunk = int(terrain_chunk_size / path_grid_resolution) + 1
	var chunk_points = chunk_astar_points[chunk]
	
	# Connect points within this chunk
	for x in range(points_per_chunk):
		for z in range(points_per_chunk):
			var current_index = x * points_per_chunk + z
			var current_id = chunk_points[current_index]
			
			# Connect to right neighbor within chunk
			if x < points_per_chunk - 1:
				var right_index = (x + 1) * points_per_chunk + z
				var right_id = chunk_points[right_index]
				astar.connect_points(current_id, right_id)
			
			# Connect to bottom neighbor within chunk
			if z < points_per_chunk - 1:
				var bottom_index = x * points_per_chunk + (z + 1)
				var bottom_id = chunk_points[bottom_index]
				astar.connect_points(current_id, bottom_id)
			
			# Connect to diagonal neighbors within chunk
			if x < points_per_chunk - 1 and z < points_per_chunk - 1:
				var diagonal_index = (x + 1) * points_per_chunk + (z + 1)
				var diagonal_id = chunk_points[diagonal_index]
				astar.connect_points(current_id, diagonal_id)
			
			if x < points_per_chunk - 1 and z > 0:
				var diagonal_index = (x + 1) * points_per_chunk + (z - 1)
				var diagonal_id = chunk_points[diagonal_index]
				astar.connect_points(current_id, diagonal_id)
	
	# Connect to neighboring chunks if they exist
	connect_to_neighboring_chunks(chunk)

func connect_to_neighboring_chunks(chunk: Vector2i):
	"""Connect edge points of this chunk to neighboring chunks"""
	var neighbors = [
		Vector2i(chunk.x + 1, chunk.y),     # Right
		Vector2i(chunk.x, chunk.y + 1),     # Bottom
		Vector2i(chunk.x + 1, chunk.y + 1), # Bottom-right diagonal
		Vector2i(chunk.x - 1, chunk.y),     # Left
		Vector2i(chunk.x, chunk.y - 1),     # Top
		Vector2i(chunk.x - 1, chunk.y - 1), # Top-left diagonal
		Vector2i(chunk.x + 1, chunk.y - 1), # Top-right diagonal
		Vector2i(chunk.x - 1, chunk.y + 1)  # Bottom-left diagonal
	]
	
	for neighbor_chunk in neighbors:
		if chunk_astar_points.has(neighbor_chunk):
			connect_chunk_edges(chunk, neighbor_chunk)

func connect_chunk_edges(chunk1: Vector2i, chunk2: Vector2i):
	"""Connect edge points between two adjacent chunks"""
	if not chunk_astar_points.has(chunk1) or not chunk_astar_points.has(chunk2):
		return
	
	var chunk1_points = chunk_astar_points[chunk1]
	var chunk2_points = chunk_astar_points[chunk2]
	var connection_distance = path_grid_resolution * 1.5  # Slightly more than grid resolution
	
	# For each point in chunk1, find nearby points in chunk2 and connect them
	for point1_id in chunk1_points:
		var pos1 = astar_point_positions[point1_id]
		
		for point2_id in chunk2_points:
			var pos2 = astar_point_positions[point2_id]
			
			# Connect if they're close enough (edge connection)
			if pos1.distance_to(pos2) <= connection_distance:
				astar.connect_points(point1_id, point2_id)

# Modify your thread function to clean up A* points when chunks are removed
func remove_chunk_astar_points(chunk: Vector2i):
	"""Remove A* points when a chunk is unloaded"""
	if chunk_astar_points.has(chunk):
		var points_to_remove = chunk_astar_points[chunk]
		
		# Remove all points for this chunk from AStar
		for point_id in points_to_remove:
			astar.remove_point(point_id)
			astar_point_positions.erase(point_id)
		
		chunk_astar_points.erase(chunk)


func generate_terrain_collision(chunk: Vector2i):
	if not collider_dict.has(chunk):
		var newcollider = CollisionShape3D.new()
		newcollider.shape = HeightMapShape3D.new()
		newcollider.shape.map_width = terrain_chunk_size + 1.0
		newcollider.shape.map_depth = terrain_chunk_size + 1.0
		collider_dict[chunk] = newcollider

		var map_data: PackedFloat32Array = []

		var chunk_x = float(chunk.x)
		var chunk_z = float(chunk.y)

		var chunk_center = Vector2(chunk_x * terrain_chunk_size, chunk_z * terrain_chunk_size)

		var start_x = chunk_center.x - (terrain_chunk_size * 0.5)
		var start_z = chunk_center.y - (terrain_chunk_size * 0.5)

		var end_x = chunk_center.x + (terrain_chunk_size * 0.5)
		var end_z = chunk_center.y + (terrain_chunk_size * 0.5)

		for x_division in int(terrain_chunk_size) + 1:
			var progress_x = float(x_division) / terrain_chunk_size
			var x_coord = lerp(end_x, start_x, progress_x)

			var progress_x_next = float(x_division + 1) / terrain_chunk_size
			var x_coord_next = lerp(start_x, end_x, progress_x_next)
			for z_division in int(terrain_chunk_size) + 1:
				var progress_z = float(z_division) / terrain_chunk_size
				var z_coord = lerp(start_z, end_z, progress_z)

				var coord_2d = Vector2(x_coord, z_coord)
				var nval = sample_2dv(coord_2d)
				if mountain_mode:
					nval -= generate_mountain_y(coord_2d)
				map_data.append(nval * terrain_height_multiplier)

		newcollider.shape.map_data = map_data

		return newcollider
	else:
		return false


func _generate_noise_normal(point: Vector2) -> Vector3:
	var gradient_pos_x = point + Vector2(0.1, 0.0)
	var gradient_pos_z = point + Vector2(0.0, 0.1)
	var nval_wheel = sample_2dv(point)
	var nval_gx = sample_2dv(gradient_pos_x)
	var nval_gz = sample_2dv(gradient_pos_z)

	var pos_3d_nval_wheel = Vector3(point.x, nval_wheel * terrain_height_multiplier, point.y)
	var pos_3d_nval_gx = Vector3(
		gradient_pos_x.x, nval_gx * terrain_height_multiplier, gradient_pos_x.y
	)
	var pos_3d_nval_gz = Vector3(
		gradient_pos_z.x, nval_gz * terrain_height_multiplier, gradient_pos_z.y
	)

	if mountain_mode:
		pos_3d_nval_wheel.y -= generate_mountain_y(point)
		pos_3d_nval_gx.y -= generate_mountain_y(gradient_pos_x)
		pos_3d_nval_gz.y -= generate_mountain_y(gradient_pos_z)

	var gradient_x = pos_3d_nval_gx - pos_3d_nval_wheel
	var gradient_z = pos_3d_nval_gz - pos_3d_nval_wheel

	var gx_norm = gradient_x.normalized()
	var gz_norm = gradient_z.normalized()
	var normal = gz_norm.cross(gx_norm)

	return normal.normalized()


func _generate_noise_normal_smooth(point: Vector2) -> Vector3:
	var gradient_pos_x = point + Vector2(0.1, 0.0)
	var gradient_pos_z = point + Vector2(0.0, 0.1)
	var nval_wheel = sample_2dv_smooth(point)
	var nval_gx = sample_2dv_smooth(gradient_pos_x)
	var nval_gz = sample_2dv_smooth(gradient_pos_z)

	var pos_3d_nval_wheel = Vector3(point.x, nval_wheel * terrain_height_multiplier, point.y)
	var pos_3d_nval_gx = Vector3(
		gradient_pos_x.x, nval_gx * terrain_height_multiplier, gradient_pos_x.y
	)
	var pos_3d_nval_gz = Vector3(
		gradient_pos_z.x, nval_gz * terrain_height_multiplier, gradient_pos_z.y
	)

	if mountain_mode:
		pos_3d_nval_wheel.y -= generate_mountain_y(point)
		pos_3d_nval_gx.y -= generate_mountain_y(gradient_pos_x)
		pos_3d_nval_gz.y -= generate_mountain_y(gradient_pos_z)

	var gradient_x = pos_3d_nval_gx - pos_3d_nval_wheel
	var gradient_z = pos_3d_nval_gz - pos_3d_nval_wheel

	var gx_norm = gradient_x.normalized()
	var gz_norm = gradient_z.normalized()
	var normal = gz_norm.cross(gx_norm)

	return normal.normalized()


func generate_mountain_y(point: Vector2) -> float:
	var value = point.length()
	#value = pow(value, 2.0) - pow(value, 1.999)
	#value = log(value)
	value *= mountain_strength
	value = pow(value, 2.0) - pow(7.388, log(value))
	value = max(value, 0.0)
	return value  # * mountain_strength * 0.01


func get_path_effect(point: Vector2) -> float:
	var pn = path_noise.get_noise_2dv(point)
	return path_curve.sample(clampf(1.0 - abs(pn), 0.0, 1.0))


func sample_2dv(point: Vector2) -> float:
	var value: float

	if not use_equation:
		value = terrain_noise.get_noise_2dv(point)

		if terrain_noise_large:
			if terrain_large_function == 0:
				value += terrain_noise_large.get_noise_2dv(point) * 5.0
			elif terrain_large_function == 1:
				value -= terrain_noise_large.get_noise_2dv(point)
			elif terrain_large_function == 2:
				value *= terrain_noise_large.get_noise_2dv(point)
			elif terrain_large_function == 3:
				value = pow(value, terrain_noise_large.get_noise_2dv(point))

		if use_paths:
			var pn_smooth_pathless = sample_2dv_smooth_pathless(point)
			var path_effect = get_path_effect(point)
			value = lerpf(value, pn_smooth_pathless, 1.0 - path_effect)
	else:
		var r = point.length() * 0.07
		var theta = atan2(point.y, point.x)
		value = (sin(r + theta) + r) * clamp(r * 0.1, 0.0, 1.0)
		value /= 50.0
	#
	#if terrain_sample_curve:
	#value *= pre_curve_multiplier
	#value = terrain_sample_curve.sample_baked(value)

	return value


func sample_2dv_pathless(point: Vector2) -> float:
	var value: float

	if not use_equation:
		value = terrain_noise.get_noise_2dv(point)

		if terrain_noise_large:
			if terrain_large_function == 0:
				value += terrain_noise_large.get_noise_2dv(point) * 5.0
			elif terrain_large_function == 1:
				value -= terrain_noise_large.get_noise_2dv(point)
			elif terrain_large_function == 2:
				value *= terrain_noise_large.get_noise_2dv(point)
			elif terrain_large_function == 3:
				value = pow(value, terrain_noise_large.get_noise_2dv(point))

	else:
		var r = point.length() * 0.07
		var theta = atan2(point.y, point.x)
		value = (sin(r + theta) + r) * clamp(r * 0.1, 0.0, 1.0)
	#
	#if terrain_sample_curve:
	#value *= pre_curve_multiplier
	#value = terrain_sample_curve.sample_baked(value)

	return value


func sample_2dv_smooth(point: Vector2) -> float:
	var value: float

	var smooth = 0.1

	var v1 = sample_2dv(point + Vector2(0.0, smooth))
	var v2 = sample_2dv(point + Vector2(0.0, -smooth))
	var v3 = sample_2dv(point + Vector2(smooth, 0.0))
	var v4 = sample_2dv(point + Vector2(-smooth, 0.0))
	var v5 = sample_2dv(point)

	value = (v1 + v2 + v3 + v4 + v5) / 5.0

	return value


func sample_2dv_smooth_pathless(point: Vector2) -> float:
	var value: float

	var v1 = sample_2dv_pathless(point + Vector2(0.0, path_smooth_radius))
	var v2 = sample_2dv_pathless(point + Vector2(0.0, -path_smooth_radius))
	var v3 = sample_2dv_pathless(point + Vector2(path_smooth_radius, 0.0))
	var v4 = sample_2dv_pathless(point + Vector2(-path_smooth_radius, 0.0))

	value = (v1 + v2 + v3 + v4) / 4.0

	return value

func generate_path_to_target(target_pos: Vector3) -> PackedVector3Array:
	"""Generate an A* path from (0,0) to target position using existing chunk points"""
	if not astar:
		print("AStar not initialized!")
		return PackedVector3Array()
	
	# Clear existing path visualization
	if path_line:
		path_line.queue_free()
	
	var start_pos = Vector3(0, 0, 0)
	start_pos.y = get_terrain_height(start_pos.x, start_pos.z)
	target_pos.y = get_terrain_height(target_pos.x, target_pos.z)
	
	# Find closest points to start and target from existing points
	var start_id: int = -1
	var target_id: int = -1
	var min_start_distance = INF
	var min_target_distance = INF
	
	for point_id in astar_point_positions.keys():
		var point_pos = astar_point_positions[point_id]
		
		var start_distance = point_pos.distance_to(start_pos)
		if start_distance < min_start_distance:
			min_start_distance = start_distance
			start_id = point_id
		
		var target_distance = point_pos.distance_to(target_pos)
		if target_distance < min_target_distance:
			min_target_distance = target_distance
			target_id = point_id
	
	if start_id == -1 or target_id == -1:
		print("Could not find suitable start or target points!")
		return PackedVector3Array()
	
	print("Finding path from ", start_id, " to ", target_id)
	
	# Find the path
	if true:
		current_path = astar.get_point_path(start_id, target_id)
		print("Path found with ", current_path.size(), " points")
		
		# Visualize the path
		visualize_path(current_path)
		
		return current_path
	else:
		print("No path found between points!")
		return PackedVector3Array()

func calculate_height_weight(height: float) -> float:
	"""Calculate path weight based on terrain height. Lower weights are preferred."""
	if not height_weight_curve:
		# Default behavior: penalize extreme heights
		var normalized_height = abs(height + 2) / 3 
		normalized_height = clamp(normalized_height, 0.0, 1.0)
		
		# Create a U-curve: low weight at mid-heights, high weight at extremes
		var weight_factor = pow(abs(normalized_height - 0.5) * 2.0, 2.0)
		return lerp(min_weight, max_weight, weight_factor)
	else:
		# Use custom curve
		var normalized_height = height / terrain_height_multiplier
		normalized_height = clamp(normalized_height * 0.5 + 0.5, 0.0, 1.0)  # Normalize to 0-1
		var curve_value = height_weight_curve.sample(normalized_height)
		return lerp(min_weight, max_weight, curve_value)

func visualize_path(path: PackedVector3Array):
	"""Create debug visualization of the path"""
	if path.size() < 2:
		return
	
	# Create a new node for the path visualization
	path_line = Node3D.new()
	path_line.name = "PathVisualization"
	add_child(path_line)
	
	# Create line segments between path points
	for i in range(path.size() - 1):
		var line_mesh = MeshInstance3D.new()
		var mesh = ArrayMesh.new()
		
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		
		var vertices = PackedVector3Array()
		var colors = PackedColorArray()
		
		# Create a simple line
		vertices.push_back(path[i])
		vertices.push_back(path[i + 1])
		colors.push_back(Color.RED)
		colors.push_back(Color.RED)
		
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		line_mesh.mesh = mesh
		
		path_line.add_child(line_mesh)
	
	# Add spheres at path points for better visibility
	for point in path:
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.25
		sphere_mesh.height = 0.5
		sphere.mesh = sphere_mesh
		sphere.position = point
		
		# Create material for the sphere
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.YELLOW
		material.flags_unshaded = true
		sphere.set_surface_override_material(0, material)
		
		path_line.add_child(sphere)

func clear_path_visualization():
	"""Remove the current path visualization"""
	if path_line:
		path_line.queue_free()
		path_line = null
	current_path.clear()


func _on_tree_exiting():
	if not Engine.is_editor_hint() and mutex:
		mutex.lock()
		exit_thread = true  # Protect with Mutex.
		mutex.unlock()

		# Unblock by posting.
		semaphore.post()

		# Wait until it exits.
		thread.wait_to_finish()


func _exit_tree():
	# Clean-up of the plugin goes here.
	pass
