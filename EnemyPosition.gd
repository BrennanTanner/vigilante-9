extends Resource
class_name EnemyPosition

@export var health: int
@export var position: Vector3
@export var distance: float

func _init(p_health = 0, p_position = Vector3(0,0,0), p_distance = 0.0):
	health = p_health
	position = p_position
	distance = p_distance
