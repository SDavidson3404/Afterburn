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

## Overdriven Rocket state flags (overdrive_rocket_max_duration represents 50 fuel units)
var has_overdriven_rocket: bool = false
var is_overdrive_surge: bool = false
var is_overcharged: bool = false
var overdrive_rocket_timer: float = 0.0
var overdrive_rocket_max_duration: float = 50.0
var overdrive_rocket_timers: Array[float] = []

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
	overdrive_rocket_timers.clear()
	speed_acceleration = 0.25
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
			# Drain the active rocket timer at the front of the queue
			var active_drain: float = power_drain_rate * passive_drain_multiplier
			if not overdrive_rocket_timers.is_empty():
				overdrive_rocket_timers[0] = maxf(0.0, overdrive_rocket_timers[0] - (active_drain * delta))
				overdrive_rocket_timer = overdrive_rocket_timers[0]
				
				# Pop depleted rocket stack and advance to the next queued stack
				if overdrive_rocket_timers[0] <= 0.0:
					overdrive_rocket_timers.pop_front()
					if overdrive_rocket_timers.is_empty():
						is_overcharged = false
						overdrive_rocket_timer = 0.0
					else:
						overdrive_rocket_timer = overdrive_rocket_timers[0]
			else:
				is_overcharged = false
				overdrive_rocket_timer = 0.0
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


## Triggers power refill and processes gadget cooldown reduction.
func collect_crystal() -> void:
	if not is_run_active:
		return

	current_power = clampf(current_power + (100.0 * crystal_power_yield), 0.0, max_power)

	# Refill active draining rocket timer
	if is_overcharged and not overdrive_rocket_timers.is_empty():
		overdrive_rocket_timers[0] = clampf(overdrive_rocket_timers[0] + (overdrive_rocket_max_duration * crystal_power_yield), 0.0, overdrive_rocket_max_duration)
		overdrive_rocket_timer = overdrive_rocket_timers[0]

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

	# Reduce cooldown on crystal collection only when the selected gadget is not active
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
			# Returns false to allow re-activation while active and enable immediate cooldown charging
			return false
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
		if not is_overdrive_surge:
			print("[POWER EXHAUSTED] Suit fuel depleted! Initiating OVERDRIVE SURGE!")
		is_overdrive_surge = true
		if player and player.current_speed > current_speed:
			current_speed = player.current_speed
	else:
		if not is_coasting:
			print("[POWER EXHAUSTED] Suit fuel depleted! Starting COASTING deceleration...")
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
	if not selected_gadget or not is_run_active or not player:
		return

	# Prevent activation if armor or pickup instance of the same gadget is currently active
	if _is_selected_gadget_active():
		print("[GADGET BLOCKED] Cannot activate selected gadget while an instance of ", selected_gadget.gadget_name, " is active.")
		return

	# Special partial-activation logic for Power Armor
	if selected_gadget.gadget_id == "power_armor":
		var recharges: int = 6 if is_gadget_ready else clampi(int(round((1.0 - gadget_cooldown_progress) * 6.0)), 0, 6)
		if recharges < 2:
			print("[GADGET BLOCKED] Power Armor requires at least 2/6 recharge to activate (Current: ", recharges, "/6).")
			return

		@warning_ignore("integer_division")
		var hits_to_grant: int = recharges / 2
		var recharges_consumed: int = hits_to_grant * 2
		var remaining_recharges: int = recharges - recharges_consumed

		print("[GADGET ACTIVATED] Power Armor activated with ", recharges, "/6 recharge! Hits granted: ", hits_to_grant, " | Subtracted: ", recharges_consumed, " | Remaining: ", remaining_recharges, "/6")
		selected_gadget.activate_ability(player, self, true, hits_to_grant)

		gadget_cooldown_progress = 1.0 - (float(remaining_recharges) / 6.0)
		is_gadget_ready = (remaining_recharges == 6)
		gadget_cooldown_changed.emit(gadget_cooldown_progress, is_gadget_ready)
		return

	# Standard gadget activation (requires full cooldown readiness)
	if not is_gadget_ready:
		return

	# Prevent activation if Overdriven Rocket stack is full (3)
	if selected_gadget.gadget_id == "overdriven_rocket" and overdrive_rocket_timers.size() >= 3:
		print("[GADGET BLOCKED] Cannot activate Overdriven Rocket: Stack is at maximum capacity (3).")
		return

	var gadget_display_name: String = selected_gadget.gadget_name if "gadget_name" in selected_gadget else "Gadget"
	print("[GADGET ACTIVATED] Activated selected loadout gadget: ", gadget_display_name)

	selected_gadget.activate_ability(player, self, true)

	is_gadget_ready = false
	gadget_cooldown_progress = 1.0
	gadget_cooldown_changed.emit(1.0, false)


