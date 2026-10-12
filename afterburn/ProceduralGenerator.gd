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
	
	# Connect the entered signal as a one shot
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)
	
	# Start the run in the power controller 
	power.start_run()
	
	# while there is less than 15 rows, summon a row of obstacles
	while current_rows.size() < 15:
		summon_row_obstacles()
	
	# Place the Area3D to the closest row before the player
	place_Area3D(current_rows.front().global_position.z)


## Spawns the roads and buildings on the links.
## Function runs to enter road
func enter(street_node: street):
	
	# Create a variable for the distance of the current object
	var distance_down_road: int = MIN_LOCAL_DIST
	
	# While loop for when the distance down the road is less than 300
	while distance_down_road < 300:
		
		# Summon a side object both for the right and left
		var current_left_spawn = summon_side(street_node)
		var current_right_spawn = summon_side(street_node)
		
		# Set the position of both current spawns
		current_left_spawn.position = Vector3(-DIST_TO_SIDE, 0.0, -distance_down_road)
		current_right_spawn.position = Vector3(DIST_TO_SIDE, 0.0, -distance_down_road)
		
		# Set the rotation of both current spawns
		current_left_spawn.global_rotation.y = deg_to_rad(LEFT_ANGLE)
		current_right_spawn.global_rotation.y = deg_to_rad(RIGHT_ANGLE)
		
		# Add the distance of the object to the distance down road variable
		distance_down_road += DIST_BETWEEN_SIDE_OBJECTS
	
	# Summon a road
	var current_road_spawn = summon_road()
	
	# Set the position of the current road
	current_road_spawn.global_position = street_node.end_link.global_position
	
	# Up the road count
	current_road_count += 1
	
	# Update the road variables based on the current road
	match street_node:
		road_1:
			road_2 = current_road_spawn
		road_2:
			road_3 = current_road_spawn
	
	# If current road count is 2 and road_2 exists
	if current_road_count < 3 and road_2:
		
		# Run this method for the new road
		enter(road_2)

## Used to connect the obstacle's signal to the method
func connect_obstacle(obstacle): obstacle.body_entered.connect(body_entered)

## Runs on body entering.
## Connects to obstacles which can be hit
func body_entered(body: Node3D):
	
	# If the body is the player
	if body.is_in_group("Player"):
		
		# Run the obstacle hit method in the power controller and emit the signal
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

## Summons a row of obstacles
func summon_row_obstacles():
	
	# Create necessary variables
	var taken_rows: Array = []
	var wall_spawns: Array = []
	var wall_count: int = 0
	var row_z_offset: Vector3
	
	# Create a node to reference the row z point
	var row_reference = Node3D.new()
	
	# Up the row count
	row_count += 1
	
	# Update the name to reflect which row it is
	row_reference.name = "Row" + str(row_count)
	
	# Add it as a child of the obstacles parent node
	obstacles.add_child(row_reference)
	
	# For loop for each row index
	for num in [-2, -1, 0, 1, 2]:
		
		# Essencially flip a coin
		if randi_range(1, 100) <= percentage_obstacle_spawned:
			
			# If all five rows are taken, end the method
			if taken_rows.size() >= 5:
				return
			
			# Create and instance an obstacle of a random type
			var obstacle = obstacles_to_spawn.pick_random()
			var obstacle_instance = obstacle.instantiate()
			
			# Add it as a child and connect its signal
			row_reference.add_child(obstacle_instance)
			connect_obstacle(obstacle_instance)
			
			# Select the main row of the possible rows for the obstacle
			var main_row = obstacle_instance.possible_main_rows.pick_random()
			
			# Loop to select a new main row that continues if the row is taken and reselects one
			var loop_count: int = 0
			while main_row in taken_rows:
				if loop_count <= 10:
					loop_count += 1
					main_row = obstacle_instance.possible_main_rows.pick_random()
			
			# Save the current row being messed with starting with the main row
			var current_row: int = main_row
			
			# Append the row to the taken rows array
			taken_rows.append(current_row)
			
			# For the amount of times in the row count of the obstacle
			for row_num in obstacle_instance.Row_Count - 1:
				
				# If the obstacle stretches right, increase the current row and append it to the taken rows
				if obstacle_instance.direction_stretched == "Right":
					current_row += 1
					taken_rows.append(current_row)
				
				# If the obstacle stretches left, decrease the current row and append it to the taken rows
				elif obstacle_instance.direction_stretched == "Left":
					current_row -= 1
					taken_rows.append(current_row)
			
			# If the first row is not set up, find the z offset based on the player's position
			if not set_up:
				row_z_offset = place_obstacle(num, player)
			
			# If it is set up, get the offset based on the back row
			else:
				row_z_offset = place_obstacle(num, current_rows.back())
			
			# Place the obstacle in its row
			obstacle_instance.global_position.x = row_z_offset.x
			
			# Detect the number of walls and put it into the wall count variable
			if detect_walls(obstacle_instance):
				wall_count += 1
	
	# If the wall count is 5 or more, pick a random one and delete it
	if wall_count >= 5:
		var to_free = wall_spawns.pick_random()
		to_free.queue_free()
	
	# If the offset is chosen, set the row's position to the offset
	if row_z_offset:
		row_reference.global_position = Vector3(0.0, 0.0, row_z_offset.z)
		
		# Append it into the current rows and set set_up to be true
		current_rows.append(row_reference)
		set_up = true

## Detects if the given obstacle is a wall
func detect_walls(obstacle: Obstacle):
	
	# If you cannot dodge the obstacle, return true
	if obstacle.dodge_capabilities == "False":
		return true

## Gets the position based on the basis point and the row index
func place_obstacle(row_index: int, basis_z):
	
	# Get the optimal distance
	var dist = find_optimal_distance()
	
	# Get the z offset
	var z_offset: float = basis_z.global_position.z - dist
	
	# Return the Vector3 with the row index times 3, and the offset
	return Vector3(row_index * 3, 0.0, z_offset)


## Finds the optimal distance for an obstacle
func find_optimal_distance():
	
	# Get the player's speed
	var clamped_speed = crystal_spawner._get_clamped_speed()
	
	# Remap the speed from a range of base speed to max speed to a range of max reaction time to min reaction time
	var reaction_time = remap(clamped_speed, crystal_spawner.base_speed, crystal_spawner.max_speed, obstacle_max_reaction_time, obstacle_min_reaction_time)
	
	# Return the product of the speed and reaction time
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

## Runs what happens when running into the area3D to detect when the player passes a row
func _on_row_detector_body_entered(body: Node3D) -> void:
	
	# If the body is in the player group
	if body.is_in_group("Player"):
		
		# If the row to free exists, delete it
		if is_instance_valid(row_to_free):
			row_to_free.queue_free()
		
		# Set row to free to the passed row
		row_to_free = current_rows.front()
		
		# Remove the passed row from current rows
		current_rows.erase(current_rows.front())
		
		# Summon a new row of obstacles
		summon_row_obstacles()
		
		# Place the area3D to the next row
		place_Area3D(current_rows.front().global_position.z)

## Places the area3D's global_position to the given variable
func place_Area3D(z_loc: float): row_detector.global_position.z = z_loc
