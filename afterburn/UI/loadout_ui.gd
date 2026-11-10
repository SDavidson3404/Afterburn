## Main Menu and Loadout interface script.
## Handles main menu navigation (Start, Stats, Exit), gadget selection, lifetime stat displays, and mouse state transitions.
class_name LoadoutUI
extends Control

## Static flag causing scene reloads from respawns to open the gadget selection screen directly
static var open_gadget_select_on_respawn: bool = false

## Static variable preserving the last selected gadget index across respawns
static var last_selected_gadget_index: int = 0

@export_category("Node References")
## Reference to the main power manager node responsible for tracking run state.
@export var power_node: Node

# Panel Containers
@onready var main_menu_panel: PanelContainer = %MainMenuPanel
@onready var gadget_panel: PanelContainer = %GadgetPanel
@onready var stats_panel: PanelContainer = %StatsPanel

# Main Menu Buttons
@onready var start_menu_button: Button = %StartMenuButton
@onready var stats_menu_button: Button = %StatsMenuButton
@onready var exit_menu_button: Button = %ExitMenuButton

# Gadget Selection Controls
@onready var gadget_option: OptionButton = %GadgetOption
@onready var confirm_start_button: Button = %ConfirmStartButton
@onready var back_from_gadget_button: Button = %BackFromGadgetButton

# Lifetime Stats Controls
@onready var stats_label: Label = %StatsLabel
@onready var back_from_stats_button: Button = %BackFromStatsButton

## Registry mapping display names to GadgetBase string IDs.
const GADGET_OPTIONS: Array[Dictionary] = [
	{"name": "None (Standard Run)", "id": ""},
	{"name": "Pulse Wave", "id": "pulse_wave"},
	{"name": "Magnet", "id": "magnet"},
	{"name": "Power Armor", "id": "power_armor"},
	{"name": "Hoverboard", "id": "hoverboard"},
	{"name": "Overdriven Rocket", "id": "overdriven_rocket"}
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("CanvasLayer"):
		$CanvasLayer.show()
	show()

	# Remove focus traps on UI elements
	for element in [start_menu_button, stats_menu_button, exit_menu_button, confirm_start_button, back_from_gadget_button, back_from_stats_button, gadget_option]:
		if element:
			element.focus_mode = Control.FOCUS_NONE

	# Populate gadget options
	gadget_option.clear()
	for i in range(GADGET_OPTIONS.size()):
		gadget_option.add_item(GADGET_OPTIONS[i]["name"], i)

	# Restore previous selection index if available
	if last_selected_gadget_index >= 0 and last_selected_gadget_index < GADGET_OPTIONS.size():
		gadget_option.selected = last_selected_gadget_index

	# Connect signal listeners
	start_menu_button.pressed.connect(_on_start_menu_button_pressed)
	stats_menu_button.pressed.connect(_on_stats_menu_button_pressed)
	exit_menu_button.pressed.connect(_on_exit_menu_button_pressed)
	confirm_start_button.pressed.connect(_on_confirm_start_button_pressed)
	back_from_gadget_button.pressed.connect(_show_main_menu)
	back_from_stats_button.pressed.connect(_show_main_menu)

	if open_gadget_select_on_respawn:
		open_gadget_select_on_respawn = false
		_show_gadget_selection()
	else:
		_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ESC"):
		if gadget_panel.visible or stats_panel.visible:
			_show_main_menu()
			get_viewport().set_input_as_handled()


func _show_main_menu() -> void:
	main_menu_panel.show()
	gadget_panel.hide()
	stats_panel.hide()


func _show_gadget_selection() -> void:
	main_menu_panel.hide()
	gadget_panel.show()
	stats_panel.hide()


func _on_start_menu_button_pressed() -> void:
	_show_gadget_selection()


func _on_stats_menu_button_pressed() -> void:
	_update_lifetime_stats_display()
	main_menu_panel.hide()
	gadget_panel.hide()
	stats_panel.show()


func _on_exit_menu_button_pressed() -> void:
	get_tree().quit()


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


func _on_confirm_start_button_pressed() -> void:
	if not power_node:
		return

	# Free old gadget instance to prevent memory leaks
	if power_node.selected_gadget:
		power_node.selected_gadget.queue_free()
		power_node.selected_gadget = null

	var selected_idx: int = gadget_option.selected
	last_selected_gadget_index = selected_idx

	if selected_idx >= 0 and selected_idx < GADGET_OPTIONS.size():
		var gadget_id: String = GADGET_OPTIONS[selected_idx]["id"]
		if not gadget_id.is_empty():
			var gadget_instance: GadgetBase = GadgetBase.create_by_id(gadget_id)
			if gadget_instance:
				power_node.add_child(gadget_instance)
				power_node.selected_gadget = gadget_instance

	# Capture mouse and start run
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if has_node("CanvasLayer"):
		$CanvasLayer.hide()
	hide()
	power_node.start_run()
