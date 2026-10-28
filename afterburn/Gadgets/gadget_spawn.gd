## Dedicated spawner node that projects standalone gadget pickups ahead of the player at timed intervals.
## Operates independently of track generation to ensure consistent gadget availability.
extends Node3D

@export_category("Scene References")
## PackedScene file instantiated when spawning a gadget pickup in 3D space.
@export var gadget_pickup_scene: PackedScene

## Reference to the main player node. Auto-assigned at runtime if left null.
@export var player: Player

@export_category("Spawn Timing")
## Minimum interval in seconds between periodic gadget spawns.
@export var min_spawn_interval: float = 20.0

## Maximum interval in seconds between periodic gadget spawns.
@export var max_spawn_interval: float = 25.0

@export_category("Track Layout")
## Total number of active movement lanes across the track.
@export var total_lanes: int = 5

## Width of each lane in world units.
@export var lane_width: float = 3.0

## Distance ahead of the player (in Z-axis world units) where pickups are spawned.
@export var spawn_distance_ahead: float = 100.0

## Internal countdown timer tracking seconds remaining until the next spawn attempt.
var _spawn_timer: float = 0.0


func _ready() -> void:
	if not player:
		player = get_tree().get_first_node_in_group("Player") as Player
	
	# Set initial delay to a random float between 20.0 and 25.0 seconds
	_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)


func _process(delta: float) -> void:
	if not gadget_pickup_scene:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_gadget()
		_spawn_timer = randf_range(min_spawn_interval, max_spawn_interval)


## Calculates track position and instantiates a gadget pickup ahead of the player.
func _spawn_gadget() -> void:
	var target_body: Node3D = _get_moving_target()
	if not target_body:
		return

	# Pick a random lane index and convert it to a symmetric X-offset centered at 0.0
	var lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset: int = lane - (total_lanes / 2)
	var gadget_x: float = lane_offset * lane_width

	var gadget_instance = gadget_pickup_scene.instantiate() as Node3D
	get_parent().add_child(gadget_instance)

	# Position pickup floating 1.0 unit above the track floor at the calculated lane and Z-distance
	var spawn_z: float = target_body.global_position.z - spawn_distance_ahead
	gadget_instance.global_position = Vector3(gadget_x, 1.0, spawn_z)


## Safely extracts the player's physical body node or falls back to the player root node.
func _get_moving_target() -> Node3D:
	if not player:
		player = get_tree().get_first_node_in_group("Player") as Player

	if player and player.body:
		return player.body

	return player
