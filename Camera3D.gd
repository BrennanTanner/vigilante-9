extends Camera3D

@export var target: Node3D

var offset: Vector3
var follow_body: Node3D
var speed: float = 0.1
	
func _ready():
	# Calculate the initial offset between the camera and the target
	follow_body = target
	offset = global_position - follow_body.global_position

func _process(delta: float):
	
	# Update camera position to follow the target with the initial offset
	global_position = follow_body.global_position + offset
	
