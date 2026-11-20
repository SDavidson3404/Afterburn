extends Node2D

@onready var stats_label: Label = %StatsLabel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var leaderboard_panel: PanelContainer = $Leaderboard/LeaderboardPanel
@onready var setting_panel: PanelContainer = $Settings/SettingPanel
@onready var shop: CanvasLayer = $Shop
@onready var gadget_menu: OptionButton = $Settings/SettingPanel/VBoxContainer/GadgetMenu
@onready var scores_label: RichTextLabel = $Leaderboard/LeaderboardPanel/VBoxContainer/Scores
@onready var res_label: Label = $Settings/SettingPanel/VBoxContainer/ResLabel
@onready var reset_button: Button = $Settings/SettingPanel/VBoxContainer/ResetButton
@onready var h_slider: HSlider = $Settings/SettingPanel/VBoxContainer/HSlider

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
	if h_slider:
		h_slider.value = get_window().content_scale_factor
	if res_label:
		res_label.text = "UI Scale: " + str(get_window().content_scale_factor) + "x"

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
	get_tree().change_scene_to_file("res://Core Files/Level.tscn")

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
		if shop.has_method("refresh_shop_ui"):
			shop.refresh_shop_ui()
		shop.show()

func _on_shop_bought(item: String) -> void:
	var display_name: String = ""
	var item_id: int = 0
	match item.to_lower():
		"pulse_wave":
			display_name = "Pulse Wave"
			item_id = 1
		"magnet":
			display_name = "Magnet"
			item_id = 2
		"power_armor":
			display_name = "Power Armor"
			item_id = 3
		"hoverboard":
			display_name = "Hoverboard"
			item_id = 4
		"overdriven_rocket":
			display_name = "Overdriven Rocket"
			item_id = 5

	if display_name.is_empty():
		return

	# Prevent duplicate entries in GadgetMenu
	for i in range(gadget_menu.item_count):
		if gadget_menu.get_item_text(i) == display_name:
			return

	gadget_menu.add_item(display_name, item_id)


func _on_gadget_menu_item_selected(index: int) -> void:
	var selected_text: String = gadget_menu.get_item_text(index)
	DatabaseManager.chosen_starting_gadget = DISPLAY_TO_ID.get(selected_text, "None")
	DatabaseManager.save_wallet()

func _on_h_slider_value_changed(value: float) -> void:
	if res_label:
		res_label.text = "UI Scale: " + str(value) + "x"
	get_window().content_scale_factor = value

func _on_reset_button_pressed() -> void:
	if reset_button.text == "ARE YOU SURE?!":
		reset_progress()
	else:
		reset_button.text = "ARE YOU SURE?!"
		await get_tree().create_timer(3).timeout
		reset_button.text = "CLICK HERE TO RESET"

func reset_progress() -> void:
	print("INSERT METHOD HERE")
