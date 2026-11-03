extends Control

@onready var fps: Label = $VBoxContainer/FPS
@onready var version: Label = $VBoxContainer/Version

func _ready() -> void:
	version.text = ("Version: " + ProjectSettings.get_setting("application/config/version"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	fps.text = ("FPS: " + str(Engine.get_frames_per_second()))
