extends Node2D

@onready var stats_label: Label = %StatsLabel
@onready var stats_panel: PanelContainer = %StatsPanel
@onready var leaderboard_panel: PanelContainer = $Leaderboard/LeaderboardPanel
@onready var setting_panel: PanelContainer = $Settings/SettingPanel
@onready var shop: CanvasLayer = $Shop
@onready var gadget_menu: OptionButton = $Settings/SettingPanel/VBoxContainer/GadgetMenu
@onready var res_label: Label = $Settings/SettingPanel/VBoxContainer/ResLabel
@onready var reset_button: Button = $Settings/SettingPanel/VBoxContainer/ResetButton

func _ready() -> void:
	res_label.text = ("Scale Factor: " + str(get_window().content_scale_factor) + "x")
	for item in DatabaseManager.unlocked_gadgets:
		_on_shop_bought(item)
	for item in gadget_menu.item_count:
		if gadget_menu.get_item_text(item) == DatabaseManager.chosen_starting_gadget:
			gadget_menu.select(item)

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
	if leaderboard_panel.visible:
		leaderboard_panel.hide()
	else:
		leaderboard_panel.show()

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
	match item:
		"PULSE_WAVE":
			gadget_menu.add_item("Pulse Wave", 1)
		"MAGNET":
			gadget_menu.add_item("Magnet", 2)
		"POWER_ARMOR":
			gadget_menu.add_item("Power Armor", 3)
		"HOVERBOARD":
			gadget_menu.add_item("Hoverboard", 4)
		"OVERDRIVEN_ROCKET":
			gadget_menu.add_item("Overdriven Rocket", 5)

func _on_gadget_menu_item_selected(index: int) -> void:
	DatabaseManager.chosen_starting_gadget = gadget_menu.get_item_text(index)

func _on_h_slider_value_changed(value: float) -> void:
	res_label.text = ("Scale Factor: " + str(value) + "x")
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
