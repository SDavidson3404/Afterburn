extends Area3D
class_name Obstacle

@export_enum("Jump", "False", "Slide") var dodge_capabilities: String = "False" # An indicator for how to dodge
@export var Row_Count: int = 1 # The amount of rows that this takes up
@export_enum("Left", "Single", "Right") var direction_stretched: String = "Single" # The direction it stretches in
