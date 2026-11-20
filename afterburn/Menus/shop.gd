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


func _ready() -> void:
	refresh_shop_ui()


## Returns the Button node corresponding to a gadget ID.
func _get_button_for_gadget(gadget_id: String) -> Button:
	match gadget_id:
		"pulse_wave":
			return pulse_button
		"magnet":
			return mag_button
		"power_armor":
			return power_button
		"hoverboard":
			return hover_button
		"overdriven_rocket":
			return over_button
	return null


## Refreshes coin count and sets each gadget button to UNLOCKED, 1,000 (available), or LOCKED.
func refresh_shop_ui() -> void:
	if not get_node_or_null("/root/DatabaseManager"):
		return

	coin_label.text = "Coins: %s" % DatabaseManager.format_number(DatabaseManager.coins)
	var next_gadget: String = DatabaseManager.get_next_purchasable_gadget()
	var cost_text: String = DatabaseManager.format_number(DatabaseManager.GADGET_COST)

	for gadget_id in GADGET_IDS:
		var button: Button = _get_button_for_gadget(gadget_id)
		if not button:
			continue

		if DatabaseManager.is_gadget_unlocked(gadget_id):
			button.text = "UNLOCKED"
			button.disabled = true
		elif gadget_id == next_gadget:
			button.text = cost_text
			button.disabled = false
		else:
			button.text = "LOCKED"
			button.disabled = true


func get_item(item_index: int) -> void:
	if item_index < 0 or item_index >= GADGET_IDS.size():
		return

	var gadget_id: String = GADGET_IDS[item_index]
	var button: Button = _get_button_for_gadget(gadget_id)
	var result: String = DatabaseManager.purchase_gadget(gadget_id)

	if result == "UNLOCKED":
		bought.emit(gadget_id)
		refresh_shop_ui()
	elif result == "NOT_ENOUGH" and button:
		button.text = "NOT ENOUGH"
		button.disabled = true
		await get_tree().create_timer(1.5).timeout
		if is_inside_tree():
			refresh_shop_ui()
	else:
		refresh_shop_ui()
