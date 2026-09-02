extends CharacterBody3D # Inherits all code from the CharacterBody3D Class
class_name Player # The name of this class

@onready var camera: Camera3D = $Camera3D # The camera
@onready var rows: Node3D = $"../Rows" # The node that houses all rows
const MAX_ROW: int = 4 # The maximum row count
const ROW_WIDTH: float = 2.0 # The width of each row
const JUMP_VELOCITY: float = 5.0 # The velocity of the jump
const STRAFE_SPEED: float = 15.0 # The speed of changing between rows
const TURN_SPEED: float = 10.0 # The speed of turning
var SPEED: float = 15.0 # The speed of the character
var row: int = 2 # The current row
var can_turn: bool = false # A bool for if the player can turn
var facing: String = "Forward"  # The direction the player is facing
var current_row_loc: Vector3 # The location of the current row
var current_angle: float = 0.0 # The angle the character currently is at

# Runs on ready, sets current row to row 3
func _ready() -> void: current_row_loc = rows.get_child(2).global_position

# Runs on input detected
func _input(event: InputEvent) -> void:
	# If A is pressed:
	if event.is_action_pressed("A"):
		# If row is greater than 0
		if row > 0:
			# Lower row by 1
			row -= 1
			# Set current row according
			current_row_loc = rows.get_child(row).global_position
		# If row IS less than 0
		else:
			# Turn left
			turn_left()
	# If D is pressed
	if event.is_action_pressed("D"):
		# If row is less than the max row
		if row < MAX_ROW:
			# Increase row by 1
			row += 1
			# Set new row
			current_row_loc = rows.get_child(row).global_position
		# If row IS greater than the max row
		else:
			# Turn right
			turn_right()

# Turn left function
func turn_left():
	# Match the direction
	match facing:
		"Forward":
			# Set facing to left
			facing = "Left"
			# Set the angle
			current_angle = PI/2.0
		"Back":
			# Set facing to right
			facing = "Right"
			# Set the angle
			current_angle = -PI/2.0
		"Left":
			# Set facing to back
			facing = "Back"
			# Set the angle
			current_angle = PI
		"Right":
			# Set facing to forward
			facing = "Forward"
			# Set the angle
			current_angle = 0
	# Set the row to the third row
	row = 2

# Turn right function
func turn_right():
	# Match the facing direction
	match facing:
		"Forward":
			# Set facing to right
			facing = "Right"
			# Set the angle
			current_angle = -PI/2.0
		"Back":
			# Set the facing to left
			facing = "Left"
			# Set the current angle
			current_angle = PI/2.0
		"Left":
			# Set facing to forward
			facing = "Forward"
			# Set current angle
			current_angle = 0
		"Right":
			# Set facing to back
			facing = "Back"
			# Set the angle
			current_angle = -PI
	# Set the row to the third row
	row = 2

# Runs 60 times a second
func _physics_process(delta: float) -> void:
	# Set the rotation to the angle given under current angle
	global_rotation.y = lerp_angle(global_rotation.y, current_angle, TURN_SPEED * delta)
	# If player is not on the floor, apply gravity
	if not is_on_floor(): velocity += get_gravity() * delta
	# If Space is pressed and player is on the floor:
	if Input.is_action_just_pressed("Space") and is_on_floor():
		# Set velocity for jump
		velocity.y = JUMP_VELOCITY
	# Set the row rotation
	rows.global_rotation = Vector3(0, current_angle, 0)
	# Match the facing direction
	match facing:
		"Forward":
			# Move the player and rows
			velocity.z = -SPEED
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Back":
			# Move the player and rows
			velocity.x = SPEED
			global_position.x = move_toward(global_position.x, current_row_loc.x, STRAFE_SPEED * delta)
			rows.global_position.z = global_position.z
		"Left":
			# Move the player and rows
			velocity.x = -SPEED
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
		"Right":
			# Move the player and rows
			velocity.x = SPEED
			global_position.z = move_toward(global_position.z, current_row_loc.z, STRAFE_SPEED * delta)
			rows.global_position.x = global_position.x
	# Apply velocity
	move_and_slide()
