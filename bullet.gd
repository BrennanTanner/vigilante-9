extends Node3D

const speed: float = 40.0
const lifetime: float = 1 
const damage: int = 1

@onready var mesh = $MeshInstance3D
@onready var ray = $RayCast3D

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _process(delta: float) -> void:
	position += transform.basis * Vector3(0, 0, -speed) * delta
	if ray.is_colliding():
		mesh.visible = false
		#particle.emittting = true
		if ray.get_collider().is_in_group("enemy"):
			ray.get_collider().hit(damage)
		await get_tree().create_timer(1.0).timeout
		queue_free()
