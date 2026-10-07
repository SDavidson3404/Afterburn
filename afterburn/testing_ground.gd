extends Node

func _ready() -> void:
	
	# The following line will clear all data from the stats table. Uncomment it to execute when needed
	# DatabaseManager.db.query("DELETE FROM stats;")
	
	print("====================================")
	print("--- FULL DATABASE MANAGER TEST ---")
	print("====================================\n")
	
	# 1. Check initial lifetime stats on database read
	print("--- 1. INITIAL LIFETIME STATS ---")
	print("Lifetime Stats: ", DatabaseManager.lifetime_stats())
	print("------------------------------------\n")
	
	# 2. Simulate Run 1 (Triggers all tracking methods)
	print("--- 2. SIMULATING RUN #1 ---")
	DatabaseManager.add_distance(3200.0)         # 3200 meters = 3200 travel points
	DatabaseManager.add_dodge("jump")            # 1 jump dodge (+10 pts)
	DatabaseManager.add_dodge("slide")           # 1 slide dodge (+10 pts)
	DatabaseManager.add_dodge("dash")            # 1 dash dodge (+10 pts)
	DatabaseManager.add_crystal()                # 1 crystal (+100 pts)
	DatabaseManager.add_crystal()                # 2 crystals (+100 pts)
	DatabaseManager.add_gadget()                 # 1 gadget
	DatabaseManager.player_crash("robot")        # 1 robot crash
	DatabaseManager.player_crash("scaffolding")  # 1 scaffolding crash
	DatabaseManager.player_crash("drone")        # 1 drone crash
	
	print("Current Calculated Score (Expected 3430): ", DatabaseManager.display_score())
	
	# 3. Save Run 1 to SQLite
	var run1_data: Dictionary = DatabaseManager.save_run()
	print("Data Saved for Run 1: ", run1_data)
	
	# 4. Reset active run stats
	DatabaseManager.reset_run_stats()
	print("Score After Reset (Expected 0): ", DatabaseManager.display_score())
	print("------------------------------------\n")
	
	# 5. Verify lifetime stats updated for 1 run
	print("--- 3. LIFETIME STATS AFTER RUN 1 ---")
	print("Lifetime Stats: ", DatabaseManager.lifetime_stats())
	print("------------------------------------\n")
	
	# 6. Simulate Run 2 (Tests multi-run aggregation, MAX, and SUM logic)
	print("--- 4. SIMULATING RUN #2 ---")
	DatabaseManager.add_distance(6400.0)   # 6400 meters = 6400 travel points
	DatabaseManager.add_dodge("jump")      # 1 dodge (+10 pts)
	DatabaseManager.add_crystal()          # 1 crystal (+100 pts)
	DatabaseManager.add_gadget()           # 1 gadget
	DatabaseManager.add_gadget()           # 2 gadgets
	DatabaseManager.player_crash("robot")  # 1 robot crash
	
	print("Run 2 Calculated Score (Expected 6510): ", DatabaseManager.display_score())
	var run2_data: Dictionary = DatabaseManager.save_run()
	print("Data Saved for Run 2: ", run2_data)
	DatabaseManager.reset_run_stats()
	print("------------------------------------\n")
	
	# 7. Check final lifetime accumulation totals
	print("--- 5. FINAL LIFETIME STATS (2 TOTAL RUNS) ---")
	print("Lifetime Stats: ", DatabaseManager.lifetime_stats())
	print("====================================\n")
	
	# Execute Power Manager test suite
	run_power_tests()
	
	# Execute Crystal Spawner test suite
	run_crystal_spawn_tests()
	
