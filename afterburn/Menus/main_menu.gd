extends Node2D

@onready var stats_label: Label = %StatsLabel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var leaderboard_panel: PanelContainer = $Leaderboard/LeaderboardPanel
@onready var setting_panel: PanelContainer = $Settings/SettingPanel
@onready var shop: CanvasLayer = $Shop
@onready var gadget_menu: OptionButton = $Settings/SettingPanel/VBoxContainer/GadgetMenu
@onready var scores_label: RichTextLabel = $Leaderboard/LeaderboardPanel/VBoxContainer/Scores

const PLACE_NAMES: Array[String] = [
	"1st Place:",
	"2nd Place:",
	"3rd Place:",
	"4th Place:",
	"5th Place:",
	"6th Place:",
	"7th Place:",
	"8th Place:",
	"9th Place:",
	"10th Place:"
]

const DISPLAY_TO_ID: Dictionary = {
	"None": "None",
	"Pulse Wave": "pulse_wave",
	"Magnet": "magnet",
	"Power Armor": "power_armor",
	"Hoverboard": "hoverboard",
	"Overdriven Rocket": "overdriven_rocket"
}


func _ready() -> void:
	res_label.text = ("Scale Factor: " + str(get_window().content_scale_factor) + "x")
	for item in DatabaseManager.unlocked_gadgets:
		_on_shop_bought(item)
	for i in range(gadget_menu.item_count):
		var item_text: String = gadget_menu.get_item_text(i)
		if DISPLAY_TO_ID.get(item_text, "None") == DatabaseManager.chosen_starting_gadget or item_text == DatabaseManager.chosen_starting_gadget:
			gadget_menu.select(i)

	_update_leaderboard_display()


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

	if get_node_or_null("/root/DatabaseManager"):
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
	_update_leaderboard_display()
	if leaderboard_panel.visible:
		leaderboard_panel.hide()
	else:
		leaderboard_panel.show()


## Populates the Top 10 leaderboard RichTextLabel with player names, scores, and gadget-colored dashes.
func _update_leaderboard_display() -> void:
	if not scores_label:
		return

	var entries: Array = []
	if get_node_or_null("/root/DatabaseManager"):
		entries = DatabaseManager.get_top_leaderboard(10)

	var lines: PackedStringArray = []
	for i in range(10):
		var place_title: String = PLACE_NAMES[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			var raw_name: String = str(entry.get("player_name", "PLAYER")).replace("[", "(").replace("]", ")")
			var score_str: String = DatabaseManager.format_number(int(entry.get("score", 0)))
			var gadget_key: String = str(entry.get("starting_gadget", "None"))
			var colored_dash: String = DatabaseManager.get_gadget_dash_bbcode(gadget_key)
			
			lines.append("%s %s%s (%s)" % [place_title, colored_dash, raw_name, score_str])
		else:
			lines.append("%s ---" % place_title)

	scores_label.text = "\n".join(lines)


func _on_settings_pressed() -> void:
	if setting_panel.visible:
		setting_panel.hide()
	else:
		setting_panel.show()


func _on_shop_pressed() -> void:
	if shop.visible:
		shop.hide()
	else:
		shop.show()


func _on_shop_bought(item: String) -> void:
	match item.to_lower():
		"pulse_wave":
			gadget_menu.add_item("Pulse Wave", 1)
		"magnet":
			gadget_menu.add_item("Magnet", 2)
		"power_armor":
			gadget_menu.add_item("Power Armor", 3)
		"hoverboard":
			gadget_menu.add_item("Hoverboard", 4)
		"overdriven_rocket":
			gadget_menu.add_item("Overdriven Rocket", 5)


func _on_gadget_menu_item_selected(index: int) -> void:
	DatabaseManager.chosen_starting_gadget = gadget_menu.get_item_text(index)

func _on_h_slider_value_changed(value: float) -> void:
	res_label.text = ("Scale Factor: " + str(value) + "x")
	get_window().content_scale_factor = value
