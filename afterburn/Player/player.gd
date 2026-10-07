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
const TILT_UPPER_LIMIT: float = deg_to_rad(90)
const TILT_LOWER_LIMIT: float = deg_to_rad(-90)
const YAW_MAX_LIMIT: float = deg_to_rad(45)
const YAW_MIN_LIMIT: float = deg_to_rad(-45)
const MOUSE_SENS: float = 0.005
var current_speed: float = 15.0 # The speed of movement
var camera_rotation: Vector2 = Vector2.ZERO
var row: int = CENTER_ROW # The current row
var current_row_loc: Vector3 = Vector3.ZERO
var previous_loc: Vector3
var power_node: Node

## Runs when the scene is instanced or loaded in
func _ready() -> void:
	
	# Get the power node and apply its signals
	get_power_node()
	connect_signals()
	
	# set the invincibility indicator
	invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.325)
	
	# Set the previous position initially
	previous_loc = body.global_position
	
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If there aren't enough rows, push an error
	if rows.get_child_count() <= MAX_ROW:
		push_error("Rows must contain at least 5 row nodes.")
		return
	
	# Set current row location
	current_row_loc = rows.get_child(row).global_position

## Runs on input of any kind
func _input(event: InputEvent) -> void:
	
	# If the player clicks, set the mouse to capture
	if event.is_action_pressed("Click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If A is pressed, move left
	if event.is_action_pressed("A"): move_left()
	
	# If D is pressed, move right
	if event.is_action_pressed("D"): move_right()
	
	# If ESC is pressed, set mouse to visible
	if event.is_action_pressed("ESC"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# If mouse is moved and the mouse is captured
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		
		# Rotate the camera according to the mouse sensitivity
		camera_rotation.y -= event.relative.x * MOUSE_SENS
		camera_rotation.x -= event.relative.y * MOUSE_SENS
		
		# set the rotation to be in range of the minimum and maximum of each direction
		camera_rotation.x = clampf(camera_rotation.x, TILT_LOWER_LIMIT, TILT_UPPER_LIMIT)
		camera_rotation.y = clampf(camera_rotation.y, YAW_MIN_LIMIT, YAW_MAX_LIMIT)
		
		# Set the camera rotation to the new rotation
		camera.rotation.y = camera_rotation.y
		camera.rotation.x = camera_rotation.x

## Moves the active row to the left one
func move_left() -> void:
	
	# If row is above the minimum, lower row
	if row > MIN_ROW:
		row -= 1
		
		# Update the target row location
		update_target_row()

## Moves the active row to the right one
func move_right() -> void:
	
	# If row is less than the max, increase row
	if row < MAX_ROW:
		row += 1
		
		# Update the target row location
		update_target_row()

## Function to update the target row
## Set current row location to the location of the current row1
func update_target_row() -> void: current_row_loc = rows.get_child(row).global_position

## Runs 60 times a second
func _physics_process(delta: float) -> void:
	
	# Set the power meter to reflect the current power
	power_meter.value = power_node.current_power
	
	# Update the row squares
	update_row_square()
	
	# Apply forward movement and reset sideways movement
	body.velocity.x = 0.0
	body.velocity.z = -power_node.current_speed
	
	# move position of player to the current row and bring rows with body
	body.global_position.x = move_toward(body.global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
	rows.global_position.z = body.global_position.z
	
	# If space is pressed and player is on floor, jump
	if Input.is_action_just_pressed("Space") and body.is_on_floor():
		body.velocity.y += JUMP_VELOCITY
	
	# If player is not on floor, apply gravity
	if not body.is_on_floor():
		body.velocity += body.get_gravity() * delta
	
	# Move the body according to the set velocities
	body.move_and_slide()

## Gets the node associated with the power script
func get_power_node():
	
	# For loop for the children nodes of the root node in the scene
	for child in get_tree().current_scene.get_children():
		
		# If node's name is "Power", set the power node variable to the node
		if child.name == "Power": power_node = child

## Updates the square representing the row you are in
func update_row_square():
	
	# For loop for children nodes of the row squares parent node
	for child in row_squares.get_children():
		
		# If the name matches the row you are in, then make the square white
		if child.name == ("Row" + str(row + 1)):
			child.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		# Otherwise, make it black
		else: child.modulate = Color(0.0, 0.0, 0.0, 1.0)

## Connects the necessary signals to their respective methods
func connect_signals():
	power_node.invincibility_changed.connect(_on_power_invincibility_changed)
	power_node.game_over_triggered.connect(lose)

## Changes the color of the Invincibility UI
func _on_power_invincibility_changed(is_invincible: bool) -> void:
	
	# if player is invincible, make it yellow, showing it is active 
	if is_invincible: invincible_indicator.modulate = Color(0.843, 0.733, 0.0, 0.573)
	
	# Otherwise, make it translucent black
	else: invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.325)

## Runs on losing the game
## As of right now only prints a message that you lost
func lose(): print("YOU LOST")
