extends Node3D

signal Wall_Hit # A signal for when a wall is hit

# ------- Scenes to be loaded -------

# Road scenes
const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1 Scene

# Side thing scenes
const BUILDING1 = preload("res://Streets/Building.tscn") # Building 1 Scene

# Obstacle scenes
const JUMP_OBSTACLE = preload("res://Obstacles/Testing_Beam.tscn") # An obstacle to jump over
const WALL = preload("res://Obstacles/Wall.tscn") # A wall you cannot jump over
const SLIDE_BEAM = preload("res://Obstacles/Sliding_Beam.tscn") # A beam you must slide under

# ------- VARIABLES -------

# Constants
const DIST_BETWEEN_SIDE_OBJECTS: int = 30 # Distance between the things on the side
const MIN_LOCAL_DIST: int = 60 # The minimum local z point where things on the side can spawn
const MAX_LOCAL_DIST: int = 300 # The maximum local z point where things on the side can spawn
const DIST_TO_SIDE: float = 9.5 # The distance to the side of the road from the middle
const LEFT_ANGLE: float = 90.0  # The left side's angle to put the things on the side at
const RIGHT_ANGLE: float = -90.0 # The right side's angle to put the things on the side at

# Safe camera frustum despawn buffer distances
const ROW_DESPAWN_OFFSET: float = 25.0
const ROAD_DESPAWN_OFFSET: float = 40.0

# Arrays to choose from for spawning
var roads_to_spawn: Array = [STREET_TEMPLATE1] # Possible roads to spawn
var side_to_spawn: Array = [BUILDING1] # Possible things to spawn on the sides
var obstacles_to_spawn: Array = [JUMP_OBSTACLE, WALL, SLIDE_BEAM] # Possible obstacles to spawn

# Nodes
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var in_road: Node3D = $In_Road # The parent node of all things in the road
@onready var roads: Node3D = $Roads # The node all roads are under
@onready var power: Node = $Power # The power controller
@onready var row_detector: Area3D = $Row_Detector # The thing that detects if you passed the row
@onready var obstacles: Node3D = $Obstacles # The parent node of the obstacles
@export var crystal_spawner: Node3D # The spawner of crystals
@export var player: Player # The player

# Exported variables
@export var obstacle_min_reaction_time: float = 0.5 # The minimum reaction time for obstacles
@export var obstacle_max_reaction_time: float = 1.0 # The maximum reaction time for obstacles
@export var obstacle_speed_difference: float = 5.0 # The difference in speed between the crystal spawner and the obstacle spawner
@export var percentage_obstacle_spawned: int = 50 # the percentage change for each obstacle to be spawned

# Variables
var current_road_count: int = 1 # The current amount of roads currently existing
var set_up: bool = false # A variable for if the rows have been set up
var road_1: street # The road the player is on
var road_2: street # The next road to be entered
var road_3: street # The road to be loaded upon entering next road
var row_count: int = 0 # The amount of rows currently in the game
var rows_passed: int = 0 # The amount of rows the player has passed
var current_rows: Array = [] # The current rows in existance
var row_to_free # The row that will be freed when you pass a row

# ------- METHODS -------

## Connects the starting street signal to the method.
## Runs on startup
func _ready() -> void:
	# Set road 1 to starting street
	road_1 = starting_street
	populate_side_props(road_1)
	
	road_2 = create_next_road(road_1)
	road_3 = create_next_road(road_2)
	
	# while there is less than 15 rows, summon a row of obstacles
	while current_rows.size() < 15:
		summon_row_obstacles()
	
	# Place the Area3D to the closest row before the player
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


## Removes old roads, buildings, and obstacles. 
## Run to disable the previous area
func advance_road_queue() -> void:
	if is_instance_valid(road_1):
		road_1.queue_free()

	road_1 = road_2
	road_2 = road_3
	road_3 = create_next_road(road_2)


## Spawns the roads and buildings on the links.
## Function runs to enter road
func create_next_road(street_node: street) -> street:
	var new_road = summon_road()
	new_road.global_position = street_node.end_link.global_position
	populate_side_props(new_road)
	return new_road


