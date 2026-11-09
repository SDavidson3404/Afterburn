extends CanvasLayer

@onready var respawn_button: Button = $Control/Button

func _ready() -> void:
	hide()
	if respawn_button:
		respawn_button.pressed.connect(_on_respawn_pressed)

## Displays the Game Over screen and makes the mouse cursor visible
func show_game_over() -> void:
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Reloads the scene instantly when the player clicks RESPAWN
func _on_respawn_pressed() -> void:
	hide()
	get_tree().reload_current_scene()
