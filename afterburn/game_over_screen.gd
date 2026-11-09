extends CanvasLayer

@onready var respawn_button: Button = $Control/VBoxContainer/RespawnButton
@onready var menu_button: Button = $Control/VBoxContainer/MenuButton

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	hide()
	
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

## Displays the Game Over screen and unhides the mouse cursor
func show_game_over() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Starts another round instantly upon clicking RESPAWN
func _on_respawn_pressed() -> void:
	hide()
	get_tree().paused = false
	LoadoutUI.auto_start_next_run = true
	get_tree().reload_current_scene()

## Reloads the scene and returns to the Main Menu
func _on_menu_pressed() -> void:
	hide()
	get_tree().paused = false
	LoadoutUI.auto_start_next_run = false
	get_tree().reload_current_scene()
