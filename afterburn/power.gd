extends Node

## Notifies UI to continuously update the power meter
signal power_changed(current_power: float, max_power: float)
## Notifies UI when invincibility state changes
signal invincibility_changed(is_invincible: bool)
## Notifies UI to display the game over screen
signal game_over_triggered

# Adjustable variables for the Godot Inspector
@export_category("Run Configuration")
@export var max_power: float = 100.0 # Max fuel capacity
@export var power_drain_rate: float = 5.0 # Power lost per second
@export var base_speed: float = 15.0 # Starting movement speed in meters per second
@export var speed_acceleration: float = 0.25 # Base acceleration rate which adds 15 m/s every 60 seconds
@export var coasting_deceleration: float = 5.0 # Speed lost per second while coasting
@export var crystal_invincibility_duration: float = 3.0 # Duration of invincibility/catch-up acceleration

# Live tracking variables
var current_power: float = 100.0 # Tracks fuel remaining in real-time
var current_speed: float = 15.0 # Tracks player speed at real-time
var target_speed: float = 15.0 # Calculated speed based on distance
var distance_traveled: float = 0.0 # Tracks live distance in meters
var is_run_active: bool = false
var is_coasting: bool = false
var is_invincible: bool = false
var invincibility_timer: float = 0.0

## Resets runtime stats and starts a new run
## Called by the UI/Level script when the player clicks the start button
func start_run() -> void:
	current_power = max_power
	current_speed = base_speed
	target_speed = base_speed
	distance_traveled = 0.0
	is_run_active = true
	is_coasting = false
	is_invincible = false
	invincibility_timer = 0.0
	power_changed.emit(current_power, max_power)

## Performs acceleration and deceleration calculations
## Called every frame during a run
func _process(delta: float) -> void:
	if not is_run_active: # Keeps the function from running when paused or during a game over
		return
	
	# Checks if invincibility is active this frame to prevent power from draining
	var was_invincible_this_frame: bool = is_invincible
	
	# 1. Update invincibility timer
	if is_invincible:
		invincibility_timer -= delta
		
		if invincibility_timer <= 0.0:
			is_invincible = false
			invincibility_timer = 0.0
			invincibility_changed.emit(false)
	
	# 2. Track distance traveled each frame
	var meters_moved: float = current_speed * delta
	distance_traveled += meters_moved
	
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_distance(meters_moved)
	
	# 3. Increase target speed steadily based on total distance traveled
	target_speed = sqrt((base_speed * base_speed) + (2.0 * speed_acceleration * distance_traveled)) # This formula prevents the player's speed from increasing exponentially
	
	if is_coasting: # Logic used when the player runs out of power
		# 4. Coasting State: Decelerate continuously to 0 m/s
		current_speed = maxf(0.0, current_speed - (coasting_deceleration * delta))
		
		# Game over logic for coming to a stop
		if current_speed <= 0.0:
			end_run()
		
	else: # Logic used when the player has power
		
		# 5. Drains power continuously when not invincible (5 units per second)
		if not was_invincible_this_frame:
			current_power = maxf(0.0, current_power - (power_drain_rate * delta))
			power_changed.emit(current_power, max_power)
		
			# Triggers coasting when the player runs out of power
			if current_power <= 0.0:
				is_coasting = true
		
		# 6. Catch-up acceleration logic when the player picks up a crystal while coasting
		if current_speed < target_speed:
			# Coverges the player's current speed to target speed over the invincibility's duration
			if is_invincible and invincibility_timer > 0.0:
				var speed_gap: float = target_speed - current_speed
				var required_acceleration: float = speed_gap / maxf(invincibility_timer, delta)
				current_speed = minf(target_speed, current_speed + (required_acceleration * delta))
			
			# Backup catch-up acceleration logic in case the player is still below the target speed
			else:
				var fallback_acceleration: float = maxf(1.0, speed_acceleration) * 10.0
				current_speed = minf(target_speed, current_speed + (fallback_acceleration * delta))
		
		else: # Logic used when the player reaches target speed
			current_speed = target_speed

## Restores power to full and triggers invincibility when the player picks up a power crystal
## Called when collecting a power crystal
func collect_crystal() -> void:
	if not is_run_active:
		return
	
	current_power = max_power
	is_coasting = false
	is_invincible = true
	invincibility_timer = crystal_invincibility_duration
	invincibility_changed.emit(true)
	power_changed.emit(current_power, max_power)

## Handles logic for the player hitting an obstacle
## Called when the player hits an obstacle
func obstacle_hit(damage: float = 25.0) -> void:
	if not is_run_active:
		return
	
	# Obstacles are ignored if invincible
	if is_invincible:
		return
	
	# Hitting an obstacle while coasting causes an immediate game over
	if is_coasting:
		end_run()
		return
	
	# Hitting an obstacle while accelerating decreases power by 25%
	current_power = maxf(0.0, current_power - damage)
	power_changed.emit(current_power, max_power)
	
	# Triggers coasting if the collision reduced the power to 0
	if current_power <= 0.0:
		is_coasting = true

## Stops gameplay processing and triggers game over
## Called when the player gets a game over
func end_run() -> void:
	is_run_active = false
	is_coasting = false
	is_invincible = false
	current_speed = 0.0
	game_over_triggered.emit()
