extends Node3D

signal Wall_Hit # A signal for when a wall is hit

# Scenes to be loaded
const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1 Scene
const BUILDING1 = preload("res://Streets/Building.tscn") # Building 1 Scene
const crystal = preload("res://Collectibles/crystal.tscn") # Crystal Scene
const JUMP_OBSTACLE = preload("res://Obstacles/Testing_Beam.tscn") # An obstacle to jump over
const WALL = preload("res://Obstacles/Wall.tscn") # A wall you cannot jump over
const SLIDE_BEAM = preload("res://Obstacles/Sliding_Beam.tscn") # A beam you must slide under

const DIST_BETWEEN_SIDE_OBJECTS: int = 30
const MIN_LOCAL_DIST: int = 60
const MAX_LOCAL_DIST: int = 300
const DIST_TO_SIDE: float = 9.5
const LEFT_ANGLE: float = 90.0
const RIGHT_ANGLE: float = -90.0

# Arrays to choose from for spawning
var roads_to_spawn: Array = [STREET_TEMPLATE1] # Possible roads to spawn
var side_to_spawn: Array = [BUILDING1] # Possible things to spawn on the sides
var collectibles_to_spawn: Array = [crystal] # Possible collectibles to spawn
var obstacles_to_spawn: Array = [JUMP_OBSTACLE, WALL, SLIDE_BEAM] # Possible obstacles to spawn

# Nodes
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var in_road: Node3D = $In_Road # The parent node of all things in the road
@onready var roads: Node3D = $Roads # The node all roads are under
@onready var power: Node = $Power # The power controller
@onready var row_detector: Area3D = $Row_Detector
@onready var obstacles: Node3D = $Obstacles
@export var crystal_spawner: Node3D # The spawner of crystals
@export var player: Player

@export var obstacle_min_reaction_time: float = 0.5
@export var obstacle_max_reaction_time: float = 1.0
@export var obstacle_speed_difference: float = 5.0

# Variables
var current_road_count: int = 1 # The current amount of roads currently existing
var set_up: bool = false
var road_1: street # The road the player is on
var road_2: street # The next road to be entered
var road_3: street # The road to be loaded upon entering next road
var row_count: int = 0
var rows_passed: int = 0
var current_rows: Array = []
var row_to_free

## Connects the starting street signal to the method.
## Runs on startup
func _ready() -> void:
	
	# Set road 1 to starting street
	road_1 = starting_street
	
	# Connect the entered signal as a one shot
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)
	
	# Start the run in the power controller 
	power.start_run()
	
	while current_rows.size() < 15:
		summon_row_obstacles()
	
	place_Area3D(current_rows.front().global_position.z)


## Spawns the roads and buildings on the links.
## Function runs to enter road
func enter(street_node: street):
	var distance_down_road: int = MIN_LOCAL_DIST
	
	while distance_down_road < 300:
		var current_left_spawn = summon_side(street_node)
		var current_right_spawn = summon_side(street_node)
		
		current_left_spawn.position = Vector3(-DIST_TO_SIDE, 0.0, -distance_down_road)
		current_right_spawn.position = Vector3(DIST_TO_SIDE, 0.0, -distance_down_road)
		current_left_spawn.global_rotation.y = deg_to_rad(LEFT_ANGLE)
		current_right_spawn.global_rotation.y = deg_to_rad(RIGHT_ANGLE)
		distance_down_road += DIST_BETWEEN_SIDE_OBJECTS
	var current_road_spawn = summon_road()
	current_road_spawn.global_position = street_node.end_link.global_position
	current_road_count += 1
	match street_node:
		road_1:
			road_2 = current_road_spawn
		road_2:
			road_3 = current_road_spawn
	
	# If current road count is 2 or less and road 2 exists,
	# Summon walls and next road for the second road
	if current_road_count < 3 and road_2 and not road_2.has_summoned_obstacles:
		current_road_count += 1
		enter(road_2)

## Used to connect the obstacle's signal to the method
func connect_obstacle(obstacle): obstacle.body_entered.connect(body_entered)

## Runs on body entering.
## Connects to obstacles which can be hit
func body_entered(body: Node3D):
	if body.is_in_group("Player"):
		power.obstacle_hit()
		Wall_Hit.emit()

