extends Area2D

@export var damage : int = 10

func _ready() -> void:
	# Maneira correta e segura no Godot 4
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
