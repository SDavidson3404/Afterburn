## Magnet loadout gadget.
## Trades accelerated passive power drain for automatic magnetic attraction of nearby collectibles.
extends GadgetBase


func _init() -> void:
	gadget_name = "Magnet"
	gadget_id = "magnet"


## Applies loadout handicap: Increases passive suit power drain by 20%.
func apply_loadout_nerf(power_manager: Node) -> void:
	power_manager.passive_drain_multiplier = 1.20


## Activates magnet field or refreshes active duration if already running.
func activate_ability(player: Node3D, _power_manager: Node) -> void:
	var existing = player.get_node_or_null("MagnetInstance") as MagnetInstance
	if existing:
		existing.duration = existing.max_duration
		return

	var magnet_instance = MagnetInstance.new()
	magnet_instance.duration = 15.0
	magnet_instance.max_duration = 15.0
	magnet_instance.player = player
	magnet_instance.name = "MagnetInstance"
	player.add_child(magnet_instance)


## Inner component node attached to the player that pulls track collectibles dynamically.
class MagnetInstance extends Node:
	## Active duration remaining in seconds.
	var duration: float = 15.0
	
	## Max duration cap used for timer refreshes.
	var max_duration: float = 15.0
	
	## Reference to the target player node.
	var player: Node3D = null
	
	## Maximum lateral/vertical cross-section distance (in units) for item attraction.
	const MAX_XY_RADIUS: float = 3.5


	func _physics_process(delta: float) -> void:
		duration -= delta
		if duration <= 0.0:
			queue_free()
			return

		if not is_instance_valid(player):
			return

		var player_node := player as Player
		var player_pos: Vector3 = player_node.body.global_position if player_node and player_node.body else player.global_position
		var current_spd: float = player_node.current_speed if player_node else 15.0

		# Dynamically scale Z-detection range and pull speed based on forward velocity
		var dynamic_z_window: float = maxf(1.5, current_spd * 0.05)
		var dynamic_pull_speed: float = maxf(120.0, current_spd * 2.5)

		# Iterate through all nodes registered under the Collectibles group
		for item in player.get_tree().get_nodes_in_group("Collectibles"):
			if is_instance_valid(item) and item is Node3D:
				var delta_x: float = item.global_position.x - player_pos.x
				var delta_y: float = item.global_position.y - player_pos.y
				var xy_distance: float = Vector2(delta_x, delta_y).length()
				var z_distance: float = absf(item.global_position.z - player_pos.z)

				# Pull collectible toward player if within lateral radius and Z-axis window
				if xy_distance <= MAX_XY_RADIUS and z_distance <= dynamic_z_window:
					item.global_position.x = move_toward(item.global_position.x, player_pos.x, dynamic_pull_speed * delta)
					item.global_position.y = move_toward(item.global_position.y, player_pos.y, dynamic_pull_speed * delta)
