extends Node3D
class_name Player

@onready var camera: Camera3D = $Body/Camera3D
@onready var rows: Node3D = $Rows
@onready var score_label: Label = $Body/UI/ScoreLabel
@onready var row_squares: Node2D = $Body/UI/Row_Squares
@onready var body: CharacterBody3D = $Body
@onready var invincible_indicator: MeshInstance2D = $"Body/UI/Invincible indicator"
@onready var power_meter: ProgressBar = $"Body/UI/Power Meter"
const MIN_ROW: int = 0 # The minimum row
const MAX_ROW: int = 4 # The maximum row
const CENTER_ROW: int = 2 # The center row
const JUMP_VELOCITY: float = 5.0 # The velocity of the jump
const STRAFE_SPEED: float = 15.0  # The speed of strafing
const TURN_SPEED: float = 10.0 # The speed of turning
const GRAVITY: float = 10.0
const TILT_UPPER_LIMIT: float = deg_to_rad(90)
const TILT_LOWER_LIMIT: float = deg_to_rad(-90)
const YAW_MAX_LIMIT: float = deg_to_rad(45)
const YAW_MIN_LIMIT: float = deg_to_rad(-45)
const MOUSE_SENS: float = 0.005
var current_speed: float = 15.0 # The speed of movement
var camera_rotation: Vector2 = Vector2.ZERO
var row: int = CENTER_ROW # The current row
var facing: String = "Forward"
var current_row_loc: Vector3= Vector3.ZERO
var score: int = 0
var previous_loc: Vector3
var lost: bool = false
var power_node: Node

# Runs on startup
func _ready() -> void:
	get_power_node()
	connect_signals()
	invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.557)
	previous_loc = body.global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# If there aren't enough rows, push an error
	if rows.get_child_count() <= MAX_ROW:
		push_error("Rows must contain at least 5 row nodes.")
		return
	# Set current row location
	current_row_loc = rows.get_child(row).global_position

# Runs on input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# If A is pressed, move left
	if event.is_action_pressed("A"): move_left()
	# Otherwise, if D is pressed, move right
	if event.is_action_pressed("D"): move_right()
	if event.is_action_pressed("ESC"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.y -= event.relative.x * MOUSE_SENS
		camera_rotation.x -= event.relative.y * MOUSE_SENS
		camera_rotation.x = clampf(camera_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
		camera_rotation.y = clampf(camera_rotation.y, YAW_MIN_LIMIT, YAW_MAX_LIMIT)
		camera.rotation.y = camera_rotation.y
		camera.rotation.x = camera_rotation.x

# Move left method
func move_left() -> void:
	# If row is above the minimum
	if row > MIN_ROW:
		# Lower the row
		row -= 1
		# Update the target row
		update_target_row()

# Move right method
func move_right() -> void:
	# If row is less than max row
	if row < MAX_ROW:
		# Increase row by 1
		row += 1
		# Update the target row
		update_target_row()

# Function to update the target row
func update_target_row() -> void: current_row_loc = rows.get_child(row).global_position

# Runs 60 times a second
func _physics_process(delta: float) -> void:
	power_meter.value = power_node.current_power
	update_row_square()
	score_label.text = ("SCORE: " + str(score))
	# Apply forward movement
	body.velocity.x = 0.0
	body.velocity.z = -power_node.current_speed
	body.global_position.x = move_toward(body.global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
	rows.global_position.z = body.global_position.z
	if Input.is_action_just_pressed("Space") and body.is_on_floor():
		body.velocity.y += JUMP_VELOCITY
	# Apply the movement
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta
	body.move_and_slide()
	previous_loc = global_position

func connect_collectible(collectible_node: collectible):
	collectible_node.pick_up.connect(collect_collectible)

func collect_collectible(collectible_name: String):
	match collectible_name:
		"Crystal":
			score += 1

func get_power_node():
	for child in get_tree().current_scene.get_children():
		if child.name == "Power":
			power_node = child

func update_row_square():
	for child in row_squares.get_children():
		if child.name == ("Row" + str(row + 1)):
			child.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			child.modulate = Color(0.0, 0.0, 0.0, 1.0)

func connect_signals():
	power_node.invincibility_changed.connect(_on_power_invincibility_changed)
	power_node.game_over_triggered.connect(lose)

func _on_power_invincibility_changed(is_invincible: bool) -> void:
	if is_invincible:
		invincible_indicator.modulate = Color(0.843, 0.733, 0.0, 0.573)
	else:
		invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.741)

func lose():
	print("YOU LOST")
