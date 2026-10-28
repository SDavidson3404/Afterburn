extends StaticBody3D
class_name street

signal entered(node_to_keep: street)

@export var starting_street_node: bool = false

@onready var end_link: Node3D = $EndLink
@onready var area: Area3D = $Area3D

var has_been_entered: bool = false

func _ready() -> void:
	if starting_street_node:
		area.monitoring = true

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and not has_been_entered:
		has_been_entered = true
		entered.emit(self)
