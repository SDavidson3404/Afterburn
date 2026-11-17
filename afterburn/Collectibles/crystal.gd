extends collectible

var spawner: Node = null # The node that spawned it

# Runs on startup
func _ready() -> void: add_to_group("Collectibles") # Enables magnet tracking

func _ready() -> void:
	add_to_group("Collectibles") # Enables magnet tracking

## Receives reference to the spawner upon instantiation
func set_spawner(spawner_node: Node) -> void: spawner = spawner_node # Set the spawner variable to the argument given

# Runs on body entering
func _on_body_entered(body: Node3D) -> void:
	
	# If body is in Player group
	if body.is_in_group("Player"):
		
		# Run the pick up effect
		pick_up_effect()

# Runs the effect when picked up
func pick_up_effect() -> void:
	super() # Triggers parent 'collectible' visual/sound effects
	
	print("[ITEM PICKUP] Collected Power Crystal at position: ", global_position)
	
	# Notify spawner to trigger power refill, invincibility, and schedule next spawn
	if spawner and spawner.has_method("on_crystal_collected"):
		spawner.on_crystal_collected()
