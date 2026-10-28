## Hoverboard loadout gadget.
## Trades accelerated track speed progression for boosted jump velocity, reduced dash drain, and extended coasting.
extends GadgetBase

@export_category("Ability Properties")
## Total active duration of the hoverboard buff in seconds.
@export var duration: float = 20.0


func _init() -> void:
	gadget_name = "Hoverboard"
	gadget_id = "hoverboard"


## Applies loadout handicap: Increases overall run acceleration rate by 30%.
func apply_loadout_nerf(power_manager: Node) -> void:
	power_manager.speed_acceleration *= 1.30


## Triggers hoverboard active state or refreshes duration if already active.
func activate_ability(player: Node3D, power_manager: Node) -> void:
	# Refresh duration if an instance is currently active on the player
	var existing = player.get_node_or_null("HoverboardInstance") as HoverboardInstance
	if existing:
		existing.duration = existing.max_duration
		return

	# Otherwise, construct and attach a new temporary HoverboardInstance node
	var hover_instance = HoverboardInstance.new()
	hover_instance.duration = duration
	hover_instance.max_duration = duration
	hover_instance.player = player
	hover_instance.power_manager = power_manager
	hover_instance.name = "HoverboardInstance"
	player.add_child(hover_instance)


## Inner component node attached to the player to manage temporary hoverboard state and stat modifiers.
class HoverboardInstance extends Node:
	var duration: float = 20.0
	var max_duration: float = 20.0
	var player: Node3D = null
	var power_manager: Node = null


	func _ready() -> void:
		# Apply active mobility buffs upon entering the scene tree
		if player:
			player.jump_velocity_multiplier = 2.0
			player.dash_drain_multiplier = 0.40
		
		if power_manager:
			power_manager.coasting_deceleration_multiplier = 0.40


	func _process(delta: float) -> void:
		duration -= delta
		if duration <= 0.0:
			_end_hoverboard()


	## Restores default player and power manager stat multipliers before self-destructing.
	func _end_hoverboard() -> void:
		if player:
			player.jump_velocity_multiplier = 1.0
			player.dash_drain_multiplier = 1.0
			
		if power_manager:
			power_manager.coasting_deceleration_multiplier = 1.0
			
		queue_free()
