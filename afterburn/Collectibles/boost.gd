extends collectible

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		pick_up_effect()

func pick_up_effect():
	super()
	for child in get_tree().get_first_node_in_group("Player").get_children():
		if child is Player:
			child.BOOST()
	queue_free()
