extends Node

## Notifies UI to continuously update the power meter
signal power_changed(current_power: float, max_power: float)
## Notifies UI when invincibility state changes
signal invincibility_changed(is_invincible: bool)
## Notifies UI to display the game over screen
signal game_over_triggered

@export_category("Run Configuration")
@export var max_power: float = 100.0 # Max fuel capacity
@export var power_drain_rate: float = 5.0 # Power lost per second
@export var slide_cost: int = 10
@export var dash_cost: int = 25
@export var base_speed: float = 15.0 # Starting movement speed in m/s
@export var speed_acceleration: float = 0.25 # Adds 15 m/s every 60 seconds
@export var coasting_deceleration: float = 5.0 # Speed lost per second while coasting
@export var crystal_invincibility_duration: float = 3.0 # Duration of invincibility/catch-up acceleration
@export var player: Player

# Live tracking variables
var current_power: float = 100.0
var current_speed: float = 15.0
var target_speed: float = 15.0 # Calculated speed ceiling based on distance
var distance_traveled: float = 0.0 # Tracks live distance in meters
var is_run_active: bool = false
var is_coasting: bool = false
var is_invincible: bool = false
var invincibility_timer: float = 0.0

## Resets runtime stats and starts a new run
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
	player.sliding.connect(slide)
	player.dashing.connect(dash)

## Performs acceleration, deceleration, and power drain calculations
func _process(delta: float) -> void:
	if not is_run_active:
		return
		
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
		player.score = DatabaseManager.display_score()
	
	# 3. Increase target speed steadily based on total distance traveled
	# Standard physics motion equation (v = sqrt(v0^2 + 2ad))
	# Scales speed based on distance traveled so gameplay ramps up quickly, but prevents speed from exponentially increasing
	target_speed = sqrt((base_speed * base_speed) + (2.0 * speed_acceleration * distance_traveled))
	
	if is_coasting:
		# 4. Coasting State: Decelerate continuously to 0 m/s
		current_speed = maxf(0.0, current_speed - (coasting_deceleration * delta))
		if current_speed <= 0.0 and player.current_speed <= 0.0:
			end_run()
			
	else:
		# 5. Drains power continuously when not invincible
		if not was_invincible_this_frame:
			current_power = maxf(0.0, current_power - (power_drain_rate * delta))
			power_changed.emit(current_power, max_power)
			if current_power <= 0.0:
				is_coasting = true
		
		# 6. Catch-up acceleration logic when current speed is below target speed
		if current_speed < target_speed:
			# Dynamically calculates exact acceleration needed so current_speed reaches target_speed simultaneously as invincibility_timer reaches 0.0s.
			if is_invincible and invincibility_timer > 0.0:
				var speed_gap: float = target_speed - current_speed
				var required_acceleration: float = speed_gap / maxf(invincibility_timer, delta)
				current_speed = minf(target_speed, current_speed + (required_acceleration * delta))
			else:
				var fallback_acceleration: float = maxf(1.0, speed_acceleration) * 10.0
				current_speed = minf(target_speed, current_speed + (fallback_acceleration * delta))
				
		else:
			current_speed = target_speed
			if is_invincible:
				is_invincible = false
				invincibility_timer = 0.0
				invincibility_changed.emit(false)

## Restores power to full and triggers invincibility if player is recovering speed
func collect_crystal() -> void:
	if not is_run_active:
		return
	
	current_power = max_power
	is_coasting = false
	
	# Invinsibility acts as recovery grace period, but is skipped if already at target speed
	if current_speed < target_speed:
		is_invincible = true
		invincibility_timer = crystal_invincibility_duration
		invincibility_changed.emit(true)
	else:
		is_invincible = false
		invincibility_timer = 0.0
		
	power_changed.emit(current_power, max_power)

## Handles logic for the player hitting an obstacle
func obstacle_hit(damage: float = 25.0) -> void:
	if not is_run_active:
		return
	if is_invincible:
		return
	if is_coasting:
		end_run()
		return
	
	current_power = maxf(0.0, current_power - damage)
	power_changed.emit(current_power, max_power)
	
	if current_power <= 0.0:
		is_coasting = true

## Stops gameplay processing and triggers game over
func end_run() -> void:
	is_run_active = false
	is_coasting = false
	is_invincible = false
	current_speed = 0.0
	game_over_triggered.emit()

func slide():
	current_power = clamp(current_power - slide_cost, 0.0, max_power)

func dash():
	current_power = clamp(current_power - dash_cost, 0.0, max_power)
