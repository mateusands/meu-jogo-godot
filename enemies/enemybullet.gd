extends Area2D

var shoot_speed := 300
var direction := 1

func _process(delta):
	position.x += shoot_speed * delta * direction

func set_direction(dir):
	direction = dir
	if dir < 0:
		$anim.set_flip_h(true)
	else:
		$anim.set_flip_h(false)
