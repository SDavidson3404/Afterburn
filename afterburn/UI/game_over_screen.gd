extends CanvasLayer

## Maximum characters allowed for leaderboard name entry.
@export var max_name_length: int = 16

@onready var respawn_button: Button = $Control/VBoxContainer/RespawnButton
@onready var menu_button: Button = $Control/VBoxContainer/MenuButton
@onready var stats_label: Label = $Control/VBoxContainer/StatsLabel if has_node("Control/VBoxContainer/StatsLabel") else null

# Dynamically ensured UI nodes for Top 10 Leaderboard name entry
var name_entry_box: VBoxContainer = null
var prompt_label: Label = null
var name_input: LineEdit = null
var submit_button: Button = null

var _pending_score: int = 0
var _score_submitted: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	hide()
	_ensure_name_entry_ui()
	
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)


## Displays the Game Over screen, populates run stats, and prompts for a name if Top 10 is reached.
func show_game_over() -> void:
	_score_submitted = false
	_update_run_stats()
	_check_and_prompt_leaderboard()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Fetches and formats statistics from DatabaseManager for the run that just ended.
func _update_run_stats() -> void:
	_ensure_stats_label()
	if not stats_label:
		return

	if get_node_or_null("/root/DatabaseManager"):
		var total_dodges: int = DatabaseManager.jump_obstacle + DatabaseManager.slide_obstacle
		_pending_score = DatabaseManager.display_score()
		
		stats_label.text = (
			"FINAL SCORE: %s\n" % DatabaseManager.format_number(_pending_score) +
			"Distance: %sm\n" % DatabaseManager.format_number(DatabaseManager.total_distance_meters) +
			"Crystals Collected: %s\n" % DatabaseManager.format_number(DatabaseManager.power_crystals) +
			"Obstacles Dodged: %s\n" % DatabaseManager.format_number(total_dodges) +
			"Gadgets Picked Up: %s\n" % DatabaseManager.format_number(DatabaseManager.gadgets)
		)
	else:
		_pending_score = 0
		stats_label.text = "Stats Unavailable"


## Checks if the final score is in the Top 10 and toggles the name entry prompt accordingly.
func _check_and_prompt_leaderboard() -> void:
	_ensure_name_entry_ui()
	if not get_node_or_null("/root/DatabaseManager"):
		if name_entry_box:
			name_entry_box.hide()
		return

	if DatabaseManager.is_top_10_score(_pending_score):
		name_entry_box.show()
		prompt_label.text = "NEW TOP 10 SCORE! ENTER NAME:"
		name_input.text = ""
		name_input.editable = true
		submit_button.disabled = false
		submit_button.show()
		
		# Hide navigation buttons until the player submits their leaderboard name
		if respawn_button:
			respawn_button.hide()
		if menu_button:
			menu_button.hide()
			
		name_input.call_deferred("grab_focus")
	else:
		name_entry_box.hide()
		if respawn_button:
			respawn_button.show()
		if menu_button:
			menu_button.show()


## Ensures a StatsLabel node exists inside VBoxContainer.
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
		vbox.move_child(stats_label, 0)


## Dynamically constructs the arcade Name Entry UI inside VBoxContainer if not already present.
func _ensure_name_entry_ui() -> void:
	if name_entry_box != null or not has_node("Control/VBoxContainer"):
		return

	var vbox: VBoxContainer = $Control/VBoxContainer
	name_entry_box = vbox.get_node_or_null("NameEntryBox") as VBoxContainer
	if name_entry_box:
		prompt_label = name_entry_box.get_node_or_null("PromptLabel")
		name_input = name_entry_box.get_node_or_null("NameInput")
		submit_button = name_entry_box.get_node_or_null("SubmitButton")
		return

	name_entry_box = VBoxContainer.new()
	name_entry_box.name = "NameEntryBox"
	name_entry_box.add_theme_constant_override("separation", 8)

	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "NEW TOP 10 SCORE! ENTER NAME:"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	name_entry_box.add_child(prompt_label)

	name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "Enter Name..."
	name_input.max_length = max_name_length
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.custom_minimum_size = Vector2(240, 38)
	name_input.add_theme_font_size_override("font_size", 18)
	name_input.text_submitted.connect(_on_name_text_submitted)
	name_entry_box.add_child(name_input)

	submit_button = Button.new()
	submit_button.name = "SubmitButton"
	submit_button.text = "SUBMIT SCORE"
	submit_button.custom_minimum_size = Vector2(0, 40)
	submit_button.add_theme_font_size_override("font_size", 18)
	submit_button.pressed.connect(_on_submit_name_pressed)
	name_entry_box.add_child(submit_button)

	vbox.add_child(name_entry_box)
	# Position right below StatsLabel and above Respawn/Menu buttons
	vbox.move_child(name_entry_box, 1)
	name_entry_box.hide()


func _on_name_text_submitted(_submitted_text: String) -> void:
	_submit_leaderboard_score()


func _on_submit_name_pressed() -> void:
	_submit_leaderboard_score()


## Saves the player's name, score, and starting gadget to the Top 10 leaderboard.
func _submit_leaderboard_score() -> void:
	if _score_submitted:
		return
	_score_submitted = true

	var entered_name: String = name_input.text.strip_edges() if name_input else "PLAYER"
	if entered_name.is_empty():
		entered_name = "PLAYER"

	if get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.add_leaderboard_entry(
			entered_name,
			_pending_score,
			DatabaseManager.chosen_starting_gadget
		)

	if prompt_label:
		prompt_label.text = "SCORE SAVED TO LEADERBOARD!"
	if name_input:
		name_input.editable = false
	if submit_button:
		submit_button.hide()

	if respawn_button:
		respawn_button.show()
	if menu_button:
		menu_button.show()


## Reloads the level and opens the gadget selection UI upon clicking RESPAWN.
func _on_respawn_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().reload_current_scene()


## Returns to the Main Menu scene upon clicking MAIN MENU.
func _on_menu_pressed() -> void:
	hide()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")
