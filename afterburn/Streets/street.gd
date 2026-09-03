extends StaticBody3D
class_name street

var has_been_entered: bool = false
@onready var links: Node3D = $Links
signal entered(node_to_keep: street)
@onready var area: Area3D = $Area3D
@export var starting_street_node: bool = false

func _ready() -> void:
	if starting_street_node:
		area.monitoring = true

func find_link_loc(Link: Node3D):
	for child in links.get_children():
		if child == Link:
			return child.global_transform

func get_links():
	return links.get_children()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and not has_been_entered:
		has_been_entered = true
		entered.emit(self)

func set_enter_potential(value: bool):
	if not is_inside_tree():
		return
	area.set_deferred("monitoring", value)
