extends Node3D

# Scenes to be loaded
const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1 Scene
const BUILDING1 = preload("res://Streets/Building.tscn") # Building 1 Scene
const crystal = preload("res://Collectibles/crystal.tscn") # Crystal Scene
const JUMP_OBSTACLE = preload("res://Obstacles/Testing_Beam.tscn") # An obstacle to jump over
const WALL = preload("res://Obstacles/Wall.tscn") # A wall you cannot jump over

# Arrays to choose from for spawning
var roads_to_spawn: Array = [STREET_TEMPLATE1] # Possible roads to spawn
var side_to_spawn: Array = [BUILDING1] # Possible things to spawn on the sides
var collectibles_to_spawn: Array = [crystal] # Possible collectibles to spawn
var obstacles_to_spawn: Array = [JUMP_OBSTACLE, WALL] # Possible obstacles to spawn

# Nodes
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var in_road: Node3D = $In_Road # The parent node of all things in the road
@onready var roads: Node3D = $Roads # The node all roads are under
@onready var power: Node = $Power # The power controller

# Variables
var current_road_count: int = 1 # The current amount of roads currently existing
var road_1: street # The road the player is on
var road_2: street # The next road to be entered
var road_3: street # The road to be loaded upon entering next road

## Connects the starting street signal to the method.
## Runs on startup
func _ready() -> void:
	
	# Set road 1 to starting street
	road_1 = starting_street
	
	# Connect the entered signal as a one shot
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)
	
	# Start the run in the power controller 
	power.start_run()

## Spawns the roads and buildings on the links.
## Function runs to enter road
func enter(street_node: street):
	# Loop for each link on a road
	for child in street_node.get_links(street_node.links):
		var current_spawn
		# Gets and instances a building node
		# Runs only if "Right" or "Left" is in the name of the link
		if "Right" in child.name or "Left" in child.name:
			current_spawn = summon_side(street_node)
		
		# Gets and instances a road scene
		# Runs only if "End" is in the name of the link
		elif "End" in child.name:
			current_spawn = summon_road()
			
			# Match the node that is being spawned from
			# and save the next road accordingly as a variable
			match street_node:
				road_1:
					road_2 = current_spawn
				road_2:
					road_3 = current_spawn
		
		# Set global transform for the spawned node
		if is_instance_valid(current_spawn):
			current_spawn.global_transform = child.global_transform
		
	# If starting street still exists, summon obstacles
	if is_instance_valid(starting_street):
		if not starting_street.has_summoned_obstacles:
			summon_in_road(street_node)
	
	# If current road count is 2 or less and road 2 exists,
	# Summon walls and next road for the second road
	if current_road_count < 3 and road_2 and not road_2.has_summoned_obstacles:
		current_road_count += 1
		summon_in_road(road_2)
		enter(road_2)

## Used to connect the obstacle's signal to the method
func connect_obstacle(obstacle):
	obstacle.body_entered.connect(body_entered)

## Runs on body entering.
## Connects to obstacles which can be hit
func body_entered(body: Node3D):
	if body.is_in_group("Player"):
		power.obstacle_hit()

## Removes old roads, buildings, and obstacles. 
## Run to disable the previous area
func disable(not_disable: street):
	
	# Set the street to not be able to be entered
	not_disable.set_enter_potential(false)
	
	# For loop for the children of the roads parent node
	for child in roads.get_children():
		
		# If child is not the entered road or the third road,
		# Get the children of the child node and remove them
		if child != not_disable and child != road_3:
			for grandchild in child.get_children():
				grandchild.queue_free()
			
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

## Summon obstacles and collectibles. 
## Run to summon stuff in the road
func summon_in_road(road: street):
	road.has_summoned_obstacles = true
	# Run 12 times from 0 to 11
	for num in 11:
		var wall_spawns: Array = []
		# Get each row in the road
		for row in road.get_rows():
			var item_to_spawn
			
			# Get a random number from 1 to 10
			var chance = randi_range(1, 20)
			
			# If the random number is less than or equal to 10, pick a random obstacle to spawn
			if num > 0 and chance <= 10:
				item_to_spawn = obstacles_to_spawn.pick_random()
				
				# Spawn the item
				var item_spawn = item_to_spawn.instantiate()
				in_road.add_child(item_spawn)
				
				# Set the location of the item
				item_spawn.global_position.z = (row.global_position.z - (num * 30))
				item_spawn.global_position.x = row.global_position.x
				
				if item_spawn.dodge_capabilities == "False":
					wall_spawns.append(item_spawn)
				
				# Connect the signal of the obstacle
				connect_obstacle(item_spawn)
		if wall_spawns.size() >= 5:
			var to_free = wall_spawns.pick_random()
			to_free.queue_free()

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
