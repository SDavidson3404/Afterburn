extends CharacterBody3D
class_name Player

@onready var camera: Camera3D = $Camera3D # The camera
@onready var rows: Node3D = $"../Rows" # The rows parent
const MIN_ROW: int = 0 # The minimum row
const MAX_ROW: int = 4 # The maximum row
const CENTER_ROW: int = 2 # The center row
const JUMP_VELOCITY: float = 5.0 # The velocity of the jump
const STRAFE_SPEED: float = 15.0  # The speed of strafing
const TURN_SPEED: float = 10.0 # The speed of turning
const SPEED: float = 15.0 # The speed of movement
var row: int = CENTER_ROW # The current row
var facing: String = "Forward"
var current_row_loc: Vector3= Vector3.ZERO
var current_angle: float = 0.0

# Runs on startup
func _ready() -> void:
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
	# If A is pressed, move left
	if event.is_action_pressed("A"): move_left()
	# Otherwise, if D is pressed, move right
	elif event.is_action_pressed("D"): move_right()

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
	# If not on floor, apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	# If you press space and are on floor, apply jump velocity
	if Input.is_action_just_pressed("Space") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	# Smoothly rotate the player
	global_rotation.y = lerp_angle(global_rotation.y, current_angle, TURN_SPEED * delta)
	# Smoothly rotate the rows
	rows.global_rotation.y = lerp_angle(rows.global_rotation.y, current_angle, TURN_SPEED * delta)
	# Match the facing direction
	match facing:
		"Forward":
			# Apply forward movement
			velocity.x = 0.0
			velocity.z = -SPEED
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Back":
			# Apply backwards movement
			velocity.x = 0.0
			velocity.z = SPEED
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Left":
			# Apply left movement
			velocity.x = -SPEED
			velocity.z = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
		"Right":
			# Apply right movement
			velocity.x = SPEED
			velocity.z = 0.0
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
	# Apply the movement
	move_and_slide()
