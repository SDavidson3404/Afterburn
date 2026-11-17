extends CanvasLayer

signal bought(item: String)
@onready var pulse_button: Button = $Buttons/PulseButton
@onready var mag_button: Button = $Buttons/MagButton
@onready var power_button: Button = $Buttons/PowerButton
@onready var hover_button: Button = $Buttons/HoverButton
@onready var over_button: Button = $Buttons/OverButton
@onready var coin_label: Label = $PanelContainer/Labels/CoinLabel
enum GadgetType { PULSE_WAVE, MAGNET, POWER_ARMOR, HOVERBOARD, OVERDRIVEN_ROCKET }
var base_cost: int = 100

func _ready() -> void:
	coin_label.text = ("COIN COUNT: " + str(DatabaseManager.coins))
	for item in DatabaseManager.unlocked_gadgets:
		match item:
			"PULSE_WAVE":
				pulse_button.text = "UNLOCKED"
			"MAGNET":
				mag_button.text = "UNLOCKED"
			"power_armor":
				power_button.text = "UNLOCKED"
			"HOVERBOARD":
				hover_button.text = "UNLOCKED"
			"OVERDRIVEN_ROCKET":
				over_button.text = "UNLOCKED"

func get_item(item_index: int) -> void:
	var gadget: String = GadgetType.keys()[item_index]
	var button_text: String = "NOT ENOUGH"
	if DatabaseManager.coins >= base_cost * (item_index + 1):
		DatabaseManager.coins -= base_cost * (item_index + 1)
		coin_label.text = ("COIN COUNT: " + str(DatabaseManager.coins))
		DatabaseManager.unlocked_gadgets.append(gadget)
		button_text = "UNLOCKED"
		bought.emit(gadget)
	var button: Button
	match gadget:
		"PULSE_WAVE":
			button = pulse_button
		"MAGNET":
			button = mag_button
		"POWER_ARMOR":
			button = power_button
		"HOVERBOARD":
			button = hover_button
		"OVERDRIVEN_ROCKET":
			button = over_button
	button.text = button_text
	if button.text == "NOT ENOUGH":
		await get_tree().create_timer(1.5).timeout
		button.text = str(base_cost * (item_index + 1))
