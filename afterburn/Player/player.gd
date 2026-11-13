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
@onready var animation_player: AnimationPlayer = $Body/AnimationPlayer # The animation player
@onready var model: Node3D = get_node_or_null("Body/Main Character Placeholder")
@onready var afterburner: GPUParticles3D = $Body/FireParticles/GPUParticles3D
@export var power_node: Node # The node that controls the power of the skateboard
@export var Wall_Detection: Node3D # The script that detects when walls are hit
@export var game_over_screen: CanvasLayer

# Constants
const MIN_ROW_INDEX: int = -2 # The minimum row
const MAX_ROW_INDEX: int = 2 # The maximum row
const JUMP_VELOCITY: float = 7.0 # The velocity of the jump
const GRAVITY: float = 12.0 # The strength of gravity
const STRAFE_SPEED: float = 15.0  # The speed of strafing
const dash_multiplier: float = 2.0 # The multiplier to the speed when dashing

# Regular variables
var current_speed: float = 15.0 # The speed of movement
var row_index: int = 0 # The current row
var current_row_offset: float = 0.0 # The offset of the current row
var score: int = 0 # The current score
var is_sliding: bool = false # A bool to show if you are currently sliding
var is_dashing: bool = false # A bool to show if you are starting dashing
var starting_run: bool = true # A bool to show if the run is starting

# Dodge maneuver trackers
var is_jumping_maneuver: bool = false
var current_jump_dodge_count: int = 0
var current_slide_dodge_count: int = 0

# Dynamic stat multipliers overridden by gadgets (e.g., Hoverboard)
var jump_velocity_multiplier: float = 1.0
var gravity_multiplier: float = 1.0
var dash_decel_multiplier: float = 1.0
var dash_decel_rate: float = 0.0

## Runs when the scene is instanced or loaded in
func _ready() -> void:
	
	# Apply the power node's signals signals
	connect_signals()
	
	# set the invincibility indicator
	invincible_indicator.modulate = Color(0.0, 0.0, 0.0, 0.325)
	
	# Programmatically instantiate and attach GadgetUI node to player HUD
	var gadget_ui_script = load("res://UI/gadget_ui.gd")
	if gadget_ui_script and $Body/UI:
		var gadget_ui = Node2D.new()
		gadget_ui.set_script(gadget_ui_script)
		gadget_ui.name = "GadgetUI"
		gadget_ui.player = self
		gadget_ui.power_node = power_node
		$Body/UI.add_child(gadget_ui)
	
	# Capture the mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Runs on input of any kind
