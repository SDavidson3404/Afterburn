## Power Armor loadout gadget.
## Trades increased collision damage for a multi-hit protective shield layer that absorbs obstacle impacts.
extends GadgetBase

@export_category("Armor Configuration")
## Maximum number of obstacle hits the armor shield can absorb before breaking.
@export var max_hits: int = 3


func _init() -> void:
	gadget_name = "Power Armor"
	gadget_id = "power_armor"


## Applies loadout handicap: Increases base obstacle collision damage by 60%.
func apply_loadout_nerf(power_manager: Node) -> void:
	power_manager.obstacle_damage_multiplier = 1.6


## Activates power armor shield or refreshes remaining hit capacity if already active.
func activate_ability(player: Node3D, power_manager: Node) -> void:
	# Refresh hit pool if an armor instance is currently active on the player
	var existing = player.get_node_or_null("PowerArmorInstance") as PowerArmorInstance
	if existing:
		existing.hits_remaining = existing.max_hits
		return

	# Construct and attach new temporary PowerArmorInstance component
	var active_armor = PowerArmorInstance.new()
	active_armor.max_hits = max_hits
	active_armor.hits_remaining = max_hits
	active_armor.power_manager = power_manager
	active_armor.name = "PowerArmorInstance"
	player.add_child(active_armor)


## Inner component node attached to the player that intercepts obstacle damage.
class PowerArmorInstance extends Node:
	## Remaining hits the armor shield can absorb.
	var hits_remaining: int = 3
	
	## Maximum hit capacity used for recharges.
	var max_hits: int = 3
	
	## Reference to the main power manager node.
	var power_manager: Node = null


	func _ready() -> void:
		hits_remaining = max_hits
		# Register shield layer with power manager to intercept incoming collision damage
		if power_manager and power_manager.has_method("register_armor_layer"):
			power_manager.register_armor_layer(self)


	## Decrements armor durability when hit. Returns true if the armor breaks on this hit.
	func absorb_hit() -> bool:
		hits_remaining -= 1
		
		if hits_remaining <= 0:
			_break_armor()
			return true
		return false


	## Unregisters shield layer from power manager and removes instance from scene tree.
	func _break_armor() -> void:
		if power_manager and power_manager.has_method("unregister_armor_layer"):
			power_manager.unregister_armor_layer(self)
		queue_free()
