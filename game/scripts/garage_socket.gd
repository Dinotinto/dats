class_name GarageSocket
extends Button
## A machined mount plate; the inner shape communicates what fits here.

var garage
var slot := ""
var socket_type := "attack"
var occupied := false
var selected := false
var drop_ready := false
var revealed := false
var snap_target := false
var drag_active := false

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(46, 46)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	pivot_offset = size * 0.5

func _draw() -> void:
	if not icon_visible(): return
	var center := size * 0.5
	var accent := Color(0.98, 0.74, 0.2) if socket_type == "attack" else (Color(0.42, 0.86, 0.98) if socket_type == "wheel" else Color(0.53, 0.96, 0.74))
	if selected: accent = Color(1.0, 0.94, 0.45)
	if drop_ready: accent = Color(0.73, 1.0, 0.48)
	if snap_target: accent = Color.WHITE
	if is_hovered(): accent = accent.lightened(0.2)
	var plate := _regular(center, 22.0, 8, PI / 8.0)
	draw_colored_polygon(plate, Color(0.05, 0.07, 0.1, 0.85))
	draw_polyline(_closed(plate), Color(0.82, 0.75, 0.58, 0.96), 3.0, true)
	draw_polyline(_closed(_regular(center, 18.5, 8, PI / 8.0)), Color(0.3, 0.37, 0.41), 3.0, true)
	for i in 4:
		var at := center + Vector2.from_angle(PI * 0.25 + i * PI * 0.5) * 19.3
		draw_circle(at, 2.4, Color(0.06, 0.08, 0.1))
		draw_circle(at, 1.2, Color(0.84, 0.83, 0.69))
	if socket_type == "wheel":
		draw_circle(center, 14.2, Color(0.06, 0.09, 0.12))
		draw_arc(center, 12.0, 0.0, TAU, 28, accent, 3.5)
		draw_circle(center, 4.5, accent.darkened(0.2))
	elif socket_type == "attack":
		var shape := _regular(center, 12.3, 6, PI / 6.0)
		draw_colored_polygon(shape, Color(0.09, 0.1, 0.13))
		draw_polyline(_closed(shape), accent, 3.0, true)
		if not occupied: draw_circle(center, 2.4, accent)
	else:
		var square := _regular(center, 12.0, 4, PI / 4.0)
		draw_colored_polygon(square, Color(0.09, 0.1, 0.13))
		draw_polyline(_closed(square), accent, 3.0, true)
		if not occupied:
			draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), accent, 2.0)
			draw_line(center + Vector2(0, -4), center + Vector2(0, 4), accent, 2.0)
	if occupied: draw_circle(center, 3.2, accent)
	if selected or drop_ready or is_hovered():
		draw_arc(center, 24.0, 0.0, TAU, 36, accent, 2.0)

func icon_visible() -> bool:
	if drag_active: return drop_ready
	return not occupied or revealed or snap_target

func _regular(center: Vector2, radius: float, sides: int, angle: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in sides:
		result.append(center + Vector2.from_angle(angle + TAU * i / sides) * radius)
	return result

func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result

func _can_drop_data(_position: Vector2,data) -> bool:
	return data is Dictionary and data.has("uid") and garage.can_fit_payload(slot,data)

func _drop_data(_position: Vector2,data) -> void:
	garage.fit_item(slot,data.uid)

func _get_drag_data(_position: Vector2):
	var build: Dictionary = garage.current_build()
	var uid: String = build.get("equipped",{}).get(slot,"")
	if slot=="chassis" or build.get(slot,"")=="": return null
	var preview := PartIcon.new()
	preview.item = garage.main.inventory.find_item(uid)
	preview.custom_minimum_size = Vector2(130, 85)
	preview.size = Vector2(130, 85)
	set_drag_preview(preview)
	return {"uid":uid,"id":build[slot],"slot":slot,"origin":"equipped","preview":weakref(preview)}
