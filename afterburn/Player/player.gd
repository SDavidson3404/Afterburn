extends CharacterBody3D # Inherits all code from the CharacterBody3D Class
class_name Player # The name of this class

const MAX_ROW: int = 5 # The maximum row count
const ROW_WIDTH: float = 2.0 # The width of each row
const JUMP_VELOCITY: float = 5.0 # The velocity of the jump
const STRAFE_SPEED: float = 15.0 # The speed of changing between rows
var SPEED: float = 15.0 # The speed of the character
var row: int = 3 # The current row

# Runs on input detected
func _input(event: InputEvent) -> void:
	# If A is pressed, decrease the row by 1
	if event.is_action_pressed("A") and row > 1: 
		row -= 1
	# If D is pressed, increase the row by 1
	if event.is_action_pressed("D") and row < MAX_ROW: 
		row += 1

# Runs 60 times a second
func _physics_process(delta: float) -> void:
	# If player is not on the floor, apply gravity
	if not is_on_floor(): velocity += get_gravity() * delta
	# If Space is pressed and player is on the floor:
	if Input.is_action_just_pressed("Space") and is_on_floor():
		# Set velocity for jump
		velocity.y = JUMP_VELOCITY
	# Apply the movement to the player
	velocity.z = -SPEED
	# Move the player dynamically towards the location of the current row
	position.x = move_toward(position.x, (row * 3), STRAFE_SPEED * delta)
	# Apply velocity
	move_and_slide()
