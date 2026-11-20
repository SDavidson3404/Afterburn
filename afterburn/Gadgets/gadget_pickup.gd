## World interactable node representing collectible gadget pickups on the track.
## Handles dynamic visual coloring, collision detection, and instant ability activation.
extends Area3D

## Available gadget types selectable in the editor or randomly rolled at runtime.
enum GadgetType { RANDOM, PULSE_WAVE, MAGNET, POWER_ARMOR, HOVERBOARD, OVERDRIVEN_ROCKET }

@export_category("Pickup Configuration")
## The specific gadget type this node represents. Defaults to RANDOM for procedural spawns.
@export var gadget_type: GadgetType = GadgetType.RANDOM

# Gadget Models
@onready var placeholder_gadget: Node3D = $"Placeholder Gadget"
@onready var magnet: Node3D = $Magnet
@onready var overdriven_rocket: Node3D = $OverdrivenRocket
@onready var power_armor: Node3D = $PowerArmor
@onready var pulse_wave: Node3D = $PulseWave
@onready var hoverboard: Node3D = $Hoverboard

## Guard flag preventing duplicate pickup activations within the same frame.
var _is_collected: bool = false

## Maps inspectable enum values to string keys required by the GadgetBase factory.
const TYPE_TO_ID: Dictionary = {
	GadgetType.PULSE_WAVE: "pulse_wave",
	GadgetType.MAGNET: "magnet",
	GadgetType.POWER_ARMOR: "power_armor",
	GadgetType.HOVERBOARD: "hoverboard",
	GadgetType.OVERDRIVEN_ROCKET: "overdriven_rocket"
}


func _ready() -> void:
	# Group assignment enables magnetic attraction by the Magnet gadget
	add_to_group("Collectibles")
	body_entered.connect(_on_body_entered)
	_resolve_gadget_type_and_color()


## Resolves random pickup types and sets up color-coded emissive materials.
func _resolve_gadget_type_and_color() -> void:
	if gadget_type == GadgetType.RANDOM:
		gadget_type = [
			GadgetType.PULSE_WAVE,
			GadgetType.MAGNET,
			GadgetType.POWER_ARMOR,
			GadgetType.HOVERBOARD,
			GadgetType.OVERDRIVEN_ROCKET
		].pick_random()

	_apply_gadget_color()


## Programmatically overrides mesh material and light node color to color-code the pickup in 3D space.
func _apply_gadget_color() -> void:
	var gadget_models: Array = [placeholder_gadget, magnet, pulse_wave, power_armor, hoverboard, overdriven_rocket]
	
	var gadget_color: Color = Color.WHITE
	var gadget_model: Node3D = placeholder_gadget
	match gadget_type:
		GadgetType.PULSE_WAVE: 
			gadget_color = Color.MAGENTA
			gadget_model = pulse_wave
		GadgetType.MAGNET: 
			gadget_color = Color.RED
			gadget_model = magnet
		GadgetType.POWER_ARMOR: 
			gadget_color = Color.GREEN
			gadget_model = power_armor
		GadgetType.HOVERBOARD: 
			gadget_color = Color.WHITE
			gadget_model = hoverboard
		GadgetType.OVERDRIVEN_ROCKET: 
			gadget_color = Color(1.0, 0.35, 0.0)
			gadget_model = overdriven_rocket
	
	for item in gadget_models:
		if gadget_model == item:
			gadget_model.visible = true
		else:
			item.visible = false

	# Sync OmniLight3D light color with active gadget type
	var light_node := get_node_or_null("OmniLight3D") as OmniLight3D
	if light_node:
		light_node.light_color = gadget_color


## Handles player intersection, triggering ability effects and freeing the pickup node.
func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return

	# Support collisions on either the root player node or sub-character body
	var player_node: Node3D = body if body is Player else body.get_parent() as Node3D
	if player_node and player_node.is_in_group("Player"):
		_is_collected = true
		
		var gadget_name_str: String = TYPE_TO_ID.get(gadget_type, "gadget").replace("_", " ").capitalize()
		
		# If tagged by spawner, forward to gadget_spawn to print elapsed time and reset timer
		var spawner = get_meta("spawner") if has_meta("spawner") else null
		if is_instance_valid(spawner) and spawner.has_method("on_gadget_collected"):
			spawner.on_gadget_collected(self, gadget_name_str)
		else:
			print("[ITEM PICKUP] Collected ", gadget_name_str, " Pickup at position: ", global_position)
		
		_trigger_pickup_effect(player_node)
		if get_node_or_null("/root/DatabaseManager"):
			DatabaseManager.add_gadget()
		queue_free()


## Uses the GadgetBase factory to instantiate and immediately activate the gadget power.
func _trigger_pickup_effect(player: Node3D) -> void:
	var power_mgr = player.get("power_node") as Node
	if not power_mgr:
		return

	var gadget_id: String = TYPE_TO_ID.get(gadget_type, "")
	var gadget_instance: GadgetBase = GadgetBase.create_by_id(gadget_id)
	if gadget_instance:
		gadget_instance.activate_ability(player, power_mgr)
		# Free temporary factory instance to prevent memory leaks
		gadget_instance.free()
