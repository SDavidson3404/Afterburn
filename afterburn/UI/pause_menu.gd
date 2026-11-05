## Pause Menu manager handling game pause, 1-second millisecond countdown resume, exit confirmation, and run state saving on exit.
extends CanvasLayer

@export_category("Node References")
## Reference to the main power manager node tracking run state.
@export var power_node: Node

## Reference to the main LoadoutUI control node.
@export var loadout_ui: Control

@onready var pause_panel: PanelContainer = $Control/PausePanel
@onready var resume_button: Button = $Control/PausePanel/VBoxContainer/ResumeButton
@onready var exit_button: Button = $Control/PausePanel/VBoxContainer/ExitButton
@onready var countdown_label: Label = $Control/CountdownLabel

# Confirmation panel controls
var confirm_panel: PanelContainer
var yes_button: Button
var no_button: Button

var is_counting_down: bool = false
var countdown_time: float = 1.0


func _ready() -> void:
	# Ensure PauseMenu continues updating input and countdown when get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_ensure_confirm_panel_exists()

	if resume_button:
		resume_button.pressed.connect(_on_exit_pressed_show_confirm)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed_show_confirm)
	if yes_button:
		yes_button.pressed.connect(_on_confirm_yes_pressed)
	if no_button:
		no_button.pressed.connect(_on_confirm_no_pressed)
		
	# Fix connect for resume button
	if resume_button and resume_button.pressed.is_connected(_on_exit_pressed_show_confirm):
		resume_button.pressed.disconnect(_on_exit_pressed_show_confirm)
		resume_button.pressed.connect(_on_resume_pressed)
		
	hide_all()


## Dynamically finds or programmatically constructs the "Are you Sure?" confirmation panel.
func _ensure_confirm_panel_exists() -> void:
	confirm_panel = get_node_or_null("Control/ConfirmPanel") as PanelContainer
	if not confirm_panel:
		confirm_panel = PanelContainer.new()
		confirm_panel.name = "ConfirmPanel"
		confirm_panel.layout_mode = 1
		confirm_panel.anchors_preset = Control.PRESET_CENTER
		confirm_panel.anchor_left = 0.5
		confirm_panel.anchor_top = 0.5
		confirm_panel.anchor_right = 0.5
		confirm_panel.anchor_bottom = 0.5
		confirm_panel.offset_left = -140.0
		confirm_panel.offset_top = -80.0
		confirm_panel.offset_right = 140.0
		confirm_panel.offset_bottom = 80.0
		confirm_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		confirm_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		var vbox := VBoxContainer.new()
		vbox.custom_minimum_size = Vector2(260, 140)
		confirm_panel.add_child(vbox)
		
		var title_label := Label.new()
		title_label.text = "Are you Sure?"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 24)
		vbox.add_child(title_label)
		
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		vbox.add_child(spacer)
		
		var hbox := HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		vbox.add_child(hbox)
		
		yes_button = Button.new()
		yes_button.name = "YesButton"
		yes_button.text = "YES"
		yes_button.custom_minimum_size = Vector2(100, 45)
		yes_button.add_theme_font_size_override("font_size", 18)
		hbox.add_child(yes_button)
		
		no_button = Button.new()
		no_button.name = "NoButton"
		no_button.text = "NO"
		no_button.custom_minimum_size = Vector2(100, 45)
		no_button.add_theme_font_size_override("font_size", 18)
		hbox.add_child(no_button)
		
		$Control.add_child(confirm_panel)
	else:
		yes_button = confirm_panel.get_node_or_null("VBoxContainer/HBoxContainer/YesButton")
		no_button = confirm_panel.get_node_or_null("VBoxContainer/HBoxContainer/NoButton")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		if power_node and power_node.get("is_run_active"):
			if get_tree().paused:
				if confirm_panel and confirm_panel.visible:
					_show_pause_panel()
				elif not is_counting_down:
					_start_resume_countdown()
			else:
				pause_game()


## Pauses the engine process tree and displays the main pause menu.
func pause_game() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	is_counting_down = false
	show()
	_show_pause_panel()


func _show_pause_panel() -> void:
	pause_panel.show()
	if confirm_panel:
		confirm_panel.hide()
	countdown_label.hide()


func _show_confirm_panel() -> void:
	pause_panel.hide()
	if confirm_panel:
		confirm_panel.show()
	countdown_label.hide()


## Hides all pause menu elements.
func hide_all() -> void:
	pause_panel.hide()
	if confirm_panel:
		confirm_panel.hide()
	countdown_label.hide()
	hide()


func _on_resume_pressed() -> void:
	_start_resume_countdown()


## Shows the "Are you Sure?" confirmation screen when "Exit to Menu" is clicked.
func _on_exit_pressed_show_confirm() -> void:
	_show_confirm_panel()


## Reverts back to the main pause menu options when "NO" is clicked.
func _on_confirm_no_pressed() -> void:
	_show_pause_panel()


## Terminates the active run and returns to the main menu when "YES" is clicked.
func _on_confirm_yes_pressed() -> void:
	is_counting_down = false
	get_tree().paused = false
	hide_all()

	# Call power manager end_run() to persist telemetry and terminate run state
	if power_node and power_node.has_method("end_run"):
		power_node.end_run()
	elif get_node_or_null("/root/DatabaseManager"):
		DatabaseManager.save_run()
		DatabaseManager.reset_run_stats()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Reload scene to reset world position, procedural track generator, and display Main Menu
	get_tree().reload_current_scene()


## Hides menu controls and starts the 1-second millisecond countdown.
func _start_resume_countdown() -> void:
	pause_panel.hide()
	if confirm_panel:
		confirm_panel.hide()
	countdown_label.show()
	countdown_time = 1.0
	is_counting_down = true
	_update_countdown_label()


func _process(delta: float) -> void:
	if is_counting_down:
		countdown_time -= delta
		if countdown_time <= 0.0:
			countdown_time = 0.0
			_update_countdown_label()
			_finish_resume()
		else:
			_update_countdown_label()


## Formats current remaining countdown time in milliseconds.
func _update_countdown_label() -> void:
	var msec: int = int(round(countdown_time * 1000.0))
	countdown_label.text = str(msec) + " ms"


## Unpauses game state and restores mouse capture.
func _finish_resume() -> void:
	is_counting_down = false
	hide_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
