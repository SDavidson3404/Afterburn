## Abstract base class and factory for all loadout gadgets.
## Employs Polymorphism and the Factory Design Pattern to decouple gadget instantiation from game management nodes.
class_name GadgetBase
extends Node

@export_category("Gadget Metadata")
## Display name shown in UI elements and menus.
@export var gadget_name: String = "Base Gadget"

## Unique string identifier used for lookup and factory instantiation.
@export var gadget_id: String = "base_gadget"

## Number of crystals required to fully recharge this gadget ability.
@export var cooldown_crystals_required: int = 6


## Virtual method: Overridden by child classes to apply run handicaps/drawbacks when this gadget is equipped in the loadout.
func apply_loadout_nerf(_power_manager: Node) -> void:
	pass


## Virtual method: Overridden by child classes to execute active ability logic.
func activate_ability(_player: Node3D, _power_manager: Node) -> void:
	pass


## Factory Method: Dynamically loads and instantiates a specific gadget script by ID.
## Returns an initialized GadgetBase instance, or null if the ID is invalid.
static func create_by_id(id: String) -> GadgetBase:
	match id:
		"pulse_wave": return load("res://Gadgets/pulse_wave.gd").new()
		"magnet": return load("res://Gadgets/magnet.gd").new()
		"power_armor": return load("res://Gadgets/power_armor.gd").new()
		"hoverboard": return load("res://Gadgets/hoverboard.gd").new()
		"overdriven_rocket": return load("res://Gadgets/overdriven_rocket.gd").new()
	return null
