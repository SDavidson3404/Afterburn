## Central run state manager controlling player power economy, kinematic speed scaling, damage resolution pipelines, and gadget cooldown lifecycles.
extends Node

## Emitted when suit power level changes.
signal power_changed(current_power: float, max_power: float)

## Emitted when player invincibility status toggles on or off.
signal invincibility_changed(is_invincible: bool)

## Emitted when loadout gadget cooldown status or progress percentage updates.
signal gadget_cooldown_changed(cooldown_progress: float, is_ready: bool)

## Emitted when a run terminates, triggering game over UI and data saving.
signal game_over_triggered

@export_category("Run Configuration")
## Maximum suit power meter capacity.
@export var max_power: float = 100.0

## Passive suit power drain rate per second during normal operation.
@export var power_drain_rate: float = 5.0

## Baseline forward movement speed at run start in meters per second.
@export var base_speed: float = 15.0

## Terminal forward movement velocity cap (Mach 1 equivalent in m/s).
@export var max_speed: float = 343.0

## Acceleration constant used in kinematic speed scaling calculations.
@export var speed_acceleration: float = 0.25

## Rate at which forward speed decays per second when power reaches zero.
@export var coasting_deceleration: float = 5.0

## Temporary invincibility duration granted when collecting crystals during speed catch-up.
@export var crystal_invincibility_duration: float = 3.0

## Suit power cost subtracted when executing a slide dodge maneuver.
@export var slide_cost: int = 10

## Suit power cost subtracted when executing a dash speed boost.
@export var dash_cost: int = 25

## Reference to the active Player node.
@export var player: Player

@export_category("Gadget Setup")
## Active GadgetBase instance equipped for the current run.
@export var selected_gadget: GadgetBase = null

# Multiplier modifiers dynamically altered by equipped gadgets
var crystal_power_yield: float = 1.0
var passive_drain_multiplier: float = 1.0
var obstacle_damage_multiplier: float = 1.0
var coasting_deceleration_multiplier: float = 1.0

# Cooldown tracking variables
var gadget_cooldown_progress: float = 0.0
var is_gadget_ready: bool = true

# Overdriven Rocket state flags (overdrive_rocket_max_duration represents 40 fuel units = 8s flight at base drain)
var has_overdriven_rocket: bool = false
var is_overdrive_surge: bool = false
var is_overcharged: bool = false
var overdrive_rocket_timer: float = 0.0
var overdrive_rocket_max_duration: float = 40.0

# Armor interception registry and runtime state trackers
var active_armor_layers: Array = []
var current_power: float = 100.0
var current_speed: float = 15.0
var target_speed: float = 15.0
var distance_traveled: float = 0.0
var is_run_active: bool = false
var is_coasting: bool = false
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var speed_recovery_timer: float = 0.0


## Resets all run variables, applies loadout gadget nerfs, and starts active gameplay.
func start_run() -> void:
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.reset_run_stats()

	# Reset suit modifiers and overdrive states to baseline defaults
	is_overcharged = false
	overdrive_rocket_timer = 0.0
	max_power = 100.0
	crystal_power_yield = 1.0
	passive_drain_multiplier = 1.0
	obstacle_damage_multiplier = 1.0
	coasting_deceleration_multiplier = 1.0
	has_overdriven_rocket = false
	is_overdrive_surge = false
	active_armor_layers.clear()
	
	# Apply loadout handicaps and initialize cooldown state if a gadget is equipped
	if selected_gadget:
		selected_gadget.apply_loadout_nerf(self)
		gadget_cooldown_progress = 0.0
		is_gadget_ready = true
		gadget_cooldown_changed.emit(0.0, true)
		
	current_power = max_power
	current_speed = base_speed
	target_speed = base_speed
	distance_traveled = 0.0
	is_run_active = true
	is_coasting = false
	is_invincible = false
	invincibility_timer = 0.0
	speed_recovery_timer = 0.0
	
	power_changed.emit(current_power, max_power)
	
	# Bind player action signals to power drain callbacks
	if player:
		if not player.sliding.is_connected(slide):
			player.sliding.connect(slide)
		if not player.dashing.is_connected(dash):
			player.dashing.connect(dash)


