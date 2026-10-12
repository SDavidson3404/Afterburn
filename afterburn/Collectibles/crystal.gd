extends collectible

var spawner: Node = null

## Receives reference to the spawner upon instantiation
func set_spawner(spawner_node: Node) -> void:
	spawner = spawner_node

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		pick_up_effect()

func pick_up_effect() -> void:
	super() # Triggers parent 'collectible' visual/sound effects
	
	# Notify spawner to trigger power refill, invincibility, and schedule next spawn
	if spawner and spawner.has_method("on_crystal_collected"):
		spawner.on_crystal_collected()
