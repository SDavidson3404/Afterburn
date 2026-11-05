## Dedicated spawner node that projects standalone gadget pickups ahead of the player.
## Uses player distance traveled to determine spawn milestones based on 20-25 seconds of travel time.
extends Node3D

@export_category("Scene References")
## PackedScene file instantiated when spawning a gadget pickup in 3D space.
@export var gadget_pickup_scene: PackedScene

## Reference to the main player node. Auto-assigned at runtime if left null.
@export var player: Player

## Reference to the main power manager node. Auto-assigned at runtime if left null.
@export var power: Node

@export_category("Spawn Distance Pacing")
## Minimum projected travel time in seconds before the next gadget spawn milestone.
@export var min_travel_time: float = 16.0

## Maximum projected travel time in seconds before the next gadget spawn milestone.
@export var max_travel_time: float = 20.0

@export_category("Track Layout")
## Total number of active movement lanes across the track.
@export var total_lanes: int = 5

## Width of each lane in world units.
@export var lane_width: float = 3.0

# Runtime distance tracking
var _active_gadget: Node3D = null
var _distance_traveled_since_spawn: float = 0.0
var _target_distance_for_next_spawn: float = 0.0
var _last_player_z: float = 0.0
var _is_tracking: bool = false


func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("Player") as Player
	if not power and player:
		power = player.get("power_node") as Node

	_calculate_next_spawn_distance()


func _process(_delta: float) -> void:
	if not gadget_pickup_scene:
		return

	var target_player := _get_moving_target()
	if not target_player:
		return

	var power_mgr := _get_power_manager(target_player)
	if power_mgr and not power_mgr.get("is_run_active"):
		_is_tracking = false
		return

	# Initialize player Z tracking when run begins
	if not _is_tracking:
		_last_player_z = target_player.global_position.z
		_is_tracking = true
		return

	# Calculate meters moved along Z-axis in this frame
	var current_z: float = target_player.global_position.z
	var move_delta: float = maxf(0.0, _last_player_z - current_z)
	_last_player_z = current_z

	# Accumulate physical distance moved toward the next spawn target
	_distance_traveled_since_spawn += move_delta

	# Monitor active gadget position relative to player to detect missed pickups
	if is_instance_valid(_active_gadget):
		var relative_z: float = target_player.to_local(_active_gadget.global_position).z
		# Trigger miss handler if gadget moves 5+ units behind the player
		if relative_z > 5.0:
			_on_gadget_missed()
		return

	# Trigger spawn when distance threshold is reached and no active gadget exists
	if _distance_traveled_since_spawn >= _target_distance_for_next_spawn:
		_spawn_gadget()


## Calculates required meters to travel for next gadget based on 20-25 seconds of target speed.
func _calculate_next_spawn_distance() -> void:
	_distance_traveled_since_spawn = 0.0

	var target_player := _get_moving_target()
	var power_mgr := _get_power_manager(target_player) if target_player else null

	var current_spd: float = 15.0
	if power_mgr:
		if "target_speed" in power_mgr and power_mgr.target_speed > 0:
			current_spd = power_mgr.target_speed
		elif "current_speed" in power_mgr and power_mgr.current_speed > 0:
			current_spd = power_mgr.current_speed

	var time_window: float = randf_range(min_travel_time, max_travel_time)
	_target_distance_for_next_spawn = current_spd * time_window


## Spawns the gadget ahead on visible generated track once target distance is reached.
func _spawn_gadget() -> void:
	var target_body := _get_moving_target()
	if not target_body:
		return

	var power_mgr := _get_power_manager(target_body)

	# Query standard spawn distance so pickup renders safely within track limits
	var spawn_distance_ahead: float = 100.0
	if power_mgr and power_mgr.has_method("get_current_spawn_distance"):
		spawn_distance_ahead = power_mgr.get_current_spawn_distance()

	# Pick a random lane index and convert to symmetric X-offset centered at 0.0
	var lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset: int = lane - (total_lanes / 2)
	var gadget_x: float = lane_offset * lane_width

	var gadget_instance = gadget_pickup_scene.instantiate() as Node3D
	get_parent().add_child(gadget_instance)
	_active_gadget = gadget_instance

	# Project position forward along player transform basis
	var spawn_pos: Vector3 = target_body.global_position
	spawn_pos += -target_body.global_transform.basis.z * spawn_distance_ahead
	spawn_pos.x = gadget_x
	spawn_pos.y = 1.0

	gadget_instance.global_position = spawn_pos

	# Resolve Gadget Type Name
	var gadget_name_str: String = "Gadget"
	if "gadget_type" in gadget_instance:
		gadget_name_str = gadget_instance.TYPE_TO_ID.get(gadget_instance.gadget_type, "gadget").replace("_", " ").capitalize()

	# Terminal Debug Log
	print("[NORMAL GADGET SPAWN] ", gadget_name_str, " spawned at position: ", gadget_instance.global_position, " (Lane: ", lane + 1, ")")

	# Immediately reset distance counter and calculate next spawn target distance
	_calculate_next_spawn_distance()


## Callback triggered when active gadget passes behind player uncollected.
func _on_gadget_missed() -> void:
	if is_instance_valid(_active_gadget):
		var gadget_name_str: String = "Gadget"
		if "gadget_type" in _active_gadget:
			gadget_name_str = _active_gadget.TYPE_TO_ID.get(_active_gadget.gadget_type, "gadget").replace("_", " ").capitalize()
		print("[ITEM MISSED] ", gadget_name_str, " missed at position: ", _active_gadget.global_position)

	_clear_active_gadget()


## Frees active gadget node from memory and clears local reference.
func _clear_active_gadget() -> void:
	if is_instance_valid(_active_gadget):
		_active_gadget.queue_free()
		_active_gadget = null


## Safely extracts the power manager reference.
func _get_power_manager(target_player: Node3D) -> Node:
	if power:
		return power
	if target_player and target_player.get("power_node"):
		return target_player.get("power_node") as Node
	return null


## Safely extracts the player's physical body node or falls back to player root node.
func _get_moving_target() -> Node3D:
	if not player:
		player = get_tree().get_first_node_in_group("Player") as Player

	if player and player.body:
		return player.body

	return player
