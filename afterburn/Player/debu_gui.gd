extends Control

@onready var fps: Label = $VBoxContainer/FPS
@onready var version: Label = $VBoxContainer/Version

const MIN_FPS_THRESHOLD: float = 60.0
const LOG_COOLDOWN: float = 1.0

var _low_fps_timer: float = 0.0

func _ready() -> void:
	version.text = ("Version: " + ProjectSettings.get_setting("application/config/version"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var current_fps: float = Engine.get_frames_per_second()
	fps.text = ("FPS: " + str(current_fps))
	_check_low_fps(current_fps, delta)

## Prints a warning to the terminal whenever FPS drops below 60 (throttled to once per second).
func _check_low_fps(current_fps: float, delta: float) -> void:
	if _low_fps_timer > 0.0:
		_low_fps_timer -= delta

	# Ignore 0 FPS during the initial second while the engine calculates its first reading
	if current_fps > 0.0 and current_fps < MIN_FPS_THRESHOLD and _low_fps_timer <= 0.0:
		print("[LOW FPS] Framerate dropped below 60 FPS: ", current_fps, " FPS")
		_low_fps_timer = LOG_COOLDOWN
