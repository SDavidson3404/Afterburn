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
@onready var side_parent: Node3D = $Side # The parent node of all things on the sides

## Connects the starting street signal to the method.
## Runs on startup
func _ready() -> void:
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)

## Spawns the roads and buildings on the links.
## Function runs to enter road
func enter(street_node: street):
	
	# Loop for each link on a road
	for child in street_node.get_links(street_node.links):
		var current_spawn # 
		
		# Gets and instances a building node
		# Runs only if "Right" or "Left" is in the name of the link
		if "Right" in child.name or "Left" in child.name:
			var side = side_to_spawn.pick_random()
			var side_spawn = side.instantiate()
			side_parent.add_child(side_spawn)
			current_spawn = side_spawn
		
		# Gets and instances a road scene
		# Runs only if "End" is in the name of the link
		elif "End" in child.name:
			var road = roads_to_spawn.pick_random()
			var road_spawn = road.instantiate()
			roads.add_child(road_spawn)
			road_spawn.entered.connect(disable)
			current_spawn = road_spawn
		
		# Set global transform for the spawned node
		current_spawn.global_transform = child.global_transform
	
	# Summon the obstacles and collectibles
	summon_in_road(street_node)

## Removes old roads, buildings, and obstacles. 
## Run to disable the previous area
func disable(not_disable: street):
	not_disable.set_enter_potential(false)
	
	# If road is not the new road, remove it.
	for child in roads.get_children():
		if child != not_disable:
			child.queue_free()
			
	# Remove all buildings
	for child in side_parent.get_children():
		child.queue_free()
	
	# If the road is valid, then run enter method
	if is_instance_valid(not_disable):
		enter(not_disable)


## Summon obstacles and collectibles. 
## Run to summon stuff in the road
func summon_in_road(road):
	
	# Run 12 times from 0 to 12
	for num in 11:
		
		# Get each row in the road
		for row in road.get_rows():
			var item_to_spawn
			
			# Get a random number from 1 to 10
			var chance = randi_range(1, 20)
			
			# If the random number is less than or equal to 10, pick a random obstacle to spawn
			if num > 0 and chance <= 10:
				item_to_spawn = obstacles_to_spawn.pick_random()
			
			# If the random number is 20, pick a random collectible to spawn
			elif num > 0 and chance == 20:
				item_to_spawn = collectibles_to_spawn.pick_random()
			
			# If there is something to spawn
			if item_to_spawn:
				
				# Spawn the item
				var item_spawn = item_to_spawn.instantiate()
				in_road.add_child(item_spawn)
				
				# Set the location of the item
				item_spawn.global_position.x = row.global_position.x
				item_spawn.global_position.z = (row.global_position.z - (num * 30))
				if item_to_spawn in collectibles_to_spawn:
					item_spawn.global_position.y = 1.5
