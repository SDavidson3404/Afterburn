extends Node3D

const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1
const STREET_TEMPLATE2 = preload("res://Streets/street_template2.tscn") # Road 2
const crystal = preload("res://Collectibles/crystal.tscn")
var roads_to_spawn: Array = [STREET_TEMPLATE1, STREET_TEMPLATE2] # Possible roads to spawn
var collectibles_to_spawn: Array = [crystal]
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var roads: Node3D = $Roads # The node all roads are under
@onready var collectibles: Node3D = $Collectibles
var player
var collectible_spawned: bool = false

func _ready() -> void:
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)

func enter(street_node: street):
	for child in street_node.get_links(street_node.links):
		if randi_range(1, 5) == 1:
			var road = roads_to_spawn.pick_random()
			var road_spawn = road.instantiate()
			roads.add_child(road_spawn)
			road_spawn.global_position = child.global_position
			road_spawn.global_rotation.y = child.global_rotation.y
			road_spawn.entered.connect(disable, CONNECT_ONE_SHOT)
			road_spawn.set_enter_potential(true)
	for child in street_node.get_links(street_node.collectibles_links):
		if not collectible_spawned and randi_range(1, 25) == 1:
			collectible_spawned = true
			var collectible_node = collectibles_to_spawn.pick_random()
			var collectible_spawn = collectible_node.instantiate()
			collectibles.add_child(collectible_spawn)
			collectible_spawn.global_position = child.global_position
			if find_player():
				player.connect_collectible(collectible_spawn)
	collectible_spawned = false

func disable(not_disable: street):
	not_disable.set_enter_potential(false)
	for child in roads.get_children():
		if child != not_disable:
			child.queue_free()
	await get_tree().process_frame
	if is_instance_valid(not_disable):
		enter(not_disable)

func find_player():
	for child in get_tree().get_first_node_in_group("Player").get_children():
		if child.name == "CharacterBody3D":
			player = child
			return true
	return false
