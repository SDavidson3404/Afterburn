## Pulse Wave loadout gadget.
## Trades crystal power efficiency for an immediate forward shockwave that clears obstacles and spawns pickups.
extends GadgetBase

@export_category("Ability Properties")
## Probability (0.0 to 1.0) of spawning a gadget pickup when an obstacle is cleared.
@export var gadget_drop_chance: float = 0.10


func _init() -> void:
	gadget_name = "Pulse Wave"
	gadget_id = "pulse_wave"


## Applies loadout handicap: Reduces suit power yield from crystals to 75%.
func apply_loadout_nerf(power_manager: Node) -> void:
	power_manager.crystal_power_yield = 0.75


## Activates shockwave: Destroys oncoming obstacles and rolls for a bonus gadget drop per obstacle.
func activate_ability(player: Node3D, power_manager: Node) -> void:
	var obstacles = player.get_tree().get_nodes_in_group("Obstacles")
	var player_pos: Vector3 = player.body.global_position

	# Scale clear distance based on current forward speed reaction distance
	var clear_distance: float = 35.0
	if power_manager and power_manager.has_method("get_current_spawn_distance"):
		clear_distance = power_manager.get_current_spawn_distance()

	for obstacle in obstacles:
		var dist: float = obstacle.global_position.distance_to(player_pos)
		# Only target obstacles within clear distance ahead of the player (negative Z direction)
		if dist <= clear_distance and obstacle.global_position.z < player_pos.z:
			# Roll independently for each destroyed obstacle
			if randf() <= gadget_drop_chance:
				_spawn_gadget_pickup_at(obstacle.global_position, player.get_tree().current_scene)

			obstacle.queue_free()


## Instantiates a 3D gadget pickup item at the destroyed obstacle position.
func _spawn_gadget_pickup_at(pos: Vector3, scene: Node) -> void:
	var pickup_scene = load("res://Gadgets/gadget_pickup.tscn")
	if pickup_scene:
		var pickup = pickup_scene.instantiate() as Node3D
		scene.add_child(pickup)
		# Lock Y-position to 1.0 unit so pickups float uniformly above the track floor
		pickup.global_position = Vector3(pos.x, 1.0, pos.z)
		print("Pulse Wave: GADGET DROPPED at position ", pickup.global_position)
