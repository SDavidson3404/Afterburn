extends Node3D

const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1
const STREET_TEMPLATE2 = preload("res://Streets/street_template2.tscn") # Road 2
const BUILDING1 = preload("res://Streets/Building.tscn")
const CLIMB_BUILDING = preload("res://Streets/Climbable_Building.tscn")
const crystal = preload("res://Collectibles/crystal.tscn")
const BOOST = preload("res://Collectibles/boost.tscn")
const CLIMBING_GEAR = preload("res://Collectibles/climbing_gear.tscn")
var roads_to_spawn: Array = [STREET_TEMPLATE1, STREET_TEMPLATE2, BUILDING1, BUILDING1, BUILDING1, CLIMB_BUILDING] # Possible roads to spawn
var collectibles_to_spawn: Array = [crystal, BOOST, CLIMBING_GEAR]
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var roads: Node3D = $Roads # The node all roads are under
@onready var collectibles: Node3D = $Collectibles
var recently_summoned_collectibles: Array = []
var player
var collectible_spawned: bool = false

func _ready() -> void:
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)

func enter(street_node: street):
	for child in street_node.get_links(street_node.links):
		if "Link" in child.name:
			var road = roads_to_spawn.pick_random()
			var road_spawn = road.instantiate()
			roads.add_child(road_spawn)
			road_spawn.global_position = child.global_position
			road_spawn.global_rotation.y = child.global_rotation.y
			if not road_spawn.is_in_group("Building"):
				road_spawn.entered.connect(disable, CONNECT_ONE_SHOT)
				road_spawn.set_enter_potential(true)
	for child in street_node.get_links(street_node.collectibles_links):
		if not collectible_spawned and randi_range(1, 5) == 1:
			collectible_spawned = true
			var collectible_node = collectibles_to_spawn.pick_random()
			var collectible_spawn = collectible_node.instantiate()
			collectibles.add_child(collectible_spawn)
			collectible_spawn.global_position = child.global_position
			recently_summoned_collectibles.append(collectible_spawn)
			if find_player():
				player.connect_collectible(collectible_spawn)
	collectible_spawned = false

func disable(not_disable: street):
	not_disable.set_enter_potential(false)
	for child in roads.get_children():
		if child != not_disable:
			child.queue_free()
	for child in collectibles.get_children():
		if child not in recently_summoned_collectibles:
			child.queue_free()
	recently_summoned_collectibles.clear()
	if is_instance_valid(not_disable):
		enter(not_disable)

func find_player():
	for child in get_tree().get_first_node_in_group("Player").get_children():
		if child.name == "CharacterBody3D":
			player = child
			if player.can_climb:
				collectibles_to_spawn.erase(CLIMBING_GEAR)
			return true
	return false