func _process(delta: float) -> void:
	if not is_run_active:
		return
		
	var was_invincible_this_frame: bool = is_invincible
	
	# Process invincibility expiration and speed catch-up logic
	if is_invincible:
		var speed_ratio: float = current_speed / target_speed if target_speed > 0.0 else 1.0
		if speed_ratio >= 0.80:
			_set_invincible(false)
		else:
			invincibility_timer -= delta
			if invincibility_timer <= 0.0:
				_set_invincible(false)
			
	if speed_recovery_timer > 0.0:
		speed_recovery_timer = maxf(0.0, speed_recovery_timer - delta)
	
	# Track physical distance moved and update travel score
	var meters_moved: float = current_speed * delta
	distance_traveled += meters_moved
	
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_distance(meters_moved)
	
	# Kinematic target speed scaling equation: target_speed = sqrt(v_0^2 + 2 * a * d)
	target_speed = minf(sqrt((base_speed * base_speed) + (2.0 * speed_acceleration * distance_traveled)), max_speed)
	
	# State Machine Processing: Coasting vs Overdrive Surge vs Normal Operation
	if is_coasting:
		var active_coasting_rate: float = coasting_deceleration * coasting_deceleration_multiplier
		current_speed = maxf(0.0, current_speed - (active_coasting_rate * delta))
		if current_speed <= 0.0 and (not player or player.current_speed <= 0.0):
			end_run()
			
	elif is_overdrive_surge:
		# Overdrive Surge rapidly accelerates player toward top speed when fuel hits zero
		current_speed = move_toward(current_speed, max_speed, 50.0 * delta)
	
	else:
		if is_overcharged:
			# Rocket Overcharge state bypasses standard suit fuel drain
			var active_drain: float = power_drain_rate * passive_drain_multiplier
			overdrive_rocket_timer = maxf(0.0, overdrive_rocket_timer - (active_drain * delta))
			if overdrive_rocket_timer <= 0.0:
				is_overcharged = false
		else:
			if not was_invincible_this_frame:
				var active_drain: float = power_drain_rate * passive_drain_multiplier
				current_power = maxf(0.0, current_power - (active_drain * delta))
				power_changed.emit(current_power, max_power)
				
				if current_power <= 0.0:
					_handle_zero_power()
		
		# Catch-up acceleration logic restoring player speed after obstacle collisions
		if current_speed < target_speed:
			if speed_recovery_timer > 0.0:
				var speed_gap: float = target_speed - current_speed
				var required_acceleration: float = speed_gap / maxf(speed_recovery_timer, delta)
				current_speed = minf(target_speed, current_speed + (required_acceleration * delta))
			else:
				var fallback_acceleration: float = maxf(1.0, speed_acceleration) * 10.0
				current_speed = minf(target_speed, current_speed + (fallback_acceleration * delta))
		else:
			current_speed = target_speed
			speed_recovery_timer = 0.0
			if is_invincible:
				_set_invincible(false)


## Triggers power refill, restores coasting/surge states, and processes gadget cooldown reduction.
func collect_crystal() -> void:
	if not is_run_active:
		return
	
	current_power = clampf(current_power + (100.0 * crystal_power_yield), 0.0, max_power)
	
	if is_overcharged and overdrive_rocket_timer > 0.0:
		overdrive_rocket_timer = clampf(overdrive_rocket_timer + (overdrive_rocket_max_duration * crystal_power_yield), 0.0, overdrive_rocket_max_duration)
	
	if is_overdrive_surge:
		is_overdrive_surge = false
		current_speed = target_speed
	is_coasting = false
	
	# Grant catch-up invincibility if collecting a crystal while running below target speed
	var speed_ratio: float = current_speed / target_speed if target_speed > 0.0 else 1.0
	if current_speed < target_speed:
		if not has_overdriven_rocket and speed_ratio < 0.80:
			_set_invincible(true, crystal_invincibility_duration)
		else:
			_set_invincible(false)
		speed_recovery_timer = crystal_invincibility_duration
	else:
		_set_invincible(false)
		speed_recovery_timer = 0.0
		
	power_changed.emit(current_power, max_power)
	
	# Reduce equipped gadget cooldown if player is running at target speed without an active ability running
	if selected_gadget and not is_gadget_ready and is_at_target_speed():
		if _is_selected_gadget_active():
			return

		reduce_gadget_cooldown(1.0 / maxf(1.0, float(selected_gadget.cooldown_crystals_required)))


## Polymorphic helper querying whether the equipped gadget currently has an active state/buff.
func _is_selected_gadget_active() -> bool:
	if not selected_gadget:
		return false
	
	if selected_gadget.has_method("is_active"):
		return selected_gadget.is_active(player, self)
	
	match selected_gadget.gadget_id:
		"overdriven_rocket":
			return is_overcharged
		"power_armor":
			return active_armor_layers.size() > 0
		"hoverboard":
			return player != null and player.has_node("HoverboardInstance")
		"magnet":
			return player != null and player.has_node("MagnetInstance")
			
	return false


## Toggles invincibility status and notifies connected listeners via signals.
func _set_invincible(enabled: bool, duration: float = 0.0) -> void:
	is_invincible = enabled
	invincibility_timer = duration if enabled else 0.0
	invincibility_changed.emit(enabled)


