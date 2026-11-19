## Pre-run Loadout interface script.
## Displays only unlocked gadgets (plus Standard Run) and initializes the player's equipped gadget.
class_name LoadoutUI
extends Control

@export_category("Node References")
## Reference to the main power manager node responsible for tracking run state.
@export var power_node: Node

# Panel Containers
@onready var gadget_panel: PanelContainer = %GadgetPanel

# Gadget Selection Controls
@onready var gadget_option: OptionButton = %GadgetOption
@onready var confirm_start_button: Button = %ConfirmStartButton

## Master registry mapping display names to GadgetBase string IDs.
const GADGET_OPTIONS: Array[Dictionary] = [
	{"name": "None (Standard Run)", "id": "None"},
	{"name": "Pulse Wave", "id": "pulse_wave"},
	{"name": "Magnet", "id": "magnet"},
	{"name": "Power Armor", "id": "power_armor"},
	{"name": "Hoverboard", "id": "hoverboard"},
	{"name": "Overdriven Rocket", "id": "overdriven_rocket"}
]

## Filtered options currently shown in the OptionButton (None + unlocked gadgets).
var _available_options: Array[Dictionary] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("CanvasLayer"):
		$CanvasLayer.show()
	show()

	# Remove focus traps on UI elements
	if gadget_option:
		gadget_option.focus_mode = Control.FOCUS_NONE

	# Populate dropdown with Standard Run + permanently unlocked gadgets only
	_available_options.clear()
	gadget_option.clear()

	var db_mgr = get_node_or_null("/root/DatabaseManager")
	for opt in GADGET_OPTIONS:
		var gid: String = opt["id"]
		if gid == "None" or (db_mgr and db_mgr.is_gadget_unlocked(gid)):
			_available_options.append(opt)
			gadget_option.add_item(opt["name"], _available_options.size() - 1)

	# Select the gadget chosen in Main Menu Settings or used in the last run
	var target_id: String = db_mgr.chosen_starting_gadget if db_mgr else "None"
	gadget_option.selected = 0
	for i in range(_available_options.size()):
		if _available_options[i]["id"] == target_id:
			gadget_option.selected = i
			break

	gadget_panel.show()


func _on_exit_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Menus/main_menu.tscn")


func _on_confirm_start_button_pressed() -> void:
	if not power_node:
		return

	# Free old gadget instance to prevent memory leaks
	if power_node.selected_gadget:
		power_node.selected_gadget.queue_free()
		power_node.selected_gadget = null

	var selected_idx: int = gadget_option.selected
	if selected_idx >= 0 and selected_idx < _available_options.size():
		var gadget_id: String = _available_options[selected_idx]["id"]
		if gadget_id != "None":
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
