extends CharacterBody3D
class_name Player

@onready var camera: Camera3D = $Camera3D # The camera
@onready var rows: Node3D = $"../Rows" # The rows parent
@onready var score_label: Label = $UI/ScoreLabel
@onready var row_1: MeshInstance2D = $"../Rows/Row 1/Row1"
@onready var row_2: MeshInstance2D = $"../Rows/Row 2/Row2"
@onready var row_3: MeshInstance2D = $"../Rows/Row 3/Row3"
@onready var row_4: MeshInstance2D = $"../Rows/Row 4/Row4"
@onready var row_5: MeshInstance2D = $"../Rows/Row 5/Row5"
@onready var climbing_gear: MeshInstance2D = $UI/MeshInstance2D
var row_squares: Array = []
const MIN_ROW: int = 0 # The minimum row
const MAX_ROW: int = 4 # The maximum row
const CENTER_ROW: int = 2 # The center row
const JUMP_VELOCITY: float = 5.0 # The velocity of the jump
const STRAFE_SPEED: float = 15.0  # The speed of strafing
const TURN_SPEED: float = 10.0 # The speed of turning
var speed: float = 15.0 # The speed of movement
const TILT_UPPER_LIMIT: float = deg_to_rad(90)
const TILT_LOWER_LIMIT: float = deg_to_rad(-90)
const YAW_MAX_LIMIT: float = deg_to_rad(45)
const YAW_MIN_LIMIT: float = deg_to_rad(-45)
const MOUSE_SENS: float = 0.005
var camera_rotation: Vector2 = Vector2.ZERO
var row: int = CENTER_ROW # The current row
var facing: String = "Forward"
var current_row_loc: Vector3= Vector3.ZERO
var current_angle: float = 0.0
var score: int = 0
var can_climb: bool = false
var climbing: bool = false
var previous_loc: Vector3
var lost: bool = false

# Runs on startup
func _ready() -> void:
	previous_loc = global_position
	row_squares.append_array([row_1, row_2, row_3, row_4, row_5])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# If there aren't enough rows, push an error
	if rows.get_child_count() <= MAX_ROW:
		push_error("Rows must contain at least 5 row nodes.")
		return
	# Set current row location
	current_row_loc = rows.get_child(row).global_position
	# Set the rotation to the current angle
	global_rotation.y = current_angle

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
	# Otherwise
	else:
		# Turn left
		turn_left()

# Move right method
func move_right() -> void:
	# If row is less than max row
	if row < MAX_ROW:
		# Increase row by 1
		row += 1
		# Update the target row
		update_target_row()
	# Otherwise
	else:
		# Turn right
		turn_right()

# Function to update the target row
func update_target_row() -> void: current_row_loc = rows.get_child(row).global_position

# Method to turn left
func turn_left() -> void:
	# Match the direction the player is facing
	match facing:
		"Forward":
			# Set turning to left and set the current angle
			facing = "Left"
			current_angle = PI / 2.0
		"Left":
			# Set facing to Back and set the current angle
			facing = "Back"
			# Set current angle
			current_angle = PI
		"Back":
			# Set facing to right and set the current angle
			facing = "Right"
			current_angle = -PI / 2.0
		"Right":
			# Set facing to forward and set the current angle
			facing = "Forward"
			current_angle = 0.0
	# Set the row to the center row
	row = CENTER_ROW
	# Update the target
	update_target_row()

# Turn right method
func turn_right() -> void:
	# Match the direction the player is currently facing
	match facing:
		"Forward":
			# Set facing to right and set the current angle
			facing = "Right"
			current_angle = -PI / 2.0
		"Right":
			# Set facing to back and set the current angle
			facing = "Back"
			current_angle = PI
		"Back":
			# Set facing to left and set the current angle
			facing = "Left"
			current_angle = PI / 2.0
		"Left":
			# Set facing to forward and set the current angle
			facing = "Forward"
			current_angle = 0.0
	# Set the row to center row and update target
	row = CENTER_ROW
	update_target_row()

# Runs 60 times a second
func _physics_process(delta: float) -> void:
	if can_climb:
		climbing_gear.modulate = Color(1.0, 1.0, 1.0, 0.502)
	update_row_square()
	score_label.text = ("SCORE: " + str(score))
	# If not on floor, apply gravity
	if not is_on_floor() and not climbing:
		velocity += get_gravity() * delta
	# If you press space and are on floor, apply jump velocity
	if Input.is_action_just_pressed("Space") and is_on_floor() and not climbing:
		velocity.y = JUMP_VELOCITY
	# Smoothly rotate the player
	if not climbing:
		global_rotation.y = lerp_angle(global_rotation.y, current_angle, TURN_SPEED * delta)
		# Smoothly rotate the rows
		rows.global_rotation.y = lerp_angle(rows.global_rotation.y, current_angle, TURN_SPEED * delta)
	else:
		match facing:
			"UpX":
				global_rotation.z = 90
			"Up-X":
				global_rotation.z = -90
			"UpZ":
				global_rotation.x = -90
			"Up-Z":
				global_rotation.x = 90
	# Match the facing direction
	match facing:
		"Forward":
			# Apply forward movement
			velocity.x = 0.0
			velocity.z = -speed
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Back":
			# Apply backwards movement
			velocity.x = 0.0
			velocity.z = speed
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Left":
			# Apply left movement
			velocity.x = -speed
			velocity.z = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
		"Right":
			# Apply right movement
			velocity.x = speed
			velocity.z = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
		"UpX":
			# Apply right movement
			velocity.y = speed
			velocity.z = 0.0
			velocity.x = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.y = global_position.y
		"UpZ":
			# Apply right movement
			velocity.y = speed
			velocity.z = 0.0
			velocity.x = 0.0
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.y = global_position.y
		"Up-X":
			# Apply right movement
			velocity.y = speed
			velocity.z = 0.0
			velocity.x = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.y = global_position.y
		"Up-Z":
			# Apply right movement
			velocity.y = speed
			velocity.z = 0.0
			velocity.x = 0.0
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.y = global_position.y
	# Apply the movement
	move_and_slide()
	if global_position == previous_loc and not lost:
		lose()
	previous_loc = global_position

func connect_collectible(collectible_node: collectible):
	collectible_node.pick_up.connect(collect_collectible)

func collect_collectible(collectible_name: String):
	match collectible_name:
		"Crystal":
			score += 1

func BOOST():
	speed += 10
	await get_tree().create_timer(5).timeout
	speed -= 10

func update_row_square():
	if not row_squares.is_empty():
		for child in row_squares:
			if child.name == ("Row" + str(row + 1)):
				child.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				child.modulate = Color(0.0, 0.0, 0.0, 1.0)

func check_climb_dir():
	var space = get_world_3d().direct_space_state
	var query1 = PhysicsRayQueryParameters3D.create(global_position, Vector3(5, 0, 0))
	var query2 = PhysicsRayQueryParameters3D.create(global_position, Vector3(-5, 0, 0))
	var query3 = PhysicsRayQueryParameters3D.create(global_position, Vector3(0, 0, 9))
	var query4 = PhysicsRayQueryParameters3D.create(global_position, Vector3(0, 0, -9))
	if space.intersect_ray(query1):
		return "UpX"
	if space.intersect_ray(query2):
		return "Up-X"
	if space.intersect_ray(query3):
		return "UpZ"
	if space.intersect_ray(query4):
		return "Up-Z"

func begin_climb():
	if can_climb:
		facing = check_climb_dir()

func lose():
	lost = true
	print("YOU LOST")
