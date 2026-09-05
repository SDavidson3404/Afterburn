extends StaticBody3D

var turned: bool = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Building") and not turned:
		turned = true
		global_rotation.y += deg_to_rad(180)