## Comprehensive test suite for power.gd physics, invincibility, catch-up math, and signals
func run_power_tests() -> void:
	print("====================================")
	print("--- FULL POWER TEST ---")
	print("====================================\n")
	
	# Instantiate power node into tree so scene calls work safely
	var power: Node = preload("res://power.gd").new()
	add_child(power)
	
	# Use single-element arrays to safely pass boolean flags by reference into lambdas
	var signal_power_updated: Array = [false]
	var signal_invincible_updated: Array = [false]
	var signal_game_over_fired: Array = [false]
	
	power.power_changed.connect(func(_curr, _max_p): signal_power_updated[0] = true)
	power.invincibility_changed.connect(func(is_inv): signal_invincible_updated[0] = is_inv)
	power.game_over_triggered.connect(func(): signal_game_over_fired[0] = true)
	
	# --- TEST 1: START RUN & INITIALIZATION ---
	print("--- 1. START RUN INITIALIZATION ---")
	power.start_run()
	print("Run Active: ", power.is_run_active, " (Expected: true)")
	print("Starting Speed: ", power.current_speed, " m/s (Expected: 15.0)")
	print("Starting Power: ", power.current_power, " (Expected: 100.0)")
	print("Is Invincible: ", power.is_invincible, " (Expected: false)")
	print("Signal Emitted on Start: ", signal_power_updated[0], " (Expected: true)")
	print("------------------------------------\n")
	
	# --- TEST 2: SIMULATE 10 SECONDS OF MOVEMENT & SPEED SCALING ---
	print("--- 2. TIME STEP & SQRT DISTANCE ACCELERATION ---")
	signal_power_updated[0] = false
	
	# Simulate 10 seconds of gameplay in steps of 1 second
	for i in range(10):
		power._process(1.0)
		
	print("Distance Traveled: ", power.distance_traveled, " meters")
	print("Target Speed (sqrt scaled): ", power.target_speed, " m/s")
	print("Current Speed: ", power.current_speed, " m/s")
	print("Current Power (10s @ 5/s drain): ", power.current_power, " (Expected: 50.0)")
	print("------------------------------------\n")
	
	# --- TEST 3: OBSTACLE HIT DAMAGE (25 UNIT POWER LOSS) ---
	print("--- 3. OBSTACLE HIT DAMAGE ---")
	power.obstacle_hit(25.0)
	print("Power after 25 unit obstacle hit: ", power.current_power, " (Expected: 25.0)")
	print("Is Coasting: ", power.is_coasting, " (Expected: false)")
	print("------------------------------------\n")
	
	# --- TEST 4: DRAIN TO ZERO & COASTING TRIGGER ---
	print("--- 4. ZERO POWER COASTING TRIGGER ---")
	# Process 6 more seconds to drain remaining 25 power to 0
	for i in range(6):
		power._process(1.0)
		
	print("Current Power: ", power.current_power, " (Expected: 0.0)")
	print("Is Coasting Active: ", power.is_coasting, " (Expected: true)")
	print("------------------------------------\n")
	
	# --- TEST 5: CRYSTAL PICKUP, INVINCIBILITY & PAUSED DRAIN ---
	print("--- 5. CRYSTAL PICKUP & INVINCIBILITY TRIGGER ---")
	var coasting_speed: float = power.current_speed
	print("Speed while coasting: ", coasting_speed, " m/s")
	
	power.collect_crystal()
	print("Power after Crystal: ", power.current_power, " (Expected: 100.0)")
	print("Is Coasting reset: ", power.is_coasting, " (Expected: false)")
	print("Is Invincible active: ", power.is_invincible, " (Expected: true)")
	print("Invincibility Timer: ", power.invincibility_timer, "s (Expected: 3.0)")
	print("Invincibility Signal Emitted: ", signal_invincible_updated[0], " (Expected: true)")
	
	# Simulate 1 second step inside the invincibility window
	power._process(1.0)
	print("Power after 1s Invincibility (Paused Drain): ", power.current_power, " (Expected: 100.0)")
	print("Speed after 1s Catch-Up: ", power.current_speed, " m/s (Expected: higher than ", coasting_speed, " m/s)")
	print("------------------------------------\n")
	
	# --- TEST 6: OBSTACLE IMMUNITY DURING INVINCIBILITY ---
	print("--- 6. OBSTACLE IMMUNITY DURING INVINCIBILITY ---")
	power.obstacle_hit(25.0) # Attempt to deal damage during invincibility
	print("Power after Obstacle Hit while Invincible: ", power.current_power, " (Expected: 100.0)")
	print("------------------------------------\n")
	
	# --- TEST 7: CATCH-UP COMPLETION & INVINCIBILITY EXPIRATION ---
	print("--- 7. CATCH-UP COMPLETION & INVINCIBILITY EXPIRATION ---")
	# Process remaining 2 seconds of invincibility frame-by-frame
	power._process(1.0)
	power._process(1.0)
	
	print("Is Invincible after 3s total: ", power.is_invincible, " (Expected: false)")
	print("Invincibility Signal Emitted (False): ", signal_invincible_updated[0] == false, " (Expected: true)")
	print("Current Speed vs Target Speed: ", power.current_speed, " / ", power.target_speed, " m/s")
	
	# Process 1 additional second to verify power drain continues post-invincibility
	power._process(1.0)
	print("Power after 1s post-invincibility drain: ", power.current_power, " (Expected: 95.0)")
	print("------------------------------------\n")
	
	# --- TEST 8: COASTING OBSTACLE HIT (INSTANT GAME OVER) ---
	print("--- 8. COASTING OBSTACLE HIT (INSTANT GAME OVER) ---")
	power.is_coasting = true
	signal_game_over_fired[0] = false # Mutate existing array element
	
	power.obstacle_hit(25.0)
	print("Game Over Signal Emitted: ", signal_game_over_fired[0], " (Expected: true)")
	print("Run Active state: ", power.is_run_active, " (Expected: false)")
	print("====================================")
	
	# Clean up test node
	power.queue_free()
	
	## Comprehensive test suite for crystal_spawn.gd spawner logic, curves, and lifecycle
