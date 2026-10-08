extends StaticBody3D
class_name street

# Signal
signal entered(node_to_keep: street) # The signal that the player entered the road

# Exported vars
@export var starting_street_node: bool = false # A check for if this is the starting street

# Nodes
@onready var links: Node3D = $Links # The parent node of the links
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

## Returns the global transform (Scale, Position, and Rotation) of a given link
func find_link_loc(Link: Node3D):
	
	# For loop for the children of the link parent node
	for child in links.get_children():
		
		# If the child is the link that was given then return the transform
		if child == Link:
			return child.global_transform

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

## Sets the potential to enter the road, toggling it to either you can or cannot.
func set_enter_potential(value: bool):
	
	# If the scenetree doesn't exist, end the method
	if not is_inside_tree():
		return
	
	# Change the monitoring on the area3D to the argument given when this method is called
	area.set_deferred("monitoring", value)
