extends Camera3D

@export var target: Node3D

var offset: Vector3

func _ready():
	# Calculate the initial offset between the camera and the target
	offset = global_position - target.global_position

func _process(delta: float):
	# Update camera position to follow the target with the initial offset
	global_position = target.global_position + offset