func run_crystal_spawn_tests() -> void:
	print("====================================")
	print("--- FULL CRYSTAL SPAWN TEST ---")
	print("====================================\n")
	
	# 1. Setup Test Hierarchy
	var test_root := Node3D.new()
	add_child(test_root)
	
	var player_node := Node3D.new()
	test_root.add_child(player_node)
	player_node.global_position = Vector3.ZERO
	
	var power_node: Node = preload("res://power.gd").new()
	test_root.add_child(power_node)
	
	# Create a dummy PackedScene for crystal spawning
	var dummy_crystal := Node3D.new()
	var dummy_scene := PackedScene.new()
	dummy_scene.pack(dummy_crystal)
	dummy_crystal.free()
	
	# Instantiate Crystal Spawner
	var spawner_script = preload("res://crystal_spawn.gd")
	var spawner = Node3D.new()
	spawner.set_script(spawner_script)
	spawner.player = player_node
	spawner.power = power_node
	spawner.crystal_scene = dummy_scene
	test_root.add_child(spawner)
	
	power_node.start_run()
	
	# --- TEST 1: SPEED & REACTION TIME CURVE HELPER MATH ---
	print("--- 1. SPEED & REACTION TIME CURVES ---")
	var clamped_base_speed: float = spawner._get_clamped_speed()
	var base_reaction: float = spawner._get_reaction_time(clamped_base_speed)
	print("Base Speed (15 m/s) Clamped: ", clamped_base_speed, " (Expected: 15.0)")
	print("Base Reaction Time: ", base_reaction, "s (Expected: 3.0)")
	
	var mach1_reaction: float = spawner._get_reaction_time(spawner.max_speed)
	print("Mach 1 (343 m/s) Reaction Time: ", mach1_reaction, "s (Expected: 1.0)")
	print("------------------------------------\n")
	
	# --- TEST 2: INITIAL SPAWN TIMER CALCULATIONS ---
	print("--- 2. INITIAL SPAWN TIMER & COUNTDOWN ---")
	print("Is Waiting to Spawn: ", spawner._is_waiting_to_spawn, " (Expected: true)")
	print("Spawn Timer Armed (> 0s): ", spawner._spawn_timer > 0.0)
	
	# Fast-forward process to force spawn crystal
	var time_to_wait: float = spawner._spawn_timer + 0.1
	spawner._process(time_to_wait)
	
	var active_crystal: Node3D = spawner._active_crystal
	print("Active Crystal Spawned: ", is_instance_valid(active_crystal), " (Expected: true)")
	if is_instance_valid(active_crystal):
		print("Spawned Distance Ahead of Player: ", -active_crystal.global_position.z, " meters")
	print("------------------------------------\n")
	
	# --- TEST 3: CRYSTAL COLLECTION EVENT ---
	print("--- 3. CRYSTAL COLLECTION ---")
	spawner.on_crystal_collected()
	print("Active Crystal Freed on Collection: ", not is_instance_valid(spawner._active_crystal), " (Expected: true)")
	print("Is Waiting to Spawn Next Crystal: ", spawner._is_waiting_to_spawn, " (Expected: true)")
	print("------------------------------------\n")
	
	# --- TEST 4: CRYSTAL MISSED EVENT ---
	print("--- 4. CRYSTAL MISSED EVENT ---")
	# Force spawn a crystal
	spawner._process(spawner._spawn_timer + 0.1)
	var second_crystal: Node3D = spawner._active_crystal
	print("Second Crystal Spawned: ", is_instance_valid(second_crystal), " (Expected: true)")
	
	# Move crystal behind player (> 5 meters) to simulate passing
	if is_instance_valid(second_crystal):
		second_crystal.global_position = player_node.global_position + Vector3(0, 0, 6.0)
		spawner._process(0.1) # Triggers on_crystal_missed inside _process
		
	print("Active Crystal Freed After Passing Player: ", not is_instance_valid(spawner._active_crystal), " (Expected: true)")
	print("Is Waiting for Next Spawn: ", spawner._is_waiting_to_spawn, " (Expected: true)")
	print("------------------------------------\n")
	
	# --- TEST 5: INVINCIBILITY DELAY OFFSET ---
	print("--- 5. INVINCIBILITY SPAWN DELAY OFFSET ---")
	power_node.is_invincible = true
	power_node.invincibility_timer = 3.0
	
	spawner._calculate_and_start_spawn_timer()
	print("Spawn Timer Includes Invincibility (>= 3.0s): ", spawner._spawn_timer >= 3.0)
	print("====================================\n")
	
	# Clean up test hierarchy
	test_root.queue_free()