## Engages overcharged rocket suit state and appends a new rocket stack to the queue.
func activate_overdrive_rocket() -> void:
	is_overcharged = true
	if overdrive_rocket_timers.size() >= 3:
		if not overdrive_rocket_timers.is_empty():
			overdrive_rocket_timers[0] = overdrive_rocket_max_duration
			overdrive_rocket_timer = overdrive_rocket_timers[0]
			print("[OVERDRIVE ROCKET] Stack full (3)! Refilled power of active draining rocket.")
	else:
		overdrive_rocket_timers.append(overdrive_rocket_max_duration)
		overdrive_rocket_timer = overdrive_rocket_timers[0]

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


## Unregisters broken Power Armor shield layer.
func unregister_armor_layer(armor_node: Node) -> void:
	active_armor_layers.erase(armor_node)


## Intercepts collision damage through active armor, overdrive rocket stacks, or suit power meter.
func obstacle_hit(damage: float = 25.0) -> void:
	if not is_run_active or is_invincible:
		return

	# Intercept hit if Power Armor shield layer is active
	if active_armor_layers.size() > 0:
		var armor = active_armor_layers[0]
		var broke: bool = armor.absorb_hit()
		if broke:
			print("[OBSTACLE HIT] Power Armor absorbed hit and BROKE!")
		else:
			print("[OBSTACLE HIT] Power Armor absorbed hit! Hits remaining: ", armor.hits_remaining)
		return
		
	# Zero-power coasting/surge states result in immediate game over on hit
	if is_coasting or is_overdrive_surge:
		print("[OBSTACLE HIT] Collided with obstacle while coasting/overdriven! Immediate crash.")
		end_run()
		return
	
	var total_damage: float = damage * obstacle_damage_multiplier

	# Deduct damage from overcharged rocket stacks before affecting suit power
	if is_overcharged and not overdrive_rocket_timers.is_empty():
		var remaining_damage: float = total_damage
		while remaining_damage > 0.0 and not overdrive_rocket_timers.is_empty():
			if overdrive_rocket_timers[0] > remaining_damage:
				overdrive_rocket_timers[0] -= remaining_damage
				remaining_damage = 0.0
			else:
				remaining_damage -= overdrive_rocket_timers[0]
				overdrive_rocket_timers.pop_front()
		
		if overdrive_rocket_timers.is_empty():
			is_overcharged = false
			overdrive_rocket_timer = 0.0
			print("[OBSTACLE HIT] Rocket Overcharge shield depleted by obstacle hit!")
		else:
			overdrive_rocket_timer = overdrive_rocket_timers[0]
			print("[OBSTACLE HIT] Rocket Overcharge absorbed hit! Remaining fuel timer: ", "%.1f" % overdrive_rocket_timer, "s")
		
		if remaining_damage <= 0.0:
			return
		else:
			total_damage = remaining_damage

	current_power = maxf(0.0, current_power - total_damage)
	print("[OBSTACLE HIT] Hit obstacle! Damage taken: ", "%.1f" % total_damage, " | Remaining Power: ", "%.1f" % current_power)
	
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


## Power drain callback invoked when player dashes.
func dash():
	current_power = clampf(current_power - dash_cost, 0.0, max_power)
	print("[PLAYER DASH] Dash executed! Remaining Power: ", "%.1f" % current_power)
	power_changed.emit(current_power, max_power)
	if current_power <= 0.0 and not is_overcharged:
		_handle_zero_power()
