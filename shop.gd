extends Control

@export var player: Car
@export var turret_gun : PackedScene
@export var grenade_gun : PackedScene

func _ready():
	if not player:
		# Try to find the player/camera
		player = get_tree().get_nodes_in_group("player")[0]
		if player:
			print("Found player node")
		else:
			push_warning("No player node assigned!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_quit_pressed() -> void:
	visible = false
	var controls : CanvasLayer = get_node("../joystick")
	#var joy : VirtualJoystick = controls.get_node("Virtual joystick")
	
	controls.visible = true
	#joy.deadzone_size = 1

func _on_turret_pressed() -> void:
	player.swap_gun(turret_gun)
	


func _on_grenade_pressed() -> void:
	player.swap_gun(grenade_gun)


func _on_level_up_pressed() -> void:
	pass # Replace with function body.
