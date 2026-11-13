## Main Menu and Loadout interface script.
## Handles main menu navigation (Start, Stats, Exit), gadget selection, lifetime stat displays, and mouse state transitions.
class_name LoadoutUI
extends Control

## Static variable preserving the last selected gadget index across respawns
static var last_selected_gadget_index: int = 0

@export_category("Node References")
## Reference to the main power manager node responsible for tracking run state.
@export var power_node: Node

# Panel Containers
@onready var gadget_panel: PanelContainer = %GadgetPanel

# Gadget Selection Controls
@onready var gadget_option: OptionButton = %GadgetOption
@onready var confirm_start_button: Button = %ConfirmStartButton

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
	if gadget_option:
		gadget_option.focus_mode = Control.FOCUS_NONE

	# Populate gadget options
	gadget_option.clear()
	for i in range(GADGET_OPTIONS.size()):
		gadget_option.add_item(GADGET_OPTIONS[i]["name"], i)

	# Restore previous selection index if available
	if last_selected_gadget_index >= 0 and last_selected_gadget_index < GADGET_OPTIONS.size():
		gadget_option.selected = last_selected_gadget_index

	gadget_panel.show()

func _on_exit_menu_button_pressed() -> void:
	get_tree().quit()

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
