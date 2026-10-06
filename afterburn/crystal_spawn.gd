extends Node3D

@export_category("Node References")
@export var crystal_scene: PackedScene
@export var player: Node3D
@export var power: Node # Central power.gd node reference

@export_category("Fuel Drain & Invincibility")
@export var invincibility_duration: float = 3.0 # Must match crystal_invincibility_duration in power.gd
@export var min_drain_time: float = 4.0 # 20% power loss (4.0s * 5 power/sec drain rate)
@export var max_drain_time: float = 5.0 # 25% power loss (5.0s * 5 power/sec drain rate)

@export_category("Speed & Reaction Curve")
@export var base_speed: float = 15.0
@export var max_speed: float = 343.0 # Mach 1
@export var max_reaction_time: float = 3.00 # Reaction window at 15 m/s (45m spawn distance)
@export var min_reaction_time: float = 1.00 # Reaction window at Mach 1 (343m spawn distance)

@export_category("Lanes Setup")
@export var lane_width: float = 3.0
@export var total_lanes: int = 5

var _active_crystal: Node3D = null
var _spawn_timer: float = 0.0
var _is_waiting_to_spawn: bool = false

## Initial spawn timer at run start
func _ready() -> void:
	_calculate_and_start_spawn_timer()

## Tracks active crystal position and counts down spawn timers
func _process(delta: float) -> void:
	if not power or not power.get("is_run_active"):
		return

	# 1. Track active crystal passing behind the player (Missed crystal)
	if is_instance_valid(_active_crystal):
		# Get Z position relative to the player's forward orientation (-Z is forward)
		var relative_z: float = player.to_local(_active_crystal.global_position).z
		if relative_z > 5.0: # 5 meters past the player
			on_crystal_missed()
		return # Do not count down spawn timer while a crystal exists on track

	# 2. Count down timer for the next crystal to spawn
	if _is_waiting_to_spawn:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_is_waiting_to_spawn = false
			spawn_crystal()

## Spawns a single crystal ahead of the player based on scaled current speed and reaction time
func spawn_crystal() -> void:
	if not crystal_scene or is_instance_valid(_active_crystal):
		return

	var crystal = crystal_scene.instantiate() as Node3D
	get_parent().add_child(crystal)
	_active_crystal = crystal

	if crystal.has_method("set_spawner"):
		crystal.set_spawner(self)

	# Fetch speed and reaction values via helper methods
	var clamped_speed: float = _get_clamped_speed()
	var reaction_time: float = _get_reaction_time(clamped_speed)
	var spawn_distance: float = clamped_speed * reaction_time

	# Select random lane from -2 to +2 index
	var random_lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset_index: int = random_lane - (total_lanes / 2)
	var x_offset: float = lane_offset_index * lane_width

	# Position crystal ahead of the player into a random lane
	var spawn_pos: Vector3 = player.global_position
	spawn_pos += -player.global_transform.basis.z * spawn_distance
	spawn_pos += player.global_transform.basis.x * x_offset

	crystal.global_position = spawn_pos

## Called by crystal.gd when player collects crystal
func on_crystal_collected() -> void:
	_clear_active_crystal()

	if power:
		power.collect_crystal()
	
	# Add score and stat tracking to DatabaseManager
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_crystal()
	
	_calculate_and_start_spawn_timer()

## Called when player passes the crystal without collecting it
func on_crystal_missed() -> void:
	_clear_active_crystal()

	_calculate_and_start_spawn_timer()

## Removes the active crystal from memory
func _clear_active_crystal() -> void:
	if is_instance_valid(_active_crystal):
		_active_crystal.queue_free()
		_active_crystal = null

## Calculates next crystal spawn arrival delay using target speed to maintain core difficulty.
func _calculate_and_start_spawn_timer() -> void:
	# Uses target_speed so spawn distance does not shrink as the player slows down
	# This prevents the system from artificially rescuing coasting players with close spawns, ensuring low-speed coasting remains a high-risk scenario
	var clamped_speed: float = _get_clamped_speed()
	var reaction_time: float = _get_reaction_time(clamped_speed)
	var target_drain_time: float = randf_range(min_drain_time, max_drain_time)

	# Freezes the crystal spawn timer until invinsibility wears off
	var active_invincibility: float = 0.0
	if power and power.get("is_invincible"):
		active_invincibility = power.get("invincibility_timer")

	# Enforce safety floor so timer is never <= 0
	_spawn_timer = active_invincibility + target_drain_time - reaction_time
	_spawn_timer = maxf(0.05, _spawn_timer)
	_is_waiting_to_spawn = true

## Safely fetches and clamps target speed within valid bounds
func _get_clamped_speed() -> float:
	var target_speed: float = power.get("target_speed") if power and power.get("target_speed") != null else base_speed
	return clampf(target_speed, base_speed, max_speed)

## Shorten reaction time as speed increases: 3.00s at 15 m/s down to 1.00s at Mach 1 (343 m/s)
func _get_reaction_time(speed: float) -> float:
	return remap(speed, base_speed, max_speed, max_reaction_time, min_reaction_time)
