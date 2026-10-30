extends StaticBody3D
class_name street

# Signal
signal entered(node_to_keep: street) # The signal that the player entered the road

# Exported vars
@export var starting_street_node: bool = false # A check for if this is the starting street

# Nodes
@onready var end_link: Node3D = $EndLink
@onready var area: Area3D = $Area3D # The area that detects if you entered the road
@onready var rows: Node3D = $Rows # The parent node of the rows

# Vars
var collectibles: Array = [] # The array of collectibles
var has_been_entered: bool = false # A check for if the road has been entered
var has_summoned_obstacles: bool = false

## Runs upon instancing the scene in a scenetree.
func _ready() -> void:
	
	# if this road is the starting road, set the monitoring to true
	if starting_street_node:
		area.monitoring = true

## Gets the link nodes under the link parent node
func get_links(link: Node3D): return link.get_children()

## Runs on a body entering the area3D
func _on_area_3d_body_entered(body: Node3D) -> void:
	
	# If the body is the player and the area has not been entered before, set that it has now been entered
	if body.is_in_group("Player") and not has_been_entered:
		has_been_entered = true
		
		# Emit the entered signal
		entered.emit(self)

## Gets the row nodes under the row parent node
func get_rows(): return rows.get_children()

func get_specific_row(row_num: int):
	for child in rows.get_children():
		if child.name == "Row" + str(row_num):
			return child
