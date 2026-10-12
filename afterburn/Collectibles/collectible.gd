extends Node3D
class_name collectible

# Signal for when picked up
signal pick_up(collectible_name: String)

@export var Name: String # The name of the collectible

## The effect when being picked up.
## Add to this in the extended script to add effects.
func pick_up_effect():
	pick_up.emit(Name)
