## World generator managing infinite procedural road chunks, dynamic obstacle rows,
## passability validation, and low-overhead queue memory recycling.
extends Node3D

## Emitted when the player collides with an obstacle on the track.
signal Wall_Hit

# Preloaded scene templates for procedural road sections, buildings, and obstacles
const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn")
const BUILDING1 = preload("res://Streets/Building.tscn")
const JUMP_OBSTACLE = preload("res://Obstacles/Testing_Beam.tscn")
const WALL = preload("res://Obstacles/Wall.tscn")
const SLIDE_BEAM = preload("res://Obstacles/Sliding_Beam.tscn")

# Layout spacing constants
const DIST_BETWEEN_SIDE_OBJECTS: int = 30
const MIN_LOCAL_DIST: int = 60
const DIST_TO_SIDE: float = 9.5

# Safe camera frustum despawn buffer distances (in world Z units behind player)
const ROW_DESPAWN_OFFSET: float = 25.0
const ROAD_DESPAWN_OFFSET: float = 40.0

# Registry arrays used for procedural instantiation
var roads_to_spawn: Array = [STREET_TEMPLATE1]
var side_to_spawn: Array = [BUILDING1]
var obstacles_to_spawn: Array = [JUMP_OBSTACLE, WALL, SLIDE_BEAM]

@export_category("Node References")
## Reference to the main player controller.
@export var player: Player

@export_category("Spawn Configuration")
## Percentage chance (1 to 100) of spawning an obstacle in each lane.
@export var percentage_obstacle_spawned: int = 50

@onready var starting_street: street = $Roads/StreetTemplate
@onready var roads: Node3D = $Roads
@onready var power: Node = $Power
@onready var row_detector: Area3D = $Row_Detector
@onready var obstacles: Node3D = $Obstacles

# Runtime queue management state
var current_road_count: int = 1
var set_up: bool = false
var road_1: street
var road_2: street
var road_3: street
var row_count: int = 0
var current_rows: Array = []
var row_to_free: Node


func _ready() -> void:
	# Initialize starting road queue (road_1 at 0m, road_2 at -300m, road_3 at -600m)
	road_1 = starting_street
	populate_side_props(road_1)
	
	road_2 = create_next_road(road_1)
	road_3 = create_next_road(road_2)
	
	# Pre-populate initial obstacle queue buffer (15 rows ahead of player)
	while current_rows.size() < 15:
		summon_row_obstacles()
	place_Area3D(current_rows.front().global_position.z)


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not player.body:
		return

	var player_z: float = player.body.global_position.z

	# Obstacle queue advancing loop: Flushes all passed rows even during high-speed frame spikes
	while not current_rows.is_empty():
		var front_row_z: float = current_rows.front().global_position.z
		if player_z < (front_row_z - ROW_DESPAWN_OFFSET):
			_advance_row_queue()
		else:
			break

	# Seamless road recycling: Trigger after player is 40m past road_2 start
	if is_instance_valid(road_2) and player_z < (road_2.global_position.z - ROAD_DESPAWN_OFFSET):
		advance_road_queue()


## Recycles oldest trailing road segment behind player and appends new road chunk ahead.
func advance_road_queue() -> void:
	if is_instance_valid(road_1):
		road_1.queue_free()

	road_1 = road_2
	road_2 = road_3
	road_3 = create_next_road(road_2)


## Instantiates upcoming road tile at the end anchor of target street node.
func create_next_road(street_node: street) -> street:
	var new_road = summon_road()
	new_road.global_position = street_node.end_link.global_position
	populate_side_props(new_road)
	return new_road


## Instantiates side environment props along borders of a road chunk.
func populate_side_props(street_node: street) -> void:
	var distance_down_road: int = MIN_LOCAL_DIST
	while distance_down_road < 300:
		var current_left_spawn = summon_side(street_node)
		var current_right_spawn = summon_side(street_node)
		
		current_left_spawn.position = Vector3(-DIST_TO_SIDE, 0.0, -distance_down_road)
		current_right_spawn.position = Vector3(DIST_TO_SIDE, 0.0, -distance_down_road)
		current_left_spawn.global_rotation.y = deg_to_rad(90.0)
		current_right_spawn.global_rotation.y = deg_to_rad(-90.0)
		
		distance_down_road += DIST_BETWEEN_SIDE_OBJECTS


## Adds obstacle to group and connects collision signal handlers.
func connect_obstacle(obstacle: Node3D) -> void:
	obstacle.add_to_group("Obstacles")
	if obstacle.has_signal("body_entered"):
		obstacle.body_entered.connect(body_entered)


