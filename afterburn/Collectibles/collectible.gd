extends Node3D
class_name collectible

signal pick_up(collectible_name: String)
@export var Name: String

func pick_up_effect():
	pick_up.emit(Name)

# TO CREATE A COLLECTIBLE:
	# Put collectible_template.tscn in a new scene
	# Put a model under it in either a sprite2D for 2D sprites or just drag a model into the scene and put it under the node of the scene
	# Extend collectible in the script at the top
	# Put the function "pick_up_effect" in the new script
	# Put the line super() at the top of the function as this will extend the pick_up_effect function
	# Put all effects that will occur when this collectible is collected in the function after super()
	# Attach the body_entered signal to the script on the root node
	# Put "if body.is_in_group("Player"):" in the connected method
	# Call pick_up_effect under that
