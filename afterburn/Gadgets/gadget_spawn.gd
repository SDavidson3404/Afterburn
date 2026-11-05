## Dedicated spawner node that projects standalone gadget pickups ahead of the player based on speed-calculated distance.
## Calculates spawn distance using 20-25 seconds of travel time at target speed and acceleration.
extends Node3D

@export_category("Scene References")
## PackedScene file instantiated when spawning a gadget pickup in 3D space.
@export var gadget_pickup_scene: PackedScene

## Reference to the main player node. Auto-assigned at runtime if left null.
@export var player: Player

## Reference to the main power manager node. Auto-assigned at runtime if left null.
@export var power: Node

@export_category("Spawn Distance Pacing")
## Minimum time window in seconds used to calculate spawn distance ahead of player.
@export var min_spawn_time: float = 20.0

## Maximum time window in seconds used to calculate spawn distance ahead of player.
@export var max_spawn_time: float = 25.0

@export_category("Track Layout")
## Total number of active movement lanes across the track.
@export var total_lanes: int = 5

## Width of each lane in world units.
@export var lane_width: float = 3.0

# Runtime state tracking
var _active_gadget: Node3D = null


func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("Player") as Player
	if not power and player:
		power = player.get("power_node") as Node


func _process(_delta: float) -> void:
	if not gadget_pickup_scene:
		return

	var target_player := _get_moving_target()
	if not target_player:
		return

	var power_mgr := _get_power_manager(target_player)
	if power_mgr and not power_mgr.get("is_run_active"):
		return

	# Monitor active gadget position relative to player to detect missed pickups
	if is_instance_valid(_active_gadget):
		var relative_z: float = target_player.to_local(_active_gadget.global_position).z
		# Trigger miss handler if gadget moves 5+ units behind the player
		if relative_z > 5.0:
			_on_gadget_missed()
		return

	# If no active gadget exists in the world, spawn the next gadget ahead
	_spawn_gadget()


## Calculates distance 20-25 seconds ahead factoring speed acceleration and instantiates gadget pickup.
func _spawn_gadget() -> void:
	if not gadget_pickup_scene or is_instance_valid(_active_gadget):
		return

	var target_body := _get_moving_target()
	if not target_body:
		return

	var power_mgr := _get_power_manager(target_body)

	# Extract target speed and acceleration from power manager
	var target_speed: float = 15.0
	var speed_accel: float = 0.25

	if power_mgr:
		if "target_speed" in power_mgr:
			target_speed = power_mgr.target_speed
		elif "current_speed" in power_mgr:
			target_speed = power_mgr.current_speed

		if "speed_acceleration" in power_mgr:
			speed_accel = power_mgr.speed_acceleration

	# Calculate travel distance over a random 20-25 second window: D = v * t + 0.5 * a * t^2
	var spawn_time_window: float = randf_range(min_spawn_time, max_spawn_time)
	var spawn_distance: float = (target_speed * spawn_time_window) + (0.5 * speed_accel * spawn_time_window * spawn_time_window)

	# Pick a random lane index and convert to symmetric X-offset centered at 0.0
	var lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset: int = lane - (total_lanes / 2)
	var gadget_x: float = lane_offset * lane_width

	var gadget_instance = gadget_pickup_scene.instantiate() as Node3D
	get_parent().add_child(gadget_instance)
	_active_gadget = gadget_instance

	# Position pickup floating 1.0 unit above track floor along player's forward transform basis
	var spawn_pos: Vector3 = target_body.global_position
	spawn_pos += -target_body.global_transform.basis.z * spawn_distance
	spawn_pos.x = gadget_x
	spawn_pos.y = 1.0

	gadget_instance.global_position = spawn_pos


## Callback triggered when active gadget passes behind player uncollected.
func _on_gadget_missed() -> void:
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
