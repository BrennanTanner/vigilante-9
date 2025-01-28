extends Node3D

@export var animated: bool = true

var horse_animation: AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	horse_animation = get_node("AnimationPlayer")
	horse_animation.get_animation("run").loop_mode = (Animation.LOOP_LINEAR)
	horse_animation.get_animation("walk").loop_mode = (Animation.LOOP_LINEAR)
	horse_animation.get_animation("idle").loop_mode = (Animation.LOOP_LINEAR)
	horse_animation.get_animation("lie")
	horse_animation.play("idle")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if animated:
		var speed = get_parent().linear_velocity.length()
		if speed > 0:
			if speed > 4:
				horse_animation.speed_scale = speed /10
				horse_animation.play("run")
				
			else:
				horse_animation.speed_scale = speed /4
				horse_animation.play("walk")
				
		else: 
			horse_animation.speed_scale = 1
			horse_animation.play("idle")