## Handles zero-power fuel exhaustion, triggering either Overdrive Surge or standard coasting.
func _handle_zero_power() -> void:
	if has_overdriven_rocket:
		is_overdrive_surge = true
		if player and player.current_speed > current_speed:
			current_speed = player.current_speed
	else:
		is_coasting = true


## Reduces gadget cooldown progress ratio and emits UI update signals.
func reduce_gadget_cooldown(amount: float) -> void:
	gadget_cooldown_progress = maxf(0.0, gadget_cooldown_progress - amount)
	if gadget_cooldown_progress <= 0.001:
		is_gadget_ready = true
		gadget_cooldown_progress = 0.0
	gadget_cooldown_changed.emit(gadget_cooldown_progress, is_gadget_ready)


## Polymorphically triggers equipped gadget active power if ready and sets initial cooldown state.
func try_use_loadout_gadget() -> void:
	if not selected_gadget or not is_run_active or not is_gadget_ready or not player:
		return

	selected_gadget.activate_ability(player, self)
		
	is_gadget_ready = false
	if selected_gadget.gadget_id != "power_armor":
		gadget_cooldown_progress = 1.0
		gadget_cooldown_changed.emit(1.0, false)


## Engages overcharged rocket suit state for maximum active duration.
func activate_overdrive_rocket() -> void:
	is_overcharged = true
	overdrive_rocket_timer = overdrive_rocket_max_duration
	if is_overdrive_surge or is_coasting:
		is_overdrive_surge = false
		is_coasting = false
		if current_speed < target_speed:
			speed_recovery_timer = crystal_invincibility_duration
	power_changed.emit(current_power, max_power)


## Returns true if current forward speed matches current target speed threshold.
func is_at_target_speed() -> bool:
	return absf(current_speed - target_speed) < 0.5


## Calculates required player reaction window (3.0s down to 1.0s) based on target speed.
func get_reaction_time() -> float:
	var clamped_spd: float = clampf(target_speed, base_speed, max_speed)
	return remap(clamped_spd, base_speed, max_speed, 3.00, 1.00)


## Returns obstacle spawn distance ahead of player scaled to target velocity.
func get_current_spawn_distance() -> float:
	var clamped_spd: float = clampf(target_speed, base_speed, max_speed)
	return clamped_spd * get_reaction_time()


## Registers active Power Armor shield layer component with power manager.
func register_armor_layer(armor_node: Node) -> void:
	active_armor_layers.append(armor_node)


## Unregisters broken Power Armor shield layer and puts armor gadget back on cooldown.
func unregister_armor_layer(armor_node: Node) -> void:
	active_armor_layers.erase(armor_node)
	if selected_gadget and selected_gadget.gadget_id == "power_armor":
		is_gadget_ready = false
		gadget_cooldown_progress = 1.0
		gadget_cooldown_changed.emit(1.0, false)


## Intercepts collision damage through active armor, overdrive rocket, or suit power meter.
func obstacle_hit(damage: float = 25.0) -> void:
	if not is_run_active or is_invincible:
		return

	# Intercept hit if Power Armor shield layer is active
	if active_armor_layers.size() > 0:
		active_armor_layers[0].absorb_hit()
		return
		
	# Zero-power coasting/surge states result in immediate game over on hit
	if is_coasting or is_overdrive_surge:
		end_run()
		return
	
	var total_damage: float = damage * obstacle_damage_multiplier

	# Deduct damage from overcharged rocket duration before affecting main power meter
	if is_overcharged:
		if overdrive_rocket_timer > total_damage:
			overdrive_rocket_timer -= total_damage
			return
		else:
			total_damage -= overdrive_rocket_timer
			overdrive_rocket_timer = 0.0
			is_overcharged = false

	current_power = maxf(0.0, current_power - total_damage)
	power_changed.emit(current_power, max_power)
	if current_power <= 0.0:
		_handle_zero_power()


## Terminates active run, saves statistics to SQLite database, and fires game over signal.
func end_run() -> void:
	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.save_run()
		
	is_run_active = false
	is_coasting = false
	is_overdrive_surge = false
	is_invincible = false
	current_speed = 0.0
	game_over_triggered.emit()


## Power drain callback invoked when player slides.
func slide():
	current_power = clampf(current_power - slide_cost, 0.0, max_power)
	power_changed.emit(current_power, max_power)


## Power drain callback invoked when player dashes.
func dash():
	current_power = clampf(current_power - dash_cost, 0.0, max_power)
	power_changed.emit(current_power, max_power)
	if current_power <= 0.0 and not is_overcharged:
		_handle_zero_power()
