## Dedicated fuel crystal spawner.
## Manages speed-adaptive vector projection, reaction-time spawn pacing, spatial miss detection, and collectible lifecycle management.
extends Node3D

@export_category("Node References")
## PackedScene instantiated for crystal collectibles.
@export var crystal_scene: PackedScene

## Reference to the main player node or character body.
@export var player: Node3D

## Reference to the main power manager node.
@export var power: Node

@export_category("Fuel Drain & Timing")
## Minimum baseline fuel drain window in seconds before spawning a crystal.
@export var min_drain_time: float = 4.0

## Maximum baseline fuel drain window in seconds before spawning a crystal.
@export var max_drain_time: float = 5.0

@export_category("Lanes Setup")
## Horizontal width of each movement lane in world units.
@export var lane_width: float = 3.0

## Total number of track movement lanes across the street.
@export var total_lanes: int = 5

# Runtime spawner state tracking
var _active_crystal: Node3D = null
var _spawn_timer: float = 0.0
var _is_waiting_to_spawn: bool = false


func _ready() -> void:
	_calculate_and_start_spawn_timer()


## Safely extracts the player's physical CharacterBody3D node or returns the root player node.
func _get_player_body() -> Node3D:
	if not player:
		return null
	var body_node = player.get("body")
	return body_node as Node3D if body_node else player


func _process(delta: float) -> void:
	if not power or not power.get("is_run_active"):
		return

	# Monitor active crystal position relative to player to detect missed collectibles
	if is_instance_valid(_active_crystal):
		var target_body := _get_player_body()
		if target_body:
			var relative_z: float = target_body.to_local(_active_crystal.global_position).z
			# Trigger miss handler if crystal moves 5+ units behind the player
			if relative_z > 5.0:
				on_crystal_missed()
		return

	# Countdown spawn timer when waiting to instantiate the next crystal
	if _is_waiting_to_spawn:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_is_waiting_to_spawn = false
			spawn_crystal()


## Projects and instantiates a new fuel crystal ahead of the player in 3D space.
func spawn_crystal() -> void:
	if not crystal_scene or is_instance_valid(_active_crystal):
		return

	var target_body := _get_player_body()
	if not target_body:
		return

	var crystal = crystal_scene.instantiate() as Node3D
	get_parent().add_child(crystal)
	_active_crystal = crystal

	# Pass spawner reference to collectible for pickup callback management
	if crystal.has_method("set_spawner"):
		crystal.set_spawner(self)

	# Query dynamic spawn distance scaled to current forward speed
	var spawn_distance: float = power.get_current_spawn_distance() if power and power.has_method("get_current_spawn_distance") else 45.0

	# Pick a random lane index and convert to symmetric X-coordinate offset
	var random_lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset_index: int = random_lane - (total_lanes / 2)
	var x_offset: float = lane_offset_index * lane_width

	# Project position forward along player transform basis
	var spawn_pos: Vector3 = target_body.global_position
	spawn_pos += -target_body.global_transform.basis.z * spawn_distance
	spawn_pos.x = x_offset
	spawn_pos.y = randf_range(1.5, 2.5)

	crystal.global_position = spawn_pos


## Callback triggered when player collects the active crystal.
func on_crystal_collected() -> void:
	_clear_active_crystal()
	if power:
		power.collect_crystal()
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_crystal()
	_calculate_and_start_spawn_timer()


## Callback triggered when active crystal passes behind player uncollected.
func on_crystal_missed() -> void:
	_clear_active_crystal()
	_calculate_and_start_spawn_timer()


## Frees active crystal node from memory and clears local reference.
func _clear_active_crystal() -> void:
	if is_instance_valid(_active_crystal):
		_active_crystal.queue_free()
		_active_crystal = null


## Calculates spawn timer delay factoring in random drain bounds, invincibility, and reaction time.
func _calculate_and_start_spawn_timer() -> void:
	var target_drain_time: float = randf_range(min_drain_time, max_drain_time)
	var active_invincibility: float = 0.0
	if power and power.get("is_invincible"):
		active_invincibility = power.get("invincibility_timer")

	var reaction_time: float = power.get_reaction_time() if power and power.has_method("get_reaction_time") else 3.0

	# Timer formula: active_invincibility + target_drain_time - reaction_time
	_spawn_timer = maxf(0.05, active_invincibility + target_drain_time - reaction_time)
	_is_waiting_to_spawn = true
