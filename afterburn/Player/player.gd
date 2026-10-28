## Player character controller script.
## Manages 5-lane strafing, kinematic jumping/sliding physics, dynamic HUD updates, and movement stat multipliers modified by active gadgets.
extends Node3D
class_name Player

## Emitted when player initiates a ground slide maneuver.
signal sliding

## Emitted when player triggers a forward speed dash.
signal dashing

@export_category("Node References")
## Reference to the main power manager node tracking run state and speed.
@export var power_node: Node

## Reference to the front-facing wall collision detector node.
@export var Wall_Detection: Node3D

@onready var camera: Camera3D = $Body/Camera3D
@onready var score_label: Label = $Body/UI/ScoreLabel
@onready var row_squares: Node2D = $Body/UI/Row_Squares
@onready var body: CharacterBody3D = $Body
@onready var invincible_indicator: MeshInstance2D = $"Body/UI/Invincible indicator"
@onready var power_meter: ProgressBar = $"Body/UI/Power Meter"
@onready var speed_label: Label = $Body/UI/SpeedLabel
@onready var animation_player: AnimationPlayer = $Body/AnimationPlayer
@onready var timer: Timer = $Timer

# Discrete lane boundaries and physics constants
const MIN_ROW_INDEX: int = -2
const MAX_ROW_INDEX: int = 2
const JUMP_VELOCITY: float = 7.0
const GRAVITY: float = 12.0
const STRAFE_SPEED: float = 15.0
const DASH_DRAIN_RATE: float = 10.0
const DASH_MULTIPLIER: float = 2.0

# Runtime state trackers
var current_speed: float = 15.0
var row_index: int = 0
var current_row_offset: float = 0.0
var is_sliding: bool = false
var is_dashing: bool = false
var starting_run: bool = true

# Dynamic stat multipliers overridden by gadgets (e.g., Hoverboard)
var jump_velocity_multiplier: float = 1.0
var gravity_multiplier: float = 1.0
var dash_drain_multiplier: float = 1.0


func _ready() -> void:
	connect_signals()
	# Set idle state color for invincibility visual indicator
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


## Processes keyboard and mouse input events for lane switching, abilities, and UI focus.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Click") and power_node and power_node.is_run_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event.is_action_pressed("A"): move_left()
	if event.is_action_pressed("D"): move_right()
	if event.is_action_pressed("S") and not is_sliding and body.is_on_floor(): slide()
	
	if event.is_action_pressed("W") and power_node and power_node.current_power >= power_node.dash_cost:
		is_dashing = true
		dashing.emit()
	
	if event.is_action_pressed("Gadget"):
		if power_node and power_node.has_method("try_use_loadout_gadget"):
			power_node.try_use_loadout_gadget()
	
	if event.is_action_pressed("ESC"): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Shifts target lane index left by one row unit (-X direction).
func move_left() -> void:
	if row_index > MIN_ROW_INDEX:
		row_index -= 1
		update_target_row()


## Shifts target lane index right by one row unit (+X direction).
func move_right() -> void:
	if row_index < MAX_ROW_INDEX:
		row_index += 1
		update_target_row()


## Calculates target X-axis position based on current 3-unit lane spacing.
func update_target_row() -> void:
	current_row_offset = int(row_index) * 3


## Physical movement processing loop for strafing, jumping, dashing, and HUD state updates.
func _physics_process(delta: float) -> void:
	if not power_node or not power_node.is_run_active:
		return
		
	# Update power meter progress bar value
	if power_meter:
		power_meter.value = min(power_node.current_power, 100.0)
	
	speed_label.text = "SPEED(MPS): %.1f" % current_speed
	if get_node_or_null("/root/DatabaseManager"):
		score_label.text = "SCORE: %d" % DatabaseManager.display_score()
	
	update_row_square()
	body.velocity.x = 0.0
	
	# Apply forward Z-velocity based on dash status and power manager velocity
	if is_dashing:
		body.velocity.z = -power_node.current_speed * DASH_MULTIPLIER
		is_dashing = false
	elif starting_run:
		body.velocity.z = -power_node.current_speed
		starting_run = false
	else:
		var target_vel_z: float = -power_node.current_speed
		if body.velocity.z < target_vel_z:
			# Decelerate boost velocity down to standard target run speed
			var active_drain_rate: float = DASH_DRAIN_RATE * dash_drain_multiplier
			body.velocity.z = move_toward(body.velocity.z, target_vel_z, active_drain_rate * delta)
		else:
			body.velocity.z = move_toward(body.velocity.z, target_vel_z, 50.0 * delta)
	
	current_speed = -body.velocity.z
	# Interpolate physical X position toward target lane coordinate
	body.global_position.x = move_toward(body.global_position.x, current_row_offset, STRAFE_SPEED * delta)
	
	# Process vertical jump mechanics and cancel active slide animation
	if Input.is_action_just_pressed("Space") and body.is_on_floor():
		if is_sliding:
			if animation_player.current_animation == "Slide":
				animation_player.stop()
			is_sliding = false
		body.velocity.y += (JUMP_VELOCITY * jump_velocity_multiplier)
	
	# Apply downward gravitational acceleration when airborne
	if not body.is_on_floor():
		body.velocity.y -= (GRAVITY * gravity_multiplier) * delta
	
	body.move_and_slide()


## Highlights active row indicator box on the HUD based on current lane index.
func update_row_square() -> void:
	var active_row_name = "Row" + str(row_index + 3)
	for child in row_squares.get_children():
		child.modulate = Color(1.0, 1.0, 1.0, 1.0) if child.name == active_row_name else Color(0.0, 0.0, 0.0, 1.0)


## Connects power manager and wall detection signals to player handling callbacks.
func connect_signals() -> void:
	if power_node:
		power_node.invincibility_changed.connect(_on_power_invincibility_changed)
		power_node.game_over_triggered.connect(lose)
	if Wall_Detection:
		Wall_Detection.Wall_Hit.connect(hit)


## Modulates invincibility HUD indicator color when invincibility state changes.
func _on_power_invincibility_changed(is_invincible: bool) -> void:
	invincible_indicator.modulate = Color(0.843, 0.733, 0.0, 0.573) if is_invincible else Color(0.0, 0.0, 0.0, 0.325)


## Starts restart countdown timer on run defeat.
func lose() -> void:
	timer.start()


## Executes slide animation sequence.
func slide() -> void:
	sliding.emit()
	is_sliding = true
	animation_player.play("Slide")
	await animation_player.animation_finished
	is_sliding = false


## Plays wall impact animation sequence when colliding with an obstacle.
func hit() -> void:
	animation_player.stop()
	animation_player.play("Hit_Wall")


## Reloads current scene upon death timer expiration.
func _on_timer_timeout() -> void:
	get_tree().reload_current_scene()
