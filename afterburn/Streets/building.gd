extends StaticBody3D
class_name building

var turned: bool = false

func _on_area_3d_body_entered(body: Node3D) -> void:
	if not body.is_in_group("Building") and not turned:
		print(body.name + " " + name)
		turned = true
		global_rotation.y += deg_to_rad(180)

func _on_rotate_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		body.turn_normal()
