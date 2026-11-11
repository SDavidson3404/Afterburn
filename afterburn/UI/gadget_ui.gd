## Custom procedural 2D HUD overlay that renders dynamic radial cooldowns, active duration pie wedges, and armor segment shields.
extends Node2D

@export_category("UI References & Offset")
## Reference to the main player node.
@export var player: Player

## Reference to the global power manager node tracking run states.
@export var power_node: Node

## Vertical offset in pixels relative to the player's invincibility indicator.
@export var vertical_offset: float = 105.0

## Vertical spacing between stacked gadget circles when multiple effects are active.
@export var circle_spacing: float = 105.0

## Default base radius of drawn UI circles in pixels.
var radius: float = 22.0

## Default fill color for active radial gauges.
const DEFAULT_FILL: Color = Color(0.20, 0.95, 0.35, 0.90)

## Divider line color used to separate power armor shield segments.
const DIVIDER_COLOR: Color = Color(0.08, 0.01, 0.08, 0.95)

## Color mapping table defining signature HUD colors for each gadget type.
const GADGET_COLORS: Dictionary = {
	"power_armor": Color(0.20, 0.95, 0.35, 0.90),
	"hoverboard": Color(1.00, 1.00, 1.00, 0.90),
	"magnet": Color(0.95, 0.25, 0.25, 0.90),
	"pulse_wave": Color(0.95, 0.20, 0.85, 0.90),
	"overdriven_rocket": Color(1.00, 0.55, 0.00, 0.90)
}

## Data container class representing rendering instructions for a single HUD status circle.
class CircleData:
	var fill_ratio: float = 0.0
	var is_thirds: bool = false
	var hits: int = 0
	var color: Color = Color.GREEN
	var bg_color: Color = Color.BLACK
	var draw_pos: Vector2 = Vector2.ZERO
	var circle_radius: float = 22.0

## Active list of circle data entries to be rendered in the current frame draw call.
var active_circles: Array[CircleData] = []


func _ready() -> void:
	# High Z-index ensures UI elements render on top of world 3D geometry
	z_index = 100


func _process(_delta: float) -> void:
	if not power_node or not power_node.is_run_active:
		hide()
		return

	# Align HUD position and scale dynamically with player screen indicators
	if player and is_instance_valid(player.invincible_indicator):
		var inv = player.invincible_indicator
		global_position = inv.global_position + Vector2(0, vertical_offset)

		if inv.mesh:
			var max_dim: float = maxf(inv.mesh.get_aabb().size.x, inv.mesh.get_aabb().size.y)
			if max_dim > 0.0:
				radius = (max_dim * inv.scale.x) / 2.0
		elif inv.scale.x > 0:
			radius = 22.0 * inv.scale.x

	show()
	_update_circle_stack()
	queue_redraw()


## Queries active loadout and pickup nodes to construct rendering data for all active status rings.
func _update_circle_stack() -> void:
	active_circles.clear()
	if not player or not power_node:
		return

	var gadget = power_node.selected_gadget
	var equipped_id: String = gadget.gadget_id if gadget else ""
	var is_overcharged_state: bool = power_node.is_overcharged

	# Query temporary effect nodes attached to the player
	var active_hover = player.get_node_or_null("HoverboardInstance")
	var active_magnet = player.get_node_or_null("MagnetInstance")
	var active_armor = player.get_node_or_null("PowerArmorInstance")

	# 1. Primary equipped loadout gadget indicator (Right side HUD)
	if gadget and equipped_id != "base_gadget":
		var primary_circle := CircleData.new()
		primary_circle.color = GADGET_COLORS.get(equipped_id, DEFAULT_FILL)
		primary_circle.bg_color = Color(primary_circle.color.r * 0.2, primary_circle.color.g * 0.2, primary_circle.color.b * 0.2, 0.65)
		primary_circle.draw_pos = Vector2.ZERO
		primary_circle.circle_radius = radius

		var active_found: bool = false
		if equipped_id == "hoverboard" and active_hover:
			active_found = true
			primary_circle.fill_ratio = clampf(active_hover.duration / active_hover.max_duration, 0.0, 1.0)
		elif equipped_id == "magnet" and active_magnet:
			active_found = true
			primary_circle.fill_ratio = clampf(active_magnet.duration / active_magnet.max_duration, 0.0, 1.0)
		elif equipped_id == "power_armor" and active_armor:
			active_found = true
			primary_circle.is_thirds = true
			primary_circle.hits = active_armor.hits_remaining
		elif equipped_id == "overdriven_rocket":
			# Overdriven Rocket charging circle remains where it was and displays cooldown charge progress
			active_found = true
			primary_circle.fill_ratio = clampf(1.0 - power_node.gadget_cooldown_progress, 0.0, 1.0)

		# Display cooldown recharge progress if no active effect duration is running
		if not active_found:
			primary_circle.fill_ratio = clampf(1.0 - power_node.gadget_cooldown_progress, 0.0, 1.0)

		active_circles.append(primary_circle)

	# 2. Secondary indicators for temporary pickup effects (Right side HUD)
	var right_index: int = 1
	if active_hover and equipped_id != "hoverboard":
		_add_right_circle("hoverboard", active_hover.duration / active_hover.max_duration, right_index)
		right_index += 1
	if active_magnet and equipped_id != "magnet":
		_add_right_circle("magnet", active_magnet.duration / active_magnet.max_duration, right_index)
		right_index += 1
	if active_armor and equipped_id != "power_armor":
		var c := _create_circle_data("power_armor")
		c.is_thirds = true
		c.hits = active_armor.hits_remaining
		c.draw_pos = Vector2(0, right_index * circle_spacing)
		c.circle_radius = radius
		active_circles.append(c)
		right_index += 1

	# 3. Draining & queued Overdriven Rocket circles (Displayed on the left side above the power meter)
	if is_overcharged_state and "overdrive_rocket_timers" in power_node:
		var rocket_timers: Array = power_node.overdrive_rocket_timers
		var count: int = rocket_timers.size()
		if count > 0:
			# Query global rect of Power Meter bar or fallback to default coordinates
			var pm_rect := Rect2(391.0, 585.0, 321.0, 27.0)
			if player:
				var pm = player.get_node_or_null("Body/UI/Power Meter") as Control
				if pm:
					pm_rect = pm.get_global_rect()

			var circle_rad: float = 12.0
			var slot_spacing: float = 30.0
			var margin_left: float = 14.0
			var margin_above: float = 6.0
			var center_y: float = pm_rect.position.y - circle_rad - margin_above

			for i in range(count):
				# Slot 0 represents the leftmost position aligned with the start of the Power Meter
				var slot_index: int = (count - 1) - i
				var slot_x: float = pm_rect.position.x + margin_left + (float(slot_index) * slot_spacing)
				var target_screen_pos := Vector2(slot_x, center_y)

				var stack_circle := _create_circle_data("overdriven_rocket")
				stack_circle.circle_radius = circle_rad
				stack_circle.draw_pos = to_local(target_screen_pos)

				if i == 0:
					# Active draining rocket
					stack_circle.fill_ratio = clampf(float(rocket_timers[0]) / power_node.overdrive_rocket_max_duration, 0.0, 1.0)
				else:
					# Queued rockets waiting to drain
					stack_circle.fill_ratio = 1.0

				active_circles.append(stack_circle)