## Removes old roads, buildings, and obstacles. 
## Run to disable the previous area
func disable(not_disable: street):
	
	# For loop for the children of the roads parent node
	for child in roads.get_children():
		
		# If child is not the entered road or the third road,
		# Get the children of the child node and remove them
		if child != not_disable and child != road_3:
			
			# Remove the child node
			child.queue_free()
	
	# Update the roads
	road_1 = road_2
	road_2 = road_3
	road_3 = null
	
	# Up the road count
	current_road_count -= 1
	
	# If the road is valid, then run enter method
	if is_instance_valid(not_disable) and is_instance_valid(road_2):
		enter(road_2)

func summon_row_obstacles():
	var taken_rows: Array = []
	var wall_spawns: Array = []
	var wall_count: int = 0
	var row_z_offset: Vector3
	var row_reference = Node3D.new()
	row_count += 1
	row_reference.name = "Row" + str(row_count)
	obstacles.add_child(row_reference)
	for num in [-2, -1, 0, 1, 2]:
		if randi_range(1, 20) >= 10:
			if taken_rows.size() >= 5:
				return
			var obstacle = obstacles_to_spawn.pick_random()
			var obstacle_instance = obstacle.instantiate()
			row_reference.add_child(obstacle_instance)
			connect_obstacle(obstacle_instance)
			var main_row = obstacle_instance.possible_main_rows.pick_random()
			var loop_count: int = 0
			while main_row in taken_rows:
				if loop_count <= 10:
					loop_count += 1
					main_row = obstacle_instance.possible_main_rows.pick_random()
			var current_row: int = main_row
			taken_rows.append(current_row)
			for row_num in obstacle_instance.Row_Count - 1:
				if obstacle_instance.direction_stretched == "Right":
					current_row += 1
					taken_rows.append(current_row)
				elif obstacle_instance.direction_stretched == "Left":
					current_row -= 1
					taken_rows.append(current_row)
			if not set_up:
				row_z_offset = place_obstacle(num, player)
			else:
				row_z_offset = place_obstacle(num, current_rows.back())
			obstacle_instance.global_position.x = row_z_offset.x
			detect_walls(obstacle_instance)
	if wall_count >= 5:
		var to_free = wall_spawns.pick_random()
		to_free.queue_free()
	if row_z_offset:
		row_reference.global_position = Vector3(0.0, 0.0, row_z_offset.z)
		current_rows.append(row_reference)
		set_up = true

func detect_walls(obstacle: Obstacle):
	if obstacle.dodge_capabilities == "False":
		return true

func place_obstacle(row_index: int, basis_z):
	var dist = find_optimal_distance()
	var z_offset: float = basis_z.global_position.z - dist
	return Vector3(row_index * 3, 0.0, z_offset)

func find_optimal_distance():
	var clamped_speed = crystal_spawner._get_clamped_speed()
	var reaction_time = remap(clamped_speed, crystal_spawner.base_speed, crystal_spawner.max_speed, obstacle_max_reaction_time, obstacle_min_reaction_time)
	return clamped_speed * reaction_time

## Summons a road and returns said road to later be put in its place
func summon_road():
	
	# Pick a random road and instance it
	var road = roads_to_spawn.pick_random()
	var road_spawn = road.instantiate()
	
	# Add it as a child and connect the entered signal
	roads.add_child(road_spawn)
	road_spawn.entered.connect(disable)
	
	# Return the road to be placed later
	return road_spawn


## Summons something to go on the side of the road, such as buildings
func summon_side(road: street):
	
	# Pick a random thing to spawn and instance it
	var side = side_to_spawn.pick_random()
	var side_spawn = side.instantiate()
	
	# Add it as a child of the given road
	road.add_child(side_spawn)
	
	# Return the side object to be placed later
	return side_spawn


func _on_row_detector_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if is_instance_valid(row_to_free):
			row_to_free.queue_free()
		row_to_free = current_rows.front()
		current_rows.erase(current_rows.front())
		summon_row_obstacles()
		place_Area3D(current_rows.front().global_position.z)

func place_Area3D(z_loc: float):
	row_detector.global_position.z = z_loc