func _input(event: InputEvent) -> void:
	
	# If the player clicks, set the mouse to capture
	if event.is_action_pressed("Click") and power_node and power_node.is_run_active: 
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# If A is pressed, move left
	if event.is_action_pressed("A"): move_left()
	
	# If D is pressed, move right
	if event.is_action_pressed("D"): move_right()
	
	# If S is pressed and the player is not currently sliding and the player is on the floor, begin slide
	if event.is_action_pressed("S") and not is_sliding and body.is_on_floor(): 
		slide()
	
	# If W is pressed and the current power is greater than or equal to the cost
	if event.is_action_pressed("W") and power_node:
		if power_node.current_power >= power_node.dash_cost:
			# Set dashing to true and emit the dashing signal
			is_dashing = true
			dashing.emit()
	
	if event.is_action_pressed("Gadget"):
		if power_node and power_node.has_method("try_use_loadout_gadget"):
			power_node.try_use_loadout_gadget()
	
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
	if not power_node or not power_node.is_run_active:
		return
	
	var material: StandardMaterial3D = afterburner.material_override
	if power_node.current_speed == power_node.target_speed:
		material.emission = Color(1.0, 0.0, 0.0, 1.0)
		material.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	else:
		material.emission = Color(0.0, 1.0, 1.0, 1.0)
		material.albedo_color = Color(0.0, 1.0, 1.0, 1.0)
	var afterburner_speed: float = remap(current_speed, 0.0, power_node.max_speed, .5, 5.0)
	@warning_ignore("narrowing_conversion")
	var afterburner_amount: int = remap(current_speed, 0.0, power_node.max_speed, 1, 60)
	afterburner.speed_scale = afterburner_speed
	afterburner.amount = afterburner_amount
	
	if model and model.has_method("play_anim") and not animation_player.is_playing():
		model.play_anim("Idle")
	# Set the power meter to reflect the current power
	if power_meter:
		power_meter.value = min(power_node.current_power, 100.0)
	
	# Update text to reflect current speed and score
	speed_label.text = ("SPEED(MPS): " + "%.1f" % current_speed)
	score_label.text = ("SCORE: " + DatabaseManager.format_number(DatabaseManager.display_score()))
	
	# Update the row squares
	update_row_square()
	
	# Set sideways movement to 0
	body.velocity.x = 0.0
	
	# If you are dashing, set the velocity to current speed of the power, times the dash multiplier and set is dashing to false
	if is_dashing:
		body.velocity.z = -power_node.current_speed * dash_multiplier
		is_dashing = false
		dash_decel_rate = 0.0
	
	# Otherwise if you are starting the run, set the initial velocity and note that it was set up
	elif starting_run:
		body.velocity.z = -power_node.current_speed
		starting_run = false
	
	# If neither are true, change the speed towards the current speed in power
	else:
		var target_vel_z: float = -power_node.current_speed
		
		# If coasting, let power.gd's coasting deceleration dictate player speed directly
		if power_node and power_node.is_coasting:
			dash_decel_rate = 0.0
			body.velocity.z = move_toward(body.velocity.z, target_vel_z, 50.0 * delta)
		elif body.velocity.z < target_vel_z:
			# Calculate required deceleration rate to reach target speed in exactly 1.0 second
			if dash_decel_rate <= 0.0:
				var excess_speed: float = abs(body.velocity.z - target_vel_z)
				var decel_duration: float = 1.0 / maxf(dash_decel_multiplier, 0.01)
				dash_decel_rate = excess_speed / maxf(decel_duration, 0.01)
			
			body.velocity.z = move_toward(body.velocity.z, target_vel_z, dash_decel_rate * delta)
		else:
			dash_decel_rate = 0.0
			body.velocity.z = move_toward(body.velocity.z, target_vel_z, 50.0 * delta)
	
	# Set the current speed to the forward velocity of the body
	current_speed = -body.velocity.z
	
	# move position of player to the current row and bring rows with body
	body.global_position.x = move_toward(body.global_position.x, current_row_offset, STRAFE_SPEED * delta)
	
	# Runs if space is pressed and you are on the floor
	if Input.is_action_just_pressed("Space") and body.is_on_floor():
		
		# If you are sliding, cancel it
		if is_sliding:
			if animation_player.current_animation == "Slide":
				animation_player.stop()
				
			is_sliding = false
			current_slide_dodge_count = 0
		
		# Apply jump velocity and start jump maneuver
		body.velocity.y += (JUMP_VELOCITY * jump_velocity_multiplier)
		is_jumping_maneuver = true
		current_jump_dodge_count = 0

		# Deduct 10% total hoverboard duration on jump
		var hover_inst = get_node_or_null("HoverboardInstance")
		if hover_inst and hover_inst.has_method("on_jump"):
			hover_inst.on_jump()
	
	# Reset jump maneuver state upon touching floor
	if body.is_on_floor():
		if is_jumping_maneuver:
			is_jumping_maneuver = false
			current_jump_dodge_count = 0
	else:
		# If player is not on floor, apply gravity
		body.velocity.y -= (GRAVITY * gravity_multiplier) * delta
	
	# Move the body according to the set velocities
	body.move_and_slide()

## Registers a dodge maneuver and awards compounding points (100, 200, 300...) per obstacle in current jump or slide.
func register_dodge(dodge_type: String) -> void:
	var points: int = 0
	if dodge_type == "jump":
		current_jump_dodge_count += 1
		points = current_jump_dodge_count * 100
	elif dodge_type == "slide":
		current_slide_dodge_count += 1
		points = current_slide_dodge_count * 100

	if points > 0 and get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_dodge(dodge_type, points)

## Resets maneuver dodge multipliers if player hits an obstacle.
func cancel_dodge_maneuver() -> void:
	current_jump_dodge_count = 0
	current_slide_dodge_count = 0

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
	
## Time untill respawn
var time_left: int = 3

## Runs on losing the game
func lose() -> void: 
	print("YOU LOST")
	if game_over_screen and game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over()
	else:
		var go_node = get_node_or_null("../GameOverScreen")
		if go_node and go_node.has_method("show_game_over"):
			go_node.show_game_over()

## Begins the sliding state
func slide():
	if model and "animation_player" in model and model.animation_player:
		model.animation_player.stop()
		
	# Emit the sliding signal and set that the player is sliding
	sliding.emit()
	is_sliding = true
	current_slide_dodge_count = 0
	
	# Play the animation and wait for it to finish
	animation_player.play("Slide")
	if model and model.has_method("play_anim"):
		model.play_anim("Slide")
		
	await animation_player.animation_finished
	
	# Set sliding to false
	is_sliding = false
	current_slide_dodge_count = 0

## Runs the hit wall animation upon being called
func hit():
	cancel_dodge_maneuver()
	animation_player.stop()
	animation_player.play("Hit_Wall")
