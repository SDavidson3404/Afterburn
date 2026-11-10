extends CanvasLayer

@onready var respawn_button: Button = $Control/VBoxContainer/RespawnButton
@onready var menu_button: Button = $Control/VBoxContainer/MenuButton
@onready var stats_label: Label = $Control/VBoxContainer/StatsLabel if has_node("Control/VBoxContainer/StatsLabel") else null

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	hide()
	
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


## Displays the Game Over screen, populates run stats, and unhides mouse cursor
func show_game_over() -> void:
	_update_run_stats()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Fetches and formats statistics from DatabaseManager for the run that just ended
func _update_run_stats() -> void:
	_ensure_stats_label()
	if not stats_label:
		return

	if get_node_or_null("/root/DatabaseManager"):
		var total_dodges: int = DatabaseManager.jump_obstacle + DatabaseManager.slide_obstacle
		
		stats_label.text = (
			"FINAL SCORE: %s\n" % DatabaseManager.format_number(DatabaseManager.display_score()) +
			"Distance: %sm\n" % DatabaseManager.format_number(DatabaseManager.total_distance_meters) +
			"Crystals Collected: %s\n" % DatabaseManager.format_number(DatabaseManager.power_crystals) +
			"Obstacles Dodged: %s\n" % DatabaseManager.format_number(total_dodges) +
			"Gadgets Picked Up: %s" % DatabaseManager.format_number(DatabaseManager.gadgets)
		)
	else:
		stats_label.text = "Stats Unavailable"


## Ensures a StatsLabel node exists inside VBoxContainer
func _ensure_stats_label() -> void:
	if stats_label == null:
		stats_label = get_node_or_null("Control/VBoxContainer/StatsLabel")
		
	if stats_label == null and has_node("Control/VBoxContainer"):
		stats_label = Label.new()
		stats_label.name = "StatsLabel"
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 16)
		
		var vbox = $Control/VBoxContainer
		vbox.add_child(stats_label)
		vbox.move_child(stats_label, 0) # Place stats above the buttons


## Opens the gadget selection UI upon clicking RESPAWN
func _on_respawn_pressed() -> void:
	hide()
	get_tree().paused = false
	LoadoutUI.open_gadget_select_on_respawn = true
	get_tree().reload_current_scene()


## Reloads the scene and returns to the Main Menu
func _on_menu_pressed() -> void:
	hide()
	get_tree().paused = false
	LoadoutUI.open_gadget_select_on_respawn = false
	get_tree().reload_current_scene()
