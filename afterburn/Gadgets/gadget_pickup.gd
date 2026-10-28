## World interactable node representing collectible gadget pickups on the track.
## Handles dynamic visual coloring, collision detection, and instant ability activation.
extends Area3D

## Available gadget types selectable in the editor or randomly rolled at runtime.
enum GadgetType { RANDOM, PULSE_WAVE, MAGNET, POWER_ARMOR, HOVERBOARD, OVERDRIVEN_ROCKET }

@export_category("Pickup Configuration")
## The specific gadget type this node represents. Defaults to RANDOM for procedural spawns.
@export var gadget_type: GadgetType = GadgetType.RANDOM

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


## Programmatically overrides the mesh material to color-code the pickup in 3D space.
func _apply_gadget_color() -> void:
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_node:
		return

	var gadget_color: Color = Color.WHITE
	match gadget_type:
		GadgetType.PULSE_WAVE: gadget_color = Color.MAGENTA
		GadgetType.MAGNET: gadget_color = Color.RED
		GadgetType.POWER_ARMOR: gadget_color = Color.GREEN
		GadgetType.HOVERBOARD: gadget_color = Color.WHITE
		GadgetType.OVERDRIVEN_ROCKET: gadget_color = Color(1.0, 0.35, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = gadget_color
	material.emission_enabled = true
	material.emission = gadget_color
	material.emission_energy_multiplier = 1.5

	mesh_node.material_override = material


## Handles player intersection, triggering ability effects and freeing the pickup node.
func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return

	# Support collisions on either the root player node or sub-character body
	var player_node: Node3D = body if body is Player else body.get_parent() as Node3D
	if player_node and player_node.is_in_group("Player"):
		_is_collected = true
		_trigger_pickup_effect(player_node)
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
