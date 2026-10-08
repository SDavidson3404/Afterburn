extends Node3D
class_name Player

signal sliding # A signal for when sliding
signal dashing # A signal for when dashing

# Nodes of note
@onready var camera: Camera3D = $Body/Camera3D # The camera
@onready var score_label: Label = $Body/UI/ScoreLabel # The label which shows the score
@onready var row_squares: Node2D = $Body/UI/Row_Squares # The parent node of the row indicators
@onready var body: CharacterBody3D = $Body # The body of the player
@onready var invincible_indicator: MeshInstance2D = $"Body/UI/Invincible indicator" # An inidicator for when invincible
@onready var power_meter: ProgressBar = $"Body/UI/Power Meter" # The meter that shows the power
@onready var speed_label: Label = $Body/UI/SpeedLabel # The label that shows the speed
@onready var animation_player: AnimationPlayer = $Body/AnimationPlayer # The animationplayer
@export var power_node: Node # The node that controls the power of the skateboard
@export var Wall_Detection: Node3D # The script that detects when walls are hit

# Constants
const MIN_ROW_INDEX: int = -2 # The minimum row
const MAX_ROW_INDEX: int = 2 # The maximum row
const JUMP_VELOCITY: float = 7.0 # The velocity of the jump
const GRAVITY: float = 12.0 # The strength of gravity
const STRAFE_SPEED: float = 15.0  # The speed of strafing
const DASH_DRAIN_RATE: float = 10.0 # The rate at which the dash speed drains back to normal
const dash_multiplier: float = 2.0 # The multiplier to the speed when dashing

# Regular variables
var current_speed: float = 15.0 # The speed of movement
var row_index: int = 0 # The current row
var current_row_offset: float = 0.0 # The offset of the current row
var score: int = 0 # The current score
var is_sliding: bool = false # A bool to show if you are currently sliding
var is_dashing: bool = false # A bool to show if you are starting dashing
var starting_run: bool = true # A bool to show if the run is starting

## Runs when the scene is instanced or loaded in
func _ready() -> void:
	
	# Apply the power node's signals signals
	connect_signals()
	
	# set the invincibility indicator
	invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.325)
	
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Runs on input of any kind
func _input(event: InputEvent) -> void:
	
	# If the player clicks, set the mouse to capture
	if event.is_action_pressed("Click"): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If A is pressed, move left
	if event.is_action_pressed("A"): move_left()
	
	# If D is pressed, move right
	if event.is_action_pressed("D"): move_right()
	
	# If Shift is pressed and the player is not currently sliding and the player is on the floor, begin slide
	if event.is_action_pressed("S") and not is_sliding and body.is_on_floor(): slide()
	
	# If W is pressed and the current power is greater than or equal to the cost
	if event.is_action_pressed("W"):
		if power_node.current_power >= power_node.dash_cost:
			
			# Set dashing to true and emit the dashing signal
			is_dashing = true
			dashing.emit()
	
	# If ESC is pressed, set mouse to visible
	if event.is_action_pressed("ESC"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Moves the active row to the left one
func move_left() -> void:
	
	# If row is above the minimum, lower row
	if row_index > MIN_ROW_INDEX:
		row_index -= 1
		
		# Update the target row location
		update_target_row()

## Moves the active row to the right one
func move_right() -> void:
	
	# If row is less than the max, increase row
	if row_index < MAX_ROW_INDEX:
		row_index += 1
		
		# Update the target row location
		update_target_row()

## Function to update the target row
## Set current row location to the location of the current row1
func update_target_row() -> void: current_row_offset = int(row_index) * 3

## Runs 60 times a second
func _physics_process(delta: float) -> void:
	# Set the power meter to reflect the current power
	power_meter.value = power_node.current_power
	
	# Update text to reflect current speed and score
	speed_label.text = ("SPEED(MPS): " + str(int(current_speed)))
	score_label.text = ("SCORE: " + str(score))
	
	# Update the row squares
	update_row_square()
	
	# Set sideways movement to 0
	body.velocity.x = 0.0
	
	# If you are dashing, set the velocity to current speed of the power, 
	# times the dash multiplier and set is dashing to false
	if is_dashing:
		body.velocity.z = -power_node.current_speed * dash_multiplier
		is_dashing = false
	
	# Otherwise if you are starting the run, set the initial velocity and note that it was set up
	elif starting_run:
		body.velocity.z = -power_node.current_speed
		starting_run = false
	
	# If neither are true, change the speed towards the current speed in power by 10 MPS/s
	else:
		body.velocity.z = move_toward(body.velocity.z, -power_node.current_speed, DASH_DRAIN_RATE * delta)
	
	# Set the current speed to the forward velocity of the body
	current_speed = -body.velocity.z
	
	# move position of player to the current row and bring rows with body
	body.global_position.x = move_toward(body.global_position.x, current_row_offset, STRAFE_SPEED * delta)
	
	# Runs if space is pressed and you are on the floor
	if Input.is_action_just_pressed("Space") and body.is_on_floor():
		
		# If you are sliding, cancel it
		if is_sliding:
			animation_player.stop()
			is_sliding = false
		
		# Apply jump velocity
		body.velocity.y += JUMP_VELOCITY
	
	# If player is not on floor, apply gravity
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta
	
	# Move the body according to the set velocities
	body.move_and_slide()

## Updates the square representing the row you are in
func update_row_square():
	
	# For loop for children nodes of the row squares parent node
	for child in row_squares.get_children():
		
		# Get the number of the row by increasing the index by 3
		var row_num = row_index + 3
		
		# If the name matches the row you are in, then make the square white
		if child.name == ("Row" + str(row_num)):
			child.modulate = Color(1.0, 1.0, 1.0, 1.0)
		
		# Otherwise, make it black
		else: child.modulate = Color(0.0, 0.0, 0.0, 1.0)

## Connects the necessary signals to their respective methods
func connect_signals():
	power_node.invincibility_changed.connect(_on_power_invincibility_changed)
	power_node.game_over_triggered.connect(lose)
	Wall_Detection.Wall_Hit.connect(hit)

## Changes the color of the Invincibility UI
func _on_power_invincibility_changed(is_invincible: bool) -> void:
	
	# if player is invincible, make it yellow, showing it is active 
	if is_invincible: invincible_indicator.modulate = Color(0.843, 0.733, 0.0, 0.573)
	
	# Otherwise, make it translucent black
	else: invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.325)

## Runs on losing the game
## As of right now only prints a message that the player lost
func lose(): print("YOU LOST")

## Begins the sliding state
func slide():
	
	# Emit the sliding signal and set that the player is sliding
	sliding.emit()
	is_sliding = true
	
	# Play the animation and wait for it to finish
	animation_player.play("Slide")
	await animation_player.animation_finished
	
	# Set sliding to false
	is_sliding = false

## Runs the hit wall animation upon being called
func hit(): animation_player.play("Hit_Wall")
