extends Node2D

@onready var stats_label: Label = %StatsLabel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var leaderboard_panel: PanelContainer = $Leaderboard/LeaderboardPanel
@onready var setting_panel: PanelContainer = $Settings/SettingPanel

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_stats_pressed() -> void:
	_update_lifetime_stats_display()
	if stats_panel.visible:
		stats_panel.hide()
	else:
		stats_panel.show()

func _update_lifetime_stats_display() -> void:
	if not stats_label:
		return

	if get_node_or_null("/root/Core Files/DatabaseManager"):
		var stats: Dictionary = DatabaseManager.lifetime_stats()
		if stats.is_empty():
			stats_label.text = "No lifetime stats found."
			return

		stats_label.text = (
			"Total Runs: %s\n" % DatabaseManager.format_number(stats.get("total_runs", 0)) +
			"High Score: %s\n" % DatabaseManager.format_number(stats.get("high_score", 0)) +
			"Lifetime Score: %s\n" % DatabaseManager.format_number(stats.get("total_lifetime_score", 0)) +
			"Max Distance: %sm\n" % DatabaseManager.format_number(stats.get("max_distance", 0)) +
			"Total Distance: %sm\n" % DatabaseManager.format_number(stats.get("total_distance", 0)) +
			"Max Crystals: %s\n" % DatabaseManager.format_number(stats.get("max_crystals", 0)) +
			"Total Crystals: %s\n" % DatabaseManager.format_number(stats.get("total_crystals", 0)) +
			"Max Dodges: %s\n" % DatabaseManager.format_number(stats.get("max_dodges", 0)) +
			"Total Dodges: %s\n" % DatabaseManager.format_number(stats.get("total_dodges", 0)) +
			"Gadgets Collected: %s" % DatabaseManager.format_number(stats.get("total_gadgets", 0))
		)
	else:
		stats_label.text = "Database not connected."

func _on_start_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Core Files/testing_ground.tscn")

func _on_leaderboard_pressed() -> void:
	if leaderboard_panel.visible:
		leaderboard_panel.hide()
	else:
		leaderboard_panel.show()

func _on_settings_pressed() -> void:
	if setting_panel.visible:
		setting_panel.hide()
	else:
		setting_panel.show()
