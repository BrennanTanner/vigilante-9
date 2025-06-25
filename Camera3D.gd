extends Node3D

@export var target: Node3D
@export var lockYAxis: bool
var offset: Vector3
var follow_body: Node3D
var speed: float = 0.1
	
func _ready():
	# Calculate the initial offset between the camera and the target
	follow_body = target
	offset = global_position - follow_body.global_position

func _process(_delta: float):
	if lockYAxis:
		global_position = follow_body.global_position + offset
	# Update camera position to follow the target with the initial offset
	else:
		#print("cary: ", follow_body.global_position.y, "\nwatery: ", global_position.y)
		global_position = Vector3(follow_body.global_position.x+offset.x, -1, follow_body.global_position.z+offset.z) 
	
