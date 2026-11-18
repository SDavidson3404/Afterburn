extends CanvasLayer

signal bought(item: String)
@onready var pulse_button: Button = $Buttons/PulseButton
@onready var mag_button: Button = $Buttons/MagButton
@onready var power_button: Button = $Buttons/PowerButton
@onready var hover_button: Button = $Buttons/HoverButton
@onready var over_button: Button = $Buttons/OverButton
@onready var coin_label: Label = $PanelContainer/Labels/CoinLabel

const GADGET_IDS: Array[String] = [
	"pulse_wave",
	"magnet",
	"power_armor",
	"hoverboard",
	"overdriven_rocket"
]
var base_cost: int = 100

func _ready() -> void:
	coin_label.text = ("COIN COUNT: " + str(DatabaseManager.coins))
	for item in DatabaseManager.unlocked_gadgets:
		match item:
			"pulse_wave":
				pulse_button.text = "UNLOCKED"
			"magnet":
				mag_button.text = "UNLOCKED"
			"power_armor":
				power_button.text = "UNLOCKED"
			"hoverboard":
				hover_button.text = "UNLOCKED"
			"overdriven_rocket":
				over_button.text = "UNLOCKED"

func get_item(item_index: int) -> void:
	var gadget: String = GADGET_IDS[item_index]
	var button_text: String = "NOT ENOUGH"
	if DatabaseManager.coins >= base_cost * (item_index + 1):
		DatabaseManager.coins -= base_cost * (item_index + 1)
		coin_label.text = ("COIN COUNT: " + str(DatabaseManager.coins))
		if not DatabaseManager.unlocked_gadgets.has(gadget):
			DatabaseManager.unlocked_gadgets.append(gadget)
		button_text = "UNLOCKED"
		bought.emit(gadget)
	var button: Button
	match gadget:
		"pulse_wave":
			button = pulse_button
		"magnet":
			button = mag_button
		"power_armor":
			button = power_button
		"hoverboard":
			button = hover_button
		"overdriven_rocket":
			button = over_button
	button.text = button_text
	if button.text == "NOT ENOUGH":
		await get_tree().create_timer(1.5).timeout
		button.text = str(base_cost * (item_index + 1))
