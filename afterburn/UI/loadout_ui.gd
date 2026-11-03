## Loadout menu interface script.
## Handles pre-run gadget selection, dynamic UI population, memory cleanup, and seamless mouse input state transitions.
extends Control

@export_category("Node References")
## Reference to the main power manager node responsible for tracking run state.
@export var power_node: Node

## Onready reference to the gadget dropdown selector menu.
@onready var gadget_option: OptionButton = %GadgetOption

## Onready reference to the run start confirmation button.
@onready var start_button: Button = %StartButton

## Registry array of dictionaries mapping display names to GadgetBase string IDs.
const GADGET_OPTIONS: Array[Dictionary] = [
	{"name": "None (Standard Run)", "id": ""},
	{"name": "Pulse Wave", "id": "pulse_wave"},
	{"name": "Magnet", "id": "magnet"},
	{"name": "Power Armor", "id": "power_armor"},
	{"name": "Hoverboard", "id": "hoverboard"},
	{"name": "Overdriven Rocket", "id": "overdriven_rocket"}
]


func _ready() -> void:
	# Enable visible mouse cursor for menu interaction
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if has_node("CanvasLayer"):
		$CanvasLayer.show()
	show()

	# Configure element dimensions and disable keyboard focus traps
	gadget_option.custom_minimum_size = Vector2(250, 40)
	start_button.custom_minimum_size = Vector2(250, 40)
	start_button.focus_mode = Control.FOCUS_NONE
	gadget_option.focus_mode = Control.FOCUS_NONE

	# Populate OptionButton menu items dynamically from registry dictionary
	gadget_option.clear()
	for i in range(GADGET_OPTIONS.size()):
		gadget_option.add_item(GADGET_OPTIONS[i]["name"], i)

	start_button.pressed.connect(_on_start_button_pressed)


## Confirms loadout selection, instantiates gadget via factory, and begins the run.
func _on_start_button_pressed() -> void:
	start_button.release_focus()
	if not power_node:
		return

	# Clean up previous gadget instance to prevent memory leaks across consecutive runs
	if power_node.selected_gadget:
		power_node.selected_gadget.queue_free()
		power_node.selected_gadget = null

	# Lookup selected gadget ID from OptionButton dropdown state
	var selected_idx: int = gadget_option.get_selected_id()
	var gadget_id: String = GADGET_OPTIONS[selected_idx]["id"]
	
	# Instantiate gadget using the GadgetBase factory method if selected
	if not gadget_id.is_empty():
		var gadget_instance: GadgetBase = GadgetBase.create_by_id(gadget_id)
		if gadget_instance:
			power_node.add_child(gadget_instance)
			power_node.selected_gadget = gadget_instance

	# Capture mouse cursor for gameplay controls, hide UI overlay, and start run
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if has_node("CanvasLayer"):
		$CanvasLayer.hide()
	hide()
	power_node.start_run()
