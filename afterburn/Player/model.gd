extends Node3D


@onready var animation_player: AnimationPlayer = $AnimationPlayer

func play_anim(Anim_Name):
	animation_player.play(Anim_Name)