func populate_side_props(street_node: street) -> void:
	var distance_down_road: int = MIN_LOCAL_DIST
	while distance_down_road < 300:
		var current_left_spawn = summon_side(street_node)
		var current_right_spawn = summon_side(street_node)
		
		current_left_spawn.position = Vector3(-DIST_TO_SIDE, 0.0, -distance_down_road)
		current_right_spawn.position = Vector3(DIST_TO_SIDE, 0.0, -distance_down_road)
		current_left_spawn.global_rotation.y = deg_to_rad(LEFT_ANGLE)
		current_right_spawn.global_rotation.y = deg_to_rad(RIGHT_ANGLE)
		
		distance_down_road += DIST_BETWEEN_SIDE_OBJECTS


## Used to connect the obstacle's signal to the method
func connect_obstacle(obstacle: Node3D) -> void:
	obstacle.add_to_group("Obstacles")
	if obstacle.has_signal("body_entered"):
		obstacle.body_entered.connect(body_entered)


## Runs on body entering.
## Connects to obstacles which can be hit
func body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		power.obstacle_hit()
		Wall_Hit.emit()


## Summons a row of obstacles
func summon_row_obstacles() -> void:
	var taken_rows: Array = []
	var wall_spawns: Array = []
	var wall_count: int = 0
	
	row_count += 1
	var row_reference = Node3D.new()
	row_reference.name = "Row" + str(row_count)
	obstacles.add_child(row_reference)

	var basis_node: Node3D = player if not set_up else current_rows.back()
	var basis_z: float = basis_node.global_position.z if is_instance_valid(basis_node) else 0.0
	var spawn_dist: float = find_optimal_distance()
	var row_z: float = basis_z - spawn_dist

	row_reference.global_position = Vector3(0.0, 0.0, row_z)
	current_rows.append(row_reference)
	set_up = true
	
	# For loop for each row index
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
			
			for row_num in obstacle_instance.Row_Count - 1:
				if obstacle_instance.direction_stretched == "Right":
					current_row += 1
				elif obstacle_instance.direction_stretched == "Left":
					current_row -= 1
				taken_rows.append(current_row)
			
			obstacle_instance.position.x = num * 3.0
			
			# Detect the number of walls and put it into the wall count variable
			if detect_walls(obstacle_instance):
				wall_count += 1
				wall_spawns.append(obstacle_instance)
	
	# If the wall count is 5 or more, pick a random one and delete it
	if wall_count >= 5 and not wall_spawns.is_empty():
		var to_free = wall_spawns.pick_random()
		if is_instance_valid(to_free):
			to_free.queue_free()


## Detects if the given obstacle is a wall
func detect_walls(obstacle: Obstacle):
	if obstacle.dodge_capabilities == "False":
		return true


## Finds the optimal distance for an obstacle
func find_optimal_distance() -> float:
	if not power:
		return 22.5

	var base_spd: float = power.base_speed if "base_speed" in power else 15.0
	var max_spd: float = power.max_speed if "max_speed" in power else 343.0
	var target_spd: float = power.target_speed if "target_speed" in power else base_spd

	var clamped_spd: float = clampf(target_spd, base_spd, max_spd)

	var base_rate: float = 1.0 / 1.50
	var max_rate: float = base_rate * 12.0

	var current_rate: float = remap(clamped_spd, base_spd, max_spd, base_rate, max_rate)
	return clamped_spd / current_rate


## Summons a road and returns said road to later be put in its place
func summon_road() -> street:
	var road_spawn = roads_to_spawn.pick_random().instantiate() as street
	roads.add_child(road_spawn)
	return road_spawn


## Summons something to go on the side of the road, such as buildings
func summon_side(road_node: street) -> Node3D:
	var side_spawn = side_to_spawn.pick_random().instantiate() as Node3D
	road_node.add_child(side_spawn)
	return side_spawn


## Runs what happens when running into the area3D to detect when the player passes a row
func _on_row_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		_advance_row_queue()


func _advance_row_queue() -> void:
	if current_rows.is_empty():
		return
	if is_instance_valid(row_to_free):
		row_to_free.queue_free()
	row_to_free = current_rows.pop_front()
	summon_row_obstacles()
	if not current_rows.is_empty():
		place_Area3D(current_rows.front().global_position.z)


## Places the area3D's global_position to the given variable
func place_Area3D(z_loc: float) -> void:
	row_detector.global_position.z = z_loc
