extends Node3D

@export var gadget_scene: PackedScene
@export var power_mgr: Node
@export var target_body: Node3D

@export var min_spawn_time_gap: float = 16.0
@export var max_spawn_time_gap: float = 20.0

@export var lane_width: float = 3.0
@export var total_lanes: int = 5

var _active_gadget: Node3D = null
var _distance_traveled_since_spawn: float = 0.0
var _target_distance_for_next_spawn: float = 0.0
var _timer: float = 0.0

func _ready() -> void:
	if power_mgr:
		_target_distance_for_next_spawn = _calculate_next_spawn_distance()

func _get_player_body() -> Node3D:
	if not target_body:
		return null
	var body_node = target_body.get("body")
	return body_node as Node3D if body_node else target_body

func _physics_process(delta: float) -> void:
	var body := _get_player_body()
	if body == null or power_mgr == null:
		return

	# Accumulate elapsed time for gadget interval
	_timer += delta

	# Monitor active gadget position; ignore if already queued for collection/deletion
	if is_instance_valid(_active_gadget):
		if _active_gadget.is_queued_for_deletion():
			return

		var relative_z: float = body.to_local(_active_gadget.global_position).z
		if relative_z > 5.0:
			var gadget_name_str: String = "Gadget"
			if "gadget_type" in _active_gadget and "TYPE_TO_ID" in _active_gadget:
				gadget_name_str = _active_gadget.TYPE_TO_ID.get(_active_gadget.gadget_type, "gadget").replace("_", " ").capitalize()
			
			print("[ITEM MISSED] ", gadget_name_str, " Pickup missed at position: ", _active_gadget.global_position, " | Time: ", "%.1f" % _timer, "s")
			_active_gadget.queue_free()
			_reset_cooldown_and_calculate_next()
		return

	if _target_distance_for_next_spawn <= 0.0:
		_target_distance_for_next_spawn = _calculate_next_spawn_distance()

	# Track travel distance while lane is clear using actual player body velocity
	if _active_gadget == null:
		var current_speed: float = 15.0
		if "current_speed" in body:
			current_speed = body.current_speed
		elif "current_speed" in power_mgr:
			current_speed = power_mgr.current_speed

		_distance_traveled_since_spawn += current_speed * delta

		if _distance_traveled_since_spawn >= _target_distance_for_next_spawn:
			_spawn_gadget()

func _spawn_gadget() -> void:
	if gadget_scene == null or power_mgr == null or target_body == null:
		return

	var body := _get_player_body()
	if not body:
		return

	var gadget_instance = gadget_scene.instantiate() as Node3D
	gadget_instance.set_meta("spawner", self)
	get_parent().add_child(gadget_instance)

	var spawn_distance_ahead: float = power_mgr.get_current_spawn_distance() if power_mgr.has_method("get_current_spawn_distance") else 45.0

	var random_lane: int = randi() % total_lanes
	@warning_ignore("integer_division")
	var lane_offset_index: int = random_lane - (total_lanes / 2)
	var x_offset: float = lane_offset_index * lane_width

	var spawn_pos: Vector3 = body.global_position
	spawn_pos += -body.global_transform.basis.z * spawn_distance_ahead
	spawn_pos.x = x_offset
	spawn_pos.y = 1.0

	gadget_instance.global_position = spawn_pos
	_active_gadget = gadget_instance

	# Terminal Debug Log
	var gadget_name_str: String = "Gadget"
	if "gadget_type" in gadget_instance and "TYPE_TO_ID" in gadget_instance:
		gadget_name_str = gadget_instance.TYPE_TO_ID.get(gadget_instance.gadget_type, "gadget").replace("_", " ").capitalize()
	
	print("[ITEM SPAWN] ", gadget_name_str, " Pickup spawned at position: ", gadget_instance.global_position, " (Lane: ", random_lane + 1, ")")

	gadget_instance.tree_exited.connect(_on_gadget_tree_exited)

func on_gadget_collected(gadget_node: Node3D, gadget_name_str: String) -> void:
	print("[ITEM PICKUP] Collected ", gadget_name_str, " Pickup at position: ", gadget_node.global_position, " | Time: ", "%.1f" % _timer, "s")
	_reset_cooldown_and_calculate_next()

func _on_gadget_tree_exited() -> void:
	_reset_cooldown_and_calculate_next()

func _reset_cooldown_and_calculate_next() -> void:
	if is_instance_valid(_active_gadget) and _active_gadget.tree_exited.is_connected(_on_gadget_tree_exited):
		_active_gadget.tree_exited.disconnect(_on_gadget_tree_exited)
	_active_gadget = null
	_timer = 0.0
	_distance_traveled_since_spawn = 0.0
	_target_distance_for_next_spawn = _calculate_next_spawn_distance()

func _calculate_next_spawn_distance() -> float:
	if power_mgr == null:
		return 0.0
	var current_target_speed: float = power_mgr.target_speed if "target_speed" in power_mgr else 15.0
	var time_gap: float = randf_range(min_spawn_time_gap, max_spawn_time_gap)
	return current_target_speed * time_gap