## Callback triggered on player collision with an obstacle node.
func body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		power.obstacle_hit()
		Wall_Hit.emit()


## Generates a new row of obstacles and verifies track passability.
func summon_row_obstacles() -> void:
	var taken_rows: Array = []
	var wall_spawns: Array = []
	var wall_count: int = 0
	
	row_count += 1
	var row_reference = Node3D.new()
	row_reference.name = "Row" + str(row_count)
	obstacles.add_child(row_reference)

	# Calculate row Z-coordinate before lane rolls to guarantee row is always tracked in queue
	var basis_node: Node3D = player if not set_up else current_rows.back()
	var basis_z: float = basis_node.global_position.z if is_instance_valid(basis_node) else 0.0
	var spawn_dist: float = _get_reaction_spawn_distance()
	var row_z: float = basis_z - spawn_dist

	row_reference.global_position = Vector3(0.0, 0.0, row_z)
	current_rows.append(row_reference)
	set_up = true
	
	# Iterate across 5 track lane indices (-2, -1, 0, 1, 2)
	for num in [-2, -1, 0, 1, 2]:
		if randi_range(1, 100) <= percentage_obstacle_spawned:
			if taken_rows.size() >= 5:
				break
			
			var obstacle_packed = obstacles_to_spawn.pick_random()
			var obstacle_instance = obstacle_packed.instantiate() as Obstacle
			
			var available_rows: Array = []
			for r in obstacle_instance.possible_main_rows:
				if not (r in taken_rows):
					available_rows.append(r)
			
			if available_rows.is_empty():
				obstacle_instance.queue_free()
				continue
			
			row_reference.add_child(obstacle_instance)
			connect_obstacle(obstacle_instance)
			
			var main_row = available_rows.pick_random()
			var current_row: int = main_row
			taken_rows.append(current_row)
			
			# Reserve adjacent lanes for wide obstacles that stretch across multiple rows
			for row_num in obstacle_instance.Row_Count - 1:
				if obstacle_instance.direction_stretched == "Right":
					current_row += 1
				elif obstacle_instance.direction_stretched == "Left":
					current_row -= 1
				taken_rows.append(current_row)
			
			obstacle_instance.position.x = num * 3.0
			
			# Track wall obstacles to validate passability
			if obstacle_instance.dodge_capabilities == "False":
				wall_count += 1
				wall_spawns.append(obstacle_instance)
	
	# Passability check: If all 5 lanes are blocked by walls, clear one wall to guarantee an open path
	if wall_count >= 5 and not wall_spawns.is_empty():
		var to_free = wall_spawns.pick_random()
		if is_instance_valid(to_free):
			to_free.queue_free()


## Derives spawn distance from target speed and linear rate scaling (1.0X at 15 m/s to 12.0X at 343 m/s).
func _get_reaction_spawn_distance() -> float:
	if not power:
		return 22.5

	var base_spd: float = power.base_speed if "base_speed" in power else 15.0
	var max_spd: float = power.max_speed if "max_speed" in power else 343.0
	var target_spd: float = power.target_speed if "target_speed" in power else base_spd

	var clamped_spd: float = clampf(target_spd, base_spd, max_spd)

	# Linearly scale passing rate (rows per second) across target speed
	var base_rate: float = 1.0 / 1.50          # 0.667 rows/sec at 15 m/s (1.0X)
	var max_rate: float = base_rate * 12.0     # 8.000 rows/sec at 343 m/s (12.0X)

	var current_rate: float = remap(clamped_spd, base_spd, max_spd, base_rate, max_rate)
	return clamped_spd / current_rate


## Spawns a new road segment and returns reference.
func summon_road() -> street:
	var road_spawn = roads_to_spawn.pick_random().instantiate() as street
	roads.add_child(road_spawn)
	return road_spawn


## Spawns side scenery buildings attached to a road segment.
func summon_side(road_node: street) -> Node3D:
	var side_spawn = side_to_spawn.pick_random().instantiate() as Node3D
	road_node.add_child(side_spawn)
	return side_spawn


## Advances the row queue when player passes detector: Frees oldest row and appends new row.
func _on_row_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_advance_row_queue()


## Core queue advancing subroutine safely shared between collision triggers and process fallbacks.
func _advance_row_queue() -> void:
	if current_rows.is_empty():
		return
	if is_instance_valid(row_to_free):
		row_to_free.queue_free()
	row_to_free = current_rows.pop_front()
	summon_row_obstacles()
	if not current_rows.is_empty():
		place_Area3D(current_rows.front().global_position.z)


## Repositions row detector Area3D to trigger at the front row Z-coordinate.
func place_Area3D(z_loc: float) -> void:
	row_detector.global_position.z = z_loc
