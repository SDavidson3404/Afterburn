extends Node

func _ready() -> void:
	print("====================================")
	print("--- TESTING DATABASE MANAGER ---")
	
	# 1. Simulate gameplay actions
	DatabaseManager.add_distance(320.0) # Adds travel score
	DatabaseManager.add_dodge("jump")    # Adds dodge score
	DatabaseManager.add_crystal()        # Adds crystal score
	
	print("Current Calculated Score: ", DatabaseManager.display_score())
	
	# 2. Save to SQLite database
	var run_data: Dictionary = DatabaseManager.save_run()
	print("Data Saved to SQLite: ", run_data)
	
	# 3. Reset stats for next run
	DatabaseManager.reset_run_stats()
	print("Score After Reset: ", DatabaseManager.display_score())
	print("====================================")
