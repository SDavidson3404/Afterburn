extends Node3D

const STREET_TEMPLATE1 = preload("res://Streets/street_template.tscn") # Road 1
const STREET_TEMPLATE2 = preload("res://Streets/street_template2.tscn") # Road 2
var roads_to_spawn: Array = [STREET_TEMPLATE1, STREET_TEMPLATE2] # Possible roads to spawn
@onready var starting_street: street = $Roads/StreetTemplate # The starting street
@onready var roads: Node3D = $Roads # The node all roads are under


func _ready() -> void:
	starting_street.entered.connect(enter, CONNECT_ONE_SHOT)

func enter(street_node: street):
	for child in street_node.get_links():
		var road = roads_to_spawn.pick_random()
		var road_spawn = road.instantiate()
		roads.add_child(road_spawn)
		road_spawn.global_position = child.global_position
		road_spawn.global_rotation.y = child.global_rotation.y
		road_spawn.entered.connect(disable, CONNECT_ONE_SHOT)
		road_spawn.set_enter_potential(true)

func disable(not_disable: street):
	not_disable.set_enter_potential(false)
	for child in roads.get_children():
		if child != not_disable:
			child.queue_free()
	await get_tree().process_frame
	if is_instance_valid(not_disable):
		enter(not_disable)
