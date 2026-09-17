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
	DatabaseManager.add_distance(3200.0)         # 32 meters, 100 travel points
	DatabaseManager.add_dodge("jump")            # 1 jump dodge (+10 pts)
	DatabaseManager.add_dodge("slide")           # 1 slide dodge (+10 pts)
	DatabaseManager.add_dodge("dash")            # 1 dash dodge (+10 pts)
	DatabaseManager.add_crystal()                # 1 crystal (+100 pts)
	DatabaseManager.add_crystal()                # 2 crystals (+100 pts)
	DatabaseManager.add_gadget()                 # 1 gadget
	DatabaseManager.player_crash("robot")       # 1 robot crash
	DatabaseManager.player_crash("scaffolding") # 1 scaffolding crash
	DatabaseManager.player_crash("drone")       # 1 drone crash

	print("Current Calculated Score (Expected 330): ", DatabaseManager.display_score())

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
	DatabaseManager.add_distance(6400.0)   # 64 meters, 200 travel points
	DatabaseManager.add_dodge("jump")      # 1 dodge (+10 pts)
	DatabaseManager.add_crystal()          # 1 crystal (+100 pts)
	DatabaseManager.add_gadget()           # 1 gadget
	DatabaseManager.add_gadget()           # 2 gadgets
	DatabaseManager.player_crash("robot") # 1 robot crash

	print("Run 2 Calculated Score (Expected 310): ", DatabaseManager.display_score())
	var run2_data: Dictionary = DatabaseManager.save_run()
	print("Data Saved for Run 2: ", run2_data)
	DatabaseManager.reset_run_stats()
	print("------------------------------------\n")

	# 7. Check final lifetime accumulation totals
	print("--- 5. FINAL LIFETIME STATS (2 TOTAL RUNS) ---")
	print("Lifetime Stats: ", DatabaseManager.lifetime_stats())
	print("====================================")
