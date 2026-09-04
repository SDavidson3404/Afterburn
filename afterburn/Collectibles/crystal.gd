extends collectible

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		pick_up_effect()

func pick_up_effect():
	super()
	queue_free()
