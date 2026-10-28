## Overdriven Rocket loadout gadget.
## Replaces zero-power coasting with a high-risk Overdrive Surge while granting a temporary fuel-free overcharged state when activated.
extends GadgetBase


func _init() -> void:
	gadget_name = "Overdriven Rocket"
	gadget_id = "overdriven_rocket"


## Applies loadout passive trait: Enables Overdrive Surge mechanics in the power manager when suit fuel reaches zero.
func apply_loadout_nerf(power_manager: Node) -> void:
	if power_manager:
		power_manager.set("has_overdriven_rocket", true)


## Activates overcharged rocket state, suspending passive fuel drain for a timed window.
func activate_ability(_player: Node3D, power_manager: Node) -> void:
	if power_manager and power_manager.has_method("activate_overdrive_rocket"):
		power_manager.activate_overdrive_rocket()