## Helper method to construct and append secondary right-side HUD indicators.
func _add_right_circle(gadget_key: String, ratio: float, index: int) -> void:
	var c := _create_circle_data(gadget_key)
	c.fill_ratio = clampf(ratio, 0.0, 1.0)
	c.draw_pos = Vector2(0, index * circle_spacing)
	c.circle_radius = radius
	active_circles.append(c)


## Helper method initializing CircleData instances with signature color styling.
func _create_circle_data(gadget_key: String) -> CircleData:
	var c := CircleData.new()
	c.color = GADGET_COLORS.get(gadget_key, DEFAULT_FILL)
	c.bg_color = Color(c.color.r * 0.2, c.color.g * 0.2, c.color.b * 0.2, 0.65)
	return c


## Main CanvasItem draw callback.
func _draw() -> void:
	for circle_data in active_circles:
		var center: Vector2 = circle_data.draw_pos
		var rad: float = circle_data.circle_radius
		
		draw_circle(center, rad, circle_data.bg_color)
		if circle_data.is_thirds:
			_draw_armor_thirds(center, rad, circle_data.hits, circle_data.color)
		else:
			_draw_pie_wedge(center, rad, circle_data.fill_ratio, circle_data.color)


## Renders a filled pie wedge.
func _draw_pie_wedge(center: Vector2, rad: float, ratio: float, color: Color) -> void:
	if rad <= 0.0 or ratio <= 0.001:
		return

	# Drawing a 360-degree pie wedge with draw_polygon causes self-overlapping start/end vertices that break 2D triangulation. Use draw_circle for full circles.
	if ratio >= 0.999:
		draw_circle(center, rad, color)
		return

	var points: PackedVector2Array = [center]
	var num_segments: int = max(4, int(ceil(32 * ratio)))
	var start_angle: float = -PI / 2.0  # Start pointing straight up (-90 degrees)
	var total_angle: float = ratio * TAU

	# Generate peripheral vertex points around circle circumference
	for i in range(num_segments + 1):
		var angle: float = start_angle + (float(i) / float(num_segments)) * total_angle
		points.append(center + Vector2(cos(angle), sin(angle)) * rad)
	draw_polygon(points, PackedColorArray([color]))


## Renders up to 3 equal 120-degree arc segments.
func _draw_armor_thirds(center: Vector2, rad: float, hits: int, color: Color) -> void:
	var segment_angle: float = TAU / 3.0
	var start_offset: float = -PI / 2.0

	# Draw filled arc polygons for active hit points
	for i in range(hits):
		var points: PackedVector2Array = [center]
		var seg_start: float = start_offset + (i * segment_angle)
		for j in range(11):
			var angle: float = seg_start + (float(j) / 10.0) * segment_angle
			points.append(center + Vector2(cos(angle), sin(angle)) * rad)
		draw_polygon(points, PackedColorArray([color]))

	# Draw segment divider lines across shield boundaries
	for i in range(3):
		var div_angle: float = start_offset + (i * segment_angle)
		var div_end: Vector2 = center + Vector2(cos(div_angle), sin(div_angle)) * rad
		draw_line(center, div_end, DIVIDER_COLOR, 3.0)
